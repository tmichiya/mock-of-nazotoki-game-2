extends Node
## 確認用シーンを組み立てて保存するスクリプト(地形を塗った状態のシーンをコードで作る)。
## 実行: godot --headless --path . res://tools/build_test_scenes.tscn [-- 名前 …]
## 名前を省くと全部作り直す。作ったシーンはエディタで自由に直してよい(作り直すと上書きされる)。

const S := { FLAT = 0, N = 1, S = 2, E = 3, W = 4 }

var builders := {
	"terrain": _build_terrain,
}


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	for key in builders.keys():
		if only.is_empty() or key in only:
			builders[key].call()
	get_tree().quit()


# ---------------------------------------------------------------- 共通

func new_world(script_path: String, help: String) -> Node2D:
	var root := Node2D.new()
	root.name = "Test"
	root.y_sort_enabled = true
	if script_path != "":
		root.set_script(load(script_path))
		root.help_text = help
	return root


func add(root: Node, node: Node, parent: Node = null) -> Node:
	(parent if parent else root).add_child(node)
	_own(node, root)
	return node


func _own(node: Node, root: Node) -> void:
	node.owner = root
	if node.scene_file_path != "":
		return
	for c in node.get_children():
		_own(c, root)


func inst(root: Node, path: String, pos: Vector2 = Vector2.ZERO, parent: Node = null) -> Node:
	var n: Node = load(path).instantiate()
	if n is Node2D:
		n.position = pos
	(parent if parent else root).add_child(n)
	n.owner = root
	return n


func add_terrain(root: Node) -> Terrain:
	var t := Terrain.new()
	t.name = "Terrain"
	t.tile_set = load("res://parts/terrain/terrain_tileset.tres")
	add(root, t)
	return t


func fill(t: Terrain, rect: Rect2i, level: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			t.set_cell(Vector2i(x, y), 0, Vector2i(S.FLAT, level))


func slope(t: Terrain, cell: Vector2i, low_level: int, shape: int) -> void:
	t.set_cell(cell, 0, Vector2i(shape, low_level))


func cell_center(c: Vector2) -> Vector2:
	return (c + Vector2(0.5, 0.5)) * Vector2(32, 24)


func add_common(root: Node, p1_cell: Vector2, p2_cell: Vector2) -> void:
	inst(root, "res://parts/player/player_spawner.tscn", cell_center(p1_cell))
	var s1 := inst(root, "res://parts/player/spawn_point.tscn", cell_center(p1_cell))
	s1.name = "SpawnPoint1"
	s1.index = 1
	var s2 := inst(root, "res://parts/player/spawn_point.tscn", cell_center(p2_cell))
	s2.name = "SpawnPoint2"
	s2.index = 2
	inst(root, "res://parts/camera/follow_camera.tscn", cell_center(p1_cell))
	var ap := Node.new()
	ap.name = "Autopilot"
	ap.set_script(load("res://tests/autopilot.gd"))
	add(root, ap)


func save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("saved ", path, " err=", err)
	root.free()


# ---------------------------------------------------------------- A・B 地形とプレイヤー

func _build_terrain() -> void:
	var root := new_world("res://parts/terrain/test_terrain.gd",
		"【地形・プレイヤー】斜面で上り下り / 段差は上からも下からも壁 / 高い段の後ろで輪郭 / 崖の縁で滑空し、影の位置に着地")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 16, 13), 0)
	fill(t, Rect2i(3, 2, 10, 7), 1)      # 1段: x3〜12, y2〜8
	fill(t, Rect2i(6, 3, 5, 3), 2)       # 2段: x6〜10, y3〜5
	slope(t, Vector2i(7, 9), 0, S.N)     # 0→1段(奥へ上る)
	slope(t, Vector2i(11, 4), 1, S.W)    # 1→2段(左へ上る)
	slope(t, Vector2i(2, 5), 0, S.E)     # おまけ:0→1段(右へ上る)
	add_common(root, Vector2(4, 10), Vector2(8, 1))
	save(root, "res://parts/terrain/test_terrain.tscn")
