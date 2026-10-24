class_name SwitchGroup
extends Node
## 複数の踏むスイッチの「同時押し」や「組み合わせ」を判定する役。スイッチを switches に登録する。
## ・pattern が空:登録した全部が同時にオンになったら solved
## ・pattern あり:オンになっている数が pattern の true の数に達した時、組み合わせが合えば solved、違えば wrong
##   (組み合わせの答えはインスペクタで決める。部品自体は答えを持たない)

signal solved
signal wrong
## 今オンの数
signal count_changed(on_count: int)
## 全部オフに戻った(solved の後、次の判定に備えた時)
signal cleared

## クリアした時に知らせる「○○をクリア」の名前(空なら知らせない)
@export var clear_event: StringName = &""
## 判定するスイッチ(FloorSwitch など、is_on と state_changed を持つ物)
@export var switches: Array[NodePath] = []
## 正しい組み合わせ(switches と同じ順に、オンであるべきなら true)。空なら「全部オン」
@export var pattern: Array[bool] = []
## 少しずれて押しても同時とみなす時間(秒)。0 なら本当に同時にオンの時だけ
@export var window := 0.0
## wrong の時、latch のスイッチを全部戻す
@export var reset_on_wrong := true

var _last_on_time := {}
var _done := false
var _wait_clear := false   # 間違えた後は、一度全部オフになるまで判定しない


func _ready() -> void:
	for path in switches:
		var s := get_node_or_null(path)
		if s and s.has_signal("state_changed"):
			s.state_changed.connect(_on_changed.bind(s))


func _switch_nodes() -> Array:
	var out := []
	for path in switches:
		out.append(get_node_or_null(path))
	return out


func _effective_on(s: Node) -> bool:
	if s == null:
		return false
	if s.is_on:
		return true
	if window > 0.0 and _last_on_time.has(s):
		return Waves.clock - _last_on_time[s] <= window
	return false


func _on_changed(on: bool, s: Node) -> void:
	if not Net.is_host():
		return
	if on:
		_last_on_time[s] = Waves.clock
	var nodes := _switch_nodes()
	var states := nodes.map(func(n): return _effective_on(n))
	var count := states.count(true)
	count_changed.emit(count)
	if count == 0:
		_wait_clear = false
		if _done:
			_done = false
			cleared.emit()
		return
	if _done or _wait_clear:
		return
	if pattern.is_empty():
		if count == nodes.size():
			_done = true
			solved.emit()
			Clears.clear(clear_event)
		return
	var need := pattern.count(true)
	if count < need:
		return
	var ok := true
	for i in range(nodes.size()):
		var want: bool = pattern[i] if i < pattern.size() else false
		if states[i] != want:
			ok = false
	if ok:
		_done = true
		solved.emit()
		Clears.clear(clear_event)
	else:
		wrong.emit()
		_wait_clear = true


# 間違えた後:全員がスイッチから降りたら、押したままのスイッチを戻して次の判定を始める
func _process(_delta: float) -> void:
	if not _wait_clear or not Net.is_host():
		return
	for n in _switch_nodes():
		if n and n.has_method("count_on_top") and n.count_on_top() > 0:
			return
	if reset_on_wrong:
		reset_switches()
	_wait_clear = false


## 押したままのスイッチを全部戻す
func reset_switches() -> void:
	for n in _switch_nodes():
		if n and n.has_method("reset"):
			n.reset()
	_last_on_time.clear()
	_done = false
	_wait_clear = false
