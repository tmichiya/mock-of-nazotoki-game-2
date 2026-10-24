class_name PuzzleReset
extends Node2D
## 謎のやり直し。reset() を呼ぶと(カエルの failed、SwitchGroup の wrong などをつなぐ)、
## ・子の ResetPoint の場所へ、プレイヤーや物を戻す
## ・parts に登録した部品の reset() を呼ぶ(レバー・スイッチ・カエルなど)

signal reset_done

## reset() を呼ぶ部品
@export var parts: Array[NodePath] = []
## プレイヤーを戻す前に待つ時間(秒。カエルが怒る演出を見せる間)
@export var delay := 0.6
## 手つなぎを切ってから戻す
@export var unlink_hands := true


func reset() -> void:
	if not Net.is_host():
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_do_reset)
	else:
		_do_reset()


func _do_reset() -> void:
	if unlink_hands:
		Hands.force_unlink()
	for c in get_children():
		if c is ResetPoint:
			c.apply()
	for path in parts:
		var n := get_node_or_null(path)
		if n and n.has_method("reset"):
			n.reset()
	reset_done.emit()
