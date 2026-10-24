class_name Layers
## 物理レイヤーの割り当て(2D)。
## 地形の壁は「上端の段」ごとに別のレイヤーに置く。歩いている時は全部の壁に当たり、
## 滑空中は「今の高さより上端が高い壁」だけに当たる、という切り替えをマスクで行う。

const MAX_WALL_LEVEL := 15          ## 壁の上端として扱える最大の段(0〜15 → レイヤー1〜16)
const VOID_LAYER := 17              ## 島の外周(空のマス)との境目。常に壁
const OBJECT_LAYER := 18            ## 扉などの置き物(固い物)
const PLAYER_LAYER := 19            ## プレイヤー
const PROP_LAYER := 20              ## 綿毛・棒など動く軽い物


static func bit(layer: int) -> int:
	return 1 << (layer - 1)


## 上端の段 top の壁が置かれるレイヤー番号(1始まり)
static func wall_layer_for_top(top: int) -> int:
	return clampi(top, 0, MAX_WALL_LEVEL) + 1


## 歩いている時のマスク(全部の壁+置き物)
static func walker_mask() -> int:
	var m := bit(VOID_LAYER) | bit(OBJECT_LAYER)
	for t in range(0, MAX_WALL_LEVEL + 1):
		m |= bit(wall_layer_for_top(t))
	return m


## 高さ h(段)で宙にいる時のマスク。上端が h より高い壁だけに当たる
static func airborne_mask(h: float) -> int:
	var m := bit(VOID_LAYER) | bit(OBJECT_LAYER)
	for t in range(0, MAX_WALL_LEVEL + 1):
		if float(t) > h + 0.01:
			m |= bit(wall_layer_for_top(t))
	return m
