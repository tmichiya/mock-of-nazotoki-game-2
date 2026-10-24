@tool
class_name Trumpet
extends PuzzlePart
## ラッパ。手を伸ばして(LB/RB)つかんで持つと、持っている人の声の波が扇形になり、
## 向いている方向にだけ遠くまで届く。

signal picked_up
signal put_down

## 扇の広がり(度、片側)
@export_range(5, 90) var spread_deg := 25.0
## 声の波の大きさの倍率(遠くまで届く)
@export var size_scale := 2.2
## つかめる距離(px)
@export var grab_radius := 10.0
## 持っている人の声を、波が届いた時に遅れて聞こえるようにする(遠くまで届く代わりに、届くまで時間がかかる)
@export var delay_voice := true
@export var color := Color("e0b84a")

var _holder: Array = []
var _holder_index := 0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group("props")
	process_physics_priority = 20


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_authority():
		_follow_remote()
		return
	if not _holder.is_empty():
		var p: Player = _holder[0]
		if not is_instance_valid(p) or not is_reaching(p, _holder[1]):
			if is_instance_valid(p):
				p.held_objects[_holder[1]] = null
				p.voice_modifier = {}
			_holder = []
			_holder_index = 0
			put_down.emit()
			sync_state()
	if _holder.is_empty():
		var g := find_grabber(global_position, grab_radius)
		if not g.is_empty():
			_holder = g
			g[0].held_objects[g[1]] = self
			_holder_index = g[0].player_index
			picked_up.emit()
			sync_state()
	if not _holder.is_empty():
		var p: Player = _holder[0]
		global_position = p.global_position + p.facing * 8.0
		height = p.height
		p.voice_modifier = { dir = p.facing, spread = deg_to_rad(spread_deg), size_scale = size_scale, delay_voice = delay_voice }
	else:
		_update_height()
	queue_redraw()


# 持っている人の声の波の形は、声を出す端末(持っている人の端末)で決まるので、そちらにも設定する
func _follow_remote() -> void:
	if _holder_index > 0:
		var p := World.get_player_by_index(_holder_index) as Player
		if p:
			global_position = p.global_position + p.facing * 8.0
			height = p.height
			if p.is_local:
				p.voice_modifier = { dir = p.facing, spread = deg_to_rad(spread_deg), size_scale = size_scale, delay_voice = delay_voice }
	queue_redraw()


func get_state() -> Dictionary:
	return { holder = _holder_index, pos = global_position }


func apply_state(s: Dictionary) -> void:
	if s.holder == 0 and _holder_index > 0:
		var p := World.get_player_by_index(_holder_index) as Player
		if p:
			p.voice_modifier = {}
	_holder_index = s.holder
	if _holder_index == 0:
		global_position = s.pos
		_update_height()


func _draw() -> void:
	var base := lift(0.6 if _holder_index > 0 else 0.1)
	var dir := Vector2.RIGHT
	if _holder_index > 0 and not Engine.is_editor_hint():
		var p := World.get_player_by_index(_holder_index) as Player
		if p:
			dir = p.facing
	var side := dir.orthogonal()
	var bell := base + dir * 7.0
	draw_line(base - dir * 5.0, bell, color.darkened(0.2), 2.0)
	draw_colored_polygon(PackedVector2Array([bell, bell + dir * 4.0 + side * 4.0, bell + dir * 4.0 - side * 4.0]), color)
