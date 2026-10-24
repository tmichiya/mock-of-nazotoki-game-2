@tool
class_name SoundShard
extends PuzzlePart
## 音のかけら。触れると拾える。二人で共有の数(World の共有値 "shards")として数える。
## hidden_at_start をオンにして appear() をつなぐと、謎の成功シグナルで現れる。

signal collected
signal appeared

## 拾った時に知らせる「○○をクリア」の名前(空なら知らせない)
@export var clear_event: StringName = &""
## 最初は隠しておく(appear() で現れる)
@export var hidden_at_start := false
## 拾える距離(px)
@export var pickup_radius := 10.0
## 数える名前(普通は "shards")
@export var counter_key := "shards"
@export var color := Color("9be0ff")

var taken := false
var shown := true


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	shown = not hidden_at_start
	visible = shown


func appear() -> void:
	if not is_authority() or shown:
		return
	shown = true
	visible = true
	appeared.emit()
	sync_state()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority() or taken or not shown:
		return
	for p: Player in World.get_players():
		if p.global_position.distance_to(global_position) <= pickup_radius and absf(p.height - height) < 0.6:
			_take()
			return


func _take() -> void:
	taken = true
	visible = false
	World.add_shared(counter_key, 1)
	collected.emit()
	Clears.clear(clear_event)
	sync_state()


func get_state() -> Dictionary:
	return { taken = taken, shown = shown }


func apply_state(s: Dictionary) -> void:
	if s.shown and not shown:
		appeared.emit()
	shown = s.shown
	if s.taken and not taken:
		collected.emit()
	taken = s.taken
	visible = shown and not taken


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var base := lift()
	var c := base + Vector2(0, -10 - sin(t * 2.5) * 2.0)
	draw_circle(base, 3.0, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(0, 6), c + Vector2(-4, 0)])
	var col := color
	if Engine.is_editor_hint() and hidden_at_start:
		col.a = 0.4
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color.WHITE, 1.0)
