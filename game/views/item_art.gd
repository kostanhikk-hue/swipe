class_name ItemArt
## Engraved slot silhouettes (placeholders until real drawings arrive) and rarity frames.

const E := preload("res://scripts/engrave.gd")


static func slot_poly(slot: String, c: Vector2, s: float) -> PackedVector2Array:
	match slot:
		"weapon":
			return PackedVector2Array([c + Vector2(-s, s * 0.8), c + Vector2(-s * 0.75, s), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.8, -s)])
		"helm":
			var p := E.ellipse(c + Vector2(0, s * 0.35), Vector2(s * 0.95, s * 1.15), 24).slice(12, 24)
			p.append(c + Vector2(s * 0.95, s * 0.35))
			return p
		"armor":
			return PackedVector2Array([c + Vector2(-s, -s), c + Vector2(-s * 0.4, -s * 0.8), c + Vector2(s * 0.4, -s * 0.8), c + Vector2(s, -s), c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s)])
		"gloves":
			return PackedVector2Array([c + Vector2(-s * 0.6, s), c + Vector2(-s * 0.6, -s), c + Vector2(s * 0.5, -s), c + Vector2(s * 0.5, 0), c + Vector2(s, -s * 0.3), c + Vector2(s, s * 0.3), c + Vector2(s * 0.5, s)])
		"boots":
			return PackedVector2Array([c + Vector2(-s * 0.5, -s), c + Vector2(s * 0.2, -s), c + Vector2(s * 0.2, s * 0.3), c + Vector2(s, s * 0.5), c + Vector2(s, s), c + Vector2(-s * 0.5, s)])
		"belt":
			return PackedVector2Array([c + Vector2(-s, -s * 0.35), c + Vector2(s, -s * 0.35), c + Vector2(s, s * 0.35), c + Vector2(-s, s * 0.35)])
		"shield":
			return PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	return E.ellipse(c + Vector2(0, s * 0.15), Vector2(s * 0.7, s * 0.7), 20)  # amulet, ring


## Draws an item silhouette into `ci` (call from _draw). `big` adds cross-hatching and details.
static func draw_item(ci: CanvasItem, slot: String, c: Vector2, s: float, rng: RandomNumberGenerator, big := false) -> void:
	var base := slot.trim_suffix("1").trim_suffix("2")
	var poly := slot_poly(base, c, s)
	var w := 1.0 if not big else 1.3
	if base == "ring":
		E.outline(ci, poly, s * 0.28)
		if big:
			ci.draw_circle(c + Vector2(0, -s * 0.6), s * 0.18, E.CINNABAR)
		return
	if big:
		ci.draw_colored_polygon(poly, E.PAPER)
	E.hatch(ci, poly, -0.8, maxf(2.4, s * 0.08), w * 0.8, rng)
	if big:
		var shade := Geometry2D.intersect_polygons(poly, PackedVector2Array([c, c + Vector2(s * 3, 0), c + Vector2(s * 3, s * 3), c + Vector2(0, s * 3)]))
		for sp in shade:
			E.hatch(ci, sp, 0.7, maxf(2.4, s * 0.07), w * 0.8, rng)
	E.outline(ci, poly, maxf(1.4, s * 0.05))
	if base == "amulet":
		E.stroke(ci, c + Vector2(-s, -s), c + Vector2(0, -s * 0.55), w, rng)
		E.stroke(ci, c + Vector2(s, -s), c + Vector2(0, -s * 0.55), w, rng)


## Rarity = frame weight + corners; cinnabar only for legendary (ART_BIBLE).
static func rarity_frame(ci: CanvasItem, c: Rect2, r: int, k := 1.0) -> void:
	match r:
		0:
			ci.draw_rect(c, E.INK_FADED, false, 1.0 * k)
		1:
			ci.draw_rect(c, E.INK, false, 1.2 * k)
			ci.draw_rect(c.grow(-3 * k), E.INK, false, 1.0 * k)
		_:
			var col := E.CINNABAR if r == 3 else E.INK
			ci.draw_rect(c, col, false, (3.0 if r == 3 else 2.6) * k)
			ci.draw_rect(c.grow(-4 * k), E.INK, false, 1.2 * k)
			var q := 3.5 * k
			for p in [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]:
				ci.draw_rect(Rect2(p - Vector2(q, q), Vector2(q, q) * 2), col)
