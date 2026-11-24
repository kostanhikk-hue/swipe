extends CanvasLayer
## Live tuning: Tab shows sliders for every ranged property of the bound Resource; P dumps JSON.

var target: Resource
var mech_id := ""
var _box: VBoxContainer


func bind(res: Resource, id: String) -> void:
	target = res
	mech_id = id
	layer = 100
	visible = false
	if _box:
		_box.queue_free()
	var bg := PanelContainer.new()
	bg.position = Vector2(20, 120)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 540)
	bg.add_child(scroll)
	_box = VBoxContainer.new()
	scroll.add_child(_box)
	for p in res.get_property_list():
		if p["hint"] != PROPERTY_HINT_RANGE:
			continue
		var r: PackedStringArray = p["hint_string"].split(",")
		var s := HSlider.new()
		var l := Label.new()
		var n: String = p["name"]
		s.min_value = float(r[0])
		s.max_value = float(r[1])
		s.step = float(r[2]) if r.size() > 2 else 0.01
		s.value = res.get(n)
		s.custom_minimum_size.x = 300
		s.focus_mode = Control.FOCUS_NONE
		l.text = "%s = %s" % [n, s.value]
		s.value_changed.connect(func(v: float): _on_slider(n, v, l))
		_box.add_child(l)
		_box.add_child(s)


func refresh() -> void:
	if target:
		bind(target, mech_id)
		visible = true


func _on_slider(n: String, v: float, l: Label) -> void:
	target.set(n, v)
	l.text = "%s = %s" % [n, v]


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_TAB:
			visible = not visible
			get_viewport().set_input_as_handled()
		elif e.physical_keycode == KEY_P:
			_dump()


func _dump() -> void:
	var d := {}
	for p in target.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[p["name"]] = target.get(p["name"])
	var dir := ProjectSettings.globalize_path("res://").path_join("../.studioigor/captures/tuning")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("%s/%s-%d.json" % [dir, mech_id, int(Time.get_unix_time_from_system())], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "  "))
	print("TUNING ", JSON.stringify(d))
