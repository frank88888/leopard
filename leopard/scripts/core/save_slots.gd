class_name SaveSlots
extends RefCounted
## 手動存檔欄位(讀取 / 儲存進度)。每欄一個檔,含日期、金額、遊戲狀態與當時的偏好設定。

const COUNT := 8
const DIR := "user://slots"


static func path(i: int, dir := DIR) -> String:
	return "%s/slot_%d.json" % [dir, i]


static func write(i: int, game_data: Dictionary, prefs_data: Dictionary, dir := DIR) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return SaveData.save(path(i, dir), {
		"version": 1,
		"date": Time.get_datetime_string_from_system(false, true),
		"credit": int(game_data["credit"]),
		"win": int(game_data["win"]),
		"game": game_data,
		"prefs": prefs_data,
	})


## 空欄或損毀回傳空字典。
static func read(i: int, dir := DIR) -> Dictionary:
	var d := SaveData.load_file(path(i, dir))
	if d.is_empty() or not d.has("game") or not d.has("date"):
		return {}
	return d


static func delete(i: int, dir := DIR) -> bool:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path(i, dir))) == OK


## 欄位列表用的摘要:{"empty": bool, "date": String, "credit": int, "win": int}
static func summary(i: int, dir := DIR) -> Dictionary:
	var d := read(i, dir)
	if d.is_empty():
		return {"empty": true, "date": "", "credit": 0, "win": 0}
	return {"empty": false, "date": str(d["date"]), "credit": int(d["credit"]), "win": int(d["win"])}
