@tool
class_name WavePushable
extends WaveReceiver
## 音の波に押される部品。軽い物(綿毛など)の子に置く。
## 親が RigidBody2D なら力を加え、apply_wave_push(力) を持つならそれを呼び、
## CharacterBody2D なら velocity に足す。

## 押す強さ(波の強さ1あたりの速さ px/秒)
@export var push_strength := 60.0

signal pushed(impulse: Vector2)


func receive(info: Dictionary) -> void:
	super.receive(info)
	if not Net.is_host():
		return
	var impulse: Vector2 = info.dir * info.strength * push_strength
	var p := get_parent()
	if p == null:
		return
	if p.has_method("apply_wave_push"):
		p.apply_wave_push(impulse)
	elif p is RigidBody2D:
		p.apply_central_impulse(impulse * p.mass)
	elif p is CharacterBody2D:
		p.velocity += impulse
	pushed.emit(impulse)
