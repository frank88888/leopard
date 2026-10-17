class_name SfxPlayer
extends Node
## 以程式合成全部音效(無外部音檔、無版權問題)。tick 使用多聲道輪播,高速時不會被吃掉。

const RATE := 44100
const TICK_VOICES := 6

var volume := 0.8:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		_apply_volume()
var muted := false:
	set(v):
		muted = v
		_apply_volume()
var tick_pitch := 1.0:
	set(v):
		tick_pitch = clampf(v, 0.5, 2.0)
		for p in _tick_pool:
			p.pitch_scale = tick_pitch

var _styles: Dictionary = {}  # 類別 → {樣式 id → AudioStreamWAV}(樣式 "off" 不在表內 = 無聲)
var _choice: Dictionary = {"tick": "relay", "bet": "beep", "coin": "coin", "win": "bell"}
var _streams: Dictionary = {}  # 固定音效
var _players: Dictionary = {}  # name → AudioStreamPlayer
var _tick_pool: Array[AudioStreamPlayer] = []
var _tick_i := 0


func _ready() -> void:
	_build_styles()
	_streams["count"] = _tone([[1100.0, 0.018]], 0.35, 120.0)
	_streams["jackpot"] = _fanfare()
	_streams["luck"] = _tone([[880.0, 0.09], [1175.0, 0.09], [1568.0, 0.09], [1175.0, 0.09], [1568.0, 0.25]], 0.6, 6.0)
	_streams["du_win"] = _tone([[660.0, 0.09], [990.0, 0.22]], 0.6, 9.0)
	_streams["du_lose"] = _tone([[330.0, 0.14], [220.0, 0.3]], 0.6, 5.0)
	_streams["dice"] = _tone([[300.0, 0.03], [420.0, 0.03], [260.0, 0.03]], 0.5, 40.0, 0.25)
	for n in ["bet", "coin", "win"]:
		_streams[n] = null
	for n in _streams:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players[n] = p
	for i in TICK_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_tick_pool.append(p)
	for cat in _choice:
		set_style(cat, _choice[cat])
	_apply_volume()


## 切換某類音效的樣式。cat:tick / bet / coin / win;style:各清單的 id,"off" 為無聲。
func set_style(cat: String, style: String) -> void:
	if not _styles.has(cat):
		return
	_choice[cat] = style
	var st: AudioStream = _styles[cat].get(style)
	if cat == "tick":
		for p in _tick_pool:
			p.stream = st
			p.pitch_scale = tick_pitch
	else:
		_players[cat].stream = st


func play(name: String) -> void:
	if muted:
		return
	if name == "tick":
		if _tick_pool[_tick_i].stream != null:
			_tick_pool[_tick_i].play()
		_tick_i = (_tick_i + 1) % TICK_VOICES
	elif _players.has(name) and _players[name].stream != null:
		_players[name].play()


func _apply_volume() -> void:
	var db := linear_to_db(0.0 if muted else maxf(volume, 0.0001))
	for p in _players.values():
		p.volume_db = db
	for p in _tick_pool:
		p.volume_db = db


func _build_styles() -> void:
	_styles["tick"] = {
		"relay": _tone([[1100.0, 0.035]], 0.9, 50.0, 0.25),
		"soft": _tone([[620.0, 0.04]], 0.6, 60.0, 0.0, 0.1),
		"beep": _tone([[1500.0, 0.03]], 0.35, 40.0, 0.0, 0.0, "square"),
		"wood": _tone([[420.0, 0.06]], 0.9, 80.0, 0.3, 0.6),
		"click": _tone([[3000.0, 0.015]], 0.8, 150.0, 0.9, 0.0),
	}
	_styles["bet"] = {
		"beep": _tone([[700.0, 0.04]], 0.5, 60.0),
		"click": _tone([[900.0, 0.02]], 0.7, 120.0, 0.7, 0.0),
		"chime": _tone([[1200.0, 0.1]], 0.5, 25.0, 0.0, 0.5),
		"pop": _tone([[350.0, 0.06]], 0.8, 50.0, 0.0, 0.0),
	}
	_styles["coin"] = {
		"coin": _tone([[1900.0, 0.07], [2800.0, 0.16]], 0.6, 14.0),
		"ding": _tone([[2400.0, 0.22]], 0.5, 12.0, 0.0, 0.15),
		"drop": _tone([[1500.0, 0.04], [1050.0, 0.04], [1600.0, 0.05], [900.0, 0.08]], 0.6, 30.0, 0.1),
	}
	_styles["win"] = {
		"bell": _tone([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.28]], 0.7, 7.0),
		"arcade": _tone([[523.0, 0.06], [659.0, 0.06], [784.0, 0.06], [1047.0, 0.06], [784.0, 0.06], [1047.0, 0.2]], 0.35, 8.0, 0.0, 0.0, "square"),
		"chime": _tone([[784.0, 0.14], [988.0, 0.14], [1175.0, 0.4]], 0.6, 5.0, 0.0, 0.2),
	}


## notes:[[頻率, 秒數], ...] 連續播放;decay 越大衰減越快;noise 為敲擊噪音量(0 = 無);
## harm 為二倍音比例;shape:sine / square / tri。
func _tone(notes: Array, amp: float, decay: float, noise := 0.0, harm := 0.35, shape := "sine") -> AudioStreamWAV:
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for note in notes:
		var f: float = note[0]
		var n := int(RATE * float(note[1]))
		for i in n:
			var t := float(i) / RATE
			var env := exp(-decay * t)
			var v := _wave(TAU * f * t, shape) + harm * _wave(TAU * f * 2.0 * t, shape)
			if noise > 0.0:
				v += noise * rng.randf_range(-1.0, 1.0) * exp(-200.0 * t)
			_put16(data, v * env * amp * 0.5)
	return _wav(data)


func _wave(x: float, shape: String) -> float:
	match shape:
		"square":
			return 0.6 if sin(x) >= 0.0 else -0.6
		"tri":
			return asin(sin(x)) * 2.0 / PI
	return sin(x)


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
