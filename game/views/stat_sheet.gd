extends Node2D
## Left sheet: the hero in two big numbers (attack per second, damage the hero can take), a compact
## grid of stats, explanations on hover (hover_at). Also the current enemy's stats in words under its
## health bar (with a tooltip).

const E := preload("res://scripts/engrave.gd")
const AREA := Rect2(22, 114, 338, 492)
const CORE := ["урон", "скорость", "крит", "броня", "блок", "вампиризм", "жизнь"]
const EXTRA := {"critdmg": "сила крита", "pen": "пробивание", "poison": "яд", "onset": "натиск", "execute": "казнь",
	"fury": "ярость", "riposte": "ответный удар", "ward": "оберег", "thorns": "шипы", "regen": "регенерация",
	"rest": "передышка", "vuln": "уязвимость", "greed": "алчность", "luck": "удача"}
const SHORT := {"сила крита": "с. крита", "пробивание": "пробив.", "ответный удар": "ответ", "регенерация": "реген.",
	"передышка": "передых.", "уязвимость": "уязвим.", "алчность": "алчность", "вампиризм": "вампир."}
const ENEMY_Y := 100.0

var hero := {}       # Combat.hero_from(...) dict
var enemy := {}      # current enemy fighter dict or {}
var t: CombatTuning
var _key := ""
var _cells: Array = []    # [rect, stat] for hover
var _head: Array = []     # [rect, "atk"|"def"]
var _enemy_rect := Rect2()


func set_data(h: Dictionary, e: Dictionary, tuning: CombatTuning) -> void:
	var key := str(h) + str(e)
	if key == _key:
		return
	_key = key
	hero = h
	enemy = e
	t = tuning
	queue_redraw()


func _draw() -> void:
	_cells.clear()
	_head.clear()
	if hero.is_empty():
		return
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	E.sheet(self, AREA, "герой")
	var x := AREA.position.x + 18
	var y := AREA.position.y + 74
	var pa := Formulas.build_parts(hero, t)
	# two big numbers
	for i in 2:
		var label := "атака" if i == 0 else "защита"
		var val := roundi(pa.x) if i == 0 else roundi(pa.y)
		var unit := "урона/с" if i == 0 else "держит урона"
		var col := Pal.text("урон") if i == 0 else Pal.text("броня")
		var r := Rect2(x - 4, y - 28, AREA.size.x - 28, 36)
		_head.append([r, "atk" if i == 0 else "def"])
		draw_string(bold, Vector2(x, y), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 110, 17, E.INK_FADED)
		draw_string(bold, Vector2(x + 96, y + 2), str(val), HORIZONTAL_ALIGNMENT_RIGHT, 92, 30, col)
		draw_string(reg, Vector2(x + 196, y), unit, HORIZONTAL_ALIGNMENT_LEFT, 120, 16, E.INK_FADED)
		y += 40
	if not enemy.is_empty():
		var through := Formulas.armor_damage(float(hero["dmg"]), float(enemy["armor"]) * (1.0 - minf(80.0, float(hero.get("pen", 0.0))) / 100.0), t.armor_k)
		var back := Formulas.armor_damage(float(enemy["dmg"]), float(hero["armor"]), t.armor_k) * (1.0 + float(hero.get("vuln", 0.0)) / 100.0)
		draw_string(reg, Vector2(x, y - 6), "вы бьёте по %d · враг по вам %d" % [roundi(through), roundi(back)], HORIZONTAL_ALIGNMENT_LEFT, 300, 15, E.INK)
		_enemy_line()
	y += 6
	draw_line(Vector2(x, y), Vector2(AREA.end.x - 18, y), Color(E.INK, 0.5), 1.0)
	y += 26
	# compact grid: core stats always, the rest when non-zero
	var shown := CORE.duplicate()
	for key in EXTRA:
		if absf(float(hero.get(key, 0.0))) > 0.001:
			shown.append(EXTRA[key])
	var col_w := (AREA.size.x - 36) / 2.0
	var rows := ceili(shown.size() / 2.0)
	var step := clampf((AREA.end.y - 120 - y) / rows, 18.0, 27.0)
	for i in shown.size():
		var s: String = shown[i]
		var cx := x + (i % 2) * col_w
		var cy := y + (i / 2) * step
		_cells.append([Rect2(cx - 4, cy - step + 6, col_w, step), s])
		Pal.stat_icon(self, s, Vector2(cx + 7, cy - 6), 7.0)
		draw_string(reg, Vector2(cx + 19, cy), SHORT.get(s, s), HORIZONTAL_ALIGNMENT_LEFT, 80, 16, Pal.text(s))
		draw_string(bold, Vector2(cx + 82, cy), _val(s), HORIZONTAL_ALIGNMENT_RIGHT, col_w - 88, 17, E.INK)


func _val(s: String) -> String:
	match s:
		"урон":
			return str(roundi(hero["dmg"]))
		"скорость":
			return ("%.2f" % float(hero["speed"])).replace(".", ",")
		"крит":
			return "%d%%" % roundi(hero["crit"])
		"броня":
			return str(roundi(hero["armor"]))
		"блок":
			return "%d%%" % roundi(minf(t.block_cap, hero["block"]))
		"вампиризм":
			return "%d%%" % roundi(hero["vamp"])
		"жизнь":
			return "%d" % roundi(hero["max_hp"])
		"сила крита":
			return "+%d%%" % roundi(hero["critdmg"])
		"пробивание":
			return "%d%%" % roundi(minf(80.0, hero["pen"]))
		"шипы":
			return str(roundi(hero["thorns"]))
		"регенерация":
			return ("%.1f" % float(hero["regen"])).replace(".", ",")
		"алчность":
			return "%+d%%" % roundi(hero["greed"])
		"оберег":
			return str(roundi(hero["ward"]))
	for k in EXTRA:
		if EXTRA[k] == s:
			return "%d%%" % roundi(hero[k])
	return ""


func _note(s: String) -> String:
	var k := t.armor_k
	match s:
		"урон":
			return "Урон одного удара до брони врага. Броня врага режет его: урон × 100 / (броня + 100)."
		"скорость":
			return "Ударов в секунду. Оружие задаёт базу, проворство ускоряет."
		"крит":
			return "Шанс крита. Крит бьёт ×%s." % str(snappedf(t.crit_mult + float(hero.get("critdmg", 0.0)) / 100.0, 0.01)).replace(".", ",")
		"броня":
			return "Срезает %d%% входящего урона (броня / (броня + 100))." % roundi(100.0 * float(hero["armor"]) / (float(hero["armor"]) + k))
		"блок":
			return "Шанс целиком отразить удар врага. Не больше %d%%." % roundi(t.block_cap)
		"вампиризм":
			return "Доля нанесённого урона возвращается жизнью."
		"жизнь":
			return "Запас здоровья. Само не восстанавливается: после победы немного, остальное — лечением (H)."
		"сила крита":
			return "Добавка к множителю крита."
		"пробивание":
			return "Доля брони врага, которую удары не замечают (до 80%)."
		"шипы":
			return "Урон каждому, кто ударил героя."
		"регенерация":
			return "Жизнь в секунду во время боя."
		"алчность":
			return "Больше монет за победы и продажу."
		"яд":
			return "Доля урона удара, которая догорает ядом ещё 3 секунды."
		"натиск":
			return "Прибавка к первому удару в каждом бою."
		"казнь":
			return "Прибавка к урону, когда у врага меньше 30% жизни."
		"ярость":
			return "Прибавка к урону, когда у героя меньше 35% жизни."
		"ответный удар":
			return "После блока герой бьёт в ответ этой долей урона."
		"оберег":
			return "Щит в начале каждого боя: поглощает столько урона."
		"передышка":
			return "Дополнительная доля жизни после каждой победы."
		"уязвимость":
			return "Проклятие: входящий урон больше на столько процентов."
		"удача":
			return "Редкие и легендарные вещи падают чаще."
	return ""


## Tooltip for the cell under p (or {}).
func hover_at(p: Vector2) -> Dictionary:
	if hero.is_empty():
		return {}
	if _enemy_rect.has_point(p) and not enemy.is_empty():
		return _enemy_tip()
	if not AREA.has_point(p):
		return {}
	for h in _head:
		if (h[0] as Rect2).has_point(p):
			if h[1] == "atk":
				return {"title": "Атака", "title_color": Pal.text("урон"), "lines": [
					["Средний урон в секунду с критами, ядом и шипами — по врагу с бронёй 20.", E.INK],
					["Растёт от урона, скорости, крита, пробивания.", E.INK_FADED]]}
			return {"title": "Защита", "title_color": Pal.text("броня"), "lines": [
				["Сколько урона врага герой выдержит с полной жизнью — с учётом брони, блока, вампиризма и оберега.", E.INK],
				["Растёт от жизни, брони, блока, вампиризма.", E.INK_FADED]]}
	for c in _cells:
		if (c[0] as Rect2).has_point(p):
			return {"title": "%s: %s" % [c[1], _val(c[1])], "title_color": Pal.text(c[1]), "lines": [[_note(c[1]), E.INK]]}
	return {}


func _enemy_parts() -> Array:
	var parts := [["урон", str(roundi(enemy["dmg"]))], ["скорость", ("%.1f" % float(enemy["speed"])).replace(".", ",")],
		["броня", str(roundi(enemy["armor"]))]]
	if float(enemy["crit"]) > 0:
		parts.append(["крит", "%d%%" % roundi(enemy["crit"])])
	if float(enemy["block"]) > 0:
		parts.append(["блок", "%d%%" % roundi(enemy["block"])])
	if float(enemy["vamp"]) > 0:
		parts.append(["вампиризм", "%d%%" % roundi(enemy["vamp"])])
	if float(enemy.get("thorns", 0)) > 0:
		parts.append(["шипы", str(roundi(enemy["thorns"]))])
	if float(enemy.get("regen", 0)) > 0:
		parts.append(["регенерация", ("%.1f" % float(enemy["regen"])).replace(".", ",")])
	if float(enemy.get("poison", 0)) > 0:
		parts.append(["яд", "%d%%" % roundi(enemy["poison"])])
	return parts


## The enemy's stats in words on a paper strip under its health bar.
func _enemy_line() -> void:
	var bold := Fonts.bold()
	var reg := Fonts.regular()
	var parts := _enemy_parts()
	var widths := []
	var total := 0.0
	for p in parts:
		var w: float = 22.0 + reg.get_string_size(SHORT.get(p[0], p[0]) + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + bold.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0
		widths.append(w)
		total += w
	var x := 640.0 - total / 2.0
	_enemy_rect = Rect2(x - 8, ENEMY_Y, total + 16, 28)
	draw_rect(_enemy_rect, Color(E.PAPER_LIGHT, 0.95))
	draw_rect(_enemy_rect, E.INK, false, 1.2)
	for i in parts.size():
		var p: Array = parts[i]
		Pal.stat_icon(self, p[0], Vector2(x + 8, ENEMY_Y + 13), 7.0)
		var nm: String = SHORT.get(p[0], p[0]) + " "
		draw_string(reg, Vector2(x + 18, ENEMY_Y + 20), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, E.INK_FADED)
		var nw := reg.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(bold, Vector2(x + 18 + nw, ENEMY_Y + 20), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.text(p[0]))
		x += widths[i]


func _enemy_tip() -> Dictionary:
	var lines := []
	var through := Formulas.armor_damage(float(hero["dmg"]), float(enemy["armor"]) * (1.0 - minf(80.0, float(hero.get("pen", 0.0))) / 100.0), t.armor_k)
	lines.append(["Ваш удар после его брони: %d (без крита)." % roundi(through), E.INK])
	lines.append(["Его удар после вашей брони: %d." % roundi(Formulas.armor_damage(float(enemy["dmg"]), float(hero["armor"]), t.armor_k)), E.CINNABAR])
	if float(enemy.get("poison", 0)) > 0:
		lines.append(["Яд: удары жгут ещё 3 с.", Pal.text("яд")])
	if float(enemy.get("steal", 0)) > 0:
		lines.append(["Каждый удар крадёт монеты.", Pal.text("алчность")])
	if int(enemy.get("stun", 0)) > 0:
		lines.append(["Каждый %d-й удар оглушает героя." % int(enemy["stun"]), E.CINNABAR])
	if float(enemy.get("thorns", 0)) > 0:
		lines.append(["Шипы: ранят за каждый ваш удар.", Pal.text("шипы")])
	return {"title": "враг", "lines": lines}
