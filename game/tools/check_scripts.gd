extends SceneTree
## Loads every game script (not addons) and reports parse/compile errors. Exit 1 on failure.
## godot --headless --path . -s res://tools/check_scripts.gd

func _initialize() -> void:
	var bad := 0
	for dir in ["res://systems", "res://run", "res://views", "res://ui", "res://scripts", "res://tools", "res://debug"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "check_scripts.gd":
				var s = load(dir + "/" + f)
				if s == null or not (s as Script).can_instantiate():
					print("FAIL ", dir + "/" + f)
					bad += 1
	print("scripts ok" if bad == 0 else "%d scripts failed" % bad)
	quit(1 if bad else 0)
