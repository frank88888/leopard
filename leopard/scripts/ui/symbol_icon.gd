class_name SymbolIcon
extends Control
## 以向量方式繪製 8 種圖案與 LUCK(自製素材,無版權問題;日後可整批換成 sprites)。

var symbol_id := "bar":
	set(v):
		symbol_id = v
		queue_redraw()
var dim := 1.0:
	set(v):
		dim = v
		queue_redraw()


func _init(id := "bar") -> void:
	symbol_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	var c := size / 2.0
	match symbol_id:
		"bar": _bar(c, s)
		"s77": _seven(c, s)
		"star":
			_star(c + Vector2(-s * 0.22, s * 0.05), s * 0.27)
			_star(c + Vector2(s * 0.22, -s * 0.05), s * 0.27)
		"melon":
			_melon(c + Vector2(-s * 0.2, 0), s * 0.2)
			_melon(c + Vector2(s * 0.2, 0), s * 0.2)
		"bell":
			_bell(c + Vector2(-s * 0.2, 0), s * 0.2)
			_bell(c + Vector2(s * 0.2, 0), s * 0.2)
		"green": _green(c, s)
		"orange": _orange(c, s)
		"lychee": _lychee(c, s)
		"luck": _luck(c, s)


func _col(col: Color) -> Color:
	return Color(col.r * dim, col.g * dim, col.b * dim, col.a)


func _ellipse(center: Vector2, r: Vector2, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	draw_colored_polygon(pts, _col(col))


func _text(text: String, center: Vector2, fsize: int, col: Color, outline := Color.BLACK) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var pos := center + Vector2(-w.x / 2.0, fsize * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, maxi(2, fsize / 8), _col(outline))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, _col(col))


func _bar(c: Vector2, s: float) -> void:
	var r := Rect2(c - Vector2(s * 0.46, s * 0.26), Vector2(s * 0.92, s * 0.52))
	draw_rect(r, _col(Color("e8c030")))
	draw_rect(r.grow(-s * 0.04), _col(Color("111111")))
	_text("BAR", c, int(s * 0.36), Color("ffd84a"), Color("000000"))


func _seven(c: Vector2, s: float) -> void:
	_text("77", c, int(s * 0.62), Color("e8202a"), Color("ffffff"))


func _star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, _col(Color("ffd21f")))
	pts.append(pts[0])
	draw_polyline(pts, _col(Color("b87800")), 2.0)


func _melon(c: Vector2, r: float) -> void:
	# 切半西瓜:上方半圓(外綠內紅),種子
	var pts_o := PackedVector2Array()
	var pts_i := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		pts_o.append(c + Vector2(cos(a) * r * 1.2, sin(a) * r * 1.6))
		pts_i.append(c + Vector2(cos(a) * r * 1.0, sin(a) * r * 1.35))
	draw_colored_polygon(pts_o, _col(Color("2e8b2e")))
	draw_colored_polygon(pts_i, _col(Color("e8344a")))
	for p in [Vector2(-0.4, 0.45), Vector2(0.0, 0.8), Vector2(0.4, 0.45), Vector2(0.0, 0.35)]:
		_ellipse(c + Vector2(p.x * r, p.y * r * 1.1), Vector2(r * 0.07, r * 0.12), Color("111111"))


func _bell(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(c + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.9 - r * 0.1))
	pts.append(c + Vector2(r * 1.25, r * 1.0))
	pts.append(c + Vector2(-r * 1.25, r * 1.0))
	draw_colored_polygon(pts, _col(Color("f5b800")))
	draw_polyline(pts, _col(Color("9a6a00")), 2.0)
	_ellipse(c + Vector2(0, r * 1.15), Vector2(r * 0.28, r * 0.28), Color("9a6a00"))
	_ellipse(c + Vector2(-r * 0.3, -r * 0.2), Vector2(r * 0.12, r * 0.35), Color("fff1a0"))


func _green(c: Vector2, s: float) -> void:
	_ellipse(c, Vector2(s * 0.24, s * 0.36), Color("4fbf3a"), 0.5)
	_ellipse(c + Vector2(-s * 0.06, -s * 0.08), Vector2(s * 0.07, s * 0.16), Color("b9f090"), 0.5)
	draw_line(c + Vector2(s * 0.15, -s * 0.32), c + Vector2(s * 0.24, -s * 0.42), _col(Color("2f6a1a")), 4.0)


func _orange(c: Vector2, s: float) -> void:
	_ellipse(c, Vector2(s * 0.34, s * 0.34), Color("ff8a00"))
	_ellipse(c + Vector2(-s * 0.1, -s * 0.1), Vector2(s * 0.09, s * 0.06), Color("ffc060"), -0.7)
	_ellipse(c + Vector2(s * 0.1, -s * 0.33), Vector2(s * 0.12, s * 0.05), Color("2f9a2a"), -0.5)


func _lychee(c: Vector2, s: float) -> void:
	for p in [Vector2(-0.16, 0.12), Vector2(0.16, 0.12), Vector2(0.0, -0.02), Vector2(-0.08, 0.3), Vector2(0.12, 0.3)]:
		var pc: Vector2 = c + p * s
		_ellipse(pc, Vector2(s * 0.14, s * 0.14), Color("d82f45"))
		_ellipse(pc + Vector2(-s * 0.04, -s * 0.04), Vector2(s * 0.04, s * 0.04), Color("ff9aa6"))
	draw_line(c + Vector2(0, -s * 0.1), c + Vector2(s * 0.04, -s * 0.3), _col(Color("5a3a1a")), 3.0)
	_ellipse(c + Vector2(s * 0.14, -s * 0.28), Vector2(s * 0.14, s * 0.05), Color("2f9a2a"), -0.4)


func _luck(c: Vector2, s: float) -> void:
	_ellipse(c, Vector2(s * 0.4, s * 0.4), Color("7a2fd0"))
	_ellipse(c, Vector2(s * 0.33, s * 0.33), Color("a860ff"))
	_text("LUCK", c, int(s * 0.24), Color("ffffff"), Color("3a0a70"))
