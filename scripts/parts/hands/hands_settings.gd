class_name HandsSettings
extends Resource
## 手つなぎの調整値。res://resources/settings/hands_settings.tres を編集すると反映される。
## (HandLinkMonitor を置けば、そのインスペクタからも開ける)

@export_group("つなぐ")
## 二人とも腕を伸ばして握っていて、手の地面の位置どうしがこの距離(px)以内ならつながる
@export var link_distance := 8.0
## 肩どうしの距離が「二人の腕の長さの和」のこの倍で伸びきり、それ以上は離れない(宙づり・回転の半径にも使う)
@export var max_stretch := 1.3
## 腕の和を超えた時に引き合う強さ
@export var pull_strength := 12.0
## ポーズ中の人が引っ張られる割合(踏ん張る)
@export_range(0.0, 0.5) var pose_anchor_share := 0.15
## 同じ段とみなす高さの差(段)
@export var same_level_tolerance := 0.6

@export_group("片手:回転投げ")
## 腕の張りがこれ以上の時だけ回り始める(物を握っている時は回らない)
@export_range(0.0, 1.0) var spin_start_tension := 0.3
## 回る人のスティックの「円の向き」の成分で、回転がどれだけ速くなるか(ラジアン/秒²)
@export var spin_acceleration := 9.0
## 回転の最高速度(ラジアン/秒)
@export var spin_max_speed := 7.0
## 何もしないと回転が落ちる速さ(ラジアン/秒²)
@export var spin_friction := 3.0
## これより速く回っている時に手を離すと飛ぶ(ラジアン/秒)
@export var min_throw_speed := 2.5
## 最高速度で離した時に飛ぶ距離(px)
@export var throw_distance := 150.0
## 飛ぶ時の山なりの高さ(段)
@export var throw_arc_levels := 1.0

@export_group("両手:反動")
## 両手を離した時に、互いに飛ぶ距離(px)
@export var recoil_distance := 36.0
@export var recoil_arc_levels := 0.4
## 両手から片手、片手から離す、がこの時間内なら「両手を離した」とみなす(秒)
@export var recoil_window := 0.25

@export_group("段またぎ")
## つないだまま別の段にいられる最大の段差
@export var max_step_levels := 2
## 崖の縁を探す距離(px)
@export var edge_probe := 10.0
## 上の人が縁からこれ以上離れようとすると「引き上げ」になる(px)
@export var edge_margin := 12.0
## 引き上げの速さ(段/秒)
@export var pull_speed := 1.6
## 宙づりの振り子の重力(px/秒²)
@export var swing_gravity := 160.0
## 宙づりの人がスティックで揺らす力
@export var swing_push := 6.0
## 振り子が止まっていく速さ
@export var swing_damping := 0.6

@export_group("振動")
## 相手の重みがかかっている時の振動の強さ
@export_range(0.0, 1.0) var vibration_strength := 0.6
## 張りがこれ以上で振動する
@export_range(0.0, 1.0) var vibration_threshold := 0.2


static var _default: HandsSettings


static func get_default() -> HandsSettings:
	if _default == null:
		_default = load("res://resources/settings/hands_settings.tres")
	return _default
