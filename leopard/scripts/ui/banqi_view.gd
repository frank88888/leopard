class_name BanqiView
extends Control
## 翻暗棋比大小:左右兩枚蓋著的棋子,翻開後標示「你」與「莊」。

const R := 62.0

var pieces: Array[int] = [0, 0]
var revealed: Array[bool] = [false, false]
var flip_scale: Array[float] = [1.0, 1.0]  ## 翻面動畫的水平縮放(0 = 側面)
var wobble: Array[float] = [0.0, 0.0]  ## 洗牌時的左右晃動
var mine := -1  ## 玩家選的那一枚(0 = 左、1 = 右),-1 = 尚未選


func _init() -> void:
	custom_minimum_size = Vector2(360, 170)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 兩枚都蓋回去。
func reset() -> void:
	revealed = [false, false]
	flip_scale = [1.0, 1.0]
	wobble = [0.0, 0.0]
	mine = -1
	queue_redraw()


func _center(k: int) -> Vector2:
	return Vector2(90.0 + k * 180.0 + wobble[k], R + 6.0)


func _draw() -> void:
	for k in 2:
		var c := _center(k)
		draw_set_transform(c, 0.0, Vector2(maxf(flip_scale[k], 0.02), 1.0))
		if revealed[k]:
			var p := pieces[k]
			SymbolIcon.draw_piece(self, Vector2.ZERO, R, DoubleUp.piece_name(p), SymbolIcon.RED if DoubleUp.side_of(p) == 0 else SymbolIcon.BLACK)
		else:
			SymbolIcon.draw_piece(self, Vector2.ZERO, R, "", Color.BLACK)
		draw_set_transform(Vector2.ZERO)
		if mine >= 0:
			var tag := "你" if k == mine else "莊"
			var font := ThemeDB.fallback_font
			var fs := 30
			var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(c.x - w / 2.0, size.y - 4.0)
			draw_string_outline(font, pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
			draw_string(font, pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd84a") if k == mine else Color("c8c8e0"))
