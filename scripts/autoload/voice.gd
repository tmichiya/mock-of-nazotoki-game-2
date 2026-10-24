extends Node
## Voice(自動読み込み)
## マイクの音量と声の高さを測り、話している間は自分の位置から「声の波」を出す。
## 声の音声はその波に乗せて相手に送り、相手の端末では「波が自分に届いた時」に再生する。
## ・近い範囲(near_distance)で同じ段なら、波を待たずにすぐ再生
## ・相手の端末に届くまでの通信の遅れの分だけ、波はすでに進んだ状態で始まるので、
##   待ち時間は「波が届くまでの時間 − 通信の遅れ」になる
## ・段が違うと波が届かないので聞こえない。手をつないでいる間は二人それぞれの段に波を出すので届く
##
## 他の部品から: Voice.get_pitch_hz() / Voice.get_pitch_midi() / Voice.get_volume()(0〜1)
##               シグナル pitch_changed(hz, midi) / speaking_changed(speaking)

signal pitch_changed(hz: float, midi: float)
signal speaking_changed(speaking: bool)
signal voice_wave_sent(size: float)
## 相手(または動物が吐き出した)声を再生し始めた。delay は波が出てから再生までの秒数
signal voice_played(source: String, delay: float, immediate: bool)
## 録音デバイスを切り替えた
signal input_device_changed(device_name: String)

const MIC_BUS := "VoiceMic"

var settings: VoiceSettings

var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _mix_rate := 48000.0
var _acc := PackedFloat32Array()        # 今の区切りの音(マイクの周波数)
var _pitch_buf := PackedFloat32Array()  # 高さを測るための音(8kHz)
var _interval_left := 0.0
var _hang := 0.0
var _speaking := false
var _volume01 := 0.0
var _volume_db := -100.0
var _pitch_hz := -1.0
var _detector := PitchDetector.new()
var _tone_phase := 0.0
var _chunk_counter := 0

var _out_player: AudioStreamPlayer
var _out_playback: AudioStreamGeneratorPlayback
var _timeline := PackedFloat32Array()   # これから鳴らす音(send_rate)
var _cursor := {}                       # 音源 -> 次の声を置く位置(_timeline の添字)
var _played := {}                       # 再生済みの声の番号 -> 時刻


func _ready() -> void:
	settings = VoiceSettings.get_default()
	_mix_rate = AudioServer.get_mix_rate()
	_setup_mic()
	_setup_output()
	Waves.wave_emitted.connect(_on_wave_emitted)
	get_tree().node_added.connect(_on_node_added)


func _setup_mic() -> void:
	var idx := AudioServer.get_bus_index(MIC_BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, MIC_BUS)
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
		AudioServer.set_bus_mute(idx, true)
	_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_apply_input_device()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.bus = MIC_BUS
	add_child(_mic_player)
	if settings.mic_enabled and settings.test_tone_hz <= 0.0:
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.play()


func _setup_output() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = settings.send_rate
	gen.buffer_length = 0.5
	_out_player = AudioStreamPlayer.new()
	_out_player.stream = gen
	_out_player.volume_db = settings.playback_volume_db
	add_child(_out_player)
	_out_player.play()
	_out_playback = _out_player.get_stream_playback()


# ---------------------------------------------------------------- 録音デバイス

func _apply_input_device() -> void:
	var want := settings.input_device
	if want != "" and want in AudioServer.get_input_device_list():
		AudioServer.input_device = want


## 録音デバイスの一覧("Default" は Windows の既定)
func get_input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func get_input_device() -> String:
	return AudioServer.input_device


## 録音デバイスを名前で選ぶ
func set_input_device(device_name: String) -> void:
	if device_name in AudioServer.get_input_device_list():
		AudioServer.input_device = device_name
		settings.input_device = "" if device_name == "Default" else device_name
		input_device_changed.emit(device_name)


## 次の録音デバイスに切り替える(F4)
func cycle_input_device() -> void:
	var list := AudioServer.get_input_device_list()
	if list.is_empty():
		return
	var i := list.find(AudioServer.input_device)
	set_input_device(list[(i + 1) % list.size()])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		cycle_input_device()


# ---------------------------------------------------------------- 問い合わせ

func get_pitch_hz() -> float:
	return _pitch_hz


func get_pitch_midi() -> float:
	return PitchDetector.hz_to_midi(_pitch_hz)


func get_volume() -> float:
	return _volume01


func get_volume_db() -> float:
	return _volume_db


func is_speaking() -> bool:
	return _speaking


## マイクの持ち主(この端末で声を出すプレイヤー)
func mic_player() -> Player:
	var locals := World.get_local_players()
	if locals.is_empty():
		return null
	if locals.size() == 1:
		return locals[0]
	for p in locals:
		if p.player_index == settings.offline_mic_player:
			return p
	return locals[0]


# ---------------------------------------------------------------- 録音

func _process(delta: float) -> void:
	_read_input(delta)
	_interval_left -= delta
	if _interval_left <= 0.0:
		_interval_left += settings.wave_interval
		if _interval_left < 0.0:
			_interval_left = settings.wave_interval
		_finish_chunk(settings.wave_interval)
	_feed_output()


func _read_input(delta: float) -> void:
	if settings.test_tone_hz > 0.0:
		var n := int(_mix_rate * delta)
		for i in range(n):
			_tone_phase += TAU * settings.test_tone_hz / _mix_rate
			_acc.append(sin(_tone_phase) * settings.test_tone_volume)
		return
	if _capture == null or not settings.mic_enabled:
		return
	var avail := _capture.get_frames_available()
	if avail <= 0:
		return
	var buf := _capture.get_buffer(avail)
	var gain := db_to_linear(settings.mic_gain_db)
	for f in buf:
		_acc.append((f.x + f.y) * 0.5 * gain)


func _finish_chunk(duration: float) -> void:
	var chunk := _acc
	_acc = PackedFloat32Array()
	if chunk.is_empty():
		_set_speaking(false)
		return
	# 音量
	var sum := 0.0
	for s in chunk:
		sum += s * s
	var rms := sqrt(sum / chunk.size())
	_volume_db = linear_to_db(maxf(rms, 1e-6))
	var loud := _volume_db > settings.threshold_db
	_volume01 = clampf(inverse_lerp(settings.threshold_db, settings.loud_db, _volume_db), 0.0, 1.0)
	if loud:
		_hang = settings.hangover
	else:
		_hang -= duration
	# 声の高さ(8kHz に間引いて測る)
	var down := _resample(chunk, _mix_rate, 8000.0)
	_pitch_buf.append_array(down)
	if _pitch_buf.size() > 800:
		_pitch_buf = _pitch_buf.slice(_pitch_buf.size() - 800)
	_detector.min_hz = settings.pitch_min_hz
	_detector.max_hz = settings.pitch_max_hz
	_detector.threshold = settings.pitch_threshold
	_detector.fallback_threshold = settings.pitch_fallback_threshold
	_detector.median_count = settings.pitch_median
	_detector.hold = settings.pitch_hold
	var raw := _detector.detect(_pitch_buf) if loud and _pitch_buf.size() >= 400 else -1.0
	var stable := _detector.push(raw, Waves.clock)
	if absf(stable - _pitch_hz) > 0.5:
		_pitch_hz = stable
		pitch_changed.emit(_pitch_hz, get_pitch_midi())
	var speaking := loud or _hang > 0.0
	_set_speaking(speaking)
	if speaking:
		_send_voice(_resample(chunk, _mix_rate, settings.send_rate))


func _set_speaking(v: bool) -> void:
	if v != _speaking:
		_speaking = v
		speaking_changed.emit(v)


static func _resample(src: PackedFloat32Array, from_rate: float, to_rate: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if src.is_empty():
		return out
	var ratio := from_rate / to_rate
	var n := int(src.size() / ratio)
	out.resize(n)
	for i in range(n):
		# 間引く時は区間の平均をとる(簡単な低域フィルタ)
		var a := int(i * ratio)
		var b := mini(int((i + 1) * ratio), src.size())
		var s := 0.0
		for k in range(a, maxi(b, a + 1)):
			s += src[mini(k, src.size() - 1)]
		out[i] = s / maxi(b - a, 1)
	return out


# ---------------------------------------------------------------- 声の波を出す

func _send_voice(samples: PackedFloat32Array) -> void:
	var p := mic_player()
	if p == null:
		return
	_chunk_counter += 1
	var chunk_id := "%d-%d" % [Net.my_id(), _chunk_counter]
	var size := lerpf(settings.min_size, settings.max_size, _volume01)
	var payload := { voice = chunk_id, audio = _encode(samples), speaker = p.player_index }
	emit_voice_wave(p, size, payload, _pitch_hz)
	voice_wave_sent.emit(size)


## 声の波を出す(手つなぎ中は相手の位置・段からも同じ声の波を出す)
func emit_voice_wave(p: Player, size: float, payload: Dictionary, pitch: float) -> void:
	var base := {
		size = size, shape = settings.voice_shape.resource_path, source = p.source_id(),
		payload = payload, pitch = pitch, kind = "voice",
	}
	var a := base.duplicate()
	a.origin = p.global_position
	a.level = roundi(p.height)
	if not p.voice_modifier.is_empty():
		a.size = size * float(p.voice_modifier.get("size_scale", 1.0))
		a.dir = p.voice_modifier.get("dir", p.facing)
		a.spread = p.voice_modifier.get("spread", PI)
	Waves.emit(a)
	var partner := Hands.voice_partner(p) as Player
	if partner:
		var b := base.duplicate()
		b.origin = partner.global_position
		b.level = roundi(partner.height)
		Waves.emit(b)


static func _encode(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	return bytes


static func _decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bytes.size() / 2)
	for i in range(out.size()):
		out[i] = bytes.decode_s16(i * 2) / 32768.0
	return out


# ---------------------------------------------------------------- 相手の声を聞く

## 自分の体の WaveReceiver に、声の波が届いた時の受け口をつなぐ
func _on_node_added(n: Node) -> void:
	if n is WaveReceiver and n.get_parent() is Player:
		n.wave_received_info.connect(_on_player_received.bind(n.get_parent()))


func _on_player_received(info: Dictionary, listener: Player) -> void:
	if not listener.is_local:
		return
	var payload: Dictionary = info.payload
	if not payload.has("audio"):
		return
	if not _should_hear(payload, listener):
		return
	if info.bounce > 0 and not settings.play_echoes and _played.has(payload.voice):
		return
	var strength: float = info.strength / maxf(float(info.size), 0.01)
	_play(payload, str(info.source), strength, Net.time() - float(info.emit_time), false)


## 近い範囲なら、波を待たずにすぐ再生する
func _on_wave_emitted(p: Dictionary) -> void:
	var payload: Dictionary = p.get("payload", {})
	if not payload.has("audio"):
		return
	for listener: Player in World.get_local_players():
		if not _should_hear(payload, listener):
			continue
		var speaker_pos: Vector2 = p.origin
		var same_level := roundi(listener.height) == int(p.level)
		if not same_level:
			continue
		if listener.global_position.distance_to(speaker_pos) <= settings.near_distance:
			_play(payload, str(p.source), 1.0, Net.time() - float(p.time), true)


func _should_hear(payload: Dictionary, listener: Player) -> bool:
	var speaker: int = payload.get("speaker", 0)
	if speaker == listener.player_index:
		return false
	# 1台で2人の時:マイクの声を自分の端末で鳴らすのは確認用の設定がある時だけ
	if not Net.is_online():
		return settings.offline_loopback
	# 自分の端末で話した声は鳴らさない(相手の端末で鳴る)
	var me := mic_player()
	if me and speaker == me.player_index and not payload.has("relay"):
		return false
	return true


func _play(payload: Dictionary, source: String, strength: float, delay: float, immediate: bool) -> void:
	var key: String = payload.voice + ("/" + str(payload.relay) if payload.has("relay") else "")
	if _played.has(key) and not settings.play_echoes:
		return
	_played[key] = Time.get_ticks_msec()
	if _played.size() > 400:
		var now := Time.get_ticks_msec()
		for k in _played.keys():
			if now - _played[k] > 10000:
				_played.erase(k)
	var samples := _decode(payload.audio)
	var gain := clampf(strength, 0.15, 1.0) if settings.volume_by_strength else 1.0
	_mix_in(source, samples, gain)
	voice_played.emit(source, delay, immediate)


func _mix_in(source: String, samples: PackedFloat32Array, gain: float) -> void:
	var start: int = _cursor.get(source, 0)
	# 前の声から間が空いた(もう鳴り終わった)なら今すぐ。遅れすぎていたら詰める
	start = clampi(start, 0, int(settings.send_rate * 0.3))
	var need := start + samples.size()
	if _timeline.size() < need:
		var old := _timeline.size()
		_timeline.resize(need)
		for i in range(old, need):
			_timeline[i] = 0.0
	for i in range(samples.size()):
		_timeline[start + i] = clampf(_timeline[start + i] + samples[i] * gain, -1.0, 1.0)
	_cursor[source] = start + samples.size()


func _feed_output() -> void:
	if _out_playback == null:
		return
	var free := _out_playback.get_frames_available()
	# 鳴らす前の溜めを短く保つ(遅れを増やさない)
	var buffered := int(settings.send_rate * 0.5) - free
	var want := maxi(0, int(settings.send_rate * 0.08) - buffered)
	want = mini(want, free)
	if want <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(want)
	var n := mini(want, _timeline.size())
	for i in range(n):
		frames[i] = Vector2(_timeline[i], _timeline[i])
	_out_playback.push_buffer(frames)
	if n > 0:
		_timeline = _timeline.slice(n)
	for k in _cursor.keys():
		_cursor[k] = maxi(0, _cursor[k] - want)
