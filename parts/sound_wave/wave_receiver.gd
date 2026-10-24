@tool
class_name WaveReceiver
extends Node2D
## 音の波を受け取る部品。物の子として置くと、その物に波が届いた時にシグナルが出る。
## 届くのは「受け手の段」と「波の段」が同じ時だけ(斜面の上は最も近い段)。歌の波は段に関係なく届く。

## 波が届いた(どの音源から・どの強さで・いつ(共通の時刻、秒))
signal wave_received(source_id: String, strength: float, time: float)
## 波が届いた(引数なし。扉の open() などにそのままつなぐ用)
signal received
## 波が届いた(詳しい情報。kind, dir, pitch, payload, wave_id, bounce など)
signal wave_received_info(info: Dictionary)
## 別々の音源の波が、許容時間内に同時に届いた
signal waves_overlapped(source_a: String, source_b: String, time: float)
## 同上(引数なし)
signal overlapped

enum LevelMode { AUTO, FIXED }

## 受け取る範囲の半径(px)
@export var radius := 8.0:
	set(v):
		radius = v
		queue_redraw()
## AUTO = 親の高さ(height を持つ物)か足元の地形から段を決める / FIXED = fixed_level の段
@export var level_mode := LevelMode.AUTO
@export var fixed_level := 0
## 反応する波の種類(空なら全部)。例: voice, impact, bird
@export var accept_kinds: Array[StringName] = []
## この強さ未満の波は無視する
@export var min_strength := 0.0
## 「同時に届いた」とみなす時間の幅(秒)
@export var overlap_window := 0.15
## 同じ音源の波どうしの重なり(直接と反射など)も数えるか
@export var overlap_same_source := false
## この名前の音源は無視する(自分の声など)
@export var ignore_source := ""
## 受け取りを止める
@export var listening := true
## エディタで範囲を表示する
@export var show_in_editor := true

var _recent: Array = []   # [source, time]


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group("wave_receiver")


func is_listening() -> bool:
	return listening and is_inside_tree()


func get_level() -> int:
	if level_mode == LevelMode.FIXED:
		return fixed_level
	var p := get_parent()
	if p and "height" in p:
		return roundi(p.height)
	return World.level_at(global_position)


func accepts(p: Dictionary) -> bool:
	if ignore_source != "" and str(p.source) == ignore_source:
		return false
	if accept_kinds.is_empty():
		return true
	var shape_kind: StringName = Waves._load_shape(p.shape).kind
	return shape_kind in accept_kinds


func receive(info: Dictionary) -> void:
	if info.strength < min_strength:
		return
	wave_received.emit(str(info.source), info.strength, info.time)
	received.emit()
	wave_received_info.emit(info)
	var p := get_parent()
	if p and p.has_method("on_wave_received"):
		p.on_wave_received(str(info.source), info.strength, info.time)
	# 重なりの判定
	var now: float = info.get("local_time", info.time)
	_recent = _recent.filter(func(e): return now - e[1] <= overlap_window)
	for e in _recent:
		if e[0] != str(info.source) or overlap_same_source:
			waves_overlapped.emit(e[0], str(info.source), info.time)
			overlapped.emit()
			break
	_recent.append([str(info.source), now])


func _draw() -> void:
	if Engine.is_editor_hint() and show_in_editor:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(0.5, 0.9, 1, 0.6), 1.0)
