extends SceneTree
## RTP 蒙地卡羅模擬。
## godot --headless --path . -s tools/simulate_rtp.gd -- [局數=1000000] [模式=all|single|random] [seed]
##   all    = 8 項各押 1
##   single = 每局只押一個隨機項目 1 分
##   random = 每項隨機 0~5 分

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rounds := int(args[0]) if args.size() > 0 else 1000000
	var mode := args[1] if args.size() > 1 else "all"
	var seed_v := int(args[2]) if args.size() > 2 else 20261017
	var cfg := GameConfig.load_default()
	var g := GameState.new(cfg, seed_v)
	var brng := RandomNumberGenerator.new()
	brng.seed = seed_v + 1
	var big_wins := 0
	var jackpots := 0
	var t0 := Time.get_ticks_msec()
	for n in rounds:
		g.credit = 10000
		match mode:
			"single":
				g.add_bet(brng.randi_range(0, 7), 1)
			"random":
				for i in 8:
					for k in brng.randi_range(0, 5):
						g.add_bet(i, 1)
				if g.bets.total() == 0:
					g.add_bet(0, 1)
			_:
				for i in 8:
					g.add_bet(i, 1)
		var r: Dictionary = g.start()["round"]
		g.finish_round()
		if r["jackpot"]:
			jackpots += 1
		g.collect()
	var a := g.acct
	print("mode=%s rounds=%d seed=%d (%.1fs)" % [mode, rounds, seed_v, (Time.get_ticks_msec() - t0) / 1000.0])
	print("設定:rtp_target=%.3f luck_bonus_prob=%.3f c=%.4f p_miss=%.4f" % [cfg.rtp_target, cfg.luck_bonus_prob, g.odds.c, g.odds.p_miss])
	print("押注=%d 收分=%d  實際RTP=%.4f" % [a.total["bet"], a.total["collected"], Accounting.rtp_of(a.total)])
	print("LUCK=%d (%.2f%%) 空燈=%d 送燈抽數=%d 大獎局=%d" % [a.total["luck"], 100.0 * a.total["luck"] / rounds, a.total["luck_miss"], a.total["bonus_spins"], jackpots])
	var spins := 0
	for h in a.symbol_hits_total:
		spins += h
	spins += a.total["luck"] + a.total["luck_miss"]
	for i in cfg.symbol_count():
		print("  %-6s x%-3d 命中 %8d  %.3f%%" % [cfg.symbol_names[i], cfg.multipliers[i], a.symbol_hits_total[i], 100.0 * a.symbol_hits_total[i] / spins])
	quit()
