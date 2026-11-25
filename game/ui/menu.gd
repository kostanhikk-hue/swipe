extends Node2D
## M09 main menu + M08 shrine (speed and convenience only) + vows, bestiary, settings.
## Keys: digits pick a line, Enter — new run, Esc — back / quit; settings: ←/→ change the line.

const E := preload("res://scripts/engrave.gd")
const DungeonView := preload("res://views/dungeon_view.gd")
const RUN_SCENE := "res://scenes/run.tscn"

var save := {}
var meta := {}
var enemies := {}
var screen := "main"     # main | shrine | vows | bestiary | settings
var buttons: Array = []   # [{rect, label, do}]
var hover := -1
var overlay: Node2D
var back: Node2D
var front: Node2D
var _flash := ""


func _ready() -> void:
	Engine.time_scale = 1.0
	save = Save.load_data()
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/m08/meta.json"))
	enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/enemies.json"))
	back = DungeonView.new()
	front = DungeonView.new()
	front.layer = "vignette"
	overlay = Node2D.new()
	for n in [back, front, overlay]:
		add_child(n)
	overlay.draw.connect(_draw_overlay)
	var clear := [_soft(Rect2(270, 40, 740, 230)), _soft(Rect2(360, 260, 560, 420))]
	back.clear = clear
	front.clear = clear
	Game.music("menu")
	_layout()


func _vows_open() -> bool:
	return Save.upgrade_level(save, "vows") > 0


func _layout() -> void:
	buttons.clear()
	match screen:
		"main":
			var items := [["Новый забег", "run"], ["Святилище", "shrine"], ["Бестиарий", "bestiary"], ["Настройки", "settings"], ["Выход", "quit"]]
			for i in items.size():
				buttons.append({"rect": Rect2(440, 286 + i * 66, 400, 56), "label": "%d · %s" % [i + 1, items[i][0]], "do": items[i][1]})
		"shrine":
			var ups: Array = meta["upgrades"]
			for i in ups.size():
				buttons.append({"rect": Rect2(380, 282 + i * 66, 520, 60), "label": "", "do": "buy:%d" % i})
			buttons.append({"rect": Rect2(540, 616, 200, 42), "label": "Esc · назад", "do": "back"})
		"vows":
			var vs: Array = meta["vows"]
			for i in vs.size():
				buttons.append({"rect": Rect2(380, 282 + i * 66, 520, 60), "label": "", "do": "vow:%d" % i})
			buttons.append({"rect": Rect2(380, 616, 250, 42), "label": "Enter · в путь", "do": "go"})
			buttons.append({"rect": Rect2(650, 616, 250, 42), "label": "Esc · назад", "do": "back"})
		"settings":
			var rows := _settings_rows()
			for i in rows.size():
				buttons.append({"rect": Rect2(400, 282 + i * 52, 480, 46), "label": rows[i][0], "do": "set:" + rows[i][1]})
			buttons.append({"rect": Rect2(540, 616, 200, 42), "label": "Esc · назад", "do": "back"})
		"bestiary":
			buttons.append({"rect": Rect2(540, 640, 200, 40), "label": "Esc · назад", "do": "back"})
	overlay.queue_redraw()


func _settings_rows() -> Array:
	var s: Dictionary = save["settings"]
	var pct := func(v) -> String: return "%d%%" % roundi(float(v) * 100.0)
	var rows := [["Музыка: %s   ← →" % pct.call(s["music"]), "music"], ["Звуки: %s   ← →" % pct.call(s["sfx"]), "sfx"],
		["Тряска экрана: %s   ← →" % pct.call(s["shake"]), "shake"],
		["Полный экран: " + ("да" if bool(s["fullscreen"]) else "нет"), "fullscreen"],
		["Подсказки: " + ("вкл" if bool(save.get("tips_on", true)) else "выкл"), "tips"]]
	if Save.upgrade_level(save, "junk") > 0:
		rows.append(["Сборщик хлама: " + ("вкл" if bool(s["junk_on"]) else "выкл"), "junk_on"])
	return rows


func _draw_overlay() -> void:
	var o := overlay
	var bold := Fonts.bold()
	var reg := Fonts.regular()
	o.draw_string(Fonts.title(), Vector2(300, 150), "РЕЛИКВАРИЙ", HORIZONTAL_ALIGNMENT_CENTER, 680, 92, E.INK)
	# a parchment plate under the subtitle: the dark doorway is right behind it
	var plate := Rect2(400, 168, 480, 76)
	o.draw_rect(plate, Color(E.PAPER_LIGHT, 0.96))
	o.draw_rect(plate, E.INK, false, 2.0)
	o.draw_rect(plate.grow(-5), E.INK, false, 1.0)
	var title: String = {"main": "каждый дроп — выбор", "shrine": "Святилище", "vows": "Обеты перед забегом",
		"bestiary": "Бестиарий", "settings": "Настройки"}[screen]
	o.draw_string(reg, Vector2(400, 200), title, HORIZONTAL_ALIGNMENT_CENTER, 480, 26, E.INK)
	var sub := "рекорд глубины %d · души %d · забегов %d" % [int(save["best_depth"]), int(save["souls"]), int(save["runs"])]
	if screen == "shrine":
		sub = "души %d → скорость и удобство, не сила героя" % int(save["souls"])
	elif screen == "vows":
		sub = "обеты делают забег труднее; душ больше: ×%s" % str(snappedf(_vow_mult(), 0.01)).replace(".", ",")
	elif screen == "bestiary":
		sub = "встречено %d из %d" % [_seen_count(), _all_foes().size()]
	o.draw_string(bold, Vector2(400, 232), sub, HORIZONTAL_ALIGNMENT_CENTER, 480, 19, E.CINNABAR)
	if screen == "bestiary":
		_draw_bestiary(o)
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var r: Rect2 = b["rect"]
		var hot := i == hover
		o.draw_rect(r, Color(E.PAPER_LIGHT, 0.96 if hot else 0.85))
		o.draw_rect(r, E.INK, false, 3.0 if hot else 1.5)
		o.draw_rect(r.grow(-5), E.INK, false, 1.0)
		var d := String(b["do"])
		if d.begins_with("buy:"):
			_draw_upgrade(o, r, int(d.get_slice(":", 1)))
		elif d.begins_with("vow:"):
			_draw_vow(o, r, int(d.get_slice(":", 1)))
		else:
			var fs := 28 if screen == "main" else 21
			o.draw_string(bold, r.position + Vector2(0, r.size.y / 2 + fs * 0.36), b["label"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, E.INK)
	if _flash != "":
		var fr := Rect2(340, 668, 600, 34)
		o.draw_rect(fr, Color(E.PAPER_LIGHT, 0.95))
		o.draw_string(bold, Vector2(340, 692), _flash, HORIZONTAL_ALIGNMENT_CENTER, 600, 20, E.CINNABAR)


func _draw_upgrade(o: Node2D, r: Rect2, i: int) -> void:
	var u: Dictionary = meta["upgrades"][i]
	var lv := Save.upgrade_level(save, u["id"])
	var levels: Array = u["levels"]
	var maxed := lv >= levels.size()
	var desc := String(u["desc"])
	if "%s" in desc:
		desc = desc % str(levels[mini(lv, levels.size() - 1)]["v"]).replace(".", ",")
	o.draw_string(Fonts.bold(), r.position + Vector2(16, 26), "%d · %s  %s" % [i + 1, u["name"], "★".repeat(lv) if lv > 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 21, E.INK)
	o.draw_string(Fonts.regular(), r.position + Vector2(16, 49), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 15, E.INK_FADED)
	var price := "куплено" if maxed else "%d душ" % int(levels[lv]["cost"])
	var ok := maxed or int(save["souls"]) >= int(levels[lv]["cost"])
	o.draw_string(Fonts.bold(), r.position + Vector2(r.size.x - 124, 38), price, HORIZONTAL_ALIGNMENT_RIGHT, 110, 21, Pal.text("алчность") if ok else E.CINNABAR)


func _draw_vow(o: Node2D, r: Rect2, i: int) -> void:
	var v: Dictionary = meta["vows"][i]
	var on: bool = v["id"] in save["vow_pick"]
	o.draw_string(Fonts.bold(), r.position + Vector2(16, 26), "%d · %s %s" % [i + 1, v["name"], "✓" if on else ""], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 21, E.CINNABAR if on else E.INK)
	o.draw_string(Fonts.regular(), r.position + Vector2(16, 49), v["desc"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 15, E.INK_FADED)
	o.draw_string(Fonts.bold(), r.position + Vector2(r.size.x - 124, 38), "+%d%% душ" % roundi(float(v["souls"]) * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 110, 19, Pal.text("алчность"))


func _all_foes() -> Array:
	return (enemies["types"] as Array) + (enemies["bosses"] as Array)


func _seen_count() -> int:
	return _all_foes().filter(func(e): return e["id"] in save["seen"]).size()


func _draw_bestiary(o: Node2D) -> void:
	var foes := _all_foes()
	var bold := Fonts.bold()
	var reg := Fonts.regular()
	var col_w := 290.0
	for i in foes.size():
		var e: Dictionary = foes[i]
		var cx := 352.0 + (i % 2) * (col_w + 10)
		var cy := 262.0 + (i / 2) * 64
		var r := Rect2(cx, cy, col_w, 58)
		o.draw_rect(r, Color(E.PAPER_LIGHT, 0.9))
		o.draw_rect(r, E.INK, false, 1.2)
		if e["id"] in save["seen"]:
			var boss: bool = e in (enemies["bosses"] as Array)
			o.draw_string(bold, r.position + Vector2(10, 22), ("босс · " if boss else "") + String(e["name"]), HORIZONTAL_ALIGNMENT_LEFT, col_w - 20, 17, E.CINNABAR if boss else E.INK)
			var line := "жизнь %d · урон %d · бр. %d" % [int(e["hp"]), int(e["dmg"]), int(e["armor"])]
			o.draw_string(reg, r.position + Vector2(10, 38), line, HORIZONTAL_ALIGNMENT_LEFT, col_w - 20, 13, E.INK_FADED)
			o.draw_string(reg, r.position + Vector2(10, 52), String(e.get("special", "")), HORIZONTAL_ALIGNMENT_LEFT, col_w - 20, 13, E.INK)
		else:
			o.draw_string(bold, r.position + Vector2(10, 34), "??? — ещё не встречен", HORIZONTAL_ALIGNMENT_LEFT, col_w - 20, 17, E.INK_FADED)


func _vow_mult() -> float:
	var m := 1.0
	for v in meta["vows"]:
		if v["id"] in save["vow_pick"]:
			m += float(v["souls"])
	return m


func _do(what: String) -> void:
	_flash = ""
	match what:
		"run":
			if _vows_open():
				screen = "vows"
				_layout()
			else:
				save["vow_pick"] = []
				Save.store(save)
				get_tree().change_scene_to_file(RUN_SCENE)
		"go":
			Save.store(save)
			get_tree().change_scene_to_file(RUN_SCENE)
		"shrine", "bestiary", "settings":
			screen = what
			_layout()
		"back":
			screen = "main"
			_layout()
		"quit":
			get_tree().quit()
		_:
			if what.begins_with("buy:"):
				_buy(int(what.get_slice(":", 1)))
			elif what.begins_with("vow:"):
				var id: String = meta["vows"][int(what.get_slice(":", 1))]["id"]
				if id in save["vow_pick"]:
					save["vow_pick"].erase(id)
				else:
					save["vow_pick"].append(id)
				_layout()
			elif what.begins_with("set:"):
				_setting(what.get_slice(":", 1), 1)


## Settings line: dir = +1 / −1 (←/→ or click = +1).
func _setting(key: String, dir: int) -> void:
	var s: Dictionary = save["settings"]
	match key:
		"music", "sfx", "shake":
			var v := float(s[key]) + 0.1 * dir
			if v > 1.001:
				v = 0.0   # a click past 100% wraps to 0
			s[key] = clampf(snappedf(v, 0.1), 0.0, 1.0)
		"fullscreen", "junk_on":
			s[key] = not bool(s[key])
		"tips":
			var on := not bool(save.get("tips_on", true))
			save["tips_on"] = on
			if on:
				save["tips"] = []   # turning tips back on shows them all again
			_flash = "подсказки включены — покажутся заново" if on else "подсказки выключены"
	Save.store(save)
	Game.apply(s)
	_layout()


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
			_do("quit" if screen == "main" else "back")
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			if screen == "main":
				_do("run")
			elif screen == "vows":
				_do("go")
		elif screen == "settings" and k in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D] and hover >= 0:
			var d := String(buttons[hover]["do"])
			if d.begins_with("set:"):
				_setting(d.get_slice(":", 1), 1 if k in [KEY_RIGHT, KEY_D] else -1)
		elif k >= KEY_1 and k <= KEY_9:
			var i := k - KEY_1
			if i < buttons.size():
				hover = i
				_do(buttons[i]["do"])


func _soft(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center()
	for i in 28:
		var d := Vector2.from_angle(TAU * i / 28.0)
		var k := 1.0 / maxf(absf(d.x) / (r.size.x * 0.5), absf(d.y) / (r.size.y * 0.5))
		pts.append(c + d * k * (1.0 + 0.06 * sin(i * 2.3)))
	return pts
