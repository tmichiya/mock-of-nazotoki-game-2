class_name ClearTrigger
extends Node
## どんなシグナルからでも「○○をクリア」を知らせる部品。シーンのどこに置いてもよい。
## エディタで、知らせたいシグナルを fire() / fire_if_equals(値) / fire_if_true(真偽) につなぐ。
## 例: レバーの position_changed → fire_if_equals(match_value = 2)

## 知らせるクリアの名前
@export var clear_event: StringName = &""
## fire_if_equals で比べる値
@export var match_value := 0
## 一度知らせたら、取り消されるまで知らせない
@export var once := true

signal fired


func fire() -> void:
	if once and Clears.is_cleared(clear_event):
		return
	Clears.clear(clear_event)
	fired.emit()


func fire_if_equals(value) -> void:
	if int(value) == match_value:
		fire()


func fire_if_true(value: bool) -> void:
	if value:
		fire()


## クリアを取り消す(やり直しなどにつなぐ)
func reset() -> void:
	Clears.reset_clear(clear_event)
