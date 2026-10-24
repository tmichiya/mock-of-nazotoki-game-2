class_name OnlyVisibleTo
extends Node
## 親の物を「片方のプレイヤーの画面にだけ」見せる部品。見せたい物の子に置く。
## 1台で2人の時は1人目の画面として扱う(F3 で「誰の目で見るか」を切り替えて確かめられる)。

enum Who { BOTH, PLAYER_1, PLAYER_2, ONLY_WHEN_HANDS_LINKED, NEVER }

## 誰の画面に見せるか(ONLY_WHEN_HANDS_LINKED は手をつないでいる間だけ二人に見える)
@export var visible_to := Who.PLAYER_1
## 見えない人には当たり判定も無くす(見えない壁を作らないため)
@export var hide_collision := false

var _last := true


func _process(_delta: float) -> void:
	var p := get_parent() as CanvasItem
	if p == null:
		return
	var v := should_show()
	if v != _last:
		_last = v
		p.visible = v
		if hide_collision:
			_set_collision(p, v)


func should_show() -> bool:
	match visible_to:
		Who.BOTH:
			return true
		Who.PLAYER_1:
			return World.get_viewer_index() == 1
		Who.PLAYER_2:
			return World.get_viewer_index() == 2
		Who.ONLY_WHEN_HANDS_LINKED:
			return Hands.is_linked()
	return false


func _set_collision(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", not on)
		_set_collision(c, on)
