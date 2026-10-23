class_name Player
extends CharacterBody2D
## プレイヤー。地面の上を動き(position = 地面の位置)、高さ height(段)は足元の地形から決まる。
## 見た目は height の分だけ上にずらして描き、影は常に足元の地形の高さに描く。
##
## 操作: 左スティック移動 / トリガー長押しでポーズ(両スティックで両腕を8方向に)/
##       LB・RB 長押しで左手・右手を伸ばす / A で崖の縁から滑空
## 「左」は常に「画面の左側に見える腕」(ポーズ中のキャラにとっては右腕)。

signal state_changed(new_state: int)
signal glide_started
signal landed
signal pose_changed(posing: bool, arm_left: int, arm_right: int)
signal wave_touched(source_id: String, strength: float)

enum State { WALK, POSE, GLIDE, FLY, HANG, CLIMB }
enum Side { LEFT, RIGHT }

@export_group("見た目")
## 体の色(2人の見分けに使う)
@export var body_color := Color("e8804a"):
	set(v):
		body_color = v
		if is_inside_tree():
			_update_colors()
## 手の色(手をつないでいるかが一目で分かるよう、体と違う色にする)
@export var hand_color := Color("fff4d8")
## 体の大きさ(px)。物陰の判定と輪郭に使う
@export var body_size := Vector2(12, 18)

@export_group("移動")
## 歩く速さ(px/秒)
@export var move_speed := 72.0
## 加速の速さ(大きいほどキビキビ)
@export var acceleration := 900.0

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
## 腕の長さ(px、画面上)
@export var arm_length := 8.0
## 手を伸ばした時の腕の長さ(px)
@export var reach_length := 13.0
## 肩の位置(足元から、画面上)
@export var shoulder_offset := Vector2(5, -11)

@export_group("入力")
## 入力の割り当て(空なら res://core/input_config.tres)
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
var arm_left := -1       ## 8方向の番号、-1 は下ろしている
var arm_right := -1
var reach_left := false
var reach_right := false
var input: Dictionary = PlayerInput.empty_state()
## 手つなぎ(Hands)が体の動きを決めている間は true
var link_controlled := false
## 確認用の台本(Autopilot)が入力を上書きする時に使う。null なら通常の入力
var input_override = null
## 手つなぎ中に Hands が決める腕の向かう先(画面上のグローバル座標)。null なら通常
var arm_target_left = null
var arm_target_right = null
## 腕の張り具合 0(緩い)〜1(張っている)
var arm_tension_left := 0.0
var arm_tension_right := 0.0

var vz := 0.0            # 高さ方向の速さ(段/秒)
var _air_grace := 0.0     # 崖を離れた直後、出発した段の壁を無視する時間
var _air_start_height := 0.0
var _prev_glide := false
var _reader := PlayerInput.new()
var _remote_input: Dictionary = PlayerInput.empty_state()
var _net_target_pos := Vector2.ZERO
var _net_target_height := 0.0
var _has_net_target := false
var _sent_pose := []
var _send_timer := 0.0
var _flash := 0.0

@onready var visual: Node2D = $Visual
@onready var shadow: Node2D = $Shadow
@onready var outline: Node2D = $Outline
@onready var arm_l_node: PlayerArm = $Visual/ArmL
@onready var arm_r_node: PlayerArm = $Visual/ArmR


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
	arm_l_node.position = Vector2(-shoulder_offset.x, shoulder_offset.y)
	arm_r_node.position = shoulder_offset
	_update_colors()
	World.register_player(self)


func _exit_tree() -> void:
	World.unregister_player(self)


func setup_input(kb: int, pad: int) -> void:
	keyboard = kb
	joy_device = pad
	_reader.keyboard = kb
	_reader.joy_device = pad


func _update_colors() -> void:
	if arm_l_node:
		arm_l_node.hand_color = hand_color
		arm_r_node.hand_color = hand_color
	if visual:
		visual.queue_redraw()
	if outline:
		outline.queue_redraw()


# ---------------------------------------------------------------- 毎フレーム

func _physics_process(delta: float) -> void:
	if is_local:
		input = _reader.read() if input_override == null else input_override
		if Net.is_online() and not Net.is_host():
			_rpc_input.rpc_id(1, input)
	else:
		input = _remote_input
	_update_arms_from_input()

	if is_simulated_here():
		if not link_controlled:
			_simulate(delta)
		_send_state(delta)
	else:
		_follow_net(delta)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	visual.position = World.height_offset(height)
	outline.position = visual.position
	shadow.position = World.height_offset(World.height_at(global_position))
	_update_arm_nodes()
	outline.visible = World.is_occluded(global_position, height, body_size, self)
	visual.queue_redraw()
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
	if not posing:
		want = input.move * move_speed
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


# ---------------------------------------------------------------- 腕

func _update_arms_from_input() -> void:
	if not is_local:
		return
	var dz := input_config.arm_deadzone
	var l := -1
	var r := -1
	if input.pose:
		l = PlayerInput.snap8(input.arm_l, dz)
		r = PlayerInput.snap8(input.arm_r, dz)
	var gl: bool = input.grab_l
	var gr: bool = input.grab_r
	var changed := l != arm_left or r != arm_right or gl != reach_left or gr != reach_right
	arm_left = l
	arm_right = r
	reach_left = gl
	reach_right = gr
	if changed:
		pose_changed.emit(input.pose, l, r)
		if Net.is_online():
			_rpc_pose.rpc(input.pose, l, r, gl, gr)


## 手の位置(地面の座標。手つなぎの距離の判定に使う)
func hand_ground_pos(side: int) -> Vector2:
	var sx := -shoulder_offset.x if side == Side.LEFT else shoulder_offset.x
	var dir := _arm_dir(side)
	var arm_len := reach_length if (reach_left if side == Side.LEFT else reach_right) else arm_length
	return global_position + Vector2(sx + dir.x * arm_len, dir.y * arm_len * 0.5)


## 手の位置(画面上のグローバル座標)
func hand_screen_pos(side: int) -> Vector2:
	var node := arm_l_node if side == Side.LEFT else arm_r_node
	return node.global_position + Vector2.RIGHT.rotated(node.global_rotation) * node.length


func shoulder_screen_pos(side: int) -> Vector2:
	var node := arm_l_node if side == Side.LEFT else arm_r_node
	return node.global_position


func _arm_dir(side: int) -> Vector2:
	var idx := arm_left if side == Side.LEFT else arm_right
	var reaching := reach_left if side == Side.LEFT else reach_right
	if idx >= 0:
		return PlayerInput.dir8(idx)
	if reaching:
		var partner := World.get_partner(self)
		if partner and partner.global_position.distance_to(global_position) < 60.0:
			return (partner.global_position - global_position).normalized()
		return Vector2(-0.94, 0.34) if side == Side.LEFT else Vector2(0.94, 0.34)
	return Vector2(-0.34, 0.94) if side == Side.LEFT else Vector2(0.34, 0.94)


func _update_arm_nodes() -> void:
	for side in [Side.LEFT, Side.RIGHT]:
		var node: PlayerArm = arm_l_node if side == Side.LEFT else arm_r_node
		var target = arm_target_left if side == Side.LEFT else arm_target_right
		if target != null:
			var v: Vector2 = target - node.global_position
			node.rotation = v.angle()
			node.length = maxf(v.length(), 2.0)
			node.tension = arm_tension_left if side == Side.LEFT else arm_tension_right
		else:
			var dir := _arm_dir(side)
			var reaching := reach_left if side == Side.LEFT else reach_right
			node.rotation = dir.angle()
			node.length = reach_length if reaching else arm_length
			node.tension = 1.0
		node.queue_redraw()


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


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pose(posing: bool, l: int, r: int, gl: bool, gr: bool) -> void:
	if multiplayer.get_remote_sender_id() != owner_peer:
		return
	var changed := l != arm_left or r != arm_right
	arm_left = l
	arm_right = r
	reach_left = gl
	reach_right = gr
	_remote_input.pose = posing
	_remote_input.grab_l = gl
	_remote_input.grab_r = gr
	if changed:
		pose_changed.emit(posing, l, r)


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


func pack_state() -> Array:
	return [global_position, height, state, facing, velocity, vz, link_controlled]


func apply_state(a: Array, snap: bool) -> void:
	_net_target_pos = a[0]
	_net_target_height = a[1]
	var s: int = a[2]
	facing = a[3]
	velocity = a[4]
	vz = a[5]
	if s != state:
		_set_state(s)
	if snap:
		global_position = _net_target_pos
		height = _net_target_height
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
