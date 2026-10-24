extends TestSceneBase
## 「○○をクリア」の窓口と、ゴールの確認用シーン。
## ・綿毛を音の波(1キー)で花(FluffGoal)まで運ぶと「fluff_done」→ 道をふさぐ箱(BlockA)が消える
## ・棒を型(PoleSocket)にはめると「pole_done」→ 扉が開く(ClearReactor の CALL で Door.open)
## ・2つともクリアすると ClearListener の activated → 隠れていた箱(Bridge)が現れる
## ・クリアのたびに ClearFx がパーティクルとチャイム


func _ready() -> void:
	super._ready()
	watch("Goal", ["reached"])
	watch("Socket", ["socketed"])
	watch("BothDone", ["activated"])
	watch("Fx", ["played"])
	Clears.cleared.connect(func(n): print("[AUTO] Clears.cleared(%s)" % n))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_1:
		$EFluff.emit()


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 1.2, call = "push" },
		{ t = 1.2, call = "push" },
		{ t = 1.5, call = "report", log = "after pushes: expect fluff_done, BlockA gone" },
		{ t = 0.1, call = "pole_near_socket" },
		{ t = 0.8, call = "report", log = "pole placed near socket: expect pole_done, door open, Bridge appears" },
	]


func push() -> void:
	$EFluff.emit()


func pole_near_socket() -> void:
	var pole := $Pole as LongPole
	pole.global_position = $Socket.global_position + Vector2(5, 3)
	pole.angle = deg_to_rad(8.0)


func report() -> void:
	print("[AUTO] fluff->goal %.0fpx  BlockA.visible=%s  door.open=%s  Bridge.visible=%s  pole.locked=%s" % [
		$Fluff.global_position.distance_to($Goal.global_position), $BlockA.visible, $Door.is_open, $Bridge.visible, $Pole.locked])


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【クリアの窓口・ゴール】1キー: 綿毛を押す → 花に入ると fluff_done(箱が消える)/ 棒を型にはめると pole_done(扉が開く)/ 両方で橋が現れる"
