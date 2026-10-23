class_name Fluff
extends CharacterBody2D
## 綿毛(波に押されて流れる軽い物)。子の WavePushable が波を受けて押す。
## 地形の壁に当たる(段差は越えない)。高さは足元の地形。

## 動きが止まっていく速さ(px/秒²)
@export var friction := 40.0
## 一番速い速さ(px/秒)
@export var max_speed := 120.0
## 見た目の大きさ(半径px)
@export var radius := 4.0
## ふわふわ浮いている高さ(段)
@export var float_height := 0.3

var height := 0.0
var _net_pos := Vector2.ZERO
var _send := 0.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = Layers.bit(Layers.PROP_LAYER)
	collision_mask = Layers.walker_mask()
	add_to_group("props")
	height = World.height_at(global_position)
	_net_pos = global_position


func apply_wave_push(impulse: Vector2) -> void:
	velocity = (velocity + impulse).limit_length(max_speed)


func _physics_process(delta: float) -> void:
	if Net.is_host():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		height = World.height_at(global_position)
		if Net.is_online():
			_send -= delta
			if _send <= 0.0:
				_send = 1.0 / 20.0
				for id in Net.ready_remote_ids():
					_rpc_pos.rpc_id(id, global_position)
	else:
		global_position = global_position.lerp(_net_pos, clampf(delta * 10.0, 0.0, 1.0))
		height = World.height_at(global_position)
	queue_redraw()


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_pos(p: Vector2) -> void:
	_net_pos = p


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var off := World.height_offset(height + float_height + sin(t * 3.0) * 0.08)
	draw_circle(World.height_offset(height) - Vector2.ZERO, radius * 0.8, Color(0, 0, 0, 0.2))
	draw_circle(off, radius, Color(1, 1, 1, 0.9))
	draw_arc(off, radius, 0, TAU, 12, Color(0.6, 0.6, 0.7), 1.0)
