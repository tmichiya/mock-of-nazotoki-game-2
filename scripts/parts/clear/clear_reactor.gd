@tool
class_name ClearReactor
extends Node2D
## 「○○をクリア」を購読して動く部品。障害物・道・扉などを、クリアで出す・消す・動かす・落とす・呼ぶ。
## ・targets が空なら、この部品自身(と子)が動く。見た目や当たり判定は子に置く(子が無ければ仮の箱)
## ・targets に別のノード(地形以外なら何でも)を並べると、それらが動く
## ・CALL は targets の method を呼ぶ(例: 扉の open)
## 判定は両方の端末で同じ(クリアは Clears が同期している)ので、この部品は状態を送らない。

signal activated
signal deactivated

enum Mode { ALL, ANY }
enum Action { APPEAR, DISAPPEAR, MOVE, FALL, CALL }

## 購読するクリアの名前
@export var listen: Array[StringName] = []
## ALL = 全部クリアしたら / ANY = どれか1つ
@export var mode := Mode.ALL
## する事
@export var action := Action.DISAPPEAR:
	set(v):
		action = v
		queue_redraw()
## 動かす相手(空ならこの部品自身)
@export var targets: Array[NodePath] = []
## MOVE の移動量(px)
@export var move_offset := Vector2(0, -32)
## FALL で落ちる段数
@export var fall_levels := 2.0
## 変化にかかる時間(秒)
@export var duration := 0.6
## CALL で呼ぶメソッド名(引数なし)
@export var method := "open"
## 取り消された時(やり直し)に元に戻す。CALL の時は undo_method を呼ぶ
@export var revert_on_reset := true
@export var undo_method := "close"
## 消えた・落ちた後は当たり判定も無くす
@export var toggle_collision := true
## 子が無い時に描く仮の箱の大きさ
@export var placeholder_size := Vector2(24, 16)

var active := false
var _t := 0.0          # 0 = 元のまま, 1 = 変化しきった
var _start := {}       # 相手 -> 元の位置


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for n in _target_nodes():
		if n is Node2D:
			_start[n] = n.position
	if action == Action.APPEAR:
		_set_shown(false)
	Clears.cleared.connect(_on_change)
	Clears.reset.connect(_on_change)
	_evaluate.call_deferred()


func _target_nodes() -> Array:
	if targets.is_empty():
		return [self]
	var out := []
	for p in targets:
		var n := get_node_or_null(p)
		if n:
			out.append(n)
	return out


func _on_change(name: StringName) -> void:
	if name in listen:
		_evaluate()


func is_satisfied() -> bool:
	if listen.is_empty():
		return false
	var n := Clears.count_cleared(listen)
	return n == listen.size() if mode == Mode.ALL else n > 0


func _evaluate() -> void:
	var now := is_satisfied()
	if now == active:
		return
	if not now and not revert_on_reset:
		return
	active = now
	if action == Action.CALL:
		for n in _target_nodes():
			var m := method if now else undo_method
			if m != "" and n.has_method(m):
				n.call(m)
	elif now and action == Action.APPEAR:
		_set_shown(true)
	if now:
		activated.emit()
	else:
		deactivated.emit()
		if action == Action.DISAPPEAR or action == Action.FALL:
			_set_shown(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or action == Action.CALL:
		return
	var goal := 1.0 if active else 0.0
	if is_equal_approx(_t, goal):
		return
	_t = move_toward(_t, goal, delta / maxf(duration, 0.01))
	var k := _t * _t * (3.0 - 2.0 * _t)
	for n in _target_nodes():
		match action:
			Action.MOVE:
				if n is Node2D and _start.has(n):
					n.position = _start[n] + move_offset * k
			Action.FALL:
				if n is Node2D and _start.has(n):
					n.position = _start[n] + Vector2(0, fall_levels * WorldConfig.get_default().level_px * _t * _t)
					n.modulate.a = 1.0 - _t
			Action.DISAPPEAR:
				if n is CanvasItem:
					n.modulate.a = 1.0 - k
			Action.APPEAR:
				if n is CanvasItem:
					n.modulate.a = k
	if _t >= 1.0 and active and (action == Action.DISAPPEAR or action == Action.FALL):
		_set_shown(false)
	if _t <= 0.0 and not active and action == Action.APPEAR:
		_set_shown(false)
	queue_redraw()


func _set_shown(v: bool) -> void:
	for n in _target_nodes():
		if n is CanvasItem:
			n.visible = v
			if v:
				n.modulate.a = 1.0 if action != Action.APPEAR or active else 0.0
		if toggle_collision:
			_set_collision(n, v)


func _set_collision(n: Node, on: bool) -> void:
	if n is CollisionShape2D or n is CollisionPolygon2D:
		n.set_deferred("disabled", not on)
	for c in n.get_children():
		_set_collision(c, on)


func _draw() -> void:
	if not targets.is_empty():
		return
	for c in get_children():
		if c is CanvasItem:
			return
	var lp := WorldConfig.get_default().level_px
	var col := Color("c7b28a")
	if Engine.is_editor_hint() and action == Action.APPEAR:
		col.a = 0.4
	var size := placeholder_size
	var top := Rect2(Vector2(-size.x * 0.5, -size.y * 0.5 - lp), size)
	draw_rect(Rect2(top.position + Vector2(0, size.y), Vector2(size.x, lp)), col.darkened(0.3))
	draw_rect(top, col)
	draw_rect(top, Color(0, 0, 0, 0.6), false, 1.0)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -size.y - lp - 2), ",".join(listen.map(func(x): return str(x))), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
