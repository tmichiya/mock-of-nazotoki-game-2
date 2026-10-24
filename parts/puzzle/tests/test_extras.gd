extends TestSceneBase
## 余裕があれば(O)の部品の確認用シーン。
## ・綿毛:波に押されて流れる(1キーで左の音源)
## ・重なる点の石:二つの音源 EA・EB の波が同時に届いた時だけ光る(2キー:同時 / 3キー:ずらす)
## ・糸電話:二人で両端を握り、張って何にも引っかかっていない間だけ声が届く
## ・ラッパ:つかんで持つと、声の波が向いている方向に扇形で遠くまで届く


func _ready() -> void:
	super._ready()
	watch("Stone", ["lit", "dimmed"])
	watch("Phone", ["connected", "disconnected"])
	watch("Trumpet", ["picked_up", "put_down"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1: $EFluff.emit()
			KEY_2: both()
			KEY_3: staggered()


func both() -> void:
	$EA.emit()
	$EB.emit()


func staggered() -> void:
	$EA.emit()
	get_tree().create_timer(0.4).timeout.connect($EB.emit)


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 1.5, call = "staggered", log = "staggered: expect stone NOT lit" },
		{ t = 1.5, call = "both", log = "together: expect stone lit" },
		{ t = 0.1, call = "phone_ends" },
		{ t = 0.4, p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 2.2, p1 = { grab_r = true, move = Vector2.LEFT }, p2 = { grab_l = true, move = Vector2.RIGHT } },
		{ t = 0.1, call = "report", log = "phone stretched: expect connected", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.3 },
		{ t = 0.1, call = "trumpet" },
		{ t = 0.4, p1 = { grab_l = true } },
		{ t = 0.1, call = "report", log = "holding trumpet: expect picked_up and voice_modifier set", p1 = { grab_l = true } },
	]


func phone_ends() -> void:
	place(1, $Phone.global_position + Vector2(-18, 0))
	place(2, $Phone.global_position + Vector2(18, 0))


func trumpet() -> void:
	place(1, $Trumpet.global_position + Vector2(-4, 0))


func report() -> void:
	var p1 := World.get_player_by_index(1) as Player
	print("[AUTO] phone=%s voice_partner(P1)=%s trumpet_modifier=%s" % [$Phone.is_connected_now, Hands.voice_partner(p1) != null, p1.voice_modifier])
