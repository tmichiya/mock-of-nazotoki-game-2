extends TestSceneBase
## 記号の暗号(記号の絵・記号の床・入力台)の確認用シーン。
## ・絵(Picture)に答えの記号が並ぶ。声で相手に伝え、記号の床を順に踏んで入力する
## ・間違えると入力が消えて、絵の記号がランダムに変わる
## ・正解すると入力台が緑になり、code_done をクリア → 扉が開く


func _ready() -> void:
	super._ready()
	watch("Lock", ["code_changed", "input_changed", "wrong", "solved"])


func _steps() -> Array:
	return [
		{ t = 0.5, call = "report", log = "start" },
		{ t = 0.3, call = "step_wrong_0" },
		{ t = 0.3, call = "step_off" },
		{ t = 0.3, call = "step_wrong_1" },
		{ t = 0.3, call = "step_off" },
		{ t = 0.3, call = "step_wrong_2" },
		{ t = 0.3, call = "step_off" },
		{ t = 1.3, call = "report", log = "after a wrong input: expect wrong, new code" },
		{ t = 0.3, call = "step_right_0" },
		{ t = 0.3, call = "step_off" },
		{ t = 0.3, call = "step_right_1" },
		{ t = 0.3, call = "step_off" },
		{ t = 0.3, call = "step_right_2" },
		{ t = 0.3, call = "step_off" },
		{ t = 0.8, call = "report", log = "after the right input: expect solved, door open" },
	]


var _wrong := PackedInt32Array()


func _pad_for(symbol: int) -> SymbolPad:
	for p in $Lock.pads():
		if p.symbol == symbol:
			return p
	return null


func _step(symbol: int) -> void:
	place(1, _pad_for(symbol).global_position)


## 答えと違う記号を最後に入れて、わざと間違える
func step_wrong_0() -> void:
	var code: PackedInt32Array = $Lock.code
	_wrong = code.duplicate()
	for p in $Lock.pads():
		if p.symbol != code[2]:
			_wrong[2] = p.symbol
			break
	_step(_wrong[0])


func step_wrong_1() -> void:
	_step(_wrong[1])


func step_wrong_2() -> void:
	_step(_wrong[2])


func step_right_0() -> void:
	_step($Lock.code[0])


func step_right_1() -> void:
	_step($Lock.code[1])


func step_right_2() -> void:
	_step($Lock.code[2])


func step_off() -> void:
	place(1, cell(Vector2(3, 11)))


func report() -> void:
	print("[AUTO] code=%s entered=%s solved=%s door.open=%s" % [$Lock.code, $Lock.entered, $Lock.is_solved, $Door.is_open])


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【記号の暗号】絵の記号を声で伝え、記号の床を順に踏んで入力 → 入力台で判定。間違えると絵の記号が変わる。正解で扉が開く"
