class_name Player
extends CharacterBody2D
## プレイヤー。地面の上を動き(position = 地面の位置)、高さ height(段)は足元の地形から決まる。
## 見た目は height の分だけ上にずらして描き、影は常に足元の地形の高さに描く。
##
## 操作: 左スティック移動 / トリガー長押しでポーズ(止まってカメラ側を向き、両スティックで両腕)/
##       L3・R3 長押しでその腕を挙げる / LB・RB 長押しで左手・右手で握る / A で崖の縁から滑空
## 「左腕」は、カメラ側を向いた時に画面の左に来る腕。
##
## 腕は「紙人形方式」:体は絵、腕は「肩から手への線+目立つ色の丸い手」をプログラムで描く。
## 腕の向きは 3D のベクトル(x = 画面の右、y = 手前、z = 上)で持ち、描く時に画面へ写す。
## 判定(手つなぎ・つかむ)は地面の上の位置で行い、描く倍率はかけない。

signal state_changed(new_state: int)
signal glide_started
signal landed
signal pose_changed(posing: bool)
signal wave_touched(source_id: String, strength: float)

enum State { WALK, POSE, GLIDE, FLY, HANG, CLIMB }
## 腕(手)。Godot には Side というグローバルの enum があるので、名前は Hand にしている
enum Hand { LEFT, RIGHT }
## 体の向き(体の絵を選ぶ・肩の位置を決める)
enum BodyDir { DOWN, UP, LEFT, RIGHT }

@export_group("見た目")
## 体の色(2人の見分けに使う)
@export var body_color := Color("e8804a"):
	set(v):
		body_color = v
		if is_inside_tree():
			_update_colors()
## 手の色(体と別の目立つ色。手をつないでいるかが一目で分かるように)
@export var hand_color := Color(1.0, 0.93, 0.55)
## 体の大きさ(px)。物陰の判定と輪郭に使う
@export var body_size := Vector2(12, 18)

@export_group("移動")
## 歩く速さ(px/秒)
@export var move_speed := 72.0
## 加速の速さ(大きいほどキビキビ)
@export var acceleration := 900.0
## 走る速さ(歩く速さの何倍か)。走る/歩くは Y ボタン(キーボードは Ctrl)で切り替え、止まると歩きに戻る
@export var run_speed_scale := 1.5
## 止まってから歩きに戻るまでの時間(秒)
@export var run_stop_time := 0.25
## 走っている時に体を上下に揺らす量(px)と速さ(1秒に何回)
@export var run_bob_px := 1.5
@export var run_bob_hz := 4.0
## 歩いている時に体を上下に揺らす量(px。0 で揺らさない)
@export var walk_bob_px := 0.0

@export_group("つかむ")
## ポーズ中に腕を伸ばすと、その手は自動で「握る」(近くの物や相手の手をつかむ)。離すのは B ボタン(キーボードは X)
@export var auto_grab := true

@export_group("滑空")
## 足元との高さの差がこの段数以上ある崖の縁で滑空できる
@export var min_glide_levels := 1
## 落ちる速さ(段/秒)
@export var glide_fall_speed := 1.4
## 前に進む速さ(px/秒)
@export var glide_forward_speed := 85.0
## 滑空中に左右へ曲がれる速さ(px/秒)。0で真っすぐだけ
@export var glide_steer_speed := 25.0
## 崖の縁を探す距離(px)
@export var glide_edge_probe := 12.0

@export_group("飛ぶ(回転投げ・反動)")
## 飛んでいる時の重力(段/秒²)
@export var fly_gravity := 9.0

@export_group("腕")
## 腕の長さ(px)。手つなぎ・つかむ判定に使う長さ(描く倍率はかけない)
@export var arm_length := 13.0
## 目標の向きへ追いつく速さ(つないでいる時は × 2)
@export var arm_follow := 16.0
## ポーズ中、スティックをこれ以上倒すと腕を伸ばす
@export_range(0.1, 0.95) var arm_deadzone := 0.5
## スナップ数(0 = 無段階、8 = 8 方向)
@export_range(0, 16) var arm_snap_directions := 0
## L3/R3 で挙げた時の仰角(度)。スティックを倒していなければ真上
@export_range(0.0, 90.0) var raise_angle_deg := 60.0
## 下ろした向き(左腕。右腕は x を反転)。x = 画面の右、y = 手前、z = 上
@export var rest_arm_direction := Vector3(-0.35, 0.15, -1.0)
## 肩の位置(足元から、画面上。x は右肩の位置、左肩は反転)
@export var shoulder_offset := Vector2(5, -10)

@export_group("腕の描き方")
## 手前・奥への腕を縦に縮める割合(3/4 ビューの奥行き)
@export var depth_squash := 0.4
## 腕を描く長さの倍率(小さな体でも腕が読めるよう、判定より長めに描く)
@export var arm_draw_scale := 1.3
## 上へ挙げた腕をさらに長く描く倍率(手が頭の上に出るように)
@export var raise_draw_scale := 1.5
## 下ろした腕を描く長さの倍率(手が足元より下に垂れないように)
@export var rest_draw_scale := 0.75
## 手前に伸ばした腕の手を大きくする割合
@export var front_hand_grow := 0.5
## 手の半径(px)
@export var hand_radius := 2.5
## 手前の腕ほど、手を体の正面の真ん中へ寄せる割合(下ろした腕と見分けるため)
@export var front_hand_center := 0.9

@export_group("入力")
## 入力の割り当て(空なら res://resources/settings/input_config.tres)
@export var input_config: InputConfig
## キーボードの組(スポナーが設定する)
@export var keyboard := PlayerInput.Keyboard.A
## コントローラーの番号(-1 で使わない)
@export var joy_device := 0

## 1 か 2。色や「片方にしか見えない物」の判定に使う
var player_index := 1
## この体を操作している端末のID
var owner_peer := 1
## この端末の入力で動かすか
var is_local := true

var height := 0.0
var state := State.WALK
var facing := Vector2.DOWN
var input: Dictionary = PlayerInput.empty_state()
## 手つなぎ(Hands)が体の動きを決めている間は true
var link_controlled := false
## 確認用の台本(Autopilot)が入力を上書きする時に使う。null なら通常の入力
var input_override = null
## 手でつかんでいる物 [左, 右](部品が設定する。つかんでいる手は手つなぎに使われない)
var held_objects: Array = [null, null]
## 声の波の形を変える道具(ラッパなど)。{ dir = Vector2, spread = 角度, size_scale = 倍率 } か空
var voice_modifier: Dictionary = {}

# 腕の状態(1本ごと。[左, 右])
var arm_dir: Array = [Vector3.ZERO, Vector3.ZERO]      ## 今の向き(単位ベクトル)
var arm_reach := [-1.0, -1.0]                          ## 負なら元の長さ。つないでいる時だけ伸び縮みする
var arm_tension := [0.0, 0.0]                          ## 張り(0〜1)。見た目と振動だけに使う
var arm_grip := [false, false]                         ## 握っているか(見た目用)
var arm_extended := [false, false]                     ## 手を伸ばしているか(手つなぎ・つかむ条件)
var _link: Array = [null, null]                        ## つなぎ先 { point, height, tension, owner }
var _net_arm_dir: Array = [Vector3.ZERO, Vector3.ZERO]
var _net_link: Array = [null, null]                    ## 他の端末が計算している時に受け取ったつなぎ先(描く時だけ使う)

var vz := 0.0            # 高さ方向の速さ(段/秒)
var _air_grace := 0.0     # 崖を離れた直後、出発した段の壁を無視する時間
var _air_start_height := 0.0
var _prev_glide := false
var _prev_pose := false
var _reader := PlayerInput.new()
var _remote_input: Dictionary = PlayerInput.empty_state()
var _net_target_pos := Vector2.ZERO
var _net_target_height := 0.0
var _has_net_target := false
var _send_timer := 0.0
var _flash := 0.0
# 自分で操作している時の、走る・握るの切り替え状態
var _running := false
var _run_btn_prev := false
var _release_prev := false
var _stopped_time := 0.0
var _grip_latch := [false, false]
var _move_locks := {}          # 動けなくしている仕組みの名前 -> true
var _bob_phase := 0.0

@onready var visual: Node2D = $Visual
@onready var shadow: Node2D = $Shadow
@onready var outline: Node2D = $Outline


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = Layers.bit(Layers.PLAYER_LAYER)
	collision_mask = Layers.walker_mask()
	add_to_group("players")
	if input_config == null:
		input_config = InputConfig.get_default()
	_reader.config = input_config
	_reader.keyboard = keyboard
	_reader.joy_device = joy_device
	_reader.require_focus = not Net.allow_unfocused
	height = World.height_at(global_position)
	_net_target_pos = global_position
	_net_target_height = height
	for h in [Hand.LEFT, Hand.RIGHT]:
		arm_dir[h] = _rest_dir(h)
		_net_arm_dir[h] = arm_dir[h]
	_update_colors()
	var rcv := get_node_or_null("WaveReceiver") as WaveReceiver
	if rcv:
		rcv.ignore_source = source_id()
	World.register_player(self)


func _exit_tree() -> void:
	World.unregister_player(self)


## 音源としての名前(声の波などに使う)
func source_id() -> String:
	return "P%d" % player_index


func setup_input(kb: int, pad: int) -> void:
	keyboard = kb
	joy_device = pad
	_reader.keyboard = kb
	_reader.joy_device = pad


func _update_colors() -> void:
	if visual:
		for n in visual.get_children():
			if n is CanvasItem:
				n.queue_redraw()
	if outline:
		outline.queue_redraw()


# ---------------------------------------------------------------- 毎フレーム

func _physics_process(delta: float) -> void:
	if is_local:
		input = _reader.read() if input_override == null else input_override.duplicate()
		_apply_local_controls(delta)
		if Net.is_online() and not Net.is_host():
			_rpc_input.rpc_id(1, input)
	else:
		input = _remote_input

	if is_simulated_here():
		if not link_controlled:
			_simulate(delta)
		_update_arms(delta)
		_send_state(delta)
	else:
		_follow_net(delta)
		_follow_net_arms(delta)


## 自分で操作している時だけ:走る/歩くの切り替えと、握ったままにする(離すボタンまで)を入力に書き込む。
## 書き込んだ入力をホストにも送るので、どの端末でも同じ判定になる
func _apply_local_controls(delta: float) -> void:
	var run_btn: bool = input.get("run", false)
	if run_btn and not _run_btn_prev:
		_running = not _running
	_run_btn_prev = run_btn
	if input.move.length() < 0.1:
		_stopped_time += delta
		if _stopped_time >= run_stop_time:
			_running = false
	else:
		_stopped_time = 0.0
	input.running = _running
	var rel: bool = input.get("release", false)
	if rel and not _release_prev:
		_grip_latch = [false, false]
	_release_prev = rel
	if not rel:
		# LB/RB を押した手、ポーズ中に伸ばした手は、離すボタンを押すまで握ったまま
		if input.grab_l:
			_grip_latch[0] = true
		if input.grab_r:
			_grip_latch[1] = true
		if auto_grab and input.pose:
			if input.arm_l.length() >= arm_deadzone or input.raise_l:
				_grip_latch[0] = true
			if input.arm_r.length() >= arm_deadzone or input.raise_r:
				_grip_latch[1] = true
	input.grab_l = _grip_latch[0]
	input.grab_r = _grip_latch[1]


## 走っているか(体の上下の揺れにも使う)
func is_running() -> bool:
	return bool(input.get("running", false))


## その場から動けなくする(レバーを握っている時など)。スティックは入力として残るので、物の側が使える。
## owner_key は止めた仕組みの名前。ホストで呼ぶと、この体を動かしている端末にも伝わる
func set_move_locked(owner_key: String, on: bool) -> void:
	if on:
		_move_locks[owner_key] = true
	else:
		_move_locks.erase(owner_key)
	if Net.is_online() and multiplayer.is_server() and owner_peer != Net.my_id():
		_rpc_move_lock.rpc_id(owner_peer, owner_key, on)


@rpc("authority", "call_remote", "reliable")
func _rpc_move_lock(owner_key: String, on: bool) -> void:
	if on:
		_move_locks[owner_key] = true
	else:
		_move_locks.erase(owner_key)


func is_move_locked() -> bool:
	return not _move_locks.is_empty()


## 自分のつかんでいる物・つないでいる手を全部離す(離すボタンと同じ。この端末で操作している時だけ効く)
func release_all() -> void:
	_grip_latch = [false, false]


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	# 見た目は整数ピクセルにそろえる(当たり判定は動かさない)
	var base := World.height_offset(height) + Vector2(0, _bob(delta))
	var snap := global_position.round() - global_position
	visual.position = (base + snap).round()
	outline.position = visual.position
	shadow.position = World.height_offset(World.height_at(global_position)) + snap
	outline.visible = World.is_occluded(global_position, height, body_size, self)
	for n in visual.get_children():
		if n is CanvasItem:
			n.queue_redraw()
	if outline.visible:
		outline.queue_redraw()


## この端末が体の動きを計算するか
func is_simulated_here() -> bool:
	if not Net.is_online():
		return true
	if Hands.is_player_linked(self):
		return Net.is_host()
	return is_local


func _simulate(delta: float) -> void:
	match state:
		State.WALK, State.POSE:
			_walk(delta)
		State.GLIDE:
			_glide(delta)
		State.FLY:
			_fly(delta)
		_:
			pass
	_prev_glide = input.glide


func _set_state(s: int) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


# ---------------------------------------------------------------- 歩く・ポーズ

func _walk(delta: float) -> void:
	var posing: bool = input.pose
	_set_state(State.POSE if posing else State.WALK)
	var want := Vector2.ZERO
	if not posing and _move_locks.is_empty():
		want = input.move * move_speed * (run_speed_scale if input.get("running", false) else 1.0)
		if input.move.length() > 0.1:
			facing = input.move.normalized()
	else:
		facing = Vector2.DOWN
	velocity = velocity.move_toward(want, acceleration * delta)
	collision_mask = Layers.walker_mask()
	move_and_slide()
	height = World.height_at(global_position)
	if input.glide and not _prev_glide and not posing and not Hands.is_player_linked(self):
		try_glide()


func is_posing() -> bool:
	return state == State.POSE


## 歩く・走る時の体の上下の揺れ(見た目だけ。上にだけ跳ねる)
func _bob(delta: float) -> float:
	var speed := velocity.length()
	if is_airborne() or speed < 5.0:
		_bob_phase = 0.0
		return 0.0
	var amp := run_bob_px if speed > move_speed * 1.15 else walk_bob_px
	if amp <= 0.0:
		return 0.0
	_bob_phase += delta * run_bob_hz * PI * (speed / (move_speed * run_speed_scale))
	return -absf(sin(_bob_phase)) * amp


## 崖の縁なら滑空を始める。始めたら true
func try_glide() -> bool:
	var dir := facing.normalized()
	if dir == Vector2.ZERO:
		return false
	for d in [glide_edge_probe * 0.6, glide_edge_probe]:
		var p: Vector2 = global_position + dir * d
		if not World.has_ground(p):
			continue
		var drop := height - World.height_at(p)
		if drop >= float(min_glide_levels) - 0.01:
			_step_over_edge(dir, d)
			start_air(dir * glide_forward_speed, 0.0, State.GLIDE)
			glide_started.emit()
			return true
	return false


## 崖の縁の向こうへ体を出す(縁の上に体の中心が残ったまま高さが下がると、出発した段に着地してしまうため)
func _step_over_edge(dir: Vector2, max_d: float) -> void:
	var r := _radius()
	var s := 0.0
	while s < max_d + 2.0:
		s += 1.0
		if World.height_at(global_position + dir * s) < height - 0.5:
			global_position += dir * (s + 1.0)
			return
	global_position += dir * r


func _radius() -> float:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		return cs.shape.radius
	return 5.0


## 宙に出る(滑空・飛ぶ共通)。vel は地面上の速さ、up_speed は上向きの速さ(段/秒)
func start_air(vel: Vector2, up_speed: float, s: int = State.FLY) -> void:
	velocity = vel
	vz = up_speed
	_air_grace = 0.15
	_air_start_height = height
	_set_state(s)


## 指定の距離だけ飛ばす(回転投げ・反動用)。arc_levels は山なりの高さ(段)
func launch(direction: Vector2, distance: float, arc_levels: float) -> void:
	var t := sqrt(maxf(arc_levels, 0.05) * 8.0 / fly_gravity)   # 元の高さに戻るまでの時間
	var speed := distance / t
	start_air(direction.normalized() * speed, fly_gravity * t * 0.5, State.FLY)


func _air_mask() -> int:
	if _air_grace > 0.0:
		return Layers.airborne_mask(maxf(height, _air_start_height))
	return Layers.airborne_mask(height)


func _glide(delta: float) -> void:
	_air_grace -= delta
	var dir := velocity.normalized() if velocity.length() > 1.0 else facing
	var side := dir.orthogonal()
	var steer: float = input.move.dot(side)
	velocity = dir * glide_forward_speed + side * steer * glide_steer_speed
	if velocity.length() > 1.0:
		facing = velocity.normalized()
	height -= glide_fall_speed * delta
	collision_mask = _air_mask()
	move_and_slide()
	_check_landing()


func _fly(delta: float) -> void:
	_air_grace -= delta
	vz -= fly_gravity * delta
	height += vz * delta
	collision_mask = _air_mask()
	move_and_slide()
	_check_landing()


func _check_landing() -> void:
	var ground := World.height_at(global_position)
	if height <= ground and vz <= 0.0:
		height = ground
		vz = 0.0
		velocity = Vector2.ZERO
		_set_state(State.WALK)
		collision_mask = Layers.walker_mask()
		landed.emit()


func is_airborne() -> bool:
	return state == State.GLIDE or state == State.FLY


# ---------------------------------------------------------------- 体の向き

func body_dir() -> int:
	if absf(facing.x) > absf(facing.y):
		return BodyDir.RIGHT if facing.x > 0.0 else BodyDir.LEFT
	return BodyDir.UP if facing.y < 0.0 else BodyDir.DOWN


# ---------------------------------------------------------------- 腕:更新

## 両腕の向き・長さを決める(体の動きを計算する端末で毎物理フレーム)。
## 優先順位は「つないでいる > ポーズ中のスティック > 下ろす」
func _update_arms(delta: float) -> void:
	var posing := is_posing()
	if posing != _prev_pose:
		_prev_pose = posing
		pose_changed.emit(posing)
	for h in [Hand.LEFT, Hand.RIGHT]:
		# 握ったままにしていても、何もつかまず腕も下ろしている時は開いた手に見せる
		arm_grip[h] = is_gripping(h) and (_link[h] != null or held_objects[h] != null or is_posing())
		var lk = _link[h]
		if lk != null:
			arm_extended[h] = true
			arm_grip[h] = true
			arm_tension[h] = lk.tension
			var to: Vector2 = lk.point - get_shoulder_ground_position(h)
			arm_dir[h] = _aim(arm_dir[h], Vector3(to.x, to.y, 0.0), arm_follow * 2.0, delta)
			arm_reach[h] = clampf(to.length(), arm_length * 0.5, arm_length * 2.0)
			continue
		arm_reach[h] = -1.0
		arm_tension[h] = 0.0
		var target := _pose_dir(h) if posing else Vector3.ZERO
		arm_extended[h] = target != Vector3.ZERO
		if target == Vector3.ZERO:
			target = _rest_dir(h)
		arm_dir[h] = _aim(arm_dir[h], target, arm_follow, delta)


## ポーズの向き(スティックと挙げるボタンから)。伸ばさない時はゼロ
func _pose_dir(h: int) -> Vector3:
	var stick: Vector2 = input.arm_l if h == Hand.LEFT else input.arm_r
	var pointing := stick.length() >= arm_deadzone
	var raised: bool = input.raise_l if h == Hand.LEFT else input.raise_r
	if raised and not pointing:
		return Vector3(0, 0, 1)
	if not pointing:
		return Vector3.ZERO
	if arm_snap_directions > 0:
		var step := TAU / arm_snap_directions
		stick = Vector2.from_angle(roundf(stick.angle() / step) * step)
	var hd := stick.normalized()
	if raised:
		var e := deg_to_rad(raise_angle_deg)
		return Vector3(hd.x * cos(e), hd.y * cos(e), sin(e))
	return Vector3(hd.x, hd.y, 0.0)


## 下ろした向き(左腕の設定。右腕は x を反転)
func _rest_dir(h: int) -> Vector3:
	var d := rest_arm_direction.normalized()
	if h == Hand.RIGHT:
		d.x = -d.x
	return d


## 今の向きから目標へ、球面の上で滑らかに回す(指数で近づくので、フレームの速さに関係なく同じ感触)。
## 真逆への切り替え(右から左など)は水平に回して体の前を通す
static func _aim(current: Vector3, target: Vector3, follow: float, delta: float) -> Vector3:
	if target == Vector3.ZERO:
		return current
	target = target.normalized()
	if current == Vector3.ZERO:
		return target
	var angle := current.angle_to(target)
	if angle < 0.001:
		return target
	var axis := current.cross(target)
	if axis.length() < 0.0001:
		axis = Vector3(0, 0, 1) if absf(current.z) < 0.9 else Vector3(1, 0, 0)
	return current.rotated(axis.normalized(), angle * (1.0 - exp(-follow * delta))).normalized()


## 体の動きを計算しない端末:受け取った向きへ滑らかに追う
func _follow_net_arms(delta: float) -> void:
	for h in [Hand.LEFT, Hand.RIGHT]:
		arm_dir[h] = _aim(arm_dir[h], _net_arm_dir[h], arm_follow * 2.0, delta)


# ---------------------------------------------------------------- 腕:他の仕組みから使う口

## 伸ばしているか(手つなぎ・つかむ条件)
func is_arm_extended(h: int) -> bool:
	return arm_extended[h]


## 握っているか(入力を直接見る)
func is_gripping(h: int) -> bool:
	return bool(input.grab_l if h == Hand.LEFT else input.grab_r)


## 腕の長さ(px、判定用)
func get_arm_length_px() -> float:
	return arm_length


## 肩の位置(足元から、画面上)。体の向きで左右が入れ替わる・中央へ寄る
func shoulder_local(h: int) -> Vector2:
	var side := -1.0 if h == Hand.LEFT else 1.0
	match body_dir():
		BodyDir.UP:
			side = -side
		BodyDir.LEFT, BodyDir.RIGHT:
			side *= 0.3
	return Vector2(side * shoulder_offset.x, shoulder_offset.y)


## 肩の地面の位置
func get_shoulder_ground_position(h: int) -> Vector2:
	return global_position + Vector2(shoulder_local(h).x, 0.0)


## 手の地面の位置(判定用。腕の上下は無視し、描く倍率はかけない)
func get_hand_ground_position(h: int) -> Vector2:
	var d: Vector3 = arm_dir[h]
	return get_shoulder_ground_position(h) + Vector2(d.x, d.y) * _reach_px(h)


func _reach_px(h: int) -> float:
	return arm_reach[h] if arm_reach[h] > 0.0 else arm_length


## つなぎ先(手が向かう地面の点)を設定する。null で外す。
## owner_key は設定した仕組みの名前。外す時は自分が設定した物だけを外す(他の物を握る手の行き先を消さないため)
## link_height はつなぎ先の高さ(段)。省略すると自分の高さ
func set_link_point(h: int, point, tension: float = 0.0, owner_key: String = "", link_height: float = NAN) -> void:
	var cur = _link[h]
	if point == null:
		if cur != null and (owner_key == "" or cur.owner == owner_key):
			_link[h] = null
	else:
		_link[h] = { point = point, tension = tension, owner = owner_key, height = link_height }
	# 体の動きを他の端末が計算している時は、その端末へ伝える
	if Net.is_online() and multiplayer.is_server() and not is_simulated_here() and owner_peer != Net.my_id():
		_rpc_link_point.rpc_id(owner_peer, h, point, tension, owner_key, link_height)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_link_point(h: int, point, tension: float, owner_key: String, link_height: float) -> void:
	if point == null:
		var cur = _link[h]
		if cur != null and (owner_key == "" or cur.owner == owner_key):
			_link[h] = null
	else:
		_link[h] = { point = point, tension = tension, owner = owner_key, height = link_height }


## つなぎ先があるか
func is_linked(h: int) -> bool:
	return _link[h] != null


## そのつなぎ先を設定した仕組みの名前(つないでいなければ空)
func link_owner(h: int) -> String:
	return _link[h].owner if _link[h] != null else ""


# ---------------------------------------------------------------- 腕:描く

## 腕の空間の向きを画面へ写す(正確な投影ではなく、合図の読み分けを優先した写し方)
func _arm_to_screen(d: Vector3) -> Vector2:
	var up := maxf(d.z, 0.0) * raise_draw_scale + minf(d.z, 0.0)
	return Vector2(d.x, d.y * depth_squash - up)


## 描く時に使うつなぎ先(この端末で計算していない時は、受け取った物)
func _draw_link(h: int):
	if _link[h] != null:
		return _link[h]
	return _net_link[h] if not is_simulated_here() else null


## 手の位置(見た目の原点=足元からの画面上の位置)
func hand_local(h: int) -> Vector2:
	var sh := shoulder_local(h)
	var lk = _draw_link(h)
	if lk != null:
		# つないでいる手は、つなぎ先の点にちょうど重ねる(二人の手が行き違って見えないように)
		var lh: float = height if is_nan(float(lk.height)) else float(lk.height)
		var p: Vector2 = lk.point - global_position + World.height_offset(lh - height) + Vector2(0, sh.y)
		return p.round()
	var d: Vector3 = arm_dir[h]
	var draw_k := lerpf(arm_draw_scale, rest_draw_scale, clampf(-d.z, 0.0, 1.0))
	var hand := sh + _arm_to_screen(d) * _reach_px(h) * draw_k
	hand.x -= sh.x * maxf(d.y, 0.0) * front_hand_center
	return hand.round()


## 体の後ろに描く腕か(奥へ向いていて、挙げていない)
func arm_behind_body(h: int) -> bool:
	var d: Vector3 = arm_dir[h]
	return d.y < -0.2 and d.z < 0.3


## 腕を描く(ArmsBack / ArmsFront の層から呼ばれる)。front = 体の前の層か
func draw_arms(canvas: CanvasItem, front: bool) -> void:
	for h in [Hand.LEFT, Hand.RIGHT]:
		if arm_behind_body(h) == front:
			continue
		var sh := shoulder_local(h)
		var hand := hand_local(h)
		var d: Vector3 = arm_dir[h]
		var line_col := body_color.lerp(Color.WHITE, float(arm_tension[h]) * 0.45)
		canvas.draw_line(sh, hand, body_color.darkened(0.55), 3.0)
		canvas.draw_line(sh, hand, line_col, 1.0)
		var r := hand_radius * (1.0 + front_hand_grow * maxf(d.y, 0.0))
		var col := hand_color
		if arm_grip[h]:
			r *= 0.75
			col = col.darkened(0.15)
		canvas.draw_circle(hand, r + 1.0, col.darkened(0.6))
		canvas.draw_circle(hand, r, col)


## 手の画面上の位置(グローバル)
func hand_screen_pos(h: int) -> Vector2:
	return visual.global_position + hand_local(h)


func shoulder_screen_pos(h: int) -> Vector2:
	return visual.global_position + shoulder_local(h)


# ---------------------------------------------------------------- 波が届いた時

## 音の波が届いたことを見せる(WaveReceiver から呼ばれる)
func on_wave_received(source_id: String, strength: float, _time: float) -> void:
	_flash = clampf(0.4 + strength, 0.0, 1.0)
	wave_touched.emit(source_id, strength)


func get_flash() -> float:
	return _flash


## 振動(この体を操作している端末のコントローラーを震わせる)
func rumble(weak: float, strong: float, duration: float) -> void:
	if is_local:
		if joy_device >= 0:
			Input.start_joy_vibration(joy_device, weak, strong, duration)
	elif Net.is_online():
		_rpc_rumble.rpc_id(owner_peer, weak, strong, duration)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_rumble(weak: float, strong: float, duration: float) -> void:
	if joy_device >= 0:
		Input.start_joy_vibration(joy_device, weak, strong, duration)


# ---------------------------------------------------------------- 通信

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(state_in: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != owner_peer:
		return
	_remote_input = state_in


func _send_state(delta: float) -> void:
	if not Net.is_online():
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = 1.0 / 30.0
	var ids := Net.ready_remote_ids()
	for id in ids:
		_rpc_state.rpc_id(id, pack_state())


## [位置, 高さ, 状態, 向き, 速さ, 上下の速さ, 手つなぎで動かされているか,
##  左の向き, 右の向き, 左の長さ, 右の長さ, 左の張り, 右の張り, 左の握り, 右の握り, 左の伸ばし, 右の伸ばし,
##  左のつなぎ先, 右のつなぎ先(なければ空の配列。あれば [点, 高さ])]
func pack_state() -> Array:
	return [global_position, height, state, facing, velocity, vz, link_controlled,
		arm_dir[0], arm_dir[1], arm_reach[0], arm_reach[1], arm_tension[0], arm_tension[1],
		arm_grip[0], arm_grip[1], arm_extended[0], arm_extended[1], _pack_link(0), _pack_link(1)]


func _pack_link(h: int) -> Array:
	var lk = _link[h]
	if lk == null:
		return []
	return [lk.point, height if is_nan(float(lk.height)) else float(lk.height)]


func apply_state(a: Array, snap: bool) -> void:
	_net_target_pos = a[0]
	_net_target_height = a[1]
	var s: int = a[2]
	facing = a[3]
	velocity = a[4]
	vz = a[5]
	if s != state:
		_set_state(s)
		var posing := s == State.POSE
		if posing != _prev_pose:
			_prev_pose = posing
			pose_changed.emit(posing)
	if a.size() >= 17:
		for h in [0, 1]:
			_net_arm_dir[h] = a[7 + h]
			arm_reach[h] = a[9 + h]
			arm_tension[h] = a[11 + h]
			arm_grip[h] = a[13 + h]
			arm_extended[h] = a[15 + h]
	if a.size() >= 19:
		for h in [0, 1]:
			var pl: Array = a[17 + h]
			_net_link[h] = null if pl.is_empty() else { point = pl[0], height = pl[1], tension = arm_tension[h], owner = "" }
	if snap:
		global_position = _net_target_pos
		height = _net_target_height
		for h in [0, 1]:
			arm_dir[h] = _net_arm_dir[h]
	_has_net_target = true


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_state(a: Array) -> void:
	if is_simulated_here():
		return
	apply_state(a, false)


## 計算する端末が切り替わる時に、最後の状態をそのまま渡す
@rpc("any_peer", "call_remote", "reliable")
func rpc_handoff_state(a: Array) -> void:
	apply_state(a, true)


func _follow_net(delta: float) -> void:
	if not _has_net_target:
		return
	var k := clampf(delta * 15.0, 0.0, 1.0)
	global_position = global_position.lerp(_net_target_pos, k)
	height = lerpf(height, _net_target_height, k)
	if global_position.distance_to(_net_target_pos) > 64.0:
		global_position = _net_target_pos
