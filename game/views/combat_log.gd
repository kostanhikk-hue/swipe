extends Node2D
## Short combat log on the left: newest at the bottom, older lines fade.

const E := preload("res://scripts/engrave.gd")
const AREA := Rect2(34, 488, 316, 108)
const MAX := 4

var lines: Array = []   # [text, color]


func add(text: String, col: Color) -> void:
	lines.append([text, col])
	if lines.size() > MAX:
		lines.pop_front()
	queue_redraw()


func clear_log() -> void:
	lines.clear()
	queue_redraw()


func _draw() -> void:
	var reg := Fonts.regular()
	draw_line(AREA.position + Vector2(8, 0), Vector2(AREA.end.x - 8, AREA.position.y), Color(E.INK, 0.5), 1.0)
	draw_string(reg, AREA.position + Vector2(8, 16), "ход боя", HORIZONTAL_ALIGNMENT_LEFT, 120, 13, E.INK_FADED)
	var y := AREA.end.y - 6
	for i in range(lines.size() - 1, -1, -1):
		var age := lines.size() - 1 - i
		var col: Color = lines[i][1]
		draw_string(reg if age > 0 else Fonts.bold(), Vector2(AREA.position.x + 8, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, AREA.size.x - 16, 16, Color(col, 1.0 - age * 0.12))
		y -= 23
