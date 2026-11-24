class_name Save
## Tiny persistent save: best depth. Schema-versioned (code.md rule 5).

const PATH := "user://save.json"
const SCHEMA_VERSION := 2


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return _migrate({"schema": SCHEMA_VERSION, "best_depth": 0})
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return _migrate({"schema": SCHEMA_VERSION, "best_depth": 0})
	return _migrate(d)


static func store(d: Dictionary) -> void:
	d["schema"] = SCHEMA_VERSION
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


static func _migrate(d: Dictionary) -> Dictionary:
	if not d.has("best_depth"):
		d["best_depth"] = 0
	# v1 → v2: account souls, meta upgrades (M08), run counters
	if int(d.get("schema", 1)) < 2 or not d.has("souls"):
		d["souls"] = int(d.get("souls", 0))
		d["upgrades"] = d.get("upgrades", {})
		d["runs"] = int(d.get("runs", 0))
		d["schema"] = 2
	return d


static func upgrade_level(d: Dictionary, id: String) -> int:
	return int(d.get("upgrades", {}).get(id, 0))
