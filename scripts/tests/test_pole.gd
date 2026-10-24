extends TestSceneBase
## 長い棒(L)の確認用シーン。
## ・棒の両端に一人ずつ立ち、ポーズ中に腕を端へ向けて握る(LB/RB)と、二人で運べる(握っている間はポーズを解いてよい)
## ・二人が同じ向きに動くと運べる。片方だけが動くと棒が回る。引っ張り合うとうまく動かない
## ・壁(右の1段の台地)に当たると、ぶつかった速さに応じた音の波が出る(こするだけなら小さな波)
## ・棒の counts_as_link をオンにすると、握っている間は声が棒を伝って届く


func _ready() -> void:
	super._ready()
	watch("Pole", ["grabbed", "released", "hit", "carried_by_two"])


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.1, call = "at_ends" },
		{ t = 0.4, p1 = { pose = true, arm_r = Vector2(1, 0), grab_r = true }, p2 = { pose = true, arm_l = Vector2(-1, 0), grab_l = true } },
		{ t = 0.1, call = "report", log = "both holding: expect carried_by_two", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 2.0, p1 = { grab_r = true, move = Vector2.UP }, p2 = { grab_l = true, move = Vector2.UP } },
		{ t = 0.1, call = "report", log = "carried up together: pole middle hits the pillar -> hit(size), stops", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 1.0, p1 = { grab_r = true, move = Vector2.DOWN }, p2 = { grab_l = true, move = Vector2.DOWN } },
		{ t = 1.2, p1 = { grab_r = true }, p2 = { grab_l = true, move = Vector2.DOWN } },
		{ t = 0.1, call = "report", log = "only P2 moved: pole rotated", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 5.0, p1 = { grab_r = true, move = Vector2.RIGHT }, p2 = { grab_l = true, move = Vector2.RIGHT } },
		{ t = 0.1, call = "report", log = "pushed into the wall: expect hit(size)", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.3, p1 = { release = true }, p2 = { release = true } },
		{ t = 0.1, call = "report", log = "released" },
	]


func at_ends() -> void:
	var e: Array = $Pole.ends()
	# 端から腕1本分(肩5px+腕13px)離れて立ち、端へ腕を向ける
	place(1, e[0] + Vector2(-18, 0))
	place(2, e[1] + Vector2(18, 0))


func report() -> void:
	print("[AUTO] pole center=(%.0f,%.0f) angle=%.0fdeg" % [$Pole.global_position.x, $Pole.global_position.y, rad_to_deg($Pole.angle)])


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【長い棒】両端で手を伸ばして握る(LB/RB)→ 二人で運ぶ・回す。柱や壁に当たると強さに応じた音の波"
