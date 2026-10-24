extends TestSceneBase
## レバー(I)と声を食べる動物(J)の確認用シーン。
## ・レバー(3段階)の position_changed を動物 Eater1 の set_direction_index につないである(0→右, 1→下, 2→左)
## ・レバーは二人で手をつないで引く(一人では動かない)。ポーズ中に腕をレバーへ向けて握り、
##   ポーズを解いて(握ったまま)レバーから離れる方向にスティックを倒す
## ・音源 E(1キー)の波を Eater1 が食べ、向いている方向へ吐き出す → その先の受け手 Rright / Rdown / Rleft に届く
## ・右の Eater2 は左を向いていて、Eater1 へ吐き返すが、同じ声は同じ動物を二度通らない(無限に回らない)


func _ready() -> void:
	super._ready()
	watch("Lever", ["position_changed", "pull_failed"])
	watch("Eater1", ["ate", "spat", "direction_changed"])
	watch("Eater2", ["ate", "spat"])
	for r in ["Rright", "Rdown", "Rleft"]:
		watch(r, ["wave_received"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_1:
		$E.emit()


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.1, call = "solo_at_lever" },
		{ t = 0.3, p1 = { pose = true, arm_l = TO_LEVER } },
		{ t = 0.2, p1 = { pose = true, arm_l = TO_LEVER, grab_l = true } },
		{ t = 0.6, p1 = { grab_l = true, move = Vector2.DOWN } },
		{ t = 0.1, call = "report", log = "solo pull: expect pull_failed, position 0" },
		{ t = 0.1, call = "pair_at_lever" },
		{ t = 0.3, p1 = { pose = true, arm_l = TO_LEVER, arm_r = Vector2(1, 0) }, p2 = { pose = true, arm_l = Vector2(-1, 0) } },
		{ t = 0.2, p1 = { pose = true, arm_l = TO_LEVER, arm_r = Vector2(1, 0), grab_l = true, grab_r = true }, p2 = { pose = true, arm_l = Vector2(-1, 0), grab_l = true } },
		{ t = 0.6, p1 = { grab_r = true, grab_l = true, move = Vector2.DOWN }, p2 = { grab_l = true } },
		{ t = 0.1, call = "report", log = "linked pull: expect position 1 -> Eater1 faces down" },
		{ t = 2.6, call = "emit_sound", log = "emit E: expect Eater1 eats, spits down -> Rdown" },
		{ t = 0.1, call = "set_right" },
		{ t = 3.0, call = "emit_sound", log = "Eater1 faces right: Rright, Eater2 eats & spits back, Eater1 does not re-eat" },
	]


## 1人目の左腕をレバーへ向ける(左肩からレバーへの向き)
const TO_LEVER := Vector2(0.81, -0.59)


func solo_at_lever() -> void:
	place(1, $Lever.global_position + Vector2(-6, 8))
	place(2, cell(Vector2(2, 12)))


func pair_at_lever() -> void:
	place(1, $Lever.global_position + Vector2(-6, 8))
	place(2, $Lever.global_position + Vector2(30, 8))


func report() -> void:
	print("[AUTO] lever=%d eater1_dir=%d linked=%s" % [$Lever.current, $Eater1.direction, Hands.is_linked()])


func emit_sound() -> void:
	$E.emit()


func set_right() -> void:
	$Eater1.set_direction_index(0)


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【レバー・声を食べる動物】二人で手をつないでレバーを引く(一人では動かない)→ 動物の向きが変わる / 1キー: 音源Eを鳴らす"
