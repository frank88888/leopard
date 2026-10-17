class_name Bonus
extends RefCounted
## LUCK 送燈:額外抽 1~3 次,依權重。


static func draw_count(rng: RandomNumberGenerator, weights: Dictionary) -> int:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var r := rng.randi_range(1, total)
	var acc := 0
	var keys := weights.keys()
	keys.sort()
	for k in keys:
		acc += int(weights[k])
		if r <= acc:
			return int(k)
	return int(keys.back())


static func expected_count(weights: Dictionary) -> float:
	var total := 0.0
	var e := 0.0
	for k in weights:
		total += float(weights[k])
		e += float(k) * float(weights[k])
	return e / total
