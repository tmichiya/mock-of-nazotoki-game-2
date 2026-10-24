@tool
class_name SoundWall
extends Node2D
## 音の波を止める/跳ね返す壁(線)。曲がった壁(楕円の広間など)もこれで作る。
## points を編集するか、「楕円にする」ボタンで楕円の形を作る。
## base_level の段に立つ、高さ height_levels 段の壁。その範囲の段の波だけに効く。

## 壁の線(この部品からの相対位置、地面の座標)
@export var points := PackedVector2Array([Vector2(-32, 0), Vector2(32, 0)]):
	set(v):
		points = v
		_rebuild()
## 最後の点と最初の点をつなぐ
@export var closed := false:
	set(v):
		closed = v
		_rebuild()
## 波を跳ね返すか(false なら吸収して止める)
@export var reflect := true:
	set(v):
		reflect = v
		queue_redraw()
## 壁が立っている段(AUTO_LEVEL なら置いた場所の地形の段)
@export var base_level := -1
## 壁の高さ(段)
@export var height_levels := 1
## プレイヤーや物も通さない(当たり判定を作る)
@export var block_bodies := true:
	set(v):
		block_bodies = v
		_rebuild()
## 見た目の色
@export var wall_color := Color(0.85, 0.85, 0.95)

@export_group("楕円を作る")
@export var ellipse_size := Vector2(160, 96)
@export_range(8, 128) var ellipse_segments := 48
## 楕円の一部だけ作る(度)。0〜360 で閉じた楕円
@export var ellipse_from_deg := 0.0
@export var ellipse_to_deg := 360.0
@export_tool_button("楕円にする") var make_ellipse_button := make_ellipse

var _body: StaticBody2D


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group("sound_wall")


func _ready() -> void:
	_rebuild()


func make_ellipse() -> void:
	var pts := PackedVector2Array()
	var full := absf(ellipse_to_deg - ellipse_from_deg) >= 359.9
	var n := ellipse_segments
	for i in range(n + (0 if full else 1)):
		var a := deg_to_rad(lerpf(ellipse_from_deg, ellipse_to_deg, float(i) / n))
		pts.append(Vector2(cos(a) * ellipse_size.x * 0.5, sin(a) * ellipse_size.y * 0.5))
	closed = full
	points = pts


func get_base_level() -> int:
	return base_level if base_level >= 0 else World.level_at(global_position)


func blocks_level(level: int) -> bool:
	var b := get_base_level()
	return level >= b and level < b + height_levels


func _segments() -> Array:
	var out := []
	var gt := global_transform
	for i in range(points.size() - 1):
		out.append([gt * points[i], gt * points[i + 1]])
	if closed and points.size() > 2:
		out.append([gt * points[points.size() - 1], gt * points[0]])
	return out


## 光線(p から d の向き、長さ max_t まで)との交差
func intersect(p: Vector2, d: Vector2, max_t: float) -> Dictionary:
	var best := { hit = false, t = max_t, normal = Vector2.ZERO, reflect = false }
	var q := p + d * max_t
	for s in _segments():
		var hit = Geometry2D.segment_intersects_segment(p, q, s[0], s[1])
		if hit == null:
			continue
		var t: float = p.distance_to(hit)
		if t < 0.01 or t >= best.t:
			continue
		var n: Vector2 = (s[1] - s[0]).orthogonal().normalized()
		if n.dot(d) > 0.0:
			n = -n
		best = { hit = true, t = t, normal = n, reflect = reflect }
	return best


func _rebuild() -> void:
	queue_redraw()
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	if _body:
		_body.queue_free()
		_body = null
	if not block_bodies:
		return
	_body = StaticBody2D.new()
	_body.collision_layer = Layers.bit(Layers.OBJECT_LAYER)
	_body.collision_mask = 0
	add_child(_body)
	var segs := []
	for i in range(points.size() - 1):
		segs.append([points[i], points[i + 1]])
	if closed and points.size() > 2:
		segs.append([points[points.size() - 1], points[0]])
	for s in segs:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = s[0]
		sh.b = s[1]
		cs.shape = sh
		_body.add_child(cs)


func _draw() -> void:
	if points.size() < 2:
		return
	var lp := World.config.level_px if not Engine.is_editor_hint() else WorldConfig.get_default().level_px
	var b := base_level if base_level >= 0 else 0
	if not Engine.is_editor_hint():
		b = get_base_level()
	var bottom := Vector2(0, -b * lp)
	var top := Vector2(0, -(b + height_levels) * lp)
	var pts := points.duplicate()
	if closed:
		pts.append(points[0])
	var col := wall_color if reflect else wall_color.darkened(0.4)
	for i in range(pts.size() - 1):
		var poly := PackedVector2Array([pts[i] + top, pts[i + 1] + top, pts[i + 1] + bottom, pts[i] + bottom])
		draw_colored_polygon(poly, Color(col, 0.55))
		draw_line(pts[i] + top, pts[i + 1] + top, col.lightened(0.3), 1.5)
	if Engine.is_editor_hint():
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(1, 1, 1, 0.4), 1.0)
