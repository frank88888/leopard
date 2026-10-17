class_name DiceView
extends Control
## 比大小的兩顆骰子。

var faces: Array[int] = [1, 1]


func _init() -> void:
	custom_minimum_size = Vector2(360, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_faces(a: int, b: int) -> void:
	faces = [a, b]
	queue_redraw()


func _draw() -> void:
	for k in 2:
		var r := Rect2(Vector2(20 + k * 190, 10), Vector2(140, 140))
		draw_rect(r, Color("f4f0e8"))
		draw_rect(r, Color("222222"), false, 4.0)
		for p in _pips(faces[k]):
			draw_circle(r.position + r.size * p, 13.0, Color("c01020") if faces[k] == 1 else Color("181818"))


func _pips(n: int) -> Array:
	var tl := Vector2(0.27, 0.27)
	var tr := Vector2(0.73, 0.27)
	var ml := Vector2(0.27, 0.5)
	var mr := Vector2(0.73, 0.5)
	var bl := Vector2(0.27, 0.73)
	var br := Vector2(0.73, 0.73)
	var c := Vector2(0.5, 0.5)
	match n:
		1: return [c]
		2: return [tl, br]
		3: return [tl, c, br]
		4: return [tl, tr, bl, br]
		5: return [tl, tr, c, bl, br]
		_: return [tl, tr, ml, mr, bl, br]
