extends Node
## 確認用シーンを組み立てて保存するスクリプト(地形を塗った状態のシーンをコードで作る)。
## 実行: godot --headless --path . res://tools/build_test_scenes.tscn [-- 名前 …]
## 名前を省くと全部作り直す。作ったシーンはエディタで自由に直してよい(作り直すと上書きされる)。

const S := { FLAT = 0, N = 1, S = 2, E = 3, W = 4 }

var builders := {
	"terrain": _build_terrain,
	"hands": _build_hands,
	"arms": _build_arms,
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
	"catalog": _build_catalog,
	"clear": _build_clear,
	"gimmicks": _build_gimmicks,
	"fence": _build_fence,
	"symbol_code": _build_symbol_code,
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
	t.tile_set = load("res://resources/terrain/terrain_tileset.tres")
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
	inst(root, "res://scenes/parts/player/player_spawner.tscn", cell_center(p1_cell))
	var s1 := inst(root, "res://scenes/parts/player/spawn_point.tscn", cell_center(p1_cell))
	s1.name = "SpawnPoint1"
	s1.index = 1
	var s2 := inst(root, "res://scenes/parts/player/spawn_point.tscn", cell_center(p2_cell))
	s2.name = "SpawnPoint2"
	s2.index = 2
	inst(root, "res://scenes/parts/camera/follow_camera.tscn", cell_center(p1_cell))
	var ap := Node.new()
	ap.name = "Autopilot"
	ap.set_script(load("res://scripts/tests/autopilot.gd"))
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
	var root := new_world("res://scripts/tests/test_terrain.gd",
		"【地形・プレイヤー】斜面で上り下り / 段差は上からも下からも壁 / 高い段の後ろで輪郭 / 崖の縁で滑空し、影の位置に着地")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 16, 13), 0)
	fill(t, Rect2i(3, 2, 10, 7), 1)      # 1段: x3〜12, y2〜8
	fill(t, Rect2i(6, 3, 5, 3), 2)       # 2段: x6〜10, y3〜5
	slope(t, Vector2i(7, 9), 0, S.N)     # 0→1段(奥へ上る)
	slope(t, Vector2i(11, 4), 1, S.W)    # 1→2段(左へ上る)
	slope(t, Vector2i(2, 5), 0, S.E)     # おまけ:0→1段(右へ上る)
	add_common(root, Vector2(4, 10), Vector2(8, 1))
	save(root, "res://scenes/tests/test_terrain.tscn")


# ---------------------------------------------------------------- C・D 腕と手つなぎ

func _build_hands() -> void:
	var root := new_world("res://scripts/tests/test_hands.gd",
		"【腕・手つなぎ】ポーズ / 片手で回転して離すと飛ぶ / 両手を離すと反動 / 1段の崖はつないだまま降りられる / 2段の崖は宙づり→揺らす→上の人が離れると引き上げ")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 20, 14), 0)
	fill(t, Rect2i(12, 0, 8, 8), 1)          # 1段:右上
	fill(t, Rect2i(15, 8, 5, 6), 2)          # 2段:右下
	slope(t, Vector2i(11, 2), 0, S.E)        # 0→1段
	slope(t, Vector2i(16, 7), 1, S.S)        # 1→2段(手前へ上る)
	add_common(root, Vector2(5, 5), Vector2(5, 5))
	root.get_node("SpawnPoint2").position += Vector2(24, 0)
	inst(root, "res://scenes/parts/hands/hand_link_monitor.tscn")
	save(root, "res://scenes/tests/test_hands.tscn")


# ---------------------------------------------------------------- C 腕のポーズの読み分け

func _build_arms() -> void:
	var root := new_world("res://scripts/tests/test_arms.gd",
		"【腕のポーズ】左から 横・真上・斜め上・手前・奥・下ろす。下の2人で自分でも試せる(挙げる: Z/C・L3/R3)")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 18, 10), 0)
	add_common(root, Vector2(7, 7), Vector2(9, 7))
	save(root, "res://scenes/tests/test_arms.tscn")


# ---------------------------------------------------------------- E 音の波

func emitter(root: Node, nm: String, cell: Vector2, shape: String, size: float) -> Node:
	var e := inst(root, "res://scenes/parts/sound_wave/sound_emitter.tscn", cell_center(cell))
	e.name = nm
	e.source_name = nm
	e.shape = load("res://resources/wave_shapes/%s.tres" % shape)
	e.size = size
	return e


func receiver(root: Node, nm: String, cell: Vector2) -> Node:
	var r := inst(root, "res://scenes/parts/sound_wave/wave_receiver.tscn", cell_center(cell))
	r.name = nm
	r.radius = 10.0
	return r


func _build_sound_wave() -> void:
	var root := new_world("res://scripts/tests/test_sound_wave.gd",
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
	var wall := inst(root, "res://scenes/parts/sound_wave/sound_wall.tscn", cell_center(Vector2(16, 14.5)))
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
	var fl := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(Vector2(4, 13)))
	fl.name = "Fluff"
	emitter(root, "EFluff", Vector2(2, 13), "generic", 1.6)
	add_common(root, Vector2(3, 10), Vector2(5, 10))
	save(root, "res://scenes/tests/test_sound_wave.tscn")


# ---------------------------------------------------------------- F マイクと声の波

func _build_voice() -> void:
	var root := new_world("res://scripts/tests/test_voice.gd",
		"【マイク・声の波】話すとオレンジの位置から声の波。大きな声ほど大きな波。右上に音量と声の高さ(Hz・音名)")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 20, 14), 0)
	fill(t, Rect2i(13, 2, 5, 9), 1)
	inst(root, "res://scenes/parts/voice/voice_monitor.tscn")
	add_common(root, Vector2(6, 7), Vector2(10, 7))
	save(root, "res://scenes/tests/test_voice.tscn")


# ---------------------------------------------------------------- G 通信とVC

func _build_net() -> void:
	var root := new_world("res://scripts/tests/test_net.gd",
		"【通信・VC】2つ起動して片方ホスト・片方参加。遠いと声が遅れて届く/近いとすぐ/段が違うと届かない/段をまたいで手をつなぐと届く")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 24, 14), 0)
	fill(t, Rect2i(14, 2, 8, 10), 1)
	slope(t, Vector2i(13, 4), 0, S.E)
	var vm := inst(root, "res://scenes/parts/voice/voice_monitor.tscn")
	add_common(root, Vector2(3, 7), Vector2(10, 7))
	inst(root, "res://scenes/parts/hands/hand_link_monitor.tscn")
	save(root, "res://scenes/tests/test_net.tscn")


# ---------------------------------------------------------------- 謎の部品

func part(root: Node, kind: String, nm: String, c: Vector2) -> Node:
	var n := inst(root, "res://scenes/parts/puzzle/%s.tscn" % kind, cell_center(c))
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
	var root := flat_world("res://scripts/tests/test_general.gd",
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
		var ov: Node = load("res://scenes/parts/puzzle/only_visible_to.tscn").instantiate()
		ov.name = "OnlyVisibleTo"
		ov.visible_to = w[1]
		sg.add_child(ov)
		ov.owner = root
	add_common(root, Vector2(3, 10), Vector2(5, 10))
	save(root, "res://scenes/tests/test_general.tscn")


func _build_lever_animal() -> void:
	var root := flat_world("res://scripts/tests/test_lever_animal.gd",
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
	save(root, "res://scenes/tests/test_lever_animal.tscn")


func _build_frog() -> void:
	var root := flat_world("res://scripts/tests/test_frog.gd",
		"【眠るカエル】1キー: 小さな音(寝返り) 2キー: 大きな音(怒る→やり直し)。カエルの下のメーターが騒がしさ")
	var frog := part(root, "sleeping_frog", "Frog", Vector2(10, 5))
	emitter(root, "Small", Vector2(10, 8), "generic", 1.6)
	emitter(root, "Big", Vector2(10, 8), "impact", 3.0)
	var reset := part(root, "puzzle_reset", "Reset", Vector2(4, 10))
	var fl := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(Vector2(13, 9)))
	fl.name = "Fluff"
	for rp in [["RP1", 1, Vector2(4, 10), ""], ["RP2", 2, Vector2(5, 10), ""], ["RP3", 0, Vector2(6, 11), "../../Fluff"]]:
		var n: Node = load("res://scenes/parts/puzzle/reset_point.tscn").instantiate()
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
	save(root, "res://scenes/tests/test_frog.tscn")


func _build_pole() -> void:
	var root := new_world("res://scripts/tests/test_pole.gd",
		"【長い棒】両端で手を伸ばして握る(LB/RB)→ 二人で運ぶ・回す。柱や壁に当たると強さに応じた音の波")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 24, 16), 0)
	fill(t, Rect2i(16, 2, 6, 12), 1)
	fill(t, Rect2i(8, 5, 1, 1), 2)      # 二人の間に当たる柱
	part(root, "long_pole", "Pole", Vector2(8, 10))
	add_common(root, Vector2(6, 12), Vector2(10, 12))
	save(root, "res://scenes/tests/test_pole.tscn")


func _build_bird() -> void:
	var root := flat_world("res://scripts/tests/test_bird.gd",
		"【歌う鳥】鳥の近くで歌うか、瓶笛(近くで X / R)を鳴らすと、鳥が近い音で鳴き直す。3羽がド・ミ・ソをそろえると和音の判定役が成功を出す
右上のメーターで、マイク(F4で切替)・音量・声の高さを確かめる。声が届いたのに高さが取れない時は Bird.heard(-1) が出る")
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
	# 鳥の手本の鳴き声を食べて、下の受け手へ吐き出す動物
	var eater := part(root, "voice_eater", "Eater", Vector2(17, 3))
	eater.direction = 2
	eater.eat_kinds.assign([&"bird"])
	var rb := receiver(root, "RBird", Vector2(17, 10))
	rb.accept_kinds.assign([&"bird"])
	inst(root, "res://scenes/parts/voice/voice_monitor.tscn")
	add_common(root, Vector2(11, 5), Vector2(12, 5))
	save(root, "res://scenes/tests/test_bird.tscn")


func _build_offering() -> void:
	var root := flat_world("res://scripts/tests/test_offering.gd",
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
	save(root, "res://scenes/tests/test_offering.tscn")


func _build_extras() -> void:
	var root := flat_world("res://scripts/tests/test_extras.gd",
		"【綿毛・重なる点の石・糸電話・ラッパ】1: 綿毛を押す 2: EAとEBを同時に 3: ずらして / 糸電話は両端を握って張る / ラッパはつかむ", Vector2i(26, 16))
	var fl := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(Vector2(5, 3)))
	fl.name = "Fluff"
	emitter(root, "EFluff", Vector2(3, 3), "generic", 1.4)
	part(root, "overlap_stone", "Stone", Vector2(13, 3))
	emitter(root, "EA", Vector2(10, 3), "generic", 0.8)
	emitter(root, "EB", Vector2(16, 3), "generic", 0.8)
	var ph := part(root, "string_phone", "Phone", Vector2(8, 9))
	ph.length = 120.0
	part(root, "trumpet", "Trumpet", Vector2(17, 9))
	add_common(root, Vector2(3, 13), Vector2(5, 13))
	save(root, "res://scenes/tests/test_extras.tscn")


# ---------------------------------------------------------------- 部品カタログ

func group(root: Node, nm: String) -> Node2D:
	var g := Node2D.new()
	g.name = nm
	g.y_sort_enabled = true
	add(root, g)
	return g


func label(parent: Node, root: Node, text: String, c: Vector2) -> void:
	var l: Node = load("res://scenes/parts/misc/world_label.tscn").instantiate()
	l.text = text
	l.position = cell_center(c) - Vector2(16, 12)
	parent.add_child(l)
	l.owner = root


func ipart(root: Node, parent: Node, kind: String, nm: String, c: Vector2) -> Node:
	var n := inst(root, "res://scenes/parts/puzzle/%s.tscn" % kind, cell_center(c), parent)
	n.name = nm
	return n


func iemit(root: Node, parent: Node, nm: String, c: Vector2, shape: String, size: float) -> Node:
	var e := inst(root, "res://scenes/parts/sound_wave/sound_emitter.tscn", cell_center(c), parent)
	e.name = nm
	e.source_name = nm
	e.shape = load("res://resources/wave_shapes/%s.tres" % shape)
	e.size = size
	return e


func ircv(root: Node, parent: Node, nm: String, c: Vector2) -> Node:
	var r := inst(root, "res://scenes/parts/sound_wave/wave_receiver.tscn", cell_center(c), parent)
	r.name = nm
	r.radius = 10.0
	return r


func _build_catalog() -> void:
	var root := new_world("res://scripts/tests/catalog.gd",
		"【部品カタログ】全部品。1:段のちがう音 2:楕円 3:重なる石 4:綿毛 5:カエル 6:動物 / F1 段番号 F2 波の範囲 F3 誰の目で見るか")
	var t := add_terrain(root)
	fill(t, Rect2i(0, 0, 66, 65), 0)

	# --- 地形(0,0)
	var o := Vector2(0, 0)
	var g := group(root, "TerrainDemo")
	fill(t, Rect2i(3, 3, 14, 8), 1)
	fill(t, Rect2i(6, 4, 8, 5), 2)
	fill(t, Rect2i(8, 5, 4, 3), 3)
	slope(t, Vector2i(9, 11), 0, S.N)
	slope(t, Vector2i(17, 6), 0, S.W)
	slope(t, Vector2i(2, 6), 0, S.E)
	slope(t, Vector2i(10, 2), 0, S.S)
	slope(t, Vector2i(14, 6), 1, S.W)
	slope(t, Vector2i(10, 8), 2, S.N)
	label(g, root, "A 地形:0〜3段と斜面\n崖の縁で A/Space を押すと滑空", Vector2(1, 1))

	# --- 音の波(1,0)
	o = Vector2(22, 0)
	g = group(root, "Waves")
	fill(t, Rect2i(int(o.x) + 8, 2, 5, 5), 1)
	fill(t, Rect2i(int(o.x) + 10, 3, 2, 2), 2)
	iemit(root, g, "E0", o + Vector2(4, 4), "impact", 2.0)
	iemit(root, g, "E1", o + Vector2(9, 3), "voice", 1.8)
	ircv(root, g, "R0", o + Vector2(2, 4))
	ircv(root, g, "R1", o + Vector2(15, 3))
	var wall := inst(root, "res://scenes/parts/sound_wave/sound_wall.tscn", cell_center(o + Vector2(10, 9.5)), g)
	wall.name = "Ellipse"
	wall.ellipse_size = Vector2(200, 72)
	wall.make_ellipse()
	wall.block_bodies = false
	var c := sqrt(100.0 * 100.0 - 36.0 * 36.0)
	var ef := iemit(root, g, "EFocus", Vector2.ZERO, "voice", 1.2)
	ef.position = cell_center(o + Vector2(10, 9.5)) - Vector2(c, 0)
	var zone := inst(root, "res://scenes/parts/sound_wave/sound_reflect_zone.tscn", cell_center(o + Vector2(8, 4.5)), g)
	zone.name = "NoReflectZone"
	zone.polygon = PackedVector2Array([Vector2(-20, -40), Vector2(4, -40), Vector2(4, 40), Vector2(-20, 40)])
	label(g, root, "E 音の波:1キーで0段と1段の音源\n2キーで楕円の焦点。赤い範囲の崖は跳ね返さない", o + Vector2(1, 1))

	# --- 扉・スイッチ・看板(2,0)
	o = Vector2(44, 0)
	g = group(root, "Doors")
	ipart(root, g, "floor_switch", "S1", o + Vector2(3, 3))
	ipart(root, g, "floor_switch", "S2", o + Vector2(7, 3))
	var grp := ipart(root, g, "switch_group", "Group", Vector2.ZERO)
	grp.switches.assign([NodePath("../S1"), NodePath("../S2")])
	var door := ipart(root, g, "door", "Door", o + Vector2(5, 6))
	door.width = 48.0
	wire(grp, "solved", door, "open")
	var sign := ipart(root, g, "symbol_sign", "Sign", o + Vector2(13, 4))
	sign.symbols = PackedInt32Array([0, 4, 8, 12])
	var who := [["SignP1", 1, o + Vector2(11, 9)], ["SignP2", 2, o + Vector2(14, 9)], ["SignLinked", 3, o + Vector2(17, 9)]]
	for w in who:
		var sg := ipart(root, g, "symbol_sign", w[0], w[2])
		sg.symbols = PackedInt32Array([w[1] + 1, w[1] + 5])
		var ov: Node = load("res://scenes/parts/puzzle/only_visible_to.tscn").instantiate()
		ov.name = "OnlyVisibleTo"
		ov.visible_to = w[1]
		sg.add_child(ov)
		ov.owner = root
	label(g, root, "H 二人で S1・S2 を同時に踏むと扉が開く\n看板:左=1人目だけ 中=2人目だけ 右=手をつないだ時だけ", o + Vector2(1, 1))

	# --- レバー・動物(0,1)
	o = Vector2(0, 13)
	g = group(root, "Animals")
	var lever := ipart(root, g, "lever", "Lever", o + Vector2(4, 4))
	lever.positions = 3
	var e1 := ipart(root, g, "voice_eater", "Eater1", o + Vector2(11, 6))
	e1.direction_map = PackedInt32Array([0, 2, 4])
	wire(lever, "position_changed", e1, "set_direction_index")
	var e2 := ipart(root, g, "voice_eater", "Eater2", o + Vector2(18, 6))
	e2.direction = 4
	e2.spit_shape = 1
	iemit(root, g, "E", o + Vector2(11, 2.5), "generic", 0.7)
	label(g, root, "I・J 二人で手をつないでレバーを引く→動物の向きが変わる\n6キー:音を動物に食べさせる(向いた方へ吐き出す)", o + Vector2(1, 1))

	# --- カエル(1,1 左)と棒(1,1 右)
	o = Vector2(22, 13)
	g = group(root, "Frog")
	var frog := ipart(root, g, "sleeping_frog", "Frog", o + Vector2(5, 5))
	iemit(root, g, "Noise", o + Vector2(5, 8), "impact", 1.6)
	var reset := ipart(root, g, "puzzle_reset", "Reset", o + Vector2(3, 10))
	for rp in [["RP1", 1, o + Vector2(3, 10)], ["RP2", 2, o + Vector2(4, 10)]]:
		var n: Node = load("res://scenes/parts/puzzle/reset_point.tscn").instantiate()
		n.name = rp[0]
		n.player_index = rp[1]
		n.position = cell_center(rp[2]) - reset.position
		reset.add_child(n)
		n.owner = root
	reset.parts.assign([NodePath("../Frog")])
	frog.reset_on_angry = NodePath("../Reset")
	label(g, root, "K 5キー:音を出す。何度も鳴らすと\n寝返り→薄目→怒る→やり直し", o + Vector2(1, 1))
	var gp := group(root, "Pole")
	fill(t, Rect2i(int(o.x) + 15, 16, 1, 1), 2)
	var pole := ipart(root, gp, "long_pole", "Pole", o + Vector2(15, 8))
	label(gp, root, "L 長い棒:両端で手を伸ばして握る\n柱に当てると音の波", o + Vector2(11, 1))

	# --- 鳥(2,1)
	o = Vector2(44, 13)
	g = group(root, "Birds")
	var bird_names := []
	var notes := [60.0, 64.0, 67.0]
	for i in range(3):
		var b := ipart(root, g, "singing_bird", "Bird%d" % i, o + Vector2(6 + i * 4, 3))
		b.notes = PackedFloat32Array([notes[i]])
		bird_names.append(NodePath("../Bird%d" % i))
		var bt := ipart(root, g, "instrument", "Bottle%d" % i, o + Vector2(6 + i * 4, 7))
		bt.note = notes[i]
		bt.size = 1.4
	var chord := ipart(root, g, "chord_judge", "Chord", Vector2.ZERO)
	chord.birds.assign(bird_names)
	label(g, root, "M 歌うか、瓶の近くで X/R を押す\n3羽がド・ミ・ソをそろえると和音成功", o + Vector2(1, 1))

	# --- かけらと捧げる場所(0,2)
	o = Vector2(0, 26)
	g = group(root, "Offering")
	for i in range(3):
		ipart(root, g, "sound_shard", "Shard%d" % i, o + Vector2(3 + i * 3, 3))
	var off := ipart(root, g, "offering_place", "Offering", o + Vector2(6, 7))
	off.required = 3
	var acts := [["Appear", 0], ["Disappear", 1], ["Fall", 2], ["Move", 3]]
	for i in range(acts.size()):
		var r := ipart(root, g, "island_change_reactor", acts[i][0], o + Vector2(12 + i * 2.5, 5))
		r.action = acts[i][1]
	var r2 := ipart(root, g, "island_change_reactor", "Stage2", o + Vector2(15, 9))
	r2.stage = 2
	label(g, root, "N かけらを3つ拾って円に立つと歌の波\n届くと段階1の物が 現れる/消える/落ちる/動く", o + Vector2(1, 1))

	# --- 余裕があれば(1,2)
	o = Vector2(22, 26)
	g = group(root, "Extras")
	var fl := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(o + Vector2(5, 3)), g)
	fl.name = "Fluff"
	iemit(root, g, "EFluff", o + Vector2(3, 3), "generic", 1.4)
	ipart(root, g, "overlap_stone", "Stone", o + Vector2(14, 3))
	iemit(root, g, "EA", o + Vector2(11, 3), "generic", 0.8)
	iemit(root, g, "EB", o + Vector2(17, 3), "generic", 0.8)
	var ph := ipart(root, g, "string_phone", "Phone", o + Vector2(7, 8))
	ph.length = 120.0
	ipart(root, g, "trumpet", "Trumpet", o + Vector2(15, 8))
	label(g, root, "O 4:綿毛を押す 3:重なる点の石\n糸電話は両端を握って張る / ラッパはつかむ", o + Vector2(1, 1))

	# --- 手つなぎ(2,2)
	o = Vector2(44, 26)
	g = group(root, "HandsArea")
	fill(t, Rect2i(int(o.x) + 12, 27, 9, 5), 1)
	fill(t, Rect2i(int(o.x) + 12, 32, 9, 6), 2)
	slope(t, Vector2i(int(o.x) + 11, 28), 0, S.E)
	slope(t, Vector2i(int(o.x) + 16, 31), 1, S.S)
	label(g, root, "D 手つなぎ:広場で片手の回転投げ・両手の反動\n右の崖(1段・2段)はつないだまま降りる・宙づり", o + Vector2(1, 1))

	# --- クリアの窓口とゴール(0,3)
	o = Vector2(0, 39)
	g = group(root, "Clear")
	var fl2 := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(o + Vector2(5, 3)), g)
	fl2.name = "Fluff2"
	iemit(root, g, "EFluff2", o + Vector2(3, 3), "generic", 1.6)
	var goal := inst(root, "res://scenes/parts/clear/fluff_goal.tscn", cell_center(o + Vector2(7, 3)), g)
	goal.name = "FluffGoal"
	goal.clear_event = &"fluff_done"
	var blk := inst(root, "res://scenes/parts/clear/clear_reactor.tscn", cell_center(o + Vector2(10, 3)), g)
	blk.name = "Block"
	blk.listen.assign([&"fluff_done"])
	inst(root, "res://scenes/parts/puzzle/long_pole.tscn", cell_center(o + Vector2(5, 8)), g).name = "Pole2"
	var sk := inst(root, "res://scenes/parts/clear/pole_socket.tscn", cell_center(o + Vector2(14, 8)), g)
	sk.name = "Socket"
	sk.clear_event = &"pole_done"
	var fx := inst(root, "res://scenes/parts/clear/clear_fx.tscn", cell_center(o + Vector2(11, 6)), g)
	fx.name = "Fx"
	fx.listen_all = true
	label(g, root, "クリアの窓口:綿毛を花へ→fluff_done で箱が消える
棒を型へ→pole_done / ClearFx が演出", o + Vector2(1, 1))

	# --- 同時押しと固定メガホン(1,3)
	o = Vector2(22, 39)
	g = group(root, "SyncMega")
	var s1 := inst(root, "res://scenes/parts/puzzle/sync_button.tscn", cell_center(o + Vector2(3, 4)), g)
	s1.name = "SyncA1"
	s1.clear_event = &"sync_done"
	inst(root, "res://scenes/parts/puzzle/sync_button.tscn", cell_center(o + Vector2(7, 4)), g).name = "SyncA2"
	var mg := inst(root, "res://scenes/parts/puzzle/fixed_megaphone.tscn", cell_center(o + Vector2(13, 8)), g)
	mg.name = "Megaphone"
	label(g, root, "同時押しボタン(二人で1.5秒以内に)
固定メガホン(後ろで話すと右へ遠く・遅れて)", o + Vector2(1, 1))

	# --- 回転レバーと正解する鳥(2,3)
	o = Vector2(44, 39)
	g = group(root, "RotaryBird")
	var rl := inst(root, "res://scenes/parts/puzzle/rotary_lever.tscn", cell_center(o + Vector2(4, 4)), g)
	rl.name = "RotaryLever"
	rl.targets.assign([NodePath("../Eater3")])
	inst(root, "res://scenes/parts/puzzle/voice_eater.tscn", cell_center(o + Vector2(9, 4)), g).name = "Eater3"
	var bd := inst(root, "res://scenes/parts/puzzle/singing_bird.tscn", cell_center(o + Vector2(14, 8)), g)
	bd.name = "BirdCorrect"
	bd.correct_notes = PackedFloat32Array([60])
	label(g, root, "回転レバー:つかんで左右に倒すと動物がゆっくり回る
鳥:ドで鳴くと正解の見た目
柵:人も綿毛も通さず、音の波は通す", o + Vector2(1, 1))
	var fc := inst(root, "res://scenes/parts/puzzle/fence.tscn", cell_center(o + Vector2(15, 4)), g)
	fc.name = "Fence"
	fc.length = 96.0
	fc.rotation_degrees = 30.0

	# --- 記号の暗号(0,4)
	o = Vector2(0, 52)
	g = group(root, "SymbolCode")
	var sl := inst(root, "res://scenes/parts/puzzle/symbol_code_lock.tscn", cell_center(o + Vector2(6, 4)), g)
	sl.name = "SymbolLock"
	sl.code_length = 3
	for i in range(5):
		var sp := inst(root, "res://scenes/parts/puzzle/symbol_pad.tscn", cell_center(o + Vector2(2 + i * 2, 7)), g)
		sp.name = "SymbolPad%d" % i
		sp.lock = NodePath("../SymbolLock")
		sp.symbol = i
	var spic := inst(root, "res://scenes/parts/puzzle/symbol_code_picture.tscn", cell_center(o + Vector2(15, 4)), g)
	spic.name = "SymbolPicture"
	spic.lock = NodePath("../SymbolLock")
	label(g, root, "記号の暗号:絵の記号を声で伝え、床を順に踏む
間違えると絵の記号が変わる", o + Vector2(1, 1))

	# 共通
	inst(root, "res://scenes/parts/hands/hand_link_monitor.tscn")
	inst(root, "res://scenes/parts/voice/voice_monitor.tscn")
	inst(root, "res://scenes/parts/sound_wave/debug_options.tscn")
	add_common(root, Vector2(27, 22), Vector2(29, 22))
	save(root, "res://scenes/catalog.tscn")


# ---------------------------------------------------------------- クリアの窓口・ゴール

func cpart(root: Node, kind: String, nm: String, c: Vector2) -> Node:
	var n := inst(root, "res://scenes/parts/clear/%s.tscn" % kind, cell_center(c))
	n.name = nm
	return n


func _build_clear() -> void:
	var root := flat_world("res://scripts/tests/test_clear.gd", "", Vector2i(24, 14))
	var fl := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(Vector2(5, 3)))
	fl.name = "Fluff"
	emitter(root, "EFluff", Vector2(3, 3), "generic", 1.6)
	var goal := cpart(root, "fluff_goal", "Goal", Vector2(7, 3))
	goal.clear_event = &"fluff_done"
	var block := cpart(root, "clear_reactor", "BlockA", Vector2(10, 3))
	block.listen.assign([&"fluff_done"])
	block.action = 1
	var pole := part(root, "long_pole", "Pole", Vector2(5, 9))
	var sock := cpart(root, "pole_socket", "Socket", Vector2(12, 9))
	sock.clear_event = &"pole_done"
	var door := part(root, "door", "Door", Vector2(16, 9))
	door.vertical = true
	var opener := cpart(root, "clear_reactor", "OpenDoor", Vector2(16, 11))
	opener.listen.assign([&"pole_done"])
	opener.action = 4
	opener.targets.assign([NodePath("../Door")])
	var bridge := cpart(root, "clear_reactor", "Bridge", Vector2(19, 6))
	bridge.listen.assign([&"fluff_done", &"pole_done"])
	bridge.action = 0
	var both := cpart(root, "clear_listener", "BothDone", Vector2.ZERO)
	both.listen.assign([&"fluff_done", &"pole_done"])
	var fx := cpart(root, "clear_fx", "Fx", Vector2(11, 6))
	fx.listen_all = true
	add_common(root, Vector2(3, 12), Vector2(5, 12))
	save(root, "res://scenes/tests/test_clear.tscn")


# ---------------------------------------------------------------- 同時押し・固定メガホン・回転レバー・正解する鳥

func _build_gimmicks() -> void:
	var root := flat_world("res://scripts/tests/test_gimmicks.gd", "", Vector2i(30, 16))
	var a1 := part(root, "sync_button", "SyncA1", Vector2(3, 3))
	a1.clear_event = &"sync_done"
	part(root, "sync_button", "SyncA2", Vector2(7, 3))
	var wall := cpart(root, "clear_reactor", "SyncWall", Vector2(5, 6))
	wall.listen.assign([&"sync_done"])
	wall.action = 1
	var lever := part(root, "rotary_lever", "Lever", Vector2(12, 3))
	lever.targets.assign([NodePath("../Plate"), NodePath("../Eater")])
	lever.clear_event = &"turned"
	lever.clear_angle_deg = 90.0
	var plate := Node2D.new()
	plate.name = "Plate"
	plate.position = cell_center(Vector2(15, 3))
	add(root, plate)
	var pl := Polygon2D.new()
	pl.polygon = PackedVector2Array([Vector2(-14, -3), Vector2(14, -3), Vector2(14, 3), Vector2(-14, 3)])
	pl.color = Color("9c7b4f")
	plate.add_child(pl)
	pl.owner = root
	part(root, "voice_eater", "Eater", Vector2(18, 3))
	var mega := part(root, "fixed_megaphone", "Megaphone", Vector2(5, 9))
	receiver(root, "RFar", Vector2(20, 9))
	receiver(root, "RSide", Vector2(5, 14))
	var bird := part(root, "singing_bird", "Bird", Vector2(12, 9))
	bird.notes = PackedFloat32Array([60, 64, 67])
	bird.correct_notes = PackedFloat32Array([60])
	bird.clear_event = &"bird_ok"
	var fx := cpart(root, "clear_fx", "Fx", Vector2(10, 7))
	fx.listen_all = true
	add_common(root, Vector2(2, 12), Vector2(3, 12))
	save(root, "res://scenes/tests/test_gimmicks.tscn")


# ---------------------------------------------------------------- 柵

func _build_fence() -> void:
	var root := flat_world("res://scripts/tests/test_fence.gd", "", Vector2i(24, 14))
	var fh := part(root, "fence", "FenceH", Vector2(6, 6))
	fh.length = 160.0
	var fl := inst(root, "res://scenes/parts/props/fluff.tscn", cell_center(Vector2(6.3, 4)))
	fl.name = "Fluff"
	emitter(root, "EF", Vector2(6.3, 2.5), "generic", 1.6)
	receiver(root, "R", Vector2(6.3, 9))
	var fd := part(root, "fence", "FenceDiag", Vector2(12, 6))
	fd.length = 128.0
	fd.rotation_degrees = 45.0
	var fv := part(root, "fence", "FenceV", Vector2(16, 6))
	fv.length = 128.0
	fv.angle_deg = 90.0
	add_common(root, Vector2(5, 3), Vector2(2, 12))
	save(root, "res://scenes/tests/test_fence.tscn")


# ---------------------------------------------------------------- 記号の暗号

func _build_symbol_code() -> void:
	var root := flat_world("res://scripts/tests/test_symbol_code.gd", "", Vector2i(24, 14))
	var pic := part(root, "symbol_code_picture", "Picture", Vector2(17, 3))
	pic.lock = NodePath("../Lock")
	var lock := part(root, "symbol_code_lock", "Lock", Vector2(6, 4))
	lock.code_length = 3
	lock.clear_event = &"code_done"
	for i in range(5):
		var pad := part(root, "symbol_pad", "Pad%d" % i, Vector2(2 + i * 2, 7))
		pad.lock = NodePath("../Lock")
		pad.symbol = i
	var door := part(root, "door", "Door", Vector2(6, 10))
	door.width = 64.0
	var opener := cpart(root, "clear_reactor", "OpenDoor", Vector2(9, 10))
	opener.listen.assign([&"code_done"])
	opener.action = 4
	opener.targets.assign([NodePath("../Door")])
	add_common(root, Vector2(3, 11), Vector2(16, 5))
	save(root, "res://scenes/tests/test_symbol_code.tscn")
