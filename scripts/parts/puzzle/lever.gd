@tool
class_name Lever
extends PuzzlePart
## レバー。手を伸ばして(LB/RB)つかみ、レバーから離れる方向へスティックを倒すと引ける。
## 引いている人と、その人と手をつないでいる人を数え、required_players 人以上の時だけ動く。
## 引くたびに位置が一段階ずつ変わり、今の位置をシグナルで知らせる。

## 位置が変わった(0 〜 positions-1)
signal position_changed(index: int)
signal pulled
## 人数が足りずに引けなかった
signal pull_failed

enum Mode { WRAP, PINGPONG, CLAMP }

## 段階の数
@export_range(2, 16) var positions := 2:
	set(v):
		positions = v
		queue_redraw()
## 最初の位置
@export var start_position := 0
## 動かすのに必要な人数(手をつないだ二人を数える)
@export_range(1, 2) var required_players := 2
## 最後まで行ったら:WRAP = 最初に戻る / PINGPONG = 折り返す / CLAMP = 止まる
@export var mode := Mode.WRAP
## つかめる距離(px)
@export var grab_radius := 14.0
## 引き続ける時間(秒)
@export var pull_time := 0.35

var current := 0
var _dir := 1
var _holder: Player
var _holder_side := 0
var _pull := 0.0
var _armed := true   # 一度引いたら、離すか戻すまで次は引けない
var _fail_cooldown := 0.0


func _ready() -> void:
	super._ready()
	current = clampi(start_position, 0, positions - 1)
	process_physics_priority = 20


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority():
		return
	_fail_cooldown -= delta
	# つかむ・離す
	if _holder and not (is_instance_valid(_holder) and is_reaching(_holder, _holder_side)):
		_release()
	if _holder == null:
		var g := find_grabber(global_position, grab_radius)
		if not g.is_empty():
			_holder = g[0]
			_holder_side = g[1]
			_holder.held_objects[_holder_side] = self
			_armed = true
			_pull = 0.0
	if _holder == null:
		return
	hold_hand(_holder, _holder_side, global_position)
	# 引く(レバーから離れる方向にスティックを倒す)
	var away := (_holder.global_position - global_position).normalized()
	var push: float = _holder.input.move.dot(away)
	if push > 0.5:
		_pull += delta
	else:
		_pull = 0.0
		if push < 0.2:
			_armed = true
	if _pull >= pull_time and _armed:
		_armed = false
		_pull = 0.0
		if count_pullers() >= required_players:
			_advance()
		elif _fail_cooldown <= 0.0:
			_fail_cooldown = 0.5
			pull_failed.emit()


func count_pullers() -> int:
	if _holder == null:
		return 0
	var n := 1
	if Hands.is_player_linked(_holder):
		n += 1
	return n


func _release() -> void:
	if is_instance_valid(_holder):
		_holder.held_objects[_holder_side] = null
		release_hand(_holder, _holder_side)
	_holder = null


func _advance() -> void:
	var next := current + _dir
	match mode:
		Mode.WRAP:
			next = posmod(next, positions)
		Mode.PINGPONG:
			if next >= positions or next < 0:
				_dir = -_dir
				next = current + _dir
		Mode.CLAMP:
			next = clampi(next, 0, positions - 1)
	if next == current:
		return
	set_position_index(next)
	pulled.emit()


## 位置を直接決める(リセットなど)
func set_position_index(i: int) -> void:
	if not is_authority():
		return
	current = clampi(i, 0, positions - 1)
	queue_redraw()
	position_changed.emit(current)
	sync_state()


func reset() -> void:
	set_position_index(start_position)


func get_state() -> Dictionary:
	return { current = current }


func apply_state(s: Dictionary) -> void:
	if s.current != current:
		current = s.current
		queue_redraw()
		position_changed.emit(current)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var base := lift()
	draw_box(base, Vector2(14, 8), Color("7b7f86"), Color("4c4f55"), 0.5)
	var lp := WorldConfig.get_default().level_px
	var pivot := base + Vector2(0, -0.5 * lp)
	var f := float(current) / maxf(positions - 1, 1)
	var ang := lerpf(-PI * 0.75, -PI * 0.25, f)
	var tip := pivot + Vector2.from_angle(ang) * 14.0
	draw_line(pivot, tip, Color("c9a35a"), 2.5)
	draw_circle(tip, 2.5, Color("e05a4a") if _holder else Color("f0e0c0"))
	for i in range(positions):
		var a := lerpf(-PI * 0.75, -PI * 0.25, float(i) / maxf(positions - 1, 1))
		draw_circle(pivot + Vector2.from_angle(a) * 17.0, 1.0, Color.WHITE if i == current else Color(1, 1, 1, 0.35))
