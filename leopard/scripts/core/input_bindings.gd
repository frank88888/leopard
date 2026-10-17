class_name InputBindings
extends RefCounted
## 可自訂的鍵盤 / 滑鼠對應。每個動作最多 2 個按鍵 + 1 個滑鼠鍵;同一個鍵只能綁在一個動作上。

const KEY_SLOTS := 2
const RESERVED_KEYS := [KEY_ESCAPE, KEY_HOME, KEY_END]  ## 開設定 / 後台用,不可重新指定
const MOUSE_ALLOWED := [
	MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
]

var map: Dictionary = {}  ## action id → {"keys": [int, int], "mouse": int}(0 = 未指定)


func _init() -> void:
	reset()


static func action_list() -> Array:
	var l: Array = [
		["coin_1", "投幣 +1"], ["coin_5", "投幣 +5"], ["coin_10", "投幣 +10"], ["coin_50", "投幣 +50"],
		["start", "啟動 / 續押"], ["collect", "收分"], ["small", "比小"], ["big", "比大"],
	]
	for i in 8:
		l.append(["bet_%d" % i, "押注 %d" % (i + 1)])
	return l


static func default_for(id: String) -> Dictionary:
	match id:
		"coin_1": return {"keys": [KEY_F1, 0], "mouse": 0}
		"coin_5": return {"keys": [KEY_F2, 0], "mouse": 0}
		"coin_10": return {"keys": [KEY_F3, 0], "mouse": 0}
		"coin_50": return {"keys": [KEY_F4, 0], "mouse": 0}
		"start": return {"keys": [KEY_SPACE, KEY_ENTER], "mouse": MOUSE_BUTTON_RIGHT}
		"collect": return {"keys": [KEY_C, 0], "mouse": 0}
		"small": return {"keys": [KEY_Z, 0], "mouse": 0}
		"big": return {"keys": [KEY_X, 0], "mouse": 0}
	var n := int(id.substr(4))  # bet_N
	return {"keys": [KEY_1 + n, KEY_KP_1 + n], "mouse": 0}


func reset() -> void:
	map = {}
	for e in action_list():
		map[e[0]] = default_for(e[0])


## 還原單一動作的預設鍵(預設鍵若被別的動作佔用,會被搶回來)。
func reset_action(id: String) -> void:
	var def := default_for(id)
	map[id] = {"keys": [0, 0], "mouse": 0}
	for s in KEY_SLOTS:
		if def["keys"][s] != 0:
			set_key(id, s, def["keys"][s])
	if def["mouse"] != 0:
		set_mouse(id, def["mouse"])


func action_for_key(code: int) -> String:
	if code == 0:
		return ""
	for id in map:
		if map[id]["keys"].has(code):
			return id
	return ""


func action_for_mouse(btn: int) -> String:
	if btn == 0:
		return ""
	for id in map:
		if map[id]["mouse"] == btn:
			return id
	return ""


## 指定按鍵;回傳被搶走這個鍵的動作 id(沒有則 "")。保留鍵回傳 "!"(不變更)。
func set_key(id: String, slot: int, code: int) -> String:
	if RESERVED_KEYS.has(code):
		return "!"
	var taken := ""
	for other in map:
		var ks: Array = map[other]["keys"]
		for s in KEY_SLOTS:
			if ks[s] == code and not (other == id and s == slot):
				ks[s] = 0
				taken = other
	map[id]["keys"][slot] = code
	return taken


func set_mouse(id: String, btn: int) -> String:
	if not MOUSE_ALLOWED.has(btn):
		return "!"
	var taken := ""
	for other in map:
		if map[other]["mouse"] == btn and other != id:
			map[other]["mouse"] = 0
			taken = other
	map[id]["mouse"] = btn
	return taken


func clear_key(id: String, slot: int) -> void:
	map[id]["keys"][slot] = 0


func clear_mouse(id: String) -> void:
	map[id]["mouse"] = 0


func key_text(id: String, slot: int) -> String:
	var c: int = map[id]["keys"][slot]
	return "—" if c == 0 else OS.get_keycode_string(c)


func mouse_text(id: String) -> String:
	return mouse_name(map[id]["mouse"])


static func mouse_name(btn: int) -> String:
	match btn:
		0: return "—"
		MOUSE_BUTTON_LEFT: return "滑鼠左鍵"
		MOUSE_BUTTON_RIGHT: return "滑鼠右鍵"
		MOUSE_BUTTON_MIDDLE: return "滑鼠中鍵"
		MOUSE_BUTTON_WHEEL_UP: return "滾輪向上"
		MOUSE_BUTTON_WHEEL_DOWN: return "滾輪向下"
		MOUSE_BUTTON_XBUTTON1: return "滑鼠側鍵 1"
		MOUSE_BUTTON_XBUTTON2: return "滑鼠側鍵 2"
	return "按鍵 %d" % btn


## 畫面按鈕上顯示的提示,例如 "Z";沒綁定時回傳 ""。
func hint(id: String) -> String:
	for s in KEY_SLOTS:
		if map[id]["keys"][s] != 0:
			return key_text(id, s)
	if map[id]["mouse"] != 0:
		return mouse_text(id)
	return ""


func to_dict() -> Dictionary:
	var d := {}
	for id in map:
		d[id] = {"keys": map[id]["keys"].duplicate(), "mouse": map[id]["mouse"]}
	return d


## 載入(JSON 還原後數字是 float)。未知動作略過;缺少的動作維持預設;重複的鍵以先出現者為準。
func from_dict(d: Dictionary) -> void:
	reset()
	var used_keys := {}
	var used_mouse := {}
	var absent: Array[String] = []
	for e in action_list():
		var id: String = e[0]
		if not d.has(id) or not (d[id] is Dictionary):
			absent.append(id)
			continue
		var src: Dictionary = d[id]
		var keys: Array = [0, 0]
		var raw: Array = src["keys"] if src.get("keys") is Array else []
		for s in KEY_SLOTS:
			var c := int(raw[s]) if s < raw.size() else 0
			if c != 0 and (RESERVED_KEYS.has(c) or used_keys.has(c)):
				c = 0
			if c != 0:
				used_keys[c] = true
			keys[s] = c
		var m := int(src.get("mouse", 0))
		if m != 0 and (not MOUSE_ALLOWED.has(m) or used_mouse.has(m)):
			m = 0
		if m != 0:
			used_mouse[m] = true
		map[id] = {"keys": keys, "mouse": m}
	# 檔案裡沒有的動作用預設鍵,但不得與已指定的衝突
	for id in absent:
		for s in KEY_SLOTS:
			var c: int = map[id]["keys"][s]
			if c != 0 and used_keys.has(c):
				map[id]["keys"][s] = 0
			elif c != 0:
				used_keys[c] = true
		var m: int = map[id]["mouse"]
		if m != 0 and used_mouse.has(m):
			map[id]["mouse"] = 0
		elif m != 0:
			used_mouse[m] = true
