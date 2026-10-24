extends SceneTree
## 地形用のパレット画像とタイルセットを作り直すスクリプト。段の色・模様は LevelStyle から取る。
## 実行: godot --headless --path . --script res://tools/make_terrain_tileset.gd
## (エディタの中では、Terrain のインスペクタの「パレットを段の見た目に合わせる」ボタンで同じことができる)


func _init() -> void:
	var cfg: WorldConfig = load("res://resources/settings/world_config.tres")
	var style: LevelStyle = load("res://resources/settings/level_style.tres")
	var err := TerrainPalette.save(cfg, style)
	print("palette saved err=", err)
	# タイルセットは無い時だけ作る(作り直すと、シーンからの参照の uid が変わるため)。
	# 作り直したい時は resources/terrain/terrain_tileset.tres を消してから実行する
	if not FileAccess.file_exists(TerrainPalette.TILESET_PATH) and ResourceLoader.exists(TerrainPalette.PNG_PATH):
		var tex: Texture2D = load(TerrainPalette.PNG_PATH)
		if tex:
			var tset := TerrainPalette.build_tileset(cfg, tex)
			err = ResourceSaver.save(tset, TerrainPalette.TILESET_PATH)
			print("tileset saved err=", err)
	quit()
