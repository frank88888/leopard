class_name UserPrefs
extends RefCounted
## 玩家偏好(聲音 / 顯示 / 遊戲 / 按鍵)。與後台的營運設定分開,存在 user://prefs.json。

const PATH := "user://prefs.json"

## 選項清單:[id, 顯示名稱]
const TICK_STYLES := [["relay", "機械繼電器"], ["soft", "柔和滴答"], ["beep", "電子嗶聲"], ["wood", "木魚"], ["click", "喀嗒"], ["off", "無聲"]]
const BET_STYLES := [["beep", "電子嗶聲"], ["click", "喀嗒"], ["chime", "清脆叮聲"], ["pop", "低音啵"], ["off", "無聲"]]
const COIN_STYLES := [["coin", "投幣聲"], ["ding", "單音叮"], ["drop", "落幣聲"], ["off", "無聲"]]
const WIN_STYLES := [["bell", "鈴聲琶音"], ["arcade", "電玩琶音"], ["chime", "柔和和弦"], ["off", "無聲"]]
const THEMES := [["blue", "藍色(預設)"], ["green", "綠色"], ["red", "紅色"], ["purple", "紫色"]]
const MODES := [["normal", "正常"], ["debug", "DEBUG(顯示調整視窗)"]]
const LED_SIZES := [["small", "小"], ["medium", "中"], ["large", "大"]]

var audio: Dictionary = {}
var display: Dictionary = {}
var game: Dictionary = {}
var bindings := InputBindings.new()

var _master_default := 0.8


func _init(master_default := 0.8) -> void:
	_master_default = master_default
	reset_all()


func reset_all() -> void:
	reset_section("audio")
	reset_section("display")
	reset_section("game")
	reset_section("controls")


func reset_section(name: String) -> void:
	match name:
		"audio":
			audio = {"master": _master_default, "mute": false, "tick": "relay", "tick_pitch": 1.0, "bet": "beep", "coin": "coin", "win": "bell"}
		"display":
			display = {"fullscreen": false, "theme": "blue", "led_size": "medium", "jackpot_flash": true, "key_hints": true}
		"game":
			game = {"anim_speed": 1.0, "mode": "normal"}
		"controls":
			bindings.reset()


static func choices(list: Array) -> Array:
	var out: Array = []
	for e in list:
		out.append(e[0])
	return out


static func choice_name(list: Array, id: String) -> String:
	for e in list:
		if e[0] == id:
			return e[1]
	return id


func to_dict() -> Dictionary:
	return {"audio": audio.duplicate(), "display": display.duplicate(), "game": game.duplicate(), "controls": bindings.to_dict()}


## 由 JSON 字典載入;缺漏或不合法的值退回預設。
func from_dict(d: Dictionary) -> void:
	reset_all()
	if d.is_empty():
		return
	_merge(audio, d.get("audio"))
	_merge(display, d.get("display"))
	_merge(game, d.get("game"))
	if d.get("controls") is Dictionary:
		bindings.from_dict(d["controls"])
	_sanitize()


func _merge(target: Dictionary, src) -> void:
	if not (src is Dictionary):
		return
	for k in target:
		if src.has(k) and typeof(src[k]) == typeof(target[k]):
			target[k] = src[k]
		elif src.has(k) and target[k] is float and src[k] is int:
			target[k] = float(src[k])


func _sanitize() -> void:
	audio["master"] = clampf(float(audio["master"]), 0.0, 1.0)
	audio["tick_pitch"] = clampf(float(audio["tick_pitch"]), 0.5, 2.0)
	audio["tick"] = _pick(TICK_STYLES, audio["tick"], "relay")
	audio["bet"] = _pick(BET_STYLES, audio["bet"], "beep")
	audio["coin"] = _pick(COIN_STYLES, audio["coin"], "coin")
	audio["win"] = _pick(WIN_STYLES, audio["win"], "bell")
	display["theme"] = _pick(THEMES, display["theme"], "blue")
	display["led_size"] = _pick(LED_SIZES, display["led_size"], "medium")
	game["mode"] = _pick(MODES, game["mode"], "normal")
	game["anim_speed"] = clampf(float(game["anim_speed"]), 0.5, 2.0)


static func _pick(list: Array, v, fallback: String) -> String:
	return v if choices(list).has(v) else fallback


func save(path := PATH) -> bool:
	return SaveData.save(path, to_dict())


## 檔案不存在或損毀時回傳全預設。
static func load_file(path := PATH, master_default := 0.8) -> UserPrefs:
	var p := UserPrefs.new(master_default)
	p.from_dict(SaveData.load_file(path))
	return p
