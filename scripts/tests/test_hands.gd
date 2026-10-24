extends TestSceneBase
## 腕と手つなぎの確認用シーン(C・D の完了条件)。
## つなぎ方:ポーズ中に相手へ腕を向けて握る(LT/RT+スティック+LB/RB)。つながったらポーズを解いても握っている間はつないだまま
## 左下の広場:ポーズ、片手の回転投げ、両手の反動
## 右上の1段の崖:つないだまま下の段へ降りる → 上の人が離れると引き上げ
## 右下の2段の崖:つないだまま降りると宙づり → 揺らす → 引き上げ


## つなぎ方:ポーズ中に相手へ腕を向けて握る → つながったらポーズを解いても、握っている間はつないだまま
const P1R_OFFER := { pose = true, arm_r = Vector2(1, 0), grab_r = true }
const P2L_OFFER := { pose = true, arm_l = Vector2(-1, 0), grab_l = true }
const P1R := { grab_r = true }
const P2L := { grab_l = true }


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		# C. ポーズ(左腕=画面左側の腕を左上、右腕を右へ)。無段階なので向きはスティックのまま
		{ t = 0.5, p1 = { pose = true, arm_l = Vector2(-1, -1), arm_r = Vector2(1, 0) }, p2 = { pose = true, raise_l = true, arm_r = Vector2(1, 1) } },
		{ t = 0.1, log = "pose arms (P1 L=(-0.7 -0.7 0)+ R=(1 0 0)+ / P2 L=(0 0 1)+ R=(0.7 0.7 0)+)", p1 = { pose = true, arm_l = Vector2(-1, -1), arm_r = Vector2(1, 0) }, p2 = { pose = true, raise_l = true, arm_r = Vector2(1, 1) } },
		# D. 片手でつなぐ → 回転 → 離して飛ぶ
		{ t = 0.1, call = "setup_one_hand" },
		{ t = 0.4, p1 = P1R_OFFER, p2 = P2L_OFFER },
		{ t = 0.1, log = "one hand linked (linked=1, P1 R and P2 L marked L)", p1 = P1R, p2 = P2L },
		{ t = 2.0, p1 = { grab_r = true, orbit = 1 }, p2 = P2L },
		{ t = 0.05, log = "spinning (spin > 2.5)", p1 = { grab_r = true, orbit = 1 }, p2 = P2L },
		{ t = 1.6, call = "mark_p1", p2 = P2L },
		{ t = 0.1, call = "report_throw", log = "after throw (landed)" },
		# 両手 → 離すと反動(向かい合って縦に並ぶ:上の人は手前へ、下の人は奥へ腕を伸ばす)
		{ t = 0.1, call = "setup_two_hands" },
		{ t = 0.4, p1 = { pose = true, arm_l = Vector2(0, 1), arm_r = Vector2(0, 1), grab_l = true, grab_r = true }, p2 = { pose = true, arm_l = Vector2(0, -1), arm_r = Vector2(0, -1), grab_l = true, grab_r = true } },
		{ t = 0.1, log = "two hands linked (linked=2)", p1 = { grab_l = true, grab_r = true }, p2 = { grab_l = true, grab_r = true } },
		{ t = 1.0, call = "mark_both" },
		{ t = 0.1, call = "report_recoil", log = "after recoil" },
		# 1段の崖:つないだまま降りる → 引き上げ
		{ t = 0.1, call = "setup_cross1" },
		{ t = 0.4, p1 = P1R_OFFER, p2 = P2L_OFFER },
		{ t = 0.8, p1 = { grab_r = true, move = Vector2.LEFT }, p2 = P2L },
		{ t = 0.1, log = "P1 stepped down 1 level while linked (P1 h=0, cross=stand)", p1 = P1R, p2 = P2L },
		{ t = 1.2, p1 = P1R, p2 = { grab_l = true, move = Vector2.RIGHT } },
		{ t = 0.1, log = "pulled up (P1 h=1)", p1 = P1R, p2 = P2L },
		# 2段の崖:宙づり → 揺らす → 引き上げ
		{ t = 0.1, call = "setup_cross2" },
		{ t = 0.4, p1 = P1R_OFFER, p2 = P2L_OFFER },
		{ t = 0.6, p1 = { grab_r = true, move = Vector2.LEFT }, p2 = P2L },
		{ t = 0.1, log = "hanging (P1 st=4, cross=hang, h between 0 and 2)", p1 = P1R, p2 = P2L },
		{ t = 0.5, p1 = { grab_r = true, move = Vector2.LEFT }, p2 = P2L },
		{ t = 0.05, log = "swinging out", p1 = P1R, p2 = P2L },
		{ t = 0.5, p1 = { grab_r = true, move = Vector2.RIGHT }, p2 = P2L },
		{ t = 0.05, log = "swinging back", p1 = P1R, p2 = P2L },
		{ t = 2.0, p1 = P1R, p2 = { grab_l = true, move = Vector2.RIGHT } },
		{ t = 0.1, log = "pulled up from hang (P1 h=2)", p1 = P1R, p2 = P2L },
		{ t = 0.3 },
	]


var _mark := Vector2.ZERO
var _mark2 := Vector2.ZERO


func _place(p: Player, cell: Vector2, offset := Vector2.ZERO) -> void:
	p.link_controlled = false
	p.state = Player.State.WALK
	p.velocity = Vector2.ZERO
	p.global_position = (cell + Vector2(0.5, 0.5)) * Vector2(32, 24) + offset
	p.height = World.height_at(p.global_position)


func mark_p1() -> void:
	_mark = World.get_player_by_index(1).global_position


func report_throw() -> void:
	var p := World.get_player_by_index(1)
	print("[AUTO] thrown distance = %.0f px" % p.global_position.distance_to(_mark))


func setup_one_hand() -> void:
	_place(World.get_player_by_index(1), Vector2(5, 5))
	_place(World.get_player_by_index(2), Vector2(5, 5), Vector2(36, 0))


func setup_two_hands() -> void:
	_place(World.get_player_by_index(1), Vector2(5, 9))
	_place(World.get_player_by_index(2), Vector2(5, 9), Vector2(0, 26))


func mark_both() -> void:
	_mark = World.get_player_by_index(1).global_position
	_mark2 = World.get_player_by_index(2).global_position


func report_recoil() -> void:
	var a: Vector2 = World.get_player_by_index(1).global_position
	var b: Vector2 = World.get_player_by_index(2).global_position
	print("[AUTO] recoil: P1 moved %.0f px, P2 moved %.0f px, now %.0f px apart" % [a.distance_to(_mark), b.distance_to(_mark2), a.distance_to(b)])


func setup_cross1() -> void:
	_place(World.get_player_by_index(1), Vector2(12, 3), Vector2(-10, 0))
	_place(World.get_player_by_index(2), Vector2(12, 3), Vector2(26, 0))


func setup_cross2() -> void:
	_place(World.get_player_by_index(1), Vector2(15, 10), Vector2(-10, 0))
	_place(World.get_player_by_index(2), Vector2(15, 10), Vector2(26, 0))
