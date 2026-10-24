class_name PlayerSpawner
extends Node2D
## 2人のプレイヤーを出す部品。島のシーンに1つ置く。出る場所は SpawnPoint 部品(番号1・2)を置いて決める。
## SpawnPoint が無ければ、この部品の位置に並んで出る。
## ・オフライン(接続せずに実行):この1台で2人とも動かす(1人目=キーボードA+コントローラー0、2人目=キーボードB+コントローラー1)
## ・オンライン:ホストが1人目、参加した人が2人目
## プレイヤーは「この部品の親」に追加される(親は Y Sort をオンにしておく)。

signal players_spawned

@export var player_scene: PackedScene = preload("res://scenes/parts/player/player.tscn")
## 1人目・2人目の体の色
@export var colors: Array[Color] = [Color("e8804a"), Color("4a9be8")]
## 接続していない時に2人とも出すか(false なら1人目だけ)
@export var offline_two_players := true
## オフラインの2人目のキーボードの組とコントローラー番号
@export var offline_p2_keyboard := PlayerInput.Keyboard.B
@export var offline_p2_pad := 1

var _spawned := {}   # peer_id -> Player


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Net.session_started.connect(_respawn_online)
	Net.peer_joined.connect(func(_id): _respawn_online())
	Net.peer_left.connect(_on_peer_left)
	Net.session_ended.connect(_respawn_offline)
	if Net.is_online():
		_respawn_online.call_deferred()
	elif Net.auto_host or Net.auto_join_ip != "":
		# 起動引数で接続する時は、つながるまで待つ(ホストは自分だけ先に出す)
		if Net.auto_host:
			_respawn_online.call_deferred()
	else:
		_respawn_offline.call_deferred()


func spawn_position(index: int) -> Vector2:
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if sp.index == index:
			return sp.global_position
	return global_position + Vector2((index - 1) * 24, 0)


func _clear() -> void:
	for p in _spawned.values():
		if is_instance_valid(p):
			p.queue_free()
	_spawned.clear()


func _respawn_offline() -> void:
	_clear()
	_spawn(1, 1, true, Net.local_keyboard, Net.local_pad)
	if offline_two_players:
		_spawn(2, 2, true, offline_p2_keyboard, offline_p2_pad)
	players_spawned.emit()


func _respawn_online() -> void:
	if not Net.is_online():
		return
	var ids := [1]
	for id in Net.remote_ids() + [Net.my_id()]:
		if id not in ids:
			ids.append(id)
	ids.sort()
	ids = ids.slice(0, 2)
	# いなくなった人(オフラインの2人目など)を消し、足りない人だけ出す
	for id in _spawned.keys():
		if id not in ids or not is_instance_valid(_spawned[id]) or _spawned[id].is_local != (id == Net.my_id()):
			if is_instance_valid(_spawned[id]):
				_spawned[id].queue_free()
			_spawned.erase(id)
	for i in range(ids.size()):
		var id: int = ids[i]
		if not _spawned.has(id):
			_spawn(id, i + 1, id == Net.my_id(), Net.local_keyboard, Net.local_pad)
	Net.announce_scene_ready.call_deferred()
	players_spawned.emit()


func _exit_tree() -> void:
	Net.local_scene_ready = false


func _on_peer_left(id: int) -> void:
	if _spawned.has(id):
		_spawned[id].queue_free()
		_spawned.erase(id)


func _spawn(peer_id: int, index: int, local: bool, kb: int, pad: int) -> Player:
	var p: Player = player_scene.instantiate()
	p.name = "Player_%d" % peer_id
	p.player_index = index
	p.owner_peer = peer_id
	p.is_local = local
	p.body_color = colors[(index - 1) % colors.size()]
	if local:
		p.keyboard = kb
		p.joy_device = pad
	else:
		p.keyboard = PlayerInput.Keyboard.NONE
		p.joy_device = -1
	p.position = get_parent().to_local(spawn_position(index)) if get_parent() is Node2D else spawn_position(index)
	get_parent().add_child.call_deferred(p)
	_spawned[peer_id] = p
	return p


func get_players() -> Array:
	return _spawned.values()
