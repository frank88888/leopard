class_name SaveData
extends RefCounted
## 本機 JSON 存檔,含 SHA-256 校驗碼。內容以字串形式存放,避免 int/float 還原造成校驗不一致。


static func checksum(payload: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(payload.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func save(path: String, data: Dictionary) -> bool:
	var payload := JSON.stringify(data)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"data": payload, "sum": checksum(payload)}))
	return true


## 檔案不存在或校驗失敗回傳空字典。
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var outer = JSON.parse_string(f.get_as_text())
	if not (outer is Dictionary) or not outer.has("data") or not outer.has("sum"):
		return {}
	if checksum(outer["data"]) != outer["sum"]:
		return {}
	var d = JSON.parse_string(outer["data"])
	return d if d is Dictionary else {}
