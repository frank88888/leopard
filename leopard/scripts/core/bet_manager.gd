class_name BetManager
extends RefCounted
## 押注與「上局押注記憶」。押注額已從 CREDIT 扣除,由 GameState 管理 CREDIT。

var bets: Array[int] = []
var last_bets: Array[int] = []
var cap := 99


func _init(count: int, bet_cap: int) -> void:
	cap = bet_cap
	bets.resize(count)
	bets.fill(0)
	last_bets.resize(count)
	last_bets.fill(0)


func total() -> int:
	return _sum(bets)


func last_total() -> int:
	return _sum(last_bets)


## 能否把 step 分加到項目 i(credit 為目前剩餘)。+10 不足或超上限即不可。
func can_add(i: int, step: int, credit: int) -> bool:
	return credit >= step and bets[i] + step <= cap


func add(i: int, step: int) -> void:
	bets[i] += step


func clear() -> void:
	bets.fill(0)


func remember() -> void:
	last_bets = bets.duplicate()


## 依占比縮放到 target_total,最大餘數法,加總恰等於 target_total。
static func scale_to(source: Array[int], target_total: int) -> Array[int]:
	var src_total := _sum(source)
	var out: Array[int] = []
	out.resize(source.size())
	out.fill(0)
	if src_total <= 0 or target_total <= 0:
		return out
	var rema: Array = []  # [index, 餘數分子]
	var given := 0
	for i in source.size():
		var num := source[i] * target_total
		out[i] = num / src_total
		given += out[i]
		rema.append([i, num % src_total])
	# 餘數大者優先,同餘數時索引小者優先(決定性)
	rema.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	var left := target_total - given
	var k := 0
	while left > 0:
		var idx: int = rema[k % rema.size()][0]
		if source[idx] > 0:
			out[idx] += 1
			left -= 1
		k += 1
	return out


static func _sum(a: Array[int]) -> int:
	var t := 0
	for v in a:
		t += v
	return t
