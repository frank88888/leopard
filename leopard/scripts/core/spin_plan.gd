class_name SpinPlan
extends RefCounted
## 跑燈步進間隔。加速依自由落體 Δ_n = Δ1·(√n − √(n−1)),等速,減速為加速的時間反轉。
## 保證 (start + 總步數) mod 24 == target。

var intervals: Array[float] = []  ## 第 k 步前的等待秒數
var accel_steps := 0
var cruise_steps := 0
var decel_steps := 0


static func build(start: int, target: int, cruise_laps: int, first_interval: float, min_interval: float) -> SpinPlan:
	var n_ring := GameConfig.RING_SIZE
	var p := SpinPlan.new()
	var accel: Array[float] = []
	var n := 1
	while true:
		var d := first_interval * (sqrt(float(n)) - sqrt(float(n - 1)))
		if d <= min_interval:
			break
		accel.append(d)
		n += 1
	p.accel_steps = accel.size()
	p.decel_steps = accel.size()
	var rest := posmod(target - start - p.accel_steps - p.decel_steps, n_ring)
	p.cruise_steps = cruise_laps * n_ring + rest
	p.intervals.append_array(accel)
	for i in p.cruise_steps:
		p.intervals.append(min_interval)
	for i in range(accel.size() - 1, -1, -1):
		p.intervals.append(accel[i])
	return p


func total_steps() -> int:
	return intervals.size()


func total_time() -> float:
	var t := 0.0
	for d in intervals:
		t += d
	return t
