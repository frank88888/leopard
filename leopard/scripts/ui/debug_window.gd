class_name DebugWindow
extends Panel
## DEBUG 模式的浮動視窗:執行中即時調整各音效的合成參數(滑桿 + 直接輸入數值),可拖曳標題列移動。
## 調整只影響本次執行,不寫入存檔;「複製變更」可把與出廠值不同的參數貼出來。

const TEXT := Color("e8e4ff")
const GOLD := Color("ffd84a")

var main: Control
var sfx: SfxPlayer

var _sounds: Array = []
var _key := ""
var _rows: VBoxContainer
var _picker: OptionButton
var _auto_preview := true
var _status: Label
var _dragging := false
var _sliders := {}
var _spins := {}
var _shape_opt: OptionButton


func setup(main_node: Control) -> void:
	main = main_node
	sfx = main.sfx
	position = Vector2(30, 520)
	size = Vector2(1020, 840)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.16, 0.96)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = 12
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	# 標題列(可拖曳)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_on_bar_input)
	box.add_child(bar)
	var title := _lbl("DEBUG ‧ 音效參數(拖曳此列移動)", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)
	var hide_b := _btn("收起", Vector2(110, 52), 26)
	hide_b.pressed.connect(func(): visible = false)
	bar.add_child(hide_b)

	# 音效選擇
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 8)
	box.add_child(sel)
	var prev := _btn("◀", Vector2(70, 60), 28)
	var nxt := _btn("▶", Vector2(70, 60), 28)
	_picker = OptionButton.new()
	_picker.custom_minimum_size = Vector2(0, 60)
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.add_theme_font_size_override("font_size", 28)
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.get_popup().add_theme_font_size_override("font_size", 28)
	_sounds = sfx.sound_list()
	for e in _sounds:
		_picker.add_item(e[1])
	_picker.item_selected.connect(_select)
	prev.pressed.connect(func(): _step(-1))
	nxt.pressed.connect(func(): _step(1))
	sel.add_child(prev)
	sel.add_child(_picker)
	sel.add_child(nxt)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)

	# 下方按鈕
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	box.add_child(acts)
	var play_b := _btn("試聽", Vector2(0, 64), 28)
	play_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_b.pressed.connect(func(): sfx.preview(_key))
	acts.add_child(play_b)
	var auto_b := _btn("調整後自動試聽:開", Vector2(0, 64), 26)
	auto_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_b.toggle_mode = true
	auto_b.button_pressed = true
	auto_b.toggled.connect(func(on: bool):
		_auto_preview = on
		auto_b.text = "調整後自動試聽:%s" % ("開" if on else "關"))
	acts.add_child(auto_b)
	var acts2 := HBoxContainer.new()
	acts2.add_theme_constant_override("separation", 8)
	box.add_child(acts2)
	var reset_b := _btn("還原此音效", Vector2(0, 64), 26)
	reset_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_b.pressed.connect(func():
		sfx.reset_sound(_key)
		_load_rows()
		_status.text = "已還原此音效")
	acts2.add_child(reset_b)
	var reset_all_b := _btn("全部還原", Vector2(0, 64), 26)
	reset_all_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_all_b.pressed.connect(func():
		sfx.reset_all_sounds()
		_load_rows()
		_status.text = "已還原所有音效")
	acts2.add_child(reset_all_b)
	var copy_b := _btn("複製變更", Vector2(0, 64), 26)
	copy_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_b.pressed.connect(func():
		var txt := sfx.export_changes()
		DisplayServer.clipboard_set(txt)
		_status.text = "已複製到剪貼簿:\n" + txt)
	acts2.add_child(copy_b)
	_status = _lbl("", 22, Color("9fe8a8"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	_select(0)


func _select(i: int) -> void:
	_picker.select(i)
	_key = _sounds[i][0]
	_status.text = ""
	_load_rows()


func _step(d: int) -> void:
	_select(posmod(_picker.selected + d, _sounds.size()))


func _load_rows() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_sliders = {}
	_spins = {}
	var cur := sfx.get_params(_key)
	for sp in SfxPlayer.PARAMS:
		_add_param_row(sp, float(cur[sp[0]]))
	# 波形
	var r := _row("波形")
	_shape_opt = OptionButton.new()
	_shape_opt.custom_minimum_size = Vector2(0, 56)
	_shape_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_opt.add_theme_font_size_override("font_size", 26)
	_shape_opt.get_popup().add_theme_font_size_override("font_size", 26)
	_shape_opt.focus_mode = Control.FOCUS_NONE
	for s in SfxPlayer.SHAPES:
		_shape_opt.add_item({"sine": "正弦波 sine", "square": "方波 square", "tri": "三角波 tri"}[s])
	_shape_opt.select(SfxPlayer.SHAPES.find(cur["shape"]))
	_shape_opt.item_selected.connect(func(idx: int):
		sfx.set_param(_key, "shape", SfxPlayer.SHAPES[idx])
		_after_change())
	r.add_child(_shape_opt)


func _add_param_row(sp: Array, value: float) -> void:
	var pname: String = sp[0]
	var r := _row(sp[1])
	var sl := HSlider.new()
	sl.min_value = sp[2]
	sl.max_value = sp[3]
	sl.step = sp[4]
	sl.value = value
	sl.custom_minimum_size = Vector2(0, 56)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	_style_bar(sl)
	r.add_child(sl)
	var sp_box := SpinBox.new()
	sp_box.min_value = sp[2]
	sp_box.max_value = sp[3]
	sp_box.step = sp[4]
	sp_box.value = value
	sp_box.custom_minimum_size = Vector2(190, 56)
	sp_box.get_line_edit().add_theme_font_size_override("font_size", 26)
	r.add_child(sp_box)
	_sliders[pname] = sl
	_spins[pname] = sp_box
	sl.value_changed.connect(func(v: float):
		sp_box.set_value_no_signal(v)
		sfx.set_param(_key, pname, v))
	sl.drag_ended.connect(func(_c: bool): _after_change())
	sp_box.value_changed.connect(func(v: float):
		sl.set_value_no_signal(v)
		sfx.set_param(_key, pname, v)
		_after_change())


## 長條圖樣式:深色底槽 + 金色填滿到目前值。
func _style_bar(sl: HSlider) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("22203a")
	bg.border_color = Color("8880d0")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.content_margin_top = 18
	bg.content_margin_bottom = 18
	var fill := bg.duplicate() as StyleBoxFlat
	fill.bg_color = Color("d9a82a")
	fill.border_color = Color("ffd84a")
	sl.add_theme_stylebox_override("slider", bg)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)


func _after_change() -> void:
	if _auto_preview:
		sfx.preview(_key)


func _on_bar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
	elif e is InputEventMouseMotion and _dragging:
		position += e.relative
		position = position.clamp(Vector2(-size.x + 120, 0), get_viewport_rect().size - Vector2(120, 60))


func _row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	_rows.add_child(r)
	var l := _lbl(label, 28)
	l.custom_minimum_size = Vector2(170, 56)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(l)
	return r


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
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		match st:
			"normal": sb.bg_color = Color("3a3270")
			"hover": sb.bg_color = Color("4a4290")
			"pressed": sb.bg_color = Color("6a5ac0")
			"disabled": sb.bg_color = Color("22203a")
		sb.border_color = Color("8880d0")
		b.add_theme_stylebox_override(st, sb)
	return b
