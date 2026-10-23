class_name Autopilot
extends Node
## 確認用の台本。プレイヤーの入力を順番に上書きして動かし、ログを出す。
## 普段は止まっている(enabled = false)。起動引数 --autopilot で動く。
##
## 台本の1段: { t = 秒, log = "見出し", call = "親のメソッド名",
##              p1 = { move = Vector2, pose = bool, arm_l = Vector2, arm_r = Vector2,
##                     grab_l = bool, grab_r = bool, glide = bool, orbit = 1/-1 }, p2 = { … } }
## 省略形: { p = 1, move = …, glide = … }(1人分だけ指定)
## orbit … 相手の周りを回る向きに毎フレーム入力する(回転投げの確認用)

@export var enabled := false
## 台本が終わったらゲームを終了する
@export var quit_when_done := true
var steps: Array = []

var _i := -1
var _left := 0.0
var _started := false
var _cur := {}


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
	_apply_dynamic()
	_left -= delta
	if _left <= 0.0:
		_next()


func _next() -> void:
	_i += 1
	for p in World.get_players():
		p.input_override = PlayerInput.empty_state()
	_cur = {}
	if _i >= steps.size():
		report("END")
		enabled = false
		if quit_when_done:
			get_tree().quit()
		return
	var s: Dictionary = steps[_i]
	_left = s.get("t", 0.0)
	if s.has("call"):
		get_parent().call(s.call)
	if s.has("log"):
		report(s.log)
	if s.has("p"):
		_cur[s.p] = s
	if s.has("p1"):
		_cur[1] = s.p1
	if s.has("p2"):
		_cur[2] = s.p2
	_apply_dynamic()


func _apply_dynamic() -> void:
	for idx in _cur.keys():
		var p := World.get_player_by_index(idx)
		if p == null:
			continue
		var src: Dictionary = _cur[idx]
		var st := PlayerInput.empty_state()
		for k in st.keys():
			if src.has(k):
				st[k] = src[k]
		if src.has("orbit"):
			var q := World.get_partner(p)
			if q:
				var rel: Vector2 = (p.global_position - q.global_position).normalized()
				st.move = rel.orthogonal() * float(src.orbit)
		p.input_override = st


func report(label: String) -> void:
	var line := "[AUTO] %s" % label
	for p in World.get_players():
		line += " | P%d pos=(%.0f,%.0f) h=%.2f ground=%.2f st=%d arms=%d,%d" % [p.player_index, p.global_position.x, p.global_position.y, p.height, World.height_at(p.global_position), p.state, p.arm_left, p.arm_right]
	if Hands.is_linked():
		line += " | linked=%d" % Hands.get_link_type()
		if Hands.is_spinning():
			line += " spin=%.2f" % Hands._spin.omega
		if Hands.is_cross_level():
			line += " cross=%s" % Hands._cross.mode
	print(line)
