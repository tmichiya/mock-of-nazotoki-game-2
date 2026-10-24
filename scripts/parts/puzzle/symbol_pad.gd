@tool
class_name SymbolPad
extends PuzzlePart
## 記号の床。踏むと、つないだ入力台(SymbolCodeLock)にこの記号を1つ入力する。
## 乗り続けても1回だけ。もう一度入力するには、一度降りてから踏み直す。

signal stepped(symbol: int)

## つなぐ入力台
@export var lock: NodePath:
	set(v):
		lock = v
		_lock = null
## この床の記号の番号(入力台の記号のセットの番号)
@export var symbol := 0:
	set(v):
		symbol = v
		queue_redraw()
## 乗っているとみなす半径(px)
@export var radius := 11.0:
	set(v):
		radius = v
		queue_redraw()
@export var color := Color("cfc6ad"):
	set(v):
		color = v
		queue_redraw()
@export var ink_color := Color("2b2622")

var is_down := false
var _lock: SymbolCodeLock
var _glow := 0.0


func _enter_tree() -> void:
	super._enter_tree()
	if not Engine.is_editor_hint():
		add_to_group("symbol_pad")


func get_lock() -> SymbolCodeLock:
	if _lock == null and not lock.is_empty():
		_lock = get_node_or_null(lock) as SymbolCodeLock
	return _lock


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _glow > 0.0:
		_glow = maxf(0.0, _glow - delta * 2.0)
		queue_redraw()
	if not is_authority():
		return
	var down := false
	for p: Player in World.get_players():
		if p.global_position.distance_to(global_position) <= radius and absf(p.height - height) < 0.5 and not p.is_airborne():
			down = true
	if down and not is_down:
		_press()
		sync_state()
	elif down != is_down:
		is_down = down
		sync_state()
		queue_redraw()


func _press() -> void:
	is_down = true
	_glow = 1.0
	stepped.emit(symbol)
	var l := get_lock()
	if l:
		l.input_symbol(symbol)
	queue_redraw()


func get_state() -> Dictionary:
	return { down = is_down }


func apply_state(s: Dictionary) -> void:
	if s.down and not is_down:
		_glow = 1.0
		stepped.emit(symbol)
	is_down = s.down
	queue_redraw()


func _draw() -> void:
	var base := lift()
	var sink := Vector2(0, 1) if is_down else Vector2.ZERO
	var r := Vector2(radius, radius * 0.75)
	var rect := Rect2(base - r + sink, r * 2.0)
	draw_rect(Rect2(rect.position + Vector2(0, 2), rect.size), color.darkened(0.4))
	draw_rect(rect, color.lerp(Color("f2e6a8"), _glow))
	draw_rect(rect, Color(0, 0, 0, 0.55), false, 1.0)
	var s: SymbolSet = get_lock().symbol_set if get_lock() and get_lock().symbol_set else load("res://resources/symbols/symbols_default.tres")
	s.draw_symbol(self, symbol, base + sink, radius * 1.1, ink_color)
