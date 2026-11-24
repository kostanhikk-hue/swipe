class_name Save
## Tiny persistent save: best depth. Schema-versioned (code.md rule 5).

const PATH := "user://save.json"
const SCHEMA_VERSION := 1


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"schema": SCHEMA_VERSION, "best_depth": 0}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return {"schema": SCHEMA_VERSION, "best_depth": 0}
	return _migrate(d)


static func store(d: Dictionary) -> void:
	d["schema"] = SCHEMA_VERSION
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


static func _migrate(d: Dictionary) -> Dictionary:
	# no older versions yet; future bumps add steps here
	if not d.has("best_depth"):
		d["best_depth"] = 0
	return d
