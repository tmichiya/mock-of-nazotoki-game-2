@tool
class_name SleepingFrog
extends PuzzlePart
## 眠るカエル。届いた音の波の強さが溜まっていき、寝返り → 薄目 → 怒る、と段階が進む。
## 時間がたつと落ち着く。怒ると failed を出す(PuzzleReset の reset() につなぐと謎をやり直せる)。
## 声の波も、物がぶつかる音の波も対象。

signal stage_changed(stage: int)
signal tossed
signal peeked
signal failed
signal calmed

enum Stage { SLEEP, TOSS, PEEK, ANGRY }

## 寝返りになる騒がしさ
@export var toss_threshold := 1.0
## 薄目になる騒がしさ
@export var peek_threshold := 2.0
## 怒る騒がしさ
@export var angry_threshold := 3.0
## 落ち着く速さ(騒がしさが1秒に減る量)
@export var calm_rate := 0.5
## 波の強さに掛ける倍率(敏感さ)
@export var sensitivity := 1.0
## 怒ってから眠りに戻るまでの時間(秒)
@export var angry_time := 2.5
## 反応する波の種類(空なら全部)
@export var hear_kinds: Array[StringName] = []
## 聞こえる範囲の半径(px)
@export var ear_radius := 14.0
## 怒った時に、この PuzzleReset の reset() を呼ぶ(空ならシグナルだけ)
@export var reset_on_angry: NodePath

var noise := 0.0
var stage := Stage.SLEEP
var _angry_left := 0.0
var _receiver: WaveReceiver


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_receiver = WaveReceiver.new()
	_receiver.radius = ear_radius
	_receiver.accept_kinds = hear_kinds
	_receiver.level_mode = WaveReceiver.LevelMode.FIXED
	_receiver.fixed_level = get_level()
	add_child(_receiver)
	_receiver.wave_received_info.connect(_on_wave)


func _on_wave(info: Dictionary) -> void:
	if not is_authority() or stage == Stage.ANGRY:
		return
	noise += float(info.strength) * sensitivity
	_update_stage()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_authority():
		return
	if stage == Stage.ANGRY:
		_angry_left -= delta
		if _angry_left <= 0.0:
			noise = 0.0
			_set_stage(Stage.SLEEP)
			calmed.emit()
		return
	if noise > 0.0:
		noise = maxf(0.0, noise - calm_rate * delta)
		_update_stage()


func _update_stage() -> void:
	var s := Stage.SLEEP
	if noise >= angry_threshold:
		s = Stage.ANGRY
	elif noise >= peek_threshold:
		s = Stage.PEEK
	elif noise >= toss_threshold:
		s = Stage.TOSS
	if s != stage:
		if stage != Stage.SLEEP and s == Stage.SLEEP:
			calmed.emit()
		_set_stage(s)
		match s:
			Stage.TOSS: tossed.emit()
			Stage.PEEK: peeked.emit()
			Stage.ANGRY:
				_angry_left = angry_time
				failed.emit()
				var r := get_node_or_null(reset_on_angry)
				if r and r.has_method("reset"):
					r.reset()


func _set_stage(s: int) -> void:
	stage = s
	queue_redraw()
	stage_changed.emit(s)
	sync_state()


## 起こした状態をなかったことにする
func reset() -> void:
	if not is_authority():
		return
	noise = 0.0
	_set_stage(Stage.SLEEP)


func get_state() -> Dictionary:
	return { stage = stage }


func apply_state(s: Dictionary) -> void:
	if s.stage != stage:
		stage = s.stage
		queue_redraw()
		stage_changed.emit(stage)


func _draw() -> void:
	var base := lift()
	var body := base + Vector2(0, -6)
	var col := Color("6fae5c")
	if stage == Stage.ANGRY:
		col = Color("d0503c")
	draw_circle(base, 8.0, Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array()
	var tilt := 0.25 if stage == Stage.TOSS else 0.0
	for i in range(18):
		var a := TAU * i / 18.0
		pts.append(body + Vector2(cos(a) * 10.0, sin(a) * 6.0).rotated(tilt))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.6), 1.0)
	# 目
	for sx in [-4.0, 4.0]:
		var e := body + Vector2(sx, -5).rotated(tilt)
		draw_circle(e, 2.5, col.lightened(0.2))
		match stage:
			Stage.SLEEP, Stage.TOSS:
				draw_line(e + Vector2(-1.5, 0), e + Vector2(1.5, 0), Color.BLACK, 1.0)
			Stage.PEEK:
				draw_line(e + Vector2(-1.5, 0), e + Vector2(1.5, 0), Color.BLACK, 1.0)
				draw_circle(e + Vector2(0, 0.6), 0.8, Color.BLACK)
			Stage.ANGRY:
				draw_circle(e, 1.3, Color.BLACK)
				draw_line(e + Vector2(-2, -2.5), e + Vector2(2, -1.5 if sx < 0 else -3.5), Color.BLACK, 1.0)
	if stage == Stage.SLEEP:
		draw_string(ThemeDB.fallback_font, body + Vector2(8, -10), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	# 騒がしさのメーター
	if not Engine.is_editor_hint() and noise > 0.0:
		var w := 20.0 * clampf(noise / angry_threshold, 0.0, 1.0)
		draw_rect(Rect2(base + Vector2(-10, 4), Vector2(20, 2)), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(base + Vector2(-10, 4), Vector2(w, 2)), Color(1, 0.8, 0.3))
