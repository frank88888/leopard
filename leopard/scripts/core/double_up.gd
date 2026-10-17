class_name DoubleUp
extends RefCounted
## 兩顆骰子,和 2~12。小=2~6、大=8~12、7=和局。

enum Guess { SMALL, BIG }
enum Result { WIN, LOSE, PUSH }


static func roll(rng: RandomNumberGenerator) -> Array[int]:
	return [rng.randi_range(1, 6), rng.randi_range(1, 6)]


static func judge(guess: int, total: int) -> int:
	if total == 7:
		return Result.PUSH
	var is_big := total > 7
	if (guess == Guess.BIG) == is_big:
		return Result.WIN
	return Result.LOSE
