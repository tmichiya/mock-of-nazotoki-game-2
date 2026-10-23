extends Node
## 確認用シーンを組み立てて保存するスクリプト(地形を塗った状態のシーンをコードで作る)。
## 実行: godot --headless --path . res://tools/build_test_scenes.tscn [-- 名前 …]
## 名前を省くと全部作り直す。作ったシーンはエディタで自由に直してよい(作り直すと上書きされる)。

const S := { FLAT = 0, N = 1, S = 2, E = 3, W = 4 }

var builders := {
	"terrain": _build_terrain,
	"hands": _build_hands,
	"sound_wave": _build_sound_wave,
	"voice": _build_voice,
	"net": _build_net,
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


# ---------------------------------------------------------------- C・D 腕と手つなぎ

func _build_hands() -> void:
	var root := new_world("res://parts/hands/test_hands.gd",
		"【腕・手つなぎ】ポーズ / 片手で回転して離すと飛ぶ / 両手を離すと反動 / 1段の崖はつないだまま降りられる / 2段の崖は宙づり→揺らす→上の人が離れると引き上げ")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 20, 14), 0)
	fill(t, Rect2i(12, 0, 8, 8), 1)          # 1段:右上
	fill(t, Rect2i(15, 8, 5, 6), 2)          # 2段:右下
	slope(t, Vector2i(11, 2), 0, S.E)        # 0→1段
	slope(t, Vector2i(16, 7), 1, S.S)        # 1→2段(手前へ上る)
	add_common(root, Vector2(5, 5), Vector2(5, 5))
	root.get_node("SpawnPoint2").position += Vector2(24, 0)
	inst(root, "res://parts/hands/hand_link_monitor.tscn")
	save(root, "res://parts/hands/test_hands.tscn")


# ---------------------------------------------------------------- E 音の波

func emitter(root: Node, nm: String, cell: Vector2, shape: String, size: float) -> Node:
	var e := inst(root, "res://parts/sound_wave/sound_emitter.tscn", cell_center(cell))
	e.name = nm
	e.source_name = nm
	e.shape = load("res://parts/sound_wave/shapes/%s.tres" % shape)
	e.size = size
	return e


func receiver(root: Node, nm: String, cell: Vector2) -> Node:
	var r := inst(root, "res://parts/sound_wave/wave_receiver.tscn", cell_center(cell))
	r.name = nm
	r.radius = 10.0
	return r


func _build_sound_wave() -> void:
	var root := new_world("res://parts/sound_wave/test_sound_wave.gd",
		"【音の波】1:E0(0段) 2:E1(1段) 3:EA+EB同時 4:ずらす 5:楕円の焦点 6:綿毛を押す  ※受け取りと重なりは画面とログに出る")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 24, 19), 0)
	fill(t, Rect2i(8, 4, 6, 6), 1)       # 台地1(1段)
	fill(t, Rect2i(10, 6, 2, 2), 2)      # 2段の塊
	fill(t, Rect2i(16, 4, 4, 6), 1)      # 台地2(1段)
	slope(t, Vector2i(7, 8), 0, S.E)
	emitter(root, "E0", Vector2(4, 6.5), "impact", 2.6)
	emitter(root, "E1", Vector2(9, 5), "voice", 2.0)
	emitter(root, "EA", Vector2(1, 1.5), "generic", 1.0)
	emitter(root, "EB", Vector2(7, 1.5), "generic", 1.0)
	receiver(root, "Rwest", Vector2(1.5, 6.5))
	receiver(root, "Rgap", Vector2(14.5, 6.5))
	receiver(root, "Rsouth", Vector2(9, 8.5))
	receiver(root, "Rbehind", Vector2(12.5, 8.5))
	receiver(root, "Reast", Vector2(17, 5))
	receiver(root, "Roverlap", Vector2(4, 1.5))
	# 楕円の広間(0段)
	var wall := inst(root, "res://parts/sound_wave/sound_wall.tscn", cell_center(Vector2(16, 14.5)))
	wall.name = "EllipseWall"
	wall.ellipse_size = Vector2(240, 96)
	wall.ellipse_segments = 64
	wall.make_ellipse()
	wall.block_bodies = false
	var c := sqrt(120.0 * 120.0 - 48.0 * 48.0)
	var ef := emitter(root, "EFocus", Vector2.ZERO, "voice", 1.4)
	ef.position = cell_center(Vector2(16, 14.5)) - Vector2(c, 0)
	var rf := receiver(root, "Rfocus", Vector2.ZERO)
	rf.position = cell_center(Vector2(16, 14.5)) + Vector2(c, 0)
	# 綿毛
	var fl := inst(root, "res://parts/props/fluff.tscn", cell_center(Vector2(4, 13)))
	fl.name = "Fluff"
	emitter(root, "EFluff", Vector2(2, 13), "generic", 1.6)
	add_common(root, Vector2(3, 10), Vector2(5, 10))
	save(root, "res://parts/sound_wave/test_sound_wave.tscn")


# ---------------------------------------------------------------- F マイクと声の波

func _build_voice() -> void:
	var root := new_world("res://parts/voice/test_voice.gd",
		"【マイク・声の波】話すとオレンジの位置から声の波。大きな声ほど大きな波。右上に音量と声の高さ(Hz・音名)")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 20, 14), 0)
	fill(t, Rect2i(13, 2, 5, 9), 1)
	inst(root, "res://parts/voice/voice_monitor.tscn")
	add_common(root, Vector2(6, 7), Vector2(10, 7))
	save(root, "res://parts/voice/test_voice.tscn")


# ---------------------------------------------------------------- G 通信とVC

func _build_net() -> void:
	var root := new_world("res://tests/test_net.gd",
		"【通信・VC】2つ起動して片方ホスト・片方参加。遠いと声が遅れて届く/近いとすぐ/段が違うと届かない/段をまたいで手をつなぐと届く")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 24, 14), 0)
	fill(t, Rect2i(14, 2, 8, 10), 1)
	slope(t, Vector2i(13, 4), 0, S.E)
	var vm := inst(root, "res://parts/voice/voice_monitor.tscn")
	add_common(root, Vector2(3, 7), Vector2(10, 7))
	inst(root, "res://parts/hands/hand_link_monitor.tscn")
	save(root, "res://tests/test_net.tscn")
