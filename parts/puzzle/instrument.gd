@tool
class_name Instrument
extends PuzzlePart
## ゲーム内の楽器(瓶笛など)。歌えない人向け。
## 近くで楽器ボタン(X / キーボード R)を押すと、決まった高さの音の波を出す。鳥に聴かせられる。
## 手を伸ばして(LB/RB)つかむと持ち運べる。

signal played(midi: float)

## 音の高さ(MIDI の音番号。60 = 真ん中のド)
@export var note := 60.0:
	set(v):
		note = v
		queue_redraw()
## 鳴らせる距離(px)
@export var play_radius := 16.0
## 波の大きさ
@export var size := 1.0
## 連続で鳴らせる間隔(秒)
@export var cooldown := 0.4
## 持ち運べる
@export var carryable := true
@export var shape: WaveShape = preload("res://parts/sound_wave/shapes/instrument.tres")
@export var color := Color("7fb7c9")

var _holder: Array = []
var _cool := 0.0
var _prev := {}
var _synth: ToneSynth


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group("props")
	process_physics_priority = 20
	_synth = ToneSynth.new()
	add_child(_synth)
	Waves.wave_emitted.connect(func(p):
		if str(p.source) == _source():
			_synth.play_note(float(p.pitch), 0.5))


func _source() -> String:
	return "instrument:" + str(name)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority():
		return
	_cool -= delta
	# 持ち運び
	if carryable:
		if not _holder.is_empty():
			var p: Player = _holder[0]
			if not is_instance_valid(p) or not is_reaching(p, _holder[1]):
				if is_instance_valid(p):
					p.held_objects[_holder[1]] = null
				_holder = []
			else:
				global_position = p.hand_ground_pos(_holder[1])
				height = p.height
		if _holder.is_empty():
			var g := find_grabber(global_position, 10.0)
			if not g.is_empty():
				_holder = g
				g[0].held_objects[g[1]] = self
		if _holder.is_empty():
			_update_height()
	# 鳴らす
	for p: Player in World.get_players():
		var pressed: bool = p.input.instrument
		var was: bool = _prev.get(p, false)
		_prev[p] = pressed
		if pressed and not was and p.global_position.distance_to(global_position) <= play_radius and absf(p.height - height) < 0.6:
			play()
	if Net.is_online() and not _holder.is_empty():
		for id in Net.ready_remote_ids():
			_rpc_pos.rpc_id(id, global_position, height)
	queue_redraw()


## 鳴らす(シグナルから直接呼んでもよい)
func play() -> void:
	if not is_authority() or _cool > 0.0:
		return
	_cool = cooldown
	Waves.emit({
		origin = global_position, level = get_level(), size = size, shape = shape.resource_path,
		source = _source(), pitch = PitchDetector.midi_to_hz(note),
	})
	played.emit(note)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_pos(p: Vector2, h: float) -> void:
	global_position = p
	height = h
	queue_redraw()


func _draw() -> void:
	var base := lift()
	draw_circle(base, 4.0, Color(0, 0, 0, 0.25))
	var body := Rect2(base + Vector2(-4, -14), Vector2(8, 12))
	draw_rect(body, Color(color, 0.85))
	draw_rect(Rect2(base + Vector2(-2, -18), Vector2(4, 4)), color.darkened(0.2))
	draw_rect(body, Color(0, 0, 0, 0.6), false, 1.0)
	draw_string(ThemeDB.fallback_font, base + Vector2(-8, 8), PitchDetector.midi_name(note), HORIZONTAL_ALIGNMENT_CENTER, 16, 7, Color.WHITE)
