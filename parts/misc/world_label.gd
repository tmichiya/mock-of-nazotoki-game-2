@tool
class_name WorldLabel
extends Node2D
## 世界の中に置く説明の札(部品カタログ用。ゲームには使わなくてよい)。

@export_multiline var text := "説明":
	set(v):
		text = v
		queue_redraw()
@export var font_size := 9:
	set(v):
		font_size = v
		queue_redraw()
@export var color := Color.WHITE
@export var background := Color(0, 0, 0, 0.55)


func _ready() -> void:
	z_index = 90
	z_as_relative = false


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var lines := text.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var h := lines.size() * (font_size + 2) + 4
	draw_rect(Rect2(Vector2(-2, -font_size - 2), Vector2(w + 4, h)), background)
	for i in range(lines.size()):
		draw_string(font, Vector2(0, i * (font_size + 2)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
