extends Node2D
## Look-dev: "this is how the game will look". Two states of one frame:
## fight (enemy in the corridor) and drop (loot card in its place).
## Tab toggles; auto-switches to drop after AUTO_SWITCH seconds; --state=drop starts there.

const E := preload("res://scripts/engrave.gd")
const V := Vector2(640, 280)                        # vanishing point
const DOOR := Rect2(565, 175, 150, 210)             # dark opening at the end of the corridor
const SCREEN := Rect2(0, 0, 1280, 720)
const AUTO_SWITCH := 2.5
const RARITY := ["обычные", "магические", "редкие", "легендарные"]
# equipped build: [slot, name, rarity 0..3]
const BUILD := [
	["weapon", "Клинок вдовы", 2], ["helm", "Шлем пилигрима", 1], ["armor", "Саван могильщика", 3],
	["gloves", "Перчатки палача", 2], ["boots", "Сапоги странника", 0], ["belt", "Пояс сборщика", 0],
	["shield", "Щит обета", 1], ["amulet", "Амулет вдовы", 3], ["ring", "Кольцо пепла", 2],
	["ring", "Медное кольцо", 0]]
const PANEL := Rect2(1046, 116, 206, 548)

var state := "fight"
var _t := 0.0
var _auto := true
var _font: FontVariation
var _font_bold: FontVariation
var _clear: Array = []   # paper left clean under the lettering, like an engraver's cartouche


func _ready() -> void:
	var base: FontFile = load("res://art/fonts/CormorantGaramond.ttf")
	_font = FontVariation.new()
	_font.base_font = base
	_font.variation_opentype = {"wght": 500}
	_font_bold = FontVariation.new()
	_font_bold.base_font = base
	_font_bold.variation_opentype = {"wght": 700}
	for a in OS.get_cmdline_user_args():
		if a == "--state=drop":
			state = "drop"
			_auto = false


func _process(delta: float) -> void:
	_t += delta
	if _auto and state == "fight" and _t >= AUTO_SWITCH:
		state = "drop"
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_auto = false
		state = "drop" if state == "fight" else "fight"
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1489
	_clear = [_soft(Rect2(36, 40, 300, 66)), _soft(Rect2(930, 40, 314, 66)), _soft(PANEL.grow(8))]
	if state == "fight":
		_clear.append(_soft(Rect2(420, 24, 440, 76)))
		_clear.append(_soft(Rect2(760, 160, 140, 92)))
	else:
		_clear.append(_soft(Rect2(290, 640, 270, 40)))
		_clear.append(_soft(Rect2(860, 640, 130, 40)))
	_draw_corridor(rng)
	if state == "fight":
		_draw_enemy(rng)
	else:
		_draw_card(rng)
	_draw_hand(rng)
	_draw_vignette(rng)
	_draw_hud(rng)


# ------------------------------------------------------------- corridor

func _draw_corridor(rng: RandomNumberGenerator) -> void:
	draw_rect(SCREEN, E.PAPER)
	for i in 9:  # ink stains on the parchment
		var c := Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		draw_colored_polygon(E.ellipse(c, Vector2(rng.randf_range(30, 120), rng.randf_range(20, 70)), 24),
			Color(E.INK, 0.05))
	var tl := DOOR.position
	var tr := Vector2(DOOR.end.x, DOOR.position.y)
	var br := DOOR.end
	var bl := Vector2(DOOR.position.x, DOOR.end.y)
	var ceiling := PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), tr, tl])
	var floor_p := PackedVector2Array([bl, br, Vector2(1280, 720), Vector2(0, 720)])
	var left := PackedVector2Array([Vector2(0, 0), tl, bl, Vector2(0, 720)])
	var right := PackedVector2Array([tr, Vector2(1280, 0), Vector2(1280, 720), br])
	# walls: perspective strokes + horizontal courses, ceiling darker, floor lightest
	E.radial(self, left, V, 260, 1.1, rng, E.INK, _clear)
	E.radial(self, right, V, 260, 1.1, rng, E.INK, _clear)
	E.radial(self, ceiling, V, 320, 1.3, rng, E.INK, _clear)
	E.hatch(self, ceiling, 0.0, 9.0, 1.0, rng, E.INK, false, Rect2(), _clear)
	E.radial(self, floor_p, V, 140, 0.9, rng, E.INK_FADED)
	for t in [0.12, 0.26, 0.4, 0.52, 0.63, 0.73, 0.82, 0.9, 0.96]:
		var r := Rect2(SCREEN.position.lerp(DOOR.position, t), SCREEN.size.lerp(DOOR.size, t))
		for seg in E._cut([PackedVector2Array([r.position, Vector2(r.position.x, r.end.y)]),
				PackedVector2Array([Vector2(r.end.x, r.position.y), r.end])], _clear):
			E.stroke(self, seg[0], seg[1], 2.2 - t, rng)  # wall joints
		E.stroke(self, Vector2(r.position.x, r.end.y), r.end, 1.8 - t, rng, E.INK_FADED)  # floor slab
	# stone courses on the walls: lines from the near edge toward V
	for y in [90.0, 190.0, 300.0, 420.0, 540.0, 640.0]:
		for side in [0.0, 1280.0]:
			var p := Vector2(side, y)
			var q := p.lerp(V, 0.82)
			var poly := left if side == 0.0 else right
			for seg in E._cut(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([p, q]), poly), _clear):
				E.stroke(self, seg[0], seg[seg.size() - 1], 2.0, rng)
	# the far opening: almost black, three layers of cross-hatching
	var door := PackedVector2Array([tl, tr, br, bl])
	draw_colored_polygon(door, Color(E.INK, 0.55))
	for ang in [0.35, -0.35, 1.57]:
		E.hatch(self, door, ang, 3.2, 1.2, rng)
	E.outline(self, door, 3.0)


# ------------------------------------------------------------- enemy

func _draw_enemy(rng: RandomNumberGenerator) -> void:
	var robe := PackedVector2Array([Vector2(500, 320), Vector2(780, 320), Vector2(890, 720), Vector2(390, 720)])
	var hood := PackedVector2Array([Vector2(640, 105), Vector2(705, 140), Vector2(745, 230), Vector2(760, 340),
		Vector2(520, 340), Vector2(535, 230), Vector2(575, 140)])
	var shoulders := PackedVector2Array([Vector2(470, 345), Vector2(560, 300), Vector2(720, 300),
		Vector2(810, 345), Vector2(830, 430), Vector2(450, 430)])
	for poly in [robe, shoulders, hood]:
		draw_colored_polygon(poly, E.PAPER)
		E.hatch(self, poly, PI / 2 + 0.06, 8.0, 1.0, rng)  # folds: near-vertical strokes
		# shadow side (right) — cross-hatching
		var shade := Geometry2D.intersect_polygons(poly, PackedVector2Array([Vector2(680, 0),
			Vector2(1280, 0), Vector2(1280, 720), Vector2(700, 720)]))
		for s in shade:
			E.hatch(self, s, 0.7, 5.0, 1.0, rng)
		E.outline(self, poly, 3.0)
	# deep fold lines
	for x in [560.0, 610.0, 680.0, 730.0]:
		E.stroke(self, Vector2(x, 440), Vector2(x + (x - 640) * 0.45, 715), 2.4, rng)
	# face: void under the hood, two cinnabar eyes
	var face := E.ellipse(Vector2(640, 235), Vector2(52, 66), 32)
	draw_colored_polygon(face, Color(E.INK, 0.75))
	for ang in [0.4, -0.4]:
		E.hatch(self, face, ang, 2.6, 1.1, rng)
	for ex in [618.0, 662.0]:
		draw_circle(Vector2(ex, 232), 6.5, E.CINNABAR)
		draw_circle(Vector2(ex, 232), 2.0, E.INK)
	# great blade held point-down in front
	var blade := PackedVector2Array([Vector2(626, 410), Vector2(654, 410), Vector2(648, 690), Vector2(640, 715), Vector2(632, 690)])
	var guard := PackedVector2Array([Vector2(568, 392), Vector2(712, 392), Vector2(712, 410), Vector2(568, 410)])
	var hands := E.ellipse(Vector2(640, 375), Vector2(46, 26), 24)
	for poly in [blade, guard, hands]:
		draw_colored_polygon(poly, E.PAPER_LIGHT)
		E.hatch(self, poly, 0.9, 4.0, 0.9, rng)
		E.outline(self, poly, 2.5)
	E.stroke(self, Vector2(640, 412), Vector2(640, 705), 1.5, rng)  # fuller
	# blood on the floor
	draw_colored_polygon(E.ellipse(Vector2(700, 700), Vector2(60, 9), 20), Color(E.CINNABAR, 0.85))


# ------------------------------------------------------------- drop card

func _draw_card(rng: RandomNumberGenerator) -> void:
	var r := Rect2(470, 135, 340, 480)
	var shadow := r
	shadow.position += Vector2(10, 12)
	E.hatch(self, _rect_poly(shadow), 0.8, 3.0, 1.0, rng)
	draw_rect(r, E.PAPER_LIGHT)
	draw_rect(r.grow(-8), E.INK, false, 3.0)
	draw_rect(r.grow(-14), E.INK, false, 1.2)
	# item engraving: the blade
	var blade := PackedVector2Array([Vector2(520, 315), Vector2(535, 330), Vector2(760, 180), Vector2(748, 168)])
	var guard := PackedVector2Array([Vector2(520, 280), Vector2(532, 270), Vector2(580, 335), Vector2(568, 345)])
	var grip := PackedVector2Array([Vector2(500, 345), Vector2(510, 355), Vector2(545, 322), Vector2(535, 312)])
	for poly in [blade, guard, grip]:
		E.hatch(self, poly, -0.6, 3.5, 0.9, rng)
		E.outline(self, poly, 2.2)
	draw_circle(Vector2(498, 357), 9, E.CINNABAR)
	E.outline(self, E.ellipse(Vector2(498, 357), Vector2(9, 9), 16), 2.0)
	_text(_font_bold, "Клинок вдовы", Vector2(470, 398), 340, 36, E.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(_font, "редкое · кровь · ночь", Vector2(470, 424), 340, 20, E.INK_FADED, HORIZONTAL_ALIGNMENT_CENTER)
	E.stroke(self, Vector2(500, 440), Vector2(780, 440), 1.4, rng)
	var rows := [["урон", "24  →  31", "+7", true], ["скорость", "1,1  →  0,9", "−0,2", false],
		["крит", "5%  →  9%", "+4", true], ["вампиризм", "—  →  3%", "новое", true]]
	var y := 474.0
	for row in rows:
		_text(_font, row[0], Vector2(500, y), 140, 22, E.INK, HORIZONTAL_ALIGNMENT_LEFT)
		_text(_font_bold, row[1], Vector2(600, y), 110, 22, E.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		_text(_font_bold, row[2], Vector2(714, y), 66, 22, E.INK if row[3] else E.CINNABAR, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 32.0
	_text(_font_bold, "← продать · 18", Vector2(300, 668), 260, 26, E.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_text(_font_bold, "надеть →", Vector2(860, 668), 124, 26, E.INK, HORIZONTAL_ALIGNMENT_RIGHT)


# ------------------------------------------------------------- hero hand

func _draw_hand(rng: RandomNumberGenerator) -> void:
	var blade := PackedVector2Array([Vector2(185, 575), Vector2(212, 598), Vector2(410, 372), Vector2(396, 352)])
	var guard := PackedVector2Array([Vector2(135, 545), Vector2(152, 530), Vector2(262, 625), Vector2(245, 640)])
	var arm := PackedVector2Array([Vector2(0, 720), Vector2(0, 600), Vector2(95, 560), Vector2(190, 585),
		Vector2(235, 650), Vector2(215, 720)])
	for poly in [blade, guard, arm]:
		draw_colored_polygon(poly, E.PAPER)
		E.hatch(self, poly, -0.85, 5.5, 1.0, rng)
		E.outline(self, poly, 3.0)
	E.hatch(self, arm, 0.6, 7.0, 0.9, rng)  # gauntlet in shadow: light cross-hatch
	for i in 4:  # plates of the gauntlet
		E.stroke(self, Vector2(30 + i * 45, 720), Vector2(60 + i * 42, 575 + i * 6), 2.2, rng)


# ------------------------------------------------------------- frame and HUD

func _draw_vignette(rng: RandomNumberGenerator) -> void:
	var layers := [[Vector2(600, 370), 0.55, 7.0], [Vector2(660, 410), -0.55, 6.0], [Vector2(700, 440), 0.0, 5.0]]
	for l in layers:
		E.hatch(self, E.ellipse(Vector2(640, 360), l[0], 64), l[1], l[2], 1.1, rng, E.INK, true, SCREEN, _clear)
	draw_rect(SCREEN.grow(-6), E.INK, false, 12.0)
	draw_rect(SCREEN.grow(-20), E.INK, false, 1.5)


func _draw_hud(rng: RandomNumberGenerator) -> void:
	_text(_font_bold, "монеты 132", Vector2(48, 68), 300, 28, E.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_text(_font, "глубина 14 · рекорд 31", Vector2(48, 96), 360, 21, E.INK, HORIZONTAL_ALIGNMENT_LEFT)
	if state == "fight":
		_text(_font_bold, "Могильный страж", Vector2(390, 60), 500, 38, E.INK, HORIZONTAL_ALIGNMENT_CENTER)
		_bar(Rect2(490, 74, 300, 16), 0.62, rng)
		_text(_font_bold, "−37", Vector2(770, 210), 200, 72, E.CINNABAR, HORIZONTAL_ALIGNMENT_LEFT)
		_text(_font_bold, "крит", Vector2(778, 238), 200, 26, E.CINNABAR, HORIZONTAL_ALIGNMENT_LEFT)
	_text(_font_bold, "жизнь 84 / 120", Vector2(932, 66), 300, 26, E.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_bar(Rect2(942, 78, 288, 14), 0.7, rng)
	_draw_build(rng)


## Equipped items, grouped by rarity (legendary first). Rarity = frame + pips, not colour;
## cinnabar only for legendary (ART_BIBLE).
func _draw_build(rng: RandomNumberGenerator) -> void:
	var y := PANEL.position.y + 4
	var x := PANEL.position.x
	_text(_font_bold, "снаряжение", Vector2(x, y + 18), PANEL.size.x, 22, E.INK, HORIZONTAL_ALIGNMENT_CENTER)
	y += 30
	for r in range(3, -1, -1):
		var items := BUILD.filter(func(it): return it[2] == r)
		if items.is_empty():
			continue
		var col := E.CINNABAR if r == 3 else E.INK_FADED
		_text(_font, RARITY[r], Vector2(x + 4, y + 14), 120, 16, col, HORIZONTAL_ALIGNMENT_LEFT)
		E.stroke(self, Vector2(x + 96, y + 9), Vector2(PANEL.end.x - 2, y + 9), 1.0, rng, col)
		y += 20
		for it in items:
			var cell := Rect2(x + 4, y, 36, 36)
			var hot: bool = state == "drop" and it[0] == "weapon"
			if hot:  # the slot the drop card is compared against
				draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y + 8), Vector2(x - 2, y + 18), Vector2(x - 14, y + 28)]), E.INK)
				E.stroke(self, Vector2(x + 48, y + 23), Vector2(PANEL.end.x - 6, y + 23), 1.6, rng)
			_rarity_frame(cell, r)
			_icon(it[0], cell.grow(-7), rng)
			_text(_font_bold if r >= 2 else _font, it[1], Vector2(x + 48, y + 18), 160, 17, E.INK, HORIZONTAL_ALIGNMENT_LEFT)
			for k in r + 1:  # rarity pips
				draw_circle(Vector2(x + 52 + k * 9, y + 29), 2.6, E.CINNABAR if r == 3 else E.INK)
			y += 42


func _rarity_frame(c: Rect2, r: int) -> void:
	draw_rect(c, E.PAPER_LIGHT)
	match r:
		0:
			draw_rect(c, E.INK_FADED, false, 1.0)
		1:
			draw_rect(c, E.INK, false, 1.2)
			draw_rect(c.grow(-3), E.INK, false, 1.0)
		2:
			draw_rect(c, E.INK, false, 2.6)
			draw_rect(c.grow(-4), E.INK, false, 1.0)
			for k in [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]:
				draw_rect(Rect2(k - Vector2(3, 3), Vector2(6, 6)), E.INK)
		3:
			draw_rect(c, E.CINNABAR, false, 3.0)
			draw_rect(c.grow(-4), E.INK, false, 1.2)
			for k in [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]:
				draw_rect(Rect2(k - Vector2(3.5, 3.5), Vector2(7, 7)), E.CINNABAR)


## Tiny engraved slot silhouettes (placeholders until drawings arrive).
func _icon(slot: String, b: Rect2, rng: RandomNumberGenerator) -> void:
	var c := b.get_center()
	var s := b.size.x / 2.0
	var poly := PackedVector2Array()
	match slot:
		"weapon":
			poly = PackedVector2Array([c + Vector2(-s, s * 0.8), c + Vector2(-s * 0.7, s), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.8, -s)])
		"helm":
			poly = E.ellipse(c + Vector2(0, s * 0.3), Vector2(s, s * 1.1), 16).slice(8, 16)
			poly.append(c + Vector2(s, s * 0.3))
		"armor":
			poly = PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s)])
		"gloves":
			poly = PackedVector2Array([c + Vector2(-s * 0.6, s), c + Vector2(-s * 0.6, -s), c + Vector2(s * 0.5, -s), c + Vector2(s * 0.5, 0), c + Vector2(s, -s * 0.3), c + Vector2(s, s * 0.3), c + Vector2(s * 0.5, s)])
		"boots":
			poly = PackedVector2Array([c + Vector2(-s * 0.5, -s), c + Vector2(s * 0.2, -s), c + Vector2(s * 0.2, s * 0.3), c + Vector2(s, s * 0.5), c + Vector2(s, s), c + Vector2(-s * 0.5, s)])
		"belt":
			poly = PackedVector2Array([c + Vector2(-s, -s * 0.35), c + Vector2(s, -s * 0.35), c + Vector2(s, s * 0.35), c + Vector2(-s, s * 0.35)])
		"shield":
			poly = PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
		"amulet", "ring":
			poly = E.ellipse(c + Vector2(0, s * 0.2), Vector2(s * 0.7, s * 0.7), 16)
	if slot == "ring":
		E.outline(self, poly, 3.0)
		return
	E.hatch(self, poly, -0.8, 2.6, 0.8, rng)
	E.outline(self, poly, 1.6)
	if slot == "amulet":
		E.stroke(self, c + Vector2(-s, -s), c + Vector2(0, -s * 0.5), 1.0, rng)
		E.stroke(self, c + Vector2(s, -s), c + Vector2(0, -s * 0.5), 1.0, rng)


func _bar(r: Rect2, fill: float, rng: RandomNumberGenerator) -> void:
	var f := Rect2(r.position, Vector2(r.size.x * fill, r.size.y))
	draw_rect(f, E.CINNABAR)
	E.hatch(self, _rect_poly(f), -0.8, 5.0, 1.0, rng)
	draw_rect(r, E.INK, false, 2.0)
	draw_rect(r.grow(4), E.INK, false, 1.0)


func _text(font: Font, s: String, pos: Vector2, width: float, size: int, color: Color,
		align: HorizontalAlignment) -> void:
	draw_string(font, pos, s, align, width, size, color)


## A cleared patch with ragged edges (scraped-out paper), not a flat plate.
func _soft(r: Rect2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.position.x * 7 + r.position.y)
	var pts := PackedVector2Array()
	var c := r.get_center()
	for i in 28:
		var a := TAU * i / 28.0
		var d := Vector2(cos(a), sin(a))
		var k := 1.0 / maxf(absf(d.x) / (r.size.x * 0.5), absf(d.y) / (r.size.y * 0.5))
		pts.append(c + d * k * rng.randf_range(0.97, 1.12))
	return pts


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
