class_name ToneSynth
extends AudioStreamPlayer2D
## 仮の音(正弦波+少しの倍音)を鳴らす小さな音源。鳥の鳴き声や瓶笛に使う。本番の音に差し替えてよい。

@export var volume := 0.25
@export var mix := 22050.0

var _playback: AudioStreamGeneratorPlayback
var _notes: Array = []   # [hz, 経過サンプル, 全体サンプル]


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = mix
	gen.buffer_length = 0.2
	stream = gen
	play()
	_playback = get_stream_playback()


## hz の音を duration 秒鳴らす
func play_note(hz: float, duration: float = 0.35) -> void:
	if hz <= 0.0:
		return
	_notes.append([hz, 0, int(duration * mix)])


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in range(n):
		var s := 0.0
		for note in _notes:
			var k: int = note[1]
			if k < note[2]:
				var t := float(k) / mix
				var env: float = minf(1.0, k / (0.01 * mix)) * (1.0 - float(k) / note[2])
				s += (sin(TAU * note[0] * t) + 0.3 * sin(TAU * note[0] * 2.0 * t)) * env * volume
				note[1] = k + 1
		frames[i] = Vector2(s, s)
	_notes = _notes.filter(func(x): return x[1] < x[2])
	_playback.push_buffer(frames)
