extends Node
## Clears(自動読み込み)
## 謎の「○○をクリア」をまとめる窓口。ギミックは名前を付けてクリアを知らせ、
## 障害物や演出は名前でクリアを購読して、動いたり、見えなくなったり見えたりする。
##
## 知らせる側: Clears.clear(&"名前")  … ギミックのインスペクタの clear_event に名前を書けば自動で呼ばれる
## 調べる側:   Clears.is_cleared(&"名前") / シグナル cleared(name)・reset(name)
##             エディタでつなぐ時は ClearListener / ClearReactor / ClearFx を置く
## クリアはホストが決め、相手にも配る(後から参加した相手にも送り直す)。シーンが変わると全部消える。

## クリアした(name = クリアの名前)
signal cleared(name: StringName)
## クリアを取り消した(やり直しなど)
signal reset(name: StringName)

var _cleared := {}
var _last_scene: Node


func _ready() -> void:
	Net.peer_scene_ready.connect(func(id):
		if Net.is_host():
			_rpc_all.rpc_id(id, _cleared.keys()))
	get_tree().tree_changed.connect(_on_tree_changed)


func _on_tree_changed() -> void:
	if not is_inside_tree():
		return
	var s := get_tree().current_scene
	if s != _last_scene:
		_last_scene = s
		_cleared.clear()


## クリアを知らせる(ホストで呼ぶ。クライアントで呼んでも無視)。同じ名前を2回クリアしても1回だけ知らせる
func clear(event: StringName) -> void:
	if event == &"" or not Net.is_host() or _cleared.has(event):
		return
	_apply_clear(event)
	if Net.is_online():
		for id in Net.ready_remote_ids():
			_rpc_clear.rpc_id(id, event)


## クリアを取り消す(ホストで呼ぶ)
func reset_clear(event: StringName) -> void:
	if not Net.is_host() or not _cleared.has(event):
		return
	_apply_reset(event)
	if Net.is_online():
		for id in Net.ready_remote_ids():
			_rpc_reset.rpc_id(id, event)


func is_cleared(event: StringName) -> bool:
	return _cleared.has(event)


## 名前の一覧のうち、いくつクリアしているか
func count_cleared(events: Array) -> int:
	var n := 0
	for e in events:
		if _cleared.has(StringName(e)):
			n += 1
	return n


func cleared_list() -> Array:
	return _cleared.keys()


func _apply_clear(event: StringName) -> void:
	if _cleared.has(event):
		return
	_cleared[event] = true
	print("[Clears] クリア: ", event)
	cleared.emit(event)


func _apply_reset(event: StringName) -> void:
	if not _cleared.has(event):
		return
	_cleared.erase(event)
	reset.emit(event)


@rpc("authority", "call_remote", "reliable")
func _rpc_clear(event: StringName) -> void:
	_apply_clear(event)


@rpc("authority", "call_remote", "reliable")
func _rpc_reset(event: StringName) -> void:
	_apply_reset(event)


@rpc("authority", "call_remote", "reliable")
func _rpc_all(events: Array) -> void:
	for e in events:
		_apply_clear(StringName(e))
