extends Node2D
## Coins, depth, life; control hints; ghost "+N" previews and punches on change.

const E := preload("res://scripts/engrave.gd")

var coins := 0
var coin_ghost := 0
var melt_on := true
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
	draw_string(reg, Vector2(48, 96), "глубина 14 · рекорд 31", HORIZONTAL_ALIGNMENT_LEFT, 360, 21, E.INK)
	draw_string(bold, Vector2(932, 66), "жизнь 84 / 120", HORIZONTAL_ALIGNMENT_RIGHT, 300, 26, E.INK)
	var bar := Rect2(942, 78, 288, 14)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * 0.7, bar.size.y)), E.CINNABAR)
	draw_rect(bar, E.INK, false, 2.0)
	draw_rect(bar.grow(4), E.INK, false, 1.0)
	draw_string(bold, Vector2(300, 668), "← продать  A", HORIZONTAL_ALIGNMENT_LEFT, 260, 25, E.INK)
	draw_string(bold, Vector2(780, 668), "D  надеть →", HORIZONTAL_ALIGNMENT_RIGHT, 220, 25, E.INK)
	if melt_on:
		draw_string(bold, Vector2(440, 128), "↑ переплавить  W", HORIZONTAL_ALIGNMENT_CENTER, 400, 23, E.INK)
