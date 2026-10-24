class_name HandLinkMonitor
extends Node
## 手つなぎの様子を、エディタでつなげるシグナルとして出す部品。シーンのどこに置いてもよい。
## (手つなぎ本体は自動読み込みの Hands。ここは窓口)

## つながった(link_type: 1=片手, 2=両手)
signal linked(link_type: int)
## 離れた
signal unlinked
## 片手⇔両手が変わった(0=つながっていない)
signal link_type_changed(link_type: int)
## つながった(引数なし。扉の open() などにそのままつなぐ用)
signal linked_simple
## 両手でつながった(引数なし)
signal two_hands_linked
## 回転投げで飛んだ
signal thrown
## 両手を離して反動で飛んだ
signal recoiled
## 宙づりになった / 引き上げられた
signal hang_started
signal pulled_up

## 手つなぎの調整値(全体で共有。ここで編集すると全員に反映)
@export var settings: HandsSettings


func _ready() -> void:
	if settings == null:
		settings = HandsSettings.get_default()
	Hands.settings = settings
	Hands.linked.connect(func(t):
		linked.emit(t)
		linked_simple.emit()
		if t == Hands.LinkType.TWO_HANDS:
			two_hands_linked.emit())
	Hands.unlinked.connect(func(): unlinked.emit())
	Hands.link_type_changed.connect(func(t):
		link_type_changed.emit(t)
		if t == Hands.LinkType.TWO_HANDS:
			two_hands_linked.emit())
	Hands.thrown.connect(func(_p): thrown.emit())
	Hands.recoiled.connect(func(): recoiled.emit())
	Hands.hang_started.connect(func(_p): hang_started.emit())
	Hands.pulled_up.connect(func(_p): pulled_up.emit())


func is_linked() -> bool:
	return Hands.is_linked()


func get_link_type() -> int:
	return Hands.get_link_type()
