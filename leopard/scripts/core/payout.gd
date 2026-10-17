class_name Payout
extends RefCounted


## 單次停燈的得分 = 該項目押注 × 倍率;LUCK(symbol < 0)不派彩。
static func spin_win(bets: Array[int], multipliers: Array[int], symbol: int) -> int:
	if symbol < 0:
		return 0
	return bets[symbol] * multipliers[symbol]
