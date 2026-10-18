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

const CATS := [["tick", "轉燈"], ["bet", "投注"], ["coin", "投幣"], ["win", "中獎"]]
const FIXED := [["count", "數分"], ["luck", "LUCK"], ["du_win", "比大小・猜對"], ["du_lose", "比大小・猜錯"], ["dice", "骰子"]]
## DEBUG 視窗可調的參數:[id, 名稱, 最小, 最大, 步進]。shape(波形)另外處理。
const PARAMS := [
	["freq_mult", "音高倍率", 0.25, 4.0, 0.01],
	["dur_mult", "長度倍率", 0.2, 4.0, 0.01],
	["amp", "振幅", 0.0, 1.5, 0.01],
	["decay", "衰減速度", 0.0, 200.0, 0.5],
	["noise", "敲擊噪音", 0.0, 1.5, 0.01],
	["harm", "二倍音", 0.0, 1.0, 0.01],
]
const SHAPES := ["sine", "square", "tri"]

var _defs: Dictionary = {}  # 音效 key → 音符表 [[頻率, 秒數], ...]
var _params: Dictionary = {}  # 音效 key → 目前參數
var _defaults: Dictionary = {}  # 音效 key → 出廠參數
var _wavs: Dictionary = {}  # 音效 key → AudioStreamWAV("類別/樣式" 或固定音效名)
var _choice: Dictionary = {"tick": "relay", "bet": "beep", "coin": "coin", "win": "bell"}
var _players: Dictionary = {}  # name → AudioStreamPlayer
var _tick_pool: Array[AudioStreamPlayer] = []
var _tick_i := 0
var _preview: AudioStreamPlayer


func _ready() -> void:
	_register_all()
	_wavs["jackpot"] = _fanfare()
	for n in ["count", "jackpot", "luck", "du_win", "du_lose", "dice", "bet", "coin", "win"]:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players[n] = p
		if _wavs.has(n):
			p.stream = _wavs[n]
	for i in TICK_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_tick_pool.append(p)
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	for cat in _choice:
		set_style(cat, _choice[cat])
	_apply_volume()


## 切換某類音效的樣式。cat:tick / bet / coin / win;style:各清單的 id,"off" 為無聲。
func set_style(cat: String, style: String) -> void:
	if not _choice.has(cat):
		return
	_choice[cat] = style
	var st: AudioStream = _wavs.get("%s/%s" % [cat, style])
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
	if _preview != null:
		_preview.volume_db = db


# ---------- DEBUG:執行中調整單一音效的合成參數 ----------

## 全部可調音效:[[key, 顯示名稱], ...]。
func sound_list() -> Array:
	var lists := {"tick": UserPrefs.TICK_STYLES, "bet": UserPrefs.BET_STYLES, "coin": UserPrefs.COIN_STYLES, "win": UserPrefs.WIN_STYLES}
	var out: Array = []
	for c in CATS:
		for e in lists[c[0]]:
			if e[0] != "off":
				out.append(["%s/%s" % [c[0], e[0]], "%s・%s" % [c[1], e[1]]])
	for f in FIXED:
		out.append([f[0], f[1]])
	return out


func get_params(key: String) -> Dictionary:
	return _params[key].duplicate() if _params.has(key) else {}


## 設定單一參數(自動夾在合法範圍內)並立即重新合成。
func set_param(key: String, pname: String, value) -> void:
	if not _params.has(key):
		return
	if pname == "shape":
		if SHAPES.has(value):
			_params[key]["shape"] = value
	else:
		for sp in PARAMS:
			if sp[0] == pname:
				_params[key][pname] = clampf(float(value), sp[2], sp[3])
	_rebuild(key)


func reset_sound(key: String) -> void:
	if _defaults.has(key):
		_params[key] = _defaults[key].duplicate()
		_rebuild(key)


func reset_all_sounds() -> void:
	for key in _defaults:
		reset_sound(key)


func preview(key: String) -> void:
	if not _wavs.has(key):
		return
	_preview.stream = _wavs[key]
	_preview.pitch_scale = tick_pitch if key.begins_with("tick/") else 1.0
	_preview.play()


## 與出廠值不同的參數,整理成可貼回程式碼的文字。
func export_changes() -> String:
	var lines: Array[String] = []
	for e in sound_list():
		var key: String = e[0]
		var diff: Array[String] = []
		for pname in _params[key]:
			if _params[key][pname] != _defaults[key][pname]:
				var v = _params[key][pname]
				diff.append("%s=%s" % [pname, v if v is String else "%.3f" % v])
		if not diff.is_empty():
			lines.append("%s: %s" % [key, ", ".join(diff)])
	return "\n".join(lines) if not lines.is_empty() else "(與出廠值相同)"


func _rebuild(key: String) -> void:
	_wavs[key] = _render(key)
	if key.contains("/"):
		var parts := key.split("/")
		if _choice[parts[0]] == parts[1]:
			set_style(parts[0], parts[1])
	elif _players.has(key):
		_players[key].stream = _wavs[key]


func _render(key: String) -> AudioStreamWAV:
	var pr: Dictionary = _params[key]
	var notes: Array = []
	for n in _defs[key]:
		notes.append([float(n[0]) * pr["freq_mult"], float(n[1]) * pr["dur_mult"]])
	return _tone(notes, pr["amp"], pr["decay"], pr["noise"], pr["harm"], pr["shape"])


func _reg(key: String, notes: Array, amp: float, decay: float, noise := 0.0, harm := 0.35, shape := "sine") -> void:
	_defs[key] = notes
	_defaults[key] = {"freq_mult": 1.0, "dur_mult": 1.0, "amp": amp, "decay": decay, "noise": noise, "harm": harm, "shape": shape}
	_params[key] = _defaults[key].duplicate()
	_wavs[key] = _render(key)


func _register_all() -> void:
	_reg("tick/relay", [[1100.0, 0.035]], 0.9, 50.0, 0.25)
	_reg("tick/soft", [[620.0, 0.04]], 0.6, 60.0, 0.0, 0.1)
	_reg("tick/beep", [[1500.0, 0.03]], 0.35, 40.0, 0.0, 0.0, "square")
	_reg("tick/wood", [[420.0, 0.06]], 0.9, 80.0, 0.3, 0.6)
	_reg("tick/click", [[3000.0, 0.015]], 0.8, 150.0, 0.9, 0.0)
	_reg("bet/beep", [[700.0, 0.04]], 0.5, 60.0)
	_reg("bet/click", [[900.0, 0.02]], 0.7, 120.0, 0.7, 0.0)
	_reg("bet/chime", [[1200.0, 0.1]], 0.5, 25.0, 0.0, 0.5)
	_reg("bet/pop", [[350.0, 0.06]], 0.8, 50.0, 0.0, 0.0)
	_reg("coin/coin", [[1900.0, 0.07], [2800.0, 0.16]], 0.6, 14.0)
	_reg("coin/ding", [[2400.0, 0.22]], 0.5, 12.0, 0.0, 0.15)
	_reg("coin/drop", [[1500.0, 0.04], [1050.0, 0.04], [1600.0, 0.05], [900.0, 0.08]], 0.6, 30.0, 0.1)
	_reg("win/bell", [[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.28]], 0.7, 7.0)
	_reg("win/arcade", [[523.0, 0.06], [659.0, 0.06], [784.0, 0.06], [1047.0, 0.06], [784.0, 0.06], [1047.0, 0.2]], 0.35, 8.0, 0.0, 0.0, "square")
	_reg("win/chime", [[784.0, 0.14], [988.0, 0.14], [1175.0, 0.4]], 0.6, 5.0, 0.0, 0.2)
	_reg("count", [[1100.0, 0.018]], 0.35, 120.0)
	_reg("luck", [[880.0, 0.09], [1175.0, 0.09], [1568.0, 0.09], [1175.0, 0.09], [1568.0, 0.25]], 0.6, 6.0)
	_reg("du_win", [[660.0, 0.09], [990.0, 0.22]], 0.6, 9.0)
	_reg("du_lose", [[330.0, 0.14], [220.0, 0.3]], 0.6, 5.0)
	_reg("dice", [[300.0, 0.03], [420.0, 0.03], [260.0, 0.03]], 0.5, 40.0, 0.25)


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
