@tool
class_name OfferingPlace
extends PuzzlePart
## 捧げる場所。音のかけらが必要な数あると、上に立った時に捧げられる。
## 捧げると「歌の波」が島中に広がる(段のルールを無視して島全体に届く特別な波)。
## 歌の波には「何回目の捧げか」の段階が付き、IslandChangeReactor がその段階に応じて変化する。

signal offered(stage: int)
## かけらが足りない時に立った
signal not_enough(have: int, need: int)

## 1回の捧げに必要なかけらの数
@export var required := 3
## 上に立っているとみなす半径(px)
@export var radius := 14.0
## 二人とも上に立つ必要があるか
@export var need_both_players := false
## 何回まで捧げられるか(0 なら何回でも)
@export var max_offerings := 0
## 歌の波が届く距離(px)。島全体を覆う大きさにする
@export var song_reach := 3000.0
@export var song_shape: WaveShape = preload("res://resources/wave_shapes/song.tres")
@export var counter_key := "shards"
@export var offerings_key := "offerings"

var _was_on := false
var _cool := 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_authority():
		return
	_cool -= delta
	var n := 0
	for p: Player in World.get_players():
		if p.global_position.distance_to(global_position) <= radius and absf(p.height - height) < 0.6:
			n += 1
	var on := n >= (2 if need_both_players else 1)
	if on and not _was_on and _cool <= 0.0:
		try_offer()
	_was_on = on


## 捧げる(シグナルから直接呼んでもよい)
func try_offer() -> void:
	if not is_authority():
		return
	var have := int(World.get_shared(counter_key, 0))
	var done := int(World.get_shared(offerings_key, 0))
	if max_offerings > 0 and done >= max_offerings:
		return
	if have < required:
		not_enough.emit(have, required)
		return
	_cool = 1.0
	World.set_shared(counter_key, have - required)
	World.set_shared(offerings_key, done + 1)
	var stage := done + 1
	Waves.emit({
		origin = global_position, level = get_level(), size = 1.0, reach = song_reach,
		shape = song_shape.resource_path, source = "offering:" + str(name), global = true, stage = stage,
	})
	offered.emit(stage)
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var base := lift()
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(base + Vector2(cos(a) * radius, sin(a) * radius * 0.7))
	draw_colored_polygon(pts, Color(0.95, 0.9, 0.7, 0.5))
	pts.append(pts[0])
	draw_polyline(pts, Color("c9a35a"), 1.5)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, base + Vector2(-20, -4), "捧げる x%d" % required, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color.WHITE)
		return
	var have := int(World.get_shared(counter_key, 0))
	for i in range(required):
		var c := base + Vector2(-(required - 1) * 4.0 + i * 8.0, -4)
		draw_circle(c, 2.2, Color("9be0ff") if i < have else Color(1, 1, 1, 0.25))
