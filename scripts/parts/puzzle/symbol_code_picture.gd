@tool
class_name SymbolCodePicture
extends PuzzlePart
## 記号の絵。つないだ入力台(SymbolCodeLock)の答えの記号を、左から順に描く。
## 入力台が答えを変えると(間違えた時など)、絵の記号も変わる。
## 片方にしか見せたくない時は、子に OnlyVisibleTo を置く。

## つなぐ入力台
@export var lock: NodePath:
	set(v):
		lock = v
		_lock = null
		queue_redraw()
## 1列に並べる記号の数(多い時は次の行へ)
@export_range(1, 12) var per_row := 4:
	set(v):
		per_row = v
		queue_redraw()
## 記号1つの大きさ(px)
@export var symbol_size := 12.0:
	set(v):
		symbol_size = v
		queue_redraw()
## 絵の高さ(地面から絵の下端までの段)
@export var stand_levels := 1.0:
	set(v):
		stand_levels = v
		queue_redraw()
@export var frame_color := Color("8a5a35"):
	set(v):
		frame_color = v
		queue_redraw()
@export var canvas_color := Color("f1e8cf"):
	set(v):
		canvas_color = v
		queue_redraw()
@export var ink_color := Color("2b2622"):
	set(v):
		ink_color = v
		queue_redraw()

var _lock: SymbolCodeLock


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var l := get_lock()
	if l:
		l.code_changed.connect(func(_c): queue_redraw())


func get_lock() -> SymbolCodeLock:
	if _lock == null and not lock.is_empty() and is_inside_tree():
		_lock = get_node_or_null(lock) as SymbolCodeLock
	return _lock


func _draw() -> void:
	var l := get_lock()
	var code := PackedInt32Array()
	var n := 3
	if l:
		n = l.code_length
		code = l.code
	var cols := mini(n, per_row)
	var rows := ceili(float(n) / per_row)
	var pad := 4.0
	var cell := symbol_size + pad
	var canvas := Vector2(cols * cell + pad, rows * cell + pad)
	var base := lift()
	var lp := WorldConfig.get_default().level_px
	var bottom := base + Vector2(0, -stand_levels * lp)
	# 画架(3本脚)
	var leg := Color("6b5440")
	draw_line(base + Vector2(-canvas.x * 0.35, 0), bottom + Vector2(-2, -canvas.y * 0.5), leg, 2.0)
	draw_line(base + Vector2(canvas.x * 0.35, 0), bottom + Vector2(2, -canvas.y * 0.5), leg, 2.0)
	draw_line(base + Vector2(0, -2), bottom + Vector2(0, -canvas.y * 0.5), leg.darkened(0.2), 1.5)
	# 額縁と絵
	var top_left := bottom + Vector2(-canvas.x * 0.5, -canvas.y)
	draw_rect(Rect2(top_left - Vector2(2, 2), canvas + Vector2(4, 4)), frame_color)
	draw_rect(Rect2(top_left, canvas), canvas_color)
	draw_rect(Rect2(top_left - Vector2(2, 2), canvas + Vector2(4, 4)), Color(0, 0, 0, 0.6), false, 1.0)
	var s: SymbolSet = l.symbol_set if l and l.symbol_set else load("res://resources/symbols/symbols_default.tres")
	for i in range(n):
		var c := top_left + Vector2(pad + symbol_size * 0.5 + (i % per_row) * cell, pad + symbol_size * 0.5 + (i / per_row) * cell)
		if i < code.size():
			s.draw_symbol(self, code[i], c, symbol_size, ink_color)
		else:
			draw_string(ThemeDB.fallback_font, c + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ink_color, 0.4))
