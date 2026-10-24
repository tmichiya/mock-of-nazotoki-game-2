extends Node
## World(自動読み込み)
## 今のシーンの地形への問い合わせ窓口と、プレイヤーの名簿、デバッグ表示の切り替え。
## 地形が無いシーンでは「平らな0段」として答えるので、部品は地形が無くても動く。

signal debug_changed
signal players_changed
## 二人で共有の値が変わった(音のかけらの数など)
signal shared_changed(key: String, value: Variant)

var config: WorldConfig
## F1: 段番号を表示
var debug_levels := false:
	set(v):
		debug_levels = v
		_redraw_terrain()
		debug_changed.emit()
## F2: 音の波の届く範囲を表示
var debug_wave_range := false:
	set(v):
		debug_wave_range = v
		debug_changed.emit()

## F3: 「片方にしか見えない物」を誰の目で見るか(0 = 自分、1・2 = その人として見る)。1台で2人の確認用
var viewer_override := 0

var _players: Array = []
var _shared := {}


func _ready() -> void:
	config = WorldConfig.get_default()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.peer_scene_ready.connect(func(id):
		if Net.is_host():
			_rpc_all_shared.rpc_id(id, _shared))
	get_tree().tree_changed.connect(_on_tree_changed)


var _last_scene: Node


func _on_tree_changed() -> void:
	if not is_inside_tree():
		return
	var s := get_tree().current_scene
	if s != _last_scene:
		_last_scene = s
		_shared.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			debug_levels = not debug_levels
		elif event.physical_keycode == KEY_F2:
			debug_wave_range = not debug_wave_range
		elif event.physical_keycode == KEY_F3:
			viewer_override = (viewer_override + 1) % 3
			debug_changed.emit()


func _redraw_terrain() -> void:
	var t := get_terrain()
	if t:
		t._queue_redraw_rows()


func get_terrain() -> Terrain:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("terrain") as Terrain


# ---------------------------------------------------------------- 地形への問い合わせ

func height_at(global_pos: Vector2) -> float:
	var t := get_terrain()
	return t.get_height_at(global_pos) if t else 0.0


func level_at(global_pos: Vector2) -> int:
	return roundi(height_at(global_pos))


func has_ground(global_pos: Vector2) -> bool:
	var t := get_terrain()
	return t.has_ground_at(global_pos) if t else true


func is_blocked_between(a: Vector2, b: Vector2, height: float) -> bool:
	var t := get_terrain()
	return t.is_blocked_between(a, b, height) if t else false


func height_offset(h: float) -> Vector2:
	return config.height_offset(h)


## 地面の位置 ground、高さ height にある大きさ size(幅・高さpx)の物が、手前の物に隠れているか
func is_occluded(ground: Vector2, height: float, size: Vector2, exclude: Node = null) -> bool:
	var t := get_terrain()
	if t and t.occludes(ground, height, size):
		return true
	var feet := ground + config.height_offset(height)
	var rect := Rect2(feet - Vector2(size.x * 0.5, size.y), size)
	for o in get_tree().get_nodes_in_group("occluder"):
		if o == exclude:
			continue
		if o.has_method("occludes_screen_rect") and o.occludes_screen_rect(rect, ground.y):
			return true
	return false


# ---------------------------------------------------------------- プレイヤーの名簿

func register_player(p: Node) -> void:
	if p not in _players:
		_players.append(p)
		players_changed.emit()


func unregister_player(p: Node) -> void:
	_players.erase(p)
	players_changed.emit()


func get_players() -> Array:
	return _players.filter(func(p): return is_instance_valid(p))


func get_player_by_index(index: int) -> Node:
	for p in get_players():
		if p.player_index == index:
			return p
	return null


func get_partner(p: Node) -> Node:
	for q in get_players():
		if q != p:
			return q
	return null


## この端末で操作しているプレイヤー(1台で2人を動かしている時は2人)
func get_local_players() -> Array:
	return get_players().filter(func(p): return p.is_local)


## この画面の「自分」(片方にしか見えない物の判定に使う。1台で2人の時は1人目)
func get_viewer_index() -> int:
	if viewer_override > 0:
		return viewer_override
	var locals := get_local_players()
	if locals.is_empty():
		return 1
	var best: int = locals[0].player_index
	for p in locals:
		best = mini(best, p.player_index)
	return best


# ---------------------------------------------------------------- 二人で共有の値(ホストが決める)

func get_shared(key: String, default: Variant = 0) -> Variant:
	return _shared.get(key, default)


## ホストで呼ぶ(クライアントで呼んでも無視)
func set_shared(key: String, value: Variant) -> void:
	if not Net.is_host():
		return
	_shared[key] = value
	shared_changed.emit(key, value)
	if Net.is_online():
		for id in Net.ready_remote_ids():
			_rpc_shared.rpc_id(id, key, value)


func add_shared(key: String, amount: int) -> void:
	set_shared(key, int(get_shared(key, 0)) + amount)


@rpc("authority", "call_remote", "reliable")
func _rpc_shared(key: String, value: Variant) -> void:
	_shared[key] = value
	shared_changed.emit(key, value)


@rpc("authority", "call_remote", "reliable")
func _rpc_all_shared(all: Dictionary) -> void:
	for k in all.keys():
		_shared[k] = all[k]
		shared_changed.emit(k, all[k])
