@tool
class_name SingingBird
extends PuzzlePart
## 歌う鳥。届いた声(または楽器の音)の高さを、決められた数音のうち最も近い音で、きれいに鳴き直す。
## 鳴き声も音の波(種類 bird)として出す。和音の判定は ChordJudge に鳥をつないで行う。
## 定期的に、正解の音(手本)で自分から鳴く。同じ組(call_group)の鳥は同時に鳴かず、
## 決まった順に call_gap 秒ずつ空けて鳴き、一回りしたら call_rest 秒休む。
## 手本の鳴き声も音の波(種類 bird)なので、声を食べる動物に食べさせて別の場所へ運べる。
## 手本は sang ではなく called を出す(和音の判定役や正解には数えない)。

## 鳴いた(MIDI の音番号。60 = 真ん中のド)
signal sang(midi: float)
## 声が届いたが、どの音にも近くなかった
signal out_of_tune(midi: float)
## 声(または楽器の音)が届いた。高さが取れていなければ midi = -1(その時は鳴き直さない)
signal heard(midi: float)
## 正解の音で鳴いた(correct_notes のどれか)
signal correct(midi: float)
## 自分から手本の音で鳴いた(定期的な鳴き声)
signal called(midi: float)

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
@export_group("定期的に鳴く")
## 定期的に手本の音で鳴く
@export var call_enabled := true
## 手本の音(MIDI番号。-1 なら correct_notes の最初、それも無ければ notes の最初)
@export var call_note := -1.0
## 一緒に順番を決める組の名前(同じ名前の鳥は同時に鳴かない)。空なら「同じ親の下の鳥」が一つの組
@export var call_group: StringName = &""
## 組の中で、ある鳥が鳴いてから次の鳥が鳴くまでの間隔(秒)
@export var call_gap := 2.5
## 組の鳥が一回り鳴いた後に休む時間(秒)
@export var call_rest := 4.0
## 始まってから最初に鳴くまでの時間(秒)
@export var call_start_delay := 2.0
## 手本の鳴き声の波の大きさ(-1 なら song_size と同じ)
@export var call_size := -1.0

var last_note := -1.0
var _last_time := -100.0
var _receiver: WaveReceiver
var _synth: ToneSynth
var _flash := 0.0
## 正解しているか
var is_correct := false
var _correct_left := 0.0
var _celebrate := 0.0

## 組ごとの順番(ホストだけが使う)。組の名前 -> { next = 次に鳴く時刻, idx = 次に鳴く鳥の番号 }
static var _call_groups := {}


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
	add_to_group("singing_bird")
	_call_groups.erase(_call_key())


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
	_emit_song(best, song_size, false)
	sang.emit(best)
	if _is_correct_note(best):
		_set_correct(true)


func _emit_song(note: float, size: float, is_call: bool) -> void:
	var payload := { note = note }
	if is_call:
		payload.call = true
	Waves.emit({
		origin = global_position, level = get_level(), size = size,
		shape = song_shape.resource_path, source = "bird:" + str(name),
		pitch = PitchDetector.midi_to_hz(note), payload = payload,
	})


# ---------------------------------------------------------------- 定期的に鳴く

func _call_key() -> String:
	if call_group != &"":
		return str(call_group)
	return str(get_parent().get_path()) if get_parent() else ""


## 手本の音
func get_call_note() -> float:
	if call_note >= 0.0:
		return call_note
	if not correct_notes.is_empty():
		return correct_notes[0]
	return notes[0] if not notes.is_empty() else -1.0


## 手本の音で鳴く(定期的に呼ばれる。シグナルから直接呼んでもよい)
func call_now() -> void:
	if not is_authority():
		return
	var n := get_call_note()
	if n < 0.0:
		return
	last_note = n
	_last_time = Waves.clock
	_emit_song(n, call_size if call_size > 0.0 else song_size, true)
	called.emit(n)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority() or not call_enabled:
		return
	var key := _call_key()
	var members := get_tree().get_nodes_in_group("singing_bird").filter(
		func(b): return b.call_enabled and b._call_key() == key)
	# 組の順番は、組の中で最初の鳥だけが進める
	if members.is_empty() or members[0] != self:
		return
	var now := Waves.clock
	if not _call_groups.has(key):
		_call_groups[key] = { next = now + call_start_delay, idx = 0 }
	var g: Dictionary = _call_groups[key]
	# 組のどれかが(声に応えて)鳴いた直後なら、間隔を空けてから
	for b in members:
		g.next = maxf(g.next, b._last_time + call_gap)
	if now < g.next:
		return
	var idx: int = g.idx % members.size()
	members[idx].call_now()
	g.idx = idx + 1
	g.next = now + (call_rest if g.idx >= members.size() else call_gap)
	if g.idx >= members.size():
		g.idx = 0


## 自分の鳴き声の波が出た時に音を鳴らす(ホストでもクライアントでも)
func _on_any_wave(p: Dictionary) -> void:
	if str(p.source) != "bird:" + str(name):
		return
	_synth.play_note(float(p.pitch), 0.45)
	_flash = 1.0
	if not is_authority():
		last_note = p.payload.get("note", -1.0)
		if p.payload.get("call", false):
			called.emit(last_note)
		else:
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
