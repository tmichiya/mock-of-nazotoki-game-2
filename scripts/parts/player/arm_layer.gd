extends Node2D
## 腕を描く層(紙人形方式)。キャラの見た目の下に ArmsBack(体の後ろ)と ArmsFront(体の前)を置く。
## 自分では何も持たず、キャラの draw_arms() を呼ぶだけ。

## 体の前の層か(false なら体の後ろの層)
@export var front := true


func _draw() -> void:
	var p := owner as Player
	if p == null:
		p = get_parent().get_parent() as Player
	if p:
		p.draw_arms(self, front)
