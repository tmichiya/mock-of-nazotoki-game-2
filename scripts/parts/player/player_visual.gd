extends Node2D
## プレイヤーの影と、物陰に隠れた時の輪郭(仮の見た目)。体と腕は body_art.gd / arm_layer.gd。
## 原点 = 足元。

@export var mode := 0   ## 1 = 影, 2 = 隠れた時の輪郭


func _draw() -> void:
	var p := owner as Player
	if p == null:
		p = get_parent() as Player
	if p == null:
		return
	var w := p.body_size.x
	var h := p.body_size.y
	match mode:
		1:
			# 影:足元の地形の高さに落とす楕円。宙にいる時は小さく薄く
			var air := clampf(p.height - World.height_at(p.global_position), 0.0, 4.0)
			var s := 1.0 - air * 0.12
			_ellipse(Vector2.ZERO, Vector2(w * 0.6, w * 0.3) * s, Color(0, 0, 0, 0.35 - air * 0.04))
		2:
			var col := p.body_color.lightened(0.3)
			_ellipse_outline(Vector2(0, -h * 0.5), Vector2(w * 0.5, h * 0.5), col, 1.5)
			for hd in [Player.Hand.LEFT, Player.Hand.RIGHT]:
				draw_line(p.shoulder_local(hd), p.hand_local(hd), col, 1.0)
				draw_arc(p.hand_local(hd), p.hand_radius, 0, TAU, 10, col, 1.0)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ellipse_outline(c: Vector2, r: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(21):
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, width)
