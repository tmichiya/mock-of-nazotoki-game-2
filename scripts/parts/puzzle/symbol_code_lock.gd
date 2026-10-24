@tool
class_name SymbolCodeLock
extends PuzzlePart
## 記号の暗号の「入力台と正解判定」。答えの記号の並び(code)をランダムに決めて持つ。
## 記号の床(SymbolPad)を踏んだ順に記号が入力され、入力台に並ぶ。code_length 個そろうと判定する。
## 答えは記号の絵(SymbolCodePicture)に表示する(絵は離れた所に置いてよい。声で相手に伝える)。
## 間違えると、入力が消えて答えがランダムに変わる(reshuffle_on_wrong)。
## 答えに使う記号は、この入力台につないだ記号の床の記号から選ぶ(床が無ければ記号のセットの先頭から)。

signal code_changed(code: PackedInt32Array)
signal input_changed(entered: PackedInt32Array)
signal solved
signal wrong

## 記号のセット(空なら res://resources/symbols/symbols_default.tres)
@export var symbol_set: SymbolSet:
	set(v):
		symbol_set = v
		queue_redraw()
## 伝える記号の数
@export_range(1, 12) var code_length := 3:
	set(v):
		code_length = v
		queue_redraw()
## 同じ記号が答えに何度出てもよい(false でも、記号の種類が足りない時は重なる)
@export var allow_repeat := false
## 間違えたら答えをランダムに変える
@export var reshuffle_on_wrong := true
## 間違えた後、入力を受け付けない時間(秒)
@export var wrong_cooldown := 1.0
## 正解したらそのまま止まる(false なら少しして新しい答えで何度でも)
@export var stay_solved := true
## 正解した時に知らせる「○○をクリア」の名前
@export var clear_event: StringName = &""
## 床が無い時に答えに使う記号の数(記号のセットの先頭から)
@export var fallback_choices := 6
## 入力台に並ぶ記号の大きさ(px)
@export var symbol_size := 10.0:
	set(v):
		symbol_size = v
		queue_redraw()
@export var color_idle := Color("d8d2c0")
@export var color_wrong := Color("d0503c")
@export var color_solved := Color("6fd08c")

var code := PackedInt32Array()
var entered := PackedInt32Array()
var is_solved := false
var _flash := 0.0       # 間違い・正解の光(見た目用)
var _cool := 0.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group("symbol_code_lock")
	# これから参加する端末は、ホストから答えが届くのを待つ
	if is_authority() and Net.auto_join_ip == "":
		_new_code.call_deferred()


func _get_set() -> SymbolSet:
	if symbol_set == null:
		symbol_set = load("res://resources/symbols/symbols_default.tres")
	return symbol_set


## この入力台につながっている記号の床
func pads() -> Array:
	if not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group("symbol_pad").filter(func(p): return p.get_lock() == self)


## 答えに使える記号
func choices() -> PackedInt32Array:
	var c := PackedInt32Array()
	for p in pads():
		if not c.has(p.symbol):
			c.append(p.symbol)
	if c.is_empty():
		for i in range(mini(fallback_choices, _get_set().count())):
			c.append(i)
	return c


func _new_code() -> void:
	var pool := choices()
	if pool.is_empty():
		return
	var c := PackedInt32Array()
	var bag := Array(pool)
	bag.shuffle()
	for i in range(code_length):
		if allow_repeat or bag.is_empty():
			c.append(pool[randi() % pool.size()])
		else:
			c.append(bag.pop_back())
	# 前と同じ答えにはしない(間違えた後に変わったと分かるように)
	if c == code and (pool.size() > 1 or code_length > 1):
		_new_code()
		return
	code = c
	entered = PackedInt32Array()
	code_changed.emit(code)
	input_changed.emit(entered)
	sync_state()
	queue_redraw()


# ---------------------------------------------------------------- 受け口

## 記号を1つ入力する(記号の床が呼ぶ。シグナルから直接つないでもよい)
func input_symbol(symbol: int) -> void:
	if not is_authority() or is_solved or _cool > 0.0 or code.is_empty():
		return
	entered.append(symbol)
	input_changed.emit(entered)
	if entered.size() >= code_length:
		_judge()
	sync_state()
	queue_redraw()


## 入力を消す
func clear_input() -> void:
	if not is_authority() or is_solved:
		return
	entered = PackedInt32Array()
	input_changed.emit(entered)
	sync_state()
	queue_redraw()


## 答えをランダムに変える
func reshuffle() -> void:
	if is_authority():
		_new_code()


## 最初からやり直す(正解も取り消す)
func reset() -> void:
	if not is_authority():
		return
	is_solved = false
	Clears.reset_clear(clear_event)
	_new_code()


func _judge() -> void:
	if entered == code:
		is_solved = true
		_flash = 1.0
		solved.emit()
		Clears.clear(clear_event)
		if not stay_solved:
			_cool = 1.5
	else:
		_flash = -1.0
		_cool = wrong_cooldown
		wrong.emit()
		if reshuffle_on_wrong:
			_new_code()
		else:
			entered = PackedInt32Array()
			input_changed.emit(entered)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _flash != 0.0:
		_flash = move_toward(_flash, 0.0, delta * 1.2) if not is_solved else 1.0
		queue_redraw()
	if _cool > 0.0:
		_cool -= delta
		if _cool <= 0.0 and is_solved and not stay_solved and is_authority():
			is_solved = false
			_flash = 0.0
			_new_code()


func get_state() -> Dictionary:
	return { code = code, entered = entered, solved = is_solved, flash = _flash }


func apply_state(s: Dictionary) -> void:
	if s.code != code:
		code = s.code
		code_changed.emit(code)
	if s.entered != entered:
		entered = s.entered
		input_changed.emit(entered)
	if s.solved and not is_solved:
		solved.emit()
	elif s.flash < 0.0 and _flash >= 0.0:
		wrong.emit()
	is_solved = s.solved
	_flash = s.flash
	queue_redraw()


# ---------------------------------------------------------------- 見た目(入力台)

func _draw() -> void:
	var base := lift()
	var n := code_length
	var pad := 3.0
	var board := Vector2(n * (symbol_size + pad) + pad, symbol_size + pad * 2)
	var h := 1.0 * WorldConfig.get_default().level_px
	# 台(石の台座)
	draw_box(base, Vector2(board.x + 6, 10), Color("9a958a"), Color("6e6a61"), 1.0)
	var top_left := base + Vector2(-board.x * 0.5, -h - 5 - board.y * 0.5)
	var col := color_idle
	if _flash > 0.0:
		col = col.lerp(color_solved, _flash)
	elif _flash < 0.0:
		col = col.lerp(color_wrong, -_flash)
	draw_rect(Rect2(top_left, board), col)
	draw_rect(Rect2(top_left, board), Color(0, 0, 0, 0.6), false, 1.0)
	for i in range(n):
		var c := top_left + Vector2(pad + symbol_size * 0.5 + i * (symbol_size + pad), board.y * 0.5)
		if i < entered.size():
			_get_set().draw_symbol(self, entered[i], c, symbol_size, Color("2b2622"))
		else:
			# まだ入力していない枠
			draw_rect(Rect2(c - Vector2.ONE * symbol_size * 0.5, Vector2.ONE * symbol_size), Color(0, 0, 0, 0.18), false, 1.0)
