extends Node
## Hands(自動読み込み)
## 二人の手つなぎ。つながる・離れる、片手/両手、回転投げ、両手の反動、段またぎ(宙づり・引き上げ)。
## つないでいる間はホストの端末で二人分を計算し、もう一方は結果に従う(ガタつき防止)。
##
## 他の部品からの問い合わせ:
##   Hands.is_linked() / Hands.get_link_type() / Hands.is_player_linked(player)
##   Hands.is_cross_level()(段をまたいでつないでいるか)
## エディタでシグナルをつなぎたい時は、シーンに HandLinkMonitor を置く。

signal linked(link_type: int)
signal unlinked
signal link_type_changed(link_type: int)
signal thrown(player: Node)
signal recoiled
signal hang_started(player: Node)
signal pulled_up(player: Node)

enum LinkType { NONE, ONE_HAND, TWO_HANDS }

var settings: HandsSettings

var _a: Player
var _b: Player
var _pairs: Array = []        # Vector2i(_a の手, _b の手)
var _two_drop_time := -100.0

var _spin := {}               # 回転中の情報
var _cross := {}              # 段またぎ中の情報
var _rumble_timer := 0.0


func _ready() -> void:
	settings = HandsSettings.get_default()
	process_physics_priority = 10   # プレイヤーが動いた後に計算する


# ---------------------------------------------------------------- 問い合わせ

func is_linked() -> bool:
	return not _pairs.is_empty()


func get_link_type() -> int:
	match _pairs.size():
		0: return LinkType.NONE
		1: return LinkType.ONE_HAND
	return LinkType.TWO_HANDS


func is_two_hands() -> bool:
	return _pairs.size() >= 2


func is_player_linked(p: Node) -> bool:
	return is_linked() and (p == _a or p == _b)


func is_cross_level() -> bool:
	return not _cross.is_empty()


## つながっている相手(つながっていなければ null)
func linked_partner(p: Node) -> Node:
	if not is_player_linked(p):
		return null
	return _b if p == _a else _a


func is_spinning() -> bool:
	return not _spin.is_empty()


## その手が相手とつながっているか
func hand_in_link(p: Node, side: int) -> bool:
	for pair in _pairs:
		if (p == _a and pair.x == side) or (p == _b and pair.y == side):
			return true
	return false


## その手が「空いていて伸ばしている」か(物をつかめるか)
func hand_is_free(p: Player, side: int) -> bool:
	var reaching := p.reach_left if side == Player.Side.LEFT else p.reach_right
	if not reaching or hand_in_link(p, side):
		return false
	return p.held_objects[side] == null


# ---------------------------------------------------------------- 物を通したつながり(長い棒・糸電話)

var _virtual_links: Array = []   # [player_a, player_b, owner]


## 物を通して二人が「つながっている」扱いにする(声が届く)。owner は登録した部品(ホストで呼ぶ)
func set_virtual_link(owner: Node, a: Node, b: Node, on: bool) -> void:
	var key := str(owner.get_path())
	var before := _virtual_links.duplicate()
	_virtual_links = _virtual_links.filter(func(l): return l[2] != key)
	if on and a and b:
		_virtual_links.append([a, b, key])
	if Net.is_host() and Net.is_online() and before != _virtual_links:
		var packed := _virtual_links.map(func(l): return [l[0].player_index, l[1].player_index, l[2]])
		_rpc_virtual_links.rpc(packed)


@rpc("authority", "call_remote", "reliable")
func _rpc_virtual_links(packed: Array) -> void:
	_virtual_links = []
	for l in packed:
		var a := World.get_player_by_index(l[0])
		var b := World.get_player_by_index(l[1])
		if a and b:
			_virtual_links.append([a, b, l[2]])


## 声が届く相手(手つなぎ、または物を通したつながり)
func voice_partner(p: Node) -> Node:
	var q := linked_partner(p)
	if q:
		return q
	for l in _virtual_links:
		if is_instance_valid(l[0]) and is_instance_valid(l[1]):
			if l[0] == p:
				return l[1]
			if l[1] == p:
				return l[0]
	return null


# ---------------------------------------------------------------- 毎フレーム

func _physics_process(delta: float) -> void:
	var players := World.get_players()
	if players.size() < 2:
		if is_linked():
			_set_pairs([])
		_a = null
		_b = null
		return
	players.sort_custom(func(p, q): return p.player_index < q.player_index)
	if _a != players[0] or _b != players[1]:
		_set_pairs([])
		_a = players[0]
		_b = players[1]
	if not Net.is_host():
		return
	_update_pairs()
	if not is_linked():
		return
	if not _cross.is_empty():
		_cross_step(delta)
	elif get_link_type() == LinkType.ONE_HAND:
		_spin_step(delta)
	else:
		_end_spin()
	if _cross.is_empty() and _spin.is_empty():
		_check_step_off()
		_distance_constraint()
	_rumble_step(delta)


func _process(_delta: float) -> void:
	for p in World.get_players():
		p.arm_target_left = null
		p.arm_target_right = null
	if not is_linked() or _a == null or _b == null:
		return
	var tension := _tension()
	for pair in _pairs:
		var sa: int = pair.x
		var sb: int = pair.y
		var meet: Vector2 = (_a.shoulder_screen_pos(sa) + _b.shoulder_screen_pos(sb)) * 0.5
		_set_target(_a, sa, meet, tension)
		_set_target(_b, sb, meet, tension)


func _set_target(p: Player, side: int, meet: Vector2, tension: float) -> void:
	if side == Player.Side.LEFT:
		p.arm_target_left = meet
		p.arm_tension_left = tension
	else:
		p.arm_target_right = meet
		p.arm_tension_right = tension


func _tension() -> float:
	if not _spin.is_empty() or (not _cross.is_empty() and _cross.mode != "stand"):
		return 1.0
	var lo := settings.link_distance * 0.5
	return clampf((_dist3d(_a, _b) - lo) / maxf(settings.max_distance - lo, 1.0), 0.0, 1.0)


func _dist3d(p: Player, q: Player) -> float:
	var dh := (p.height - q.height) * World.config.level_world_px
	return sqrt(p.global_position.distance_squared_to(q.global_position) + dh * dh)


func _reach(p: Player, side: int) -> bool:
	if p.held_objects[side] != null:
		return false
	return p.reach_left if side == Player.Side.LEFT else p.reach_right


# ---------------------------------------------------------------- つながる・離れる

func _update_pairs() -> void:
	var kept: Array = []
	for pair in _pairs:
		if _reach(_a, pair.x) and _reach(_b, pair.y):
			kept.append(pair)
	var can_form := not _a.is_airborne() and not _b.is_airborne() \
		and absf(_a.height - _b.height) < settings.same_level_tolerance \
		and _a.global_position.distance_to(_b.global_position) <= settings.link_distance
	if can_form and kept.size() < 2:
		var cands := []
		for sa in [Player.Side.LEFT, Player.Side.RIGHT]:
			for sb in [Player.Side.LEFT, Player.Side.RIGHT]:
				if not (_reach(_a, sa) and _reach(_b, sb)):
					continue
				var used := false
				for k in kept:
					if k.x == sa or k.y == sb:
						used = true
				if used:
					continue
				var d: float = _a.hand_ground_pos(sa).distance_to(_b.hand_ground_pos(sb))
				cands.append([d, Vector2i(sa, sb)])
		cands.sort_custom(func(p, q): return p[0] < q[0])
		for c in cands:
			var v: Vector2i = c[1]
			var clash := false
			for k in kept:
				if k.x == v.x or k.y == v.y:
					clash = true
			if not clash and kept.size() < 2:
				kept.append(v)
	if kept != _pairs:
		_set_pairs(kept)


func _set_pairs(new_pairs: Array) -> void:
	var old_n := _pairs.size()
	var new_n := new_pairs.size()
	var now := Net.local_time()
	if Net.is_host() and _a and _b:
		if old_n == 2 and new_n == 1:
			_two_drop_time = now
		if old_n > 0 and new_n == 0:
			var recoil := old_n == 2 or (now - _two_drop_time) < settings.recoil_window
			_on_release(recoil)
	_pairs = new_pairs
	if Net.is_host() and Net.is_online():
		_rpc_pairs.rpc(new_pairs)
	_emit_changes(old_n, new_n)


func _emit_changes(old_n: int, new_n: int) -> void:
	if old_n == new_n:
		return
	if old_n == 0:
		linked.emit(get_link_type())
	elif new_n == 0:
		unlinked.emit()
	link_type_changed.emit(get_link_type())


@rpc("authority", "call_remote", "reliable")
func _rpc_pairs(new_pairs: Array) -> void:
	var old_n := _pairs.size()
	_pairs = new_pairs
	_emit_changes(old_n, new_pairs.size())


var _suppress_effects := false


## 手つなぎを強制的に切る(やり直しなど)。投げや反動は起きない
func force_unlink() -> void:
	if not Net.is_host() or not is_linked():
		return
	_spin = {}
	_cross = {}
	_suppress_effects = true
	_set_pairs([])
	_suppress_effects = false


## 手を離した時の動き(ホストで計算し、相手の体の状態を引き渡す)
func _on_release(recoil: bool) -> void:
	if _suppress_effects:
		recoil = false
	if not _spin.is_empty():
		var mover: Player = _spin.mover
		var omega: float = _spin.omega
		mover.link_controlled = false
		if absf(omega) >= settings.min_throw_speed:
			var t := Vector2.from_angle(_spin.angle).orthogonal() * signf(omega)
			mover.launch(t, settings.throw_distance * absf(omega) / settings.spin_max_speed, settings.throw_arc_levels)
			thrown.emit(mover)
		_spin = {}
	elif not _cross.is_empty():
		var lower: Player = _cross.lower
		if _cross.mode != "stand":
			lower.link_controlled = false
			lower.start_air(Vector2.ZERO, 0.0, Player.State.FLY)
		_cross = {}
	elif recoil:
		var dir := (_a.global_position - _b.global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		_a.launch(dir, settings.recoil_distance, settings.recoil_arc_levels)
		_b.launch(-dir, settings.recoil_distance, settings.recoil_arc_levels)
		recoiled.emit()
	_a.link_controlled = false
	_b.link_controlled = false
	# 相手の端末の体を、この計算結果から再開させる
	if Net.is_online():
		for p in [_a, _b]:
			if p.owner_peer != Net.my_id() and Net.is_peer_ready(p.owner_peer):
				p.rpc_handoff_state.rpc_id(p.owner_peer, p.pack_state())


# ---------------------------------------------------------------- 距離を保つ

func _distance_constraint() -> void:
	var d := _a.global_position - _b.global_position
	var dh := (_a.height - _b.height) * World.config.level_world_px
	var horiz_max := sqrt(maxf(settings.max_distance * settings.max_distance - dh * dh, 0.0))
	var dl := d.length()
	if dl <= horiz_max or dl < 0.001:
		return
	var excess := dl - horiz_max
	var dir := d / dl
	# 動こうとしている人が、止まっている人を引っ張る
	var ma: float = _a.input.move.length()
	var mb: float = _b.input.move.length()
	var wa := 0.5
	if ma + mb > 0.05:
		wa = mb / (ma + mb)
	_a.move_and_collide(-dir * excess * wa)
	_b.move_and_collide(dir * excess * (1.0 - wa))
	for p: Player in [_a, _b]:
		if not p.is_airborne() and not p.link_controlled:
			p.height = World.height_at(p.global_position)


# ---------------------------------------------------------------- 片手:回転

func _spin_step(delta: float) -> void:
	var idle_a: bool = _a.input.move.length() < 0.2
	var idle_b: bool = _b.input.move.length() < 0.2
	if _spin.is_empty():
		if idle_a == idle_b:
			return
		var axis: Player = _a if idle_a else _b
		var mover: Player = _b if idle_a else _a
		var rel := mover.global_position - axis.global_position
		if rel.length() < settings.max_distance * 0.75:
			return
		var t := rel.normalized().orthogonal()
		var in_t: float = mover.input.move.dot(t)
		if absf(in_t) < 0.5:
			return
		_spin = { axis = axis, mover = mover, angle = rel.angle(), omega = signf(in_t) * 1.0,
			radius = clampf(rel.length(), settings.link_distance, settings.max_distance * 0.95) }
		mover.link_controlled = true
	var ax: Player = _spin.axis
	var mv: Player = _spin.mover
	if ax.input.move.length() > 0.4:
		_end_spin()
		return
	var tangent := Vector2.from_angle(_spin.angle).orthogonal()
	var push: float = mv.input.move.dot(tangent)
	var omega: float = _spin.omega
	if absf(push) > 0.2:
		omega += push * settings.spin_acceleration * delta
	else:
		omega = move_toward(omega, 0.0, settings.spin_friction * delta)
	omega = clampf(omega, -settings.spin_max_speed, settings.spin_max_speed)
	var angle: float = _spin.angle + omega * delta
	var target: Vector2 = ax.global_position + Vector2.from_angle(angle) * _spin.radius
	mv.collision_mask = Layers.walker_mask()
	var col := mv.move_and_collide(target - mv.global_position)
	if col:
		omega *= -0.3
		angle = (mv.global_position - ax.global_position).angle()
	mv.height = World.height_at(mv.global_position)
	mv.velocity = tangent * omega * _spin.radius
	if absf(omega) > 0.1:
		mv.facing = tangent * signf(omega)
	ax.facing = (mv.global_position - ax.global_position).normalized()
	_spin.omega = omega
	_spin.angle = angle
	if absf(omega) < 0.3 and absf(push) < 0.2:
		_end_spin()


func _end_spin() -> void:
	if _spin.is_empty():
		return
	_spin.mover.link_controlled = false
	_spin.mover.velocity = Vector2.ZERO
	_spin = {}


# ---------------------------------------------------------------- 段またぎ

func _check_step_off() -> void:
	for x: Player in [_a, _b]:
		var y: Player = _b if x == _a else _a
		if x.is_airborne() or y.is_airborne() or x.state == Player.State.POSE:
			continue
		var mv: Vector2 = x.input.move
		if mv.length() < 0.5:
			continue
		var n := Vector2(signf(mv.x), 0) if absf(mv.x) >= absf(mv.y) else Vector2(0, signf(mv.y))
		var p := x.global_position + n * settings.edge_probe
		if not World.has_ground(p):
			continue
		var drop := x.height - World.height_at(p)
		if drop < 0.9 or drop > settings.max_step_levels + 0.01:
			continue
		if absf(y.height - x.height) > 0.3:
			continue
		var t := World.get_terrain()
		if t == null:
			continue
		var cell := t.local_to_cell(t.to_local(p))
		var ts := Vector2(World.config.tile_size)
		var origin := t.to_global(t.cell_origin(cell))
		var edge: float
		var axis := 0 if n.x != 0.0 else 1
		if axis == 0:
			edge = origin.x if n.x > 0.0 else origin.x + ts.x
		else:
			edge = origin.y if n.y > 0.0 else origin.y + ts.y
		_cross = { lower = x, upper = y, n = n, axis = axis, edge = edge,
			upper_level = x.height, mode = "drop", theta = 0.0, theta_v = 0.0, vz = 0.0 }
		x.link_controlled = true
		x.state = Player.State.HANG
		x.global_position = _on_axis(x.global_position, axis, edge + n[axis] * _r0(x))
		return


func _r0(p: Player) -> float:
	var shape := p.get_node("CollisionShape2D").shape as CircleShape2D
	return (shape.radius if shape else 5.0) + 1.0


func _on_axis(v: Vector2, axis: int, value: float) -> Vector2:
	if axis == 0:
		return Vector2(value, v.y)
	return Vector2(v.x, value)


func _cross_step(delta: float) -> void:
	var lower: Player = _cross.lower
	var upper: Player = _cross.upper
	var n: Vector2 = _cross.n
	var axis: int = _cross.axis
	var edge: float = _cross.edge
	var lw := World.config.level_world_px
	var L := settings.max_distance
	var r0 := _r0(lower)
	# 上の人:縁から離れようとすると「引き上げ」
	var dist_up := (edge - upper.global_position[axis]) * n[axis]
	var pulling := false
	if dist_up > settings.edge_margin:
		pulling = true
		upper.move_and_collide(n * (dist_up - settings.edge_margin))
		upper.height = World.height_at(upper.global_position)
	var pivot := _on_axis(upper.global_position, axis, edge)
	var hang_drop := sqrt(maxf(L * L - r0 * r0, 0.0)) / lw
	var hang_height: float = _cross.upper_level - hang_drop
	match _cross.mode:
		"drop":
			_cross.vz -= lower.fly_gravity * delta
			lower.height += _cross.vz * delta
			lower.global_position = _follow_lateral(lower.global_position, pivot, axis, delta)
			var ground := World.height_at(lower.global_position)
			if lower.height <= ground:
				lower.height = ground
				_to_stand(lower)
			elif lower.height <= hang_height:
				lower.height = hang_height
				_cross.mode = "hang"
				_cross.theta = 0.0
				_cross.theta_v = 0.0
				lower.state = Player.State.HANG
				hang_started.emit(lower)
			if pulling and _cross.mode != "stand":
				_cross.mode = "climb"
		"hang":
			var push: float = lower.input.move.dot(n)
			var acc: float = -(settings.swing_gravity / L) * sin(_cross.theta) - settings.swing_damping * _cross.theta_v + push * settings.swing_push
			_cross.theta_v += acc * delta
			_cross.theta += _cross.theta_v * delta
			if _cross.theta < 0.0:
				_cross.theta = 0.0
				_cross.theta_v = -_cross.theta_v * 0.3
			_cross.theta = minf(_cross.theta, 1.3)
			var r: float = r0 + L * sin(_cross.theta)
			var pos := _on_axis(pivot, axis, edge + n[axis] * r)
			var lateral_axis := 1 - axis
			pos[lateral_axis] = lerpf(lower.global_position[lateral_axis], pivot[lateral_axis], clampf(delta * 8.0, 0.0, 1.0))
			lower.global_position = pos
			lower.height = _cross.upper_level - L * cos(_cross.theta) / lw
			lower.velocity = n * _cross.theta_v * L
			if lower.height <= World.height_at(lower.global_position):
				lower.height = World.height_at(lower.global_position)
				_to_stand(lower)
			elif pulling:
				_cross.mode = "climb"
		"climb":
			if pulling:
				lower.state = Player.State.CLIMB
				lower.height += settings.pull_speed * delta
				var target := _on_axis(pivot, axis, edge + n[axis] * r0)
				lower.global_position = lower.global_position.move_toward(target, 40.0 * delta)
				if lower.height >= _cross.upper_level - 0.05:
					lower.global_position = _on_axis(pivot, axis, edge - n[axis] * r0)
					lower.height = _cross.upper_level
					lower.state = Player.State.WALK
					lower.link_controlled = false
					_cross = {}
					pulled_up.emit(lower)
			else:
				_cross.mode = "drop"
				_cross.vz = 0.0
		"stand":
			if pulling:
				_cross.mode = "climb"
				lower.link_controlled = true
			elif absf(lower.height - upper.height) < 0.3:
				_cross = {}
			else:
				_distance_constraint()


func _follow_lateral(pos: Vector2, pivot: Vector2, axis: int, delta: float) -> Vector2:
	var lat := 1 - axis
	pos[lat] = lerpf(pos[lat], pivot[lat], clampf(delta * 8.0, 0.0, 1.0))
	return pos


func _to_stand(lower: Player) -> void:
	_cross.mode = "stand"
	lower.link_controlled = false
	lower.state = Player.State.WALK
	lower.velocity = Vector2.ZERO


# ---------------------------------------------------------------- 振動

func _rumble_step(delta: float) -> void:
	_rumble_timer -= delta
	if _rumble_timer > 0.0:
		return
	_rumble_timer = 0.1
	var holder: Player = null
	var k := 0.0
	if not _cross.is_empty() and _cross.mode in ["hang", "climb", "drop"]:
		holder = _cross.upper
		k = 1.0
	elif not _spin.is_empty():
		holder = _spin.axis
		k = absf(_spin.omega) / settings.spin_max_speed
	elif _tension() > 0.95:
		k = 0.4
		holder = _a if _a.input.move.length() < _b.input.move.length() else _b
	if holder and k > 0.05:
		holder.rumble(settings.rumble_weak * k, settings.rumble_strong * k, 0.12)
