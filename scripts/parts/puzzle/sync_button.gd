@tool
class_name SyncButton
extends PuzzlePart
## だいたい同時に踏まないと駄目なボタン。同じ sync_group の名前のボタンを全部、window 秒以内に踏むと成功。
## 見た目で「同時に押す物だ」と分かるように、同じ組のボタンの数だけ点が並ぶ(成功すると全部光る)。
## 色: 待機(idle)/ 踏まれて他を待っている(waiting。残り時間の輪が縮む)/ 失敗(fail。cooldown 秒は押せない)/ 成功(success)
## 待っている色と輪は「踏まれているボタン」にだけ出す。まだ踏まれていない側は待機の見た目のまま
## (見た目で「今押せ」と分からないようにする。タイミングは声やギミックで合わせる)
## 成功したら clear_event を知らせる(組のどのボタンに書いてもよい)。

signal pressed
signal waiting_started
signal failed
signal succeeded

enum St { IDLE, WAITING, FAIL, SUCCESS }

## 同時に踏む組の名前(同じ名前のボタンが同じ組)
@export var sync_group: StringName = &"A"
## 最初に踏まれてから、他のボタンを待つ時間(秒)
@export var window := 1.5
## 失敗した後に押せない時間(秒。連打を防ぐ)
@export var fail_cooldown := 3.0
## 成功したら、そのまま成功の色で止まる(false なら少しして待機に戻り、何度でも成功できる)
@export var stay_success := true
## 成功した時に知らせる「○○をクリア」の名前
@export var clear_event: StringName = &""
## 乗っているとみなす半径(px)
@export var radius := 10.0:
	set(v):
		radius = v
		queue_redraw()
@export var color_idle := Color("8fa3b8")
@export var color_waiting := Color("f2c14e")
@export var color_fail := Color("d0503c")
@export var color_success := Color("6fd08c")

## 組の状態(ホストが決める)。組の中のボタンで共有する
static var _groups := {}

var state := St.IDLE
## 今の待ち時間の中で、このボタンが踏まれたか(待っている色はこのボタンにだけ出す)
var mine := false
var is_down := false
var _was_down := false
var _wait_left := 0.0       # 見た目用(残り時間の割合)
var _group_size := 1
var _group_down := 0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group("sync_button")
	_groups.erase(sync_group)


func _members() -> Array:
	return get_tree().get_nodes_in_group("sync_button").filter(func(b): return b.sync_group == sync_group)


func _g() -> Dictionary:
	if not _groups.has(sync_group):
		_groups[sync_group] = { state = St.IDLE, t0 = 0.0, until = 0.0, pressed = {}, leader = null }
	return _groups[sync_group]


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var members := _members()
	_group_size = members.size()
	if not is_authority():
		queue_redraw()
		return
	is_down = _someone_on_me()
	var g := _g()
	var now := Waves.clock
	var edge := is_down and not _was_down
	_was_down = is_down
	# 組の計算は、組の中で最初のボタンだけが行う
	if g.leader == null or not is_instance_valid(g.leader):
		g.leader = self
	if edge:
		pressed.emit()
		match g.state:
			St.IDLE:
				g.state = St.WAITING
				g.t0 = now
				g.pressed = { self: true }
				waiting_started.emit()
			St.WAITING:
				g.pressed[self] = true
	if g.leader == self:
		_update_group(g, members, now)
	_group_down = g.pressed.size()
	var st: int = g.state
	var m: bool = g.pressed.has(self)
	if st != state or m != mine:
		var changed_state := st != state
		state = st
		mine = m
		if changed_state:
			match st:
				St.FAIL: failed.emit()
				St.SUCCESS: succeeded.emit()
		sync_state()
	_wait_left = clampf(1.0 - (now - g.t0) / maxf(window, 0.01), 0.0, 1.0) if st == St.WAITING else 0.0
	queue_redraw()


func _update_group(g: Dictionary, members: Array, now: float) -> void:
	match g.state:
		St.WAITING:
			if g.pressed.size() >= members.size():
				g.state = St.SUCCESS
				g.until = now + 1.0
				Clears.clear(_group_clear_event(members))
			elif now - g.t0 > window:
				g.state = St.FAIL
				g.until = now + fail_cooldown
				g.pressed = {}
		St.FAIL:
			if now >= g.until:
				g.state = St.IDLE
		St.SUCCESS:
			if not stay_success and now >= g.until:
				g.state = St.IDLE
				g.pressed = {}


func _group_clear_event(members: Array) -> StringName:
	for b in members:
		if b.clear_event != &"":
			return b.clear_event
	return &""


func _someone_on_me() -> bool:
	for p: Player in World.get_players():
		if p.global_position.distance_to(global_position) <= radius and absf(p.height - height) < 0.5 and not p.is_airborne():
			return true
	for o in get_tree().get_nodes_in_group("props"):
		if o is Node2D and o.global_position.distance_to(global_position) <= radius:
			return true
	return false


## 組を待機に戻す(やり直しなど)
func reset() -> void:
	if not is_authority():
		return
	var g := _g()
	g.state = St.IDLE
	g.pressed = {}
	Clears.reset_clear(_group_clear_event(_members()))


func get_state() -> Dictionary:
	return { state = state, down = _group_down, mine = mine }


func apply_state(s: Dictionary) -> void:
	if s.state != state:
		state = s.state
		match state:
			St.FAIL: failed.emit()
			St.SUCCESS: succeeded.emit()
	_group_down = s.down
	mine = s.get("mine", false)
	queue_redraw()


func _color() -> Color:
	match state:
		St.WAITING: return color_waiting if mine else color_idle
		St.FAIL: return color_fail
		St.SUCCESS: return color_success
	return color_idle


func _draw() -> void:
	var base := lift()
	var col := _color()
	var r := Vector2(radius, radius * 0.7)
	var sink := 0.0 if (not Engine.is_editor_hint() and is_down) else -2.0
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(base + Vector2(cos(a) * r.x, sin(a) * r.y + sink))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.6), 1.0)
	# 同じ組の数だけ点(踏まれた分だけ光る)。「同時に押す物」の目印
	var n := maxi(_group_size, 2) if not Engine.is_editor_hint() else 2
	for i in range(n):
		var c := base + Vector2(-(n - 1) * 3.0 + i * 6.0, -radius * 0.7 - 6)
		var lit := not Engine.is_editor_hint() and state == St.SUCCESS
		draw_circle(c, 2.0, col.lightened(0.4) if lit else Color(0, 0, 0, 0.45))
	# 待っている間の残り時間の輪
	if state == St.WAITING and mine and _wait_left > 0.0:
		draw_arc(base + Vector2(0, sink), radius + 3.0, -PI * 0.5, -PI * 0.5 + TAU * _wait_left, 24, color_waiting, 1.5)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, base + Vector2(-4, 3), str(sync_group), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
