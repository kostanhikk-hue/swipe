extends Node2D
## Hero stats and what they mean together (DPS, armor reduction, lifesteal per second),
## plus the current enemy's stats under its health bar.

const E := preload("res://scripts/engrave.gd")
const AREA := Rect2(40, 124, 300, 300)
const ORDER := ["урон", "скорость", "крит", "броня", "блок", "вампиризм", "жизнь"]
const EXTRA := {"critdmg": "сила крита", "pen": "пробивание", "poison": "яд", "onset": "натиск", "execute": "казнь",
	"fury": "ярость", "riposte": "ответный удар", "ward": "оберег", "thorns": "шипы", "regen": "регенерация",
	"rest": "передышка", "vuln": "уязвимость", "greed": "алчность", "luck": "удача"}

var hero := {}       # Combat.hero_from(...) dict
var enemy := {}      # current enemy fighter dict or {}
var k := 100.0
var crit_mult := 2.0
var block_cap := 60.0
var _key := ""


func set_data(h: Dictionary, e: Dictionary, t: CombatTuning) -> void:
	var key := str(h) + str(e)
	if key == _key:
		return
	_key = key
	hero = h
	enemy = e
	k = t.armor_k
	crit_mult = t.crit_mult
	block_cap = t.block_cap
	queue_redraw()


func dps(f: Dictionary) -> float:
	return Formulas.dps(float(f["dmg"]), float(f["speed"]), float(f["crit"]), crit_mult + float(f.get("critdmg", 0.0)) / 100.0)


func _draw() -> void:
	if hero.is_empty():
		return
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var x := AREA.position.x + 8
	var y := AREA.position.y + 20
	draw_string(bold, Vector2(x, y), "герой", HORIZONTAL_ALIGNMENT_LEFT, 120, 21, E.INK)
	draw_string(bold, Vector2(x + 110, y), "≈ %d урона/с" % roundi(dps(hero)), HORIZONTAL_ALIGNMENT_RIGHT, 170, 21, Pal.text("урон"))
	y += 30
	var shown := ORDER.duplicate()
	for key in EXTRA:
		if absf(float(hero.get(key, 0.0))) > 0.001:
			shown.append(EXTRA[key])
	var room := AREA.end.y - y - (24.0 if not enemy.is_empty() else 0.0)
	var step := clampf(room / shown.size(), 15.0, 24.0)
	var fs := 17 if step >= 20.0 else 15
	for s in shown:
		var v := _val(s)
		var note := _note(s)
		Pal.stat_icon(self, s, Vector2(x + 8, y - 5), 7.0 if fs == 17 else 6.0)
		draw_string(bold, Vector2(x + 22, y), s, HORIZONTAL_ALIGNMENT_LEFT, 100, fs, Pal.text(s))
		draw_string(bold, Vector2(x + 120, y), v, HORIZONTAL_ALIGNMENT_LEFT, 50, fs, E.INK)
		draw_string(reg, Vector2(x + 168, y), note, HORIZONTAL_ALIGNMENT_LEFT, 128, fs - 2, E.INK_FADED)
		y += step
	if not enemy.is_empty():
		var through := Formulas.armor_damage(float(hero["dmg"]), float(enemy["armor"]) * (1.0 - minf(80.0, float(hero.get("pen", 0.0))) / 100.0), k)
		draw_string(reg, Vector2(x, y + 6), "по врагу: −%d за удар" % roundi(through), HORIZONTAL_ALIGNMENT_LEFT, 290, 17, E.INK)
		_enemy_line()


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
			return "%d%%" % roundi(minf(block_cap, hero["block"]))
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
		"яд", "натиск", "казнь", "ярость", "ответный удар", "передышка", "удача", "уязвимость":
			return "%d%%" % roundi(hero[_key_of(s)])
		"оберег":
			return str(roundi(hero["ward"]))
	return ""


func _key_of(stat: String) -> String:
	for k in EXTRA:
		if EXTRA[k] == stat:
			return k
	return ""


func _note(s: String) -> String:
	match s:
		"урон":
			return "за удар"
		"скорость":
			return "уд/с с проворством"
		"крит":
			return "шанс ×%s урона" % str(snappedf(crit_mult + float(hero.get("critdmg", 0.0)) / 100.0, 0.01)).replace(".", ",")
		"броня":
			return "−%d%% входящего" % roundi(100.0 * float(hero["armor"]) / (float(hero["armor"]) + k))
		"блок":
			return "отражает удары"
		"вампиризм":
			return "+%s HP/с" % ("%.1f" % (dps(hero) * float(hero["vamp"]) / 100.0)).replace(".", ",")
		"жизнь":
			return "запас здоровья"
		"сила крита":
			return "к множителю крита"
		"пробивание":
			return "брони врага игнор."
		"шипы":
			return "урон тому, кто бьёт"
		"регенерация":
			return "HP в секунду"
		"алчность":
			return "монет за бой" if float(hero["greed"]) >= 0.0 else "меньше монет"
		"яд":
			return "от удара ядом за 3 с"
		"натиск":
			return "к первому удару"
		"казнь":
			return "урон по врагу <30%"
		"ярость":
			return "урон при жизни <35%"
		"ответный удар":
			return "урона после блока"
		"оберег":
			return "щит в начале боя"
		"передышка":
			return "жизни после победы"
		"уязвимость":
			return "входящего урона"
		"удача":
			return "редкий дроп чаще"
	return ""


func _enemy_line() -> void:
	var bold := Fonts.bold()
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
	var w := 62.0
	var x := 640.0 - parts.size() * w / 2.0
	var plate := Rect2(x - 6, 100, parts.size() * w + 8, 28)   # paper under the line: crowns and heads sit behind
	draw_rect(plate, Color(E.PAPER_LIGHT, 0.94))
	draw_rect(plate, E.INK, false, 1.2)
	for p in parts:
		Pal.stat_icon(self, p[0], Vector2(x + 10, 113), 8.0)
		draw_string(bold, Vector2(x + 22, 120), p[1], HORIZONTAL_ALIGNMENT_LEFT, 44, 19, Pal.text(p[0]))
		x += w
