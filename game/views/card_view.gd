extends Node2D
## The drop card, drawn around (0,0): engraving, name, "было → станет", build power line, stamp.

const E := preload("res://scripts/engrave.gd")
const SIZE := Vector2(340, 500)
const STAMPS := {1: "ПРОДАТЬ", 2: "НАДЕТЬ", 3: "ПЕРЕПЛАВИТЬ"}   # Swipe.SELL / EQUIP / MELT

var item: Dictionary = {}
var rows: Array = []
var rarity_name := ""
var power_before := 0.0
var power_after := 0.0
var melt_line := ""
var stamp_dir := 0
var stamp_p := 0.0


func show_item(it: Dictionary, rows_: Array, rname: String, pb: float, pa: float, melt: String) -> void:
	item = it
	rows = rows_
	rarity_name = rname
	power_before = pb
	power_after = pa
	melt_line = melt
	stamp_dir = 0
	stamp_p = 0.0
	queue_redraw()


func set_stamp(dir: int, p: float) -> void:
	if dir != stamp_dir or absf(p - stamp_p) > 0.02:
		stamp_dir = dir
		stamp_p = p
		queue_redraw()


func _draw() -> void:
	if item.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item["id"])
	var r := Rect2(-SIZE / 2.0, SIZE)
	var sh := r
	sh.position += Vector2(10, 12)
	E.hatch(self, E.rect_poly(sh), 0.8, 3.0, 1.0, rng)
	var rr := int(item["rarity"])
	draw_rect(r, E.PAPER_LIGHT)
	if rr > 0:   # rarity wash over the engraving area
		draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(SIZE.x - 16, 140)), Color(Pal.RARITY[rr], 0.18))
	ItemArt.rarity_frame(self, r.grow(-8), rr, 1.4)
	draw_rect(r.grow(-15), E.INK, false, 1.0)
	ItemArt.draw_item(self, item["slot"], Vector2(0, -176), 48, rng, true)
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var x0 := r.position.x
	draw_string(bold, Vector2(x0, -84), item["name"], HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 31, Pal.RARITY_TEXT[rr])
	var tags: Array = item.get("tags", [])
	var sub := rarity_name + (" · " + String(item["type"]).to_lower() if item.has("type") and rr > 0 else "")
	draw_string(bold, Vector2(x0, -60), sub, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 18, Pal.RARITY_TEXT[rr])
	if not tags.is_empty():
		draw_string(reg, Vector2(x0, -39), "теги: " + ", ".join(tags), HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 17, E.INK_FADED)
	E.stroke(self, Vector2(x0 + 28, -28), Vector2(-x0 - 28, -28), 1.4, rng)
	var y := -6.0
	for row in rows.slice(0, 9):
		var b = row[1]
		var a = row[2]
		Pal.stat_icon(self, row[0], Vector2(x0 + 34, y - 6), 7.5)
		draw_string(bold, Vector2(x0 + 48, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, 112, 18, Pal.stat(row[0]))
		draw_string(bold, Vector2(x0 + 150, y), "%s → %s" % [_fmt(row[0], b), _fmt(row[0], a)], HORIZONTAL_ALIGNMENT_RIGHT, 110, 18, E.INK)
		var d := (0.0 if a == null else float(a)) - (0.0 if b == null else float(b))
		if absf(d) > 0.001:
			draw_string(bold, Vector2(x0 + 262, y), ("+" if d > 0 else "−") + _fmt(row[0], absf(d)), HORIZONTAL_ALIGNMENT_RIGHT, 52, 18, Color("#2E7D32") if d > 0 else E.CINNABAR)
		y += 22.0
	# build power: the one number that sums it up
	if melt_line != "":   # resonance change from equipping
		draw_string(bold, Vector2(x0 + 20, r.end.y - 66), "резонанс: " + melt_line, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 40, 16, Color("#7B1FA2"))
	var dp := power_after - power_before
	E.stroke(self, Vector2(x0 + 28, r.end.y - 52), Vector2(-x0 - 28, r.end.y - 52), 1.0, rng)
	draw_string(reg, Vector2(x0 + 30, r.end.y - 26), "сила", HORIZONTAL_ALIGNMENT_LEFT, 80, 21, E.INK)
	draw_string(bold, Vector2(x0 + 80, r.end.y - 26), "%d → %d" % [roundi(power_before), roundi(power_after)], HORIZONTAL_ALIGNMENT_RIGHT, 160, 23, E.INK)
	draw_string(bold, Vector2(x0 + 244, r.end.y - 26), ("+%d" if dp >= 0 else "−%d") % absi(roundi(dp)), HORIZONTAL_ALIGNMENT_RIGHT, 50, 23, Color("#2E7D32") if dp >= 0 else E.CINNABAR)
	if stamp_dir != 0 and stamp_p > 0.05:
		_stamp(STAMPS.get(stamp_dir, ""), stamp_p)


func _stamp(text: String, p: float) -> void:
	var a := clampf(p, 0.0, 1.0)
	var ang := -0.25 if stamp_dir == 2 else (0.25 if stamp_dir == 1 else 0.0)
	var pos := Vector2(0, -170)
	draw_set_transform(pos, ang, Vector2.ONE * (0.8 + 0.25 * a))
	var col := Color(E.CINNABAR if stamp_dir == 3 else E.INK, a)
	var w := 250.0
	draw_rect(Rect2(-w / 2, -32, w, 64), Color(E.PAPER_LIGHT, 0.85 * a))
	draw_rect(Rect2(-w / 2, -32, w, 64), col, false, 4.0)
	draw_rect(Rect2(-w / 2 + 6, -26, w - 12, 52), col, false, 1.5)
	draw_string(Fonts.bold(), Vector2(-w / 2, 13), text, HORIZONTAL_ALIGNMENT_CENTER, w, 34 if text.length() < 9 else 26, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _fmt(stat: String, v) -> String:
	if v == null:
		return "—"
	var f := float(v)
	if stat == "скорость":
		return ("%.2f" % f).replace(".", ",")
	if stat == "регенерация":
		return ("%.1f/с" % f).replace(".", ",")
	if stat in Pal.PCT:
		return "%d%%" % roundi(f)
	return str(roundi(f))
