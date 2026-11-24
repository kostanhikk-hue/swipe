extends Node2D
## Frontal engraved enemy (placeholder shapes: hood / beast / helm). Node origin = PIVOT.

const E := preload("res://scripts/engrave.gd")
const PIVOT := Vector2(640, 430)
const DOOR := Vector2(640, 290)

var appear := 1.0   # 0 = tiny in the doorway, 1 = in front of the hero
var shape := "hood"
var boss := false
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
	match shape:
		"beast":
			_beast(rng)
		"helm":
			_helm(rng)
		_:
			_hood(rng)
	if boss:
		var top := 150.0 if shape == "beast" else (95.0 if shape == "hood" else 160.0)
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
