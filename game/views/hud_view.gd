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
var enemy_note := ""
var actions: Array = []        # [{key, label, cost, ok}] — M06 spends, top centre
var action_rects: Array = []   # filled on draw, for mouse clicks
var undo_hint := 0.0           # 0..1 time left to take back a costly decision
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
	return Vector2(175, 60)


func _process(delta: float) -> void:
	if _coin_punch > 0.0:
		_coin_punch = maxf(0.0, _coin_punch - delta * 3.5)
		queue_redraw()


func _draw() -> void:
	var reg := Fonts.regular()
	var bold := Fonts.bold()
	var k := 1.0 + 0.45 * _coin_punch * _coin_punch
	var a := coin_anchor()
	E.sheet(self, Rect2(22, 26, 338, 80))
	E.sheet(self, Rect2(996, 26, 262, 76))
	draw_string(reg, Vector2(48, 68), "монеты", HORIZONTAL_ALIGNMENT_LEFT, 120, 26, E.INK)
	draw_set_transform(a * (1.0 - k), 0.0, Vector2.ONE * k)
	draw_string(bold, Vector2(150, 70), str(coins), HORIZONTAL_ALIGNMENT_LEFT, 120, 32, Pal.text("алчность"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if coin_ghost > 0:
		draw_string(bold, Vector2(225, 68), "+%d" % coin_ghost, HORIZONTAL_ALIGNMENT_LEFT, 100, 26, E.INK_FADED)
	draw_string(reg, Vector2(48, 96), "глубина %d · рекорд %d" % [depth, best], HORIZONTAL_ALIGNMENT_LEFT, 300, 19, E.INK_FADED)
	draw_string(reg, Vector2(1016, 60), "жизнь", HORIZONTAL_ALIGNMENT_LEFT, 100, 21, E.INK)
	draw_string(bold, Vector2(1060, 62), "%d / %d" % [ceili(hp), roundi(hp_max)], HORIZONTAL_ALIGNMENT_RIGHT, 178, 25, Pal.text("жизнь") if hp > hp_max * 0.35 else E.CINNABAR)
	_bar(Rect2(1018, 74, 218, 16), hp / maxf(1.0, hp_max))
	if enemy_name != "":
		draw_string_outline(Fonts.title(), Vector2(390, 60), enemy_name, HORIZONTAL_ALIGNMENT_CENTER, 500, 36, 8, E.PAPER_LIGHT)
		draw_string(Fonts.title(), Vector2(390, 60), enemy_name, HORIZONTAL_ALIGNMENT_CENTER, 500, 36, E.INK)
		_bar(Rect2(490, 74, 300, 16), enemy_hp / maxf(1.0, enemy_hp_max))
		var hp_txt := "%d / %d" % [ceili(enemy_hp), roundi(enemy_hp_max)]
		draw_string_outline(bold, Vector2(490, 88), hp_txt, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, 4, E.PAPER_LIGHT)
		draw_string(bold, Vector2(490, 88), hp_txt, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, E.INK)
	if enemy_note != "":   # bottom plate: away from the crown and the floating numbers
		var w := minf(600.0, bold.get_string_size(enemy_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 40.0)
		var nr := Rect2(640.0 - w / 2.0, 640, w, 36)
		draw_rect(nr, Color(E.PAPER_LIGHT, 0.96))
		draw_rect(nr, E.CINNABAR, false, 2.0)
		draw_string(bold, nr.position + Vector2(0, 25), enemy_note, HORIZONTAL_ALIGNMENT_CENTER, w, 19, E.CINNABAR)
	action_rects.clear()
	if enemy_name == "" and not actions.is_empty():
		var w := 168.0
		var x0 := 640.0 - (w + 8.0) * actions.size() / 2.0 + 4.0
		for i in actions.size():
			var act: Dictionary = actions[i]
			var r := Rect2(x0 + i * (w + 8.0), 28, w, 56)
			action_rects.append(r)
			var ok: bool = act["ok"]
			draw_rect(r, Color(E.PAPER_LIGHT, 0.9 if ok else 0.5))
			draw_rect(r, E.INK if ok else E.INK_FADED, false, 2.0 if ok else 1.0)
			draw_string(bold, r.position + Vector2(0, 24), "%s · %s" % [act["key"], act["label"]], HORIZONTAL_ALIGNMENT_CENTER, w, 19, E.INK if ok else E.INK_FADED)
			if int(act["cost"]) > 0:
				draw_string(reg, r.position + Vector2(0, 46), "%d монет" % int(act["cost"]), HORIZONTAL_ALIGNMENT_CENTER, w, 17, Pal.text("алчность") if ok else E.INK_FADED)
	if banner != "":
		var parts := banner.split("\n")
		var h := 70.0 + 34.0 * (parts.size() - 1)
		var box := Rect2(330, 360 - h / 2.0, 620, h)
		draw_rect(box, Color(E.PAPER_LIGHT, 0.96))
		draw_rect(box, E.INK, false, 4.0)
		draw_rect(box.grow(-8), E.INK, false, 1.2)
		draw_string(Fonts.title(), Vector2(330, box.position.y + 50), parts[0], HORIZONTAL_ALIGNMENT_CENTER, 620, 42, E.CINNABAR)
		for i in range(1, parts.size()):
			draw_string(bold if i == 1 else reg, Vector2(330, box.position.y + 50 + 34 * i), parts[i], HORIZONTAL_ALIGNMENT_CENTER, 620, 22, E.INK)
	if undo_hint > 0.0:
		var ur := Rect2(490, 610, 300, 44)
		draw_rect(ur, Color(E.PAPER_LIGHT, 0.95))
		draw_rect(ur, E.INK, false, 2.0)
		draw_rect(Rect2(ur.position + Vector2(4, ur.size.y - 7), Vector2((ur.size.x - 8) * undo_hint, 3)), E.CINNABAR)
		draw_string(bold, ur.position + Vector2(0, 28), "Z — отменить решение", HORIZONTAL_ALIGNMENT_CENTER, ur.size.x, 21, E.INK)
	if not show_hints:
		return
	draw_string_outline(bold, Vector2(380, 692), "← продать  A", HORIZONTAL_ALIGNMENT_LEFT, 260, 24, 6, E.PAPER_LIGHT)
	draw_string(bold, Vector2(380, 692), "← продать  A", HORIZONTAL_ALIGNMENT_LEFT, 260, 24, E.INK)
	draw_string_outline(bold, Vector2(740, 692), "D  надеть →", HORIZONTAL_ALIGNMENT_RIGHT, 240, 24, 6, E.PAPER_LIGHT)
	draw_string(bold, Vector2(740, 692), "D  надеть →", HORIZONTAL_ALIGNMENT_RIGHT, 240, 24, E.INK)
	if melt_on:
		draw_string(bold, Vector2(440, 128), "↑ переплавить  W", HORIZONTAL_ALIGNMENT_CENTER, 400, 23, E.INK)


func _bar(r: Rect2, k: float) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), E.CINNABAR)
	draw_rect(r, E.INK, false, 2.0)
	draw_rect(r.grow(4), E.INK, false, 1.0)
