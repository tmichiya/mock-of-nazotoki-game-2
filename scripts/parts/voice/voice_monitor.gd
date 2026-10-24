class_name VoiceMonitor
extends Node
## マイクと声の様子をエディタでつなげるシグナルとして出す部品。シーンのどこに置いてもよい。
## (本体は自動読み込みの Voice)

## 声の高さが変わった(Hz と MIDI の音番号。60 = 真ん中のド。-1 は高さが取れない)
signal pitch_changed(hz: float, midi: float)
## 話し始めた / 話し終えた
signal speaking_changed(speaking: bool)
signal started_speaking
signal stopped_speaking

## 声とVCの調整値(全体で共有。ここで編集すると反映)
@export var settings: VoiceSettings
## 画面の右上に音量と声の高さを表示する
@export var show_meter := false

var _meter: Label


func _ready() -> void:
	if settings == null:
		settings = VoiceSettings.get_default()
	Voice.settings = settings
	Voice.pitch_changed.connect(func(hz, midi): pitch_changed.emit(hz, midi))
	Voice.speaking_changed.connect(func(s):
		speaking_changed.emit(s)
		if s:
			started_speaking.emit()
		else:
			stopped_speaking.emit())
	if show_meter:
		var layer := CanvasLayer.new()
		layer.layer = 11
		add_child(layer)
		_meter = Label.new()
		_meter.anchor_left = 1.0
		_meter.anchor_right = 1.0
		_meter.offset_left = -420
		_meter.offset_top = 8
		_meter.add_theme_font_size_override("font_size", 14)
		_meter.add_theme_color_override("font_outline_color", Color.BLACK)
		_meter.add_theme_constant_override("outline_size", 4)
		layer.add_child(_meter)


func _process(_delta: float) -> void:
	if _meter == null:
		return
	var bars := int(Voice.get_volume() * 20.0)
	var midi := Voice.get_pitch_midi()
	_meter.text = "マイク: %s (F4 で切替)\n音量 %5.1f dB [%s%s] しきい値 %.0f dB\n声の高さ %s Hz (%s)\n%s" % [
		Voice.get_input_device(), Voice.get_volume_db(), "|".repeat(bars), " ".repeat(20 - bars), Voice.settings.threshold_db,
		"%.0f" % Voice.get_pitch_hz() if Voice.get_pitch_hz() > 0 else "-",
		PitchDetector.midi_name(midi), "話している(声の波を出している)" if Voice.is_speaking() else "(しきい値より小さいので声の波は出ていない)"]
	var d: Dictionary = Voice.debug
	_meter.text += "\n--- 確認用 ---\n高さの候補 %s Hz  谷の深さ %.2f(%.2f 以下で採用)\n取り込み %.0f/秒(ミックス %.0f)途切れ %.0f回/秒\n左 %.0f dB  右 %.0f dB  左右の相関 %.2f(使う音: %s)\nF5: 3秒録って user://voice_debug.wav に保存" % [
		"%.0f" % d.candidate_hz if d.candidate_hz > 0 else "-", d.dip, Voice.settings.pitch_fallback_threshold,
		d.capture_rate, AudioServer.get_mix_rate(), d.gaps, d.left_db, d.right_db, d.correlation,
		["左右の平均", "左", "右"][Voice.settings.mic_channel]]


func get_pitch_hz() -> float:
	return Voice.get_pitch_hz()


func get_pitch_midi() -> float:
	return Voice.get_pitch_midi()
