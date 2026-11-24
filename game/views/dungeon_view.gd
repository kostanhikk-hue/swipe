extends Node2D
## The corridor (layer "back") or the hero's hand + engraved vignette (layer "front").
## Static: drawn once, redrawn only when `clear` changes.

const E := preload("res://scripts/engrave.gd")
const V := Vector2(640, 280)
const DOOR := Rect2(565, 175, 150, 210)
const SCREEN := Rect2(0, 0, 1280, 720)

@export var layer := "back"   # back | front (hand + vignette) | hand | vignette
var clear: Array = []   # polygons of clean paper under lettering


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1489 if layer == "back" else 77
	if layer == "back":
		_corridor(rng)
		return
	if layer in ["front", "hand"]:
		_hand(rng)
	if layer in ["front", "vignette"]:
		_vignette(rng)


func _corridor(rng: RandomNumberGenerator) -> void:
	draw_rect(SCREEN, E.PAPER)
	for i in 9:
		var c := Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		draw_colored_polygon(E.ellipse(c, Vector2(rng.randf_range(30, 120), rng.randf_range(20, 70)), 24), Color(E.INK, 0.05))
	var tl := DOOR.position
	var tr := Vector2(DOOR.end.x, DOOR.position.y)
	var br := DOOR.end
	var bl := Vector2(DOOR.position.x, DOOR.end.y)
	var ceiling := PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), tr, tl])
	var floor_p := PackedVector2Array([bl, br, Vector2(1280, 720), Vector2(0, 720)])
	var left := PackedVector2Array([Vector2(0, 0), tl, bl, Vector2(0, 720)])
	var right := PackedVector2Array([tr, Vector2(1280, 0), Vector2(1280, 720), br])
	E.radial(self, left, V, 260, 1.1, rng, E.INK, clear)
	E.radial(self, right, V, 260, 1.1, rng, E.INK, clear)
	E.radial(self, ceiling, V, 320, 1.3, rng, E.INK, clear)
	E.hatch(self, ceiling, 0.0, 9.0, 1.0, rng, E.INK, false, Rect2(), clear)
	E.radial(self, floor_p, V, 140, 0.9, rng, E.INK_FADED, clear)
	for t in [0.12, 0.26, 0.4, 0.52, 0.63, 0.73, 0.82, 0.9, 0.96]:
		var r := Rect2(SCREEN.position.lerp(DOOR.position, t), SCREEN.size.lerp(DOOR.size, t))
		for seg in E._cut([PackedVector2Array([r.position, Vector2(r.position.x, r.end.y)]),
				PackedVector2Array([Vector2(r.end.x, r.position.y), r.end]),
				PackedVector2Array([Vector2(r.position.x, r.end.y), r.end])], clear):
			E.stroke(self, seg[0], seg[seg.size() - 1], 2.2 - t, rng)
	for y in [90.0, 190.0, 300.0, 420.0, 540.0, 640.0]:
		for side in [0.0, 1280.0]:
			var p := Vector2(side, y)
			var poly := left if side == 0.0 else right
			for seg in E._cut(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([p, p.lerp(V, 0.82)]), poly), clear):
				E.stroke(self, seg[0], seg[seg.size() - 1], 2.0, rng)
	var door := PackedVector2Array([tl, tr, br, bl])
	draw_colored_polygon(door, Color(E.INK, 0.55))
	for ang in [0.35, -0.35, 1.57]:
		E.hatch(self, door, ang, 3.2, 1.2, rng)
	E.outline(self, door, 3.0)


func _hand(rng: RandomNumberGenerator) -> void:
	var blade := PackedVector2Array([Vector2(185, 575), Vector2(212, 598), Vector2(410, 372), Vector2(396, 352)])
	var guard := PackedVector2Array([Vector2(135, 545), Vector2(152, 530), Vector2(262, 625), Vector2(245, 640)])
	var arm := PackedVector2Array([Vector2(0, 720), Vector2(0, 600), Vector2(95, 560), Vector2(190, 585), Vector2(235, 650), Vector2(215, 720)])
	for poly in [blade, guard, arm]:
		draw_colored_polygon(poly, E.PAPER)
		E.hatch(self, poly, -0.85, 5.5, 1.0, rng)
		E.outline(self, poly, 3.0)
	E.hatch(self, arm, 0.6, 7.0, 0.9, rng)
	for i in 4:
		E.stroke(self, Vector2(30 + i * 45, 720), Vector2(60 + i * 42, 575 + i * 6), 2.2, rng)


func _vignette(rng: RandomNumberGenerator) -> void:
	for l in [[Vector2(600, 370), 0.55, 7.0], [Vector2(660, 410), -0.55, 6.0], [Vector2(700, 440), 0.0, 5.0]]:
		E.hatch(self, E.ellipse(Vector2(640, 360), l[0], 64), l[1], l[2], 1.1, rng, E.INK, true, SCREEN, clear)
	draw_rect(SCREEN.grow(-6), E.INK, false, 12.0)
	draw_rect(SCREEN.grow(-20), E.INK, false, 1.5)
