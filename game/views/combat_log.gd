extends Node2D
## Short combat log on the left: newest at the bottom, older lines fade.

const E := preload("res://scripts/engrave.gd")
const AREA := Rect2(40, 128, 300, 330)
const MAX := 11

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
	var y := AREA.end.y - 6
	for i in range(lines.size() - 1, -1, -1):
		var age := lines.size() - 1 - i
		var col: Color = lines[i][1]
		draw_string(reg if age > 0 else Fonts.bold(), Vector2(AREA.position.x + 8, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, AREA.size.x - 16, 19, Color(col, 1.0 - age * 0.075))
		y -= 28
