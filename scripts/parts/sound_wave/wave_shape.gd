class_name WaveShape
extends Resource
## 音の波の「形」。音の種類ごとに .tres を作る(resources/wave_shapes/ にある物を複製して増やせる)。

## 種類の名前(受け取り側で「この種類だけ反応する」に使う。例: voice, impact, bird, song)
@export var kind: StringName = &"generic"
## 輪の数
@export_range(1, 6) var rings := 1
## 輪と輪の間隔(px)
@export var ring_spacing := 6.0
## ギザギザの大きさ(px)。0 でなめらか
@export var zigzag := 0.0
## ギザギザの細かさ(px。小さいほど細かい)
@export var zigzag_length := 6.0
## 線の太さ
@export var line_width := 1.5
## 広がる速さ(px/秒)
@export var speed := 160.0
## 大きさ1の時の寿命(秒)。届く距離 = 速さ × 寿命 × 大きさ
@export var lifetime := 1.2
## 色(音源が色を指定しない時に使う)
@export var color := Color(1, 1, 1, 0.9)
## 光線の本数(多いほど細かく正確だが重い)
@export_range(32, 512) var ray_count := 160
## 跳ね返る回数の上限
@export_range(0, 8) var max_bounces := 3
