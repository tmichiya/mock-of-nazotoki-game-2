@tool
class_name SymbolSign
extends PuzzlePart
## 記号の看板。SymbolSet から番号で記号を選んで並べて表示する。
## 片方にしか見せたくない時は、子に OnlyVisibleTo を置く。

signal symbols_changed(symbols: PackedInt32Array)

## 記号のセット(空なら res://resources/symbols/symbols_default.tres)
@export var symbol_set: SymbolSet:
	set(v):
		symbol_set = v
		queue_redraw()
## 表示する記号の番号(左から順に並ぶ)
@export var symbols := PackedInt32Array([0]):
	set(v):
		symbols = v
		queue_redraw()
## 記号1つの大きさ(px)
@export var symbol_size := 12.0:
	set(v):
		symbol_size = v
		queue_redraw()
## 看板の板の高さ(地面からの段)
@export var board_levels := 1.2:
	set(v):
		board_levels = v
		queue_redraw()
@export var board_color := Color("e9dfc4"):
	set(v):
		board_color = v
		queue_redraw()
@export var ink_color := Color("2b2622"):
	set(v):
		ink_color = v
		queue_redraw()


func _get_set() -> SymbolSet:
	if symbol_set == null:
		symbol_set = load("res://resources/symbols/symbols_default.tres")
	return symbol_set


## 1つ目の記号を変える
func set_symbol(index: int) -> void:
	var s := symbols.duplicate()
	if s.is_empty():
		s.append(index)
	else:
		s[0] = index
	set_symbols(s)


## 1つ目の記号を次の番号にする
func next_symbol() -> void:
	set_symbol((symbols[0] + 1) % maxi(_get_set().count(), 1) if not symbols.is_empty() else 0)


func set_symbols(s: PackedInt32Array) -> void:
	if Engine.is_editor_hint():
		symbols = s
		return
	if not is_authority():
		return
	symbols = s
	symbols_changed.emit(s)
	sync_state()


func get_state() -> Dictionary:
	return { symbols = symbols }


func apply_state(st: Dictionary) -> void:
	if st.symbols != symbols:
		symbols = st.symbols
		symbols_changed.emit(symbols)


func _draw() -> void:
	var n := maxi(symbols.size(), 1)
	var pad := 3.0
	var board := Vector2(n * (symbol_size + pad) + pad, symbol_size + pad * 2)
	var base := lift()
	# 支柱
	var post_h := board_levels * WorldConfig.get_default().level_px
	draw_line(base, base + Vector2(0, -post_h), Color("6b5440"), 2.0)
	var top_left := base + Vector2(-board.x * 0.5, -post_h - board.y)
	draw_rect(Rect2(top_left, board), board_color)
	draw_rect(Rect2(top_left, board), Color(0, 0, 0, 0.6), false, 1.0)
	for i in range(symbols.size()):
		var c := top_left + Vector2(pad + symbol_size * 0.5 + i * (symbol_size + pad), board.y * 0.5)
		_get_set().draw_symbol(self, symbols[i], c, symbol_size, ink_color)
