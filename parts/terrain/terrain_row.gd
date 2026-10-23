@tool
class_name TerrainRow
extends Node2D
## 地形の1行分を描く内部ノード(Terrain が自動で作る。手で置かない)。
## 行ごとに分けて Y-sort に参加させることで、高い段の床や崖が手前のキャラを正しく隠す。

enum Kind { GROUND, WAVES }

var terrain: Terrain
var row := 0
var kind := Kind.GROUND


func _draw() -> void:
	if terrain == null:
		return
	if kind == Kind.GROUND:
		terrain.draw_row(self, row)
	else:
		var waves := get_node_or_null("/root/Waves")
		if waves:
			waves.draw_row(self, row, terrain)
