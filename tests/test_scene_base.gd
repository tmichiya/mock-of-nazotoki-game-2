class_name TestSceneBase
extends Node2D
## 確認用シーンの共通部分。画面の左上に「確かめること」と操作を表示する。
## 子の Autopilot に台本(_steps)を渡す(起動引数 --autopilot の時だけ動く)。

## 画面に出す説明
@export_multiline var help_text := ""

const COMMON_HELP := "移動 WASD/左スティック  ポーズ Shift/LT  腕 移動キー+IJKL/両スティック  手 Q,E/LB,RB  滑空 Space/A\n2人目: 矢印  ポーズ /  腕 矢印+テンキー8456  手 , .  滑空 Enter    F1 段番号  F2 波の範囲"

var _label: Label


func _ready() -> void:
	y_sort_enabled = true
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.text = help_text + "\n" + COMMON_HELP
	layer.add_child(_label)
	var ap := get_node_or_null("Autopilot") as Autopilot
	if ap:
		ap.steps = _steps()


func _steps() -> Array:
	return []


func set_status(text: String) -> void:
	_label.text = help_text + "\n" + COMMON_HELP + "\n" + text
