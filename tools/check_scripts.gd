extends Node
## すべてのスクリプトとシーンを読み込んで、エラーがないか確かめる(確認用)。
## 実行: godot --headless --path . res://tools/check_scripts.tscn


func _ready() -> void:
	var files := []
	_collect("res://", files)
	var bad := 0
	for f in files:
		var r = load(f)
		if r == null:
			print("FAILED: ", f)
			bad += 1
		elif r is GDScript and not r.can_instantiate() and not f.ends_with("_settings.gd"):
			pass
		elif r is PackedScene:
			var n = r.instantiate()
			if n == null:
				print("FAILED to instantiate: ", f)
				bad += 1
			else:
				n.free()
	print("checked %d files, %d failed" % [files.size(), bad])
	get_tree().quit()


func _collect(dir: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or (f.ends_with(".tscn") and not f.begins_with("build_") and not f.begins_with("check_")):
			out.append(dir.path_join(f))
