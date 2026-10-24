class_name InputConfig
extends Resource
## 操作の割り当て(全プレイヤー共通)。res://resources/settings/input_config.tres を編集すると全員に反映される。
## コントローラーは「何番のコントローラーか」をプレイヤーごとに選ぶので、InputMap は使わず直接読む。

enum PoseTrigger { LT, RT, EITHER }

@export_group("コントローラー")
## ポーズモードに使うトリガー(未決定なのでここで切り替える。既定はどちらでも)
@export var pose_trigger := PoseTrigger.EITHER
## トリガーをどこまで押したら「押している」とみなすか
@export_range(0.05, 1.0) var trigger_threshold := 0.4
## 左スティックの遊び(これより小さい傾きは0)
@export_range(0.0, 0.9) var move_deadzone := 0.2
@export var glide_button := JOY_BUTTON_A
@export var grab_left_button := JOY_BUTTON_LEFT_SHOULDER
@export var grab_right_button := JOY_BUTTON_RIGHT_SHOULDER
## 押している間、その腕を上へ挙げる(L3 / R3)
@export var raise_left_button := JOY_BUTTON_LEFT_STICK
@export var raise_right_button := JOY_BUTTON_RIGHT_STICK
## 走る/歩くを切り替えるボタン(既定は上のボタン。Xbox の Y)
@export var run_button := JOY_BUTTON_Y
## つかんでいる物・つないでいる手を全部離すボタン(戻るボタン)。既定は右のボタン(Xbox の B)。
## Switch の並び(下が B)にしたい時は JOY_BUTTON_A にして、滑空(glide_button)を別のボタンにする
@export var release_button := JOY_BUTTON_B
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
@export var a_raise_left := KEY_Z
@export var a_raise_right := KEY_C
@export var a_glide := KEY_SPACE
@export var a_instrument := KEY_R
@export var a_run := KEY_CTRL
@export var a_release := KEY_X

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
@export var b_raise_left := KEY_KP_7
@export var b_raise_right := KEY_KP_9
@export var b_glide := KEY_ENTER
@export var b_instrument := KEY_BACKSLASH
@export var b_run := KEY_KP_0
@export var b_release := KEY_KP_PERIOD


static var _default: InputConfig


static func get_default() -> InputConfig:
	if _default == null:
		_default = load("res://resources/settings/input_config.tres")
	return _default
