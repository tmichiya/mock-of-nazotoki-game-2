extends TestSceneBase
## 眠るカエル(K)の確認用シーン。
## ・1キー: 小さな音(寝返りまで)  2キー: 大きな音(一気に怒る)
## ・怒ると failed → PuzzleReset.reset() をつないであり、プレイヤーと綿毛が ResetPoint に戻る


func _ready() -> void:
	super._ready()
	watch("Frog", ["stage_changed", "failed", "calmed"])
	watch("Reset", ["reset_done"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_1:
			$Small.emit()
		elif event.physical_keycode == KEY_2:
			$Big.emit()


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 1.2, call = "small", log = "small sound: expect TOSS(1)" },
		{ t = 3.0, call = "report", log = "after calming: expect SLEEP(0)" },
		{ t = 0.1, call = "move_players_away" },
		{ t = 1.2, call = "big", log = "big sounds: expect ANGRY(3) + failed + reset" },
		{ t = 0.4, call = "big" },
		{ t = 1.5 },
		{ t = 0.1, call = "report", log = "after reset: players back at reset points" },
	]


func small() -> void:
	$Small.emit()


func big() -> void:
	$Big.emit()


func move_players_away() -> void:
	place(1, cell(Vector2(15, 10)))
	place(2, cell(Vector2(16, 10)))


func report() -> void:
	var a: Vector2 = World.get_player_by_index(1).global_position
	var b: Vector2 = World.get_player_by_index(2).global_position
	print("[AUTO] frog stage=%d noise=%.2f P1=(%.0f,%.0f) P2=(%.0f,%.0f) reset1=(%.0f,%.0f)" % [$Frog.stage, $Frog.noise, a.x, a.y, b.x, b.y, $Reset/RP1.global_position.x, $Reset/RP1.global_position.y])


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【眠るカエル】1キー: 小さな音(寝返り) 2キー: 大きな音(怒る→やり直し)。カエルの下のメーターが騒がしさ"
