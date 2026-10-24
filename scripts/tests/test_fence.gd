extends TestSceneBase
## 柵(Fence)の確認用シーン。
## ・プレイヤーは柵を通れない(下へ歩いても柵の手前で止まる)
## ・綿毛も柵で止まる(1キーで上から押す)
## ・音の波は柵を通り抜け、柵の向こうの受け手(R)に届く
## ・斜め(ノードの回転)・縦(angle_deg)に置いても、杭は上に立つ


func _ready() -> void:
	super._ready()
	watch("R", ["wave_received"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_1:
		$EF.emit()


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 1.5, p = 1, move = Vector2.DOWN, log = "P1 walks down into the fence" },
		{ t = 0.1, call = "report_player", log = "expect P1 stopped above the fence" },
		{ t = 1.2, call = "push" },
		{ t = 1.2, call = "push" },
		{ t = 1.5, call = "report_fluff", log = "expect fluff stopped above the fence, R received the wave" },
		{ t = 2.5, call = "look_side", log = "P1 next to the diagonal / vertical fences (visual check)" },
	]


func look_side() -> void:
	place(1, cell(Vector2(14, 8)))


func push() -> void:
	$EF.emit()


func report_player() -> void:
	var p := World.get_player_by_index(1)
	print("[AUTO] P1.y=%.0f fence.y=%.0f blocked=%s" % [p.global_position.y, $FenceH.global_position.y, p.global_position.y < $FenceH.global_position.y])


func report_fluff() -> void:
	print("[AUTO] fluff.y=%.0f fence.y=%.0f blocked=%s" % [$Fluff.global_position.y, $FenceH.global_position.y, $Fluff.global_position.y < $FenceH.global_position.y])


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【柵】人も綿毛も通さないが、音の波は通る。1キー: 上から綿毛を押す(波は柵の向こうの R にも届く) / 右の2つは斜め・縦に置いた柵"
