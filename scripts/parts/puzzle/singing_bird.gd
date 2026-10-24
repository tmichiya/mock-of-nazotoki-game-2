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
## 正解の音で鳴いた(correct_notes のどれか)
signal correct(midi: float)

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
@export_group("正解")
## 正解の音(MIDI番号)。この音で鳴くと「正解」の見た目になり、clear_event を知らせる。空なら正解は無い
@export var correct_notes := PackedFloat32Array()
## 正解した後も、正解の見た目のままにする(false なら correct_time 秒で戻る)
@export var stay_correct := true
@export var correct_time := 2.0
## 正解した時に知らせる「○○をクリア」の名前
@export var clear_event: StringName = &""
## 正解の時の色と、頭の上の光
@export var correct_color := Color("ffd84a")

var last_note := -1.0
var _last_time := -100.0
var _receiver: WaveReceiver
var _synth: ToneSynth
var _flash := 0.0
## 正解しているか
var is_correct := false
var _correct_left := 0.0
var _celebrate := 0.0


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
	if _is_correct_note(best):
		_set_correct(true)


## 自分の鳴き声の波が出た時に音を鳴らす(ホストでもクライアントでも)
func _on_any_wave(p: Dictionary) -> void:
	if str(p.source) != "bird:" + str(name):
		return
	_synth.play_note(float(p.pitch), 0.45)
	_flash = 1.0
	if not is_authority():
		last_note = p.payload.get("note", -1.0)
		sang.emit(last_note)


func _is_correct_note(n: float) -> bool:
	for c in correct_notes:
		var d := absf(n - c)
		if octave_free:
			d = absf(fposmod(n - c + 6.0, 12.0) - 6.0)
		if d < 0.5:
			return true
	return false


func _set_correct(v: bool) -> void:
	_correct_left = correct_time
	if v == is_correct:
		return
	is_correct = v
	if v:
		correct.emit(last_note)
		_celebrate = 1.0
		if is_authority():
			Clears.clear(clear_event)
	sync_state()
	queue_redraw()


## 喜ぶ(和音がそろった時などに呼ぶ。見た目だけ)
func celebrate() -> void:
	_celebrate = 1.0
	queue_redraw()


func get_state() -> Dictionary:
	return { correct = is_correct }


func apply_state(s: Dictionary) -> void:
	if s.correct != is_correct:
		is_correct = s.correct
		if is_correct:
			correct.emit(last_note)
			_celebrate = 1.0
		queue_redraw()


func reset() -> void:
	if not is_authority():
		return
	is_correct = false
	Clears.reset_clear(clear_event)
	sync_state()
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _celebrate > 0.0:
		_celebrate = maxf(0.0, _celebrate - delta * 0.8)
		queue_redraw()
	if is_correct:
		queue_redraw()
	if is_correct and not stay_correct and is_authority():
		_correct_left -= delta
		if _correct_left <= 0.0:
			is_correct = false
			sync_state()
			queue_redraw()
	if Engine.is_editor_hint():
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	var base := lift()
	var body := base + Vector2(0, -10)
	draw_line(base, base + Vector2(0, -4), Color("6b5440"), 2.0)
	var bc := correct_color if is_correct else body_color
	if is_correct:
		# 正解:光の輪と、頭の上の音符
		draw_circle(body, 9.0 + sin(Time.get_ticks_msec() / 200.0) * 1.0, Color(correct_color, 0.25))
		var nb := body + Vector2(-2, -12)
		draw_circle(nb, 1.8, Color.WHITE)
		draw_line(nb + Vector2(1.6, 0), nb + Vector2(1.6, -6), Color.WHITE, 1.0)
		draw_line(nb + Vector2(1.6, -6), nb + Vector2(4.0, -4.5), Color.WHITE, 1.0)
	if _celebrate > 0.0:
		for i in range(6):
			var a := TAU * i / 6.0 + (1.0 - _celebrate) * 2.0
			draw_circle(body + Vector2.from_angle(a) * (8.0 + (1.0 - _celebrate) * 10.0), 1.3, Color(correct_color, _celebrate))
	draw_circle(body, 6.0, bc.lightened(_flash * 0.4))
	draw_arc(body, 6.0, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)
	draw_colored_polygon(PackedVector2Array([body + Vector2(5, -1), body + Vector2(10, 0), body + Vector2(5, 2)]), Color("e07a2a"))
	draw_circle(body + Vector2(2, -2), 1.0, Color.BLACK)
	# 鳴ける音の数だけ点
	for i in range(notes.size()):
		var lit := not Engine.is_editor_hint() and notes[i] == last_note and _flash > 0.0
		draw_circle(base + Vector2(-4 + i * 4, 4), 1.3, Color.WHITE if lit else Color(1, 1, 1, 0.4))
