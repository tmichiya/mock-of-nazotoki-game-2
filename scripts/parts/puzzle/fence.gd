@tool
class_name Fence
extends PuzzlePart
## 柵。プレイヤーや綿毛などの物は通さないが、音の波(声も)はすき間から通り抜ける。
## 置いた位置が柵の真ん中。向きはノードの回転(エディタの回転ツール)でも angle_deg でも変えられる。
## 杭は回しても常に画面の上へ立ち、杭ごとに前後の並べ替えをするので、斜めや縦に置いても見た目が崩れない。

## 柵の長さ(px)
@export var length := 64.0:
	set(v):
		length = maxf(v, 4.0)
		_rebuild()
## 柵の向き(度。0=左右、90=上下)。ノードの回転と足し合わせる
@export var angle_deg := 0.0:
	set(v):
		angle_deg = v
		_rebuild()
## 杭の間隔(px。長さを等分するので、だいたいこの間隔になる)
@export var post_spacing := 16.0:
	set(v):
		post_spacing = maxf(v, 4.0)
		_rebuild()
## 柵の高さ(段。見た目だけ)
@export var fence_levels := 1.0:
	set(v):
		fence_levels = v
		_redraw_panels()
## 当たり判定の厚み(px)
@export var thickness := 4.0:
	set(v):
		thickness = v
		_rebuild()
## 綿毛・棒などの物も止める(false ならプレイヤーだけを止め、物はすり抜ける)
@export var blocks_props := true
@export var post_color := Color("8a6a4a"):
	set(v):
		post_color = v
		_redraw_panels()
@export var rail_color := Color("b08c5e"):
	set(v):
		rail_color = v
		_redraw_panels()

var _body: StaticBody2D
var _shape: CollisionShape2D
var _panels: Array[FencePanel] = []


func _ready() -> void:
	super._ready()
	y_sort_enabled = true   # 杭ごとの見た目を、まわりの物と一緒に前後で並べ替える
	_rebuild()
	if Engine.is_editor_hint():
		return
	if not blocks_props:
		_let_props_through.call_deferred()
		get_tree().node_added.connect(_on_node_added)


## 柵の両端(このノードから見た位置)
func ends() -> Array:
	var d := Vector2.from_angle(deg_to_rad(angle_deg)) * length * 0.5
	return [-d, d]


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_build_panels()
	if Engine.is_editor_hint():
		return
	if _body == null:
		_body = StaticBody2D.new()
		_body.collision_layer = Layers.bit(Layers.OBJECT_LAYER)
		_body.collision_mask = 0
		add_child(_body, false, INTERNAL_MODE_BACK)
		_shape = CollisionShape2D.new()
		_body.add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	_shape.shape = rect
	_shape.rotation = deg_to_rad(angle_deg)


## 杭と杭の間ごとに、見た目の部品(FencePanel)を作り直す。シーンには保存しない
func _build_panels() -> void:
	for p in _panels:
		p.queue_free()
	_panels.clear()
	var e := ends()
	var n := maxi(1, roundi(length / post_spacing))
	for i in range(n + 1):
		var p := FencePanel.new()
		p.fence = self
		var a: Vector2 = e[0].lerp(e[1], float(i) / n)
		if i < n:
			var b: Vector2 = e[0].lerp(e[1], float(i + 1) / n)
			p.position = (a + b) * 0.5   # 並べ替えは杭の間の真ん中で行う
			p.post_local = a
			p.next_local = b
			p.has_rail = true
		else:
			p.position = a
			p.post_local = a
		add_child(p, false, INTERNAL_MODE_FRONT)
		_panels.append(p)


func _redraw_panels() -> void:
	for p in _panels:
		p.queue_redraw()


func _notification(what: int) -> void:
	# エディタで回した・動かした時も、杭が上に立つように描き直す
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_redraw_panels()


func _enter_tree() -> void:
	super._enter_tree()
	set_notify_transform(true)


func _let_props_through() -> void:
	for o in get_tree().get_nodes_in_group("props"):
		_except(o)


func _on_node_added(n: Node) -> void:
	_except.call_deferred(n)


func _except(n: Node) -> void:
	if _body and is_instance_valid(n) and n is PhysicsBody2D and n.is_in_group("props"):
		n.add_collision_exception_with(_body)


## 柵の見た目の一区切り(杭1本と、次の杭までの横木)。Fence が作る
class FencePanel:
	extends Node2D

	var fence: Fence
	var post_local := Vector2.ZERO   # 柵から見た位置
	var next_local := Vector2.ZERO
	var has_rail := false

	func _draw() -> void:
		if fence == null:
			return
		# 回転・拡大を打ち消して「画面の向き」で描く(杭がいつも上に立つ)
		var g := global_transform
		draw_set_transform_matrix(g.affine_inverse() * Transform2D(0.0, g.origin))
		var fg := fence.global_transform
		var me := g.origin
		var a := fg * post_local - me
		var b := fg * next_local - me
		var up := fence.lift()
		var h := fence.fence_levels * WorldConfig.get_default().level_px
		var dark := fence.post_color.darkened(0.35)
		# 地面に落ちる影(右下へ。どの向きでも柵の幅が分かる)
		var sh := Vector2(h * 0.45, 2.0)
		if has_rail:
			draw_colored_polygon(PackedVector2Array([a + up, b + up, b + up + sh, a + up + sh]), Color(0, 0, 0, 0.16))
			# 横木2本(すき間があるので音が通る見た目)
			for k in [0.4, 0.8]:
				var o := Vector2(0, -h * k)
				draw_line(a + up + o + Vector2(1, 1), b + up + o + Vector2(1, 1), dark, 3.0)
				draw_line(a + up + o, b + up + o, fence.rail_color, 2.0)
		else:
			draw_line(a + up, a + up + sh, Color(0, 0, 0, 0.16), 3.0)
		# 杭(どの向きでも同じ形)
		var top := a + up + Vector2(0, -h - 2)
		var r := Rect2(top - Vector2(2, 0), Vector2(4, h + 2))
		draw_rect(r, fence.post_color)
		draw_rect(Rect2(r.position + Vector2(2.5, 0), Vector2(1.5, r.size.y)), dark)
		draw_circle(top, 2.0, fence.post_color.lightened(0.2))
