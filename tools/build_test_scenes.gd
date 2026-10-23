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
	"general": _build_general,
	"lever_animal": _build_lever_animal,
	"frog": _build_frog,
	"pole": _build_pole,
	"bird": _build_bird,
	"offering": _build_offering,
	"extras": _build_extras,
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


# ---------------------------------------------------------------- 謎の部品

func part(root: Node, kind: String, nm: String, c: Vector2) -> Node:
	var n := inst(root, "res://parts/puzzle/%s.tscn" % kind, cell_center(c))
	n.name = nm
	return n


## エディタでつないだのと同じ形で、シグナルをつないで保存する
func wire(src: Node, sig: String, dst: Node, method: String) -> void:
	src.connect(sig, Callable(dst, method), CONNECT_PERSIST)


func flat_world(script: String, help: String, size := Vector2i(22, 14)) -> Node2D:
	var root := new_world(script, help)
	var t := add_terrain(root)
	fill(t, Rect2i(Vector2i.ZERO, size), 0)
	return root


func _build_general() -> void:
	var root := flat_world("res://parts/puzzle/tests/test_general.gd",
		"【汎用】S1とS2を二人で同時に踏むと扉が開く / A〜Dは組み合わせ(正解はAとC) / 看板は誰の画面に見えるかが違う(F3で切替)")
	part(root, "floor_switch", "S1", Vector2(3, 3))
	part(root, "floor_switch", "S2", Vector2(7, 3))
	var g := part(root, "switch_group", "Group", Vector2.ZERO)
	g.switches.assign([NodePath("../S1"), NodePath("../S2")])
	var door := part(root, "door", "Door", Vector2(5, 6))
	door.width = 48.0
	wire(g, "solved", door, "open")
	var names := ["A", "B", "C", "D"]
	for i in range(4):
		var sw := part(root, "floor_switch", names[i], Vector2(12 + i * 2, 3))
		sw.latch = true
	var pg := part(root, "switch_group", "PatternGroup", Vector2.ZERO)
	pg.switches.assign([NodePath("../A"), NodePath("../B"), NodePath("../C"), NodePath("../D")])
	pg.pattern.assign([true, false, true, false])
	var sign := part(root, "symbol_sign", "Sign", Vector2(15, 7))
	sign.symbols = PackedInt32Array([0, 3, 5])
	wire(pg, "solved", sign, "next_symbol")
	var who := [["SignP1", 1, Vector2(10, 10), PackedInt32Array([1, 2])], ["SignP2", 2, Vector2(13, 10), PackedInt32Array([6, 7])], ["SignLinked", 3, Vector2(16, 10), PackedInt32Array([9])]]
	for w in who:
		var sg := part(root, "symbol_sign", w[0], w[2])
		sg.symbols = w[3]
		var ov: Node = load("res://parts/puzzle/only_visible_to.tscn").instantiate()
		ov.name = "OnlyVisibleTo"
		ov.visible_to = w[1]
		sg.add_child(ov)
		ov.owner = root
	add_common(root, Vector2(3, 10), Vector2(5, 10))
	save(root, "res://parts/puzzle/tests/test_general.tscn")


func _build_lever_animal() -> void:
	var root := flat_world("res://parts/puzzle/tests/test_lever_animal.gd",
		"【レバー・声を食べる動物】二人で手をつないでレバーを引く(一人では動かない)→ 動物の向きが変わる / 1キー: 音源Eを鳴らす")
	var lever := part(root, "lever", "Lever", Vector2(4, 4))
	lever.positions = 3
	var e1 := part(root, "voice_eater", "Eater1", Vector2(10, 7))
	e1.direction_map = PackedInt32Array([0, 2, 4])
	wire(lever, "position_changed", e1, "set_direction_index")
	var e2 := part(root, "voice_eater", "Eater2", Vector2(18, 7))
	e2.direction = 4
	e2.spit_shape = 1
	emitter(root, "E", Vector2(10, 3.5), "generic", 0.7)
	for r in [["Rright", Vector2(14, 7)], ["Rdown", Vector2(10, 12)], ["Rleft", Vector2(5, 7)]]:
		var rc := receiver(root, r[0], r[1])
		rc.ignore_source = "E"
	add_common(root, Vector2(2, 11), Vector2(3, 11))
	save(root, "res://parts/puzzle/tests/test_lever_animal.tscn")


func _build_frog() -> void:
	var root := flat_world("res://parts/puzzle/tests/test_frog.gd",
		"【眠るカエル】1キー: 小さな音(寝返り) 2キー: 大きな音(怒る→やり直し)。カエルの下のメーターが騒がしさ")
	var frog := part(root, "sleeping_frog", "Frog", Vector2(10, 5))
	emitter(root, "Small", Vector2(10, 8), "generic", 1.6)
	emitter(root, "Big", Vector2(10, 8), "impact", 3.0)
	var reset := part(root, "puzzle_reset", "Reset", Vector2(4, 10))
	var fl := inst(root, "res://parts/props/fluff.tscn", cell_center(Vector2(13, 9)))
	fl.name = "Fluff"
	for rp in [["RP1", 1, Vector2(4, 10), ""], ["RP2", 2, Vector2(5, 10), ""], ["RP3", 0, Vector2(6, 11), "../../Fluff"]]:
		var n: Node = load("res://parts/puzzle/reset_point.tscn").instantiate()
		n.name = rp[0]
		n.player_index = rp[1]
		n.position = cell_center(rp[2]) - reset.position
		if rp[3] != "":
			n.target = NodePath(rp[3])
		reset.add_child(n)
		n.owner = root
	reset.parts.assign([NodePath("../Frog")])
	frog.reset_on_angry = NodePath("../Reset")
	add_common(root, Vector2(4, 10), Vector2(5, 10))
	save(root, "res://parts/puzzle/tests/test_frog.tscn")


func _build_pole() -> void:
	var root := new_world("res://parts/puzzle/tests/test_pole.gd",
		"【長い棒】両端で手を伸ばして握る(LB/RB)→ 二人で運ぶ・回す。柱や壁に当たると強さに応じた音の波")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 24, 16), 0)
	fill(t, Rect2i(16, 2, 6, 12), 1)
	fill(t, Rect2i(8, 5, 1, 1), 2)      # 二人の間に当たる柱
	part(root, "long_pole", "Pole", Vector2(8, 10))
	add_common(root, Vector2(6, 12), Vector2(10, 12))
	save(root, "res://parts/puzzle/tests/test_pole.tscn")


func _build_bird() -> void:
	var root := flat_world("res://parts/puzzle/tests/test_bird.gd",
		"【歌う鳥】歌うか瓶笛(近くで X / R)を鳴らすと、鳥が近い音で鳴き直す。3羽がド・ミ・ソをそろえると和音の判定役が成功を出す")
	var notes := [["BirdA", Vector2(8, 3), PackedFloat32Array([60])], ["BirdB", Vector2(11, 3), PackedFloat32Array([64])], ["BirdC", Vector2(14, 3), PackedFloat32Array([67])]]
	for b in notes:
		var bird := part(root, "singing_bird", b[0], b[1])
		bird.notes = b[2]
	var chord := part(root, "chord_judge", "Chord", Vector2.ZERO)
	chord.birds.assign([NodePath("../BirdA"), NodePath("../BirdB"), NodePath("../BirdC")])
	for bt in [["BottleC", Vector2(8, 7), 60.0], ["BottleE", Vector2(11, 7), 64.0], ["BottleG", Vector2(14, 7), 67.0]]:
		var bottle := part(root, "instrument", bt[0], bt[1])
		bottle.note = bt[2]
		bottle.size = 1.4
	add_common(root, Vector2(5, 10), Vector2(7, 10))
	save(root, "res://parts/puzzle/tests/test_bird.tscn")


func _build_offering() -> void:
	var root := flat_world("res://parts/puzzle/tests/test_offering.gd",
		"【音のかけら・捧げる場所・島の変化】かけらを3つ拾って光る円に立つと歌の波。届いた物が段階1で変化する", Vector2i(26, 16))
	part(root, "sound_shard", "Shard1", Vector2(3, 3))
	part(root, "sound_shard", "Shard2", Vector2(6, 3))
	var hidden := part(root, "sound_shard", "Hidden", Vector2(9, 3))
	hidden.hidden_at_start = true
	var sw := part(root, "floor_switch", "Switch", Vector2(9, 6))
	wire(sw, "pressed", hidden, "appear")
	var off := part(root, "offering_place", "Offering", Vector2(6, 8))
	off.required = 3
	var acts := [["Appear1", 0, Vector2(14, 4)], ["Disappear1", 1, Vector2(17, 4)], ["Fall1", 2, Vector2(20, 4)], ["Move1", 3, Vector2(23, 4)]]
	for a in acts:
		var r := part(root, "island_change_reactor", a[0], a[2])
		r.action = a[1]
		r.stage = 1
	var r2 := part(root, "island_change_reactor", "Appear2", Vector2(17, 10))
	r2.stage = 2
	r2.compare = 0
	add_common(root, Vector2(3, 11), Vector2(4, 11))
	save(root, "res://parts/puzzle/tests/test_offering.tscn")


func _build_extras() -> void:
	var root := flat_world("res://parts/puzzle/tests/test_extras.gd",
		"【綿毛・重なる点の石・糸電話・ラッパ】1: 綿毛を押す 2: EAとEBを同時に 3: ずらして / 糸電話は両端を握って張る / ラッパはつかむ", Vector2i(26, 16))
	var fl := inst(root, "res://parts/props/fluff.tscn", cell_center(Vector2(5, 3)))
	fl.name = "Fluff"
	emitter(root, "EFluff", Vector2(3, 3), "generic", 1.4)
	part(root, "overlap_stone", "Stone", Vector2(13, 3))
	emitter(root, "EA", Vector2(10, 3), "generic", 0.8)
	emitter(root, "EB", Vector2(16, 3), "generic", 0.8)
	var ph := part(root, "string_phone", "Phone", Vector2(8, 9))
	ph.length = 120.0
	part(root, "trumpet", "Trumpet", Vector2(17, 9))
	add_common(root, Vector2(3, 13), Vector2(5, 13))
	save(root, "res://parts/puzzle/tests/test_extras.tscn")
