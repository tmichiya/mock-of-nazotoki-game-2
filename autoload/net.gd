extends Node
## Net(自動読み込み)
## ENet による2人の接続、時計合わせ、起動引数の読み取り。
##
## 起動引数(エディタの「デバッグ > 複数インスタンスの実行をカスタマイズ」で指定する):
##   --host               起動したらすぐホストになる
##   --join=127.0.0.1     起動したらすぐ参加する
##   --port=7777          ポート
##   --pad=0              使うコントローラーの番号(-1 でコントローラーを使わない)
##   --kb=a|b|none        使うキーボードの組
##   --allow-unfocused    ウィンドウが選ばれていなくても入力を受け付ける
## 「--」の後ろに書く(例: godot -- --host --pad=0)。

signal session_started            ## 二人そろった(ホストは相手の参加時、参加側は接続成功時)
signal session_ended
signal peer_joined(id: int)
signal peer_left(id: int)
signal connection_failed
signal status_changed(text: String)
signal peer_ready_changed
## 相手のシーンの準備ができた(部品はこれを受けて、ホストから今の状態を送り直す)
signal peer_scene_ready(id: int)

const DEFAULT_PORT := 7777

## 時計合わせの間隔(秒)
var ping_interval := 1.0

var port := DEFAULT_PORT
var local_pad := 0
var local_keyboard := PlayerInput.Keyboard.A
var allow_unfocused := false
var auto_host := false
var auto_join_ip := ""

var _clock_offset := 0.0     # ホストの時計 - 自分の時計
var _rtt := 0.0
var _ping_timer := 0.0
var _ready_peers := {}       # シーンの準備ができた相手
var local_scene_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	if auto_host:
		host.call_deferred(port)
	elif auto_join_ip != "":
		join.call_deferred(auto_join_ip, port)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == "--host":
			auto_host = true
		elif a.begins_with("--join="):
			auto_join_ip = a.substr(7)
		elif a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--pad="):
			local_pad = int(a.substr(6))
		elif a.begins_with("--kb="):
			match a.substr(5).to_lower():
				"a": local_keyboard = PlayerInput.Keyboard.A
				"b": local_keyboard = PlayerInput.Keyboard.B
				_: local_keyboard = PlayerInput.Keyboard.NONE
		elif a == "--allow-unfocused":
			allow_unfocused = true


# ---------------------------------------------------------------- 接続

func host(p: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p, 1)
	if err != OK:
		status_changed.emit("ホストを開けませんでした (%s)" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	status_changed.emit("ホスト中 ポート %d。相手を待っています…" % p)
	return OK


func join(ip: String, p: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, p)
	if err != OK:
		status_changed.emit("接続できませんでした (%s)" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	status_changed.emit("%s:%d に接続中…" % [ip, p])
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_ready_peers.clear()
	session_ended.emit()


## 通信中か(相手がいなくてもホストとして待っている間は true)
func is_online() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## 部品の状態を決める端末か(オフラインでは常に true)
func is_host() -> bool:
	return not is_online() or multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func remote_ids() -> Array:
	return Array(multiplayer.get_peers()) if is_online() else []


func has_partner() -> bool:
	return not remote_ids().is_empty()


func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)
	if multiplayer.is_server():
		status_changed.emit("相手が参加しました")
		# 今のシーンを相手にも開かせる
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path != "":
			_rpc_change_scene.rpc_id(id, scene.scene_file_path)
		session_started.emit()


func _on_peer_disconnected(id: int) -> void:
	_ready_peers.erase(id)
	peer_left.emit(id)
	status_changed.emit("相手が抜けました")


func _on_connected() -> void:
	status_changed.emit("接続しました")
	_ping_timer = 0.0
	session_started.emit()


func _on_failed() -> void:
	status_changed.emit("接続に失敗しました")
	connection_failed.emit()
	leave()


func _on_server_gone() -> void:
	status_changed.emit("ホストとの接続が切れました")
	leave()


# ---------------------------------------------------------------- シーンの準備

## シーンの部品(プレイヤーなど)の準備ができたことを相手に知らせる
func announce_scene_ready() -> void:
	local_scene_ready = true
	if is_online():
		_rpc_scene_ready.rpc(true)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_scene_ready(reply: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	_ready_peers[id] = true
	if reply and local_scene_ready:
		_rpc_scene_ready.rpc_id(id, false)
	peer_ready_changed.emit()
	peer_scene_ready.emit(id)


func is_peer_ready(id: int) -> bool:
	return _ready_peers.has(id)


func ready_remote_ids() -> Array:
	return remote_ids().filter(func(id): return _ready_peers.has(id))


## ホストが相手にシーンの切り替えを指示する
func change_scene_for_all(path: String) -> void:
	if is_online() and multiplayer.is_server():
		_rpc_change_scene.rpc(path)
	_ready_peers.clear()
	local_scene_ready = false
	get_tree().change_scene_to_file(path)


@rpc("authority", "call_remote", "reliable")
func _rpc_change_scene(path: String) -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == path:
		return
	_ready_peers.clear()
	local_scene_ready = false
	get_tree().change_scene_to_file(path)


# ---------------------------------------------------------------- 時計

## 二人で共通の時刻(秒)。ホストの時計に合わせる
func time() -> float:
	return Time.get_ticks_usec() / 1000000.0 + _clock_offset


func local_time() -> float:
	return Time.get_ticks_usec() / 1000000.0


## 相手の時刻 t を、自分の時計での時刻に直す
func to_local_time(shared_time: float) -> float:
	return shared_time - _clock_offset


func rtt() -> float:
	return _rtt


func _process(delta: float) -> void:
	if not is_online() or multiplayer.is_server():
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = ping_interval
		_rpc_ping.rpc_id(1, local_time())


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping(client_time: float) -> void:
	_rpc_pong.rpc_id(multiplayer.get_remote_sender_id(), client_time, local_time())


@rpc("authority", "call_remote", "unreliable")
func _rpc_pong(client_time: float, host_time: float) -> void:
	var now := local_time()
	var rtt_now := now - client_time
	var offset_now := host_time + rtt_now * 0.5 - now
	if _rtt == 0.0:
		_rtt = rtt_now
		_clock_offset = offset_now
	else:
		_rtt = lerpf(_rtt, rtt_now, 0.2)
		_clock_offset = lerpf(_clock_offset, offset_now, 0.2)
