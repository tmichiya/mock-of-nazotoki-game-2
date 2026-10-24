class_name FollowCamera
extends Camera2D
## この端末の自分(1台で2人なら2人の真ん中)を追う固定角度のカメラ。島のシーンに1つ置く。
## 見た目の位置(高さの分だけ上)を追うので、高い段にいても画面の中心に来る。

## 拡大率(2 なら 1px が画面の 2px)
@export var view_zoom := 2.0:
	set(v):
		view_zoom = v
		zoom = Vector2(v, v)
## 追いかけの滑らかさ(大きいほどすぐ追いつく)
@export var follow_speed := 6.0
## カメラの位置を1ピクセル単位に揃える(ちらつき対策)
@export var pixel_snap := true
## 追う相手がいない時の位置
@export var idle_position := Vector2.ZERO

var _pos := Vector2.ZERO


func _ready() -> void:
	zoom = Vector2(view_zoom, view_zoom)
	_pos = global_position
	make_current()


func _process(delta: float) -> void:
	var targets := World.get_local_players()
	if targets.is_empty():
		targets = World.get_players()
	if targets.is_empty():
		return
	var sum := Vector2.ZERO
	for p in targets:
		sum += p.global_position + World.height_offset(p.height)
	var goal := sum / targets.size()
	_pos = _pos.lerp(goal, clampf(delta * follow_speed, 0.0, 1.0))
	global_position = _pos.round() if pixel_snap else _pos
