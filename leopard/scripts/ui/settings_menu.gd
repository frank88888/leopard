class_name SettingsMenu
extends Control
## 設定選單:主頁(分類)→ 細項頁。聲音 / 顯示 / 遊戲 / 輸入控制 / 讀取進度 / 儲存進度 / 還原預設。
## 所有變更立即生效並寫入 user://prefs.json。

const TEXT := Color("e8e4ff")
const DIM := Color("9a94c8")

var main: Control
var prefs: UserPrefs

var _title: Label
var _content: VBoxContainer
var _status: Label
var _back: Button
var _page := "root"
var _confirm := ""  ## 等待「再按一次確認」的操作
var _capture := {}  ## 正在等待按鍵 / 滑鼠鍵的欄位 {"id", "kind": "key"|"mouse", "slot"}
var _bind_buttons := {}  ## "id|k0" / "id|k1" / "id|m" → Button
var _load_opts := {"with_prefs": true}


func setup(main_node: Control) -> void:
	main = main_node
	prefs = main.prefs
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.12, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 30
	box.offset_bottom = -30
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_title = _lbl("設定", 52, Color("ffd84a"))
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_status = _lbl("", 28, Color("9fe8a8"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_back = _btn("關閉設定", Vector2(0, 90), 38)
	_back.pressed.connect(_on_back)
	box.add_child(_back)


func open(page := "root") -> void:
	prefs = main.prefs
	visible = true
	main.update_debug()
	_show(page)


func close() -> void:
	visible = false
	_capture = {}
	main._refresh()
	main.update_debug()


func _on_back() -> void:
	if _page == "root":
		close()
	else:
		_show("root")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if not _capture.is_empty():
			_capture_key(k.physical_keycode)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _capture.is_empty() and _capture["kind"] == "mouse":
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			return  # 左鍵保留給畫面按鈕(包含點選別的欄位)
		_capture_mouse(m.button_index)
		get_viewport().set_input_as_handled()


# ---------- 頁面切換 ----------

func _show(page: String) -> void:
	_page = page
	_confirm = ""
	_capture = {}
	_status.text = ""
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_bind_buttons = {}
	_back.text = "關閉設定" if _page == "root" else "← 返回上層"
	match _page:
		"root":
			_title.text = "設定"
			_build_root()
		"audio":
			_title.text = "設定 › 聲音"
			_build_audio()
		"display":
			_title.text = "設定 › 顯示"
			_build_display()
		"game":
			_title.text = "設定 › 遊戲"
			_build_game()
		"mode":
			_title.text = "設定 › 模式"
			_build_mode()
		"controls":
			_title.text = "設定 › 輸入控制"
			_build_controls()
		"load":
			_title.text = "設定 › 讀取進度"
			_build_slots(false)
		"save":
			_title.text = "設定 › 儲存進度"
			_build_slots(true)


func _changed(preview := "") -> void:
	main.prefs_changed()
	if preview != "":
		main.sfx.play(preview)


# ---------- 主頁 ----------

func _build_root() -> void:
	var a := prefs.audio
	var used := 0
	for i in SaveSlots.COUNT:
		if not SaveSlots.summary(i)["empty"]:
			used += 1
	var items := [
		["audio", "聲音", "靜音" if a["mute"] else "主音量 %d%%" % roundi(a["master"] * 100.0)],
		["display", "顯示", "全螢幕:%s" % ("開" if prefs.display["fullscreen"] else "關")],
		["game", "遊戲", "動畫速度 ×%.1f" % prefs.game["anim_speed"]],
		["controls", "輸入控制", "鍵盤 + 滑鼠 自訂按鍵"],
		["mode", "模式", "DEBUG(調整視窗)" if prefs.game["mode"] == "debug" else "正常"],
		["load", "讀取進度", "已存 %d / %d 欄" % [used, SaveSlots.COUNT]],
		["save", "儲存進度", "CREDIT %d  WIN %d" % [main.game.credit, main.game.win]],
		["reset", "還原預設值", "聲音 / 顯示 / 遊戲 / 按鍵"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for it in items:
		var key: String = it[0]
		var b := _btn("%s\n%s" % [it[1], it[2]], Vector2(0, 170), 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == "reset":
			if _confirm == "reset":
				b.text = "再按一次確認\n還原所有設定"
			b.pressed.connect(_on_reset)
		else:
			b.pressed.connect(_show.bind(key))
		grid.add_child(b)


func _on_reset() -> void:
	if _confirm != "reset":
		_confirm = "reset"
		_rebuild()
		return
	prefs.reset_all()
	main.prefs_changed()
	_show("root")
	_status.text = "已還原為預設值(存檔欄位不受影響)"


# ---------- 聲音 ----------

func _build_audio() -> void:
	_slider_row("主音量", prefs.audio, "master", 0.0, 1.0, 0.05, func(v): return "%d%%" % roundi(v * 100.0), "bet")
	_toggle_row("靜音", prefs.audio, "mute")
	_cycle_row("轉燈聲音", prefs.audio, "tick", UserPrefs.TICK_STYLES, "tick")
	_slider_row("轉燈音高", prefs.audio, "tick_pitch", 0.5, 2.0, 0.05, func(v): return "×%.2f" % v, "tick")
	_cycle_row("投注聲音", prefs.audio, "bet", UserPrefs.BET_STYLES, "bet")
	_cycle_row("投幣聲音", prefs.audio, "coin", UserPrefs.COIN_STYLES, "coin")
	_cycle_row("中獎聲音", prefs.audio, "win", UserPrefs.WIN_STYLES, "win")
	_reset_button("audio", "還原聲音預設")


# ---------- 顯示 ----------

func _build_display() -> void:
	_toggle_row("全螢幕", prefs.display, "fullscreen")
	_cycle_row("中央底板顏色", prefs.display, "theme", UserPrefs.THEMES)
	_cycle_row("跑燈燈號大小", prefs.display, "led_size", UserPrefs.LED_SIZES)
	_toggle_row("大獎閃光", prefs.display, "jackpot_flash")
	_toggle_row("按鈕顯示按鍵提示", prefs.display, "key_hints")
	_reset_button("display", "還原顯示預設")


# ---------- 遊戲 ----------

func _build_game() -> void:
	_slider_row("動畫速度", prefs.game, "anim_speed", 0.5, 2.0, 0.1, func(v): return "×%.1f" % v)
	var note := _lbl("只改變跑燈與提示的節奏,不影響機率與結果。", 26, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)
	_reset_button("game", "還原遊戲預設")


# ---------- 模式 ----------

func _build_mode() -> void:
	_cycle_row("執行模式", prefs.game, "mode", UserPrefs.MODES)
	var note := _lbl("DEBUG 模式:關閉設定後會出現浮動的調整視窗,可在執行中用滑桿或直接輸入數值調整各音效(轉燈、押分、投幣、中獎…)的音高、長度、振幅、衰減、噪音、波形。視窗可拖曳;調整只影響本次執行,不會存檔,也不影響機率與結果。", 26, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


# ---------- 輸入控制 ----------

func _build_controls() -> void:
	var note := _lbl("點選欄位後按下想指定的鍵(或滑鼠右鍵 / 中鍵 / 滾輪 / 側鍵)。\nDelete 或 Backspace 清除欄位;Esc 取消。保留鍵:Esc、Home、End。同一個鍵只能指定給一個動作。", 24, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)
	var head := HBoxContainer.new()
	_content.add_child(head)
	for e in [["動作", 220], ["按鍵 1", 220], ["按鍵 2", 220], ["滑鼠", 300]]:
		var l := _lbl(e[0], 26, Color("ffd84a"))
		l.custom_minimum_size = Vector2(e[1], 0)
		head.add_child(l)
	for e in InputBindings.action_list():
		var id: String = e[0]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		_content.add_child(r)
		var l := _lbl(e[1], 28)
		l.custom_minimum_size = Vector2(212, 0)
		r.add_child(l)
		for s in InputBindings.KEY_SLOTS:
			var b := _btn("", Vector2(212, 60), 26)
			b.pressed.connect(_begin_capture.bind(id, "key", s))
			r.add_child(b)
			_bind_buttons["%s|k%d" % [id, s]] = b
		var mb := _btn("", Vector2(292, 60), 26)
		mb.pressed.connect(_begin_capture.bind(id, "mouse", 0))
		r.add_child(mb)
		_bind_buttons["%s|m" % id] = mb
	_refresh_bind_buttons()
	_reset_button("controls", "還原按鍵預設")


func _refresh_bind_buttons() -> void:
	var bd := prefs.bindings
	for id in bd.map:
		for s in InputBindings.KEY_SLOTS:
			var b: Button = _bind_buttons.get("%s|k%d" % [id, s])
			if b != null:
				b.text = bd.key_text(id, s)
		var mb: Button = _bind_buttons.get("%s|m" % id)
		if mb != null:
			mb.text = bd.mouse_text(id)
	if not _capture.is_empty():
		var key := "%s|k%d" % [_capture["id"], _capture["slot"]] if _capture["kind"] == "key" else "%s|m" % _capture["id"]
		var cb: Button = _bind_buttons.get(key)
		if cb != null:
			cb.text = "請按下…" if _capture["kind"] == "key" else "請按滑鼠鍵…"


func _begin_capture(id: String, kind: String, slot: int) -> void:
	_capture = {"id": id, "kind": kind, "slot": slot}
	_status.text = ""
	_refresh_bind_buttons()


func _capture_key(code: int) -> void:
	var id: String = _capture["id"]
	var slot: int = _capture["slot"]
	if code == KEY_ESCAPE:
		_capture = {}
		_status.text = "已取消"
	elif code == KEY_DELETE or code == KEY_BACKSPACE:
		prefs.bindings.clear_key(id, slot)
		_capture = {}
		_status.text = "已清除"
		_changed()
	else:
		var taken := prefs.bindings.set_key(id, slot, code)
		if taken == "!":
			_status.text = "「%s」是保留鍵,不能指定" % OS.get_keycode_string(code)
		else:
			_capture = {}
			_status.text = "已指定「%s」" % OS.get_keycode_string(code) + ("(原本屬於「%s」,已移除)" % _action_label(taken) if taken != "" else "")
			_changed()
	_refresh_bind_buttons()


func _capture_mouse(btn: int) -> void:
	var id: String = _capture["id"]
	var taken := prefs.bindings.set_mouse(id, btn)
	if taken == "!":
		_status.text = "這個滑鼠鍵不能指定"
	else:
		_capture = {}
		_status.text = "已指定「%s」" % InputBindings.mouse_name(btn) + ("(原本屬於「%s」,已移除)" % _action_label(taken) if taken != "" else "")
		_changed()
	_refresh_bind_buttons()


func _action_label(id: String) -> String:
	for e in InputBindings.action_list():
		if e[0] == id:
			return e[1]
	return id


# ---------- 讀取 / 儲存 ----------

func _build_slots(saving: bool) -> void:
	var info: Label = null
	if saving:
		info = _lbl("目前:CREDIT %d    WIN %d" % [main.game.credit, main.game.win], 30, Color("6fe0ff"))
	if info != null:
		_content.add_child(info)
	else:
		_toggle_row("同時還原當時的自訂設定", _load_opts, "with_prefs", false)
	if not main.can_manage_saves():
		var warn := _lbl("遊戲進行中,請等這一局結束後再操作。", 28, Color("ffb070"))
		_content.add_child(warn)
	for i in SaveSlots.COUNT:
		var sm := SaveSlots.summary(i)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		_content.add_child(r)
		var key := "%s%d" % ["save" if saving else "load", i]
		var text := ""
		if sm["empty"]:
			text = "槽 %d    (空)" % (i + 1)
		else:
			text = "槽 %d    %s\nCREDIT %d    WIN %d" % [i + 1, sm["date"], sm["credit"], sm["win"]]
		if _confirm == key:
			text = "槽 %d    再按一次確認%s" % [i + 1, "覆蓋" if saving else "讀取"]
		var b := _btn(text, Vector2(0, 104), 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = (not saving and sm["empty"]) or not main.can_manage_saves()
		b.pressed.connect(_on_slot.bind(i, saving, not sm["empty"]))
		r.add_child(b)
		if not sm["empty"]:
			var del := _btn("確認刪除" if _confirm == "del%d" % i else "刪除", Vector2(170, 104), 28)
			del.pressed.connect(_on_delete.bind(i))
			r.add_child(del)


func _on_slot(i: int, saving: bool, occupied: bool) -> void:
	var key := "%s%d" % ["save" if saving else "load", i]
	if occupied and _confirm != key:
		_confirm = key
		_rebuild()
		return
	_confirm = ""
	if saving:
		var ok: bool = main.save_to_slot(i)
		_rebuild()
		_status.text = "已儲存到槽 %d" % (i + 1) if ok else "儲存失敗"
	else:
		var ok: bool = main.load_from_slot(i, _load_opts["with_prefs"])
		_rebuild()
		_status.text = "已讀取槽 %d" % (i + 1) if ok else "讀取失敗(檔案不存在或已損毀)"


func _on_delete(i: int) -> void:
	if _confirm != "del%d" % i:
		_confirm = "del%d" % i
		_rebuild()
		return
	_confirm = ""
	SaveSlots.delete(i)
	_rebuild()
	_status.text = "已刪除槽 %d" % (i + 1)


# ---------- 共用元件 ----------

func _row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	_content.add_child(r)
	var l := _lbl(label, 32)
	l.custom_minimum_size = Vector2(330, 64)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(l)
	return r


func _slider_row(label: String, sect: Dictionary, key: String, lo: float, hi: float, step: float, fmt: Callable, preview := "") -> void:
	var r := _row(label)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(sect[key])
	sl.custom_minimum_size = Vector2(380, 64)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.focus_mode = Control.FOCUS_NONE
	r.add_child(sl)
	var val := _lbl(fmt.call(sl.value), 30)
	val.custom_minimum_size = Vector2(120, 0)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(val)
	sl.value_changed.connect(func(v: float):
		sect[key] = v
		val.text = fmt.call(v)
		main.apply_prefs())
	sl.drag_ended.connect(func(_changed_flag: bool): _changed(preview))


func _toggle_row(label: String, sect: Dictionary, key: String, apply := true) -> void:
	var r := _row(label)
	var b := _btn("", Vector2(200, 64), 32)
	b.toggle_mode = true
	b.button_pressed = bool(sect[key])
	b.text = "開" if b.button_pressed else "關"
	b.toggled.connect(func(on: bool):
		sect[key] = on
		b.text = "開" if on else "關"
		if apply:
			_changed())
	r.add_child(b)


func _cycle_row(label: String, sect: Dictionary, key: String, list: Array, preview := "") -> void:
	var r := _row(label)
	var prev := _btn("◀", Vector2(76, 64), 30)
	var name_l := _lbl("", 30, Color("fff2b0"))
	name_l.custom_minimum_size = Vector2(240, 64)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var nxt := _btn("▶", Vector2(76, 64), 30)
	var refresh := func(): name_l.text = UserPrefs.choice_name(list, sect[key])
	var step := func(d: int):
		var ids := UserPrefs.choices(list)
		var cur := ids.find(sect[key])
		sect[key] = ids[posmod(cur + d, ids.size())]
		refresh.call()
		_changed(preview)
	prev.pressed.connect(func(): step.call(-1))
	nxt.pressed.connect(func(): step.call(1))
	refresh.call()
	r.add_child(prev)
	r.add_child(name_l)
	r.add_child(nxt)
	if preview != "":
		var t := _btn("試聽", Vector2(110, 64), 28)
		t.pressed.connect(func(): main.sfx.play(preview))
		r.add_child(t)


func _reset_button(section: String, text: String) -> void:
	var b := _btn(text, Vector2(0, 80), 32)
	b.pressed.connect(func():
		prefs.reset_section(section)
		main.prefs_changed()
		_rebuild()
		_status.text = "已還原")
	_content.add_child(b)


func _lbl(text: String, fsize: int, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l


func _btn(text: String, min_size: Vector2, fsize: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(3)
		match st:
			"normal": sb.bg_color = Color("3a3270")
			"hover": sb.bg_color = Color("4a4290")
			"pressed": sb.bg_color = Color("6a5ac0")
			"disabled": sb.bg_color = Color("22203a")
		sb.border_color = Color("8880d0") if st != "disabled" else Color("3a3858")
		b.add_theme_stylebox_override(st, sb)
	return b
