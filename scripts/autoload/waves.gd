extends Node
## Waves(自動読み込み)
## 音の波の計算と描画。波は発した段の高さだけを水平に進み、それより高い地形で止まり、
## 低い地形の上は通り過ぎ、反射する壁で跳ね返る。
##
## 波を出す: Waves.emit({ origin = 位置, size = 大きさ, shape = "res://…/voice.tres", source = "P1", … })
##   主な項目: origin(地面の位置) level(省略時は足元の段) size(1=普通) shape(WaveShape のパス)
##             color source(音源の名前) dir+spread(向きと広がりの半分の角度。省略で全方向)
##             global(true で段のルールを無視して島全体に届く「歌の波」) payload(付けて送る情報)
##             hidden(true で波面を描かない。受け取りの計算はする)
##             show_reach + reach_color(出た瞬間に、届く範囲の外側の線を薄く描く)
## 波を出した端末から相手の端末にも送られ、両方で同じ計算をする。
## 受け取りは WaveReceiver 部品で行う。

signal wave_emitted(info: Dictionary)

const OVERLAY_Z := 150

## 波の計算と描画を止める(確認用)
var paused := false
## この端末のゲーム内の時計(秒)。重なりの判定に使う
var clock := 0.0

var _waves: Array = []        # Wave
var _by_id := {}              # 波のID -> Wave
var _counter := 0
var _shape_cache := {}
var _bins := {}               # row -> [PackedVector2Array, PackedColorArray, PackedFloat32Array]
var _dirty_rows := {}
var _overlay: Node2D           # 地形が無い時の描画先+歌の波+デバッグ表示
var _overlay_lines: Array = []  # [a, b, color, width] (画面座標)


class Wave:
	var id := 0
	var p: Dictionary
	var shape: WaveShape
	var origin := Vector2.ZERO
	var level := 0
	var size := 1.0
	var color := Color.WHITE
	var speed := 160.0
	var reach := 100.0
	var age := 0.0
	var is_global := false
	var full_circle := true
	var rays: Array = []       # [PackedVector2Array 点, PackedFloat32Array 累積距離]
	var angles := PackedFloat32Array()
	var hits := {}

	func front() -> float:
		return age * speed

	func strength_at(s: float) -> float:
		return maxf(0.0, size * (1.0 - s / reach))

	func finished() -> bool:
		return front() - (shape.rings - 1) * shape.ring_spacing > reach


func _ready() -> void:
	process_priority = 5


# ---------------------------------------------------------------- 出す

## 波を出す(この端末が音の持ち主の時に呼ぶ)。相手の端末にも送る。戻り値は波のID
func emit(params: Dictionary) -> int:
	var p := params.duplicate()
	_counter += 1
	p.id = Net.my_id() * 1000000 + _counter
	if not p.has("time"):
		p.time = Net.time()
	_fill_defaults(p)
	_spawn(p, 0.0)
	if Net.is_online():
		for id in Net.ready_remote_ids():
			_rpc_emit.rpc_id(id, p)
	return p.id


## 相手から届いた波。送られてくるまでにかかった時間の分だけ、波を進めた状態で始める
@rpc("any_peer", "call_remote", "reliable")
func _rpc_emit(p: Dictionary) -> void:
	var age := maxf(0.0, Net.time() - float(p.time))
	_spawn(p, age)


func _fill_defaults(p: Dictionary) -> void:
	if not p.has("origin"):
		p.origin = Vector2.ZERO
	if not p.has("level"):
		p.level = World.level_at(p.origin)
	if not p.has("size"):
		p.size = 1.0
	if not p.has("shape"):
		p.shape = "res://resources/wave_shapes/generic.tres"
	if p.shape is Resource:
		p.shape = p.shape.resource_path
	if not p.has("source"):
		p.source = "?"
	if not p.has("payload"):
		p.payload = {}


func _load_shape(path: String) -> WaveShape:
	if not _shape_cache.has(path):
		var s = load(path)
		_shape_cache[path] = s if s is WaveShape else load("res://resources/wave_shapes/generic.tres")
	return _shape_cache[path]


func _spawn(p: Dictionary, age: float) -> void:
	var w := Wave.new()
	w.id = p.id
	w.p = p
	w.shape = _load_shape(p.shape)
	w.origin = p.origin
	w.level = int(p.level)
	w.size = maxf(0.01, float(p.size))
	w.color = p.get("color", w.shape.color)
	w.speed = w.shape.speed * float(p.get("speed_scale", 1.0))
	w.reach = w.speed * w.shape.lifetime * w.size
	if p.has("reach"):
		w.reach = float(p.reach)
	w.is_global = bool(p.get("global", false))
	w.age = age
	_trace(w)
	_waves.append(w)
	_by_id[w.id] = w
	wave_emitted.emit(p)
	# 届くまでに通り過ぎた分の受け取りもまとめて調べる
	if age > 0.0:
		_check_receivers(w, 0.0, w.front())


# ---------------------------------------------------------------- 道筋の計算

func _trace(w: Wave) -> void:
	var count := w.shape.ray_count
	var spread := float(w.p.get("spread", PI))
	var center := 0.0
	if w.p.has("dir") and spread < PI - 0.001:
		center = Vector2(w.p.dir).angle()
		w.full_circle = false
		count = maxi(12, int(count * spread / PI))
	var terrain := World.get_terrain()
	var walls := get_tree().get_nodes_in_group("sound_wall")
	w.angles.resize(count)
	for i in range(count):
		var a: float
		if w.full_circle:
			a = TAU * i / count
		else:
			a = center - spread + 2.0 * spread * i / maxf(count - 1, 1)
		w.angles[i] = a
		var d := Vector2.from_angle(a)
		if w.is_global:
			w.rays.append([PackedVector2Array([w.origin, w.origin + d * w.reach]), PackedFloat32Array([0.0, w.reach])])
		else:
			w.rays.append(_trace_ray(w.origin, d, w.reach, w.level, w.shape.max_bounces, terrain, walls))


func _trace_ray(origin: Vector2, dir: Vector2, reach: float, level: int, max_bounces: int, terrain: Terrain, walls: Array) -> Array:
	var pts := PackedVector2Array([origin])
	var cum := PackedFloat32Array([0.0])
	var p := origin
	var d := dir
	var traveled := 0.0
	var bounces := 0
	while traveled < reach - 0.01:
		var remaining := reach - traveled
		var best := { hit = false, t = remaining, normal = Vector2.ZERO, reflect = false }
		if terrain:
			var r := terrain.trace_wave(p, d, remaining, level)
			if r.hit and r.t < best.t:
				best = r
		for wall in walls:
			if not wall.blocks_level(level):
				continue
			var r2: Dictionary = wall.intersect(p, d, best.t)
			if r2.hit and r2.t < best.t:
				best = r2
		var q: Vector2 = p + d * best.t
		traveled += best.t
		pts.append(q)
		cum.append(traveled)
		if not best.hit:
			break
		if best.reflect and bounces < max_bounces:
			d = d.bounce(best.normal).normalized()
			p = q + d * 0.05
			bounces += 1
		else:
			break
	return [pts, cum]


## 道筋の上で、出発から距離 s の所の位置。届かない(止まった・寿命)なら null
static func pos_on_ray(ray: Array, s: float):
	var cum: PackedFloat32Array = ray[1]
	if s < 0.0 or s > cum[cum.size() - 1]:
		return null
	var pts: PackedVector2Array = ray[0]
	for k in range(1, cum.size()):
		if s <= cum[k]:
			var seg := cum[k] - cum[k - 1]
			var f := (s - cum[k - 1]) / seg if seg > 0.0 else 0.0
			return pts[k - 1].lerp(pts[k], f)
	return pts[pts.size() - 1]


static func leg_on_ray(ray: Array, s: float) -> int:
	var cum: PackedFloat32Array = ray[1]
	for k in range(1, cum.size()):
		if s <= cum[k]:
			return k - 1
	return cum.size() - 2


static func dir_on_ray(ray: Array, s: float) -> Vector2:
	var pts: PackedVector2Array = ray[0]
	var k := leg_on_ray(ray, s)
	return (pts[k + 1] - pts[k]).normalized()


# ---------------------------------------------------------------- 毎フレーム

func _process(delta: float) -> void:
	if paused:
		return
	clock += delta
	for w: Wave in _waves.duplicate():
		var s0: float = w.front()
		w.age += delta
		_check_receivers(w, s0, w.front())
		if w.finished():
			_waves.erase(w)
			_by_id.erase(w.id)
	_rebuild_bins()


func active_wave_count() -> int:
	return _waves.size()


## 波(ID)の届く範囲に、地面の位置 pos・半径 radius・段 level の物が入っているか(壁で止まる所も考える)。
## 波面が届くのを待たずに、出た瞬間に分かる。波がもう無ければ false
func reaches(wave_id: int, pos: Vector2, radius: float, level: int) -> bool:
	var w: Wave = _by_id.get(wave_id)
	if w == null:
		return false
	if not w.is_global and level != w.level:
		return false
	var dist := pos.distance_to(w.origin)
	if dist > w.reach + radius:
		return false
	if dist <= radius:
		return true
	var ang := (pos - w.origin).angle()
	var window := (radius + 2.0) / maxf(dist, 1.0) + TAU / w.rays.size()
	for i in range(w.rays.size()):
		var ray: Array = w.rays[i]
		var cum: PackedFloat32Array = ray[1]
		# 最初の直線だけ方向で絞る(反射した先は全部調べる)
		if cum.size() <= 2 and absf(angle_difference(w.angles[i], ang)) > window:
			continue
		if _ray_passes(ray, 0.0, w.reach, pos, radius) >= 0.0:
			return true
	return false


# 出た瞬間に、届く範囲の外側の線(最初の壁で止まる所、または届く距離)を描く。時間とともに薄くなる
func _draw_reach_outlines() -> void:
	var lp := World.config.level_px
	for w: Wave in _waves:
		if not w.p.get("show_reach", false) or w.is_global:
			continue
		var base: Color = w.p.get("reach_color", Color(1.0, 0.62, 0.25, 0.45))
		var life := w.reach / maxf(w.speed, 1.0)
		var fade := clampf(1.0 - w.age / maxf(life, 0.01), 0.0, 1.0)
		var c := Color(base.r, base.g, base.b, base.a * fade)
		var off := Vector2(0, -w.level * lp)
		var first = null
		var prev = null
		for i in range(w.rays.size()):
			var ray: Array = w.rays[i]
			var pts: PackedVector2Array = ray[0]
			var end: Vector2 = pts[1] + off
			if prev != null and prev.distance_to(end) < 40.0:
				_overlay.draw_line(prev, end, c, 1.5)
			if first == null:
				first = end
			prev = end
		if w.full_circle and first != null and prev != null and prev.distance_to(first) < 40.0:
			_overlay.draw_line(prev, first, c, 1.5)


func _check_receivers(w: Wave, s0: float, s1: float) -> void:
	if s1 <= s0:
		return
	for r in get_tree().get_nodes_in_group("wave_receiver"):
		if not r.is_listening():
			continue
		if not w.is_global and r.get_level() != w.level:
			continue
		if not r.accepts(w.p):
			continue
		var q: Vector2 = r.global_position
		var rad: float = r.radius
		var dist := q.distance_to(w.origin)
		if dist > s1 + rad:
			continue
		var rid: int = r.get_instance_id()
		if w.is_global:
			if dist >= s0 - rad and not w.hits.has(rid):
				w.hits[rid] = true
				_deliver(r, w, dist, (q - w.origin).normalized(), 0)
			continue
		var ang := (q - w.origin).angle()
		var window := (rad + 2.0) / maxf(dist, 1.0) + TAU / w.rays.size()
		for i in range(w.rays.size()):
			var ray: Array = w.rays[i]
			var cum: PackedFloat32Array = ray[1]
			if cum[cum.size() - 1] < s0:
				continue
			# 最初の直線の上にいる光線は、方向が近い物だけ調べる
			if cum.size() > 1 and s1 <= cum[1] and absf(angle_difference(w.angles[i], ang)) > window:
				continue
			var hit := _ray_passes(ray, s0, s1, q, rad)
			if hit < 0.0:
				continue
			var leg := leg_on_ray(ray, hit)
			var key := rid * 16 + leg
			if w.hits.has(key):
				continue
			w.hits[key] = true
			_deliver(r, w, hit, dir_on_ray(ray, hit), leg)


# 光線の s0〜s1 の部分が、点 q から半径 rad 以内を通るか。通るならその距離、通らなければ -1
func _ray_passes(ray: Array, s0: float, s1: float, q: Vector2, rad: float) -> float:
	var cum: PackedFloat32Array = ray[1]
	var total := cum[cum.size() - 1]
	var a := clampf(s0, 0.0, total)
	var b := clampf(s1, 0.0, total)
	if b <= a:
		return -1.0
	var marks := [a]
	for k in range(1, cum.size() - 1):
		if cum[k] > a and cum[k] < b:
			marks.append(cum[k])
	marks.append(b)
	for k in range(marks.size() - 1):
		var pa: Vector2 = pos_on_ray(ray, marks[k])
		var pb: Vector2 = pos_on_ray(ray, marks[k + 1])
		var c := Geometry2D.get_closest_point_to_segment(q, pa, pb)
		if c.distance_to(q) <= rad:
			var seg := pa.distance_to(pb)
			var f := pa.distance_to(c) / seg if seg > 0.0 else 0.0
			return lerpf(marks[k], marks[k + 1], f)
	return -1.0


func _deliver(r: Node, w: Wave, s: float, dir: Vector2, bounce: int) -> void:
	var info := {
		wave_id = w.id, source = w.p.source, kind = w.shape.kind, strength = w.strength_at(s),
		time = Net.time(), local_time = clock, dir = dir, bounce = bounce, level = w.level, distance = s,
		origin = w.origin, payload = w.p.payload, emit_time = w.p.time, size = w.size,
		is_global = w.is_global, pitch = w.p.get("pitch", -1.0), stage = w.p.get("stage", 0),
	}
	r.receive(info)


# ---------------------------------------------------------------- 描画

func _rebuild_bins() -> void:
	var terrain := World.get_terrain()
	var old_rows := _bins.keys()
	_bins.clear()
	_overlay_lines.clear()
	var lp := World.config.level_px
	var th := float(World.config.tile_size.y)
	for w: Wave in _waves:
		if w.p.get("hidden", false):
			continue
		var s_front: float = w.front()
		var col: Color = w.color
		for k in range(w.shape.rings):
			var s := s_front - k * w.shape.ring_spacing
			if s <= 0.0 or s > w.reach:
				continue
			var alpha := col.a * clampf(1.0 - s / w.reach, 0.0, 1.0) * (1.0 - 0.25 * k)
			var c := Color(col.r, col.g, col.b, alpha)
			_front_segments(w, s, c, terrain, lp, th)
	if _overlay == null or not is_instance_valid(_overlay):
		_make_overlay()
	if _overlay:
		_overlay.queue_redraw()
	if terrain:
		var rows := {}
		for r in old_rows:
			rows[r] = true
		for r in _bins.keys():
			rows[r] = true
		for node in terrain.get_wave_row_nodes():
			if rows.has(node.row):
				node.queue_redraw()


func _front_segments(w: Wave, s: float, c: Color, terrain: Terrain, lp: float, th: float) -> void:
	var n: int = w.rays.size()
	var pts: Array = []
	pts.resize(n)
	var legs := PackedInt32Array()
	legs.resize(n)
	for i in range(n):
		var ray: Array = w.rays[i]
		var p = pos_on_ray(ray, s)
		if p != null and w.shape.zigzag > 0.0:
			var arc := w.angles[i] * s
			var tri := absf(fposmod(arc / w.shape.zigzag_length, 2.0) - 1.0) * 2.0 - 1.0
			p += dir_on_ray(ray, s) * tri * w.shape.zigzag
		pts[i] = p
		legs[i] = leg_on_ray(ray, s) if p != null else -1
	var gap := maxf(TAU * s / n * 3.0, 6.0) + w.shape.zigzag * 2.0
	var last := n if w.full_circle else n - 1
	var off := Vector2(0, -w.level * lp)
	for i in range(last):
		var j := (i + 1) % n
		if pts[i] == null or pts[j] == null or legs[i] != legs[j]:
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if a.distance_to(b) > gap:
			continue
		if terrain == null or w.is_global:
			_overlay_lines.append([a + off, b + off, c, w.shape.line_width])
			continue
		var la := terrain.to_local(a)
		var lb := terrain.to_local(b)
		var row := floori((la.y + lb.y) * 0.5 / th)
		if not _bins.has(row):
			_bins[row] = [PackedVector2Array(), PackedColorArray(), PackedFloat32Array()]
		var bin: Array = _bins[row]
		bin[0].append(la + off)
		bin[0].append(lb + off)
		bin[1].append(c)
		bin[2].append(w.shape.line_width)


## 地形の行ノード(TerrainRow)から呼ばれる
func draw_row(canvas: CanvasItem, row: int, _terrain: Terrain) -> void:
	if not _bins.has(row):
		return
	var bin: Array = _bins[row]
	canvas.draw_set_transform(Vector2(0, -canvas.position.y))
	var pts: PackedVector2Array = bin[0]
	var cols: PackedColorArray = bin[1]
	var widths: PackedFloat32Array = bin[2]
	for k in range(cols.size()):
		canvas.draw_line(pts[k * 2], pts[k * 2 + 1], cols[k], widths[k])
	canvas.draw_set_transform(Vector2.ZERO)


func _make_overlay() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_overlay = Node2D.new()
	_overlay.name = "WaveOverlay"
	_overlay.z_index = OVERLAY_Z
	_overlay.z_as_relative = false
	_overlay.draw.connect(_draw_overlay)
	scene.add_child(_overlay, false, Node.INTERNAL_MODE_BACK)


func _draw_overlay() -> void:
	for l in _overlay_lines:
		_overlay.draw_line(l[0], l[1], l[2], l[3])
	_draw_reach_outlines()
	if World.debug_wave_range:
		var lp := World.config.level_px
		for w: Wave in _waves:
			if w.is_global:
				continue
			var off := Vector2(0, -w.level * lp)
			var c := Color(w.color.r, w.color.g, w.color.b, 0.25)
			var prev = null
			for i in range(w.rays.size()):
				var ray: Array = w.rays[i]
				var pts: PackedVector2Array = ray[0]
				var end: Vector2 = pts[pts.size() - 1] + off
				if prev != null and prev.distance_to(end) < 40.0:
					_overlay.draw_line(prev, end, c, 1.0)
				prev = end
			_overlay.draw_circle(w.origin + off, 2.0, c)
