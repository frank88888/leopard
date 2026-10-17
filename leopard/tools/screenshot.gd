extends SceneTree
## 開發用:啟動主畫面,模擬操作並存成 PNG。
## godot --path . -s tools/screenshot.gd -- <輸出資料夾>
## 注意:會寫入 user://save.json,結束前會刪除。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "."
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await _frames(5)
	_shot(out + "/1_idle.png")
	scene._insert_coin(50)
	scene.game.add_bet(0, 3)
	scene.game.add_bet(6, 5)
	scene.game.add_bet(7, 10)
	scene.game.add_bet(3, 2)
	await _frames(3)
	_shot(out + "/2_bets.png")
	scene._on_start()
	await _secs(1.5)
	_shot(out + "/3_spinning.png")
	while scene.busy:
		await _frames(1)
	_shot(out + "/4_result.png")
	if scene.game.win > 0:
		scene._on_guess(DoubleUp.Guess.BIG)
		await _secs(1.2)
		_shot(out + "/5_double.png")
	while scene.busy:
		await _frames(1)
	scene.backoffice.open()
	scene.backoffice._pw_edit.text = scene.cfg.s["admin_password"]
	scene.backoffice._try_login()
	await _frames(3)
	_shot(out + "/6_backoffice.png")
	var tabs: TabContainer = scene.backoffice._panel.get_child(0)
	tabs.current_tab = 1
	await _frames(3)
	_shot(out + "/7_settings.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://audit.log"))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	await create_timer(s).timeout


func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
