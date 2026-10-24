extends TestSceneBase
## 腕のポーズの読み分けの確認用シーン。同じ距離に人形を並べ、6種類のポーズを取らせる。
## 左から:横・真上・斜め上・手前・奥・下ろす(どれも両腕)。
## 1人目・2人目は下の段で自由に動かして、自分でもポーズを試せる。
## 腕の描き方の数値は Player のインスペクタ「腕の描き方」で調整する(人形にも同じ数値が使われる)。

const POSES := [
	["横", { pose = true, arm_l = Vector2(-1, 0), arm_r = Vector2(1, 0) }],
	["真上", { pose = true, raise_l = true, raise_r = true }],
	["斜め上", { pose = true, raise_l = true, raise_r = true, arm_l = Vector2(-1, 0), arm_r = Vector2(1, 0) }],
	["手前", { pose = true, arm_l = Vector2(0, 1), arm_r = Vector2(0, 1) }],
	["奥", { pose = true, arm_l = Vector2(0, -1), arm_r = Vector2(0, -1) }],
	["下ろす", { pose = true }],
]

var _dummies: Array = []


func _ready() -> void:
	super._ready()
	var scene: PackedScene = load("res://scenes/parts/player/player.tscn")
	for i in range(POSES.size()):
		var p: Player = scene.instantiate()
		p.name = "Pose_%d" % i
		p.player_index = 10 + i
		p.is_local = true
		p.keyboard = PlayerInput.Keyboard.NONE
		p.joy_device = -1
		p.body_color = Color.from_hsv(0.08 + i * 0.13, 0.55, 0.85)
		p.position = cell(Vector2(3 + i * 2, 4))
		add_child(p)
		_dummies.append(p)
		var l := WorldLabel.new()
		l.text = POSES[i][0]
		l.position = p.position + Vector2(-8, 22)
		add_child(l)


func _physics_process(_delta: float) -> void:
	for i in range(_dummies.size()):
		var st := PlayerInput.empty_state()
		for k in POSES[i][1].keys():
			st[k] = POSES[i][1][k]
		_dummies[i].input_override = st


func _steps() -> Array:
	return [{ t = 1.0, log = "6 poses" }]
