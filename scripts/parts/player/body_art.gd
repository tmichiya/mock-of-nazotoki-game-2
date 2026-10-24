extends Node2D
## 体の絵(紙人形方式)。向き(下・上・左・右)ごとに1枚ずつ絵を設定する。
## 絵が無い向きは、仮の図形(体の色の楕円と目)を描く。原点 = 足元。絵は足元が原点に来るように置く。

## 下(カメラ側)を向いた時の絵
@export var texture_down: Texture2D
## 上(背中)を向いた時の絵
@export var texture_up: Texture2D
## 左を向いた時の絵
@export var texture_left: Texture2D
## 右を向いた時の絵(空なら左の絵を反転して使う)
@export var texture_right: Texture2D
## 絵の足元の位置(絵の左上からのピクセル。空なら絵の下端の真ん中)
@export var texture_feet := Vector2(-1, -1)


func _draw() -> void:
	var p := owner as Player
	if p == null:
		p = get_parent().get_parent() as Player
	if p == null:
		return
	var dir := p.body_dir()
	var tex: Texture2D = null
	var flip := false
	match dir:
		Player.BodyDir.DOWN: tex = texture_down
		Player.BodyDir.UP: tex = texture_up
		Player.BodyDir.LEFT: tex = texture_left
		Player.BodyDir.RIGHT:
			tex = texture_right
			if tex == null and texture_left:
				tex = texture_left
				flip = true
	if tex:
		var size := tex.get_size()
		var feet := texture_feet if texture_feet.x >= 0.0 else Vector2(size.x * 0.5, size.y)
		if flip:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture(tex, -feet)
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_placeholder(p, dir)
	_draw_flash(p)


func _draw_placeholder(p: Player, dir: int) -> void:
	var w := p.body_size.x
	var h := p.body_size.y
	var c := Vector2(0, -h * 0.5)
	_ellipse(c, Vector2(w * 0.5, h * 0.5), p.body_color)
	_ellipse_outline(c, Vector2(w * 0.5, h * 0.5), Color(0.1, 0.08, 0.08), 1.0)
	# 目(背中を向いている時は描かない)
	var eye_y := -h * 0.68
	match dir:
		Player.BodyDir.DOWN:
			draw_rect(Rect2(Vector2(-3, eye_y), Vector2(1.5, 2)), Color.BLACK)
			draw_rect(Rect2(Vector2(1.5, eye_y), Vector2(1.5, 2)), Color.BLACK)
		Player.BodyDir.LEFT:
			draw_rect(Rect2(Vector2(-4, eye_y), Vector2(1.5, 2)), Color.BLACK)
		Player.BodyDir.RIGHT:
			draw_rect(Rect2(Vector2(2.5, eye_y), Vector2(1.5, 2)), Color.BLACK)
	if p.state == Player.State.POSE:
		draw_line(Vector2(-2, -h - 3), Vector2(2, -h - 3), Color.WHITE, 1.0)


func _draw_flash(p: Player) -> void:
	var f := p.get_flash()
	if f <= 0.0:
		return
	var r := p.body_size * 0.5 + Vector2.ONE * (1.0 - f) * 6.0
	_ellipse_outline(Vector2(0, -p.body_size.y * 0.5), r, Color(1, 1, 1, f), 1.5)


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
