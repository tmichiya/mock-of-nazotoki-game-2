class_name ClearListener
extends Node
## 「○○をクリア」を購読して、エディタでつなげるシグナルとして出す部品。シーンのどこに置いてもよい。
## listen に名前を並べ、mode で「全部そろったら」か「どれか1つで」を選ぶ。

## 購読するクリアの名前
@export var listen: Array[StringName] = []
enum Mode { ALL, ANY }
## ALL = 全部クリアしたら / ANY = どれか1つクリアしたら
@export var mode := Mode.ALL

## 条件がそろった(シーンを開いた時にすでにそろっていても出す)
signal activated
## 条件がくずれた(取り消された)
signal deactivated
## 購読している名前のどれかがクリアされた
signal any_cleared(name: StringName)

var active := false


func _ready() -> void:
	Clears.cleared.connect(_on_change)
	Clears.reset.connect(_on_change)
	_evaluate.call_deferred()


func _on_change(name: StringName) -> void:
	if name in listen:
		if Clears.is_cleared(name):
			any_cleared.emit(name)
		_evaluate()


func is_satisfied() -> bool:
	if listen.is_empty():
		return false
	var n := Clears.count_cleared(listen)
	return n == listen.size() if mode == Mode.ALL else n > 0


func _evaluate() -> void:
	var now := is_satisfied()
	if now == active:
		return
	active = now
	if now:
		activated.emit()
	else:
		deactivated.emit()
