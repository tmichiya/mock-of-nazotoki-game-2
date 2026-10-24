extends TestSceneBase
## 歌う鳥(M)の確認用シーン。
## ・3羽の鳥(ド・ミ・ソを鳴ける)。声の高さが近い音で鳴き直す(マイクで歌うか、瓶笛で)
## ・瓶笛:近くで楽器ボタン(X / キーボード R)を押すと鳴る。手を伸ばしてつかむと持ち運べる
## ・3羽がそれぞれ別の音を許容時間内に鳴くと、和音の判定役が chord_completed を出す(和音はインスペクタで設定)


func _ready() -> void:
	super._ready()
	for b in ["BirdA", "BirdB", "BirdC"]:
		watch(b, ["sang", "out_of_tune", "heard"])
	watch("Chord", ["chord_completed", "progress_changed"])


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.1, call = "to_bottle_c" },
		{ t = 0.1, p1 = { instrument = true } },
		{ t = 0.3 },
		{ t = 0.1, call = "to_bottle_e" },
		{ t = 0.1, p1 = { instrument = true } },
		{ t = 0.3 },
		{ t = 0.1, call = "to_bottle_g" },
		{ t = 0.1, p1 = { instrument = true } },
		{ t = 1.2, log = "played C, E, G: expect 3 birds sing, chord_completed" },
		{ t = 0.1, call = "off_pitch", log = "off-pitch voice (F#): expect out_of_tune" },
		{ t = 0.6 },
		{ t = 1.0, call = "sing_c", log = "voice C4 (261.6Hz) near BirdA: expect BirdA sings" },
		{ t = 0.5, call = "sing_off" },
	]


func sing_c() -> void:
	place(1, $BirdA.global_position + Vector2(0, 30))
	Voice.settings.test_tone_hz = 261.63
	Voice.settings.test_tone_volume = 0.25


func sing_off() -> void:
	Voice.settings.test_tone_hz = 0.0001
	Voice.settings.test_tone_volume = 0.0
	print("[AUTO] voice pitch=%.1f volume_db=%.1f" % [Voice.get_pitch_hz(), Voice.get_volume_db()])


func to_bottle_c() -> void:
	place(1, $BottleC.global_position + Vector2(0, 8))


func to_bottle_e() -> void:
	place(1, $BottleE.global_position + Vector2(0, 8))


func to_bottle_g() -> void:
	place(1, $BottleG.global_position + Vector2(0, 8))


func off_pitch() -> void:
	$BirdA.hear_pitch(66.0)


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【歌う鳥】鳥の近くで歌うか、瓶笛(近くで X / R)を鳴らすと、鳥が近い音で鳴き直す。3羽がド・ミ・ソをそろえると和音の判定役が成功を出す
右上のメーターで、マイク(F4で切替)・音量・声の高さを確かめる。声が届いたのに高さが取れない時は Bird.heard(-1) が出る"
