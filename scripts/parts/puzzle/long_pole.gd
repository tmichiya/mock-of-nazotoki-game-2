@tool
class_name LongPole
extends PuzzlePart
## 長い棒。二人で両端を握って運ぶ(握るのは手つなぎと同じボタン LB/RB)。
## 棒は二人の位置に合わせて動き・回るが、重いほどゆっくりしか動かない。
## 二人の動きが合わないと(引っ張り合うと)うまく回らない。
## 地形の壁や扉に当たると、ぶつかった速さに応じた大きさの音の波を出す(こすっただけなら小さな波)。
## この部品の位置は棒の真ん中。

signal grabbed(end_index: int)
signal released(end_index: int)
## 何かに当たった(強さ 0〜)
signal hit(strength: float)
## 二人で両端を握った / 片方が離した
signal carried_by_two
signal dropped_by_two

## 長さ(px)
@export var length := 72.0:
	set(v):
		length = v
		queue_redraw()
## 向き(度。置いた時の向き)
@export var start_angle_deg := 0.0:
	set(v):
		start_angle_deg = v
		angle = deg_to_rad(v)
		queue_redraw()
## 重さ(大きいほどゆっくり動く・回る)
@export_range(0.2, 10.0) var weight := 1.5
## 重さ1の時に動ける速さ(px/秒)と回れる速さ(ラジアン/秒)
@export var move_speed := 80.0
@export var turn_speed := 2.5
## 握れる距離(px)
@export var grab_radius := 12.0
## 端から手がこれ以上離れたら、プレイヤーを端へ引き戻す(px)
@export var slack := 4.0
## 両端を握っている間を「つながっている」扱いにする(声が棒を伝って届く)
@export var counts_as_link := false
@export_group("当たった音")
## この速さ(px/秒)で当たると大きさ1の波
@export var impact_speed_ref := 60.0
## この速さ未満は音を出さない
@export var min_impact_speed := 4.0
## 波の大きさの上限
@export var max_wave_size := 2.5
## 音を出す間隔の最小(秒。こすり続けた時に出しすぎない)
@export var sound_cooldown := 0.18
@export var impact_shape: WaveShape = preload("res://resources/wave_shapes/impact.tres")
@export var color := Color("b88a52")

var angle := 0.0
## 型(PoleSocket)にはまって動かない
var locked := false
var _holders: Array = [null, null]    # [Player, side]
var _cooldown := 0.0
var _net_center := Vector2.ZERO
var _net_angle := 0.0
var _send := 0.0
var _two := false


func _ready() -> void:
	super._ready()
	angle = deg_to_rad(start_angle_deg)
	if Engine.is_editor_hint():
		return
	add_to_group("props")
	process_physics_priority = 20
	_net_center = global_position
	_net_angle = angle


func ends() -> Array:
	var u := Vector2.from_angle(angle) * length * 0.5
	return [global_position - u, global_position + u]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if locked:
		return
	if not is_authority():
		global_position = global_position.lerp(_net_center, clampf(delta * 12.0, 0.0, 1.0))
		angle = lerp_angle(angle, _net_angle, clampf(delta * 12.0, 0.0, 1.0))
		_update_height()
		queue_redraw()
		return
	_cooldown -= delta
	_update_holders()
	var e := ends()
	var h0: Player = _holders[0][0] if _holders[0] else null
	var h1: Player = _holders[1][0] if _holders[1] else null
	var target_c := global_position
	var target_a := angle
	if h0 and h1:
		var t0 := _hand(0)
		var t1 := _hand(1)
		target_c = (t0 + t1) * 0.5
		target_a = (t1 - t0).angle()
	elif h0 or h1:
		var i := 0 if h0 else 1
		var t := _hand(i)
		var other: Vector2 = e[1 - i]
		var u := (other - t).normalized()
		if u == Vector2.ZERO:
			u = Vector2.from_angle(angle) * (1.0 if i == 0 else -1.0)
		target_c = t + u * length * 0.5
		target_a = (u if i == 0 else -u).angle()
	var w := maxf(weight, 0.05)
	var max_move := move_speed / w * delta
	var max_turn := turn_speed / w * delta
	var new_c := global_position + (target_c - global_position).limit_length(max_move)
	var da := clampf(angle_difference(angle, target_a), -max_turn, max_turn)
	var new_a := angle + da
	_try_move(new_c, new_a, delta)
	_pull_players_to_ends()
	var e2 := ends()
	for i in [0, 1]:
		if _holders[i]:
			hold_hand(_holders[i][0], _holders[i][1], e2[i])
	_update_height()
	_update_link()
	queue_redraw()
	_sync(delta)


func _hand(i: int) -> Vector2:
	var p: Player = _holders[i][0]
	return p.global_position


func _update_holders() -> void:
	var e := ends()
	for i in [0, 1]:
		if _holders[i]:
			var p: Player = _holders[i][0]
			var side: int = _holders[i][1]
			if not is_instance_valid(p) or not is_reaching(p, side):
				if is_instance_valid(p):
					p.held_objects[side] = null
					release_hand(p, side)
				_holders[i] = null
				released.emit(i)
		if _holders[i] == null:
			var g := find_grabber(e[i], grab_radius, 1.2)
			if not g.is_empty():
				# 同じ人が両端は持たない
				var other = _holders[1 - i]
				if other and other[0] == g[0]:
					continue
				_holders[i] = g
				g[0].held_objects[g[1]] = self
				grabbed.emit(i)


# 動けるなら動く。壁に当たったら止まって音を出す
func _try_move(new_c: Vector2, new_a: float, delta: float) -> void:
	var old_e := ends()
	var u := Vector2.from_angle(new_a) * length * 0.5
	var ne := [new_c - u, new_c + u]
	var hit_point = _blocked_point(ne[0], ne[1])
	if hit_point == null:
		global_position = new_c
		angle = new_a
		return
	# どれくらいの速さでぶつかったか(端の動きの速い方)
	var v0: float = ne[0].distance_to(old_e[0]) / delta
	var v1: float = ne[1].distance_to(old_e[1]) / delta
	var speed := maxf(v0, v1)
	# 回転だけ・移動だけで動けるか試す(こすりながら動く)
	var ua := Vector2.from_angle(angle) * length * 0.5
	if _blocked_point(new_c - ua, new_c + ua) == null:
		global_position = new_c
	elif _blocked_point(global_position - u, global_position + u) == null:
		angle = new_a
	_make_sound(hit_point, speed)


func _blocked_point(a: Vector2, b: Vector2):
	var h := height + 0.5
	var steps := maxi(4, int(a.distance_to(b) / 6.0))
	for k in range(steps + 1):
		var p := a.lerp(b, float(k) / steps)
		if World.height_at(p) > h + 0.01 or not World.has_ground(p):
			return p
	for wall in get_tree().get_nodes_in_group("sound_wall"):
		if wall.has_method("blocks_level") and wall.blocks_level(get_level()):
			var d := (b - a)
			var r: Dictionary = wall.intersect(a, d.normalized(), d.length())
			if r.hit:
				return a + d.normalized() * float(r.t)
	return null


func _make_sound(at: Vector2, speed: float) -> void:
	if speed < min_impact_speed or _cooldown > 0.0:
		return
	_cooldown = sound_cooldown
	var size := clampf(speed / impact_speed_ref, 0.15, max_wave_size)
	Waves.emit({ origin = at, level = get_level(), size = size, shape = impact_shape.resource_path, source = "pole:" + str(name) })
	hit.emit(size)


func _pull_players_to_ends() -> void:
	var e := ends()
	for i in [0, 1]:
		if _holders[i] == null:
			continue
		var p: Player = _holders[i][0]
		var d: Vector2 = e[i] - p.global_position
		if d.length() > slack:
			p.move_and_collide(d - d.normalized() * slack)
			if not p.is_airborne():
				p.height = World.height_at(p.global_position)


func _update_height() -> void:
	var hs := []
	for hd in _holders:
		if hd:
			hs.append(hd[0].height)
	if hs.is_empty():
		height = World.height_at(global_position)
	else:
		var sum := 0.0
		for v in hs:
			sum += v
		height = sum / hs.size()


func _update_link() -> void:
	var two := _holders[0] != null and _holders[1] != null
	if two != _two:
		_two = two
		if two:
			carried_by_two.emit()
		else:
			dropped_by_two.emit()
	if counts_as_link:
		Hands.set_virtual_link(self, _holders[0][0] if _holders[0] else null, _holders[1][0] if _holders[1] else null, two)


func _sync(delta: float) -> void:
	if not Net.is_online():
		return
	_send -= delta
	if _send > 0.0:
		return
	_send = 1.0 / 20.0
	for id in Net.ready_remote_ids():
		_rpc_pose.rpc_id(id, global_position, angle)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_pose(c: Vector2, a: float) -> void:
	_net_center = c
	_net_angle = a


## 型にはめる(動かなくなる)。release = 握っている手を離させる
func lock_at(pos: Vector2, a: float, release: bool = true) -> void:
	locked = true
	global_position = pos
	angle = a
	_net_center = pos
	_net_angle = a
	for i in [0, 1]:
		if _holders[i]:
			var p: Player = _holders[i][0]
			if is_instance_valid(p):
				p.held_objects[_holders[i][1]] = null
				release_hand(p, _holders[i][1])
				if release:
					p.release_all()
			_holders[i] = null
	_update_link()
	if Net.is_online() and is_authority():
		_rpc_lock.rpc(pos, a)
	queue_redraw()


@rpc("authority", "call_remote", "reliable")
func _rpc_lock(pos: Vector2, a: float) -> void:
	locked = true
	global_position = pos
	angle = a
	queue_redraw()


func on_reset() -> void:
	angle = deg_to_rad(start_angle_deg)
	_net_center = global_position
	_net_angle = angle


func _draw() -> void:
	var u := Vector2.from_angle(angle) * length * 0.5
	var lp := WorldConfig.get_default().level_px
	var ground := Vector2(0, -height * lp) if not Engine.is_editor_hint() else lift()
	var held := not Engine.is_editor_hint() and (_holders[0] != null or _holders[1] != null)
	var lifted := ground + Vector2(0, -(0.6 if held else 0.1) * lp)
	draw_line(ground - u, ground + u, Color(0, 0, 0, 0.25), 3.0)
	draw_line(lifted - u, lifted + u, color.darkened(0.3), 4.0)
	draw_line(lifted - u, lifted + u, color, 2.0)
	for i in [0, 1]:
		var end := lifted + (-u if i == 0 else u)
		var on := not Engine.is_editor_hint() and _holders[i] != null
		draw_circle(end, 2.5, Color("fff4d8") if on else color.lightened(0.3))
