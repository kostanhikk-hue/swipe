extends Node2D
## Hover tooltip: a parchment note near the mouse. Content: {title, title_color, lines: [[text, color]]}.
## The owner polls providers (hover_at(p) → content or {}) and calls show_at / hide_tip.

const E := preload("res://scripts/engrave.gd")
const W := 300.0

var data := {}
var at := Vector2.ZERO


func show_at(p: Vector2, d: Dictionary) -> void:
	if d == data and p.distance_to(at) < 1.0:
		return
	data = d
	at = p
	visible = true
	queue_redraw()


func hide_tip() -> void:
	if visible:
		data = {}
		visible = false
		queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var lines: Array = data.get("lines", [])
	var h := 40.0
	for l in lines:
		h += _line_h(l)
	var r := Rect2(at + Vector2(18, 14), Vector2(W, h))
	if r.end.x > 1270:
		r.position.x = at.x - W - 14
	if r.end.y > 712:
		r.position.y = 712 - h
	r.position.y = maxf(8.0, r.position.y)
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(E.INK, 0.35))
	draw_rect(r, E.PAPER_LIGHT)
	draw_rect(r, E.INK, false, 2.0)
	draw_rect(r.grow(-4), E.INK, false, 0.8)
	draw_string(bold, r.position + Vector2(12, 26), String(data.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, W - 24, 19, data.get("title_color", E.INK))
	var y := r.position.y + 50
	for l in lines:
		var fs := int(l[2]) if l.size() > 2 else 16
		draw_multiline_string(reg if fs < 17 else bold, Vector2(r.position.x + 12, y), String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, W - 24, fs, -1, l[1])
		y += _line_h(l)


func _line_h(l: Array) -> float:
	var fs := int(l[2]) if l.size() > 2 else 16
	var n := ceili(Fonts.regular().get_string_size(String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / (W - 24.0))
	return maxf(1.0, n) * (fs + 5.0)
