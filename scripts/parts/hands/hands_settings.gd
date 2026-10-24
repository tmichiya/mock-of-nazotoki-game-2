class_name HandsSettings
extends Resource
## 手つなぎの調整値。res://resources/settings/hands_settings.tres を編集すると反映される。
## (HandLinkMonitor を置けば、そのインスペクタからも開ける)

@export_group("つなぐ")
## 二人の距離(体の中心どうし、px)がこれ以下で、二人とも手を伸ばしているとつながる
@export var link_distance := 26.0
## 腕が伸びきった時の二人の距離(px、段の高さも含めた立体の距離)
@export var max_distance := 30.0
## 同じ段とみなす高さの差(段)
@export var same_level_tolerance := 0.6

@export_group("片手:回転投げ")
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
@export_range(0.0, 1.0) var rumble_weak := 0.25
@export_range(0.0, 1.0) var rumble_strong := 0.45


static var _default: HandsSettings


static func get_default() -> HandsSettings:
	if _default == null:
		_default = load("res://resources/settings/hands_settings.tres")
	return _default
