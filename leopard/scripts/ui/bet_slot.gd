class_name BetSlot
extends Control
## 一個押注視窗:圖案、倍率、目前押注額、上局押注(淡色)。整個視窗即押注鍵。

signal pressed(index: int)
signal released(index: int)

var index := 0
var mult := 0
var bet := 0:
	set(v):
		bet = v
		queue_redraw()
var last_bet := 0:
	set(v):
		last_bet = v
		queue_redraw()
var flashing := false:
	set(v):
		flashing = v
		queue_redraw()
var held := false:
	set(v):
		held = v
		queue_redraw()
var icon: SymbolIcon
var _t := 0.0


func setup(i: int, symbol_id: String, multiplier: int) -> void:
	index = i
	mult = multiplier
	icon = SymbolIcon.new(symbol_id)
	icon.position = Vector2(4, 10)
	icon.size = Vector2(size.x - 8, size.x - 8)
	add_child(icon)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed.emit(index)
		else:
			released.emit(index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and held:
		released.emit(index)


func _process(delta: float) -> void:
	if flashing:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var bright := not flashing or int(_t * 6.0) % 2 == 0
	var bg := Color("2a2440")
	if flashing and bright:
		bg = Color("8a6a10")
	elif held:
		bg = Color("3a3460")
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(Rect2(Vector2.ZERO, size), Color("ffd84a") if flashing else Color("5a5480"), false, 3.0)
	var font := ThemeDB.fallback_font
	var y1 := size.x + 22.0
	var txt := "x%d" % mult
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(font, Vector2((size.x - w) / 2.0, y1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ffe27a"))
	var s := str(bet) if bet > 0 else (str(last_bet) if last_bet > 0 else "0")
	var col := Color("ffffff") if bet > 0 else (Color(1, 1, 1, 0.3) if last_bet > 0 else Color(1, 1, 1, 0.25))
	var fs := 46
	w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) / 2.0, size.y - 14.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
