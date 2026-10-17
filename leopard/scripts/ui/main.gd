extends Control
## 主畫面:組合 HUD、跑燈環、8 個押注視窗、操作鍵,並串接 GameState / 動畫 / 音效 / 存檔。

const SAVE_PATH := "user://save.json"
const BACKOFFICE_HOLD_SEC := 3.0

var cfg: GameConfig
var game: GameState
var sfx: SfxPlayer
var ring_view: RingView
var slots: Array[BetSlot] = []
var repeaters: Array[HoldRepeater] = []
var win_label: Label
var credit_label: Label
var center_label: Label
var dice_view: DiceView
var btn_small: Button
var btn_big: Button
var btn_collect: Button
var btn_start: Button
var backoffice: Backoffice
var settings: SettingsMenu
var prefs: UserPrefs
var btn_settings: Button
var coin_caption: Label
var anim_rng := RandomNumberGenerator.new()

var busy := false  ## 動畫進行中,鎖住操作
var hud_lock := false  ## 計數動畫期間,HUD 數字由動畫控制
var shown_win := 0
var shown_credit := 0
var _bo_hold := 0.0
var _save_dirty := false
var _msg_sticky := false  ## 中央訊息為暫時性文字時,不被待機提示覆蓋


func _ready() -> void:
	anim_rng.randomize()
	cfg = GameConfig.load_default(true)
	game = GameState.new(cfg)
	var saved := SaveData.load_file(SAVE_PATH)
	var recovered := false
	if not saved.is_empty():
		recovered = int(saved["phase"]) == GameState.Phase.SPINNING
		game.restore(saved)
	prefs = UserPrefs.load_file(UserPrefs.PATH, float(cfg.s["volume"]))
	sfx = SfxPlayer.new()
	add_child(sfx)
	_build_ui()
	apply_prefs()
	game.changed.connect(_on_changed)
	game.round_started.connect(func(_r): _save_now())  # 結果決定後、動畫開始前先存檔
	game.round_finished.connect(func(_r): _save_now())
	game.collected.connect(func(_a): _save_now())
	game.doubled.connect(func(_i): _save_now())
	shown_win = game.win
	shown_credit = game.credit
	ring_view.light(game.last_stop)
	_refresh()
	if recovered:
		_message("斷電復原:已依存檔結果補完結算")
		ring_view.light(game.last_stop)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0e0b1c")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# HUD
	_caption("WIN", Vector2(30, 8), 28, Color("ffd84a"))
	win_label = _number_label(Vector2(30, 36), 380, HORIZONTAL_ALIGNMENT_LEFT)
	_caption("CREDIT", Vector2(700, 8), 28, Color("6fe0ff"), 350, HORIZONTAL_ALIGNMENT_RIGHT)
	credit_label = _number_label(Vector2(700, 36), 350, HORIZONTAL_ALIGNMENT_RIGHT)
	var coin_vals := [1, 5, 10, 50]
	for k in 4:
		var b := _button("+%d" % coin_vals[k], Rect2(400 + k * 70, 60, 64, 56), 26)
		var v: int = coin_vals[k]
		b.pressed.connect(func(): _insert_coin(v))
		b.focus_mode = Control.FOCUS_NONE
	coin_caption = _caption("投幣", Vector2(400, 30), 22, Color("8880b0"), 280)
	btn_settings = _button("設定", Rect2(270, 6, 120, 50), 26)
	btn_settings.focus_mode = Control.FOCUS_NONE
	btn_settings.pressed.connect(func(): settings.open())

	# 跑燈環
	ring_view = RingView.new()
	ring_view.position = Vector2(92, 150)
	add_child(ring_view)
	ring_view.setup(cfg.ring_cells, cfg.symbol_ids)
	center_label = Label.new()
	center_label.position = Vector2(190, 400)
	center_label.size = Vector2(620, 260)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_label.add_theme_font_size_override("font_size", 56)
	center_label.add_theme_color_override("font_color", Color("fff2b0"))
	center_label.add_theme_constant_override("outline_size", 8)
	center_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ring_view.add_child(center_label)
	center_label.position = Vector2(138, 150)
	dice_view = DiceView.new()
	dice_view.position = Vector2(268, 520)
	dice_view.visible = false
	ring_view.add_child(dice_view)

	# 押注視窗
	for i in cfg.symbol_count():
		var s := BetSlot.new()
		s.position = Vector2(20 + i * 131, 1075)
		s.size = Vector2(123, 215)
		add_child(s)
		s.setup(i, cfg.symbol_ids[i], cfg.multipliers[i])
		s.pressed.connect(_slot_press)
		s.released.connect(_slot_release)
		slots.append(s)
		repeaters.append(HoldRepeater.new(float(cfg.s["hold_1_sec"]), float(cfg.s["hold_2_sec"]), float(cfg.s["repeat_interval_ms"]) / 1000.0))

	# 操作鍵
	btn_small = _button("小", Rect2(20, 1310, 200, 110), 40)
	btn_big = _button("大", Rect2(230, 1310, 200, 110), 40)
	btn_collect = _button("收分", Rect2(440, 1310, 200, 110), 40)
	btn_start = _button("啟動", Rect2(650, 1310, 410, 110), 48)
	for b in [btn_small, btn_big, btn_collect, btn_start]:
		b.focus_mode = Control.FOCUS_NONE
	btn_small.pressed.connect(func(): _on_guess(DoubleUp.Guess.SMALL))
	btn_big.pressed.connect(func(): _on_guess(DoubleUp.Guess.BIG))
	btn_collect.pressed.connect(_on_collect)
	btn_start.pressed.connect(_on_start)

	settings = SettingsMenu.new()
	settings.visible = false
	settings.setup(self)
	add_child(settings)
	backoffice = Backoffice.new()
	backoffice.visible = false
	backoffice.setup(self)
	add_child(backoffice)


func _caption(text: String, pos: Vector2, fsize: int, col: Color, w := 300.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, fsize + 8)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _number_label(pos: Vector2, w: float, align: int) -> Label:
	var l := _caption("0", pos, 84, Color.WHITE, w, align)
	l.size.y = 100
	return l


func _button(text: String, rect: Rect2, fsize: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", fsize)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3)
		match st:
			"normal": sb.bg_color = Color("3a3270")
			"hover": sb.bg_color = Color("4a4290")
			"pressed": sb.bg_color = Color("6a5ac0")
			"disabled": sb.bg_color = Color("22203a")
		sb.border_color = Color("8880d0") if st != "disabled" else Color("3a3858")
		b.add_theme_stylebox_override(st, sb)
	add_child(b)
	return b


# ---------- 輸入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or backoffice.visible or settings.visible:
		return
	var k := event as InputEventKey
	if k.echo:
		return
	if k.pressed and k.physical_keycode == KEY_ESCAPE:
		settings.open()
		return
	var id := prefs.bindings.action_for_key(k.physical_keycode)
	if id != "":
		_do_action(id, k.pressed)


## 滑鼠鍵走 _input:畫面上的控制項會吃掉滑鼠事件,到不了 _unhandled_input。
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or backoffice.visible or settings.visible:
		return
	var m := event as InputEventMouseButton
	var id := prefs.bindings.action_for_mouse(m.button_index)
	if id != "":
		_do_action(id, m.pressed)


func _do_action(id: String, pressed: bool) -> void:
	if id.begins_with("bet_"):
		var i := int(id.substr(4))
		if pressed:
			_slot_press(i)
		else:
			_slot_release(i)
		return
	if not pressed:
		return
	if id.begins_with("coin_"):
		_insert_coin(int(id.substr(5)))
		return
	match id:
		"start": _on_start()
		"collect": _on_collect()
		"small": _on_guess(DoubleUp.Guess.SMALL)
		"big": _on_guess(DoubleUp.Guess.BIG)


# ---------- 偏好設定 / 手動存檔 ----------

func prefs_changed() -> void:
	apply_prefs()
	prefs.save()


func apply_prefs() -> void:
	var a := prefs.audio
	sfx.volume = a["master"]
	sfx.muted = a["mute"]
	sfx.tick_pitch = a["tick_pitch"]
	for cat in ["tick", "bet", "coin", "win"]:
		sfx.set_style(cat, a[cat])
	var d := prefs.display
	ring_view.set_theme_name(d["theme"])
	ring_view.led_scale = RingView.LED_SCALES[d["led_size"]]
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if d["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	_refresh_labels()


## 後台改「預設音量」時一併套用到玩家主音量。
func set_master_volume(v: float) -> void:
	prefs.audio["master"] = v
	prefs_changed()


func _speed() -> float:
	return float(prefs.game["anim_speed"])


func _labeled(base: String, id: String) -> String:
	var h := prefs.bindings.hint(id) if prefs.display["key_hints"] else ""
	return "%s (%s)" % [base, h] if h != "" else base


func _refresh_labels() -> void:
	btn_small.text = _labeled("小", "small")
	btn_big.text = _labeled("大", "big")
	btn_collect.text = _labeled("收分", "collect")
	btn_settings.text = "設定"
	var hints: Array[String] = []
	if prefs.display["key_hints"]:
		for id in ["coin_1", "coin_5", "coin_10", "coin_50"]:
			var h := prefs.bindings.hint(id)
			if h != "":
				hints.append(h)
	coin_caption.text = "投幣 " + "/".join(hints) if hints.size() > 0 else "投幣"
	_refresh()


func can_manage_saves() -> bool:
	return not busy and game.phase != GameState.Phase.SPINNING


func save_to_slot(i: int) -> bool:
	if not can_manage_saves():
		return false
	return SaveSlots.write(i, game.serialize(), prefs.to_dict())


## 讀取存檔欄位。帳務紀錄維持目前的(後台帳本不回溯);with_prefs 時一併還原當時的偏好設定。
func load_from_slot(i: int, with_prefs: bool) -> bool:
	if not can_manage_saves():
		return false
	var d := SaveSlots.read(i)
	if d.is_empty():
		return false
	var g: Dictionary = d["game"].duplicate()
	g["acct"] = game.acct.serialize()
	game.restore(g)
	if with_prefs and d.get("prefs") is Dictionary:
		prefs.from_dict(d["prefs"])
		prefs_changed()
	hud_lock = false
	shown_win = game.win
	shown_credit = game.credit
	dice_view.visible = false
	ring_view.clear_lights()
	ring_view.light(game.last_stop)
	_clear_message()
	_save_now()
	_refresh()
	return true


func _slot_press(i: int) -> void:
	if busy or game.phase == GameState.Phase.SPINNING:
		return
	slots[i].held = true
	repeaters[i].press()
	if game.add_bet(i, 1):
		sfx.play("bet")
	else:
		repeaters[i].stop()


func _slot_release(i: int) -> void:
	repeaters[i].release()
	slots[i].held = false


func _insert_coin(v: int) -> void:
	if busy and game.phase == GameState.Phase.SPINNING:
		return
	game.insert_coin(v)
	sfx.play("coin")
	_save_dirty = true


func _process(delta: float) -> void:
	for i in repeaters.size():
		for step in repeaters[i].update(delta):
			if game.add_bet(i, step):
				sfx.play("bet")
			else:
				repeaters[i].stop()
				break
	if _save_dirty:
		_save_dirty = false
		_save_now()
	# 後台:同時按住 Home + End 3 秒
	if Input.is_key_pressed(KEY_HOME) and Input.is_key_pressed(KEY_END) and not busy and game.phase != GameState.Phase.SPINNING:
		_bo_hold += delta
		if _bo_hold >= BACKOFFICE_HOLD_SEC:
			_bo_hold = 0.0
			backoffice.open()
	else:
		_bo_hold = 0.0


# ---------- 狀態 → 畫面 ----------

func _on_changed() -> void:
	_save_dirty = true
	_refresh()


func _refresh() -> void:
	if not hud_lock:
		shown_win = game.win
		shown_credit = game.credit
	win_label.text = str(shown_win)
	credit_label.text = str(shown_credit)
	for i in slots.size():
		slots[i].bet = game.bets.bets[i]
		slots[i].last_bet = game.bets.last_bets[i]
	var idle := not busy and game.phase != GameState.Phase.SPINNING
	btn_small.disabled = not (idle and game.can_double())
	btn_big.disabled = btn_small.disabled
	btn_collect.disabled = not (idle and game.win > 0)
	var can_repeat := game.bets.total() == 0 and game.bets.last_total() > 0 and game.credit > 0
	btn_start.text = _labeled("續押" if can_repeat else "啟動", "start")
	btn_start.disabled = not idle or not (game.bets.total() > 0 or can_repeat or game.win > 0 and game.bets.last_total() > 0)
	if idle:
		ring_view.rest_cell = game.last_stop
		if not _msg_sticky:
			_idle_hint()


func _idle_hint() -> void:
	if game.credit == 0 and game.bets.total() == 0 and game.win == 0:
		center_label.text = "請投幣"
	elif game.bets.total() > 0:
		center_label.text = "按啟動開始"
	elif game.win > 0:
		center_label.text = "得分 %d\n比大小或收分" % game.win
	else:
		center_label.text = "請押注"


func _message(text: String) -> void:
	_msg_sticky = text != ""
	center_label.text = text


func _clear_message() -> void:
	_msg_sticky = false
	center_label.text = ""


func _save_now() -> void:
	SaveData.save(SAVE_PATH, game.serialize())


# ---------- 啟動 / 一局流程 ----------

func _on_start() -> void:
	if busy or game.phase == GameState.Phase.SPINNING:
		return
	busy = true
	dice_view.visible = false
	if game.win > 0:
		await _do_collect()  # 已確認:WIN > 0 時按啟動 → 先自動收分
	busy = false
	var r := game.start()
	if not r["ok"]:
		_refresh()
		return
	busy = true
	_refresh()
	await _play_round(r["round"])
	busy = false
	_refresh()


func _play_round(rd: Dictionary) -> void:
	_clear_message()
	ring_view.clear_lights()
	ring_view.rest_cell = -1
	var cur: int = rd["start_cell"]
	ring_view.light(cur)
	var spins: Array = rd["spins"]
	var jackpot_played := false
	for k in spins.size():
		var sp: Dictionary = spins[k]
		if k > 0:
			_message("送燈 %d / %d" % [k, spins.size() - 1])
			sfx.play("luck")
			await _wait(0.9)
			ring_view.flash.clear()
		var laps := anim_rng.randi_range(int(cfg.s["min_cruise_laps"]), int(cfg.s["max_cruise_laps"]))
		var plan := SpinPlan.build(cur, sp["cell"], laps, float(cfg.s["first_interval"]), float(cfg.s["min_interval"]))
		await _run_plan(cur, plan)
		cur = sp["cell"]
		ring_view.flash[cur] = true
		if sp["kind"] == OddsTable.Kind.LUCK:
			sfx.play("luck")
			_message("LUCK!\n送燈")
		elif sp["win"] > 0:
			if cfg.jackpot_symbols.has(sp["symbol"]):
				_big_win(sp["win"])
				jackpot_played = true
			else:
				sfx.play("win")
				_message("WIN %d" % sp["win"])
			slots[sp["symbol"]].flashing = true
		elif sp["kind"] == OddsTable.Kind.SYMBOL:
			_message("")
		await _wait(1.3 if sp["win"] > 0 else 0.7)
		slots[sp["symbol"] if sp["symbol"] >= 0 else 0].flashing = false
	if rd["jackpot"] and not jackpot_played:
		_big_win(rd["total_win"])
		await _wait(1.2)
	ring_view.flash.clear()
	ring_view.rest_cell = cur
	var before_credit := game.credit
	hud_lock = true
	shown_win = 0
	shown_credit = before_credit
	game.finish_round()
	if game.win > 0:
		await _count(0, game.win, before_credit, before_credit)
	hud_lock = false
	for s in slots:
		s.flashing = false
	_clear_message()
	_refresh()


func _big_win(amount: int) -> void:
	sfx.play("jackpot")
	if prefs.display["jackpot_flash"]:
		ring_view.jackpot_flash = 2.5
	_message("大獎!\n%d" % amount)


func _run_plan(start: int, plan: SpinPlan) -> void:
	var idx := 0
	var acc := 0.0
	var pos := start
	var n := plan.intervals.size()
	while idx < n:
		await get_tree().process_frame
		acc += get_process_delta_time() * _speed()
		while idx < n and acc >= plan.intervals[idx]:
			acc -= plan.intervals[idx]
			idx += 1
			pos = (pos + 1) % GameConfig.RING_SIZE
			ring_view.light(pos)
			sfx.play("tick")  # 每跳一格必播


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / _speed()).timeout


## WIN 與 CREDIT 的計數動畫(逐分跳動 + 計數音)。
func _count(win_from: int, win_to: int, credit_from: int, credit_to: int) -> void:
	var diff := absi(win_to - win_from)
	var dur := clampf(diff * 0.015, 0.25, 1.6) / _speed()
	var t := 0.0
	var last := -1
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := minf(t / dur, 1.0)
		shown_win = int(round(lerpf(win_from, win_to, k)))
		shown_credit = int(round(lerpf(credit_from, credit_to, k)))
		win_label.text = str(shown_win)
		credit_label.text = str(shown_credit)
		if shown_win != last:
			last = shown_win
			sfx.play("count")
	shown_win = win_to
	shown_credit = credit_to


# ---------- 收分 / 比大小 ----------

func _on_collect() -> void:
	if busy or game.win <= 0 or game.phase == GameState.Phase.SPINNING:
		return
	busy = true
	await _do_collect()
	busy = false
	_refresh()


func _do_collect() -> void:
	var w := game.win
	var c0 := game.credit
	hud_lock = true
	shown_win = w
	shown_credit = c0
	var amount := game.collect()
	await _count(w, 0, c0, c0 + amount)
	hud_lock = false
	dice_view.visible = false
	_clear_message()
	_refresh()


func _on_guess(g: int) -> void:
	if busy or not game.can_double():
		return
	busy = true
	hud_lock = true
	var w0 := game.win
	shown_win = w0
	shown_credit = game.credit
	var info := game.double_up(g)  # 結果先決定,動畫只是呈現
	center_label.text = "比大小"
	dice_view.visible = true
	sfx.play("dice")
	var t := 0.0
	while t < 0.9:
		await get_tree().process_frame
		t += get_process_delta_time()
		dice_view.show_faces(anim_rng.randi_range(1, 6), anim_rng.randi_range(1, 6))
	dice_view.show_faces(info["dice"][0], info["dice"][1])
	var total: int = info["total"]
	match info["result"]:
		DoubleUp.Result.WIN:
			sfx.play("du_win")
			_message("%d 點  猜對!\nWIN %d" % [total, info["win"]])
		DoubleUp.Result.LOSE:
			sfx.play("du_lose")
			_message("%d 點  猜錯\nWIN 歸零" % total)
		_:
			_message("%d 點  和局\n可再猜" % total)
	await _wait(1.2)
	hud_lock = false
	if game.win == 0:
		dice_view.visible = false
		_clear_message()
	busy = false
	_refresh()
	if game.win > 0:
		center_label.text = "WIN %d\n再猜或收分" % game.win
