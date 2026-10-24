extends TestSceneBase
## マイク入力と声の波の確認用シーン(F の完了条件)。
## 話すと1人目(オレンジ)の位置から声の波が出る。大きな声ほど大きな波。右上に音量と声の高さ。
## マイクが無い時は、VoiceSettings の test_tone_hz に数値を入れると、その高さの音で試せる。

var _sizes: Array = []


func _ready() -> void:
	super._ready()
	Voice.voice_wave_sent.connect(func(s): _sizes.append(s))


func _steps() -> Array:
	return [
		{ t = 1.0, call = "tone_220_quiet" },
		{ t = 0.05, call = "report", log = "220Hz quiet" },
		{ t = 1.0, call = "tone_220_loud" },
		{ t = 0.05, call = "report", log = "220Hz loud" },
		{ t = 1.0, call = "tone_440_loud" },
		{ t = 0.05, call = "report", log = "440Hz loud" },
		{ t = 1.0, call = "tone_off" },
		{ t = 0.05, call = "report", log = "silent" },
	]


func _tone(hz: float, vol: float) -> void:
	Voice.settings.test_tone_hz = hz
	Voice.settings.test_tone_volume = vol
	_sizes.clear()


func tone_220_quiet() -> void:
	_tone(220.0, 0.03)


func tone_220_loud() -> void:
	_tone(220.0, 0.25)


func tone_440_loud() -> void:
	_tone(440.0, 0.25)


func tone_off() -> void:
	_tone(0.0001, 0.0)


func report() -> void:
	var avg := 0.0
	for s in _sizes:
		avg += s
	if not _sizes.is_empty():
		avg /= _sizes.size()
	print("[AUTO] volume_db=%.1f pitch=%.1fHz midi=%.1f (%s) waves=%d avg_size=%.2f" % [
		Voice.get_volume_db(), Voice.get_pitch_hz(), Voice.get_pitch_midi(),
		PitchDetector.midi_name(Voice.get_pitch_midi()), _sizes.size(), avg])
