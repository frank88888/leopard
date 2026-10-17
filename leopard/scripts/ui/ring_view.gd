class_name RingView
extends Control
## 9x9 方環跑燈:32 格,索引 0 在上邊正中,順時針。

const CELL := 100.0

var cells: Array[int] = []
var ids: Array[String] = []
var glow: Array[float] = []  ## 每格亮度 0~1,逐格衰減形成拖尾
var flash: Dictionary = {}  ## 閃爍中的格 idx → true
var jackpot_flash := 0.0
var rest_cell := -1  ## 待機時持續亮著的格(上局停止格)
var _t := 0.0


func setup(ring_cells: Array[int], symbol_ids: Array[String]) -> void:
	cells = ring_cells
	ids = symbol_ids
	glow.resize(GameConfig.RING_SIZE)
	glow.fill(0.0)
	custom_minimum_size = Vector2(CELL * 9, CELL * 9)
	size = custom_minimum_size
	for i in GameConfig.RING_SIZE:
		var icon := SymbolIcon.new("luck" if cells[i] == GameConfig.LUCK else ids[cells[i]])
		var p := cell_rect(i)
		icon.position = p.position + Vector2(8, 8)
		icon.size = p.size - Vector2(16, 16)
		add_child(icon)


func cell_rect(i: int) -> Rect2:
	var g := Ring.grid_pos(i)
	return Rect2(Vector2(g.x, g.y) * CELL, Vector2(CELL, CELL))


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
	for i in glow.size():
		var r := cell_rect(i).grow(-3)
		var base := Color("1c1830")
		draw_rect(r, base)
		var g := glow[i]
		if i == rest_cell:
			g = maxf(g, 0.8)
		if flash.has(i):
			g = 1.0 if blink else 0.15
		if g > 0.0:
			draw_rect(r, Color(1.0, 0.85, 0.2, 0.55 * g))
			draw_rect(r, Color(1.0, 0.95, 0.5, g), false, 5.0)
		else:
			draw_rect(r, Color("4a4468"), false, 2.0)
	if jackpot_flash > 0.0:
		var a := 0.5 * jackpot_flash * (1.0 if blink else 0.4)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.9, 0.3, a))
