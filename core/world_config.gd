@tool
class_name WorldConfig
extends Resource
## 世界の寸法の設定。res://core/world_config.tres を全部品が共有する。
## 「地面の位置(position)」と「高さ(段単位の小数)」から画面上の位置を決める。

## 地面のマス1つの大きさ(px)。横長にすると斜めから見下ろした見た目になる
@export var tile_size := Vector2i(32, 24):
	set(v):
		tile_size = v
		emit_changed()
## 1段の高さが画面上で何pxか。手前に向かって上る斜面を見せるため、tile_size.y より小さくする
@export var level_px := 12.0:
	set(v):
		level_px = v
		emit_changed()
## 1段の「実際の高さ」(手つなぎの腕の長さなど、立体的な距離を計算する時に使う。地面と同じpx単位)
@export var level_world_px := 18.0:
	set(v):
		level_world_px = v
		emit_changed()
## 島の外(空のマス)の崖を何段下まで描くか
@export var void_depth_levels := 1.5


## 高さ h(段)の物を描く時の、見た目のずらし量
func height_offset(h: float) -> Vector2:
	return Vector2(0.0, -h * level_px)


func ground_to_screen(ground: Vector2, h: float) -> Vector2:
	return ground + height_offset(h)


func has_slope_warning() -> bool:
	return level_px >= float(tile_size.y)


static var _default: WorldConfig


static func get_default() -> WorldConfig:
	if _default == null:
		_default = load("res://core/world_config.tres")
	return _default
