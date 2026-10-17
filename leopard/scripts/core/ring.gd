class_name Ring
extends RefCounted
## 24 格環:索引 0 = 上邊中間(BAR),順時針。

var cells: Array[int] = []


func _init(layout: Array[int]) -> void:
	assert(layout.size() == GameConfig.RING_SIZE)
	cells = layout


func cells_of(symbol: int) -> Array[int]:
	var out: Array[int] = []
	for i in cells.size():
		if cells[i] == symbol:
			out.append(i)
	return out


func pick_cell(rng: RandomNumberGenerator, symbol: int) -> int:
	var c := cells_of(symbol)
	assert(not c.is_empty(), "no cell for symbol %d" % symbol)
	return c[rng.randi_range(0, c.size() - 1)]


## 索引 → 7x7 方環上的 (col,row),順時針,索引 0 在上邊正中 (3,0)。
static func grid_pos(idx: int) -> Vector2i:
	idx = posmod(idx, GameConfig.RING_SIZE)
	if idx <= 3:
		return Vector2i(3 + idx, 0)
	if idx <= 9:
		return Vector2i(6, idx - 3)
	if idx <= 15:
		return Vector2i(6 - (idx - 9), 6)
	if idx <= 21:
		return Vector2i(0, 6 - (idx - 15))
	return Vector2i(idx - 21, 0)
