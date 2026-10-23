class_name TopMenuBar
extends Control
## 畫面最上方的選單列(像一般應用程式):點標題展開下拉選單,點選項執行,點別處關閉。
## 選單內容由 add_menu 的 items 回呼在每次展開時產生,所以按鍵提示等文字永遠是最新的。

const H := 56
const BAR_BG := Color("1a1633")
const TEXT := Color("e8e4ff")

var _titles := HBoxContainer.new()
var _menus: Array = []  ## {"btn": Button, "items": Callable}
var _catcher: Control  ## 展開時蓋住下方畫面,點擊即關閉
var _drop: PanelContainer
var _drop_box: VBoxContainer
var _open_idx := -1


func setup(width: float, height: float) -> void:
	position = Vector2.ZERO
	size = Vector2(width, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = BAR_BG
	bg.size = Vector2(width, H)
	add_child(bg)
	var line := ColorRect.new()
	line.color = Color("3a3270")
	line.position = Vector2(0, H - 2)
	line.size = Vector2(width, 2)
	add_child(line)
	_titles.position = Vector2(8, 0)
	_titles.size = Vector2(width - 16, H - 2)
	_titles.add_theme_constant_override("separation", 4)
	add_child(_titles)

	_catcher = Control.new()
	_catcher.position = Vector2(0, H)
	_catcher.size = Vector2(width, height - H)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	_catcher.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close_menu())
	add_child(_catcher)
	_drop = PanelContainer.new()
	_drop.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("22204a")
	sb.border_color = Color("8880d0")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	_drop.add_theme_stylebox_override("panel", sb)
	_drop_box = VBoxContainer.new()
	_drop_box.add_theme_constant_override("separation", 4)
	_drop.add_child(_drop_box)
	add_child(_drop)


## items:Callable,回傳 [[文字, Callable, 是否可按(預設 true)], ...]。回傳 index。
func add_menu(title: String, items: Callable) -> int:
	var b := Button.new()
	b.text = "%s ▾" % title
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, H - 2)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for st in ["hover", "pressed"]:
		var h := StyleBoxFlat.new()
		h.bg_color = Color("3a3270")
		b.add_theme_stylebox_override(st, h)
	var idx := _menus.size()
	b.pressed.connect(func(): toggle_menu(idx))
	_titles.add_child(b)
	_menus.append({"btn": b, "items": items})
	return idx


func set_menu_visible(idx: int, on: bool) -> void:
	_menus[idx]["btn"].visible = on
	if not on and _open_idx == idx:
		close_menu()


func toggle_menu(idx: int) -> void:
	if _open_idx == idx:
		close_menu()
		return
	_open(idx)


func close_menu() -> void:
	_open_idx = -1
	_catcher.visible = false
	_drop.visible = false


func is_open() -> bool:
	return _open_idx >= 0


func _open(idx: int) -> void:
	for c in _drop_box.get_children():
		_drop_box.remove_child(c)
		c.queue_free()
	var b: Button = _menus[idx]["btn"]
	for it in _menus[idx]["items"].call():
		var item := Button.new()
		item.text = it[0]
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.focus_mode = Control.FOCUS_NONE
		item.custom_minimum_size = Vector2(320, 60)
		item.add_theme_font_size_override("font_size", 28)
		item.disabled = it.size() > 2 and not it[2]
		for st in ["normal", "hover", "pressed", "disabled"]:
			var s := StyleBoxFlat.new()
			s.set_content_margin_all(12)
			s.bg_color = Color("22204a") if st != "hover" and st != "pressed" else Color("4a4290")
			item.add_theme_stylebox_override(st, s)
		var cb: Callable = it[1]
		item.pressed.connect(func():
			close_menu()
			cb.call())
		_drop_box.add_child(item)
	_open_idx = idx
	_catcher.visible = true
	_drop.visible = true
	_drop.reset_size()
	_drop.position = Vector2(b.global_position.x, H)
