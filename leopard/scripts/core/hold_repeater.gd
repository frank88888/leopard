class_name HoldRepeater
extends RefCounted
## 押注鍵長按邏輯(與 UI 無關,可單元測試)。
## 按下立即 +1;按住超過 t1 秒後每 interval 秒 +1;超過 t2 秒後每 interval 秒 +10。

var t1 := 1.0
var t2 := 3.0
var interval := 0.1
var holding := false
var held := 0.0
var _next := 0.0


func _init(first_sec := 1.0, second_sec := 3.0, repeat_sec := 0.1) -> void:
	t1 = first_sec
	t2 = second_sec
	interval = repeat_sec


## 回傳按下當下要加的分數(短按 +1)。
func press() -> int:
	holding = true
	held = 0.0
	_next = t1
	return 1


func release() -> void:
	holding = false


## 加分失敗(CREDIT 不足 / 上限)時呼叫:本次按住不再連加。
func stop() -> void:
	holding = false


## 推進時間,回傳這段時間內應連加的各次分數。
func update(delta: float) -> Array[int]:
	var out: Array[int] = []
	if not holding:
		return out
	held += delta
	while holding and held >= _next:
		out.append(10 if _next >= t2 else 1)
		_next += interval
	return out
