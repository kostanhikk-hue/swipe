extends Node2D
## Frontal engraved enemy (placeholder shapes: hood / beast / helm / skull / butcher / wraith / golem /
## tithe). Node origin = PIVOT. Boss — crown; elite — cinnabar halo of spikes behind.

const E := preload("res://scripts/engrave.gd")
const PIVOT := Vector2(640, 430)
const DOOR := Vector2(640, 290)

var appear := 1.0   # 0 = tiny in the doorway, 1 = in front of the hero
var shape := "hood"
var boss := false
var elite := false
const CROWN_TOP := {"beast": 150.0, "hood": 95.0, "helm": 160.0, "skull": 120.0, "butcher": 150.0, "wraith": 80.0, "golem": 130.0, "tithe": 110.0}
var _flash := 0.0
var _lunge := 0.0
var _recoil := 0.0


func set_shape(s: String) -> void:
	shape = s
	queue_redraw()


func hurt(strength := 1.0) -> void:
	_flash = 1.0
	_recoil = strength


func lunge() -> void:
	_lunge = 1.0


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 8.0)
	_lunge = maxf(0.0, _lunge - delta * 4.0)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	var l := sin(_lunge * PI)
	scale = Vector2.ONE * (1.0 + 0.08 * l - 0.03 * _recoil) * lerpf(0.25, 1.0, appear)
	position = DOOR.lerp(PIVOT, appear) + Vector2(0, 30 * l - 14 * _recoil)
	modulate = Color(1, 1, 1).lerp(Color(1.5, 1.35, 1.2), _flash)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shape)
	draw_set_transform(-PIVOT, 0.0, Vector2.ONE)
	if elite:
		_halo(rng)
	match shape:
		"beast":
			_beast(rng)
		"helm":
			_helm(rng)
		"skull":
			_skull(rng)
		"butcher":
			_butcher(rng)
		"wraith":
			_wraith(rng)
		"golem":
			_golem(rng)
		"tithe":
			_tithe(rng)
		_:
			_hood(rng)
	if boss:
		var top: float = CROWN_TOP.get(shape, 120.0)
		var crown := PackedVector2Array([Vector2(570, top + 40), Vector2(580, top - 20), Vector2(605, top + 15), Vector2(640, top - 40),
			Vector2(675, top + 15), Vector2(700, top - 20), Vector2(710, top + 40)])
		draw_colored_polygon(crown, Pal.RARITY[3])
		E.hatch(self, crown, 0.6, 4.0, 1.0, rng)
		E.outline(self, crown, 3.0)
		for x in [605.0, 640.0, 675.0]:
			draw_circle(Vector2(x, top + 25), 6.0, E.CINNABAR)


func _body(polys: Array, rng: RandomNumberGenerator, fold := PI / 2 + 0.06) -> void:
	for poly in polys:
		draw_colored_polygon(poly, E.PAPER)
		E.hatch(self, poly, fold, 8.0, 1.0, rng)
		for s in Geometry2D.intersect_polygons(poly, PackedVector2Array([Vector2(680, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(700, 720)])):
			E.hatch(self, s, 0.7, 5.0, 1.0, rng)
		E.outline(self, poly, 3.0)


func _eyes(pts: Array, r := 6.5) -> void:
	for p in pts:
		draw_circle(p, r, E.CINNABAR)
		draw_circle(p, r * 0.3, E.INK)


func _void(c: Vector2, r: Vector2, rng: RandomNumberGenerator) -> void:
	var face := E.ellipse(c, r, 32)
	draw_colored_polygon(face, Color(E.INK, 0.75))
	for ang in [0.4, -0.4]:
		E.hatch(self, face, ang, 2.6, 1.1, rng)


func _hood(rng: RandomNumberGenerator) -> void:
	_body([PackedVector2Array([Vector2(500, 320), Vector2(780, 320), Vector2(890, 720), Vector2(390, 720)]),
		PackedVector2Array([Vector2(470, 345), Vector2(560, 300), Vector2(720, 300), Vector2(810, 345), Vector2(830, 430), Vector2(450, 430)]),
		PackedVector2Array([Vector2(640, 105), Vector2(705, 140), Vector2(745, 230), Vector2(760, 340), Vector2(520, 340), Vector2(535, 230), Vector2(575, 140)])], rng)
	for x in [560.0, 610.0, 680.0, 730.0]:
		E.stroke(self, Vector2(x, 440), Vector2(x + (x - 640) * 0.45, 715), 2.4, rng)
	_void(Vector2(640, 235), Vector2(52, 66), rng)
	_eyes([Vector2(618, 232), Vector2(662, 232)])


func _beast(rng: RandomNumberGenerator) -> void:
	var body := E.ellipse(Vector2(640, 560), Vector2(280, 210), 40)
	var head := E.ellipse(Vector2(640, 330), Vector2(120, 100), 32)
	var horn_l := PackedVector2Array([Vector2(560, 270), Vector2(470, 150), Vector2(500, 260)])
	var horn_r := PackedVector2Array([Vector2(720, 270), Vector2(810, 150), Vector2(780, 260)])
	_body([body, horn_l, horn_r, head], rng, 0.4)
	var jaw := PackedVector2Array([Vector2(570, 360), Vector2(710, 360), Vector2(680, 420), Vector2(600, 420)])
	draw_colored_polygon(jaw, Color(E.INK, 0.8))
	for i in 7:
		var x := 580.0 + i * 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 360), Vector2(x + 12, 360), Vector2(x + 6, 385)]), E.PAPER_LIGHT)
	_eyes([Vector2(600, 310), Vector2(680, 310), Vector2(620, 290), Vector2(660, 290)], 5.5)


func _helm(rng: RandomNumberGenerator) -> void:
	var torso := PackedVector2Array([Vector2(470, 380), Vector2(810, 380), Vector2(850, 720), Vector2(430, 720)])
	var paul_l := E.ellipse(Vector2(480, 395), Vector2(80, 50), 24)
	var paul_r := E.ellipse(Vector2(800, 395), Vector2(80, 50), 24)
	var helm := PackedVector2Array([Vector2(570, 170), Vector2(710, 170), Vector2(725, 360), Vector2(555, 360)])
	_body([torso, paul_l, paul_r, helm], rng, 0.0)
	draw_rect(Rect2(580, 245, 120, 16), E.INK)
	for i in 5:
		draw_circle(Vector2(600 + i * 20, 300), 3.5, E.INK)
	E.stroke(self, Vector2(640, 170), Vector2(640, 360), 2.2, rng)
	_eyes([Vector2(615, 253), Vector2(665, 253)], 4.5)
	var blade := PackedVector2Array([Vector2(890, 200), Vector2(910, 200), Vector2(915, 650), Vector2(885, 650)])
	draw_colored_polygon(blade, E.PAPER_LIGHT)
	E.hatch(self, blade, 0.9, 4.0, 0.9, rng)
	E.outline(self, blade, 2.5)


func _halo(rng: RandomNumberGenerator) -> void:
	var c := Vector2(640, 300)
	var pts := PackedVector2Array()
	for i in 36:
		var r := 250.0 if i % 2 == 0 else 200.0
		pts.append(c + Vector2.from_angle(TAU * i / 36.0) * r)
	draw_colored_polygon(pts, Color(E.CINNABAR, 0.16))
	E.hatch(self, pts, 0.9, 9.0, 1.0, rng, Color(E.CINNABAR, 0.55))
	E.outline(self, pts, 2.0, Color(E.CINNABAR, 0.8))


func _skull(rng: RandomNumberGenerator) -> void:
	# bone archer: ribs, a big skull, a drawn bow across the body
	var ribs := PackedVector2Array([Vector2(540, 360), Vector2(740, 360), Vector2(720, 560), Vector2(560, 560)])
	var pelvis := PackedVector2Array([Vector2(560, 560), Vector2(720, 560), Vector2(760, 720), Vector2(520, 720)])
	var skull := E.ellipse(Vector2(640, 245), Vector2(95, 110), 32)
	var jaw := PackedVector2Array([Vector2(585, 300), Vector2(695, 300), Vector2(680, 355), Vector2(600, 355)])
	_body([pelvis, ribs, skull, jaw], rng, 0.2)
	for i in 5:
		var y := 385.0 + i * 34.0
		E.stroke(self, Vector2(552 + i * 3, y), Vector2(728 - i * 3, y), 3.0, rng)
	for p in [Vector2(605, 235), Vector2(675, 235)]:
		draw_colored_polygon(E.ellipse(p, Vector2(26, 30), 18), E.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(640, 262), Vector2(628, 292), Vector2(652, 292)]), E.INK)
	for i in 6:
		E.stroke(self, Vector2(598 + i * 16, 318), Vector2(598 + i * 16, 345), 2.0, rng)
	_eyes([Vector2(605, 238), Vector2(675, 238)], 7.0)
	var bow := PackedVector2Array()
	for i in 17:
		var a := lerpf(-1.2, 1.2, i / 16.0)
		bow.append(Vector2(860, 420) + Vector2(-cos(a) * 120, sin(a) * 260))
	draw_polyline(bow, E.INK, 7.0, true)
	E.stroke(self, bow[0], bow[16], 1.6, rng)


func _butcher(rng: RandomNumberGenerator) -> void:
	# plague butcher: huge round belly, small bagged head, cleaver
	var belly := E.ellipse(Vector2(640, 540), Vector2(300, 230), 40)
	var head := E.ellipse(Vector2(640, 270), Vector2(80, 95), 28)
	var apron := PackedVector2Array([Vector2(530, 420), Vector2(750, 420), Vector2(790, 720), Vector2(490, 720)])
	_body([belly, apron, head], rng, 0.35)
	for i in 6:
		draw_circle(Vector2(560 + rng.randf_range(0, 160), 470 + rng.randf_range(0, 200)), rng.randf_range(6, 14), Color(E.CINNABAR, 0.7))
	E.stroke(self, Vector2(575, 245), Vector2(705, 245), 3.0, rng)
	_eyes([Vector2(615, 262), Vector2(665, 262)], 6.0)
	var cleaver := PackedVector2Array([Vector2(880, 250), Vector2(990, 230), Vector2(1000, 330), Vector2(900, 350)])
	draw_colored_polygon(cleaver, E.PAPER_LIGHT)
	E.hatch(self, cleaver, 0.3, 4.0, 0.9, rng)
	E.outline(self, cleaver, 3.0)
	E.stroke(self, Vector2(895, 345), Vector2(870, 470), 8.0, rng)


func _wraith(rng: RandomNumberGenerator) -> void:
	# weeper: tall veil tapering to tatters, long hands, no face but tears
	var veil := PackedVector2Array([Vector2(640, 80), Vector2(720, 150), Vector2(760, 330), Vector2(830, 560), Vector2(800, 720),
		Vector2(740, 650), Vector2(690, 720), Vector2(640, 640), Vector2(590, 720), Vector2(540, 650), Vector2(480, 720), Vector2(450, 560), Vector2(520, 330), Vector2(560, 150)])
	_body([veil], rng, PI / 2 + 0.02)
	_void(Vector2(640, 210), Vector2(48, 62), rng)
	for x in [618.0, 662.0]:
		E.stroke(self, Vector2(x, 225), Vector2(x - 2, 300), 3.0, rng, E.CINNABAR)
	_eyes([Vector2(618, 214), Vector2(662, 214)], 5.0)
	for side in [-1.0, 1.0]:
		var hand := PackedVector2Array([Vector2(640 + side * 120, 380), Vector2(640 + side * 230, 470), Vector2(640 + side * 240, 520), Vector2(640 + side * 200, 500), Vector2(640 + side * 110, 420)])
		draw_colored_polygon(hand, E.PAPER)
		E.hatch(self, hand, 0.8, 5.0, 0.9, rng)
		E.outline(self, hand, 2.5)


func _golem(rng: RandomNumberGenerator) -> void:
	# ash golem: stacked stone blocks, glowing seams
	var blocks := [PackedVector2Array([Vector2(460, 420), Vector2(820, 410), Vector2(850, 720), Vector2(430, 720)]),
		PackedVector2Array([Vector2(400, 350), Vector2(560, 340), Vector2(560, 520), Vector2(390, 530)]),
		PackedVector2Array([Vector2(720, 340), Vector2(880, 350), Vector2(890, 530), Vector2(720, 520)]),
		PackedVector2Array([Vector2(530, 330), Vector2(750, 320), Vector2(760, 440), Vector2(520, 450)]),
		PackedVector2Array([Vector2(575, 160), Vector2(705, 155), Vector2(715, 330), Vector2(565, 335)])]
	_body(blocks, rng, 0.05)
	for seg in [[Vector2(470, 560), Vector2(820, 575)], [Vector2(640, 420), Vector2(625, 720)], [Vector2(575, 250), Vector2(705, 245)]]:
		E.stroke(self, seg[0], seg[1], 4.0, rng, E.CINNABAR)
	_eyes([Vector2(610, 220), Vector2(670, 220)], 7.0)


func _tithe(rng: RandomNumberGenerator) -> void:
	# tithe collector: robed figure, tall hat, a lantern and a coin purse
	var robe := PackedVector2Array([Vector2(540, 300), Vector2(740, 300), Vector2(830, 720), Vector2(450, 720)])
	var hat := PackedVector2Array([Vector2(585, 110), Vector2(695, 110), Vector2(715, 250), Vector2(565, 250)])
	var brim := E.ellipse(Vector2(640, 250), Vector2(120, 20), 24)
	var face := E.ellipse(Vector2(640, 290), Vector2(55, 50), 24)
	_body([robe, face, brim, hat], rng, PI / 2 - 0.05)
	_void(Vector2(640, 292), Vector2(40, 36), rng)
	_eyes([Vector2(624, 290), Vector2(656, 290)], 5.0)
	var purse := E.ellipse(Vector2(560, 520), Vector2(45, 55), 20)
	draw_colored_polygon(purse, Pal.stat("алчность"))
	E.hatch(self, purse, 0.6, 5.0, 1.0, rng)
	E.outline(self, purse, 2.5)
	E.stroke(self, Vector2(820, 300), Vector2(820, 400), 2.0, rng)
	var lamp := PackedVector2Array([Vector2(795, 400), Vector2(845, 400), Vector2(855, 470), Vector2(785, 470)])
	draw_colored_polygon(lamp, Color("#E0B04A"))
	E.outline(self, lamp, 2.5)
