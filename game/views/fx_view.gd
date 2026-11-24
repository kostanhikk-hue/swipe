extends Node2D
## Juice: coins flying to the purse, card shards, ink bursts, floating numbers.
## Pools are plain arrays reused in place; runs on scaled time (hitstop / slow motion).

signal coin_arrived

const E := preload("res://scripts/engrave.gd")

var coins: Array = []
var shards: Array = []
var bursts: Array = []
var texts: Array = []
var specks: Array = []


func spray_coins(from: Vector2, to: Vector2, n: int, rng: RandomNumberGenerator) -> void:
	for i in n:
		coins.append({"a": from + Vector2(rng.randf_range(-40, 40), rng.randf_range(-60, 60)), "b": to,
			"c": from + Vector2(rng.randf_range(-200, 120), rng.randf_range(-260, -40)), "t": -i * 0.04, "life": 0.5})


func shatter(center: Vector2, size: Vector2, rot: float, rng: RandomNumberGenerator) -> void:
	var cols := 3
	var rws := 4
	var cell := size / Vector2(cols, rws)
	for i in cols:
		for j in rws:
			var lc := -size / 2.0 + cell * Vector2(i + 0.5, j + 0.5)
			var poly := PackedVector2Array()
			for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
				poly.append(cell * corner + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9)))
			var p := center + lc.rotated(rot)
			var out := (p - center).normalized()
			shards.append({"poly": poly, "p": p, "v": out * rng.randf_range(250, 650) + Vector2(0, -rng.randf_range(100, 400)),
				"r": rot, "w": rng.randf_range(-7, 7), "t": 0.0, "life": rng.randf_range(0.5, 0.8)})
	for i in 40:
		var a := rng.randf_range(0, TAU)
		specks.append({"p": center, "v": Vector2.from_angle(a) * rng.randf_range(100, 700), "t": 0.0, "life": rng.randf_range(0.3, 0.7), "s": rng.randf_range(1.5, 4.0)})


func ink_burst(p: Vector2, radius := 60.0, col := E.INK) -> void:
	bursts.append({"p": p, "t": 0.0, "life": 0.35, "r": radius, "col": col})


func float_text(s: String, p: Vector2, col := E.INK, size := 30) -> void:
	texts.append({"s": s, "p": p, "t": 0.0, "life": 0.9, "col": col, "size": size})


func busy() -> bool:
	return not (coins.is_empty() and shards.is_empty() and bursts.is_empty() and texts.is_empty() and specks.is_empty())


func _process(delta: float) -> void:
	if not busy():
		return
	for c in coins:
		c["t"] += delta
	var arrived := coins.filter(func(c): return c["t"] >= c["life"])
	for c in arrived:
		coins.erase(c)
		coin_arrived.emit()
	for s in shards:
		s["t"] += delta
		s["v"] += Vector2(0, 1400) * delta
		s["p"] += s["v"] * delta
		s["r"] += s["w"] * delta
	for s in specks:
		s["t"] += delta
		s["v"] *= 0.9
		s["p"] += s["v"] * delta
	for b in bursts:
		b["t"] += delta
	for t in texts:
		t["t"] += delta
	shards = shards.filter(func(s): return s["t"] < s["life"])
	specks = specks.filter(func(s): return s["t"] < s["life"])
	bursts = bursts.filter(func(b): return b["t"] < b["life"])
	texts = texts.filter(func(t): return t["t"] < t["life"])
	queue_redraw()


func _draw() -> void:
	for b in bursts:
		var k: float = b["t"] / b["life"]
		var col: Color = b["col"]
		draw_arc(b["p"], b["r"] * (0.3 + k), 0, TAU, 40, Color(col, 1.0 - k), 10.0 * (1.0 - k) + 1.0, true)
		for i in 10:
			var d := Vector2.from_angle(TAU * i / 10.0 + 0.3)
			draw_line(b["p"] + d * b["r"] * (0.4 + k), b["p"] + d * b["r"] * (0.7 + 1.2 * k), Color(col, 1.0 - k), 3.0 * (1.0 - k) + 0.5)
	for s in shards:
		var a := 1.0 - pow(s["t"] / s["life"], 2.0)
		draw_set_transform(s["p"], s["r"], Vector2.ONE)
		draw_colored_polygon(s["poly"], Color(E.PAPER_LIGHT, a))
		var closed: PackedVector2Array = s["poly"].duplicate()
		closed.append(closed[0])
		draw_polyline(closed, Color(E.INK, a), 2.0, true)
		draw_line(closed[0], closed[2], Color(E.INK, a * 0.6), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in specks:
		draw_circle(s["p"], s["s"], Color(E.INK, 1.0 - s["t"] / s["life"]))
	for c in coins:
		if c["t"] < 0.0:
			continue
		var k: float = c["t"] / c["life"]
		k = k * k
		var p: Vector2 = c["a"].lerp(c["c"], k).lerp(c["c"].lerp(c["b"], k), k)
		draw_circle(p, 10.0, E.PAPER_LIGHT)
		draw_arc(p, 10.0, 0, TAU, 20, E.INK, 2.0, true)
		draw_arc(p, 5.5, 0, TAU, 14, E.INK, 1.0, true)
	for t in texts:
		var k: float = t["t"] / t["life"]
		var p: Vector2 = t["p"] + Vector2(0, -70.0 * k)
		draw_string(Fonts.bold(), p - Vector2(100, 0), t["s"], HORIZONTAL_ALIGNMENT_CENTER, 200, t["size"], Color(t["col"], 1.0 - k * k))
