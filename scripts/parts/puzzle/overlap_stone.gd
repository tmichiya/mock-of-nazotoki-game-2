@tool
class_name OverlapStone
extends PuzzlePart
## 重なる点の石。二つの(別々の音源の)波が、許容時間内に同時に届いた時だけ光る。

signal lit
signal dimmed

## 同時とみなす時間の幅(秒)
@export var window := 0.12
## 光っている時間(秒)
@export var glow_time := 2.0
## 受け取る範囲の半径(px)
@export var radius := 8.0
## 反応する波の種類(空なら全部)
@export var hear_kinds: Array[StringName] = []
## この強さ未満の波は数えない
@export var min_strength := 0.05
@export var color := Color("a8a39a")
@export var glow_color := Color("fff2a8")

var glowing := false
var _left := 0.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var r := WaveReceiver.new()
	r.radius = radius
	r.overlap_window = window
	r.accept_kinds = hear_kinds
	r.min_strength = min_strength
	r.level_mode = WaveReceiver.LevelMode.FIXED
	r.fixed_level = get_level()
	add_child(r)
	r.overlapped.connect(_on_overlap)


func _on_overlap() -> void:
	if not is_authority():
		return
	_left = glow_time
	if not glowing:
		glowing = true
		lit.emit()
		sync_state()
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority() or not glowing:
		return
	_left -= delta
	if _left <= 0.0:
		glowing = false
		dimmed.emit()
		sync_state()
		queue_redraw()


func get_state() -> Dictionary:
	return { glowing = glowing }


func apply_state(s: Dictionary) -> void:
	if s.glowing != glowing:
		glowing = s.glowing
		if glowing:
			lit.emit()
		else:
			dimmed.emit()
		queue_redraw()


func _draw() -> void:
	var base := lift()
	if glowing:
		draw_circle(base + Vector2(0, -5), 13.0, Color(glow_color, 0.3))
	draw_box(base, Vector2(14, 10), glow_color if glowing else color, (glow_color if glowing else color).darkened(0.35), 0.7)
