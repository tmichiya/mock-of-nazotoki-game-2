# 2人協力・探索謎解きモック 部品と土台

島の地形と謎の配置をエディタで作るための「置くだけで使える部品」と土台です。
見た目は仮(単色の図形)。高さの読みやすさ(影・崖の側面・段の色・輪郭)と音の波の表示は入っています。

- エンジン: **Godot 4.7.1**(CLAUDE.md には 4.6 とあるが、project.godot が 4.7 で作られていたため 4.7 で進めた)
- 言語: GDScript / 2D / 少し斜めから見下ろす固定カメラ

## 進み具合

| 部品 | 確認用シーン | 完了条件の確認 |
| --- | --- | --- |
| A 高さのある地形 | `parts/terrain/test_terrain.tscn` | 済(台本で 0→1→2段の上り下り、壁、前後関係・輪郭を画像で確認) |
| B プレイヤー・滑空 | 同上 | 済(崖の縁で滑空し、影の位置=着地点。着地時の高さ=足元の段) |
| C 腕と身振り | `parts/hands/test_hands.tscn` / `tests/test_net.tscn` | 済(8方向スナップ。2つ起動して相手側でも同じ番号になることを確認) |
| D 手つなぎ | `parts/hands/test_hands.tscn` | 済(片手の回転投げ、両手の反動、1段は立ったまま、2段は宙づり→揺れ→引き上げ) |
| E 音の波 | `parts/sound_wave/test_sound_wave.tscn` | 済(止まる・通り過ぎる・跳ね返る・楕円の焦点、受け取りと重なりのシグナル、押す) |
| F マイクと声の波 | `parts/voice/test_voice.tscn` | 済(試験音で確認:音量で波の大きさが変わる、220Hz→220.1Hz、440Hz→440.6Hz) |
| G 通信とVC | `tests/test_net.tscn` | 1台・2起動で確認済(遠い=約1.3秒遅れ、近い=即、段違い=届かない、段またぎの手つなぎ=届く)。**別々のPC・別々の部屋での確認はまだ** |
| H 汎用の部品 | `parts/puzzle/tests/test_general.tscn` / `test_offering.tscn` | 済 |
| I レバー | `parts/puzzle/tests/test_lever_animal.tscn` | 済(一人では pull_failed、手をつないだ二人で1段階進む) |
| J 声を食べる動物 | 同上 | 済(向いた方へ吐き出す、レバーで向きが変わる、リレーで無限に回らない) |
| K 眠るカエル | `parts/puzzle/tests/test_frog.tscn` | 済(寝返り→落ち着く、怒る→failed→やり直し) |
| L 長い棒 | `parts/puzzle/tests/test_pole.tscn` | 済(二人で運ぶ・回す、柱に当たると hit と音の波) |
| M 歌う鳥・和音 | `parts/puzzle/tests/test_bird.tscn` | 済(瓶笛ド・ミ・ソで3羽が鳴き直し、chord_completed) |
| N かけら・捧げる場所 | `parts/puzzle/tests/test_offering.tscn` | 済(3つ拾って捧げる→歌の波→段階1の物だけ変化) |
| O 綿毛・重なる石・糸電話・ラッパ | `parts/puzzle/tests/test_extras.tscn` | 済 |
| 部品カタログ | `catalog.tscn` | 全部品を並べて歩いて回れる |

自動確認の結果は、各シーンを `--autopilot` 付きで実行すると `[AUTO]` `[SIG]` のログで見られます(下の「確認の仕方」)。

---

## 動かし方

### 1台で2人(オフライン)
確認用シーンをそのまま実行(F6)。2人とも出てきます。

| | 1人目 | 2人目 |
| --- | --- | --- |
| 移動 | WASD / コントローラー0 の左スティック | 矢印 / コントローラー1 |
| ポーズ(押している間) | Shift / LT(設定で RT・両方に変更可) | `/` |
| 腕(ポーズ中) | 画面左側の腕=WASD、右側の腕=IJKL / 両スティック | 矢印+テンキー8456 |
| 手を伸ばす(左・右) | Q・E / LB・RB | `,` `.` |
| 滑空 | Space / A | Enter |
| 楽器 | R / X | `\` |

F1 段番号の表示 / F2 音の波の届く範囲 / F3 「片方にしか見えない物」を誰の目で見るか(1台で2人の確認用)

### 1台で2つ起動して通信を試す
1. エディタの「デバッグ > 複数インスタンスの実行をカスタマイズ」で、インスタンス数を2にする
2. 1つ目の引数 `--host`、2つ目の引数 `--join=127.0.0.1 --pad=1`(2つ目は2番目のコントローラー)
3. 確かめたいシーンを開いて実行(F6)。ホストが1人目、参加した方が2人目になる

または、メインシーン(`ui/connect_screen.tscn`)から「ホストする」「参加する」を押す。ホストが選んだシーンを相手も開きます。

起動引数(`--` の後に書く): `--host` / `--join=IP` / `--port=7777` / `--pad=番号`(-1 でコントローラーなし) / `--kb=a|b|none` / `--allow-unfocused`(選ばれていないウィンドウでも入力を受け付ける。2つのウィンドウに別々のコントローラーを使う時)

### 別々のPCで
ホスト側でポート 7777(UDP)を通し、参加側は接続画面でホストのIPを入れる。同じLAN内を想定しています。

---

## 島の作り方(新しいシーン)

1. ルートに Node2D を置き、**インスペクタで「Y Sort Enabled」をオン**にする(前後関係に必須)
2. 子に **Terrain**(ノード追加で `Terrain` を検索、または `TileMapLayer` に `parts/terrain/terrain.gd`)を置き、タイルを塗る
3. `parts/player/player_spawner.tscn` と `parts/player/spawn_point.tscn` ×2(index 1・2)を置く
4. `parts/camera/follow_camera.tscn` を置く
5. 謎の部品を置いて、インスペクタで数値を決め、「ノード > シグナル」でつなぐ
6. 接続画面から開くなら、`ui/connect_screen.tscn` の `scenes` に追加する

部品は特定のシーンに依存しません(地形が無ければ平らな0段として動く)。部品は**ルート(または Y Sort をオンにした Node2D)の直下**に置くと、キャラとの前後関係が正しくなります。

---

## 共通の約束

- **位置と高さ**: どの物も「地面の位置(position)」と「高さ(段、小数)」を持つ。画面には高さの分だけ上にずらして描く。並べ替え(手前・奥)は地面の位置で行う
- **寸法**: `core/world_config.tres` … マス 32×24px、1段 12px(画面)、1段の実際の高さ 18px(手つなぎの腕の長さなどの計算用)
- **同期**: 部品の状態はホストが決めて相手に配る(相手が後から来ても送り直す)。プレイヤーの動きは各自の端末が決める(手つなぎ中だけホストが二人分を計算)
- **シグナル**: 引数のあるシグナルの他に、扉の `open()` などにそのままつなげる引数なしのシグナル(`received`、`linked_simple` など)も用意した
- **自動読み込み**: `World`(地形への問い合わせ・名簿・共有値)、`Net`(通信)、`Hands`(手つなぎ)、`Waves`(音の波)、`Voice`(マイク・VC)
- 仮の見た目は各部品の `_draw()` にある。絵に差し替える時は、子に Sprite2D などを置いて `_draw()` を消してよい

---

## 部品ごとの使い方

### A. 高さのある地形 `Terrain`(`parts/terrain/terrain.gd`)
- **置き方**: `TileMapLayer` として置き、`terrain_tileset.tres` のタイルを塗る。パレットは「行=段番号(0〜7)、列=平地/奥へ上る/手前へ上る/右へ上る/左へ上る」。斜面の段番号は低い側
- 塗った場所(地面の位置)に対して、見た目は段の高さ分だけ上に描かれる。`logic_alpha_in_editor` を上げると塗ったタイルを透かして見られる
- **調整できる値**: `config`(寸法)、`style`(`core/level_style.tres`:段ごとの床の色・模様・模様テクスチャ、崖の暗さ、輪郭、根元の影)、`cliffs_reflect`(崖が音を跳ね返すか)、`show_level_numbers`
- **同じ段は必ず同じ見た目**: 色と模様は `LevelStyle` の段番号からしか決まらない(マスごとの例外は作れない)
- **問い合わせ**(`World.` からも同じ名前で呼べる。地形が無ければ平らな0段):
  `get_height_at(pos)` 高さ(段、小数) / `get_level_at(pos)` 段番号(斜面は最も近い段) / `is_blocked_between(a, b, height)` 2点の間に height より高い地形があるか / `has_ground_at(pos)`
- **シグナル**: `terrain_rebuilt`
- 壁: 隣のマスと辺の高さが合わなければ、上の段からも下の段からも壁。島の外(空のマス)も壁
- タイルセットを作り直す: `godot --headless --path . --script res://tools/make_terrain_tileset.gd`(段の色を変えた時にパレットの色を合わせる)

### B. プレイヤー `parts/player/player.tscn`
- **置き方**: 直接置かず、`PlayerSpawner` が出す。出る場所は `SpawnPoint`(index 1・2)
- **調整できる値**: 色(`PlayerSpawner.colors`)、`move_speed`、`min_glide_levels`(滑空できる最低段数)、`glide_fall_speed`(段/秒)、`glide_forward_speed`、`glide_steer_speed`、腕の長さ、`body_size`
- **シグナル**: `state_changed` `glide_started` `landed` `pose_changed(posing, arm_left, arm_right)` `wave_touched`
- 影は常に足元の地形の高さに描く。手前の高い段(や group `occluder` の物)に隠れると輪郭を最前面に出す
- 滑空の着地: 高さが真下の地形の高さまで下がった所(=影の位置)。滑空中は今の高さより低い崖には当たらない

### C. 腕と身振り(プレイヤーの一部)
- 腕は体と別のノード(`Visual/ArmL`・`ArmR`、`PlayerArm`)で、回転で8方向を表す
- **ポーズのトリガー**: `core/input_config.tres` の `pose_trigger`(LT / RT / EITHER)。他のボタンもここで変えられる
- **シグナル**: `Player.pose_changed`。腕の番号は 0=右, 1=右下, 2=下 … 時計回り、-1=下ろしている
- 腕の変化は即座に相手へ送る(信頼性あり)

### D. 手つなぎ `Hands`(自動読み込み)+ `HandLinkMonitor`(`parts/hands/hand_link_monitor.tscn`)
- **置き方**: 手つなぎ自体は何も置かなくても動く。エディタでシグナルをつなぎたい時に `HandLinkMonitor` を置く
- **調整できる値**: `parts/hands/hands_settings.tres`(つながる距離、腕が伸びきる距離、回転の加速・最高速・止まる速さ、飛ぶ距離、反動の距離、最大段差 `max_step_levels`=2、引き上げの速さ、振り子、振動の強さ)
- **シグナル**(HandLinkMonitor): `linked(link_type)` `unlinked` `link_type_changed(link_type)` `linked_simple` `two_hands_linked` `thrown` `recoiled` `hang_started` `pulled_up`(link_type: 1=片手, 2=両手)
- **問い合わせ**: `Hands.is_linked()` `Hands.get_link_type()` `Hands.is_player_linked(player)` `Hands.is_cross_level()`
- 片手の回転: 止まっている方が軸。もう一人が軸の周りを走ると勢いがたまり、どちらかが離すと接線方向へ飛ぶ
- 両手の反動: 両手を(ほぼ同時に)離すと、互いに反対へ少し飛ぶ
- 段またぎ: つないだまま崖の方へ歩くと降りられる(最大段差まで)。届けば下の段に立つ、届かなければ宙づり。宙づりの人はスティックで揺らせる。上の人が崖から離れる方へ歩くと引き上げる
- 腕の張り: 張るほど細く赤くなり、緩むと垂れる。相手の重みがかかる人のコントローラーが振動する

### E. 音の波 `Waves`(自動読み込み)と部品
| 部品 | 置き方・役割 | 主な調整値 | シグナル・受け口 |
| --- | --- | --- | --- |
| `SoundEmitter`(`parts/sound_wave/sound_emitter.tscn`) | 音源。`emit()` を呼ぶか一定間隔で鳴る | 形(`shape`)、大きさ、色、段、向きと広がり、`auto_interval` | `emit()` / `emitted` |
| `WaveReceiver` | 物の子に置くと、波が届いた時に知らせる | 半径、段の決め方、反応する種類、最小の強さ、重なりの時間幅 | `wave_received(source, strength, time)` `received` `wave_received_info(info)` `waves_overlapped(a, b, time)` `overlapped` |
| `WavePushable` | 軽い物の子に置くと波で押される | `push_strength` | `pushed(impulse)` |
| `SoundWall` | 波を止める/跳ね返す線(曲線も)。「楕円にする」ボタン付き | 点、閉じる、反射、立つ段・高さ、体も止めるか | — |
| `SoundReflectZone` | 範囲内の地形の崖の「反射する/しない」を上書き | 多角形、反射 | — |
| `DebugOptions` | 段番号・波の範囲の表示の初期状態 | `show_levels` `show_wave_range` | — |

- **波の形**: `parts/sound_wave/shapes/*.tres`(`WaveShape`)。種類名、輪の数・間隔、ギザギザ、線の太さ、速さ、寿命、光線の本数、反射回数。種類は .tres を複製するだけで追加できる
- **段のルール**: 波は発した段の高さだけを進み、「段+0.5 より高い地形」で止まり、それ以下の地形の上は通り過ぎる。受け取れるのは同じ段の物だけ(斜面は最も近い段)
- **届く距離** = 速さ × 寿命 × 大きさ。強さ = 大きさ ×(1 − 進んだ距離 / 届く距離)
- **描き方**: 発した段の高さに描く。地形の行ごとに分けて描くので、手前の高い段に隠れ、高い崖で切れて見える
- 波を出す: `Waves.emit({ origin, level, size, shape, source, color, dir, spread, payload, global })`

### F. マイクと声の波 `Voice`(自動読み込み)+ `VoiceMonitor`(`parts/voice/voice_monitor.tscn`)
- **調整できる値**: `parts/voice/voice_settings.tres`(感度 `mic_gain_db`、話しているとみなす音量、最大の音量、語尾の余韻、波を出す間隔、波の大きさの最小・最大、声の高さの範囲・判定の厳しさ・中央値の回数、VC の即時範囲など)。マイクが無い時は `test_tone_hz` で試験音
- **問い合わせ**: `Voice.get_pitch_hz()` `Voice.get_pitch_midi()`(60=真ん中のド)`Voice.get_volume()`(0〜1)
- **シグナル**(VoiceMonitor): `pitch_changed(hz, midi)` `speaking_changed(speaking)` `started_speaking` `stopped_speaking`。`show_meter` で画面右上に音量・声の高さ
- 声の高さ: 8kHz に間引いて自己相関(YIN 簡易版)、中央値で安定させ、自信のない結果は捨てる

### G. 通信とゲーム内VC `Net` / `Voice`
- 接続: ENet、IP指定。`ui/connect_screen.tscn`(メインシーン)か起動引数
- 同期するもの: 位置・高さ・腕・手つなぎ・波の発生(音源の情報だけ送り、波の計算は両方の端末で同じ)・部品の状態・共有の数
- **VC(声を波に乗せる方式)**: 0.1秒ごとの声の波に、その間の声(16kHz・16bit・無圧縮)を乗せて送る。受け手の端末では相手の声の波を自分の画面でも動かし、**波が自分に届いた瞬間に**その声を鳴らす
  - 送られてくるまでの通信の遅れの分だけ、波は「すでに進んだ状態」で始まる → 待ち時間 = 波が届くまでの時間 − 通信の遅れ
  - `near_distance`(初期40px)以内で同じ段なら、波を待たずにすぐ鳴らす
  - 段が違うと波が届かない=聞こえない。手をつないでいる間は、声の波を二人それぞれの位置・段から出すので届く
  - 動物が吐き出した声も、同じ仕組みで音声ごとリレーされる。反射した2回目以降は `play_echoes` で鳴らすか選べる
- 時計合わせ: 1秒ごとに往復時間を測って、ホストの時計とのずれを推定

### H. 汎用の部品(`parts/puzzle/`)
| 部品 | 置き方 | 主な調整値 | シグナル | 受け口 |
| --- | --- | --- | --- | --- |
| `Door` | 通路に置く | 幅、縦向き、高さ(段)、最初から開く、音を止める・跳ね返す、開閉時間 | `opened` `closed` `state_changed(is_open)` | `open()` `close()` `toggle()` `set_open(bool)` |
| `FloorSwitch` | 床に置く | 半径、プレイヤー/物で押せるか、必要な数、押したまま(latch) | `pressed` `released` `state_changed(is_on)` | `reset()` |
| `SwitchGroup` | どこでも。`switches` にスイッチを登録 | `pattern`(空=全部同時、ありなら組み合わせ)、`window`(少しずれてもよい時間)、間違えたら戻す | `solved` `wrong` `count_changed(n)` `cleared` | `reset_switches()` |
| `SymbolSign` | 置く。記号は `symbols` に番号で | 記号セット(`symbols_default.tres`。`textures` に絵を足すと記号が増える)、大きさ、板の高さ・色 | `symbols_changed` | `set_symbol(i)` `next_symbol()` `set_symbols(arr)` |
| `OnlyVisibleTo` | 見せたい物の子に置く | 誰に見せるか(両方/1人目/2人目/手をつないだ時だけ/誰にも)、見えない人の当たり判定を消す | — | — |
| `IslandChangeReactor` | 置き、変化させたい物を子にする(子が無ければ仮の箱) | 段階、EXACT/AT_LEAST、動作(現れる/消える/落ちる/移動)、移動量、落ちる段数、時間 | `changed` `appeared` `disappeared` `fell` `moved` | `trigger()` |

### I. レバー `Lever`
- **置き方**: 置く。手を伸ばして(LB/RB)つかみ、レバーから離れる方向へスティックを倒すと引ける
- **調整できる値**: 段階数 `positions`、最初の位置、必要な人数 `required_players`(手をつないだ二人を2人と数える)、最後まで行ったら(WRAP/PINGPONG/CLAMP)、つかめる距離、引き続ける時間
- **シグナル**: `position_changed(index)` `pulled` `pull_failed` / **受け口**: `set_position_index(i)` `reset()`

### J. 声を食べる動物 `VoiceEater`
- **置き方**: 置いて、初期の向き `direction`(0=右 … 時計回りに8方向)を決める。向きはレバーの `position_changed` を `set_direction_index` につなぐと変わる(`direction_map` で番号→向きを読み替え)
- **調整できる値**: 吐き出す形(まっすぐ/扇形)と幅、溜める時間 `hold_time`、大きさの倍率と最小、まっすぐの時の距離の倍率、食べる種類、口の半径、リレーの上限
- **シグナル**: `ate(source)` `spat` `direction_changed(index)` / **受け口**: `set_direction_index(i)` `turn_clockwise()` `turn_counterclockwise()`

### K. 眠るカエル `SleepingFrog` と やり直し `PuzzleReset` / `ResetPoint`
- **カエル**: 届いた波の強さ×敏感さが「騒がしさ」として溜まり、時間で減る。寝返り・薄目・怒るのしきい値、落ち着く速さ、怒っている時間、反応する種類、聞こえる半径を調整。`reset_on_angry` に PuzzleReset を指定すると怒った時にやり直す
  - **シグナル**: `stage_changed(stage)` `tossed` `peeked` `failed` `calmed` / **受け口**: `reset()`
- **PuzzleReset**: 子に `ResetPoint` を置く(`player_index` 1・2 でプレイヤーを、`target` で物を、その場所へ戻す)。`parts` に登録した部品の `reset()` も呼ぶ。`delay`、手つなぎを切るか
  - **シグナル**: `reset_done` / **受け口**: `reset()`

### L. 長い棒 `LongPole`
- **置き方**: 置く(位置は棒の真ん中)。両端で手を伸ばして握る
- **調整できる値**: 長さ、置いた向き、重さ、動く・回る速さ、握れる距離、端からの遊び、`counts_as_link`(握っている間「つながっている」扱いにして声を届けるか。初期値オフ)、当たった音(基準の速さ、最小の速さ、最大の大きさ、間隔、形)
- **シグナル**: `grabbed(end)` `released(end)` `hit(strength)` `carried_by_two` `dropped_by_two`

### M. 歌う鳥 `SingingBird` / 和音の判定役 `ChordJudge` / 楽器 `Instrument`
- **鳥**: 鳴ける音 `notes`(MIDI番号)、許容幅(半音)、オクターブ違いを同じとみなすか、反応する種類(voice・instrument)、間隔、鳴き声の波の大きさ・形
  - **シグナル**: `sang(midi)` `out_of_tune(midi)` / **受け口**: `hear_pitch(midi)`
- **和音の判定役**: `birds` に鳥を登録、`chord`(MIDI番号)、`window`、オクターブ違い、余計な音を許さない、一度だけ
  - **シグナル**: `chord_completed` `progress_changed(matched, needed)` / **受け口**: `reset()`
- **楽器(瓶笛)**: `note`、鳴らせる距離、大きさ、間隔、持ち運べるか。近くで楽器ボタン(X / R)を押すと鳴る。手を伸ばしてつかむと運べる
  - **シグナル**: `played(midi)` / **受け口**: `play()`
- 鳴き声・瓶笛の音は `ToneSynth`(仮の正弦波)。本番の音に差し替えてよい

### N. 音のかけら `SoundShard` / 捧げる場所 `OfferingPlace`
- **かけら**: 触れると拾える。数は二人で共有(`World.get_shared("shards")`)。`hidden_at_start` をオンにして `appear()` を謎の成功シグナルにつなぐと、その時に現れる
  - **シグナル**: `collected` `appeared` / **受け口**: `appear()`
- **捧げる場所**: 必要な数 `required`、半径、二人とも立つ必要があるか、上限回数、歌の波の届く距離・形。立った時にかけらが足りていれば捧げる
  - **シグナル**: `offered(stage)` `not_enough(have, need)` / **受け口**: `try_offer()`
- **歌の波**: 段のルールを無視して島全体に届く特別な波。「何回目の捧げか」が段階として付き、`IslandChangeReactor` が反応する

### O. 余裕があれば
| 部品 | 内容 | 主な調整値 | シグナル |
| --- | --- | --- | --- |
| `Fluff`(`parts/props/fluff.tscn`) | 波に押されて流れる軽い物 | 摩擦、最高速、大きさ、浮く高さ。押す強さは子の `WavePushable` | — |
| `OverlapStone` | 二つの波が同時に届いた時だけ光る | 時間幅、光る時間、半径、種類、最小の強さ | `lit` `dimmed` |
| `StringPhone` | 二人で両端を握り、張っていて引っかかっていない間だけ声が届く | 長さ、張っているとみなす割合、握れる距離 | `connected` `disconnected` |
| `Trumpet` | 持つと声の波が扇形になり、向いた方向に遠くまで届く | 広がり、大きさの倍率、握れる距離 | `picked_up` `put_down` |

---

## 選んだ解釈(仕様が曖昧で、こちらで決めた所)

**質問で決めたこと**
- Godot は 4.7 で進める / 謎の企画まとめ(puzzle_plan…md)は無しで進める
- 斜面は「1マスで1段・上下左右4方向」から
- ポーズ中、左スティック=画面の左側に見える腕(キャラにとっては右腕)。LB=画面の左側の手。歩いている時も「画面の左右」で呼ぶ
- VC の遅延は「声を波に乗せる」方式
- 片手の回転は「止まっている方が軸」
- 片手でも段またぎ・宙づり・引き上げができる。両手は「崩れる足場などで落ちそうな時に支える」役

**こちらで決めたこと**
- 塗るのは「地面の位置」、見た目は段の高さ分だけ上に描く(物の配置も同じ)
- 斜面の段番号は低い側。斜面は崖として音を跳ね返さない(吸収)。手前に向かって上る斜面は、1段の高さpx < マスの奥行きpx でないと見えなくなる(Terrain がシーンの警告として出す)
- 波が止まるのは「波の段 + 0.5 より高い地形」。受け取れるのは同じ段(斜面は最も近い段)の物だけ。島の外(海)の上は通り過ぎる
- 手つなぎ中の声は「二人それぞれの位置・段から」同じ声の波を出す(話した人の位置から両方の段に、ではなく)
- 腕が伸びきる距離は段の高さを含めた立体の距離(1段=18px)。初期値では1段の崖は下の段に立てて、2段の崖は宙づりになる
- 両手の反動は「両手を離した時」(両手→片手→離す が `recoil_window` 以内も含む)。片手を離しただけでは反動なし
- 回転投げは、軸の人・回る人のどちらが離しても飛ぶ
- 1台で2人の時、「片方にしか見えない物」は1人目の画面として扱う(F3 で切替)。マイクは1人目の声(`offline_mic_player`)
- 1台で2人の時は、マイクの声を自分の端末では鳴らさない(`offline_loopback` で鳴らせる)
- 動物の吐き出す波の大きさ = max(最小, 食べた波の強さ × 倍率)。同じ声は同じ動物を二度通らない+リレー上限
- 歌う鳥は初期値で「オクターブ違いも同じ音」とみなす(低い声でも高い声でも歌える)
- レバー: 引いている人+その人と手をつないでいる人を数える。一度引いたら、スティックを戻すまで次は引けない
- 長い棒・糸電話・ラッパ・楽器・レバーは「手を伸ばした空いている手」でつかむ。手つなぎに使っている手ではつかめない。つかんでいる手は手つなぎに使われない
- SwitchGroup の組み合わせ判定は、オンの数が正解の数に達した時に合否を出す。間違えたら全員が降りるまで次の判定をしない
- 歌の波の届く距離は捧げる場所の `song_reach`(初期3000px)。島が大きい時は増やす

## 技術メモ・わかっている制限
- 音声はまず無圧縮(16kHz・16bit、約32KB/秒)。LAN なら十分。送受信は `autoload/voice.gd` の `_encode` / `_decode` と `emit_voice_wave` に集めてあるので、TwoVoip(Opus)に差し替える時はここを変える(4.7 で動くかは未確認)
- `SoundWall` は1つのノードとして並べ替えられるので、長い壁はキャラとの前後関係が場所によってずれることがある
- 棒・糸電話などの「物を通したつながり」はホストで判定して相手に送る
- 本番の3D化(企画まとめの「低解像度3D」)は対象外。2Dの仮の見た目

## 確認の仕方(自動)
```
godot --headless --path . res://tools/check_scripts.tscn              # 全スクリプト・シーンの読み込み確認
godot --headless --path . res://tools/build_test_scenes.tscn          # 確認用シーンとカタログを作り直す(上書き)
godot --headless --path . res://parts/terrain/test_terrain.tscn -- --autopilot   # 台本で動かしてログを出す
```
- 確認用シーンの台本は各シーンのスクリプトの `_steps()`。`--autopilot` の時だけ動く(普段は手で操作)
- 確認用シーンは `tools/build_test_scenes.gd` がコードで組み立てている。作り直すと上書きされるので、自分で直したシーンは別名で保存する

## フォルダ
```
core/            WorldConfig・LevelStyle・InputConfig・物理レイヤー
autoload/        World・Net・Hands・Waves・Voice
parts/terrain/   地形
parts/player/    プレイヤー・スポナー・出る場所
parts/camera/    カメラ
parts/hands/     手つなぎの設定とモニター、確認用シーン
parts/sound_wave/ 音の波の部品と波の形
parts/voice/     声の設定とモニター、確認用シーン
parts/puzzle/    謎の部品(tests/ に確認用シーン)
parts/props/     綿毛
parts/misc/      カタログ用の札
tests/           台本(Autopilot)・確認用の共通部分・通信の確認用シーン
tools/           タイルセット生成・確認用シーンの組み立て・読み込み確認
ui/              接続画面
catalog.tscn     部品カタログ
```
