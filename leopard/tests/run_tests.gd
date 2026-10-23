extends SceneTree
## 輕量測試執行器(不依賴 GUT)。
## 執行:godot --headless --path . -s tests/run_tests.gd

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", label)


func _init() -> void:
	var cfg := GameConfig.load_default()
	test_config_and_ring(cfg)
	test_odds(cfg)
	test_bets(cfg)
	test_scale()
	test_start_rules(cfg)
	test_round_payout(cfg)
	test_spin_plan(cfg)
	test_double_up(cfg)
	test_hold()
	test_save(cfg)
	test_prefs(cfg)
	test_sfx_debug()
	test_rtp(cfg)
	print("passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_config_and_ring(cfg: GameConfig) -> void:
	print("ring")
	var cells := cfg.ring_cells
	check(cells.size() == 24, "24 cells")
	check(cells[0] == 0, "cell 0 is BAR")
	var counts := {}
	for c in cells:
		counts[c] = counts.get(c, 0) + 1
	var expect := {0: 1, 1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 4, 7: 5, GameConfig.LUCK: 2}
	check(counts == expect, "cell counts " + str(counts))
	for i in 24:
		check(cells[i] != cells[(i + 1) % 24], "no adjacent same at %d" % i)
	var seen := {}
	for i in 24:
		var p := Ring.grid_pos(i)
		check(p.x == 0 or p.x == 6 or p.y == 0 or p.y == 6, "on border %d" % i)
		seen[p] = true
	check(seen.size() == 24, "grid positions unique")
	check(Ring.grid_pos(0) == Vector2i(3, 0), "idx0 top middle")
	check(Ring.grid_pos(1) == Vector2i(4, 0), "idx1 moves right")
	check(Ring.grid_pos(3) == Vector2i(6, 0) and Ring.grid_pos(9) == Vector2i(6, 6), "corners")
	check(Ring.grid_pos(15) == Vector2i(0, 6) and Ring.grid_pos(21) == Vector2i(0, 0), "corners 2")


func test_odds(cfg: GameConfig) -> void:
	print("odds")
	var t := OddsTable.build(cfg.multipliers, cfg.rtp_target, cfg.luck_bonus_prob, cfg.bonus_weights)
	var sum := 0.0
	for i in t.probs.size():
		sum += t.probs[i]
		check(absf(t.probs[i] * cfg.multipliers[i] - t.c) < 1e-9, "p*m const %d" % i)
	check(absf(sum + t.p_luck + t.p_miss - 1.0) < 1e-9, "probs sum to 1")
	check(t.p_miss >= 0.0, "miss >= 0")
	check(absf(Bonus.expected_count({1: 60, 2: 30, 3: 10}) - 1.5) < 1e-9, "bonus E=1.5")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 2000:
		check(t.draw(rng, false)["kind"] != OddsTable.Kind.LUCK, "no chain")
		if i > 50:
			break


func test_bets(cfg: GameConfig) -> void:
	print("bets")
	var g := GameState.new(cfg, 1)
	g.insert_coin(5)
	check(g.credit == 5, "coin 1:1")
	check(g.add_bet(0, 1) and g.credit == 4 and g.bets.bets[0] == 1, "short press")
	check(not g.add_bet(0, 10), "+10 blocked when credit < 10")
	check(g.add_bet(0, 1), "+1 still ok")
	g.insert_coin(500)
	for i in 100:
		g.add_bet(1, 1)
	check(g.bets.bets[1] == 99, "cap 99")
	check(not g.add_bet(1, 1), "cap stops")
	g.bets.bets[2] = 95
	check(not g.add_bet(2, 10), "+10 exceeding cap blocked")
	check(g.add_bet(2, 1), "+1 under cap ok")
	var g2 := GameState.new(cfg, 1)
	g2.insert_coin(3)
	while g2.add_bet(3, 1):
		pass
	check(g2.credit == 0 and g2.bets.bets[3] == 3, "+1 stops at credit 0")


func test_scale() -> void:
	print("scale")
	var s: Array[int] = [10, 0, 0, 0, 0, 0, 0, 30]
	var want: Array[int] = [5, 0, 0, 0, 0, 0, 0, 15]
	check(BetManager.scale_to(s, 20) == want, "example 10/30 -> 5/15")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for n in 500:
		var src: Array[int] = []
		for i in 8:
			src.append(rng.randi_range(0, 99) if rng.randf() < 0.6 else 0)
		var tot := 0
		for v in src:
			tot += v
		if tot == 0:
			continue
		var target := rng.randi_range(1, tot)
		var out := BetManager.scale_to(src, target)
		var os := 0
		for i in 8:
			os += out[i]
			check(src[i] > 0 or out[i] == 0, "zero stays zero")
			check(out[i] <= src[i], "no growth")
		check(os == target, "sum equals target")


func test_start_rules(cfg: GameConfig) -> void:
	print("start")
	var g := GameState.new(cfg, 5)
	check(not g.start()["ok"], "no bet no start")
	g.insert_coin(100)
	g.add_bet(0, 1)
	g.add_bet(7, 1)
	g.add_bet(7, 1)
	var r := g.start()
	check(r["ok"], "start ok")
	check(not g.add_bet(1, 1), "no bet while spinning")
	check(not g.start()["ok"], "no start while spinning")
	g.finish_round()
	check(g.bets.total() == 0, "bets cleared")
	check(g.bets.last_bets[0] == 1 and g.bets.last_bets[7] == 2, "memory stored")
	var credit_before := g.credit + g.win
	# 續押:不改任何押注直接啟動(若有 WIN 會先自動收分)
	var r2 := g.start()
	check(r2["ok"] and r2["round"]["repeated"], "repeat start")
	check(r2["round"]["bets"][0] == 1 and r2["round"]["bets"][7] == 2, "repeat same bets")
	check(g.credit + g.win + 3 == credit_before, "repeat deducts 3")
	g.finish_round()
	# 不足續押 → 縮減
	var g3 := GameState.new(cfg, 5)
	g3.insert_coin(40)
	g3.add_bet(0, 10)
	for i in 30:
		g3.add_bet(7, 1)
	g3.bets.remember()
	g3.bets.clear()
	g3.credit = 20
	var r3 := g3.start()
	check(r3["ok"] and r3["round"]["bets"][0] == 5 and r3["round"]["bets"][7] == 15, "scaled 5/15")
	check(g3.credit == 0, "credit all used")
	check(g3.bets.last_bets[0] == 5 and g3.bets.last_bets[7] == 15, "memory overwritten by scaled")
	# CREDIT 0 不開局
	var g4 := GameState.new(cfg, 5)
	g4.bets.last_bets[0] = 5
	check(not g4.start()["ok"], "credit 0 no repeat")
	# 手動押注時不套用記憶
	var g5 := GameState.new(cfg, 5)
	g5.insert_coin(50)
	g5.bets.last_bets[0] = 20
	g5.add_bet(3, 1)
	var r5 := g5.start()
	check(r5["ok"] and not r5["round"]["repeated"] and r5["round"]["bets"][0] == 0, "manual bets ignore memory")
	# WIN>0 按啟動自動收分
	var g6 := GameState.new(cfg, 5)
	g6.insert_coin(10)
	g6.win = 40
	g6.phase = GameState.Phase.WIN_PENDING
	g6.add_bet(2, 1)
	var credit_start := g6.credit
	var r6 := g6.start()
	check(r6["ok"] and g6.win == 0 and g6.credit == credit_start + 40, "auto collect on start")


func test_round_payout(cfg: GameConfig) -> void:
	print("payout")
	check(Payout.spin_win([3, 0, 0, 0, 0, 0, 0, 0] as Array[int], cfg.multipliers, 0) == 150, "BAR x3 = 150")
	check(Payout.spin_win([3, 0, 0, 0, 0, 0, 0, 0] as Array[int], cfg.multipliers, GameConfig.LUCK) == 0, "luck 0")
	var g := GameState.new(cfg, 11)
	var wins := 0
	for n in 3000:
		g.credit = 1000
		for i in 8:
			g.add_bet(i, 1)
		var credit0 := g.credit
		var r: Dictionary = g.start()["round"]
		var sum := 0
		for sp in r["spins"]:
			sum += sp["win"]
			if sp["kind"] == OddsTable.Kind.SYMBOL:
				check(cfg.ring_cells[sp["cell"]] == sp["symbol"], "cell matches symbol")
			else:
				check(cfg.ring_cells[sp["cell"]] == GameConfig.LUCK, "luck cell")
			check(sp["bonus"] == (sp != r["spins"][0]), "bonus flag")
		check(sum == r["total_win"], "total_win sum")
		check(r["spins"].size() == 1 or r["spins"][0]["kind"] == OddsTable.Kind.LUCK, "bonus only after LUCK")
		check(r["spins"].size() <= 4, "<=3 bonus spins")
		g.finish_round()
		check(g.win == sum, "win credited")
		check(g.credit == credit0 and g.credit == 992, "bet deducted")
		g.collect()
		wins += sum
	check(g.phase == GameState.Phase.IDLE, "idle after collect")


func test_spin_plan(cfg: GameConfig) -> void:
	print("spin plan")
	var fi: float = cfg.s["first_interval"]
	var mi: float = cfg.s["min_interval"]
	for start in 24:
		for target in 24:
			var laps := 2 + (start + target) % 2
			var p := SpinPlan.build(start, target, laps, fi, mi)
			check((start + p.total_steps()) % 24 == target, "stop at target %d->%d" % [start, target])
			check(p.cruise_steps >= laps * 24, "cruise >= laps")
	var p0 := SpinPlan.build(0, 5, 2, fi, mi)
	for i in range(1, p0.accel_steps):
		check(p0.intervals[i] <= p0.intervals[i - 1], "accel monotonic")
	var n := p0.total_steps()
	for i in p0.accel_steps:
		check(absf(p0.intervals[i] - p0.intervals[n - 1 - i]) < 1e-9, "decel mirrors accel")
	check(p0.intervals[p0.accel_steps] == mi, "cruise at min interval")
	# 自由落體:第 n 步累積時間 ∝ √n
	var t := 0.0
	for i in 10:
		t += p0.intervals[i]
	check(absf(t - fi * sqrt(10.0)) < 1e-6, "free fall t_n = sqrt(n)")


func test_double_up(cfg: GameConfig) -> void:
	print("double up")
	var small := 0
	var big := 0
	var push := 0
	for a in range(1, 7):
		for b in range(1, 7):
			match DoubleUp.judge(DoubleUp.Guess.SMALL, a + b):
				DoubleUp.Result.WIN: small += 1
				DoubleUp.Result.PUSH: push += 1
			if DoubleUp.judge(DoubleUp.Guess.BIG, a + b) == DoubleUp.Result.WIN:
				big += 1
	check(small == 15 and big == 15 and push == 6, "15/15/6")
	var g := GameState.new(cfg, 9)
	g.win = 100
	g.phase = GameState.Phase.WIN_PENDING
	var seen_win := false
	var seen_lose := false
	for i in 200:
		g.win = 100
		g.phase = GameState.Phase.WIN_PENDING
		g.du_count = 0
		var r := g.double_up(DoubleUp.Guess.BIG)
		if r["result"] == DoubleUp.Result.WIN:
			check(g.win == 200, "win doubles")
			seen_win = true
		elif r["result"] == DoubleUp.Result.LOSE:
			check(g.win == 0 and g.phase == GameState.Phase.IDLE, "lose zeroes")
			seen_lose = true
		else:
			check(g.win == 100 and g.du_count == 0, "push keeps")
	check(seen_win and seen_lose, "both outcomes occur")
	g.win = 100
	g.phase = GameState.Phase.WIN_PENDING
	g.du_count = 10
	check(not g.can_double(), "max guesses reached")
	g.du_count = 0
	g.win = 9999
	check(not g.can_double(), "win cap reached")
	test_banqi(cfg)


func test_banqi(cfg: GameConfig) -> void:
	print("banqi double up")
	var pool := DoubleUp.banqi_pool()
	check(pool.size() == 32, "banqi pool has 32 pieces")
	check(pool.count(6) == 5 and pool.count(13) == 5 and pool.count(0) == 1 and pool.count(7) == 1, "5 soldiers / 1 general per side")
	check(DoubleUp.piece_name(0) == "帥" and DoubleUp.piece_name(7) == "將" and DoubleUp.piece_name(12) == "包", "piece names")
	check(DoubleUp.beats(6, 0) and not DoubleUp.beats(0, 6), "soldier beats general, not the reverse")
	check(DoubleUp.beats(0, 1) and DoubleUp.beats(5, 6) and not DoubleUp.beats(3, 3), "rank order, equal never beats")
	check(DoubleUp.judge_banqi(0, 7) == DoubleUp.Result.PUSH, "red vs black same rank is push")
	# 所有有序抽法(不放回):勝負次數必須相等 → 期望值 0
	var w := 0
	var l := 0
	var p := 0
	for a in pool.size():
		for b in pool.size():
			if a == b:
				continue
			match DoubleUp.judge_banqi(pool[a], pool[b]):
				DoubleUp.Result.WIN: w += 1
				DoubleUp.Result.LOSE: l += 1
				_: p += 1
	check(w == l, "banqi win count == lose count (%d / %d)" % [w, l])
	check(p == 152, "banqi push count 152 / 992")
	var g := GameState.new(cfg, 21)
	g.double_style = "banqi"
	var seen := {}
	for i in 300:
		g.win = 100
		g.phase = GameState.Phase.WIN_PENDING
		g.du_count = 0
		var guess := DoubleUp.Guess.SMALL if i % 2 == 0 else DoubleUp.Guess.BIG
		var r := g.double_up(guess)
		var pieces: Array = r["pieces"]
		check(r["style"] == "banqi" and pieces.size() == 2, "banqi info shape")
		check(r["mine"] == pieces[0 if guess == DoubleUp.Guess.SMALL else 1] and r["theirs"] == pieces[1 if guess == DoubleUp.Guess.SMALL else 0], "guess picks left / right")
		check(r["result"] == DoubleUp.judge_banqi(r["mine"], r["theirs"]), "banqi result matches judge")
		match r["result"]:
			DoubleUp.Result.WIN: check(g.win == 200, "banqi win doubles")
			DoubleUp.Result.LOSE: check(g.win == 0 and g.phase == GameState.Phase.IDLE, "banqi lose zeroes")
			_: check(g.win == 100, "banqi push keeps")
		seen[r["result"]] = true
	check(seen.size() == 3, "banqi: win, lose and push all occur")


func test_hold() -> void:
	print("hold repeater")
	var h := HoldRepeater.new(1.0, 3.0, 0.1)
	check(h.press() == 1, "press gives +1")
	check(h.update(0.5).is_empty(), "no repeat before 1s")
	check(h.update(0.49).is_empty(), "still none at 0.99s")
	var a := h.update(0.02)
	check(a.size() == 1 and a[0] == 1, "first +1 repeat after 1s")
	var total1 := 0
	var steps_before_3 := 0
	var t := 1.01
	while t < 2.99:
		for st in h.update(0.01):
			check(st == 1, "+1 between 1s and 3s")
			steps_before_3 += 1
		t += 0.01
	check(steps_before_3 >= 18 and steps_before_3 <= 21, "about 10/s: %d" % steps_before_3)
	var saw10 := false
	for i in 100:
		for st in h.update(0.01):
			check(st == 10, "+10 after 3s")
			saw10 = true
	check(saw10, "+10 appears")
	h.stop()
	check(h.update(5.0).is_empty(), "stopped")
	h.press()
	h.release()
	check(h.update(5.0).is_empty(), "released: no repeat")
	var h2 := HoldRepeater.new(1.0, 3.0, 0.1)
	h2.press()
	var big := h2.update(4.0)
	check(big.size() >= 29 and big.has(1) and big.has(10), "big frame produces multiple steps")


func test_save(cfg: GameConfig) -> void:
	print("save")
	var path := "user://test_save.json"
	var g := GameState.new(cfg, 21)
	g.insert_coin(80)
	g.add_bet(0, 2)
	g.add_bet(6, 3)
	g.start()
	check(SaveData.save(path, g.serialize()), "saved mid-spin")
	var d := SaveData.load_file(path)
	check(not d.is_empty(), "loads with checksum")
	var expected_win: int = g.round_data["total_win"]
	var g2 := GameState.new(cfg, 99)
	g2.restore(d)
	check(g2.win == expected_win, "recovered win from saved result, no re-draw")
	check(g2.phase != GameState.Phase.SPINNING, "recovered state settled")
	check(g2.credit == g.credit, "credit restored")
	check(g2.bets.last_bets[0] == 2 and g2.bets.last_bets[6] == 3, "memory restored")
	check(g2.acct.total["bet"] == 5, "accounting restored")
	# 竄改偵測
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_string(txt.replace("credit", "credix"))
	w.close()
	check(SaveData.load_file(path).is_empty(), "tamper detected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(SaveData.load_file("user://nope.json").is_empty(), "missing file empty")


func test_sfx_debug() -> void:
	var sfx := SfxPlayer.new()
	sfx._ready()  # 不掛進場景樹也能建立音效表
	var list := sfx.sound_list()
	check(list.size() == 20, "sfx: 20 tunable sounds")
	var key := "tick/relay"
	var before: int = sfx._wavs[key].data.size()
	sfx.set_param(key, "dur_mult", 2.0)
	check(absi(sfx._wavs[key].data.size() - before * 2) <= 4, "sfx: dur_mult doubles length")
	sfx.set_param(key, "amp", 99.0)
	check(is_equal_approx(sfx.get_params(key)["amp"], 1.5), "sfx: param clamped to range")
	sfx.set_param(key, "shape", "bogus")
	check(sfx.get_params(key)["shape"] == "sine", "sfx: invalid shape ignored")
	check(sfx.export_changes().begins_with("tick/relay:"), "sfx: export lists changes")
	sfx.reset_all_sounds()
	check(sfx.export_changes() == "(與出廠值相同)", "sfx: reset restores factory values")
	check(sfx._wavs[key].data.size() == before, "sfx: reset re-renders")
	var pr := UserPrefs.new()
	pr.game["mode"] = "junk"
	var pr2 := UserPrefs.new()
	pr2.from_dict(pr.to_dict())
	check(pr2.game["mode"] == "normal", "prefs: invalid mode falls back")
	sfx.free()


func test_prefs(cfg: GameConfig) -> void:
	print("prefs")
	var b := InputBindings.new()
	check(b.action_for_key(KEY_SPACE) == "start" and b.action_for_key(KEY_ENTER) == "start", "default start keys")
	check(b.action_for_key(KEY_KP_3) == "bet_2" and b.action_for_key(KEY_8) == "bet_7", "default bet keys")
	check(b.action_for_mouse(MOUSE_BUTTON_RIGHT) == "start", "default mouse start")
	# 搶鍵:Z 改給收分,原本的比小被清掉
	check(b.set_key("collect", 1, KEY_Z) == "small", "rebind reports displaced action")
	check(b.action_for_key(KEY_Z) == "collect" and b.map["small"]["keys"][0] == 0, "key moved, old slot cleared")
	check(b.set_key("start", 0, KEY_ESCAPE) == "!", "reserved key refused")
	check(b.set_mouse("big", MOUSE_BUTTON_LEFT) == "!", "left mouse refused")
	check(b.set_mouse("collect", MOUSE_BUTTON_RIGHT) == "start" and b.map["start"]["mouse"] == 0, "mouse rebind steals")
	b.reset_action("small")
	check(b.map["small"]["keys"][0] == KEY_Z and b.map["collect"]["keys"][1] == 0, "reset action restores default, taking key back")
	# 序列化來回(經 JSON,數字變 float)
	var b2 := InputBindings.new()
	b2.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	check(b2.to_dict() == b.to_dict(), "bindings json roundtrip")
	var bad := {"start": {"keys": [KEY_ESCAPE, KEY_F1], "mouse": 99}, "coin_1": {"keys": [KEY_F1, 0], "mouse": 0}}
	b2.from_dict(bad)
	check(b2.map["start"]["keys"][0] == 0 and b2.map["start"]["mouse"] == 0, "bad bindings sanitized")
	check(b2.map["coin_1"]["keys"][0] == KEY_F1 and b2.map["start"]["keys"][1] == 0, "duplicate key: first wins")

	var path := "user://test_prefs.json"
	var p := UserPrefs.new(0.8)
	p.audio["master"] = 0.35
	p.audio["tick"] = "wood"
	p.display["theme"] = "green"
	p.game["anim_speed"] = 1.5
	p.bindings.set_key("big", 0, KEY_B)
	check(p.save(path), "prefs saved")
	var q := UserPrefs.load_file(path, 0.8)
	check(is_equal_approx(q.audio["master"], 0.35) and q.audio["tick"] == "wood", "audio prefs roundtrip")
	check(q.display["theme"] == "green" and is_equal_approx(q.game["anim_speed"], 1.5), "display/game roundtrip")
	check(q.bindings.action_for_key(KEY_B) == "big", "bindings in prefs roundtrip")
	var junk := UserPrefs.new(0.8)
	junk.from_dict({"audio": {"master": 9, "tick": "nope", "tick_pitch": 0.0}, "game": {"anim_speed": 50}})
	check(junk.audio["master"] == 1.0 and junk.audio["tick"] == "relay" and junk.audio["tick_pitch"] == 0.5, "audio values clamped / invalid choice falls back")
	check(junk.game["anim_speed"] == 2.0, "anim speed clamped")
	p.reset_section("audio")
	check(is_equal_approx(p.audio["master"], 0.8) and p.display["theme"] == "green", "reset one section only")
	check(UserPrefs.load_file("user://nope.json", 0.6).audio["master"] == 0.6, "missing prefs → default master")
	var sk := UserPrefs.new(0.8)
	check(sk.display["skin"] == "fruit" and sk.resolved_double_style() == "dice", "default skin fruit + dice")
	sk.display["skin"] = "chess"
	check(sk.resolved_double_style() == "banqi", "auto: chess skin → banqi")
	sk.game["double_style"] = "dice"
	check(sk.resolved_double_style() == "dice", "explicit double style wins over skin")
	sk.from_dict({"display": {"skin": "nope"}, "game": {"double_style": "nope"}})
	check(sk.display["skin"] == "fruit" and sk.game["double_style"] == "auto", "invalid skin / double style fall back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# 存檔欄位
	var dir := "user://test_slots"
	var g := GameState.new(cfg, 5)
	g.insert_coin(40)
	g.add_bet(2, 3)
	check(SaveSlots.summary(3, dir)["empty"], "slot starts empty")
	check(SaveSlots.write(3, g.serialize(), p.to_dict(), dir), "slot written")
	var sm := SaveSlots.summary(3, dir)
	check(not sm["empty"] and sm["credit"] == g.credit and sm["date"].length() == 19, "slot summary has credit + date")
	var rd := SaveSlots.read(3, dir)
	var g2 := GameState.new(cfg, 6)
	g2.restore(rd["game"])
	check(g2.credit == g.credit and g2.bets.bets[2] == 3, "slot restores game")
	var p2 := UserPrefs.new(0.8)
	p2.from_dict(rd["prefs"])
	check(p2.display["theme"] == "green", "slot carries prefs")
	check(SaveSlots.delete(3, dir) and SaveSlots.summary(3, dir)["empty"], "slot deleted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func test_rtp(cfg: GameConfig) -> void:
	print("rtp (200k rounds, all items bet 1)")
	var g := GameState.new(cfg, 12345)
	for n in 200000:
		g.credit = 100
		for i in 8:
			g.add_bet(i, 1)
		g.start()
		g.finish_round()
		g.collect()
	var rtp := Accounting.rtp_of(g.acct.total)
	print("  rtp=%.4f" % rtp)
	check(rtp > 0.88 and rtp < 0.98, "RTP in plausible range")
