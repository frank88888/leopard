class_name DoubleUp
extends RefCounted
## 比大小。兩種玩法,期望值都是 0(猜對 ×2、猜錯歸零、和局保留):
## - dice:兩顆骰子,和 2~12。小=2~6、大=8~12、7=和局。
## - banqi:翻暗棋。從一副 32 枚暗棋抽兩枚蓋著的棋子(不放回),玩家選左或右,另一枚歸莊家。
##   階級 帥>仕>相>俥>傌>炮>兵,兵吃帥(帥不吃兵),同階級和局,不分紅黑。

enum Guess { SMALL, BIG }  ## banqi 時 SMALL = 翻左、BIG = 翻右
enum Result { WIN, LOSE, PUSH }

const STYLES := ["dice", "banqi"]

## 階級 0..6:帥 仕 相 俥 傌 炮 兵。棋子代碼 = side * 7 + rank(side 0 = 紅、1 = 黑)。
const RANK_COUNT := [1, 2, 2, 2, 2, 2, 5]  ## 每方各階級枚數
const PIECE_NAMES := [["帥", "仕", "相", "俥", "傌", "炮", "兵"], ["將", "士", "象", "車", "馬", "包", "卒"]]
const SOLDIER := 6
const GENERAL := 0

static var _pool: Array[int] = []


static func roll(rng: RandomNumberGenerator) -> Array[int]:
	return [rng.randi_range(1, 6), rng.randi_range(1, 6)]


static func judge(guess: int, total: int) -> int:
	if total == 7:
		return Result.PUSH
	var is_big := total > 7
	if (guess == Guess.BIG) == is_big:
		return Result.WIN
	return Result.LOSE


# ---------- 暗棋 ----------

## 整副 32 枚暗棋的代碼。
static func banqi_pool() -> Array[int]:
	if _pool.is_empty():
		for side in 2:
			for rank in RANK_COUNT.size():
				for k in RANK_COUNT[rank]:
					_pool.append(side * 7 + rank)
	return _pool


## 抽兩枚不同的棋子:[左, 右]。
static func draw_pair(rng: RandomNumberGenerator) -> Array[int]:
	var pool := banqi_pool()
	var a := rng.randi_range(0, pool.size() - 1)
	var b := rng.randi_range(0, pool.size() - 2)
	if b >= a:
		b += 1
	return [pool[a], pool[b]]


static func rank_of(piece: int) -> int:
	return piece % 7


static func side_of(piece: int) -> int:
	return piece / 7


static func piece_name(piece: int) -> String:
	return PIECE_NAMES[side_of(piece)][rank_of(piece)]


## 階級 a 能否吃階級 b。
static func beats(a: int, b: int) -> bool:
	if a == b:
		return false
	if a == SOLDIER and b == GENERAL:
		return true
	if a == GENERAL and b == SOLDIER:
		return false
	return a < b


static func judge_banqi(mine: int, theirs: int) -> int:
	var a := rank_of(mine)
	var b := rank_of(theirs)
	if beats(a, b):
		return Result.WIN
	if beats(b, a):
		return Result.LOSE
	return Result.PUSH
