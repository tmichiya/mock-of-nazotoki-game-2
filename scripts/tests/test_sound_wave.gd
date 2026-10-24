extends TestSceneBase
## 音の波の確認用シーン(E の完了条件)。
## E0(0段)… 西の受け手 Rwest に直接届き、1段の台地の崖で跳ね返ってもう一度届く。台地の向こう(Rgap)には届かない
## E1(1段の台地の上)… 南の Rsouth(1段)に届く。2段の塊の後ろ(Rbehind)には届かない。
##                     間の0段の上を通り過ぎて、東の台地の Reast(1段)に届く。真下の0段の Rgap には届かない
## EA・EB … 同時に鳴らすと Roverlap で「重なり」。ずらすと重ならない
## 楕円 … 片方の焦点で鳴らすと、壁で跳ね返った波がもう一方の焦点 Rfocus に集まる
## 綿毛 … 波に押されて流れる
## Enter/Space でも試せる: 1〜6 キーで各音源を鳴らす

var _log: Array = []


func _ready() -> void:
	super._ready()
	for r in get_tree().get_nodes_in_group("wave_receiver"):
		if r.get_parent() == self:
			r.wave_received_info.connect(_on_received.bind(r.name))
			r.waves_overlapped.connect(_on_overlap.bind(r.name))


func _on_received(info: Dictionary, rname: String) -> void:
	var line := "[RECV] %s <- %s strength=%.2f bounce=%d dist=%.0f" % [rname, info.source, info.strength, info.bounce, info.distance]
	print(line)
	_push(line)


func _on_overlap(a: String, b: String, _t: float, rname: String) -> void:
	var line := "[OVERLAP] %s: %s + %s" % [rname, a, b]
	print(line)
	_push(line)


func _push(line: String) -> void:
	_log.append(line)
	if _log.size() > 8:
		_log.pop_front()
	set_status("\n".join(_log))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: emit_e0()
			KEY_2: emit_e1()
			KEY_3: emit_both()
			KEY_4: emit_staggered()
			KEY_5: emit_focus()
			KEY_6: emit_fluff()


func emit_e0() -> void:
	$E0.emit()


func emit_e1() -> void:
	$E1.emit()


func emit_both() -> void:
	$EA.emit()
	$EB.emit()


func emit_staggered() -> void:
	$EA.emit()
	get_tree().create_timer(0.5).timeout.connect($EB.emit)


func emit_focus() -> void:
	$EFocus.emit()


func emit_fluff() -> void:
	$EFluff.emit()


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 2.5, call = "emit_e0", log = "E0 (level0): expect Rwest bounce0 then bounce1, nothing at Rgap" },
		{ t = 2.5, call = "emit_e1", log = "E1 (level1): expect Rsouth, Reast; not Rbehind, not Rgap" },
		{ t = 2.0, call = "emit_both", log = "EA+EB together: expect OVERLAP at Roverlap" },
		{ t = 2.0, call = "emit_staggered", log = "EA then EB 0.5s later: expect no overlap" },
		{ t = 2.5, call = "emit_focus", log = "ellipse focus: expect Rfocus bounce0 and bounce1" },
		{ t = 0.1, call = "mark_fluff" },
		{ t = 2.0, call = "emit_fluff", log = "push fluff" },
		{ t = 0.1, call = "report_fluff" },
	]


var _fluff_start := Vector2.ZERO


func mark_fluff() -> void:
	_fluff_start = $Fluff.global_position


func report_fluff() -> void:
	print("[AUTO] fluff moved %.0f px" % $Fluff.global_position.distance_to(_fluff_start))


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【音の波】1:E0(0段) 2:E1(1段) 3:EA+EB同時 4:ずらす 5:楕円の焦点 6:綿毛を押す  ※受け取りと重なりは画面とログに出る"
