@tool
class_name Door
extends PuzzlePart
## 扉。シグナルを受けて開閉する(open / close / toggle / set_open)。
## 閉じている間は、プレイヤーも物も音の波も通さない。

signal opened
signal closed
signal state_changed(is_open: bool)

## 開いた時に知らせる「○○をクリア」の名前(空なら知らせない)
@export var clear_event: StringName = &""
## 扉の幅(px)
@export var width := 32.0:
	set(v):
		width = v
		_rebuild()
## 縦向き(true なら上下方向に伸びる)
@export var vertical := false:
	set(v):
		vertical = v
		_rebuild()
## 扉の高さ(段)。音の波はこの高さまでの段で止まる
@export var door_levels := 1.0:
	set(v):
		door_levels = v
		queue_redraw()
## 最初から開いている
@export var start_open := false
## 閉じている時に音の波を止める
@export var blocks_sound := true
## 閉じている時に音の波を跳ね返す(false なら吸収)
@export var reflects_sound := false
## 開け閉めにかかる時間(秒)
@export var move_time := 0.35
@export var color := Color("8a6a4a")

var is_open := false
var _anim := 0.0   # 0 = 閉, 1 = 開
var _body: StaticBody2D
var _shape: CollisionShape2D


func _ready() -> void:
	super._ready()
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group("sound_wall")
	is_open = start_open
	_anim = 1.0 if is_open else 0.0
	_apply_collision()


func _segment() -> Array:
	var half := width * 0.5
	if vertical:
		return [Vector2(0, -half), Vector2(0, half)]
	return [Vector2(-half, 0), Vector2(half, 0)]


func _rebuild() -> void:
	queue_redraw()
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	if _body == null:
		_body = StaticBody2D.new()
		_body.collision_layer = Layers.bit(Layers.OBJECT_LAYER)
		_body.collision_mask = 0
		add_child(_body)
		_shape = CollisionShape2D.new()
		_body.add_child(_shape)
	var seg := SegmentShape2D.new()
	var s := _segment()
	seg.a = s[0]
	seg.b = s[1]
	_shape.shape = seg


func _apply_collision() -> void:
	if _shape:
		_shape.set_deferred("disabled", is_open)


# ---------------------------------------------------------------- 受け口

func open() -> void:
	set_open(true)


func close() -> void:
	set_open(false)


func toggle() -> void:
	set_open(not is_open)


func set_open(v: bool) -> void:
	if not is_authority() or v == is_open:
		return
	_apply_open(v)
	sync_state()


func _apply_open(v: bool) -> void:
	is_open = v
	_apply_collision()
	state_changed.emit(v)
	if v:
		opened.emit()
		if is_authority():
			Clears.clear(clear_event)
	else:
		closed.emit()


func get_state() -> Dictionary:
	return { open = is_open }


func apply_state(s: Dictionary) -> void:
	if s.open != is_open:
		_apply_open(s.open)


# ---------------------------------------------------------------- 音の波

func blocks_level(level: int) -> bool:
	return blocks_sound and not is_open and level >= get_level() and level < get_level() + ceili(door_levels)


func intersect(p: Vector2, d: Vector2, max_t: float) -> Dictionary:
	var s := _segment()
	var a: Vector2 = global_transform * s[0]
	var b: Vector2 = global_transform * s[1]
	var hit = Geometry2D.segment_intersects_segment(p, p + d * max_t, a, b)
	if hit == null:
		return { hit = false, t = max_t, normal = Vector2.ZERO, reflect = false }
	var n := (b - a).orthogonal().normalized()
	if n.dot(d) > 0.0:
		n = -n
	return { hit = true, t = p.distance_to(hit), normal = n, reflect = reflects_sound }


# ---------------------------------------------------------------- 見た目

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var goal := 1.0 if is_open else 0.0
	if not is_equal_approx(_anim, goal):
		_anim = move_toward(_anim, goal, delta / maxf(move_time, 0.01))
		queue_redraw()


func _draw() -> void:
	var s := _segment()
	var thick := 6.0
	var size := Vector2(width, thick) if not vertical else Vector2(thick, width)
	var levels := door_levels * (1.0 - _anim)
	var base := lift()
	if levels > 0.02:
		draw_box(base, size, color.lightened(0.15), color.darkened(0.3), levels)
	else:
		draw_rect(Rect2(base - size * 0.5, size), Color(color, 0.35))
	draw_rect(Rect2(base - size * 0.5, size), Color(0, 0, 0, 0.5), false, 1.0)
