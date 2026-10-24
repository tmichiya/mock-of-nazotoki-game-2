@tool
class_name VoiceEater
extends PuzzlePart
## 声を食べる動物。届いた音の波を食べ、溜める時間の後に、自分が向いている方向へ吐き出す。
## どの方向から届いても、吐き出す向きは変わらない。向きはシグナル(レバーなど)で変えられる。
## 吐き出した声は、VCでも「声の波」として扱われ、届いた相手にはその声が聞こえる。
## 動物から動物へリレーできる。同じ声が同じ動物を二度通らないので、食べ合いで無限に回らない。

signal ate(source_id: String)
signal spat
signal direction_changed(index: int)

enum SpitShape { STRAIGHT, FAN }

## 向き(8方向の番号。0=右, 1=右下, 2=下, 3=左下, 4=左, 5=左上, 6=上, 7=右上)
@export_range(0, 7) var direction := 0:
	set(v):
		direction = posmod(v, 8)
		queue_redraw()
## レバーの位置などの番号を向きに読み替える表(空なら番号=向き)。例: [0, 2, 4] なら 0→右, 1→下, 2→左
@export var direction_map := PackedInt32Array()
## 吐き出す形:まっすぐ / 扇形
@export var spit_shape := SpitShape.STRAIGHT
## まっすぐの時の幅(度、片側)
@export_range(1, 30) var straight_spread_deg := 4.0
## 扇形の時の広がり(度、片側)
@export_range(5, 179) var fan_spread_deg := 40.0
## 食べてから吐き出すまでの時間(秒)。声が遅れて届く
@export var hold_time := 0.6
## 吐き出す波の大きさの倍率(食べた波の強さに掛ける)
@export var size_multiplier := 1.5
## 吐き出す波の大きさの最小
@export var min_spit_size := 0.8
## まっすぐ吐く時は遠くまで届くように、さらに距離を伸ばす倍率
@export var straight_reach_multiplier := 1.6
## 食べる波の種類(空なら全部)
@export var eat_kinds: Array[StringName] = []
## 食べる範囲の半径(px)
@export var mouth_radius := 12.0
## リレーの回数の上限(同じ声が通れる動物の数)
@export var max_relays := 8
@export var body_color := Color("b98ad6")

var _queue: Array = []   # [吐く時刻, 波の情報]
var _eaten := {}         # 食べた波のID
var _receiver: WaveReceiver


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_receiver = WaveReceiver.new()
	_receiver.radius = mouth_radius
	_receiver.accept_kinds = eat_kinds
	_receiver.ignore_source = get_source_id()
	_receiver.level_mode = WaveReceiver.LevelMode.FIXED
	_receiver.fixed_level = get_level()
	add_child(_receiver)
	_receiver.wave_received_info.connect(_on_wave)


func get_source_id() -> String:
	return "animal:" + str(name)


func _on_wave(info: Dictionary) -> void:
	if not is_authority() or info.is_global:
		return
	if _eaten.has(info.wave_id):
		return
	var payload: Dictionary = info.payload
	var hops: Array = payload.get("hops", [])
	if get_source_id() in hops or hops.size() >= max_relays:
		return
	_eaten[info.wave_id] = true
	_queue.append([Waves.clock + hold_time, info])
	ate.emit(str(info.source))
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	while not _queue.is_empty() and Waves.clock >= _queue[0][0]:
		var item: Array = _queue.pop_front()
		_spit(item[1])
		queue_redraw()


func _spit(info: Dictionary) -> void:
	var payload: Dictionary = info.payload.duplicate()
	var hops: Array = payload.get("hops", []).duplicate()
	hops.append(get_source_id())
	payload.hops = hops
	if payload.has("voice"):
		payload.relay = get_source_id()
	var shape_path := "res://resources/wave_shapes/voice.tres" if payload.has("voice") else "res://resources/wave_shapes/generic.tres"
	var dir := PlayerInput.dir8(direction)
	var spread := deg_to_rad(straight_spread_deg if spit_shape == SpitShape.STRAIGHT else fan_spread_deg)
	var size: float = maxf(min_spit_size, float(info.strength) * size_multiplier)
	var p := {
		origin = global_position + dir * (mouth_radius + 2.0), level = get_level(), size = size,
		shape = shape_path, source = get_source_id(), payload = payload, dir = dir, spread = spread,
		pitch = info.pitch, color = body_color.lightened(0.4),
	}
	if spit_shape == SpitShape.STRAIGHT:
		var sh: WaveShape = load(shape_path)
		p.reach = sh.speed * sh.lifetime * size * straight_reach_multiplier
	Waves.emit(p)
	spat.emit()


# ---------------------------------------------------------------- 向き

## 向きを番号で決める(direction_map があれば読み替える)。レバーの position_changed をつなぐ
func set_direction_index(i: int) -> void:
	var d := i
	if not direction_map.is_empty():
		d = direction_map[clampi(i, 0, direction_map.size() - 1)]
	_set_direction(d)


func turn_clockwise() -> void:
	_set_direction(direction + 1)


func turn_counterclockwise() -> void:
	_set_direction(direction - 1)


func _set_direction(d: int) -> void:
	if Engine.is_editor_hint():
		direction = d
		return
	if not is_authority():
		return
	direction = d
	direction_changed.emit(direction)
	sync_state()


func get_state() -> Dictionary:
	return { direction = direction }


func apply_state(s: Dictionary) -> void:
	if s.direction != direction:
		direction = s.direction
		direction_changed.emit(direction)


func _draw() -> void:
	var base := lift()
	var body := base + Vector2(0, -8)
	var col := body_color
	if not _queue.is_empty():
		col = col.lightened(0.25)
	draw_circle(base, 7.0, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * i / 18.0
		pts.append(body + Vector2(cos(a) * 9.0, sin(a) * 7.0))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.6), 1.0)
	# 口(向き)
	var d := PlayerInput.dir8(direction)
	var mouth := body + Vector2(d.x * 9.0, d.y * 7.0)
	draw_line(mouth, mouth + d * 7.0, Color("402030"), 3.0)
	var side := d.orthogonal() * 3.0
	draw_colored_polygon(PackedVector2Array([mouth + d * 10.0, mouth + d * 5.0 + side, mouth + d * 5.0 - side]), Color("402030"))
	# 溜めている声の数
	for i in range(mini(_queue.size(), 5)):
		draw_circle(body + Vector2(-6 + i * 3, -9), 1.2, Color.WHITE)
