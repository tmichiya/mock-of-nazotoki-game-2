extends TestSceneBase
## 同時押しボタン・固定メガホン・回転レバー・正解する鳥 の確認用シーン。
## ・同時押しボタン(組 A の2つ):片方だけ踏むと待機の色→1.5秒で失敗の色(3秒押せない)。二人で同時に踏むと成功 → 「sync_done」
## ・固定メガホン:後ろの吹き口に立って話すと、口の向き(右)へ扇形に遠くまで、遅れて届く
## ・回転レバー:つかんで左右に倒している間、動物と板がゆっくり回る。板が90度になると「turned」
## ・鳥:正解の音(ド)で鳴くと金色になって頭に音符


func _ready() -> void:
	super._ready()
	watch("SyncA1", ["waiting_started", "failed", "succeeded"])
	watch("Lever", ["tilted"])
	watch("Bird", ["correct"])
	watch("RFar", ["wave_received"])
	watch("RSide", ["wave_received"])
	Clears.cleared.connect(func(n): print("[AUTO] Clears.cleared(%s)" % n))


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.1, call = "p1_on_a1" },
		{ t = 0.5, call = "report_sync", log = "one button pressed: expect WAITING(1)" },
		{ t = 1.3, call = "report_sync", log = "after window: expect FAIL(2)" },
		{ t = 0.1, call = "both_off" },
		{ t = 3.2, call = "report_sync", log = "after cooldown: expect IDLE(0)" },
		{ t = 0.1, call = "both_on" },
		{ t = 0.3, call = "report_sync", log = "both pressed: expect SUCCESS(3), sync_done" },
		{ t = 0.1, call = "to_lever" },
		{ t = 0.4, p1 = { pose = true, arm_r = Vector2(1, 0) } },
		{ t = 1.0, call = "mark_rot", p1 = { move = Vector2.RIGHT } },
		{ t = 1.0, p1 = { move = Vector2.RIGHT } },
		{ t = 0.05, call = "report_lever", log = "held right 2s: expect plate +90deg, turned, player stayed" },
		{ t = 0.5, p1 = { release = true } },
		{ t = 0.05, call = "report_lever", log = "released: lever back to center" },
		{ t = 0.1, call = "to_megaphone" },
		{ t = 0.4, call = "speak_on" },
		{ t = 0.1, call = "speak_off" },
		{ t = 2.5, log = "megaphone: expect RFar receives (far, in front), RSide not" },
		{ t = 0.1, call = "bird_hear", log = "bird hears C: expect correct" },
		{ t = 0.3 },
	]


func p1_on_a1() -> void:
	place(1, $SyncA1.global_position)
	place(2, cell(Vector2(2, 12)))


func both_off() -> void:
	place(1, cell(Vector2(2, 11)))
	place(2, cell(Vector2(3, 11)))


func both_on() -> void:
	place(1, $SyncA1.global_position)
	place(2, $SyncA2.global_position)


func report_sync() -> void:
	print("[AUTO] sync state=%d / %d  looks waiting: A1=%s A2=%s" % [$SyncA1.state, $SyncA2.state, $SyncA1._color() == $SyncA1.color_waiting, $SyncA2._color() == $SyncA2.color_waiting])


var _p1_mark := Vector2.ZERO


func to_lever() -> void:
	place(1, $Lever.global_position + Vector2(-18, 0))
	place(2, cell(Vector2(2, 12)))


func mark_rot() -> void:
	_p1_mark = World.get_player_by_index(1).global_position


func report_lever() -> void:
	var p: Vector2 = World.get_player_by_index(1).global_position
	print("[AUTO] tilt=%.2f plate=%.0fdeg eater=%.0fdeg player_moved=%.0fpx" % [$Lever.tilt, rad_to_deg($Plate.rotation), $Eater.facing_deg, p.distance_to(_p1_mark)])


func to_megaphone() -> void:
	place(1, $Megaphone.mouthpiece_position())


func speak_on() -> void:
	Voice.settings.test_tone_hz = 220.0
	Voice.settings.test_tone_volume = 0.25


func speak_off() -> void:
	Voice.settings.test_tone_hz = 0.0001
	Voice.settings.test_tone_volume = 0.0


func bird_hear() -> void:
	$Bird.hear_pitch(60.0)


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【同時押し・固定メガホン・回転レバー・鳥】A の2つのボタンは二人で同時に / メガホンの後ろで話す / レバーをつかんで左右に倒す / 鳥はドで正解"
