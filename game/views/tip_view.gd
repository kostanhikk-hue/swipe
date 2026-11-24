extends Node2D
## Onboarding tip: a paper note with a cinnabar frame and an arrow to what it explains.
## One tip at a time; each id is shown once (ids stored in the save by the caller).

const E := preload("res://scripts/engrave.gd")
const W := 380.0

var text := ""
var box := Vector2.ZERO
var to := Vector2.ZERO
var id := ""
var _t := 0.0


func show_tip(tip_id: String, d: Dictionary) -> void:
	id = tip_id
	text = d["text"]
	box = Vector2(d["box"][0], d["box"][1])
	to = Vector2(d["to"][0], d["to"][1])
	_t = 0.0
	visible = true
	queue_redraw()


func hide_tip() -> void:
	id = ""
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func rect() -> Rect2:
	var lines := ceili(Fonts.regular().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x / (W - 32.0)) + 1
	var h := 44.0 + lines * 24.0
	var r := Rect2(box - Vector2(W / 2.0, h / 2.0), Vector2(W, h))
	r.position.x = clampf(r.position.x, 24, 1280 - 24 - W)
	r.position.y = clampf(r.position.y, 24, 720 - 24 - h)
	return r


func _draw() -> void:
	if id == "":
		return
	var a := clampf(_t * 4.0, 0.0, 1.0)
	var r := rect()
	# arrow from the note to the target, with a pulsing ring
	var from := Vector2(clampf(to.x, r.position.x + 20, r.end.x - 20), r.position.y if to.y < r.position.y else r.end.y)
	if not r.has_point(to):
		draw_line(from, to, Color(E.CINNABAR, a), 3.0, true)
		var dir := (to - from).normalized()
		draw_colored_polygon(PackedVector2Array([to, to - dir * 16 + dir.orthogonal() * 8, to - dir * 16 - dir.orthogonal() * 8]), Color(E.CINNABAR, a))
		var k := fmod(_t, 1.2) / 1.2
		draw_arc(to, 10.0 + 22.0 * k, 0, TAU, 28, Color(E.CINNABAR, (1.0 - k) * a), 2.5, true)
	draw_rect(r, Color(E.PAPER_LIGHT, 0.97 * a))
	draw_rect(r, Color(E.CINNABAR, a), false, 3.0)
	draw_rect(r.grow(-5), Color(E.INK, a), false, 1.0)
	draw_string(Fonts.bold(), r.position + Vector2(16, 26), "подсказка · щелчок — скрыть", HORIZONTAL_ALIGNMENT_LEFT, W - 32, 15, Color(E.CINNABAR, a))
	draw_multiline_string(Fonts.regular(), r.position + Vector2(16, 52), text, HORIZONTAL_ALIGNMENT_LEFT, W - 32, 19, -1, Color(E.INK, a))
