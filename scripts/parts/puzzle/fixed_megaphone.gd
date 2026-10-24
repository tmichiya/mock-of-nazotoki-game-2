@tool
class_name FixedMegaphone
extends PuzzlePart
## 地面に突き刺さった棒に固定された、動かせない一方向メガホン。
## 吹き口(後ろ側)の近くに立って話すと、声はメガホンの口から、向いている方向へ扇形で遠くまで届く。
## ラッパと同じく、メガホンを通した声は波が届いた時に遅れて聞こえる(delay_voice)。

signal used_by(player_index: int)
signal released_by(player_index: int)

## 向き(度。0=右、90=下)
@export var direction_deg := 0.0:
	set(v):
		direction_deg = v
		queue_redraw()
## 扇の広がり(度、片側)
@export_range(5, 90) var spread_deg := 20.0:
	set(v):
		spread_deg = v
		queue_redraw()
## 声の届く距離の倍率
@export var size_scale := 2.5
## 遅れて聞こえる声にする
@export var delay_voice := true
## 吹き口からこの距離(px)以内で話すと使える
@export var use_radius := 14.0
## 吹き口の位置(メガホンの後ろへ何px)
@export var mouthpiece_offset := 10.0
@export var color := Color("d9a441")

var _users := {}     # この端末で操作しているプレイヤー -> true


func _dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(direction_deg))


func mouthpiece_position() -> Vector2:
	return global_position - _dir() * mouthpiece_offset


func horn_position() -> Vector2:
	return global_position + _dir() * 8.0


## 声は話す人の端末で作られるので、この端末で操作しているプレイヤーにだけ設定する(ホストは関係ない)
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for p: Player in World.get_local_players():
		var near := p.global_position.distance_to(mouthpiece_position()) <= use_radius and absf(p.height - height) < 0.6
		if near and not _users.has(p):
			_users[p] = true
			p.voice_modifier = {
				dir = _dir(), spread = deg_to_rad(spread_deg), size_scale = size_scale,
				delay_voice = delay_voice, origin = horn_position(), level = get_level(),
			}
			used_by.emit(p.player_index)
		elif not near and _users.has(p):
			_users.erase(p)
			if p.voice_modifier.get("origin", null) == horn_position():
				p.voice_modifier = {}
			released_by.emit(p.player_index)


func _exit_tree() -> void:
	for p in _users.keys():
		if is_instance_valid(p):
			p.voice_modifier = {}
	_users.clear()


func _draw() -> void:
	var base := lift()
	var lp := WorldConfig.get_default().level_px
	var d := _dir()
	var side := d.orthogonal()
	var top := base + Vector2(0, -1.2 * lp)
	# 地面に刺さった棒
	draw_line(base + Vector2(0, 2), top, Color("6b5440"), 2.0)
	# メガホン(吹き口 → 口に向かって広がる)
	var mouth_back := top - d * 6.0
	var mouth_front := top + d * 8.0
	var poly := PackedVector2Array([mouth_back + side * 1.5, mouth_front + side * 5.0, mouth_front - side * 5.0, mouth_back - side * 1.5])
	draw_colored_polygon(poly, color)
	poly.append(poly[0])
	draw_polyline(poly, color.darkened(0.4), 1.0)
	# 届く方向の目印(扇)
	var a := deg_to_rad(direction_deg)
	var s := deg_to_rad(spread_deg)
	var c := Color(color, 0.35)
	draw_line(mouth_front, mouth_front + Vector2.from_angle(a - s) * 14.0, c, 1.0)
	draw_line(mouth_front, mouth_front + Vector2.from_angle(a + s) * 14.0, c, 1.0)
	# 吹き口(ここに立って話す)
	var mp := base - d * mouthpiece_offset
	draw_arc(mp, use_radius * 0.5, 0, TAU, 16, Color(1, 1, 1, 0.3 if not _users.is_empty() else 0.15), 1.0)
