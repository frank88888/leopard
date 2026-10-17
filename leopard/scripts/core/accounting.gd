class_name Accounting
extends RefCounted
## 帳務:分「本期」與「總計」兩組。

const KEYS := ["coins", "bet", "payout", "collected", "rounds", "luck", "luck_miss", "bonus_spins", "du_win", "du_lose"]

var period: Dictionary = {}
var total: Dictionary = {}
var symbol_hits_period: Array[int] = []
var symbol_hits_total: Array[int] = []


func _init(symbol_count: int = 8) -> void:
	for k in KEYS:
		period[k] = 0
		total[k] = 0
	symbol_hits_period.resize(symbol_count)
	symbol_hits_period.fill(0)
	symbol_hits_total.resize(symbol_count)
	symbol_hits_total.fill(0)


func add(key: String, n: int) -> void:
	period[key] += n
	total[key] += n


func hit(symbol: int) -> void:
	symbol_hits_period[symbol] += 1
	symbol_hits_total[symbol] += 1


## 實際 RTP = 收分 / 押注(以已收分計)
static func rtp_of(d: Dictionary) -> float:
	if d["bet"] <= 0:
		return 0.0
	return float(d["collected"]) / float(d["bet"])


func reset_period() -> void:
	for k in KEYS:
		period[k] = 0
	symbol_hits_period.fill(0)


func to_csv(symbol_names: Array[String]) -> String:
	var lines: Array[String] = ["項目,本期,總計"]
	for k in KEYS:
		lines.append("%s,%d,%d" % [k, period[k], total[k]])
	lines.append("rtp,%.4f,%.4f" % [rtp_of(period), rtp_of(total)])
	for i in symbol_names.size():
		lines.append("hit_%s,%d,%d" % [symbol_names[i], symbol_hits_period[i], symbol_hits_total[i]])
	return "\n".join(lines) + "\n"


func serialize() -> Dictionary:
	return {"period": period, "total": total, "hp": symbol_hits_period, "ht": symbol_hits_total}


func restore(d: Dictionary) -> void:
	for k in KEYS:
		period[k] = int(d["period"].get(k, 0))
		total[k] = int(d["total"].get(k, 0))
	for i in symbol_hits_period.size():
		symbol_hits_period[i] = int(d["hp"][i])
		symbol_hits_total[i] = int(d["ht"][i])
