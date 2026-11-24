extends Node2D
## Hero stats and what they mean together (DPS, armor reduction, lifesteal per second),
## plus the current enemy's stats under its health bar.

const E := preload("res://scripts/engrave.gd")
const AREA := Rect2(40, 124, 300, 262)
const ORDER := ["урон", "скорость", "крит", "броня", "блок", "вампиризм", "жизнь"]

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
	return Formulas.dps(float(f["dmg"]), float(f["speed"]), float(f["crit"]), crit_mult)


func _draw() -> void:
	if hero.is_empty():
		return
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var x := AREA.position.x + 8
	var y := AREA.position.y + 20
	draw_string(bold, Vector2(x, y), "герой", HORIZONTAL_ALIGNMENT_LEFT, 120, 21, E.INK)
	draw_string(bold, Vector2(x + 110, y), "≈ %d урона/с" % roundi(dps(hero)), HORIZONTAL_ALIGNMENT_RIGHT, 170, 21, Pal.stat("урон"))
	y += 30
	for s in ORDER:
		var v := _val(s)
		var note := _note(s)
		Pal.stat_icon(self, s, Vector2(x + 8, y - 7), 8.0)
		draw_string(bold, Vector2(x + 24, y), s, HORIZONTAL_ALIGNMENT_LEFT, 100, 19, Pal.stat(s))
		draw_string(bold, Vector2(x + 110, y), v, HORIZONTAL_ALIGNMENT_LEFT, 60, 19, E.INK)
		draw_string(reg, Vector2(x + 160, y), note, HORIZONTAL_ALIGNMENT_LEFT, 135, 16, E.INK_FADED)
		y += 26
	if not enemy.is_empty():
		var through := Formulas.armor_damage(float(hero["dmg"]), float(enemy["armor"]), k)
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
	return ""


func _note(s: String) -> String:
	match s:
		"урон":
			return "за удар"
		"скорость":
			return "уд/с с проворством"
		"крит":
			return "шанс ×%s урона" % str(crit_mult).replace(".", ",")
		"броня":
			return "−%d%% входящего" % roundi(100.0 * float(hero["armor"]) / (float(hero["armor"]) + k))
		"блок":
			return "отражает удары"
		"вампиризм":
			return "+%s HP/с" % ("%.1f" % (dps(hero) * float(hero["vamp"]) / 100.0)).replace(".", ",")
		"жизнь":
			return "запас здоровья"
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
	var w := 62.0
	var x := 640.0 - parts.size() * w / 2.0
	for p in parts:
		Pal.stat_icon(self, p[0], Vector2(x + 10, 132), 8.0)
		draw_string(bold, Vector2(x + 22, 139), p[1], HORIZONTAL_ALIGNMENT_LEFT, 44, 19, Pal.stat(p[0]))
		x += w
