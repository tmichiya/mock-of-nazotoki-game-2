class_name PlayerInput
extends RefCounted
## 1人分の入力を読む。キーボードの組(A/B/なし)と、コントローラー番号(-1でなし)を選べる。
## 読んだ結果は辞書(InputState)で返し、そのまま通信でも送る。

enum Keyboard { NONE, A, B }

var config: InputConfig
var keyboard := Keyboard.A
var joy_device := 0
## ウィンドウが選ばれていない時は入力を無視する(1台で2つ起動した時に両方が動かないように)
var require_focus := true


static func empty_state() -> Dictionary:
	return {
		move = Vector2.ZERO, pose = false, arm_l = Vector2.ZERO, arm_r = Vector2.ZERO,
		grab_l = false, grab_r = false, raise_l = false, raise_r = false, glide = false, instrument = false,
	}


func read() -> Dictionary:
	var s := empty_state()
	if config == null:
		config = InputConfig.get_default()
	if require_focus and not DisplayServer.window_is_focused():
		return s
	var move := Vector2.ZERO
	var arm_r_kb := Vector2.ZERO
	var pose := false
	var grab_l := false
	var grab_r := false
	var glide := false
	var instrument := false
	var raise_l := false
	var raise_r := false
	if keyboard != Keyboard.NONE:
		var c := config
		var a := keyboard == Keyboard.A
		move.x = _k(c.a_right if a else c.b_right) - _k(c.a_left if a else c.b_left)
		move.y = _k(c.a_down if a else c.b_down) - _k(c.a_up if a else c.b_up)
		arm_r_kb.x = _k(c.a_arm_right if a else c.b_arm_right) - _k(c.a_arm_left if a else c.b_arm_left)
		arm_r_kb.y = _k(c.a_arm_down if a else c.b_arm_down) - _k(c.a_arm_up if a else c.b_arm_up)
		pose = _k(c.a_pose if a else c.b_pose) > 0.0
		grab_l = _k(c.a_grab_left if a else c.b_grab_left) > 0.0
		grab_r = _k(c.a_grab_right if a else c.b_grab_right) > 0.0
		glide = _k(c.a_glide if a else c.b_glide) > 0.0
		instrument = _k(c.a_instrument if a else c.b_instrument) > 0.0
		raise_l = _k(c.a_raise_left if a else c.b_raise_left) > 0.0
		raise_r = _k(c.a_raise_right if a else c.b_raise_right) > 0.0
	var arm_l := move
	var arm_r := arm_r_kb
	if joy_device >= 0 and joy_device in Input.get_connected_joypads():
		var d := joy_device
		var ls := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		var rs := Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
		if ls.length() > config.move_deadzone:
			move = ls
		if ls.length() > arm_l.length():
			arm_l = ls
		if rs.length() > arm_r.length():
			arm_r = rs
		var lt := Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > config.trigger_threshold
		var rt := Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > config.trigger_threshold
		match config.pose_trigger:
			InputConfig.PoseTrigger.LT: pose = pose or lt
			InputConfig.PoseTrigger.RT: pose = pose or rt
			_: pose = pose or lt or rt
		grab_l = grab_l or Input.is_joy_button_pressed(d, config.grab_left_button)
		grab_r = grab_r or Input.is_joy_button_pressed(d, config.grab_right_button)
		glide = glide or Input.is_joy_button_pressed(d, config.glide_button)
		instrument = instrument or Input.is_joy_button_pressed(d, config.instrument_button)
		raise_l = raise_l or Input.is_joy_button_pressed(d, config.raise_left_button)
		raise_r = raise_r or Input.is_joy_button_pressed(d, config.raise_right_button)
	if move.length() > 1.0:
		move = move.normalized()
	s.move = move
	s.pose = pose
	s.arm_l = arm_l
	s.arm_r = arm_r
	s.grab_l = grab_l
	s.grab_r = grab_r
	s.glide = glide
	s.instrument = instrument
	s.raise_l = raise_l
	s.raise_r = raise_r
	return s


func _k(key: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


## スティックの向きを8方向の番号にする(0=右, 1=右下, 2=下 … 時計回り)。倒し方が足りなければ -1
static func snap8(v: Vector2, deadzone: float) -> int:
	if v.length() < deadzone:
		return -1
	return posmod(roundi(v.angle() / (PI / 4.0)), 8)


static func dir8(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(index * PI / 4.0)
