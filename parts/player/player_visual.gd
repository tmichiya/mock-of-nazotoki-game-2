extends Node2D
## プレイヤーの仮の見た目(体・目・波が届いた時の光)。本番の絵に差し替えてよい。
## 原点 = 足元。上に向かって描く。

@export var mode := 0   ## 0 = 体, 1 = 影, 2 = 隠れた時の輪郭


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
			_ellipse_outline(Vector2(0, -h * 0.5), Vector2(w * 0.5, h * 0.5), p.body_color.lightened(0.3), 1.5)
			for side in [0, 1]:
				var a: Vector2 = p.shoulder_screen_pos(side) - global_position
				var b: Vector2 = p.hand_screen_pos(side) - global_position
				draw_line(a, b, p.body_color.lightened(0.3), 1.0)
		_:
			var body_center := Vector2(0, -h * 0.5)
			_ellipse(body_center, Vector2(w * 0.5, h * 0.5), p.body_color)
			_ellipse_outline(body_center, Vector2(w * 0.5, h * 0.5), Color(0.1, 0.08, 0.08), 1.0)
			# 目(向いている方を見る。奥を向いている時は描かない)
			if p.facing.y > -0.5:
				var eye_c := Vector2(p.facing.x * 2.5, -h * 0.68)
				draw_rect(Rect2(eye_c + Vector2(-3, 0), Vector2(1.5, 2)), Color.BLACK)
				draw_rect(Rect2(eye_c + Vector2(1.5, 0), Vector2(1.5, 2)), Color.BLACK)
			# ポーズ中の印(頭の上の小さな線)
			if p.state == Player.State.POSE:
				draw_line(Vector2(-2, -h - 3), Vector2(2, -h - 3), Color.WHITE, 1.0)
			var f := p.get_flash()
			if f > 0.0:
				_ellipse_outline(body_center, Vector2(w * 0.5, h * 0.5) + Vector2.ONE * (1.0 - f) * 6.0, Color(1, 1, 1, f), 1.5)


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
