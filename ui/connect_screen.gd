extends Control
## 接続画面(最小限)。ホストする / IPを指定して参加する / 1台で2人(オフライン)で遊ぶ。
## 開くシーンは scenes(インスペクタで編集)から選ぶ。ホストが選んだシーンを相手も開く。

## 選べるシーン(自分で作った島のシーンもここに足す)
@export var scenes: PackedStringArray = PackedStringArray([
	"res://catalog.tscn",
	"res://parts/terrain/test_terrain.tscn",
	"res://parts/hands/test_hands.tscn",
	"res://parts/sound_wave/test_sound_wave.tscn",
	"res://parts/voice/test_voice.tscn",
	"res://tests/test_net.tscn",
	"res://parts/puzzle/tests/test_general.tscn",
	"res://parts/puzzle/tests/test_lever_animal.tscn",
	"res://parts/puzzle/tests/test_frog.tscn",
	"res://parts/puzzle/tests/test_pole.tscn",
	"res://parts/puzzle/tests/test_bird.tscn",
	"res://parts/puzzle/tests/test_offering.tscn",
	"res://parts/puzzle/tests/test_extras.tscn",
])

@onready var _ip: LineEdit = %IP
@onready var _port: SpinBox = %Port
@onready var _scene: OptionButton = %Scene
@onready var _pad: SpinBox = %Pad
@onready var _status: Label = %Status


func _ready() -> void:
	for s in scenes:
		if ResourceLoader.exists(s):
			_scene.add_item(s.get_file().get_basename())
			_scene.set_item_metadata(_scene.item_count - 1, s)
	_port.value = Net.port
	_pad.value = Net.local_pad
	Net.status_changed.connect(func(t): _status.text = t)
	%Host.pressed.connect(_on_host)
	%Join.pressed.connect(_on_join)
	%Offline.pressed.connect(_on_offline)


func _selected_scene() -> String:
	return _scene.get_item_metadata(_scene.selected) if _scene.item_count > 0 else ""


func _apply_pad() -> void:
	Net.local_pad = int(_pad.value)


func _on_host() -> void:
	_apply_pad()
	if Net.host(int(_port.value)) == OK:
		Net.change_scene_for_all(_selected_scene())


func _on_join() -> void:
	_apply_pad()
	Net.join(_ip.text.strip_edges(), int(_port.value))
	_status.text = "接続中…(ホストが開いているシーンに移ります)"


func _on_offline() -> void:
	_apply_pad()
	get_tree().change_scene_to_file(_selected_scene())
