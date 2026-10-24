@tool
class_name SingingBird
extends PuzzlePart
## 歌う鳥。届いた声(または楽器の音)の高さを、決められた数音のうち最も近い音で、きれいに鳴き直す。
## 鳴き声も音の波(種類 bird)として出す。和音の判定は ChordJudge に鳥をつないで行う。

## 鳴いた(MIDI の音番号。60 = 真ん中のド)
signal sang(midi: float)
## 声が届いたが、どの音にも近くなかった
signal out_of_tune(midi: float)
## 声(または楽器の音)が届いた。高さが取れていなければ midi = -1(その時は鳴き直さない)
signal heard(midi: float)

## 鳴ける音(MIDI の音番号)。60=ド 62=レ 64=ミ 65=ファ 67=ソ 69=ラ 71=シ 72=上のド
@export var notes := PackedFloat32Array([60, 64, 67]):
	set(v):
		notes = v
		queue_redraw()
## 許容幅(半音いくつまでのずれなら、その音とみなすか)
@export var tolerance := 1.0
## オクターブ違いも同じ音とみなす(低い声・高い声のどちらでも歌える)
@export var octave_free := true
## 反応する波の種類
@export var hear_kinds: Array[StringName] = [&"voice", &"instrument"]
## 聞こえる範囲の半径(px)
@export var ear_radius := 14.0
## 同じ音を続けて鳴く間隔(秒)
@export var cooldown := 0.6
## 鳴き声の波の大きさ
@export var song_size := 1.2
@export var song_shape: WaveShape = preload("res://resources/wave_shapes/bird.tres")
@export var body_color := Color("f2c14e")

var last_note := -1.0
var _last_time := -100.0
var _receiver: WaveReceiver
var _synth: ToneSynth
var _flash := 0.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_receiver = WaveReceiver.new()
	_receiver.radius = ear_radius
	_receiver.accept_kinds = hear_kinds
	_receiver.level_mode = WaveReceiver.LevelMode.FIXED
	_receiver.fixed_level = get_level()
	add_child(_receiver)
	_receiver.wave_received_info.connect(_on_wave)
	_synth = ToneSynth.new()
	add_child(_synth)
	Waves.wave_emitted.connect(_on_any_wave)


func _on_wave(info: Dictionary) -> void:
	if not is_authority():
		return
	var hz: float = info.get("pitch", -1.0)
	if hz <= 0.0:
		heard.emit(-1.0)
		return
	var midi := PitchDetector.hz_to_midi(hz)
	heard.emit(midi)
	hear_pitch(midi)


## 音の高さ(MIDI)を聴かせる。シグナルから直接呼んでもよい
func hear_pitch(midi: float) -> void:
	if not is_authority():
		return
	var best := -1.0
	var best_d := 999.0
	for n in notes:
		var d := absf(midi - n)
		if octave_free:
			d = absf(fposmod(midi - n + 6.0, 12.0) - 6.0)
		if d < best_d:
			best_d = d
			best = n
	if best < 0.0 or best_d > tolerance:
		out_of_tune.emit(midi)
		return
	if best == last_note and Waves.clock - _last_time < cooldown:
		return
	last_note = best
	_last_time = Waves.clock
	Waves.emit({
		origin = global_position, level = get_level(), size = song_size,
		shape = song_shape.resource_path, source = "bird:" + str(name),
		pitch = PitchDetector.midi_to_hz(best), payload = { note = best },
	})
	sang.emit(best)


## 自分の鳴き声の波が出た時に音を鳴らす(ホストでもクライアントでも)
func _on_any_wave(p: Dictionary) -> void:
	if str(p.source) != "bird:" + str(name):
		return
	_synth.play_note(float(p.pitch), 0.45)
	_flash = 1.0
	if not is_authority():
		last_note = p.payload.get("note", -1.0)
		sang.emit(last_note)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	var base := lift()
	var body := base + Vector2(0, -10)
	draw_line(base, base + Vector2(0, -4), Color("6b5440"), 2.0)
	draw_circle(body, 6.0, body_color.lightened(_flash * 0.4))
	draw_arc(body, 6.0, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)
	draw_colored_polygon(PackedVector2Array([body + Vector2(5, -1), body + Vector2(10, 0), body + Vector2(5, 2)]), Color("e07a2a"))
	draw_circle(body + Vector2(2, -2), 1.0, Color.BLACK)
	# 鳴ける音の数だけ点
	for i in range(notes.size()):
		var lit := not Engine.is_editor_hint() and notes[i] == last_note and _flash > 0.0
		draw_circle(base + Vector2(-4 + i * 4, 4), 1.3, Color.WHITE if lit else Color(1, 1, 1, 0.4))
