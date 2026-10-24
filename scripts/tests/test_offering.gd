extends TestSceneBase
## 音のかけらと捧げる場所(N)、島の変化に反応する物(H)の確認用シーン。
## ・かけらを3つ拾って捧げる場所に立つと、歌の波が島中に広がる(1回目)
## ・歌の波が届いた順に、段階1の物が「現れる」「消える」「落ちる」「動く」
## ・最初は隠れているかけら(Hidden)は、スイッチを踏むと現れる(appear をつないである)


func _ready() -> void:
	super._ready()
	watch("Offering", ["offered", "not_enough"])
	for n in ["Appear1", "Disappear1", "Fall1", "Move1", "Appear2"]:
		watch(n, ["changed"])
	watch("Hidden", ["appeared", "collected"])
	World.shared_changed.connect(func(k, v): print("[AUTO] shared %s = %s" % [k, v]))


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.2, call = "go_offer", log = "no shards: expect not_enough" },
		{ t = 0.2, call = "pick1" },
		{ t = 0.2, call = "pick2" },
		{ t = 0.2, call = "press_switch" },
		{ t = 0.3, call = "pick_hidden" },
		{ t = 0.2, call = "go_away" },
		{ t = 0.2, call = "go_offer", log = "3 shards: expect offered(1), song wave" },
		{ t = 4.0 },
		{ t = 0.1, call = "report", log = "stage-1 reactors changed, stage-2 not" },
	]


func go_offer() -> void:
	place(1, $Offering.global_position)


func go_away() -> void:
	place(1, cell(Vector2(3, 11)))
	place(2, cell(Vector2(4, 11)))


func pick1() -> void:
	place(1, $Shard1.global_position)


func pick2() -> void:
	place(1, $Shard2.global_position)


func press_switch() -> void:
	place(2, $Switch.global_position)


func pick_hidden() -> void:
	place(1, $Hidden.global_position)


func report() -> void:
	print("[AUTO] shards=%s offerings=%s appear1.visible=%s disappear1.visible=%s move1=(%.0f,%.0f) appear2.visible=%s" % [
		World.get_shared("shards"), World.get_shared("offerings"), $Appear1.visible, $Disappear1.visible,
		$Move1.position.x, $Move1.position.y, $Appear2.visible])


## 画面に出す説明(シーンに保存しないので、エディタで保存し直しても消えない)
func _help() -> String:
	return "【音のかけら・捧げる場所・島の変化】かけらを3つ拾って光る円に立つと歌の波。届いた物が段階1で変化する"
