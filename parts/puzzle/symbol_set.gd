@tool
class_name SymbolSet
extends Resource
## 名前のない記号のセット。看板(SymbolSign)はこの中から番号で記号を選んで表示する。
## 記号を足す時は textures に絵(Texture2D)を追加する。番号は 0 から textures の順、続いて仮の記号。

## 自分で描いた記号(後から追加する)
@export var textures: Array[Texture2D] = []
## 仮の記号(線で描く)を使うか
@export var use_builtin := true

## 仮の記号。-1〜1 の範囲の折れ線の集まり
const BUILTIN := [
	[[Vector2(-0.8, 0.6), Vector2(0, -0.8), Vector2(0.8, 0.6), Vector2(-0.8, 0.6)]],
	[[Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(-0.7, -0.7)], [Vector2(0, -0.1), Vector2(0, 0.1)]],
	[[Vector2(-0.8, 0), Vector2(-0.4, -0.6), Vector2(0, 0), Vector2(0.4, 0.6), Vector2(0.8, 0)]],
	[[Vector2(0, -0.8), Vector2(0, 0.8)], [Vector2(-0.6, -0.3), Vector2(0.6, -0.3)], [Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]],
	[[Vector2(-0.7, -0.7), Vector2(0.7, 0.7)], [Vector2(0.7, -0.7), Vector2(-0.7, 0.7)], [Vector2(-0.8, 0), Vector2(0.8, 0)]],
	[[Vector2(-0.6, 0.8), Vector2(-0.6, -0.8), Vector2(0.6, -0.2), Vector2(-0.6, 0.2)]],
	[[Vector2(-0.8, -0.4), Vector2(-0.3, 0.6), Vector2(0.1, -0.4), Vector2(0.5, 0.6), Vector2(0.8, -0.4)]],
	[[Vector2(0, -0.8), Vector2(0.8, 0), Vector2(0, 0.8), Vector2(-0.8, 0), Vector2(0, -0.8)], [Vector2(0, -0.3), Vector2(0, 0.3)]],
	[[Vector2(-0.8, 0.8), Vector2(-0.8, -0.2), Vector2(0, -0.8), Vector2(0.8, -0.2), Vector2(0.8, 0.8)]],
	[[Vector2(-0.7, -0.6), Vector2(0.7, -0.6)], [Vector2(-0.7, 0), Vector2(0.7, 0)], [Vector2(-0.7, 0.6), Vector2(0.2, 0.6)]],
	[[Vector2(0.6, -0.7), Vector2(-0.6, -0.7), Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0.6, 0.7), Vector2(-0.6, 0.7)]],
	[[Vector2(-0.8, 0.7), Vector2(0, -0.7), Vector2(0.8, 0.7)], [Vector2(-0.3, 0.2), Vector2(0.3, 0.2)]],
	[[Vector2(0, -0.8), Vector2(0, 0.2)], [Vector2(-0.6, 0.2), Vector2(0, 0.8), Vector2(0.6, 0.2)]],
	[[Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, 0.7)]],
	[[Vector2(-0.5, -0.8), Vector2(0.5, -0.8)], [Vector2(0, -0.8), Vector2(0, 0.8)], [Vector2(-0.8, 0.8), Vector2(0.8, 0.8)], [Vector2(-0.4, 0), Vector2(0.4, 0)]],
	[[Vector2(-0.8, 0), Vector2(-0.3, -0.5), Vector2(0.3, 0.5), Vector2(0.8, 0)], [Vector2(-0.3, -0.5), Vector2(-0.3, 0.7)]],
]


func count() -> int:
	return textures.size() + (BUILTIN.size() if use_builtin else 0)


## 記号を描く(center を中心に、大きさ size)
func draw_symbol(canvas: CanvasItem, index: int, center: Vector2, size: float, col: Color, width := 1.5) -> void:
	if index < 0 or count() == 0:
		return
	index = index % count()
	if index < textures.size():
		var t := textures[index]
		if t:
			canvas.draw_texture_rect(t, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, col)
		return
	var strokes: Array = BUILTIN[index - textures.size()]
	for stroke in strokes:
		var pts := PackedVector2Array()
		for v in stroke:
			pts.append(center + v * size * 0.5)
		canvas.draw_polyline(pts, col, width)
