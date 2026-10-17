class_name GameState
extends RefCounted
## 遊戲規則核心,不依賴任何 UI。UI 呼叫方法、監聽 signal。

signal changed  ## CREDIT / WIN / 押注任一改變
signal round_started(round: Dictionary)
signal round_finished(round: Dictionary)
signal collected(amount: int)
signal doubled(info: Dictionary)

enum Phase { IDLE, SPINNING, WIN_PENDING }

var cfg: GameConfig
var odds: OddsTable
var ring: Ring
var bets: BetManager
var acct: Accounting
var rng := RandomNumberGenerator.new()

var credit := 0
var win := 0
var phase: int = Phase.IDLE
var last_stop := 0  ## 上局停止格(第一局為 0 = BAR)
var du_count := 0  ## 本次得分已連續猜對次數
var round_data: Dictionary = {}  ## 進行中 / 最近一局


func _init(config: GameConfig, seed_value: int = -1) -> void:
	cfg = config
	odds = OddsTable.build(cfg.multipliers, cfg.rtp_target, cfg.luck_bonus_prob, cfg.bonus_weights)
	ring = Ring.new(cfg.ring_cells)
	bets = BetManager.new(cfg.symbol_count(), cfg.bet_cap())
	acct = Accounting.new(cfg.symbol_count())
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## 後台改完設定後重建機率表與押注上限。
func reload_config() -> void:
	odds = OddsTable.build(cfg.multipliers, cfg.rtp_target, cfg.luck_bonus_prob, cfg.bonus_weights)
	bets.cap = cfg.bet_cap()
	changed.emit()


# ---------- 投幣 / 押注 ----------

func insert_coin(value: int) -> void:
	if value <= 0:
		return
	credit += value
	acct.add("coins", value)
	changed.emit()


## 押注鍵一次動作。回傳是否真的加了(連按時回傳 false 就該停止連加)。
func add_bet(i: int, step: int) -> bool:
	if phase == Phase.SPINNING:
		return false
	if not bets.can_add(i, step, credit):
		return false
	bets.add(i, step)
	credit -= step
	changed.emit()
	return true


# ---------- 啟動 / 續押 ----------

## 回傳 {ok:bool, reason:String, round:Dictionary}
func start() -> Dictionary:
	if phase == Phase.SPINNING:
		return {"ok": false, "reason": "spinning"}
	if win > 0:
		collect()  # 已確認:WIN > 0 時按啟動 → 先自動收分
	var repeated := false
	if bets.total() == 0:
		if bets.last_total() == 0 or credit <= 0:
			return {"ok": false, "reason": "no_bet"}
		var last_total := bets.last_total()
		var plan: Array[int] = bets.last_bets.duplicate() if credit >= last_total else BetManager.scale_to(bets.last_bets, credit)
		for i in plan.size():
			bets.bets[i] = plan[i]
		credit -= bets.total()
		repeated = true
	bets.remember()
	round_data = _resolve()
	round_data["repeated"] = repeated
	phase = Phase.SPINNING
	acct.add("bet", bets.total())
	acct.add("rounds", 1)
	changed.emit()
	round_started.emit(round_data)
	return {"ok": true, "reason": "", "round": round_data}


## 先決定整局結果(含送燈),動畫之後才播放。
func _resolve() -> Dictionary:
	var spins: Array = []
	var total_win := 0
	var start_cell := last_stop
	var first := odds.draw(rng)
	spins.append(_make_spin(first, false))
	if first["kind"] == OddsTable.Kind.LUCK:
		var n := Bonus.draw_count(rng, cfg.bonus_weights)
		for k in n:
			spins.append(_make_spin(odds.draw(rng, false), true))
	var jackpot := false
	for sp in spins:
		total_win += sp["win"]
		if sp["win"] > 0 and cfg.jackpot_symbols.has(sp["symbol"]):
			jackpot = true
	if total_win >= cfg.jackpot_threshold():
		jackpot = true
	last_stop = spins.back()["cell"]
	return {
		"bets": bets.bets.duplicate(),
		"spins": spins,
		"total_win": total_win,
		"jackpot": jackpot,
		"start_cell": start_cell,
	}


func _make_spin(outcome: Dictionary, is_bonus: bool) -> Dictionary:
	var sym: int = outcome["symbol"]
	return {
		"kind": outcome["kind"],
		"symbol": sym,
		"cell": ring.pick_cell(rng, sym),
		"win": Payout.spin_win(bets.bets, cfg.multipliers, sym),
		"bonus": is_bonus,
	}


## 動畫播完(或斷電復原)後呼叫:結算並進入 WIN_PENDING / IDLE。
func finish_round() -> void:
	if phase != Phase.SPINNING:
		return
	var tw: int = round_data["total_win"]
	for sp in round_data["spins"]:
		if sp["kind"] == OddsTable.Kind.SYMBOL:
			acct.hit(sp["symbol"])
		elif sp["kind"] == OddsTable.Kind.LUCK:
			acct.add("luck", 1)
		else:
			acct.add("luck_miss", 1)
		if sp["bonus"]:
			acct.add("bonus_spins", 1)
	win += tw
	acct.add("payout", tw)
	bets.clear()
	du_count = 0
	phase = Phase.WIN_PENDING if win > 0 else Phase.IDLE
	changed.emit()
	round_finished.emit(round_data)


# ---------- 收分 / 比大小 ----------

func collect() -> int:
	if win <= 0 or phase == Phase.SPINNING:
		return 0
	var amount := win
	credit += amount
	win = 0
	du_count = 0
	phase = Phase.IDLE
	acct.add("collected", amount)
	changed.emit()
	collected.emit(amount)
	return amount


func can_double() -> bool:
	return phase == Phase.WIN_PENDING and win > 0 and du_count < int(cfg.s["double_up_max"]) and win < int(cfg.s["win_cap"])


## guess: DoubleUp.Guess。回傳 {dice, total, result, win}
func double_up(guess: int) -> Dictionary:
	if not can_double():
		return {}
	var dice := DoubleUp.roll(rng)
	var total: int = dice[0] + dice[1]
	var res := DoubleUp.judge(guess, total)
	match res:
		DoubleUp.Result.WIN:
			win = mini(win * 2, int(cfg.s["win_cap"]))
			du_count += 1
			acct.add("du_win", 1)
		DoubleUp.Result.LOSE:
			win = 0
			du_count = 0
			phase = Phase.IDLE
			acct.add("du_lose", 1)
	var info := {"dice": dice, "total": total, "result": res, "win": win}
	changed.emit()
	doubled.emit(info)
	return info


# ---------- 存檔 ----------

func serialize() -> Dictionary:
	return {
		"credit": credit,
		"win": win,
		"phase": phase,
		"last_stop": last_stop,
		"du_count": du_count,
		"bets": bets.bets,
		"last_bets": bets.last_bets,
		"round": round_data,
		"acct": acct.serialize(),
	}


func restore(d: Dictionary) -> void:
	if d.is_empty():
		return
	credit = int(d["credit"])
	win = int(d["win"])
	phase = int(d["phase"])
	last_stop = int(d["last_stop"])
	du_count = int(d["du_count"])
	for i in bets.bets.size():
		bets.bets[i] = int(d["bets"][i])
		bets.last_bets[i] = int(d["last_bets"][i])
	round_data = _fix_round(d.get("round", {}))
	acct.restore(d["acct"])
	if phase == Phase.SPINNING:
		finish_round()  # 斷電復原:依存檔結果補完結算,不重抽
	changed.emit()


## JSON 還原後數值為 float,轉回 int。
func _fix_round(r: Dictionary) -> Dictionary:
	if r.is_empty():
		return r
	var out := {
		"bets": [],
		"spins": [],
		"total_win": int(r["total_win"]),
		"jackpot": bool(r["jackpot"]),
		"start_cell": int(r["start_cell"]),
		"repeated": bool(r.get("repeated", false)),
	}
	for b in r["bets"]:
		out["bets"].append(int(b))
	for sp in r["spins"]:
		out["spins"].append({
			"kind": int(sp["kind"]),
			"symbol": int(sp["symbol"]),
			"cell": int(sp["cell"]),
			"win": int(sp["win"]),
			"bonus": bool(sp["bonus"]),
		})
	return out
