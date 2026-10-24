extends SceneTree
## 地形用タイルセット(parts/terrain/terrain_tileset.tres)を作り直すスクリプト。
## 段の色を LevelStyle から取り、パレットの見た目を合わせる。
## 実行: godot --headless --path . --script res://tools/make_terrain_tileset.gd
##
## パレットの並び: 行 = 段番号(0〜LEVELS-1)、列 = 平地 / 奥へ上る / 手前へ上る / 右へ上る / 左へ上る

const LEVELS := 8
const SHAPES := 5
const OUT := "res://parts/terrain/terrain_tileset.tres"
const PNG := "res://parts/terrain/terrain_palette.png"

const DIGITS := [
	"111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001010010010", "111101111101111", "111101111001111",
]


func _init() -> void:
	var cfg: WorldConfig = load("res://core/world_config.tres")
	var style: LevelStyle = load("res://core/level_style.tres")
	var ts := cfg.tile_size
	var img := Image.create(ts.x * SHAPES, ts.y * LEVELS, false, Image.FORMAT_RGBA8)
	for lv in range(LEVELS):
		for sh in range(SHAPES):
			var o := Vector2i(sh * ts.x, lv * ts.y)
			var col := style.floor_color(lv)
			if sh > 0:
				col = col.lerp(style.floor_color(lv + 1), 0.5)
			img.fill_rect(Rect2i(o, ts), col)
			# 枠
			var dark := col.darkened(0.5)
			img.fill_rect(Rect2i(o, Vector2i(ts.x, 1)), dark)
			img.fill_rect(Rect2i(o + Vector2i(0, ts.y - 1), Vector2i(ts.x, 1)), dark)
			img.fill_rect(Rect2i(o, Vector2i(1, ts.y)), dark)
			img.fill_rect(Rect2i(o + Vector2i(ts.x - 1, 0), Vector2i(1, ts.y)), dark)
			_draw_digit(img, lv, o + Vector2i(3, 3), Color.WHITE)
			if sh > 0:
				_draw_arrow(img, sh, o + ts / 2, Color.WHITE)
	img.save_png(ProjectSettings.globalize_path(PNG))
	# 取り込み済みならPNGを参照、まだなら一時的に埋め込む(取り込み後にもう一度実行すると参照に変わる)
	var tex: Texture2D
	if ResourceLoader.exists(PNG):
		tex = load(PNG)
	if tex == null:
		tex = ImageTexture.create_from_image(img)
		print("PNG がまだ取り込まれていないので埋め込みました。--import の後にもう一度実行してください。")

	var tset := TileSet.new()
	tset.tile_size = ts
	tset.add_custom_data_layer()
	tset.set_custom_data_layer_name(0, "level")
	tset.set_custom_data_layer_type(0, TYPE_INT)
	tset.add_custom_data_layer()
	tset.set_custom_data_layer_name(1, "shape")
	tset.set_custom_data_layer_type(1, TYPE_INT)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = ts
	tset.add_source(src, 0)
	for lv in range(LEVELS):
		for sh in range(SHAPES):
			var coords := Vector2i(sh, lv)
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			td.set_custom_data("level", lv)
			td.set_custom_data("shape", sh)
	var err := ResourceSaver.save(tset, OUT)
	print("saved ", OUT, " err=", err)
	quit()


func _draw_digit(img: Image, n: int, at: Vector2i, col: Color) -> void:
	var s: String = DIGITS[n % 10]
	for y in range(5):
		for x in range(3):
			if s[y * 3 + x] == "1":
				img.fill_rect(Rect2i(at + Vector2i(x, y) * 2, Vector2i(2, 2)), col)


func _draw_arrow(img: Image, shape: int, center: Vector2i, col: Color) -> void:
	var dir := Vector2i.ZERO
	match shape:
		1: dir = Vector2i(0, -1)
		2: dir = Vector2i(0, 1)
		3: dir = Vector2i(1, 0)
		4: dir = Vector2i(-1, 0)
	var side := Vector2i(-dir.y, dir.x)
	# 軸
	for i in range(-6, 7):
		img.fill_rect(Rect2i(center + dir * i, Vector2i(1, 1)), col)
	# 矢じり
	for i in range(1, 5):
		var tip := center + dir * 6
		img.fill_rect(Rect2i(tip - dir * i + side * i, Vector2i(1, 1)), col)
		img.fill_rect(Rect2i(tip - dir * i - side * i, Vector2i(1, 1)), col)
