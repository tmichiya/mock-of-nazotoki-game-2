extends TestSceneBase
## 汎用部品の確認用シーン(H)。
## ・左上の2つのスイッチ(S1・S2)を二人で同時に踏むと、扉が開く(SwitchGroup → Door.open をエディタでつないである)
## ・右上の4つのスイッチ(A〜D)は組み合わせ判定。正解は A と C(パターンはインスペクタで設定)
##   正解で看板の記号が変わる。間違えると wrong(スイッチは戻る)
## ・看板「1人目だけ」「2人目だけ」「手をつないだ時だけ」(F3 で誰の目で見るかを切り替え)


func _ready() -> void:
	super._ready()
	watch("Group", ["solved", "count_changed"])
	watch("Door", ["state_changed"])
	watch("PatternGroup", ["solved", "wrong"])
	watch("Sign", ["symbols_changed"])


func _steps() -> Array:
	return [
		{ t = 0.3, log = "start" },
		{ t = 0.3, call = "both_on_s1_s2" },
		{ t = 0.1, call = "report", log = "both on S1,S2: expect Door open=true" },
		{ t = 0.3, call = "leave" },
		{ t = 0.3, call = "wrong_combo" },
		{ t = 0.1, call = "report", log = "A + B: expect PatternGroup.wrong" },
		{ t = 0.3, call = "leave" },
		{ t = 0.1, call = "report", log = "after leaving: wrong combo cleared" },
		{ t = 0.3, call = "right_combo" },
		{ t = 0.1, call = "report", log = "A + C: expect PatternGroup.solved, Sign changed" },
		{ t = 0.1, call = "visibility_check" },
	]


func both_on_s1_s2() -> void:
	place(1, $S1.global_position)
	place(2, $S2.global_position)


func leave() -> void:
	place(1, cell(Vector2(3, 10)))
	place(2, cell(Vector2(5, 10)))


func wrong_combo() -> void:
	place(1, $A.global_position)
	place(2, $B.global_position)


func right_combo() -> void:
	place(1, $A.global_position)
	place(2, $C.global_position)


func report() -> void:
	print("[AUTO] door open=%s  sign=%s" % [$Door.is_open, $Sign.symbols])


func visibility_check() -> void:
	for v in [1, 2]:
		World.viewer_override = v
		print("[AUTO] viewer=%d: only_p1=%s only_p2=%s linked_only=%s" % [v,
			$SignP1/OnlyVisibleTo.should_show(), $SignP2/OnlyVisibleTo.should_show(), $SignLinked/OnlyVisibleTo.should_show()])
	World.viewer_override = 0
