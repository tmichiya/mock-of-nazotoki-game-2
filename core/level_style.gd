@tool
class_name LevelStyle
extends Resource
## 段ごとの床の見た目を「一か所で」決めるリソース。
## 同じ段は必ず同じ見た目になる(地形の描画はここ以外から色を取らない)。
## 段の見分けを謎に使うため、マスごとの例外は作れない作りにしている。

enum Pattern { NONE, DOTS, STRIPES, CHECKER, CROSS, WAVES }

## 段番号ごとの床の色(0段目から順に)。足りない段は最後の色を少しずつ明るくして使う
@export var floor_colors: PackedColorArray = PackedColorArray([
	Color("4f7d5a"), Color("7a9a55"), Color("b3a36a"), Color("c98f5f"),
	Color("a8736f"), Color("8c7aa8"), Color("6f8fb3"), Color("d8d0c0"),
]):
	set(v):
		floor_colors = v
		emit_changed()
## 段番号ごとの模様(床の色の上に描く)
@export var patterns: Array[Pattern] = [
	Pattern.NONE, Pattern.DOTS, Pattern.STRIPES, Pattern.CHECKER,
	Pattern.CROSS, Pattern.WAVES, Pattern.DOTS, Pattern.STRIPES,
]:
	set(v):
		patterns = v
		emit_changed()
## 段番号ごとの模様テクスチャ(任意。設定すると模様の代わりに床に敷く)
@export var textures: Array[Texture2D] = []:
	set(v):
		textures = v
		emit_changed()
## 模様の濃さ(床の色を何割暗く/明るくするか)
@export_range(0.0, 1.0) var pattern_strength := 0.18:
	set(v):
		pattern_strength = v
		emit_changed()
## 崖の側面の暗さ(床の色に掛ける)
@export_range(0.0, 1.0) var cliff_darken := 0.45:
	set(v):
		cliff_darken = v
		emit_changed()
## 崖の上端の輪郭線
@export var outline_color := Color(0.12, 0.1, 0.1, 0.9):
	set(v):
		outline_color = v
		emit_changed()
@export var outline_width := 1.0:
	set(v):
		outline_width = v
		emit_changed()
## 崖の根元に落ちる影(低い側の床に描く帯)
@export var base_shadow_color := Color(0, 0, 0, 0.22):
	set(v):
		base_shadow_color = v
		emit_changed()
@export var base_shadow_width := 5.0:
	set(v):
		base_shadow_width = v
		emit_changed()
## 斜面の床は「つながる2つの段の色の中間」に、上り方向を示す線を重ねる
@export var slope_line_color := Color(1, 1, 1, 0.25):
	set(v):
		slope_line_color = v
		emit_changed()
## 島の外側の崖の色
@export var void_cliff_color := Color("3b3530"):
	set(v):
		void_cliff_color = v
		emit_changed()


func floor_color(level: int) -> Color:
	if floor_colors.is_empty():
		return Color.GRAY
	if level < 0:
		return floor_colors[0].darkened(0.3)
	if level < floor_colors.size():
		return floor_colors[level]
	var extra := level - floor_colors.size() + 1
	return floor_colors[floor_colors.size() - 1].lightened(0.08 * extra)


func pattern(level: int) -> Pattern:
	if level >= 0 and level < patterns.size():
		return patterns[level]
	return Pattern.NONE


func texture(level: int) -> Texture2D:
	if level >= 0 and level < textures.size():
		return textures[level]
	return null


func cliff_color(level: int) -> Color:
	return floor_color(level).darkened(cliff_darken)
