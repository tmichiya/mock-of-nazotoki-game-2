@tool
class_name Terrain
extends TileMapLayer
## 高さのある地形。terrain_tileset.tres のタイルを塗るだけで段差と斜面ができる。
## 塗ったタイル自体は描かず(実行時は透明)、段の高さに合わせた床・崖の側面・輪郭・影を自動で描く。
## タイルは「地面の位置」に塗る。高い段の床は、塗った場所より段の高さの分だけ上に描かれる。
## エディタでは editor_view で「両方 / 塗る用 / 仕上がり」を切り替えられる。
##
## タイルのカスタムデータ:
##   level … 段番号(斜面は低い側の段)
##   shape … 0=平地 1=奥(上)に向かって上る 2=手前(下)に向かって上る 3=右に向かって上る 4=左に向かって上る
##
## 他の部品からの問い合わせ:
##   get_height_at(global_pos) -> float   その位置の高さ(段単位の小数。斜面では連続的に変わる)
##   get_level_at(global_pos) -> int      その位置の段番号(斜面は最も近い段)
##   is_blocked_between(a, b, height) -> bool  2点の間に height より高い地形があるか
##   has_ground_at(global_pos) -> bool    島の上か

signal terrain_rebuilt

enum Shape { FLAT, UP_NORTH, UP_SOUTH, UP_EAST, UP_WEST }

const VOID_HEIGHT := -1.0
const ROW_MARGIN := 8

## 世界の寸法(全部品で共通の res://resources/settings/world_config.tres を使う)
@export var config: WorldConfig:
	set(v):
		if config and config.changed.is_connected(_queue_rebuild):
			config.changed.disconnect(_queue_rebuild)
		config = v
		if config:
			config.changed.connect(_queue_rebuild)
		_queue_rebuild()
## 段ごとの見た目(全段の色・模様はここだけで決まる)
@export var style: LevelStyle:
	set(v):
		if style and style.changed.is_connected(_queue_redraw_rows):
			style.changed.disconnect(_queue_redraw_rows)
		style = v
		if style:
			style.changed.connect(_queue_redraw_rows)
		_queue_redraw_rows()

@export_group("音の波")
## 崖が音の波を跳ね返すか(初期値)。場所ごとに変えたい時は SoundReflectZone を置く
@export var cliffs_reflect := true

@export_group("エディタ表示")
enum EditorView { BOTH, PAINT, RENDERED }
## エディタでの見せ方。BOTH = 仕上がりの上に、塗ったタイルを薄く重ねる(どこに塗ったか分かる)/
## PAINT = 塗ったタイルだけ(真上から見た平らな地図。塗りやすい)/ RENDERED = 仕上がりだけ
@export var editor_view := EditorView.BOTH:
	set(v):
		editor_view = v
		_apply_view()
## BOTH の時に、塗ったタイルをどれくらい透かして重ねるか
@export_range(0.0, 1.0) var logic_alpha_in_editor := 0.35:
	set(v):
		logic_alpha_in_editor = v
		_apply_view()
## パレットの見た目(色・模様)を、今の段の見た目(style)に合わせて作り直す
@export_tool_button("パレットを段の見た目に合わせる") var rebuild_palette_button := _rebuild_palette
## 段番号を各マスに表示する(実行中は F1 でも切り替え)
@export var show_level_numbers := false:
	set(v):
		show_level_numbers = v
		_queue_redraw_rows()

# 段・形の早見表: Vector2i(cell) -> Vector2i(level, shape)
var _cells: Dictionary = {}
var _rows: Dictionary = {}          # row -> TerrainRow
var _wave_rows: Dictionary = {}     # row -> TerrainRow(波を描く)
var _row_range := Vector2i(0, -1)
var _col_range := Vector2i(0, -1)
var _body: StaticBody2D
var _rebuild_queued := false
var _redraw_queued := false


func _init() -> void:
	y_sort_enabled = true


func _enter_tree() -> void:
	add_to_group("terrain")
	if config == null:
		config = WorldConfig.get_default()
	if style == null:
		style = load("res://resources/settings/level_style.tres")
	if tile_set == null:
		tile_set = load("res://resources/terrain/terrain_tileset.tres")


func _ready() -> void:
	y_sort_enabled = true
	if not changed.is_connected(_queue_rebuild):
		changed.connect(_queue_rebuild)
	_rebuild()
	_apply_view()


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	var p := get_parent() as CanvasItem
	if p and not p.y_sort_enabled:
		w.append("親ノードの「Y Sort Enabled」をオンにしてください(キャラと地形の前後関係が正しくなりません)。")
	if config and config.has_slope_warning():
		w.append("WorldConfig.level_px がマスの奥行き以上なので、手前に向かって上る斜面が潰れて見えません。")
	if tile_set and config and tile_set.tile_size != config.tile_size:
		w.append("タイルセットのタイルの大きさが WorldConfig.tile_size と違います。")
	return w


# ---------------------------------------------------------------- 塗ったタイルの見せ方

## 塗ったタイルは self_modulate の透明度で隠す(タイルごとの処理をしないので重くならない。
## 地形の描画は子のノードなので self_modulate の影響を受けない)
func _apply_view() -> void:
	if not is_inside_tree():
		return
	var logic_a := 0.0
	var rendered := true
	if Engine.is_editor_hint():
		match editor_view:
			EditorView.BOTH:
				logic_a = logic_alpha_in_editor
			EditorView.PAINT:
				logic_a = 1.0
				rendered = false
			EditorView.RENDERED:
				logic_a = 0.0
	self_modulate = Color(1, 1, 1, logic_a)
	for r in _rows.values():
		r.visible = rendered
	for r in _wave_rows.values():
		r.visible = rendered


func _rebuild_palette() -> void:
	if config == null or style == null:
		return
	var err := TerrainPalette.save(config, style)
	if err != OK:
		push_error("パレット画像を保存できませんでした: %s" % error_string(err))


# ---------------------------------------------------------------- 組み立て

func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _queue_redraw_rows() -> void:
	if _redraw_queued or not is_inside_tree():
		return
	_redraw_queued = true
	_redraw_all.call_deferred()


func _redraw_all() -> void:
	_redraw_queued = false
	for r in _rows.values():
		r.queue_redraw()


func _rebuild() -> void:
	_rebuild_queued = false
	if config == null:
		return
	_cells.clear()
	var min_r := 1 << 30
	var max_r := -(1 << 30)
	var min_c := 1 << 30
	var max_c := -(1 << 30)
	for cell in get_used_cells():
		var td := get_cell_tile_data(cell)
		if td == null:
			continue
		var level := 0
		var shape := 0
		if tile_set and tile_set.has_custom_data_layer_by_name("level"):
			level = int(td.get_custom_data("level"))
		else:
			level = get_cell_atlas_coords(cell).y
		if tile_set and tile_set.has_custom_data_layer_by_name("shape"):
			shape = int(td.get_custom_data("shape"))
		else:
			shape = get_cell_atlas_coords(cell).x
		_cells[cell] = Vector2i(level, shape)
		min_r = mini(min_r, cell.y)
		max_r = maxi(max_r, cell.y)
		min_c = mini(min_c, cell.x)
		max_c = maxi(max_c, cell.x)
	if _cells.is_empty():
		_row_range = Vector2i(0, -1)
		_col_range = Vector2i(0, -1)
	else:
		_row_range = Vector2i(min_r - ROW_MARGIN, max_r + ROW_MARGIN)
		_col_range = Vector2i(min_c, max_c)
	_sync_row_nodes()
	if not Engine.is_editor_hint():
		_build_collision()
	update_configuration_warnings()
	terrain_rebuilt.emit()


func _sync_row_nodes() -> void:
	var th := float(config.tile_size.y)
	var wanted := {}
	for r in range(_row_range.x, _row_range.y + 1):
		wanted[r] = true
	for r in _rows.keys():
		if not wanted.has(r):
			_rows[r].queue_free()
			_rows.erase(r)
			_wave_rows[r].queue_free()
			_wave_rows.erase(r)
	for r in wanted.keys():
		if not _rows.has(r):
			var n := TerrainRow.new()
			n.terrain = self
			n.row = r
			n.kind = TerrainRow.Kind.GROUND
			add_child(n, false, Node.INTERNAL_MODE_FRONT)
			_rows[r] = n
			var w := TerrainRow.new()
			w.terrain = self
			w.row = r
			w.kind = TerrainRow.Kind.WAVES
			add_child(w, false, Node.INTERNAL_MODE_FRONT)
			_wave_rows[r] = w
		# 地面の y で並べ替える。行の上端より少しだけ前にして、その行に立つ物より先に描く
		_rows[r].position = Vector2(0, r * th - 0.5)
		_wave_rows[r].position = Vector2(0, r * th - 0.25)
		_rows[r].queue_redraw()
	_apply_view()


func get_wave_row_nodes() -> Array:
	return _wave_rows.values()


func get_row_range() -> Vector2i:
	return _row_range


# ---------------------------------------------------------------- 形と高さ

func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)


func get_cell_level(cell: Vector2i) -> int:
	return _cells[cell].x if _cells.has(cell) else -1


func get_cell_shape(cell: Vector2i) -> int:
	return _cells[cell].y if _cells.has(cell) else -1


## マスの4隅の高さ [北西, 北東, 南東, 南西]。空のマスは空配列
func corners(cell: Vector2i) -> PackedFloat32Array:
	if not _cells.has(cell):
		return PackedFloat32Array()
	var lv: float = _cells[cell].x
	var hi := lv + 1.0
	match _cells[cell].y:
		Shape.UP_NORTH:
			return PackedFloat32Array([hi, hi, lv, lv])
		Shape.UP_SOUTH:
			return PackedFloat32Array([lv, lv, hi, hi])
		Shape.UP_EAST:
			return PackedFloat32Array([lv, hi, hi, lv])
		Shape.UP_WEST:
			return PackedFloat32Array([hi, lv, lv, hi])
	return PackedFloat32Array([lv, lv, lv, lv])


func cell_max_height(cell: Vector2i) -> float:
	var c := corners(cell)
	if c.is_empty():
		return VOID_HEIGHT
	return maxf(maxf(c[0], c[1]), maxf(c[2], c[3]))


func local_to_cell(p: Vector2) -> Vector2i:
	var ts := Vector2(config.tile_size)
	return Vector2i(floori(p.x / ts.x), floori(p.y / ts.y))


func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Vector2(config.tile_size)


func _height_local(p: Vector2) -> float:
	var cell := local_to_cell(p)
	var c := corners(cell)
	if c.is_empty():
		return VOID_HEIGHT
	var ts := Vector2(config.tile_size)
	var f := (p - cell_origin(cell)) / ts
	var top := lerpf(c[0], c[1], f.x)
	var bottom := lerpf(c[3], c[2], f.x)
	return lerpf(top, bottom, f.y)


func get_height_at(global_pos: Vector2) -> float:
	return _height_local(to_local(global_pos))


func get_level_at(global_pos: Vector2) -> int:
	return roundi(get_height_at(global_pos))


func has_ground_at(global_pos: Vector2) -> bool:
	return _cells.has(local_to_cell(to_local(global_pos)))


## 地面の位置 ground(グローバル)、高さ height に立つ、大きさ size の物が、手前の地形に隠れているか
func occludes(ground: Vector2, height: float, size: Vector2) -> bool:
	if config == null:
		return false
	var p := to_local(ground)
	var ts := Vector2(config.tile_size)
	var lp := config.level_px
	var feet_y := p.y - height * lp
	var top_y := feet_y - size.y
	var row := floori(p.y / ts.y)
	var c0 := floori((p.x - size.x * 0.5) / ts.x)
	var c1 := floori((p.x + size.x * 0.5) / ts.x)
	var max_h := 16.0
	var rows_ahead := ceili((max_h * lp) / ts.y) + 1
	for r in range(row + 1, row + rows_ahead + 1):
		for c in range(c0, c1 + 1):
			var cell := Vector2i(c, r)
			if not _cells.has(cell):
				continue
			var hm := cell_max_height(cell)
			if hm <= height + 0.01:
				continue
			var cell_top := r * ts.y - hm * lp
			# 隠れる量が体の1/4以上なら「隠れている」
			if cell_top < feet_y - (feet_y - top_y) * 0.25:
				return true
	return false


## 2点の間に、指定の高さより高い地形があるか(端点を含む。島の外は「低い」とみなす)
func is_blocked_between(a: Vector2, b: Vector2, height: float) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	var dist := la.distance_to(lb)
	var step := minf(config.tile_size.x, config.tile_size.y) * 0.25
	var n := maxi(1, ceili(dist / step))
	for i in range(n + 1):
		if _height_local(la.lerp(lb, float(i) / n)) > height + 0.01:
			return true
	return false


# ---------------------------------------------------------------- 音の波のための光線

## 高さ level の波が、origin から dir 方向へ進んだ時に最初に止まる所を返す(地面座標・グローバル)。
## 波は「level + 0.5 より高い地形」に当たると止まる。崖は反射できる。斜面は吸収する。
## 戻り値 { hit: bool, t: float, normal: Vector2, reflect: bool }
func trace_wave(origin: Vector2, dir: Vector2, max_len: float, level: int) -> Dictionary:
	var limit := float(level) + 0.5
	var p := to_local(origin)
	var ts := Vector2(config.tile_size)
	var cell := local_to_cell(p)
	var step := Vector2i(1 if dir.x > 0.0 else -1, 1 if dir.y > 0.0 else -1)
	var t_max := Vector2(INF, INF)
	var t_delta := Vector2(INF, INF)
	if absf(dir.x) > 1e-6:
		var next_x := (cell.x + (1 if dir.x > 0.0 else 0)) * ts.x
		t_max.x = (next_x - p.x) / dir.x
		t_delta.x = ts.x / absf(dir.x)
	if absf(dir.y) > 1e-6:
		var next_y := (cell.y + (1 if dir.y > 0.0 else 0)) * ts.y
		t_max.y = (next_y - p.y) / dir.y
		t_delta.y = ts.y / absf(dir.y)
	var t_enter := 0.0
	var guard := 0
	while t_enter <= max_len and guard < 4096:
		guard += 1
		var t_exit := minf(t_max.x, t_max.y)
		# 今いるマスの中で斜面が上がって波の高さを超えるか
		var s := get_cell_shape(cell)
		if s > Shape.FLAT:
			var h0 := _height_local(p + dir * (t_enter + 0.001))
			var t1 := minf(t_exit, max_len)
			var h1 := _height_local(p + dir * maxf(t1 - 0.001, t_enter))
			if h1 > limit and h0 <= limit:
				var k := (limit - h0) / maxf(h1 - h0, 1e-6)
				return { hit = true, t = lerpf(t_enter, t1, k), normal = -dir, reflect = false }
		if t_exit > max_len:
			break
		# 次のマスへ
		var normal := Vector2.ZERO
		if t_max.x < t_max.y:
			cell.x += step.x
			t_enter = t_max.x
			t_max.x += t_delta.x
			normal = Vector2(-step.x, 0)
		else:
			cell.y += step.y
			t_enter = t_max.y
			t_max.y += t_delta.y
			normal = Vector2(0, -step.y)
		if not _cells.has(cell):
			continue
		var c := corners(cell)
		var edge_h := _entry_edge_height(c, normal)
		if edge_h > limit:
			var hit_local := p + dir * t_enter
			return { hit = true, t = t_enter, normal = normal, reflect = _edge_reflects(to_global(hit_local)) }
	return { hit = false, t = max_len, normal = Vector2.ZERO, reflect = false }


# 入ってきた辺の高さ(その辺の2隅の高い方)
func _entry_edge_height(c: PackedFloat32Array, normal: Vector2) -> float:
	# normal は入ってきた向きの逆。normal.x<0 → 西から東へ入った → 西の辺
	if normal.x < 0.0:
		return maxf(c[0], c[3])
	if normal.x > 0.0:
		return maxf(c[1], c[2])
	if normal.y < 0.0:
		return maxf(c[0], c[1])
	return maxf(c[2], c[3])


func _edge_reflects(global_point: Vector2) -> bool:
	var result := cliffs_reflect
	for z in get_tree().get_nodes_in_group("sound_reflect_zone"):
		if z.has_method("contains_point") and z.contains_point(global_point):
			result = z.reflect
	return result


# ---------------------------------------------------------------- 壁(当たり判定)

func _build_collision() -> void:
	if _body:
		_body.queue_free()
	_body = StaticBody2D.new()
	_body.name = "Walls"
	_body.collision_mask = 0
	add_child(_body, false, Node.INTERNAL_MODE_BACK)
	# レイヤーごとに別の StaticBody2D を作る(1つのボディは1つのレイヤー集合しか持てないため)
	var bodies := {}
	var ts := Vector2(config.tile_size)
	var segs := _collect_wall_edges()
	for key in segs.keys():
		var layer: int = key
		var b := StaticBody2D.new()
		b.collision_layer = Layers.bit(layer)
		b.collision_mask = 0
		_body.add_child(b)
		bodies[layer] = b
		for s in _merge_segments(segs[key]):
			var cs := CollisionShape2D.new()
			var shape := SegmentShape2D.new()
			shape.a = s[0]
			shape.b = s[1]
			cs.shape = shape
			b.add_child(cs)


# 辺ごとの壁を集める。戻り値 layer -> Array[[a, b, is_horizontal]]
func _collect_wall_edges() -> Dictionary:
	var out := {}
	var ts := Vector2(config.tile_size)
	var checked := {}
	for cell in _cells.keys():
		# 右隣と下隣だけを見る(上・左は相手側で見る)+空のマスとの境目は全方向
		for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var other: Vector2i = cell + dir
			if _cells.has(other) and (dir == Vector2i.LEFT or dir == Vector2i.UP):
				continue
			var info := _edge_info(cell, other, dir)
			if info.is_empty():
				continue
			var layer: int = Layers.VOID_LAYER if info.is_void else Layers.wall_layer_for_top(int(ceil(info.top - 0.001)))
			if not out.has(layer):
				out[layer] = []
			out[layer].append(info.seg)
	return out


# cell と other の境目の情報。通れるなら空の辞書
func _edge_info(cell: Vector2i, other: Vector2i, dir: Vector2i) -> Dictionary:
	var ts := Vector2(config.tile_size)
	var a := corners(cell)
	var b := corners(other)
	var o := cell_origin(cell)
	var seg: Array
	var mine: Array
	var theirs: Array
	if dir == Vector2i.RIGHT:
		seg = [o + Vector2(ts.x, 0), o + ts, false]
		mine = [1, 2]
		theirs = [0, 3]
	elif dir == Vector2i.LEFT:
		seg = [o, o + Vector2(0, ts.y), false]
		mine = [0, 3]
		theirs = [1, 2]
	elif dir == Vector2i.DOWN:
		seg = [o + Vector2(0, ts.y), o + ts, true]
		mine = [3, 2]
		theirs = [0, 1]
	else:
		seg = [o, o + Vector2(ts.x, 0), true]
		mine = [0, 1]
		theirs = [3, 2]
	if b.is_empty():
		return { is_void = true, top = maxf(a[mine[0]], a[mine[1]]), seg = seg }
	if is_equal_approx(a[mine[0]], b[theirs[0]]) and is_equal_approx(a[mine[1]], b[theirs[1]]):
		return {}
	var top := maxf(maxf(a[mine[0]], a[mine[1]]), maxf(b[theirs[0]], b[theirs[1]]))
	return { is_void = false, top = top, seg = seg }


# 一直線に並んだ辺をつなげて数を減らす
func _merge_segments(segs: Array) -> Array:
	var horiz := {}
	var vert := {}
	for s in segs:
		if s[2]:
			var key = s[0].y
			if not horiz.has(key):
				horiz[key] = []
			horiz[key].append(Vector2(s[0].x, s[1].x))
		else:
			var key2 = s[0].x
			if not vert.has(key2):
				vert[key2] = []
			vert[key2].append(Vector2(s[0].y, s[1].y))
	var out := []
	for y in horiz.keys():
		for r in _merge_ranges(horiz[y]):
			out.append([Vector2(r.x, y), Vector2(r.y, y)])
	for x in vert.keys():
		for r in _merge_ranges(vert[x]):
			out.append([Vector2(x, r.x), Vector2(x, r.y)])
	return out


func _merge_ranges(ranges: Array) -> Array:
	ranges.sort_custom(func(p, q): return p.x < q.x)
	var out := []
	for r in ranges:
		if not out.is_empty() and absf(out[-1].y - r.x) < 0.01:
			out[-1].y = maxf(out[-1].y, r.y)
		elif not out.is_empty() and r.x < out[-1].y:
			out[-1].y = maxf(out[-1].y, r.y)
		else:
			out.append(Vector2(r.x, r.y))
	return out


## 壁の線分(音の波の計算や確認用)。[{a, b, top, void}]
func get_wall_segments() -> Array:
	var out := []
	for cell in _cells.keys():
		for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var other: Vector2i = cell + dir
			if _cells.has(other) and (dir == Vector2i.LEFT or dir == Vector2i.UP):
				continue
			var info := _edge_info(cell, other, dir)
			if info.is_empty():
				continue
			out.append({ a = to_global(info.seg[0]), b = to_global(info.seg[1]), top = info.top, is_void = info.is_void })
	return out


# ---------------------------------------------------------------- 描画(TerrainRow から呼ばれる)

func draw_row(canvas: CanvasItem, r: int) -> void:
	if style == null or config == null:
		return
	var ts := Vector2(config.tile_size)
	var lp := config.level_px
	# 行ノードは r*th の位置にあるので、地面座標に戻す
	canvas.draw_set_transform(Vector2(0, -canvas.position.y))
	for c in range(_col_range.x, _col_range.y + 1):
		var cell := Vector2i(c, r)
		if not _cells.has(cell):
			continue
		_draw_cell(canvas, cell, ts, lp)
	canvas.draw_set_transform(Vector2.ZERO)


func _proj(p: Vector2, h: float) -> Vector2:
	return Vector2(p.x, p.y - h * config.level_px)


func _draw_cell(canvas: CanvasItem, cell: Vector2i, ts: Vector2, lp: float) -> void:
	var c := corners(cell)
	var o := cell_origin(cell)
	var lv: int = _cells[cell].x
	var shape: int = _cells[cell].y
	var nw := _proj(o, c[0])
	var ne := _proj(o + Vector2(ts.x, 0), c[1])
	var se := _proj(o + ts, c[2])
	var sw := _proj(o + Vector2(0, ts.y), c[3])

	# 床
	var floor_col: Color
	if shape == Shape.FLAT:
		floor_col = style.floor_color(lv)
	else:
		floor_col = style.floor_color(lv).lerp(style.floor_color(lv + 1), 0.5)
	var poly := PackedVector2Array([nw, ne, se, sw])
	var tex := style.texture(lv) if shape == Shape.FLAT else null
	if tex:
		canvas.draw_colored_polygon(poly, Color.WHITE, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
	else:
		canvas.draw_colored_polygon(poly, floor_col)
		if shape == Shape.FLAT:
			_draw_pattern(canvas, style.pattern(lv), nw, ts, floor_col)
		else:
			_draw_slope_lines(canvas, shape, nw, ne, se, sw)

	# 崖の根元の影(隣が高い辺に沿って、自分の床に帯を描く)
	_draw_base_shadows(canvas, cell, c, nw, ne, se, sw)

	# 手前(南)向きの崖の側面
	var south := cell + Vector2i.DOWN
	var b := corners(south)
	var bot_w: float
	var bot_e: float
	var face_col: Color
	if b.is_empty():
		bot_w = -config.void_depth_levels
		bot_e = -config.void_depth_levels
		face_col = style.cliff_color(lv)
	else:
		bot_w = minf(b[0], c[3])
		bot_e = minf(b[1], c[2])
		face_col = style.cliff_color(lv)
	if c[3] > bot_w + 0.001 or c[2] > bot_e + 0.001:
		var p_sw := o + Vector2(0, ts.y)
		var p_se := o + ts
		var face := PackedVector2Array([sw, se, _proj(p_se, bot_e), _proj(p_sw, bot_w)])
		canvas.draw_colored_polygon(face, face_col)
		# 段の境目を示す横線(1段ごと)
		var top_h := maxf(c[2], c[3])
		var low_h := minf(bot_w, bot_e)
		var k := floori(top_h) - 1
		while float(k) > low_h + 0.001:
			var yk := p_sw.y - k * lp
			if float(k) < minf(c[2], c[3]):
				canvas.draw_line(Vector2(p_sw.x, yk), Vector2(p_se.x, yk), face_col.darkened(0.25), 1.0)
			k -= 1
		canvas.draw_line(sw, se, style.outline_color, style.outline_width)

	# 他の辺の輪郭(隣が低い・島の外)
	var oc := style.outline_color
	var ow := style.outline_width
	if _neighbor_lower(cell, Vector2i.UP, c[0], c[1]):
		canvas.draw_line(nw, ne, oc, ow)
	if _neighbor_lower(cell, Vector2i.LEFT, c[0], c[3]):
		canvas.draw_line(nw, sw, oc, ow)
		# 左右の崖の縦の線
		var bl := _side_bottom(cell, Vector2i.LEFT, true)
		canvas.draw_line(sw, _proj(o + Vector2(0, ts.y), bl), oc, ow)
	if _neighbor_lower(cell, Vector2i.RIGHT, c[1], c[2]):
		canvas.draw_line(ne, se, oc, ow)
		var br := _side_bottom(cell, Vector2i.RIGHT, false)
		canvas.draw_line(se, _proj(o + ts, br), oc, ow)

	if show_level_numbers or (not Engine.is_editor_hint() and _debug_levels_on()):
		var font := ThemeDB.fallback_font
		var label := str(lv) if shape == Shape.FLAT else "%d/" % lv
		var center := (nw + se) * 0.5
		canvas.draw_string(font, center + Vector2(-4, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))


func _debug_levels_on() -> bool:
	var w := get_node_or_null("/root/World")
	return w != null and w.debug_levels


func _neighbor_lower(cell: Vector2i, dir: Vector2i, h0: float, h1: float) -> bool:
	var other := cell + dir
	if not _cells.has(other):
		return true
	var b := corners(other)
	var e0: float
	var e1: float
	if dir == Vector2i.UP:
		e0 = b[3]
		e1 = b[2]
	elif dir == Vector2i.LEFT:
		e0 = b[1]
		e1 = b[2]
	elif dir == Vector2i.RIGHT:
		e0 = b[0]
		e1 = b[3]
	else:
		e0 = b[0]
		e1 = b[1]
	return e0 < h0 - 0.001 or e1 < h1 - 0.001


func _side_bottom(cell: Vector2i, dir: Vector2i, west: bool) -> float:
	var south_other := cell + dir
	var b := corners(south_other)
	var south_c := corners(cell + Vector2i.DOWN)
	var h := -config.void_depth_levels
	if not b.is_empty():
		h = b[2] if west else b[3]
	if not south_c.is_empty():
		var hs: float = south_c[0] if west else south_c[1]
		h = maxf(h, minf(hs, cell_max_height(cell)))
	return h


func _draw_base_shadows(canvas: CanvasItem, cell: Vector2i, c: PackedFloat32Array, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2) -> void:
	var col := style.base_shadow_color
	var w := style.base_shadow_width
	# 北(奥)の隣が高い
	var n := corners(cell + Vector2i.UP)
	if not n.is_empty() and (n[3] > c[0] + 0.001 or n[2] > c[1] + 0.001):
		canvas.draw_colored_polygon(PackedVector2Array([nw, ne, ne + Vector2(0, w), nw + Vector2(0, w)]), col)
	var west := corners(cell + Vector2i.LEFT)
	if not west.is_empty() and (west[1] > c[0] + 0.001 or west[2] > c[3] + 0.001):
		canvas.draw_colored_polygon(PackedVector2Array([nw, nw + Vector2(w, 0), sw + Vector2(w, 0), sw]), col)
	var east := corners(cell + Vector2i.RIGHT)
	if not east.is_empty() and (east[0] > c[1] + 0.001 or east[3] > c[2] + 0.001):
		canvas.draw_colored_polygon(PackedVector2Array([ne - Vector2(w, 0), ne, se, se - Vector2(w, 0)]), col)


func _draw_pattern(canvas: CanvasItem, pat: int, nw: Vector2, ts: Vector2, base: Color) -> void:
	var col := base.darkened(style.pattern_strength)
	match pat:
		LevelStyle.Pattern.DOTS:
			canvas.draw_rect(Rect2(nw + Vector2(7, 6), Vector2(2, 2)), col)
			canvas.draw_rect(Rect2(nw + Vector2(22, 15), Vector2(2, 2)), col)
		LevelStyle.Pattern.STRIPES:
			canvas.draw_line(nw + Vector2(4, ts.y - 4), nw + Vector2(14, 4), col, 1.0)
			canvas.draw_line(nw + Vector2(18, ts.y - 4), nw + Vector2(28, 4), col, 1.0)
		LevelStyle.Pattern.CHECKER:
			canvas.draw_rect(Rect2(nw, ts * 0.5), col)
			canvas.draw_rect(Rect2(nw + ts * 0.5, ts * 0.5), col)
		LevelStyle.Pattern.CROSS:
			var cpos := nw + ts * 0.5
			canvas.draw_line(cpos + Vector2(-4, -3), cpos + Vector2(4, 3), col, 1.0)
			canvas.draw_line(cpos + Vector2(-4, 3), cpos + Vector2(4, -3), col, 1.0)
		LevelStyle.Pattern.WAVES:
			var y := nw.y + ts.y * 0.5
			var pts := PackedVector2Array()
			for i in range(5):
				pts.append(Vector2(nw.x + 4 + i * 6, y + (-2 if i % 2 == 0 else 2)))
			canvas.draw_polyline(pts, col, 1.0)


func _draw_slope_lines(canvas: CanvasItem, shape: int, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2) -> void:
	# 等高線(段の途中の高さ)を3本。上り方向に向かって線が並ぶ
	var col := style.slope_line_color
	for i in range(1, 4):
		var f := i / 4.0
		match shape:
			Shape.UP_NORTH, Shape.UP_SOUTH:
				canvas.draw_line(nw.lerp(sw, f), ne.lerp(se, f), col, 1.0)
			_:
				canvas.draw_line(nw.lerp(ne, f), sw.lerp(se, f), col, 1.0)
	# 上り方向の矢印(小さな山形)
	var center := (nw + se) * 0.5
	var up_dir := Vector2.ZERO
	match shape:
		Shape.UP_NORTH: up_dir = Vector2.UP
		Shape.UP_SOUTH: up_dir = Vector2.DOWN
		Shape.UP_EAST: up_dir = Vector2.RIGHT
		Shape.UP_WEST: up_dir = Vector2.LEFT
	var side := up_dir.orthogonal() * 4.0
	var tip := center + up_dir * 3.0
	canvas.draw_polyline(PackedVector2Array([tip - up_dir * 4.0 + side, tip, tip - up_dir * 4.0 - side]), style.outline_color.lerp(Color.WHITE, 0.6), 1.0)
