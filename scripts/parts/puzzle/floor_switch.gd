@tool
class_name FloorSwitch
extends PuzzlePart
## 踏むスイッチ。乗っている間だけオン(latch で押したままにもできる)。
## 複数のスイッチの同時押しは SwitchGroup で判定する。

signal pressed
signal released
signal state_changed(is_on: bool)

## 押された時に知らせる「○○をクリア」の名前(空なら知らせない)
@export var clear_event: StringName = &""
## 乗っているとみなす半径(px)
@export var radius := 10.0:
	set(v):
		radius = v
		queue_redraw()
## プレイヤーで押せる
@export var by_players := true
## 物(綿毛・棒・瓶など group "props" の物)で押せる
@export var by_props := true
## 何人(何個)乗るとオンになるか
@export var required_count := 1
## 一度押したら離れてもオンのまま(reset() で戻す)
@export var latch := false
@export var color_off := Color("b55d4c")
@export var color_on := Color("e8d36a")

var is_on := false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority():
		return
	var n := count_on_top()
	var on := n >= required_count
	if latch and is_on:
		on = true
	if on != is_on:
		_apply_on(on)
		sync_state()


func count_on_top() -> int:
	var n := 0
	if by_players:
		for p: Player in World.get_players():
			if _on_me(p.global_position, p.height) and not p.is_airborne():
				n += 1
	if by_props:
		for o in get_tree().get_nodes_in_group("props"):
			if o is Node2D and _on_me(o.global_position, o.get("height") if "height" in o else height):
				n += 1
	return n


func _on_me(pos: Vector2, h: float) -> bool:
	return pos.distance_to(global_position) <= radius and absf(h - height) < 0.5


func _apply_on(v: bool) -> void:
	is_on = v
	queue_redraw()
	state_changed.emit(v)
	if v:
		pressed.emit()
		if is_authority():
			Clears.clear(clear_event)
	else:
		released.emit()


## 押したままのスイッチを戻す
func reset() -> void:
	if is_authority() and is_on:
		_apply_on(false)
		sync_state()


func get_state() -> Dictionary:
	return { on = is_on }


func apply_state(s: Dictionary) -> void:
	if s.on != is_on:
		_apply_on(s.on)


func _draw() -> void:
	var base := lift()
	var r := Vector2(radius, radius * 0.7)
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(base + Vector2(cos(a) * r.x, sin(a) * r.y + (0 if is_on else -2)))
	draw_colored_polygon(pts, color_on if is_on else color_off)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.6), 1.0)
