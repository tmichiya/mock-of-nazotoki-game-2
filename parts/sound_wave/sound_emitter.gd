@tool
class_name SoundEmitter
extends Node2D
## 音源の部品。emit() を呼ぶ(シグナルをつなぐ)か、一定間隔で、音の波を出す。
## 鐘・ボール・置き物の音など。出すのはホストの端末(相手の端末にも送られる)。

signal emitted

## 音源の名前(受け取り側のシグナルで「どの音源から」に入る)。空ならノード名
@export var source_name := ""
## 波の形(parts/sound_wave/shapes/ から選ぶ。種類もここで決まる)
@export var shape: WaveShape = preload("res://parts/sound_wave/shapes/generic.tres")
## 大きさ(1が普通。届く距離と強さ)
@export_range(0.05, 10.0, 0.05) var size := 1.0
## 色(透明なら形の色)
@export var color := Color(0, 0, 0, 0)
## AUTO = 置いた場所の地形の段 / FIXED = fixed_level
@export var level_mode := WaveReceiver.LevelMode.AUTO
@export var fixed_level := 0
## 向き(度。0=右、90=下)と広がり(度、片側)。広がり180で全方向
@export_range(-180, 180) var direction_deg := 0.0:
	set(v):
		direction_deg = v
		queue_redraw()
@export_range(1, 180) var spread_deg := 180.0:
	set(v):
		spread_deg = v
		queue_redraw()
## 何秒ごとに自動で出すか(0で出さない)
@export var auto_interval := 0.0
## 始まった時に1回出す
@export var emit_on_ready := false

var _timer := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if emit_on_ready:
		emit.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or auto_interval <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = auto_interval
		emit()


func get_source_id() -> String:
	return source_name if source_name != "" else str(name)


func get_level() -> int:
	if level_mode == WaveReceiver.LevelMode.FIXED:
		return fixed_level
	var p := get_parent()
	if p and "height" in p:
		return roundi(p.height)
	return World.level_at(global_position)


## 波を出す(ホストだけが実際に出す)
func emit(size_scale: float = 1.0) -> void:
	if not Net.is_host():
		return
	var p := {
		origin = global_position, level = get_level(), size = size * size_scale,
		shape = shape.resource_path, source = get_source_id(),
	}
	if color.a > 0.0:
		p.color = color
	if spread_deg < 179.9:
		p.dir = Vector2.from_angle(deg_to_rad(direction_deg))
		p.spread = deg_to_rad(spread_deg)
	Waves.emit(p)
	emitted.emit()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 4, Color(1, 0.9, 0.4, 0.7))
	if spread_deg < 179.9:
		var a := deg_to_rad(direction_deg)
		var s := deg_to_rad(spread_deg)
		draw_line(Vector2.ZERO, Vector2.from_angle(a - s) * 20, Color(1, 0.9, 0.4, 0.7))
		draw_line(Vector2.ZERO, Vector2.from_angle(a + s) * 20, Color(1, 0.9, 0.4, 0.7))
