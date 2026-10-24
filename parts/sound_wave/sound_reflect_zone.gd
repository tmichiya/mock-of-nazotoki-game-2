@tool
class_name SoundReflectZone
extends Node2D
## 範囲の中にある「地形の崖」が音の波を跳ね返すかどうかを上書きする部品。
## (地形全体の初期値は Terrain の cliffs_reflect)

## 範囲(この部品からの相対位置の多角形)
@export var polygon := PackedVector2Array([Vector2(-32, -24), Vector2(32, -24), Vector2(32, 24), Vector2(-32, 24)]):
	set(v):
		polygon = v
		queue_redraw()
## 範囲の中の崖が跳ね返すか
@export var reflect := false:
	set(v):
		reflect = v
		queue_redraw()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group("sound_reflect_zone")


func contains_point(global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(global_transform.affine_inverse() * global_point, polygon)


func _draw() -> void:
	if Engine.is_editor_hint() and polygon.size() > 2:
		var c := Color(0.4, 1, 0.6, 0.18) if reflect else Color(1, 0.4, 0.4, 0.18)
		draw_colored_polygon(polygon, c)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color(c, 0.8), 1.0)
