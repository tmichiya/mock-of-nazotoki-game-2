@tool
class_name StringPhone
extends PuzzlePart
## 糸電話。二人で両端を握ると(LB/RB)、糸が張っていて、何にも引っかかっていない間だけ声が届く。
## この部品の位置は、糸を置いておく場所(誰も握っていない時の端の位置)。

signal connected
signal disconnected

## 糸の長さ(px)。これより離れると張りすぎて切れはしないが、引っ張られる
@export var length := 160.0
## 長さのこの割合以上離れていると「張っている」
@export_range(0.1, 1.0) var taut_ratio := 0.8
## 握れる距離(px)
@export var grab_radius := 12.0
@export var color := Color("e8e0d0")

var _holders: Array = [null, null]
var is_connected_now := false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	process_physics_priority = 20


## 誰も握っていない時の端の位置(二人が手つなぎの距離より離れて握れるよう、少し離して置く)
func _end_rest(i: int) -> Vector2:
	return global_position + Vector2(-18 if i == 0 else 18, 0)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority():
		return
	for i in [0, 1]:
		if _holders[i]:
			var p: Player = _holders[i][0]
			if not is_instance_valid(p) or not is_reaching(p, _holders[i][1]):
				if is_instance_valid(p):
					p.held_objects[_holders[i][1]] = null
				_holders[i] = null
		if _holders[i] == null:
			var g := find_grabber(_end_rest(i), grab_radius, 9.0)
			if not g.is_empty() and not (_holders[1 - i] and _holders[1 - i][0] == g[0]):
				_holders[i] = g
				g[0].held_objects[g[1]] = self
	var on := false
	if _holders[0] and _holders[1]:
		var a: Player = _holders[0][0]
		var b: Player = _holders[1][0]
		var d := a.global_position.distance_to(b.global_position)
		# 長さを超えたら引き戻す
		if d > length:
			var dir := (b.global_position - a.global_position).normalized()
			var ex := d - length
			a.move_and_collide(dir * ex * 0.5)
			b.move_and_collide(-dir * ex * 0.5)
		var taut := d >= length * taut_ratio
		var snag := World.is_blocked_between(a.global_position, b.global_position, maxf(a.height, b.height) + 0.4)
		on = taut and not snag
	if on != is_connected_now:
		is_connected_now = on
		if on:
			connected.emit()
		else:
			disconnected.emit()
		sync_state()
	Hands.set_virtual_link(self, _holders[0][0] if _holders[0] else null, _holders[1][0] if _holders[1] else null, on)
	queue_redraw()
	if Net.is_online():
		for id in Net.ready_remote_ids():
			_rpc_holders.rpc_id(id, _holder_indices())


func _holder_indices() -> Array:
	return [_holders[0][0].player_index if _holders[0] else 0, _holders[1][0].player_index if _holders[1] else 0]


var _remote_holders := [0, 0]


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_holders(idx: Array) -> void:
	_remote_holders = idx
	queue_redraw()


func get_state() -> Dictionary:
	return { on = is_connected_now }


func apply_state(s: Dictionary) -> void:
	if s.on != is_connected_now:
		is_connected_now = s.on
		if s.on:
			connected.emit()
		else:
			disconnected.emit()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and not is_authority():
		queue_redraw()


func _draw() -> void:
	var lp := WorldConfig.get_default().level_px
	var pts := []
	for i in [0, 1]:
		var p: Player = null
		if not Engine.is_editor_hint():
			if is_authority():
				p = _holders[i][0] if _holders[i] else null
			elif _remote_holders[i] > 0:
				p = World.get_player_by_index(_remote_holders[i])
		if p:
			pts.append(p.global_position - global_position + Vector2(0, -(p.height + 0.7) * lp))
		else:
			pts.append(_end_rest(i) - global_position + lift())
	var col := Color("ffe680") if is_connected_now else color
	if pts[0].distance_to(pts[1]) > 1.0:
		var mid: Vector2 = (pts[0] + pts[1]) * 0.5 + Vector2(0, 0 if is_connected_now else 8)
		var line := PackedVector2Array()
		for k in range(11):
			var t := k / 10.0
			line.append(pts[0].lerp(mid, t).lerp(mid.lerp(pts[1], t), t))
		draw_polyline(line, col, 1.0)
	for e in pts:
		draw_rect(Rect2(e - Vector2(3, 3), Vector2(6, 6)), Color("c98f5f"))
