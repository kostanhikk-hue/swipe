class_name Engrave
## Procedural engraving: hatching clipped to polygons, wobbly hand-cut strokes.
## Call only from inside a CanvasItem's _draw().

const INK := Color("#1F150E")
const INK_FADED := Color("#4A3524")
const PAPER := Color("#B9A276")
const PAPER_LIGHT := Color("#CDB88E")
const CINNABAR := Color("#9E1B14")


## Parallel strokes at `angle`, kept inside `poly` (or outside it when `outside`).
static func hatch(ci: CanvasItem, poly: PackedVector2Array, angle: float, spacing: float,
		width: float, rng: RandomNumberGenerator, color := INK, outside := false,
		area := Rect2(), holes: Array = []) -> void:
	var b := area if outside else _bounds(poly)
	var center := b.get_center()
	var radius := b.size.length() * 0.5 + spacing
	var dir := Vector2.from_angle(angle)
	var nrm := dir.orthogonal()
	var n := int(ceil(radius * 2.0 / spacing))
	for i in n + 1:
		var off := -radius + i * spacing + rng.randf_range(-0.2, 0.2) * spacing
		var line := PackedVector2Array([center + nrm * off - dir * radius, center + nrm * off + dir * radius])
		var parts: Array
		if outside:
			parts = Geometry2D.clip_polyline_with_polygon(line, poly)
		else:
			parts = Geometry2D.intersect_polyline_with_polygon(line, poly)
		for seg in _cut(parts, holes):
			stroke(ci, seg[0], seg[seg.size() - 1], width * rng.randf_range(0.7, 1.25), rng, color)


## Strokes radiating from `origin`, clipped to `poly` — perspective engraving.
static func radial(ci: CanvasItem, poly: PackedVector2Array, origin: Vector2, count: int,
		width: float, rng: RandomNumberGenerator, color := INK, holes: Array = []) -> void:
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.01, 0.01)
		var line := PackedVector2Array([origin, origin + Vector2.from_angle(a) * 3000.0])
		for seg in _cut(Geometry2D.intersect_polyline_with_polygon(line, poly), holes):
			stroke(ci, seg[0], seg[seg.size() - 1], width * rng.randf_range(0.6, 1.3), rng, color)


## One hand-cut stroke: slight wobble, tapered by drawing a thinner core.
static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, w: float, rng: RandomNumberGenerator,
		color := INK) -> void:
	var length := a.distance_to(b)
	if length < 1.5:
		return
	var steps := maxi(1, int(length / 28.0))
	var nrm := (b - a).normalized().orthogonal()
	var pts := PackedVector2Array()
	for s in steps + 1:
		pts.append(a.lerp(b, s / float(steps)) + nrm * rng.randf_range(-0.7, 0.7))
	ci.draw_polyline(pts, color, w, true)


static func outline(ci: CanvasItem, poly: PackedVector2Array, w: float, color := INK) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, color, w, true)


static func ellipse(c: Vector2, r: Vector2, n := 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2(cos(TAU * i / n) * r.x, sin(TAU * i / n) * r.y))
	return pts


## Removes the parts of polylines that fall inside any hole polygon (clean paper under lettering).
static func _cut(parts: Array, holes: Array) -> Array:
	var out := parts
	for h in holes:
		var next := []
		for seg in out:
			next.append_array(Geometry2D.clip_polyline_with_polygon(seg, h))
		out = next
	return out.filter(func(s): return s.size() >= 2)


static func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## A clean parchment sheet for UI: soft shadow, light paper, double ink frame, corner ticks.
static func sheet(ci: CanvasItem, r: Rect2, title := "") -> void:
	ci.draw_rect(Rect2(r.position + Vector2(6, 7), r.size), Color(INK, 0.35))
	ci.draw_rect(r, PAPER_LIGHT)
	ci.draw_rect(r, INK, false, 2.5)
	ci.draw_rect(r.grow(-6), INK, false, 1.0)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		ci.draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), INK)
	if title != "":
		ci.draw_string(Fonts.title(), Vector2(r.position.x, r.position.y + 30), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, INK)
		ci.draw_line(Vector2(r.position.x + 24, r.position.y + 40), Vector2(r.end.x - 24, r.position.y + 40), Color(INK, 0.6), 1.0)
