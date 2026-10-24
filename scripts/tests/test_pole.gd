extends TestSceneBase
## 長い棒(L)の確認用シーン。
## ・棒の両端に一人ずつ立ち、手を伸ばして(LB/RB)握ると、二人で運べる
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
		{ t = 0.4, p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.1, call = "report", log = "both holding: expect carried_by_two", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 2.0, p1 = { grab_r = true, move = Vector2.UP }, p2 = { grab_l = true, move = Vector2.UP } },
		{ t = 0.1, call = "report", log = "carried up together: pole middle hits the pillar -> hit(size), stops", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 1.0, p1 = { grab_r = true, move = Vector2.DOWN }, p2 = { grab_l = true, move = Vector2.DOWN } },
		{ t = 1.2, p1 = { grab_r = true }, p2 = { grab_l = true, move = Vector2.DOWN } },
		{ t = 0.1, call = "report", log = "only P2 moved: pole rotated", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 5.0, p1 = { grab_r = true, move = Vector2.RIGHT }, p2 = { grab_l = true, move = Vector2.RIGHT } },
		{ t = 0.1, call = "report", log = "pushed into the wall: expect hit(size)", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.3 },
		{ t = 0.1, call = "report", log = "released" },
	]


func at_ends() -> void:
	var e: Array = $Pole.ends()
	place(1, e[0])
	place(2, e[1])


func report() -> void:
	print("[AUTO] pole center=(%.0f,%.0f) angle=%.0fdeg" % [$Pole.global_position.x, $Pole.global_position.y, rad_to_deg($Pole.angle)])
