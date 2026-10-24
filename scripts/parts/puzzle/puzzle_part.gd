@tool
class_name PuzzlePart
extends Node2D
## 謎の部品の共通部分。
## ・高さ: 置いた場所の地形の段に立つ(fixed_level で上書きできる)。見た目は高さの分だけ上に描く
## ・状態の同期: 状態はホストが決め、set_state() で相手にも配る。相手が後から来ても送り直す
## ・つかむ: 手を伸ばしている(LB/RB)プレイヤーの、空いている手が近くにあるかを調べる

## 立つ段(-1 なら置いた場所の地形の段)
@export var fixed_level := -1:
	set(v):
		fixed_level = v
		queue_redraw()

var height := 0.0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("puzzle_parts")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_update_height()
	Net.peer_scene_ready.connect(_on_peer_ready)


func _update_height() -> void:
	height = float(fixed_level) if fixed_level >= 0 else World.height_at(global_position)


func get_level() -> int:
	return roundi(height)


## 見た目のずらし量(高さの分だけ上へ)
func lift(extra_levels: float = 0.0) -> Vector2:
	var lp := WorldConfig.get_default().level_px
	if Engine.is_editor_hint():
		return Vector2(0, -maxf(fixed_level, 0) * lp - extra_levels * lp)
	return Vector2(0, -(height + extra_levels) * lp)


func is_authority() -> bool:
	return Net.is_host()


# ---------------------------------------------------------------- 状態の同期

## 今の状態(派生側で作る)
func get_state() -> Dictionary:
	return {}


## 状態を反映する(派生側で作る)。ホストでもクライアントでも呼ばれる
func apply_state(_s: Dictionary) -> void:
	pass


## ホストが状態を変えた後に呼ぶ。相手にも同じ状態を配る
func sync_state() -> void:
	if not is_authority() or not Net.is_online():
		return
	var s := get_state()
	for id in Net.ready_remote_ids():
		_rpc_state.rpc_id(id, s)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(s: Dictionary) -> void:
	apply_state(s)


func _on_peer_ready(id: int) -> void:
	if is_authority():
		_rpc_state.rpc_id(id, get_state())


# ---------------------------------------------------------------- つかむ

## point(地面の位置)の近く radius 以内に、つかもうとしている手があるプレイヤーを探す。
## つかむ条件は手つなぎと同じ形:腕を伸ばしていて(ポーズ中にスティック)、握っていて、つないでいなくて、
## 手の地面の位置が point から radius 以内。戻り値 [player, hand] / 見つからなければ []
func find_grabber(point: Vector2, radius: float, level_tolerance: float = 0.6) -> Array:
	var best := []
	var best_d := radius
	for p: Player in World.get_players():
		if absf(p.height - height) > level_tolerance:
			continue
		for h in [Player.Hand.LEFT, Player.Hand.RIGHT]:
			if not Hands.hand_is_free(p, h):
				continue
			var d := p.get_hand_ground_position(h).distance_to(point)
			if d <= best_d:
				best_d = d
				best = [p, h]
	return best


## 握り続けているか(つかんだ物を持ち続ける条件)
static func is_reaching(p: Player, h: int) -> bool:
	return p.is_gripping(h)


## つかんだ手の行き先を、この物の位置にする(毎フレーム呼ぶ)。外す時は release_hand
func hold_hand(p: Player, h: int, point: Vector2) -> void:
	p.set_link_point(h, point, 0.0, _link_key(), height)


func release_hand(p: Player, h: int) -> void:
	if is_instance_valid(p):
		p.set_link_point(h, null, 0.0, _link_key())


func _link_key() -> String:
	return "part:" + str(get_path())


# ---------------------------------------------------------------- 描画の小物

func draw_label(text: String, at: Vector2, col := Color.WHITE, size := 8) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 64, size, col)


func draw_box(center: Vector2, size: Vector2, top_col: Color, side_col: Color, levels: float) -> void:
	## 立方体ふうの箱(上面と手前の面)を描く。center は地面の位置からの相対
	var lp := WorldConfig.get_default().level_px
	var h := levels * lp
	var top := Rect2(center - size * 0.5 + Vector2(0, -h), size)
	draw_rect(Rect2(top.position + Vector2(0, size.y), Vector2(size.x, h)), side_col)
	draw_rect(top, top_col)
	draw_rect(top, Color(0, 0, 0, 0.6), false, 1.0)
