@tool
class_name ResetPoint
extends Marker2D
## やり直しの時に「戻す場所」。PuzzleReset の子に置く。
## player_index に 1 か 2 を入れるとそのプレイヤーを、target に物を指定するとその物を、ここへ戻す。

## 戻すプレイヤー(0 なら戻さない)
@export_range(0, 2) var player_index := 0:
	set(v):
		player_index = v
		queue_redraw()
## 戻す物(綿毛・棒など)
@export var target: NodePath


func apply() -> void:
	if player_index > 0:
		var p := World.get_player_by_index(player_index) as Player
		if p:
			_move_player(p)
	var t := get_node_or_null(target) as Node2D
	if t:
		t.global_position = global_position
		if t is CharacterBody2D or t is RigidBody2D:
			t.set("velocity", Vector2.ZERO)
			t.set("linear_velocity", Vector2.ZERO)
		if t.has_method("on_reset"):
			t.on_reset()


func _move_player(p: Player) -> void:
	if Net.is_online() and not p.is_local:
		_rpc_move.rpc_id(p.owner_peer, p.player_index, global_position)
		return
	_place(p)


func _place(p: Player) -> void:
	p.link_controlled = false
	p.state = Player.State.WALK
	p.velocity = Vector2.ZERO
	p.global_position = global_position
	p.height = World.height_at(global_position)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_move(index: int, pos: Vector2) -> void:
	var p := World.get_player_by_index(index) as Player
	if p:
		p.link_controlled = false
		p.state = Player.State.WALK
		p.velocity = Vector2.ZERO
		p.global_position = pos
		p.height = World.height_at(pos)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, 6, 0, TAU, 16, Color(1, 0.5, 0.5, 0.8), 1.0)
		if player_index > 0:
			draw_string(ThemeDB.fallback_font, Vector2(-3, 4), str(player_index), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
