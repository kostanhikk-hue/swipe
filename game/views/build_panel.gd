extends Node2D
## Equipped items grouped by rarity, sharpening ranks, build power; Reigns-like preview.

const E := preload("res://scripts/engrave.gd")
const PANEL := Rect2(1046, 116, 206, 556)
const SLOT_NAMES := {"weapon": "оружие", "shield": "щит", "helm": "шлем", "armor": "броня", "gloves": "перчатки",
	"boots": "сапоги", "belt": "пояс", "amulet": "амулет", "ring1": "кольцо", "ring2": "кольцо"}

var loadout: Loadout
var preview_slot := ""
var preview_text := ""
var preview_delta := 0.0
var slot_pos := {}          # slot -> cell centre, filled on draw
var _punch := {}            # slot -> 0..1 remaining
var _power_punch := 0.0


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
	var busy := _power_punch > 0.0
	_power_punch = maxf(0.0, _power_punch - delta * 3.0)
	for k in _punch.keys():
		_punch[k] = maxf(0.0, _punch[k] - delta * 3.0)
		busy = busy or _punch[k] > 0.0
	if busy:
		queue_redraw()


func _draw() -> void:
	if loadout == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var x := PANEL.position.x
	var y := PANEL.position.y + 4
	draw_string(bold, Vector2(x, y + 18), "снаряжение", HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 22, E.INK)
	y += 32
	for s in Loadout.SLOTS:
		var it: Dictionary = loadout.equipped[s]
		var r := int(it.get("rarity", 0))
		var cell := Rect2(x + 4, y, 36, 36)
		slot_pos[s] = cell.get_center()
		var k := 1.0 + 0.6 * _ease(_punch.get(s, 0.0))
		draw_set_transform(cell.get_center() * (1.0 - k), 0.0, Vector2.ONE * k)
		draw_rect(cell, E.PAPER_LIGHT)
		ItemArt.rarity_frame(self, cell, r)
		if not it.is_empty():
			ItemArt.draw_item(self, s, cell.get_center(), 11, rng)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var nm: String = (it["name"] if not it.is_empty() else SLOT_NAMES[s]) + ("  +%d" % loadout.rank[s] if loadout.rank[s] > 0 else "")
		draw_string(bold if r >= 2 else reg, Vector2(x + 48, y + 17), nm, HORIZONTAL_ALIGNMENT_LEFT, 160, 17, Pal.RARITY_TEXT[r] if not it.is_empty() else E.INK_FADED)
		if s == preview_slot and preview_text != "":
			draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y + 8), Vector2(x - 2, y + 18), Vector2(x - 14, y + 28)]), E.INK)
			draw_string(bold, Vector2(x + 48, y + 34), preview_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 15, E.INK_FADED)
		elif not it.is_empty():
			draw_string(reg, Vector2(x + 48, y + 34), SLOT_NAMES[s], HORIZONTAL_ALIGNMENT_LEFT, 70, 13, E.INK_FADED)
			for i in r + 1:
				draw_circle(Vector2(x + 128 + i * 9, y + 30), 3.0, Pal.RARITY[r])
		y += 40
	_resonance(x, y + 4, rng)
	# build power
	var pk := 1.0 + 0.35 * _ease(_power_punch)
	var py := PANEL.end.y - 8
	E.stroke(self, Vector2(x, py - 30), Vector2(PANEL.end.x, py - 30), 1.2, rng)
	draw_string(reg, Vector2(x + 4, py), "сила", HORIZONTAL_ALIGNMENT_LEFT, 60, 22, E.INK)
	draw_set_transform(Vector2(x + 110, py - 8) * (1.0 - pk), 0.0, Vector2.ONE * pk)
	draw_string(bold, Vector2(x + 50, py), str(roundi(loadout.power())), HORIZONTAL_ALIGNMENT_RIGHT, 80, 26, E.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if preview_text != "" and absf(preview_delta) >= 0.5:
		draw_string(bold, Vector2(x + 134, py), ("+%d" if preview_delta > 0 else "−%d") % absi(roundi(preview_delta)), HORIZONTAL_ALIGNMENT_LEFT, 70, 22, Color("#2E7D32") if preview_delta > 0 else E.CINNABAR)


## M04: tag counters under the slots — "кровь 4/5 +3%".
func _resonance(x: float, y: float, rng: RandomNumberGenerator) -> void:
	if loadout.resonance.is_empty():
		return
	var counts := loadout.tag_counts()
	var tags := counts.keys()
	tags.sort_custom(func(a, b): return counts[a] > counts[b])
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	E.stroke(self, Vector2(x, y), Vector2(PANEL.end.x, y), 1.0, rng, E.INK_FADED)
	draw_string(reg, Vector2(x + 4, y + 16), "резонанс тегов 3/5/7", HORIZONTAL_ALIGNMENT_LEFT, 200, 14, E.INK_FADED)
	y += 34
	for tg in tags.slice(0, 3):
		var n := int(counts[tg])
		var lv := loadout.resonance_level(n)
		var th: Array = loadout.resonance["thresholds"]
		var nxt := int(th[mini(lv, th.size() - 1)])
		var r: Dictionary = loadout.resonance["tags"].get(tg, {})
		var col: Color = Pal.stat(r.get("stat", "")) if lv > 0 else E.INK_FADED
		draw_string(bold if lv > 0 else reg, Vector2(x + 4, y), "%s %d/%d" % [tg, n, nxt], HORIZONTAL_ALIGNMENT_LEFT, 110, 17, E.INK if lv > 0 else E.INK_FADED)
		if lv > 0:
			draw_string(bold, Vector2(x + 100, y), "+%d %s" % [roundi(float(r["v"][lv - 1])), _short(r["stat"])], HORIZONTAL_ALIGNMENT_LEFT, 106, 15, col)
		y += 20


func _short(stat: String) -> String:
	return {"вампиризм": "вамп.", "пробивание": "проб.", "сила крита": "с.крит", "алчность": "алч."}.get(stat, stat)


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
