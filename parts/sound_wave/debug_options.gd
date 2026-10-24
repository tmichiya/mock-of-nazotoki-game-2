class_name DebugOptions
extends Node
## 確認用の表示を、シーンを開いた時の初期状態として決める部品(実行中は F1 / F2 で切り替え)。

## 各マスに段の番号を表示する
@export var show_levels := false
## 音の波が届く範囲(道筋の終わり)を表示する
@export var show_wave_range := false


func _ready() -> void:
	World.debug_levels = show_levels
	World.debug_wave_range = show_wave_range
