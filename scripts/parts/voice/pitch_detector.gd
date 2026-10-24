class_name PitchDetector
extends RefCounted
## 声の高さ(基本周波数)を求める。YIN の簡易版。精度より安定を重視して、
## 少し前までの結果の中央値をとる。一度取れた高さは hold 秒のあいだ覚えておく(息つぎ・子音で途切れないように)。

var sample_rate := 8000.0
var min_hz := 75.0
var max_hz := 1000.0
var threshold := 0.25
## threshold を下回る谷が無くても、一番深い谷がこれより浅ければ採用する(雑音のある実際の声向け)
var fallback_threshold := 0.45
var median_count := 5
## 取れた高さを覚えておく時間(秒)
var hold := 0.4

var _history: Array = []   # [高さ, 時刻]
## 確認用:直前の検出で一番深かった谷の深さ(0 に近いほどはっきりした高さ。1 に近いと高さが無い)と、その時の高さ
var last_dip := 1.0
var last_candidate_hz := -1.0


## samples から高さ(Hz)を求める。見つからなければ -1
func detect(samples: PackedFloat32Array) -> float:
	var tau_min := maxi(2, int(sample_rate / max_hz))
	var tau_max := mini(samples.size() / 2, int(sample_rate / min_hz))
	last_dip = 1.0
	last_candidate_hz = -1.0
	if tau_max <= tau_min + 2:
		return -1.0
	var w := samples.size() - tau_max
	var d := PackedFloat32Array()
	d.resize(tau_max + 1)
	for tau in range(1, tau_max + 1):
		var sum := 0.0
		for j in range(w):
			var diff := samples[j] - samples[j + tau]
			sum += diff * diff
		d[tau] = sum
	# 累積平均で正規化
	var running := 0.0
	var dn := PackedFloat32Array()
	dn.resize(tau_max + 1)
	dn[0] = 1.0
	for tau in range(1, tau_max + 1):
		running += d[tau]
		dn[tau] = d[tau] * tau / running if running > 0.0 else 1.0
	var best := -1
	for tau in range(tau_min, tau_max):
		if dn[tau] < last_dip:
			last_dip = dn[tau]
			last_candidate_hz = sample_rate / tau
	for tau in range(tau_min, tau_max):
		if dn[tau] < threshold:
			# 谷の底まで進む
			while tau + 1 < tau_max and dn[tau + 1] < dn[tau]:
				tau += 1
			best = tau
			break
	if best < 0:
		# しきい値を下回らなくても、一番深い谷がそこそこ深ければ使う
		var min_tau := -1
		var min_v := 1e9
		for tau in range(tau_min, tau_max):
			if dn[tau] < min_v:
				min_v = dn[tau]
				min_tau = tau
		if min_tau < 0 or min_v > fallback_threshold:
			return -1.0
		best = min_tau
	# 放物線で補間
	var t := float(best)
	if best > 1 and best < tau_max:
		var a := dn[best - 1]
		var b := dn[best]
		var c := dn[best + 1]
		var denom := a - 2.0 * b + c
		if absf(denom) > 1e-9:
			t += 0.5 * (a - c) / denom
	return sample_rate / t


## 中央値で安定させた高さ。now は今の時刻(秒)。hold 秒より古い結果は忘れる。何も無ければ -1
func push(hz: float, now: float) -> float:
	if hz > 0.0:
		_history.append([hz, now])
		while _history.size() > median_count:
			_history.pop_front()
	_history = _history.filter(func(e): return now - e[1] <= hold)
	if _history.is_empty():
		return -1.0
	var values := _history.map(func(e): return e[0])
	values.sort()
	return values[values.size() / 2]


static func hz_to_midi(hz: float) -> float:
	if hz <= 0.0:
		return -1.0
	return 69.0 + 12.0 * log(hz / 440.0) / log(2.0)


static func midi_to_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


const NOTE_NAMES := ["ド", "ド#", "レ", "レ#", "ミ", "ファ", "ファ#", "ソ", "ソ#", "ラ", "ラ#", "シ"]


static func midi_name(midi: float) -> String:
	if midi < 0.0:
		return "-"
	var n := roundi(midi)
	return "%s%d" % [NOTE_NAMES[posmod(n, 12)], n / 12 - 1]
