class_name Backoffice
extends Control
## 後台:密碼 → 帳務 / 設定 / 稽核。

const AUDIT_PATH := "user://audit.log"

var main: Control
var game: GameState
var cfg: GameConfig

var _login: Control
var _panel: Control
var _pw_edit: LineEdit
var _login_msg: Label
var _acct_text: RichTextLabel
var _audit_text: RichTextLabel
var _status: Label
var _fields: Dictionary = {}  # key -> SpinBox
var _mult_fields: Array[SpinBox] = []
var _new_pw: LineEdit


func setup(main_node: Control) -> void:
	main = main_node
	game = main.game
	cfg = main.cfg
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.1, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_build_login()
	_build_panel()


func open() -> void:
	visible = true
	_login.visible = true
	_panel.visible = false
	_pw_edit.text = ""
	_login_msg.text = ""
	_pw_edit.grab_focus()


func _close() -> void:
	visible = false
	main._refresh()


func _build_login() -> void:
	_login = Control.new()
	add_child(_login)
	var l := _label("後台密碼", Vector2(340, 450), 44)
	_login.add_child(l)
	_pw_edit = LineEdit.new()
	_pw_edit.secret = true
	_pw_edit.position = Vector2(340, 530)
	_pw_edit.size = Vector2(400, 70)
	_pw_edit.add_theme_font_size_override("font_size", 36)
	_pw_edit.text_submitted.connect(func(_t): _try_login())
	_login.add_child(_pw_edit)
	_login_msg = _label("", Vector2(340, 620), 30)
	_login.add_child(_login_msg)
	var ok := _btn("進入", Vector2(340, 680), Vector2(190, 70))
	ok.pressed.connect(_try_login)
	_login.add_child(ok)
	var cancel := _btn("取消", Vector2(550, 680), Vector2(190, 70))
	cancel.pressed.connect(_close)
	_login.add_child(cancel)


func _try_login() -> void:
	if _pw_edit.text == str(cfg.s["admin_password"]):
		_audit("登入後台")
		_login.visible = false
		_panel.visible = true
		_refresh_all()
	else:
		_audit("後台登入失敗")
		_login_msg.text = "密碼錯誤"
		_pw_edit.text = ""


func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var tabs := TabContainer.new()
	tabs.position = Vector2(20, 20)
	tabs.size = Vector2(1040, 1300)
	tabs.add_theme_font_size_override("font_size", 30)
	_panel.add_child(tabs)

	# 帳務
	var t1 := VBoxContainer.new()
	t1.name = "帳務"
	tabs.add_child(t1)
	_acct_text = RichTextLabel.new()
	_acct_text.bbcode_enabled = true
	_acct_text.custom_minimum_size = Vector2(1000, 900)
	_acct_text.add_theme_font_size_override("normal_font_size", 28)
	t1.add_child(_acct_text)
	var row := HBoxContainer.new()
	t1.add_child(row)
	var b_reset := _btn("清除本期帳", Vector2.ZERO, Vector2(240, 70))
	b_reset.pressed.connect(func():
		game.acct.reset_period()
		_audit("清除本期帳")
		_refresh_all())
	row.add_child(b_reset)
	var b_csv := _btn("匯出 CSV", Vector2.ZERO, Vector2(240, 70))
	b_csv.pressed.connect(_export_csv)
	row.add_child(b_csv)

	# 設定
	var t2 := VBoxContainer.new()
	t2.name = "設定"
	tabs.add_child(t2)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1000, 1000)
	t2.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	sc.add_child(grid)
	_add_field(grid, "rtp_target", "RTP 目標 (0.5~1.0)", 0.5, 1.0, 0.005)
	_add_field(grid, "luck_bonus_prob", "LUCK 送燈機率", 0.0, 0.5, 0.005)
	_add_field(grid, "bet_cap", "單項押注上限", 1, 999, 1)
	_add_field(grid, "double_up_max", "比大小連猜上限", 0, 50, 1)
	_add_field(grid, "win_cap", "WIN 上限(禁止再猜)", 1, 999999, 1)
	_add_field(grid, "jackpot_coef", "大獎門檻係數(×單項上限)", 1, 100, 0.5)
	_add_field(grid, "repeat_interval_ms", "連按間隔 (ms)", 30, 1000, 10)
	_add_field(grid, "volume", "音量 (0~1)", 0.0, 1.0, 0.05)
	for i in cfg.symbol_count():
		grid.add_child(_label("倍率:" + cfg.symbol_names[i], Vector2.ZERO, 28))
		var sb := _spin(1, 999, 1)
		grid.add_child(sb)
		_mult_fields.append(sb)
	grid.add_child(_label("新後台密碼(留空不變)", Vector2.ZERO, 28))
	_new_pw = LineEdit.new()
	_new_pw.custom_minimum_size = Vector2(300, 50)
	_new_pw.add_theme_font_size_override("font_size", 28)
	grid.add_child(_new_pw)
	var row2 := HBoxContainer.new()
	t2.add_child(row2)
	var b_apply := _btn("套用並儲存", Vector2.ZERO, Vector2(280, 70))
	b_apply.pressed.connect(_apply_settings)
	row2.add_child(b_apply)
	var b_def := _btn("恢復預設", Vector2.ZERO, Vector2(240, 70))
	b_def.pressed.connect(_restore_defaults)
	row2.add_child(b_def)

	# 稽核
	var t3 := VBoxContainer.new()
	t3.name = "稽核"
	tabs.add_child(t3)
	_audit_text = RichTextLabel.new()
	_audit_text.custom_minimum_size = Vector2(1000, 1000)
	_audit_text.add_theme_font_size_override("normal_font_size", 24)
	t3.add_child(_audit_text)

	_status = _label("", Vector2(30, 1330), 28)
	_panel.add_child(_status)
	var close := _btn("離開後台", Vector2(780, 1335), Vector2(280, 90))
	close.pressed.connect(func():
		_audit("離開後台")
		_close())
	_panel.add_child(close)


func _label(text: String, pos: Vector2, fsize: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	return l


func _btn(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.add_theme_font_size_override("font_size", 30)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.custom_minimum_size = Vector2(300, 50)
	sb.get_line_edit().add_theme_font_size_override("font_size", 28)
	return sb


func _add_field(grid: GridContainer, key: String, title: String, lo: float, hi: float, step: float) -> void:
	grid.add_child(_label(title, Vector2.ZERO, 28))
	var sb := _spin(lo, hi, step)
	grid.add_child(sb)
	_fields[key] = sb


func _refresh_all() -> void:
	var a := game.acct
	var t := a.total
	var p := a.period
	var rows: Array = [["項目", "本期", "總計"]]
	for k in Accounting.KEYS:
		rows.append([k, str(p[k]), str(t[k])])
	rows.append(["實際RTP", "%.2f%%" % (Accounting.rtp_of(p) * 100.0), "%.2f%%" % (Accounting.rtp_of(t) * 100.0)])
	rows.append(["", "", ""])
	rows.append(["圖案停燈次數", "本期", "總計"])
	for i in cfg.symbol_count():
		rows.append(["%s x%d" % [cfg.symbol_names[i], cfg.multipliers[i]], str(a.symbol_hits_period[i]), str(a.symbol_hits_total[i])])
	var bb := "[table=3]"
	for r in rows:
		for c in r:
			bb += "[cell padding=6,2,24,2]%s[/cell]" % c
	_acct_text.text = bb + "[/table]"
	for k in _fields:
		_fields[k].value = float(cfg.rtp_target if k == "rtp_target" else (cfg.luck_bonus_prob if k == "luck_bonus_prob" else cfg.s[k]))
	for i in _mult_fields.size():
		_mult_fields[i].value = cfg.multipliers[i]
	_audit_text.text = _read_audit()
	_new_pw.text = ""


func _apply_settings() -> void:
	var old := cfg.overrides_dict().duplicate(true)
	var trial := cfg.overrides_dict().duplicate(true)
	for k in _fields:
		trial[k] = _fields[k].value
	var m: Array = []
	for sb in _mult_fields:
		m.append(int(sb.value))
	trial["multipliers"] = m
	if _new_pw.text != "":
		trial["admin_password"] = _new_pw.text
	for k in ["bet_cap", "double_up_max", "win_cap", "repeat_interval_ms"]:
		trial[k] = int(trial[k])
	var probe := GameConfig.load_default()
	probe.apply_overrides(trial)
	if not probe.odds_valid():
		_status.text = "套用失敗:機率總和超過 100%,請降低 RTP 目標 / LUCK 機率或提高倍率"
		return
	if game.bets.total() > 0 and int(trial["bet_cap"]) < game.bets.cap:
		_status.text = "有押注中,無法調降單項上限"
		return
	cfg.apply_overrides(trial)
	cfg.save_overrides()
	game.reload_config()
	main.set_master_volume(float(cfg.s["volume"]))
	for i in cfg.symbol_count():
		main.slots[i].mult = cfg.multipliers[i]
		main.slots[i].queue_redraw()
	for r in main.repeaters:
		r.interval = float(cfg.s["repeat_interval_ms"]) / 1000.0
	for k in trial:
		if str(trial[k]) != str(old[k]):
			_audit("%s: %s → %s" % [k, str(old[k]) if k != "admin_password" else "***", str(trial[k]) if k != "admin_password" else "***"])
	_status.text = "已套用並儲存"
	_refresh_all()


func _restore_defaults() -> void:
	var d := GameConfig.load_default()
	cfg.apply_overrides(d.overrides_dict())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameConfig.OVERRIDE_PATH))
	game.reload_config()
	main.set_master_volume(float(cfg.s["volume"]))
	for i in cfg.symbol_count():
		main.slots[i].mult = cfg.multipliers[i]
		main.slots[i].queue_redraw()
	_audit("恢復預設設定")
	_status.text = "已恢復預設"
	_refresh_all()


func _export_csv() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path := "user://accounting_%s.csv" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_status.text = "匯出失敗"
		return
	f.store_string(game.acct.to_csv(cfg.symbol_names))
	f.close()
	_audit("匯出帳務 CSV " + path)
	_status.text = "已匯出:" + ProjectSettings.globalize_path(path)
	_refresh_all()


func _audit(msg: String) -> void:
	var f := FileAccess.open(AUDIT_PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(AUDIT_PATH) else FileAccess.open(AUDIT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s  %s" % [Time.get_datetime_string_from_system(false, true), msg])


func _read_audit() -> String:
	if not FileAccess.file_exists(AUDIT_PATH):
		return "(無紀錄)"
	var lines := FileAccess.get_file_as_string(AUDIT_PATH).split("\n", false)
	var start := maxi(0, lines.size() - 200)
	return "\n".join(lines.slice(start))
