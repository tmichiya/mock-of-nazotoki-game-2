extends TestSceneBase
## 地形とプレイヤーの確認用シーン(A・B の完了条件)。
## 3段(0・1・2段)と斜面2本(0→1段の手前の斜面、1→2段の右の斜面)。
## 確かめること: 斜面で上り下りできる / 段差は上からも下からも壁 / 高い段の後ろに入ると隠れて輪郭が出る /
##               崖の縁で滑空でき、着地点が影の位置と一致する


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.6, p = 2, move = Vector2.DOWN, call = "toggle_levels" },
		{ t = 0.3, log = "P2 pushed against plateau from behind (outline expected)" },
		{ t = 1.35, move = Vector2.RIGHT },
		{ t = 1.1, move = Vector2.UP, log = "at slope foot (h=0 expected)" },
		{ t = 0.1, log = "after slope up (h=1 expected)" },
		{ t = 0.9, move = Vector2.UP },
		{ t = 0.1, log = "pushed into 2-level wall from below (y~149, h=1)" },
		{ t = 2.25, move = Vector2.RIGHT },
		{ t = 0.6, move = Vector2.UP },
		{ t = 1.6, move = Vector2.LEFT, log = "at east of slope2" },
		{ t = 0.1, log = "on level 2 via slope2 (h=2 expected)" },
		{ t = 0.6, move = Vector2.DOWN },
		{ t = 0.1, log = "pushed into south cliff from above (y~139, h=2)" },
		{ t = 0.05, move = Vector2.DOWN, glide = true, log = "glide start" },
		{ t = 0.4, move = Vector2.ZERO },
		{ t = 0.1, log = "mid glide (state=2)" },
		{ t = 1.0 },
		{ t = 0.1, log = "landed (h == ground)" },
		{ t = 1.6, move = Vector2.LEFT },
		{ t = 0.1, log = "walked west on level1" },
		{ t = 0.5 },
	]


func toggle_levels() -> void:
	World.debug_levels = not World.debug_levels


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【地形・プレイヤー】斜面で上り下り / 段差は上からも下からも壁 / 高い段の後ろで輪郭 / 崖の縁で滑空し、影の位置に着地"
