class_name InputConfig
extends Resource
## 操作の割り当て(全プレイヤー共通)。res://resources/settings/input_config.tres を編集すると全員に反映される。
## コントローラーは「何番のコントローラーか」をプレイヤーごとに選ぶので、InputMap は使わず直接読む。

enum PoseTrigger { LT, RT, EITHER }

@export_group("コントローラー")
## ポーズモードに使うトリガー(未決定なのでここで切り替える)
@export var pose_trigger := PoseTrigger.LT
## トリガーをどこまで押したら「押している」とみなすか
@export_range(0.05, 1.0) var trigger_threshold := 0.4
## 左スティックの遊び(これより小さい傾きは0)
@export_range(0.0, 0.9) var move_deadzone := 0.2
## ポーズ中の腕:スティックをこれ以上倒すと腕がその方向へスナップする。これより小さいと腕を下ろす
@export_range(0.1, 0.95) var arm_deadzone := 0.5
@export var glide_button := JOY_BUTTON_A
@export var grab_left_button := JOY_BUTTON_LEFT_SHOULDER
@export var grab_right_button := JOY_BUTTON_RIGHT_SHOULDER
## 楽器(瓶笛など)を鳴らすボタン
@export var instrument_button := JOY_BUTTON_X

@export_group("キーボードA(1人目)")
@export var a_up := KEY_W
@export var a_down := KEY_S
@export var a_left := KEY_A
@export var a_right := KEY_D
## ポーズ中は移動キーが画面左側の腕、腕キーが画面右側の腕になる
@export var a_pose := KEY_SHIFT
@export var a_arm_up := KEY_I
@export var a_arm_down := KEY_K
@export var a_arm_left := KEY_J
@export var a_arm_right := KEY_L
@export var a_grab_left := KEY_Q
@export var a_grab_right := KEY_E
@export var a_glide := KEY_SPACE
@export var a_instrument := KEY_R

@export_group("キーボードB(1台で2人を動かす時の2人目)")
@export var b_up := KEY_UP
@export var b_down := KEY_DOWN
@export var b_left := KEY_LEFT
@export var b_right := KEY_RIGHT
@export var b_pose := KEY_SLASH
@export var b_arm_up := KEY_KP_8
@export var b_arm_down := KEY_KP_5
@export var b_arm_left := KEY_KP_4
@export var b_arm_right := KEY_KP_6
@export var b_grab_left := KEY_COMMA
@export var b_grab_right := KEY_PERIOD
@export var b_glide := KEY_ENTER
@export var b_instrument := KEY_BACKSLASH


static var _default: InputConfig


static func get_default() -> InputConfig:
	if _default == null:
		_default = load("res://resources/settings/input_config.tres")
	return _default
