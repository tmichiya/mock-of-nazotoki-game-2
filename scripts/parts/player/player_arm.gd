class_name PlayerArm
extends Node2D
## 腕1本(体とは別のパーツ)。回転で向きを表す。本番の絵に差し替える時はこのノードの子に絵を置き、
## length に合わせて伸ばすか、この描画を消して使う。

## 腕の長さ(px)。Player が毎フレーム決める
var length := 8.0
## 0 = 緩んで垂れている、1 = ピンと張っている
var tension := 1.0
var arm_color := Color(0.2, 0.15, 0.12)
var hand_color := Color("fff4d8")
var hand_radius := 2.5


func _draw() -> void:
	var end := Vector2(length, 0)
	var width := lerpf(2.0, 1.2, tension)
	var col := arm_color.lerp(Color(0.85, 0.3, 0.25), clampf((tension - 0.7) / 0.3, 0.0, 1.0) * 0.6)
	if tension < 0.95 and length > 6.0:
		# 緩んでいる時は下向きに垂れた曲線
		var down := Vector2.DOWN.rotated(-global_rotation)
		var sag := down * (1.0 - tension) * length * 0.35
		var pts := PackedVector2Array()
		for i in range(9):
			var t := i / 8.0
			pts.append(end * t + sag * 4.0 * t * (1.0 - t))
		draw_polyline(pts, col, width)
	else:
		draw_line(Vector2.ZERO, end, col, width)
	draw_circle(end, hand_radius, hand_color)
	draw_arc(end, hand_radius, 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
