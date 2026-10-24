extends TestSceneBase
## 通信とゲーム内VCの確認用シーン(G の完了条件)。
## 2つ起動して、片方「ホストする」、もう片方「参加する」。
## 確かめること:
##  ・相手の動き・腕のポーズ・手つなぎがすぐ見える
##  ・遠いと声が遅れて届く(波が届いた時に聞こえる)。近い(near_distance 以内)とすぐ届く
##  ・段が違うと届かない。段をまたいで手をつないでいる間は届く
## 右上の表示: 最後に聞こえた声の遅れ(秒)と「すぐ/波で」

var _last := ""


func _ready() -> void:
	super._ready()
	Voice.voice_played.connect(_on_played)
	set_status("通信: %s" % ("ホスト" if Net.is_host() else "参加"))


func _on_played(source: String, delay: float, immediate: bool) -> void:
	var line := "[NET %s] voice from %s delay=%.2fs %s" % ["host" if Net.is_host() else "client", source, delay, "IMMEDIATE" if immediate else "by-wave"]
	for p in World.get_players():
		line += " P%d(%.0f,%.0f h%.1f)" % [p.player_index, p.global_position.x, p.global_position.y, p.height]
	print(line)
	_last = line
	set_status(line)


func _steps() -> Array:
	return [
		{ t = 1.0, log = "both present" },
		{ t = 0.6, p1 = { pose = true, arm_l = Vector2(-1, -1), arm_r = Vector2(1, -1) }, p2 = { pose = true, arm_l = Vector2(0, 1), arm_r = Vector2(1, 0) } },
		{ t = 0.2, log = "poses (P1 arms 5,7 / P2 arms 2,0 on both screens)", p1 = { pose = true, arm_l = Vector2(-1, -1), arm_r = Vector2(1, -1) }, p2 = { pose = true, arm_l = Vector2(0, 1), arm_r = Vector2(1, 0) } },
		{ t = 0.3, call = "speak_on", log = "P1 speaks far (~224px): expect by-wave delay ~1.3s" },
		{ t = 0.1, call = "speak_off" },
		{ t = 2.2 },
		{ t = 2.6, p1 = { move = Vector2.RIGHT } },
		{ t = 0.3, call = "speak_on", log = "P1 speaks near: expect IMMEDIATE" },
		{ t = 0.1, call = "speak_off" },
		{ t = 1.5, call = "p2_to_plateau" },
		{ t = 0.3, call = "speak_on", log = "P2 on level 1, P1 on level 0: expect nothing" },
		{ t = 0.1, call = "speak_off" },
		{ t = 2.0, call = "both_on_plateau_edge" },
		{ t = 0.5, p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.8, p1 = { grab_r = true, move = Vector2.LEFT }, p2 = { grab_l = true } },
		{ t = 0.3, call = "speak_on", log = "linked across levels (P1 below): expect heard", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.1, call = "speak_off", p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 1.0, p1 = { grab_r = true }, p2 = { grab_l = true } },
		{ t = 0.5, p1 = { move = Vector2.LEFT }, log = "released" },
		{ t = 0.3, call = "speak_on", log = "not linked, different levels: expect nothing" },
		{ t = 0.1, call = "speak_off" },
		{ t = 2.0, log = "done" },
	]


func speak_on() -> void:
	if Net.is_host():
		Voice.settings.test_tone_hz = 220.0
		Voice.settings.test_tone_volume = 0.25


func speak_off() -> void:
	Voice.settings.test_tone_hz = 0.0001
	Voice.settings.test_tone_volume = 0.0


func _place_local(index: int, pos: Vector2) -> void:
	var p := World.get_player_by_index(index) as Player
	if p and p.is_local:
		p.global_position = pos
		p.height = World.height_at(pos)
		p.velocity = Vector2.ZERO


func p2_to_plateau() -> void:
	_place_local(2, Vector2(15.5 * 32, 7.5 * 24))


func both_on_plateau_edge() -> void:
	_place_local(1, Vector2(14 * 32 + 8, 7.5 * 24))
	_place_local(2, Vector2(14 * 32 + 30, 7.5 * 24))
