class_name Autopilot
extends Node
## 確認用の台本。プレイヤーの入力を順番に上書きして動かし、ログを出す。
## 普段は止まっている(enabled = false)。起動引数 --autopilot で動く。

## 台本: [{ t = 秒, p = プレイヤー番号, move = Vector2, glide = bool, pose = bool,
##          arm_l = Vector2, arm_r = Vector2, grab_l = bool, grab_r = bool, log = "見出し", call = "メソッド名" }]
@export var enabled := false
## 台本が終わったらゲームを終了する
@export var quit_when_done := true
var steps: Array = []

var _i := -1
var _left := 0.0
var _started := false


func _ready() -> void:
	if "--autopilot" in OS.get_cmdline_user_args() or "--autopilot" in OS.get_cmdline_args():
		enabled = true


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if not _started:
		if World.get_players().size() < 1:
			return
		_started = true
		_next()
		return
	_left -= delta
	if _left <= 0.0:
		_next()


func _next() -> void:
	_i += 1
	for p in World.get_players():
		p.input_override = PlayerInput.empty_state()
	if _i >= steps.size():
		report("END")
		enabled = false
		if quit_when_done:
			get_tree().quit()
		return
	var s: Dictionary = steps[_i]
	_left = s.get("t", 0.0)
	if s.has("log"):
		report(s.log)
	if s.has("call"):
		get_parent().call(s.call)
	var p := World.get_player_by_index(s.get("p", 1))
	if p == null:
		return
	var st := PlayerInput.empty_state()
	for k in st.keys():
		if s.has(k):
			st[k] = s[k]
	p.input_override = st
	# 他の人も止めたままにしない時は別の段で指定する
	if s.has("p2"):
		var q := World.get_player_by_index(2)
		if q:
			var st2 := PlayerInput.empty_state()
			for k in st2.keys():
				if s.p2.has(k):
					st2[k] = s.p2[k]
			q.input_override = st2


func report(label: String) -> void:
	var line := "[AUTO] %s" % label
	for p in World.get_players():
		line += " | P%d pos=(%.0f,%.0f) h=%.2f ground=%.2f state=%d" % [p.player_index, p.global_position.x, p.global_position.y, p.height, World.height_at(p.global_position), p.state]
	if Hands.is_linked():
		line += " | linked=%d" % Hands.get_link_type()
	print(line)
