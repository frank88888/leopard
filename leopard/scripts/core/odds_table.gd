class_name OddsTable
extends RefCounted
## 機率表:p_i = c / 倍率_i,c = RTP目標 / (1 + 平均送燈次數 × LUCK機率)。
## 剩餘機率為「LUCK 空燈」(停在 LUCK 格但不送燈)。
## 送燈中的每一抽不會再連鎖送燈(抽到 LUCK 視為空燈),所以每抽期望回報恆為 c。

enum Kind { SYMBOL, LUCK, LUCK_MISS }

var probs: Array[float] = []  ## 各符號機率
var p_luck := 0.0
var p_miss := 0.0
var c := 0.0


static func build(multipliers: Array[int], rtp_target: float, luck_prob: float, bonus_weights: Dictionary) -> OddsTable:
	var t := OddsTable.new()
	var e := Bonus.expected_count(bonus_weights)
	t.c = rtp_target / (1.0 + e * luck_prob)
	var sum := 0.0
	for m in multipliers:
		var p := t.c / float(m)
		t.probs.append(p)
		sum += p
	t.p_luck = luck_prob
	t.p_miss = 1.0 - sum - luck_prob
	assert(t.p_miss >= -1e-9, "odds overflow: lower rtp_target or luck_bonus_prob")
	t.p_miss = maxf(t.p_miss, 0.0)
	return t


## 回傳 {kind, symbol}。allow_chain=false 時 LUCK 轉為空燈(送燈中使用)。
func draw(rng: RandomNumberGenerator, allow_chain := true) -> Dictionary:
	var r := rng.randf()
	var acc := 0.0
	for i in probs.size():
		acc += probs[i]
		if r < acc:
			return {"kind": Kind.SYMBOL, "symbol": i}
	acc += p_luck
	if r < acc and allow_chain:
		return {"kind": Kind.LUCK, "symbol": GameConfig.LUCK}
	return {"kind": Kind.LUCK_MISS, "symbol": GameConfig.LUCK}
