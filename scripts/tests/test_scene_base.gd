class_name TestSceneBase
extends Node2D
## 確認用シーンの共通部分。画面の左上に「確かめること」と操作を表示する。
## 子の Autopilot に台本(_steps)を渡す(起動引数 --autopilot の時だけ動く)。

## 画面に出す説明
@export_multiline var help_text := ""

const COMMON_HELP := "移動 WASD/左スティック  走る(切替) Ctrl/Y  ポーズ Shift/LT・RT  腕 移動キー+IJKL/両スティック(伸ばすと自動でつかむ)  挙げる Z,C/L3,R3  離す X/B  滑空 Space/A
2人目: 矢印  走る テンキー0  ポーズ /  腕 矢印+テンキー8456  挙げる テンキー7,9  離す テンキー.  滑空 Enter    F1 段番号  F2 波の範囲  F4 マイク"

var _label: Label


func _ready() -> void:
	y_sort_enabled = true
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.text = _help() + "\n" + COMMON_HELP
	layer.add_child(_label)
	var ap := get_node_or_null("Autopilot") as Autopilot
	if ap:
		ap.steps = _steps()


func _steps() -> Array:
	return []


## 画面に出す説明(派生のスクリプトで決める。無ければ help_text)
func _help() -> String:
	return help_text


func set_status(text: String) -> void:
	_label.text = _help() + "\n" + COMMON_HELP + "\n" + text


var _sig_log: Array = []


## 子の部品のシグナルを画面とログに出す(確認用)
func watch(node_path: String, signals: Array) -> void:
	var n := get_node_or_null(node_path)
	if n == null:
		push_warning("watch: %s が見つかりません" % node_path)
		return
	for sname in signals:
		var argc := 0
		for info in n.get_signal_list():
			if info.name == sname:
				argc = info.args.size()
		var cb: Callable
		match argc:
			0: cb = func(): _sig(node_path, sname, [])
			1: cb = func(a): _sig(node_path, sname, [a])
			2: cb = func(a, b): _sig(node_path, sname, [a, b])
			_: cb = func(a, b, c): _sig(node_path, sname, [a, b, c])
		n.connect(sname, cb)


func _sig(node_path: String, sname: String, args: Array) -> void:
	var line := "[SIG] %s.%s(%s)" % [node_path, sname, ", ".join(args.map(func(x): return str(x)))]
	print(line)
	_sig_log.append(line)
	if _sig_log.size() > 8:
		_sig_log.pop_front()
	set_status("\n".join(_sig_log))


## プレイヤーを地面の位置 pos へ置く(この端末で動かしている人だけ)
func place(index: int, pos: Vector2) -> void:
	var p := World.get_player_by_index(index) as Player
	if p == null or not p.is_local:
		return
	p.release_all()
	p.link_controlled = false
	p.state = Player.State.WALK
	p.velocity = Vector2.ZERO
	p.global_position = pos
	p.height = World.height_at(pos)


static func cell(c: Vector2) -> Vector2:
	return (c + Vector2(0.5, 0.5)) * Vector2(32, 24)
