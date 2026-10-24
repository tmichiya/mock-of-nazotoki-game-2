extends TestSceneBase
## 部品カタログ。すべての部品を並べてある(1台で2人、またはホスト・参加で歩いて回れる)。
## 区画ごとに札で説明している。数字キーで各区画の音源を鳴らせる:
##   1: 段のちがう音源  2: 楕円の焦点  3: 重なる点の石(同時)  4: 綿毛  5: カエルを起こす  6: 動物に食べさせる


func _ready() -> void:
	super._ready()
	watch("Doors/Group", ["solved"])
	watch("Animals/Lever", ["position_changed", "pull_failed"])
	watch("Frog/Frog", ["stage_changed", "failed"])
	watch("Birds/Chord", ["chord_completed"])
	watch("Offering/Offering", ["offered", "not_enough"])
	watch("Extras/Stone", ["lit"])
	watch("Extras/Phone", ["connected", "disconnected"])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1:
			$Waves/E0.emit()
			$Waves/E1.emit()
		KEY_2: $Waves/EFocus.emit()
		KEY_3:
			$Extras/EA.emit()
			$Extras/EB.emit()
		KEY_4: $Extras/EFluff.emit()
		KEY_5: $Frog/Noise.emit()
		KEY_6: $Animals/E.emit()


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【部品カタログ】全部品。1:段のちがう音 2:楕円 3:重なる石 4:綿毛 5:カエル 6:動物 / F1 段番号 F2 波の範囲 F3 誰の目で見るか"
