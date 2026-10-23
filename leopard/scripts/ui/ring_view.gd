class_name RingView
extends Control
## 7x7 方環跑燈:24 格,索引 0 在上邊正中,順時針。

const CELL := 128.0

var cells: Array[int] = []
var ids: Array[String] = []
var glow: Array[float] = []  ## 每格亮度 0~1,逐格衰減形成拖尾
var flash: Dictionary = {}  ## 閃爍中的格 idx → true
var jackpot_flash := 0.0
var rest_cell := -1  ## 待機時持續亮著的格(上局停止格)
var led_scale := 1.0  ## 跑燈 LED 大小倍率
var theme_fill := Color("1a3fa8")  ## 中央底板顏色
var theme_edge := Color("0a1f6a")
var skin := "fruit"
var icons: Array[SymbolIcon] = []
var _t := 0.0

const THEME_COLORS := {
	"blue": ["1a3fa8", "0a1f6a"],
	"green": ["14753a", "0a4a22"],
	"red": ["a8261a", "6a120a"],
	"purple": ["5a2aa8", "34156a"],
}
const LED_SCALES := {"small": 0.75, "medium": 1.0, "large": 1.35}


func setup(ring_cells: Array[int], symbol_ids: Array[String]) -> void:
	cells = ring_cells
	ids = symbol_ids
	glow.resize(GameConfig.RING_SIZE)
	glow.fill(0.0)
	custom_minimum_size = Vector2(CELL * 7, CELL * 7)
	size = custom_minimum_size
	for i in GameConfig.RING_SIZE:
		var icon := SymbolIcon.new("luck" if cells[i] == GameConfig.LUCK else ids[cells[i]])
		var p := cell_rect(i)
		icon.position = p.position + Vector2(8, 8)
		icon.size = p.size - Vector2(16, 16)
		add_child(icon)
		icons.append(icon)


func cell_rect(i: int) -> Rect2:
	var g := Ring.grid_pos(i)
	return Rect2(Vector2(g.x, g.y) * CELL, Vector2(CELL, CELL))


func set_theme_name(id: String) -> void:
	var c: Array = THEME_COLORS.get(id, THEME_COLORS["blue"])
	theme_fill = Color(c[0])
	theme_edge = Color(c[1])


func set_skin(id: String) -> void:
	skin = id
	for icon in icons:
		icon.skin = id
	queue_redraw()


func light(i: int) -> void:
	glow[i] = 1.0


func clear_lights() -> void:
	glow.fill(0.0)
	flash.clear()


func _process(delta: float) -> void:
	_t += delta
	for i in glow.size():
		if glow[i] > 0.0:
			glow[i] = maxf(0.0, glow[i] - delta * 5.0)
	if jackpot_flash > 0.0:
		jackpot_flash = maxf(0.0, jackpot_flash - delta)
	queue_redraw()


func _draw() -> void:
	var blink := int(_t * 6.0) % 2 == 0
	# 中央藍色底板(參考機台風格)
	draw_rect(Rect2(Vector2(CELL, CELL), Vector2(CELL * 5, CELL * 5)), theme_fill)
	draw_rect(Rect2(Vector2(CELL, CELL), Vector2(CELL * 5, CELL * 5)), theme_edge, false, 6.0)
	if skin == "chess":
		_draw_board(Rect2(Vector2(CELL, CELL), Vector2(CELL * 5, CELL * 5)).grow(-CELL * 0.35))
	for i in glow.size():
		var r := cell_rect(i).grow(-3)
		draw_rect(r, Color("f4f1e6"))
		draw_rect(r, Color("8a8570"), false, 2.0)
		var g := glow[i]
		if i == rest_cell:
			g = maxf(g, 0.8)
		if flash.has(i):
			g = 1.0 if blink else 0.15
		# 格子內側(朝中央)的紅色跑燈點
		var c := cell_rect(i).get_center()
		var g2 := Ring.grid_pos(i)
		var inward := Vector2(signf(3.0 - g2.x), signf(3.0 - g2.y))
		var on_x_edge := g2.x == 0 or g2.x == 6
		var on_y_edge := g2.y == 0 or g2.y == 6
		if on_y_edge and not on_x_edge:
			inward.x = 0.0  # 上/下邊:燈在圖示內側邊的正中央
		elif on_x_edge and not on_y_edge:
			inward.y = 0.0  # 左/右邊同理
		var dot := c + inward * CELL * 0.5
		var led := Vector2(32, 20) * led_scale
		_led(dot, led, Color("5a1010"))
		if g > 0.0:
			draw_rect(r, Color(1.0, 0.85, 0.2, 0.35 * g))
			draw_rect(r, Color(1.0, 0.2, 0.2, g), false, 5.0)
			_led(dot, led + Vector2(10, 10) * g, Color(1.0, 0.15, 0.15, 0.4 * g))
			_led(dot, led, Color(1.0, 0.35, 0.3, g))
	if jackpot_flash > 0.0:
		var a := 0.5 * jackpot_flash * (1.0 if blink else 0.4)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.9, 0.3, a))


## 象棋主題:中央底板淡淡畫一張棋盤(9 直線 × 10 橫線,中間楚河漢界)。
func _draw_board(r: Rect2) -> void:
	var col := Color(1, 1, 1, 0.22)
	var dx := r.size.x / 8.0
	var dy := r.size.y / 9.0
	for k in 10:
		var y := r.position.y + dy * k
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col, 2.0)
	for k in 9:
		var x := r.position.x + dx * k
		if k == 0 or k == 8:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), col, 2.0)
		else:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + dy * 4), col, 2.0)
			draw_line(Vector2(x, r.position.y + dy * 5), Vector2(x, r.end.y), col, 2.0)
	for top in [r.position.y, r.position.y + dy * 7]:  # 九宮斜線
		var a := Vector2(r.position.x + dx * 3, top)
		draw_line(a, a + Vector2(dx * 2, dy * 2), col, 2.0)
		draw_line(a + Vector2(dx * 2, 0), a + Vector2(0, dy * 2), col, 2.0)
	var font := ThemeDB.fallback_font
	var fs := int(dy * 0.6)
	var ty := r.position.y + dy * 4.5 + fs * 0.36
	for e in [["楚 河", 0.25], ["漢 界", 0.75]]:
		var w := font.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(r.position.x + r.size.x * e[1] - w / 2.0, ty), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.3))


## 圓角方形 LED(非正方形)。
func _led(center: Vector2, sz: Vector2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(center - sz / 2.0, sz))
