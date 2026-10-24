@tool
class_name FluffGoal
extends PuzzlePart
## 綿毛を運ぶゴール(花など)。決めた物(既定は綿毛)が、範囲の中に一定時間とどまったらクリア。

signal reached
## 何個入っているか
signal count_changed(count: int)

## 知らせるクリアの名前
@export var clear_event: StringName = &""
## ゴールの半径(px)
@export var radius := 14.0:
	set(v):
		radius = v
		queue_redraw()
## 何個そろえばクリアか
@export var required := 1
## 範囲にとどまる時間(秒)
@export var hold_time := 0.5
## 数える物のグループ(既定は綿毛。groups にこの名前を入れた物なら何でも)
@export var target_group: StringName = &"fluff"
## クリアしたら、入った物を消す(吸い込まれたように見せる)
@export var consume := false
@export var color := Color("f2a7c3")

var done := false
var _inside_time := {}


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or done or not is_authority():
		return
	var n := 0
	for o in get_tree().get_nodes_in_group(target_group):
		if not (o is Node2D):
			continue
		var oh: float = o.get("height") if "height" in o else height
		if o.global_position.distance_to(global_position) <= radius and absf(oh - height) < 0.6:
			_inside_time[o] = _inside_time.get(o, 0.0) + delta
			if _inside_time[o] >= hold_time:
				n += 1
		else:
			_inside_time.erase(o)
	count_changed.emit(n)
	if n >= required:
		_finish()


func _finish() -> void:
	done = true
	if consume:
		for o in _inside_time.keys():
			if is_instance_valid(o):
				o.queue_free()
	reached.emit()
	Clears.clear(clear_event)
	sync_state()
	queue_redraw()


func get_state() -> Dictionary:
	return { done = done }


func apply_state(s: Dictionary) -> void:
	if s.done and not done:
		done = true
		reached.emit()
		queue_redraw()


func reset() -> void:
	if not is_authority():
		return
	done = false
	_inside_time.clear()
	Clears.reset_clear(clear_event)
	sync_state()
	queue_redraw()


func _draw() -> void:
	var base := lift()
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(base + Vector2(cos(a) * radius, sin(a) * radius * 0.7))
	draw_colored_polygon(pts, Color(color, 0.35 if not done else 0.8))
	pts.append(pts[0])
	draw_polyline(pts, color.darkened(0.3), 1.5)
	# 花びら
	for i in range(5):
		var a := TAU * i / 5.0
		draw_circle(base + Vector2(cos(a), sin(a) * 0.7) * 5.0, 3.0, color.lightened(0.3) if done else color)
	draw_circle(base, 2.5, Color("f7e27a"))
