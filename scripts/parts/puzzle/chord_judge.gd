class_name ChordJudge
extends Node
## 和音の判定役。登録した鳥(SingingBird)の鳴き声が、許容時間内に指定の組み合わせ(和音)になったら成功。
## 和音の答えはインスペクタで決める(部品自体は答えを持たない)。

signal chord_completed
## 揃った音の数が変わった
signal progress_changed(matched: int, needed: int)

## クリアした時に知らせる「○○をクリア」の名前(空なら知らせない)
@export var clear_event: StringName = &""
## 判定する鳥
@export var birds: Array[NodePath] = []
## そろえる音(MIDI の音番号)
@export var chord := PackedFloat32Array([60, 64, 67])
## この時間(秒)の間に鳴いた音をまとめて和音とみなす
@export var window := 1.5
## オクターブ違いも同じ音とみなす
@export var octave_free := true
## 余計な音が混ざっていたら成功にしない
@export var exact := false
## 一度成功したら、reset() まで判定しない
@export var once := true

var _recent: Array = []   # [音, 時刻]
var _done := false


func _ready() -> void:
	for path in birds:
		var b := get_node_or_null(path)
		if b and b.has_signal("sang"):
			b.sang.connect(_on_sang)


func _key(m: float) -> float:
	return fposmod(roundf(m), 12.0) if octave_free else roundf(m)


func _on_sang(midi: float) -> void:
	if not Net.is_host() or (_done and once):
		return
	var now := Waves.clock
	_recent = _recent.filter(func(e): return now - e[1] <= window)
	_recent.append([_key(midi), now])
	var heard := {}
	for e in _recent:
		heard[e[0]] = true
	var needed := {}
	for c in chord:
		needed[_key(c)] = true
	var matched := 0
	for k in needed.keys():
		if heard.has(k):
			matched += 1
	progress_changed.emit(matched, needed.size())
	if matched == needed.size():
		if exact and heard.size() > needed.size():
			return
		_done = true
		_recent.clear()
		chord_completed.emit()
		Clears.clear(clear_event)


func reset() -> void:
	_done = false
	_recent.clear()
