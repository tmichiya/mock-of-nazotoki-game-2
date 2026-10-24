@tool
class_name IslandChangeReactor
extends PuzzlePart
## 島の変化に反応する物。捧げる場所(OfferingPlace)から広がる「歌の波」が、
## 指定した段階で届いたら、現れる・消える・落ちる・移動する。
## 見た目や当たり判定は、この部品の子に置いた物がまとめて動く(子が無い時は仮の箱を描く)。
## 落ちる(FALL)は、下へ落ちながら薄くなって消える(地面の位置は変えずに下へ描くので、
## 残しておくと手前の地面にめり込んで見えるため)。落ちた先に残したい時は MOVE を使う。

signal changed
signal appeared
signal disappeared
signal fell
signal moved

enum Action { APPEAR, DISAPPEAR, FALL, MOVE }
enum Compare { EXACT, AT_LEAST }

## 変化した時に知らせる「○○をクリア」の名前(空なら知らせない)
@export var clear_event: StringName = &""
## 何回目の捧げ(歌の波の段階)で反応するか
@export var stage := 1
## EXACT = その段階の時だけ / AT_LEAST = その段階以上なら
@export var compare := Compare.AT_LEAST
@export var action := Action.APPEAR:
	set(v):
		action = v
		queue_redraw()
## MOVE の時の移動量(px)
@export var move_offset := Vector2(0, -32)
## FALL の時に落ちる段数
@export var fall_levels := 2.0
## 変化にかかる時間(秒)
@export var duration := 0.8
## 落ちた・消えた後は当たり判定を無くす
@export var disable_collision_after := true
## 子が無い時に描く仮の箱の大きさ
@export var placeholder_size := Vector2(24, 16)

var done := false
var _t := 0.0        # 変化の進み 0〜1
var _start_pos := Vector2.ZERO
var _child_start := {}   # FALL で下げる子 -> 元の位置


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_start_pos = position
	var rcv := WaveReceiver.new()
	rcv.radius = 4.0
	rcv.level_mode = WaveReceiver.LevelMode.FIXED
	rcv.fixed_level = -99   # 普通の波は届かない(歌の波は段に関係なく届く)
	add_child(rcv)
	rcv.wave_received_info.connect(_on_wave)
	if action == Action.APPEAR:
		_set_visible_content(false)


func _on_wave(info: Dictionary) -> void:
	if not info.is_global or done or not is_authority():
		return
	var st: int = info.stage
	var ok := st == stage if compare == Compare.EXACT else st >= stage
	if ok:
		trigger()


## 変化させる(シグナルから直接呼んでもよい)
func trigger() -> void:
	if done or not is_authority():
		return
	_begin()
	sync_state()


func _begin() -> void:
	done = true
	_t = 0.0
	if action == Action.APPEAR:
		_set_visible_content(true)
	changed.emit()
	if is_authority():
		Clears.clear(clear_event)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not done or _t >= 1.0:
		return
	_t = minf(1.0, _t + delta / maxf(duration, 0.01))
	match action:
		Action.MOVE:
			position = _start_pos + move_offset * _smooth(_t)
		Action.FALL:
			modulate.a = 1.0 - _t
			var drop := Vector2(0, fall_amount() * WorldConfig.get_default().level_px)
			for c in get_children():
				if c is Node2D and not (c is WaveReceiver):
					if not _child_start.has(c):
						_child_start[c] = c.position
					c.position = _child_start[c] + drop
		Action.DISAPPEAR:
			modulate.a = 1.0 - _t
	queue_redraw()
	for c in get_children():
		if c is CanvasItem:
			c.queue_redraw()
	if _t >= 1.0:
		_finish()


func _finish() -> void:
	match action:
		Action.APPEAR:
			appeared.emit()
		Action.DISAPPEAR:
			_set_visible_content(false)
			disappeared.emit()
		Action.FALL:
			_set_visible_content(false)
			fell.emit()
		Action.MOVE:
			moved.emit()
	if disable_collision_after and action in [Action.DISAPPEAR, Action.FALL]:
		_set_collision(self, false)


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## 落ちている量(段)。子の見た目が使えるように公開する
func fall_amount() -> float:
	return fall_levels * _t * _t if action == Action.FALL and done else 0.0


func _set_visible_content(v: bool) -> void:
	visible = v
	_set_collision(self, v)


func _set_collision(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", not on)
		_set_collision(c, on)


func get_state() -> Dictionary:
	return { done = done }


func apply_state(s: Dictionary) -> void:
	if s.done and not done:
		_begin()


func _draw() -> void:
	var has_visual := false
	for c in get_children():
		if c is CanvasItem and not (c is WaveReceiver):
			has_visual = true
	if has_visual:
		return
	var levels := 1.0
	var off := lift(-fall_amount())
	var col := Color("9fc7d9")
	if Engine.is_editor_hint() and action == Action.APPEAR:
		col.a = 0.4
	draw_box(off, placeholder_size, col, col.darkened(0.35), levels)
	draw_label("段階%d" % stage, off + Vector2(0, -levels * 12 - 10), Color.WHITE, 8)
