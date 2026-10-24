@tool
class_name SpawnPoint
extends Marker2D
## プレイヤーが出る場所。index = 1(ホスト/1人目)か 2(参加した人/2人目)。
## 謎のやり直し(ResetPoint)でもここに戻す。

@export_range(1, 2) var index := 1:
	set(v):
		index = v
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("spawn_point")


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 5, Color(1, 1, 1, 0.4))
		draw_string(ThemeDB.fallback_font, Vector2(-3, 4), str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.BLACK)
