class_name WaveTone
extends ToneSynth
## 音の波に乗せた音(鳥の鳴き声・瓶笛など)を、声と同じきまりで鳴らす ToneSynth。
## ・普通の音: 出た瞬間に、波の届く範囲(同じ段・壁で止まる所まで)にこの端末のプレイヤーがいれば鳴る
## ・遅れて届く音(動物が吐き出した音など。payload.delayed): 波がプレイヤーに届いた時に鳴る
## 届かない所にいるプレイヤーには聞こえない。source_id の波だけを扱う。

## 音を鳴らした(この端末で聞こえた)
signal played(hz: float)

## 扱う波の音源ID(例 "bird:BirdA")
var source_id := ""
## 1回に鳴らす長さ(秒)
var duration := 0.45
## 聞き手の半径(px。プレイヤーの体の大きさ)
var listener_radius := 9.0

var _pending := {}   # 届くのを待っている波のID -> 高さ(Hz)


func _ready() -> void:
	super._ready()
	# 画面の中心からの距離では弱めない(聞こえるかどうかは波で決める)
	max_distance = 100000.0
	attenuation = 0.0
	Waves.wave_emitted.connect(_on_emitted)
	for p in World.get_players():
		_watch_player(p)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Player:
		_watch_player.call_deferred(n)


func _watch_player(p: Player) -> void:
	if not is_instance_valid(p):
		return
	var rcv := p.get_node_or_null("WaveReceiver") as WaveReceiver
	if rcv and not rcv.wave_received_info.is_connected(_on_player_received):
		rcv.wave_received_info.connect(_on_player_received.bind(p))


func _on_emitted(p: Dictionary) -> void:
	if str(p.source) != source_id:
		return
	var hz := float(p.get("pitch", -1.0))
	if hz <= 0.0:
		return
	var payload: Dictionary = p.get("payload", {})
	if payload.get("delayed", false):
		var id := int(p.id)
		_pending[id] = hz
		# 誰にも届かなかった波は、しばらくしたら忘れる
		get_tree().create_timer(10.0).timeout.connect(func(): _pending.erase(id))
		return
	for listener: Player in World.get_local_players():
		if Waves.reaches(int(p.id), listener.global_position, listener_radius, roundi(listener.height)):
			_play(hz)
			return


func _on_player_received(info: Dictionary, listener: Player) -> void:
	if not listener.is_local or not _pending.has(int(info.wave_id)):
		return
	var hz: float = _pending[int(info.wave_id)]
	_pending.erase(int(info.wave_id))
	_play(hz)


func _play(hz: float) -> void:
	play_note(hz, duration)
	played.emit(hz)
