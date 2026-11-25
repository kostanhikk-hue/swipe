extends Node2D
## Equipment as a paper doll (decision: slots where they sit on the body, like the artifact screen
## of Heroes of Might and Magic). Hover a slot — the item in a tooltip (hover_at). While a card is
## dragged, its target slot glows and the line under the doll says what will happen.

const E := preload("res://scripts/engrave.gd")
const PANEL := Rect2(996, 110, 262, 596)
const CELL := 46.0
const CX := 1127.0
const SLOT_NAMES := {"weapon": "оружие", "shield": "щит", "helm": "шлем", "armor": "броня", "gloves": "перчатки",
	"boots": "сапоги", "belt": "пояс", "amulet": "амулет", "ring1": "кольцо", "ring2": "кольцо"}
## slot centres on the doll
const SPOTS := {"helm": Vector2(CX, 178), "amulet": Vector2(CX + 62, 196), "armor": Vector2(CX, 252),
	"weapon": Vector2(CX - 86, 252), "shield": Vector2(CX + 86, 262), "gloves": Vector2(CX - 86, 324),
	"belt": Vector2(CX, 326), "ring1": Vector2(CX - 86, 396), "ring2": Vector2(CX + 86, 396), "boots": Vector2(CX, 412)}

var loadout: Loadout
var preview_slot := ""
var preview_text := ""
var preview_delta := 0.0
var slot_pos := {}          # slot -> cell centre (for flying cards and tips)
var _punch := {}            # slot -> 0..1 remaining
var _power_punch := 0.0
var _t := 0.0


func _ready() -> void:
	slot_pos = SPOTS.duplicate()


func punch(slot: String) -> void:
	_punch[slot] = 1.0
	_power_punch = 1.0
	queue_redraw()


func set_preview(slot: String, text: String, delta: float) -> void:
	if slot != preview_slot or text != preview_text or absf(delta - preview_delta) > 0.5:
		preview_slot = slot
		preview_text = text
		preview_delta = delta
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var busy := _power_punch > 0.0 or preview_slot != ""
	_power_punch = maxf(0.0, _power_punch - delta * 3.0)
	for k in _punch.keys():
		_punch[k] = maxf(0.0, _punch[k] - delta * 3.0)
		busy = busy or _punch[k] > 0.0
	if busy:
		queue_redraw()


func cell_rect(slot: String) -> Rect2:
	return Rect2(SPOTS[slot] - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL))


func _draw() -> void:
	if loadout == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	E.sheet(self, PANEL, "снаряжение")
	_figure(rng)
	for s in Loadout.SLOTS:
		_slot(s, rng)
	# what the dragged card will do
	var y := 452.0
	if preview_text != "":
		draw_string(bold, Vector2(PANEL.position.x + 12, y + 8), preview_text, HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x - 24, 16, E.INK)
	else:
		draw_string(reg, Vector2(PANEL.position.x + 12, y + 8), "наведите на вещь — подробности", HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x - 24, 14, E.INK_FADED)
	_resonance(PANEL.position.x + 16, y + 22, rng)
	# build power
	var pk := 1.0 + 0.35 * _ease(_power_punch)
	var py := PANEL.end.y - 16
	draw_line(Vector2(PANEL.position.x + 16, py - 34), Vector2(PANEL.end.x - 16, py - 34), Color(E.INK, 0.6), 1.0)
	draw_string(reg, Vector2(PANEL.position.x + 18, py), "сила", HORIZONTAL_ALIGNMENT_LEFT, 60, 22, E.INK)
	var mid := Vector2(PANEL.position.x + 120, py - 8)
	draw_set_transform(mid * (1.0 - pk), 0.0, Vector2.ONE * pk)
	draw_string(bold, Vector2(PANEL.position.x + 60, py), str(roundi(loadout.power())), HORIZONTAL_ALIGNMENT_RIGHT, 90, 28, E.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if preview_text != "" and absf(preview_delta) >= 0.5:
		draw_string(bold, Vector2(PANEL.position.x + 160, py), ("+%d" if preview_delta > 0 else "−%d") % absi(roundi(preview_delta)), HORIZONTAL_ALIGNMENT_LEFT, 80, 24, Color("#2E7D32") if preview_delta > 0 else E.CINNABAR)


## The hero's silhouette behind the slots: faint engraving.
func _figure(rng: RandomNumberGenerator) -> void:
	var col := Color(E.INK_FADED, 0.45)
	var torso := PackedVector2Array([Vector2(CX - 44, 214), Vector2(CX + 44, 214), Vector2(CX + 34, 340), Vector2(CX - 34, 340)])
	var head := E.ellipse(Vector2(CX, 176), Vector2(26, 30), 20)
	for poly in [torso, head]:
		E.hatch(self, poly, 0.9, 6.0, 0.8, rng, col)
		E.outline(self, poly, 1.4, col)
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(CX + side * 44, 220), Vector2(CX + side * 72, 280), Vector2(CX + side * 86, 330)]), col, 7.0, true)
		draw_polyline(PackedVector2Array([Vector2(CX + side * 20, 340), Vector2(CX + side * 26, 400), Vector2(CX + side * 30, 436)]), col, 9.0, true)


func _slot(s: String, rng: RandomNumberGenerator) -> void:
	var it: Dictionary = loadout.equipped[s]
	var r := int(it.get("rarity", 0))
	var cell := cell_rect(s)
	var k := 1.0 + 0.5 * _ease(_punch.get(s, 0.0))
	var c := cell.get_center()
	draw_set_transform(c * (1.0 - k), 0.0, Vector2.ONE * k)
	if s == preview_slot:   # the dragged card goes here
		var pulse := 0.5 + 0.5 * sin(_t * 8.0)
		draw_rect(cell.grow(6 + 2 * pulse), Color(E.CINNABAR, 0.25 + 0.25 * pulse))
	draw_rect(cell, E.PAPER_LIGHT if it.is_empty() else Color("#E2D3AE"))
	if it.is_empty():
		draw_rect(cell, Color(E.INK_FADED, 0.6), false, 1.2)
		var ghost := RandomNumberGenerator.new()
		ghost.seed = 3
		draw_set_transform(c * (1.0 - k), 0.0, Vector2.ONE * k)
		_ghost(s, c)
	else:
		ItemArt.rarity_frame(self, cell, r, 1.2)
		ItemArt.draw_item(self, s, c, 14, rng)
	if bool(it.get("cursed", false)):
		draw_rect(cell.grow(3), E.CINNABAR, false, 3.0)
	if bool(it.get("unique", false)):
		draw_circle(cell.position + Vector2(6, 6), 5.0, Pal.RARITY[3])
	var rk: int = loadout.rank[s]
	if rk > 0:   # sharpening badge
		var bc := cell.end - Vector2(4, 4)
		draw_circle(bc, 10.0, E.CINNABAR)
		draw_string(Fonts.bold(), bc + Vector2(-10, 5), "+%d" % rk, HORIZONTAL_ALIGNMENT_CENTER, 20, 13, E.PAPER_LIGHT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ghost(s: String, c: Vector2) -> void:
	var base := s.trim_suffix("1").trim_suffix("2")
	var poly := ItemArt.slot_poly(base, c, 13)
	E.outline(self, poly, 1.2, Color(E.INK_FADED, 0.35))


## Tooltip for the slot under p (or {}).
func hover_at(p: Vector2) -> Dictionary:
	if loadout == null or not PANEL.has_point(p):
		return {}
	for s in Loadout.SLOTS:
		if cell_rect(s).grow(3).has_point(p):
			return item_tip(loadout.equipped[s], s, loadout)
	if p.y > PANEL.end.y - 56:
		var pa := loadout.parts()
		return {"title": "сила %d" % roundi(loadout.power()), "lines": [
			["Итог билда: среднее атаки и защиты (√ атака × защита).", E.INK],
			["атака %d урона/с · защита %d" % [roundi(pa.x), roundi(pa.y)], E.INK_FADED]]}
	return {}


## Tooltip content for an item (also used by other views).
static func item_tip(it: Dictionary, slot: String, lo: Loadout) -> Dictionary:
	if it.is_empty():
		return {"title": SLOT_NAMES[slot], "lines": [["пусто — первая же вещь этого вида сюда встанет", E.INK_FADED]]}
	var r := int(it["rarity"])
	var lines := []
	var sub: String = ("проклятое" if bool(it.get("cursed", false)) else Pal.RARITY_NAME[r]) + " · " + String(it.get("type", "")).to_lower()
	if lo.rank[slot] > 0:
		sub += " · заточка +%d (+%d%%)" % [lo.rank[slot], roundi(float(lo.econ["melt_bonus"]) * 100.0 * lo.rank[slot])]
	lines.append([sub, Pal.RARITY_TEXT[r] if not bool(it.get("cursed", false)) else E.CINNABAR])
	var st := lo.slot_stats(slot)
	for k in Loadout.STAT_ORDER:
		if st.has(k):
			lines.append(["%s  %s" % [k, _fmt(k, float(st[k]))], Pal.text(k), 17])
	if not (it.get("tags", []) as Array).is_empty():
		lines.append(["теги: " + ", ".join(it["tags"]), E.INK_FADED])
	if bool(it.get("unique", false)):
		lines.append(["реликвия: " + String(it.get("effect", "")), Pal.RARITY_TEXT[3]])
	if bool(it.get("cursed", false)):
		lines.append(["проклятие: %s — снять нельзя" % it.get("curse", ""), E.CINNABAR])
	return {"title": it["name"], "title_color": Pal.RARITY_TEXT[r], "lines": lines}


static func _fmt(stat: String, f: float) -> String:
	if stat == "скорость":
		return ("%.2f уд/с" % f).replace(".", ",")
	if stat == "регенерация":
		return ("%.1f/с" % f).replace(".", ",")
	if stat in Pal.PCT:
		return "%+d%%" % roundi(f)
	return "%+d" % roundi(f)


## M04: tag counters under the doll — "кровь 3/4 +5 вамп.".
func _resonance(x: float, y: float, rng: RandomNumberGenerator) -> void:
	if loadout.resonance.is_empty():
		return
	var counts := loadout.tag_counts()
	var tags := counts.keys()
	tags.sort_custom(func(a, b): return counts[a] > counts[b])
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var ths := "/".join((loadout.resonance["thresholds"] as Array).map(func(v): return str(int(v))))
	draw_string(reg, Vector2(x, y + 14), "резонанс тегов · " + ths, HORIZONTAL_ALIGNMENT_LEFT, 230, 14, E.INK_FADED)
	y += 34
	if tags.is_empty():
		draw_string(reg, Vector2(x, y), "пока нет тегов", HORIZONTAL_ALIGNMENT_LEFT, 230, 15, E.INK_FADED)
	for tg in tags.slice(0, 3):
		var n := int(counts[tg])
		var lv := loadout.resonance_level(n)
		var th: Array = loadout.resonance["thresholds"]
		var nxt := int(th[mini(lv, th.size() - 1)])
		var r: Dictionary = loadout.resonance["tags"].get(tg, {})
		draw_string(bold if lv > 0 else reg, Vector2(x, y), "%s %d/%d" % [tg, n, nxt], HORIZONTAL_ALIGNMENT_LEFT, 110, 17, E.INK if lv > 0 else E.INK_FADED)
		if lv > 0:
			draw_string(bold, Vector2(x + 104, y), "+%d %s" % [roundi(float(r["v"][lv - 1])), _short(r["stat"])], HORIZONTAL_ALIGNMENT_LEFT, 130, 15, Pal.text(r.get("stat", "")))
		y += 21


func _short(stat: String) -> String:
	return {"вампиризм": "вампир.", "пробивание": "пробив.", "сила крита": "с. крита", "алчность": "алчн."}.get(stat, stat)


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
