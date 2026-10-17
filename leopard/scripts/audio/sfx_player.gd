class_name SfxPlayer
extends Node
## 以程式合成全部音效(無外部音檔、無版權問題)。tick 使用多聲道輪播,高速時不會被吃掉。

const RATE := 44100
const TICK_VOICES := 6

var volume := 0.8:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		_apply_volume()

var _streams: Dictionary = {}
var _players: Dictionary = {}  # name -> AudioStreamPlayer
var _tick_pool: Array[AudioStreamPlayer] = []
var _tick_i := 0


func _ready() -> void:
	_streams["tick"] = _tone([[1500.0, 0.035]], 0.9, 90.0, true)
	_streams["bet"] = _tone([[700.0, 0.04]], 0.5, 60.0)
	_streams["coin"] = _tone([[1900.0, 0.07], [2800.0, 0.16]], 0.6, 14.0)
	_streams["count"] = _tone([[1100.0, 0.018]], 0.35, 120.0)
	_streams["win"] = _tone([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.28]], 0.7, 7.0)
	_streams["jackpot"] = _fanfare()
	_streams["luck"] = _tone([[880.0, 0.09], [1175.0, 0.09], [1568.0, 0.09], [1175.0, 0.09], [1568.0, 0.25]], 0.6, 6.0)
	_streams["du_win"] = _tone([[660.0, 0.09], [990.0, 0.22]], 0.6, 9.0)
	_streams["du_lose"] = _tone([[330.0, 0.14], [220.0, 0.3]], 0.6, 5.0)
	_streams["dice"] = _tone([[300.0, 0.03], [420.0, 0.03], [260.0, 0.03]], 0.5, 40.0, true)
	for n in _streams:
		if n == "tick":
			continue
		var p := AudioStreamPlayer.new()
		p.stream = _streams[n]
		add_child(p)
		_players[n] = p
	for i in TICK_VOICES:
		var p := AudioStreamPlayer.new()
		p.stream = _streams["tick"]
		add_child(p)
		_tick_pool.append(p)
	_apply_volume()


func play(name: String) -> void:
	if name == "tick":
		_tick_pool[_tick_i].play()
		_tick_i = (_tick_i + 1) % TICK_VOICES
	elif _players.has(name):
		_players[name].play()


func _apply_volume() -> void:
	var db := linear_to_db(maxf(volume, 0.0001))
	for p in _players.values():
		p.volume_db = db
	for p in _tick_pool:
		p.volume_db = db


## notes: [[freq, seconds], ...] 連續播放;decay 越大衰減越快;noisy 加入一點噪音(敲擊感)。
func _tone(notes: Array, amp: float, decay: float, noisy := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for note in notes:
		var f: float = note[0]
		var n := int(RATE * float(note[1]))
		for i in n:
			var t := float(i) / RATE
			var env := exp(-decay * t)
			var v := sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)
			if noisy:
				v += 0.25 * rng.randf_range(-1.0, 1.0) * exp(-200.0 * t)
			_put16(data, v * env * amp * 0.5)
	return _wav(data)


func _fanfare() -> AudioStreamWAV:
	var data := PackedByteArray()
	var seq := [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0, 1047.0, 1319.0, 1568.0]
	for k in seq.size():
		var f: float = seq[k]
		var dur := 0.11 if k < seq.size() - 1 else 0.7
		var n := int(RATE * dur)
		for i in n:
			var t := float(i) / RATE
			var vib := 1.0 + 0.01 * sin(TAU * 6.0 * t)
			var env := exp(-4.0 * t)
			var v := sin(TAU * f * vib * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.25 * sin(TAU * f * 3.0 * t)
			_put16(data, v * env * 0.3)
	return _wav(data)


func _put16(data: PackedByteArray, v: float) -> void:
	var s := int(clampf(v, -1.0, 1.0) * 32767.0)
	data.append(s & 0xFF)
	data.append((s >> 8) & 0xFF)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
