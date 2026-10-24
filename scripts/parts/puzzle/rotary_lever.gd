@tool
class_name RotaryLever
extends PuzzlePart
## 回転レバー。どんな物でも回せる。つかんで(ポーズ中に腕を向けると自動でつかむ)左スティックを左右に倒している間、
## レバーがそちらに倒れ、targets がそちらへゆっくり、なめらかに回る。離すと真ん中に戻って止まる。
## 握っている間、握っている人はその場から動かない(スティックはレバーを倒すのに使う)。
##
## 回す相手(targets): get_lever_rotation() / set_lever_rotation(ラジアン) を持つ物(声を食べる動物など)はそれを使い、
## それ以外の Node2D は rotation を回す。

signal tilted(direction: int)          ## -1 = 左, 0 = 真ん中, 1 = 右
signal rotation_changed(degrees: float)
signal pull_failed

## 回す相手
@export var targets: Array[NodePath] = []
## いっぱいに倒した時の回る速さ(度/秒)。右に倒すと時計回り
@export var rotate_speed_deg := 45.0
## 回せる範囲(度)。最初の向きからの角度。0 なら制限なし
@export var limit_deg := 0.0
## 動かすのに必要な人数(握っている人と、その人と手をつないでいる人を数える)
@export_range(1, 2) var required_players := 1
## つかめる距離(px)
@export var grab_radius := 12.0
## レバーが倒れる・戻る速さ
@export var tilt_speed := 4.0
@export_group("クリア")
## 1つ目の相手がこの角度(度。最初の向きからではなく、そのものの角度)になったら知らせる
@export var clear_event: StringName = &""
@export var clear_angle_deg := 0.0
@export var clear_tolerance_deg := 6.0

var tilt := 0.0          # -1〜1(見た目と回す量)
var _holder: Player
var _holder_side := 0
var _start := {}         # 相手 -> 最初の角度
var _sent := 0.0
var _last_dir := 0
var _fail_latch := false
var _cleared := false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	process_physics_priority = 20
	for n in _target_nodes():
		_start[n] = _get_rot(n)


func _target_nodes() -> Array:
	var out := []
	for p in targets:
		var n := get_node_or_null(p)
		if n:
			out.append(n)
	return out


func _get_rot(n: Node) -> float:
	if n.has_method("get_lever_rotation"):
		return n.get_lever_rotation()
	if n is Node2D:
		return n.rotation
	return 0.0


func _set_rot(n: Node, r: float) -> void:
	if n.has_method("set_lever_rotation"):
		n.set_lever_rotation(r)
	elif n is Node2D:
		n.rotation = r


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority():
		return
	# つかむ・離す
	if _holder and not (is_instance_valid(_holder) and is_reaching(_holder, _holder_side)):
		_release()
	if _holder == null:
		var g := find_grabber(global_position, grab_radius)
		if not g.is_empty():
			_holder = g[0]
			_holder_side = g[1]
			_holder.held_objects[_holder_side] = self
			_holder.set_move_locked(_lock_key(), true)
	var want := 0.0
	if _holder:
		hold_hand(_holder, _holder_side, global_position)
		var x: float = _holder.input.move.x
		if absf(x) > 0.25:
			if _count_pullers() >= required_players:
				want = signf(x) * minf(1.0, absf(x))
				_fail_latch = false
			elif not _fail_latch:
				_fail_latch = true
				pull_failed.emit()
		else:
			_fail_latch = false
	tilt = move_toward(tilt, want, tilt_speed * delta)
	var dir := 0 if absf(tilt) < 0.05 else int(signf(tilt))
	if dir != _last_dir:
		_last_dir = dir
		tilted.emit(dir)
	if absf(tilt) > 0.01:
		_rotate_targets(deg_to_rad(rotate_speed_deg) * tilt * delta)
	_sync(delta)
	queue_redraw()


func _rotate_targets(amount: float) -> void:
	for n in _target_nodes():
		var r := _get_rot(n) + amount
		if limit_deg > 0.0 and _start.has(n):
			var lim := deg_to_rad(limit_deg)
			r = _start[n] + clampf(angle_difference(_start[n], r), -lim, lim)
		_set_rot(n, r)
	var first = _target_nodes().front() if not _target_nodes().is_empty() else null
	if first:
		var deg := rad_to_deg(_get_rot(first))
		rotation_changed.emit(deg)
		var near := absf(angle_difference(deg_to_rad(deg), deg_to_rad(clear_angle_deg))) <= deg_to_rad(clear_tolerance_deg)
		if near and not _cleared and clear_event != &"":
			_cleared = true
			Clears.clear(clear_event)


func _count_pullers() -> int:
	var n := 1
	if Hands.is_player_linked(_holder):
		n += 1
	return n


func _lock_key() -> String:
	return "lever:" + str(get_path())


func _release() -> void:
	if is_instance_valid(_holder):
		_holder.held_objects[_holder_side] = null
		release_hand(_holder, _holder_side)
		_holder.set_move_locked(_lock_key(), false)
	_holder = null


# 回した結果(相手の角度)を相手の端末へ送る
func _sync(delta: float) -> void:
	if not Net.is_online():
		return
	_sent -= delta
	if _sent > 0.0:
		return
	_sent = 1.0 / 15.0
	var rots := []
	for n in _target_nodes():
		rots.append(_get_rot(n))
	for id in Net.ready_remote_ids():
		_rpc_rot.rpc_id(id, tilt, rots)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_rot(t: float, rots: Array) -> void:
	tilt = t
	var nodes := _target_nodes()
	for i in range(mini(nodes.size(), rots.size())):
		_set_rot(nodes[i], rots[i])
	queue_redraw()


func _draw() -> void:
	var base := lift()
	var lp := WorldConfig.get_default().level_px
	draw_box(base, Vector2(16, 8), Color("7b7f86"), Color("4c4f55"), 0.5)
	var pivot := base + Vector2(0, -0.5 * lp)
	# 左右の矢印(どちらへ回るか)
	draw_arc(pivot, 13.0, PI * 1.15, PI * 1.45, 8, Color(1, 1, 1, 0.35), 1.0)
	draw_arc(pivot, 13.0, PI * 1.55, PI * 1.85, 8, Color(1, 1, 1, 0.35), 1.0)
	var ang := -PI * 0.5 + tilt * PI * 0.3
	var tip := pivot + Vector2.from_angle(ang) * 12.0
	draw_line(pivot, tip, Color("c9a35a"), 2.5)
	draw_circle(tip, 2.5, Color("e05a4a") if _holder else Color("f0e0c0"))
