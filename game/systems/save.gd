class_name Save
## Tiny persistent save: record, souls, shrine, tips, bestiary, history, settings, vows.
## Schema-versioned (code.md rule 5): v1 → v2 (souls, upgrades) → v3 (seen, history, settings, vows).

const PATH := "user://save.json"
const SCHEMA_VERSION := 3
const SETTINGS := {"sfx": 0.8, "music": 0.6, "fullscreen": false, "shake": 1.0, "junk_on": true}


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return _migrate({"schema": SCHEMA_VERSION, "best_depth": 0, "souls": 0})
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return _migrate({"schema": SCHEMA_VERSION, "best_depth": 0, "souls": 0})
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
	# v2 → v3: bestiary, run history, settings, chosen vows; the omen upgrade became free
	if int(d.get("schema", 2)) < 3:
		d["upgrades"] = d.get("upgrades", {})
		if d["upgrades"].has("omen"):
			d["souls"] = int(d["souls"]) + 40   # refund: omen is free for everyone now
			d["upgrades"].erase("omen")
		d["schema"] = 3
	for k in ["seen", "history", "vow_pick", "tips"]:
		if not d.has(k) or typeof(d[k]) != TYPE_ARRAY:
			d[k] = []
	if not d.has("tips_on"):
		d["tips_on"] = true
	d["runs"] = int(d.get("runs", 0))
	d["souls"] = int(d.get("souls", 0))
	if typeof(d.get("upgrades")) != TYPE_DICTIONARY:
		d["upgrades"] = {}
	var st: Dictionary = d.get("settings", {}) if typeof(d.get("settings")) == TYPE_DICTIONARY else {}
	for k in SETTINGS:
		if not st.has(k):
			st[k] = SETTINGS[k]
	d["settings"] = st
	return d


static func upgrade_level(d: Dictionary, id: String) -> int:
	return int(d.get("upgrades", {}).get(id, 0))
