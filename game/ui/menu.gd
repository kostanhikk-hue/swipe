extends Node2D
## M09 main menu + M08 shrine (meta upgrades: speed and convenience only).
## Keys: 1 / Enter — new run, 2 — shrine, 3 / Esc — quit; in the shrine 1..3 buy, Esc back.

const E := preload("res://scripts/engrave.gd")
const DungeonView := preload("res://views/dungeon_view.gd")
const RUN_SCENE := "res://scenes/gyms/loop_gym.tscn"

var save := {}
var meta := {}
var screen := "main"
var buttons: Array = []   # [{rect, label, do}]
var hover := -1
var overlay: Node2D
var back: Node2D
var front: Node2D
var _flash := ""
var _sfx: AudioStreamPlayer


func _ready() -> void:
	Engine.time_scale = 1.0
	save = Save.load_data()
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/m08/meta.json"))
	back = DungeonView.new()
	front = DungeonView.new()
	front.layer = "vignette"
	overlay = Node2D.new()
	for n in [back, front, overlay]:
		add_child(n)
	overlay.draw.connect(_draw_overlay)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	var clear := [_soft(Rect2(270, 40, 740, 230)), _soft(Rect2(380, 260, 520, 340))]
	back.clear = clear
	front.clear = clear
	_layout()


func _layout() -> void:
	buttons.clear()
	if screen == "main":
		var items := [["Новый забег", "run"], ["Святилище", "shrine"], ["Выход", "quit"]]
		for i in items.size():
			buttons.append({"rect": Rect2(440, 300 + i * 80, 400, 62), "label": "%d · %s" % [i + 1, items[i][0]], "do": items[i][1]})
	else:
		var ups: Array = meta["upgrades"]
		for i in ups.size():
			buttons.append({"rect": Rect2(400, 280 + i * 84, 480, 72), "label": "", "do": "buy:%d" % i})
		buttons.append({"rect": Rect2(540, 540, 200, 46), "label": "Esc · назад", "do": "back"})
	overlay.queue_redraw()


func _draw_overlay() -> void:
	var o := overlay
	var bold := Fonts.bold()
	var reg := Fonts.regular()
	o.draw_string(bold, Vector2(300, 150), "РЕЛИКВАРИЙ", HORIZONTAL_ALIGNMENT_CENTER, 680, 92, E.INK)
	o.draw_string(reg, Vector2(300, 196), "каждый дроп — выбор", HORIZONTAL_ALIGNMENT_CENTER, 680, 26, E.INK_FADED)
	o.draw_string(bold, Vector2(300, 232), "рекорд глубины %d · души %d · забегов %d" % [int(save["best_depth"]), int(save["souls"]), int(save["runs"])],
		HORIZONTAL_ALIGNMENT_CENTER, 680, 22, E.CINNABAR)
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var r: Rect2 = b["rect"]
		var hot := i == hover
		o.draw_rect(r, Color(E.PAPER_LIGHT, 0.95 if hot else 0.8))
		o.draw_rect(r, E.INK, false, 3.0 if hot else 1.5)
		o.draw_rect(r.grow(-5), E.INK, false, 1.0)
		if String(b["do"]).begins_with("buy:"):
			_draw_upgrade(o, r, int(String(b["do"]).get_slice(":", 1)), hot)
		else:
			o.draw_string(bold, r.position + Vector2(0, r.size.y / 2 + 11), b["label"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30 if screen == "main" else 22, E.INK)
	if screen == "shrine":
		o.draw_string(bold, Vector2(300, 266), "Святилище: души → скорость и удобство (не сила героя)", HORIZONTAL_ALIGNMENT_CENTER, 680, 20, E.INK)
	if _flash != "":
		o.draw_string(bold, Vector2(300, 620), _flash, HORIZONTAL_ALIGNMENT_CENTER, 680, 22, E.CINNABAR)


func _draw_upgrade(o: Node2D, r: Rect2, i: int, _hot: bool) -> void:
	var u: Dictionary = meta["upgrades"][i]
	var lv := Save.upgrade_level(save, u["id"])
	var levels: Array = u["levels"]
	var maxed := lv >= levels.size()
	var bold := Fonts.bold()
	var reg := Fonts.regular()
	var desc := String(u["desc"])
	if "%s" in desc:
		desc = desc % str(levels[mini(lv, levels.size() - 1)]["v"]).replace(".", ",")
	o.draw_string(bold, r.position + Vector2(16, 30), "%d · %s  %s" % [i + 1, u["name"], "★".repeat(lv) if lv > 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 140, 22, E.INK)
	o.draw_string(reg, r.position + Vector2(16, 56), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 140, 17, E.INK_FADED)
	var price := "куплено" if maxed else "%d душ" % int(levels[lv]["cost"])
	var ok := maxed or int(save["souls"]) >= int(levels[lv]["cost"])
	o.draw_string(bold, r.position + Vector2(r.size.x - 130, 44), price, HORIZONTAL_ALIGNMENT_RIGHT, 114, 22, Pal.stat("алчность") if ok else E.CINNABAR)


func _do(what: String) -> void:
	_flash = ""
	match what:
		"run":
			get_tree().change_scene_to_file(RUN_SCENE)
		"shrine":
			screen = "shrine"
			_layout()
		"back":
			screen = "main"
			_layout()
		"quit":
			get_tree().quit()
		_:
			if what.begins_with("buy:"):
				_buy(int(what.get_slice(":", 1)))


func _buy(i: int) -> void:
	var u: Dictionary = meta["upgrades"][i]
	var lv := Save.upgrade_level(save, u["id"])
	var levels: Array = u["levels"]
	if lv >= levels.size():
		return
	var cost := int(levels[lv]["cost"])
	if int(save["souls"]) < cost:
		_flash = "не хватает душ: нужно %d" % cost
		overlay.queue_redraw()
		return
	save["souls"] = int(save["souls"]) - cost
	save["upgrades"][u["id"]] = lv + 1
	Save.store(save)
	_flash = "%s — получено" % u["name"]
	_layout()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := -1
		for i in buttons.size():
			if (buttons[i]["rect"] as Rect2).has_point(e.position):
				h = i
		if h != hover:
			hover = h
			overlay.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hover >= 0:
		_do(buttons[hover]["do"])
	elif e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k == KEY_ESCAPE:
			_do("back" if screen == "shrine" else "quit")
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			if screen == "main":
				_do("run")
		elif k >= KEY_1 and k <= KEY_9:
			var i := k - KEY_1
			if i < buttons.size():
				_do(buttons[i]["do"])


func _soft(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center()
	for i in 28:
		var d := Vector2.from_angle(TAU * i / 28.0)
		var k := 1.0 / maxf(absf(d.x) / (r.size.x * 0.5), absf(d.y) / (r.size.y * 0.5))
		pts.append(c + d * k * (1.0 + 0.06 * sin(i * 2.3)))
	return pts
