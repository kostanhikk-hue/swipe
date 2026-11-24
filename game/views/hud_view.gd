extends Node2D
## Coins, depth, life; control hints; ghost "+N" previews and punches on change.

const E := preload("res://scripts/engrave.gd")

var coins := 0
var coin_ghost := 0
var melt_on := true
var depth := 14
var best := 31
var hp := 84.0
var hp_max := 120.0
var enemy_name := ""
var enemy_hp := 0.0
var enemy_hp_max := 1.0
var show_hints := true
var banner := ""
var _coin_punch := 0.0


func punch_coins() -> void:
	_coin_punch = 1.0
	queue_redraw()


func set_coins(c: int, ghost: int) -> void:
	if c != coins or ghost != coin_ghost:
		coins = c
		coin_ghost = ghost
		queue_redraw()


func coin_anchor() -> Vector2:
	return Vector2(190, 60)


func _process(delta: float) -> void:
	if _coin_punch > 0.0:
		_coin_punch = maxf(0.0, _coin_punch - delta * 3.5)
		queue_redraw()


func _draw() -> void:
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var k := 1.0 + 0.45 * _coin_punch * _coin_punch
	var a := coin_anchor()
	draw_string(reg, Vector2(48, 68), "монеты", HORIZONTAL_ALIGNMENT_LEFT, 120, 28, E.INK)
	draw_set_transform(a * (1.0 - k), 0.0, Vector2.ONE * k)
	draw_string(bold, Vector2(150, 68), str(coins), HORIZONTAL_ALIGNMENT_LEFT, 120, 30, E.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if coin_ghost > 0:
		draw_string(bold, Vector2(225, 68), "+%d" % coin_ghost, HORIZONTAL_ALIGNMENT_LEFT, 100, 26, E.INK_FADED)
	draw_string(reg, Vector2(48, 96), "глубина %d · рекорд %d" % [depth, best], HORIZONTAL_ALIGNMENT_LEFT, 360, 21, E.INK)
	draw_string(bold, Vector2(932, 66), "жизнь %d / %d" % [ceili(hp), roundi(hp_max)], HORIZONTAL_ALIGNMENT_RIGHT, 300, 26, E.INK)
	_bar(Rect2(942, 78, 288, 14), hp / maxf(1.0, hp_max))
	if enemy_name != "":
		draw_string(bold, Vector2(390, 60), enemy_name, HORIZONTAL_ALIGNMENT_CENTER, 500, 36, E.INK)
		_bar(Rect2(490, 74, 300, 16), enemy_hp / maxf(1.0, enemy_hp_max))
		draw_string(reg, Vector2(490, 112), "%d / %d" % [ceili(enemy_hp), roundi(enemy_hp_max)], HORIZONTAL_ALIGNMENT_CENTER, 300, 17, E.INK)
	if banner != "":
		draw_rect(Rect2(340, 300, 600, 120), Color(E.PAPER_LIGHT, 0.95))
		draw_rect(Rect2(340, 300, 600, 120), E.INK, false, 4.0)
		draw_rect(Rect2(348, 308, 584, 104), E.INK, false, 1.2)
		var parts := banner.split("\n")
		draw_string(bold, Vector2(340, 352), parts[0], HORIZONTAL_ALIGNMENT_CENTER, 600, 40, E.CINNABAR)
		if parts.size() > 1:
			draw_string(reg, Vector2(340, 394), parts[1], HORIZONTAL_ALIGNMENT_CENTER, 600, 24, E.INK)
	if not show_hints:
		return
	draw_string(bold, Vector2(300, 668), "← продать  A", HORIZONTAL_ALIGNMENT_LEFT, 260, 25, E.INK)
	draw_string(bold, Vector2(780, 668), "D  надеть →", HORIZONTAL_ALIGNMENT_RIGHT, 220, 25, E.INK)
	if melt_on:
		draw_string(bold, Vector2(440, 128), "↑ переплавить  W", HORIZONTAL_ALIGNMENT_CENTER, 400, 23, E.INK)


func _bar(r: Rect2, k: float) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), E.CINNABAR)
	draw_rect(r, E.INK, false, 2.0)
	draw_rect(r.grow(4), E.INK, false, 1.0)
