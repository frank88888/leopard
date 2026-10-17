class_name Ring
extends RefCounted
## 32 格環:索引 0 = 上邊中間(BAR),順時針。

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


## 索引 → 9x9 方環上的 (col,row),順時針,索引 0 在上邊正中 (4,0)。
static func grid_pos(idx: int) -> Vector2i:
	idx = posmod(idx, GameConfig.RING_SIZE)
	if idx <= 4:
		return Vector2i(4 + idx, 0)
	if idx <= 12:
		return Vector2i(8, idx - 4)
	if idx <= 20:
		return Vector2i(8 - (idx - 12), 8)
	if idx <= 28:
		return Vector2i(0, 8 - (idx - 20))
	return Vector2i(idx - 28, 0)
