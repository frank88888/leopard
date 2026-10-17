class_name GameConfig
extends RefCounted
## 載入 config/*.json。所有數值皆可調,規則模組只讀這裡。

const SYMBOLS_PATH := "res://config/symbols.json"
const RING_PATH := "res://config/ring_layout.json"
const ODDS_PATH := "res://config/odds.json"
const SETTINGS_PATH := "res://config/settings.json"

const RING_SIZE := 32
const LUCK := -1  ## 環上 LUCK 格的符號代碼

var symbol_ids: Array[String] = []
var symbol_names: Array[String] = []
var multipliers: Array[int] = []
var jackpot_symbols: Array[int] = []
var ring_cells: Array[int] = []  ## 長度 32,元素為符號索引或 LUCK
var rtp_target := 0.93
var luck_bonus_prob := 0.06
var bonus_weights: Dictionary = {1: 60, 2: 30, 3: 10}  ## 送燈次數 → 權重
var s: Dictionary = {}  ## settings


static func load_default(with_overrides := false) -> GameConfig:
	var c := GameConfig.new()
	var sym := _read(SYMBOLS_PATH)
	for e in sym["symbols"]:
		c.symbol_ids.append(e["id"])
		c.symbol_names.append(e["name"])
		c.multipliers.append(int(e["multiplier"]))
	for id in sym["jackpot_symbols"]:
		c.jackpot_symbols.append(c.symbol_ids.find(id))
	for id in _read(RING_PATH)["cells"]:
		c.ring_cells.append(LUCK if id == "luck" else c.symbol_ids.find(id))
	var odds := _read(ODDS_PATH)
	c.rtp_target = float(odds["rtp_target"])
	c.luck_bonus_prob = float(odds["luck_bonus_prob"])
	c.bonus_weights = {}
	for k in odds["bonus_weights"]:
		c.bonus_weights[int(k)] = int(odds["bonus_weights"][k])
	c.s = _read(SETTINGS_PATH)
	if with_overrides:
		c.apply_overrides(SaveData.load_file(OVERRIDE_PATH))
	return c


const OVERRIDE_PATH := "user://overrides.json"
const TUNABLE_SETTINGS := ["bet_cap", "repeat_interval_ms", "double_up_max", "win_cap", "jackpot_coef", "volume", "admin_password"]


## 後台修改過的值(存在 user://,不動到 res:// 內的預設)。
func apply_overrides(d: Dictionary) -> void:
	if d.is_empty():
		return
	if d.has("rtp_target"):
		rtp_target = float(d["rtp_target"])
	if d.has("luck_bonus_prob"):
		luck_bonus_prob = float(d["luck_bonus_prob"])
	if d.has("multipliers") and d["multipliers"].size() == multipliers.size():
		for i in multipliers.size():
			multipliers[i] = int(d["multipliers"][i])
	for k in TUNABLE_SETTINGS:
		if d.has(k):
			s[k] = d[k]


func overrides_dict() -> Dictionary:
	var d := {"rtp_target": rtp_target, "luck_bonus_prob": luck_bonus_prob, "multipliers": multipliers}
	for k in TUNABLE_SETTINGS:
		d[k] = s[k]
	return d


func save_overrides() -> bool:
	return SaveData.save(OVERRIDE_PATH, overrides_dict())


## 目前的倍率 / RTP / LUCK 機率組合是否能建出合法機率表(總機率不超過 1)。
func odds_valid() -> bool:
	var e := Bonus.expected_count(bonus_weights)
	var c := rtp_target / (1.0 + e * luck_bonus_prob)
	var sum := 0.0
	for m in multipliers:
		if m <= 0:
			return false
		sum += c / float(m)
	return sum + luck_bonus_prob <= 1.0 + 1e-9


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "cannot open " + path)
	var d = JSON.parse_string(f.get_as_text())
	assert(d is Dictionary, "bad json " + path)
	return d


func symbol_count() -> int:
	return multipliers.size()


func bet_cap() -> int:
	return int(s["bet_cap"])


func jackpot_threshold() -> int:
	return int(round(bet_cap() * float(s["jackpot_coef"])))
