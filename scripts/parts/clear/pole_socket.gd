@tool
class_name PoleSocket
extends PuzzlePart
## 長い棒をはめる型(ゴール)。棒の真ん中が型の近くに来て、向きが合ったら、棒がはまって動かなくなりクリア。
## 置いた位置が型の真ん中。型の向きは angle_deg(棒は前後どちら向きでもはまる)。

signal socketed

## 知らせるクリアの名前
@export var clear_event: StringName = &""
## 型の長さ(px。見た目用。棒の長さに合わせる)
@export var length := 72.0:
	set(v):
		length = v
		queue_redraw()
## 型の向き(度)
@export var angle_deg := 0.0:
	set(v):
		angle_deg = v
		queue_redraw()
## はまる距離(棒の真ん中と型の真ん中、px)
@export var snap_distance := 10.0
## はまる向きのずれ(度)
@export var snap_angle_deg := 15.0
## はまったら棒を握っている手を離させる
@export var release_holders := true
@export var color := Color("6f5a3a")

var done := false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or done or not is_authority():
		return
	for o in get_tree().get_nodes_in_group("props"):
		if not (o is LongPole) or o.locked:
			continue
		if o.global_position.distance_to(global_position) > snap_distance:
			continue
		var target := deg_to_rad(angle_deg)
		var diff := absf(angle_difference(o.angle, target))
		diff = minf(diff, absf(angle_difference(o.angle, target + PI)))
		if diff > deg_to_rad(snap_angle_deg):
			continue
		var a := target if absf(angle_difference(o.angle, target)) <= PI * 0.5 else target + PI
		o.lock_at(global_position, a, release_holders)
		done = true
		socketed.emit()
		Clears.clear(clear_event)
		sync_state()
		queue_redraw()
		return


func get_state() -> Dictionary:
	return { done = done }


func apply_state(s: Dictionary) -> void:
	if s.done and not done:
		done = true
		socketed.emit()
		queue_redraw()


func _draw() -> void:
	var base := lift()
	var u := Vector2.from_angle(deg_to_rad(angle_deg)) * length * 0.5
	var side := u.orthogonal().normalized() * 4.0
	var poly := PackedVector2Array([base - u - side, base + u - side, base + u + side, base - u + side])
	draw_colored_polygon(poly, Color(color, 0.9 if not done else 0.5))
	poly.append(poly[0])
	draw_polyline(poly, color.darkened(0.4), 1.0)
	if not done:
		# はめる向きの目印
		draw_line(base - u * 0.9, base + u * 0.9, Color(1, 1, 1, 0.25), 1.0)
