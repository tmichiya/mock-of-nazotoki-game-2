@tool
class_name TerrainPalette
extends RefCounted
## 地形のタイルセットのパレット画像(textures/terrain/terrain_palette.png)を、段の見た目(LevelStyle)から作る。
## 並び: 行 = 段番号(0〜LEVELS-1)、列 = 平地 / 奥へ上る / 手前へ上る / 右へ上る / 左へ上る
## 床の色と模様は、地形が実際に描く床と同じにし、左上に段番号、斜面には上り方向の矢印を描く。

const LEVELS := 8
const SHAPES := 5
const PNG_PATH := "res://textures/terrain/terrain_palette.png"
const TILESET_PATH := "res://resources/terrain/terrain_tileset.tres"

const DIGITS := [
	"111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001010010010", "111101111101111", "111101111001111",
]


static func build_image(cfg: WorldConfig, style: LevelStyle) -> Image:
	var ts := cfg.tile_size
	var img := Image.create(ts.x * SHAPES, ts.y * LEVELS, false, Image.FORMAT_RGBA8)
	for lv in range(LEVELS):
		for sh in range(SHAPES):
			var o := Vector2i(sh * ts.x, lv * ts.y)
			var col := style.floor_color(lv)
			if sh > 0:
				col = col.lerp(style.floor_color(lv + 1), 0.5)
			img.fill_rect(Rect2i(o, ts), col)
			if sh == 0:
				_draw_pattern(img, style.pattern(lv), o, ts, col.darkened(style.pattern_strength))
			else:
				_draw_slope_lines(img, sh, o, ts, col.lightened(0.25))
				_draw_arrow(img, sh, o + ts / 2, Color.WHITE)
			# 枠(崖の輪郭と同じ色)
			var dark := style.outline_color
			_rect_outline(img, Rect2i(o, ts), dark)
			_draw_digit(img, lv, o + Vector2i(2, 2), Color.WHITE, Color(0, 0, 0, 0.8))
	return img


## パレット画像を保存する。タイルセットが無ければ作る。エディタの中なら取り込み直す
static func save(cfg: WorldConfig, style: LevelStyle) -> Error:
	var img := build_image(cfg, style)
	var err := img.save_png(ProjectSettings.globalize_path(PNG_PATH))
	if err != OK:
		return err
	if Engine.is_editor_hint():
		var ei = Engine.get_singleton("EditorInterface")
		if ei:
			ei.get_resource_filesystem().reimport_files(PackedStringArray([PNG_PATH]))
	return OK


## タイルセットを作り直す(段番号・形のカスタムデータ付き)。パレット画像を先に取り込んでおくこと
static func build_tileset(cfg: WorldConfig, texture: Texture2D) -> TileSet:
	var tset := TileSet.new()
	tset.tile_size = cfg.tile_size
	tset.add_custom_data_layer()
	tset.set_custom_data_layer_name(0, "level")
	tset.set_custom_data_layer_type(0, TYPE_INT)
	tset.add_custom_data_layer()
	tset.set_custom_data_layer_name(1, "shape")
	tset.set_custom_data_layer_type(1, TYPE_INT)
	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.texture_region_size = cfg.tile_size
	tset.add_source(src, 0)
	for lv in range(LEVELS):
		for sh in range(SHAPES):
			var coords := Vector2i(sh, lv)
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			td.set_custom_data("level", lv)
			td.set_custom_data("shape", sh)
	return tset


# ---------------------------------------------------------------- 描く小物

static func _draw_pattern(img: Image, pat: int, o: Vector2i, ts: Vector2i, col: Color) -> void:
	match pat:
		LevelStyle.Pattern.DOTS:
			img.fill_rect(Rect2i(o + Vector2i(7, 6), Vector2i(2, 2)), col)
			img.fill_rect(Rect2i(o + Vector2i(22, 15), Vector2i(2, 2)), col)
		LevelStyle.Pattern.STRIPES:
			_line(img, o + Vector2i(4, ts.y - 4), o + Vector2i(14, 4), col)
			_line(img, o + Vector2i(18, ts.y - 4), o + Vector2i(28, 4), col)
		LevelStyle.Pattern.CHECKER:
			img.fill_rect(Rect2i(o, ts / 2), col)
			img.fill_rect(Rect2i(o + ts / 2, ts / 2), col)
		LevelStyle.Pattern.CROSS:
			var c := o + ts / 2
			_line(img, c + Vector2i(-4, -3), c + Vector2i(4, 3), col)
			_line(img, c + Vector2i(-4, 3), c + Vector2i(4, -3), col)
		LevelStyle.Pattern.WAVES:
			var y := o.y + ts.y / 2
			for i in range(4):
				_line(img, Vector2i(o.x + 4 + i * 6, y + (-2 if i % 2 == 0 else 2)), Vector2i(o.x + 10 + i * 6, y + (2 if i % 2 == 0 else -2)), col)


static func _draw_slope_lines(img: Image, shape: int, o: Vector2i, ts: Vector2i, col: Color) -> void:
	for i in range(1, 4):
		match shape:
			1, 2:
				var y := o.y + ts.y * i / 4
				_line(img, Vector2i(o.x + 1, y), Vector2i(o.x + ts.x - 2, y), col)
			_:
				var x := o.x + ts.x * i / 4
				_line(img, Vector2i(x, o.y + 1), Vector2i(x, o.y + ts.y - 2), col)


static func _draw_arrow(img: Image, shape: int, center: Vector2i, col: Color) -> void:
	var dir := Vector2i.ZERO
	match shape:
		1: dir = Vector2i(0, -1)
		2: dir = Vector2i(0, 1)
		3: dir = Vector2i(1, 0)
		4: dir = Vector2i(-1, 0)
	var side := Vector2i(-dir.y, dir.x)
	_line(img, center - dir * 6, center + dir * 6, col)
	var tip := center + dir * 6
	_line(img, tip, tip - dir * 4 + side * 4, col)
	_line(img, tip, tip - dir * 4 - side * 4, col)


static func _draw_digit(img: Image, n: int, at: Vector2i, col: Color, shadow: Color) -> void:
	var s: String = DIGITS[n % 10]
	for pass_i in [0, 1]:
		var off := Vector2i(1, 1) if pass_i == 0 else Vector2i.ZERO
		var c := shadow if pass_i == 0 else col
		for y in range(5):
			for x in range(3):
				if s[y * 3 + x] == "1":
					img.fill_rect(Rect2i(at + off + Vector2i(x, y) * 2, Vector2i(2, 2)), c)


static func _rect_outline(img: Image, r: Rect2i, col: Color) -> void:
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), col)
	img.fill_rect(Rect2i(r.position + Vector2i(0, r.size.y - 1), Vector2i(r.size.x, 1)), col)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), col)
	img.fill_rect(Rect2i(r.position + Vector2i(r.size.x - 1, 0), Vector2i(1, r.size.y)), col)


static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(n + 1):
		var p := Vector2(a).lerp(Vector2(b), float(i) / maxf(n, 1))
		var q := Vector2i(roundi(p.x), roundi(p.y))
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixelv(q, col)
