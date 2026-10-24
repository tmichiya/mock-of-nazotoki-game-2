class_name VoiceSettings
extends Resource
## マイク・声の波・ゲーム内VCの調整値。res://resources/settings/voice_settings.tres を編集する
## (VoiceMonitor を置けば、そのインスペクタからも開ける)。

@export_group("マイク")
## 使う録音デバイスの名前(空なら Windows の既定の録音デバイス)。実行中は F4 で切り替えられる
@export var input_device := ""
## マイクの感度(dB。大きいほど小さな声でも拾う)
@export_range(-20.0, 40.0, 0.5) var mic_gain_db := 0.0
## この音量(dB)を超えたら「話している」とみなす
@export_range(-80.0, 0.0, 0.5) var threshold_db := -42.0
## この音量(dB)で声の波が一番大きくなる
@export_range(-60.0, 0.0, 0.5) var loud_db := -12.0
## 話し終わってから波を出し続ける時間(秒。語尾が切れないように)
@export var hangover := 0.2
## マイクを使わない(テスト用)
@export var mic_enabled := true
## 確認用:マイクの代わりにこの高さ(Hz)の音を出す(0で使わない)
@export var test_tone_hz := 0.0
## 確認用の音の大きさ(0〜1)
@export_range(0.0, 1.0) var test_tone_volume := 0.3

@export_group("声の波")
## 何秒ごとに声の波を出すか(この長さの声がひとつの波に乗る)
@export var wave_interval := 0.1
## 一番小さい声の波の大きさ
@export var min_size := 0.35
## 一番大きい声の波の大きさ
@export var max_size := 2.2
## 声の波の形
@export var voice_shape: WaveShape = preload("res://resources/wave_shapes/voice.tres")
## 1台で2人を動かす時、マイクは何人目の声か
@export_range(1, 2) var offline_mic_player := 1

@export_group("声の高さ")
## 探す声の高さの範囲(Hz)
@export var pitch_min_hz := 75.0
@export var pitch_max_hz := 1000.0
## 判定の厳しさ(小さいほど厳しい。0.1〜0.3)
@export_range(0.05, 0.5) var pitch_threshold := 0.25
## これより浅い谷しか無い時は「高さが無い」とみなす(大きいほど雑音の多い声でも取る)
@export_range(0.1, 0.8) var pitch_fallback_threshold := 0.45
## 取れた高さを覚えておく時間(秒。息つぎ・子音で途切れないように)
@export var pitch_hold := 0.4
## 何回分の結果の中央値をとるか(大きいほど安定、反応は遅い)
@export_range(1, 15) var pitch_median := 5

@export_group("ゲーム内VC")
## この距離(px)以内で同じ段(または手つなぎ中)なら、波を待たずにすぐ再生する
@export var near_distance := 40.0
## 相手の声の音量(dB)
@export_range(-40.0, 12.0) var playback_volume_db := 0.0
## 波の強さで音量を変える
@export var volume_by_strength := true
## 反射して何度も届いた時に、2回目以降も再生する(やまびこ)
@export var play_echoes := false
## 1台で2人を動かす時、マイクの声が「もう一人」に届いたら再生する(ヘッドホンで確認用)
@export var offline_loopback := false
## 通信で送る音声の標本化周波数
@export var send_rate := 16000


static var _default: VoiceSettings


static func get_default() -> VoiceSettings:
	if _default == null:
		_default = load("res://resources/settings/voice_settings.tres")
	return _default
