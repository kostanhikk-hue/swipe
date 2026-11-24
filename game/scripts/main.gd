extends Node2D
## Hello scene: parchment, a hatched enemy silhouette, a swipeable loot card.
## Placeholder art drawn in code (ART_BIBLE: engraving on dark parchment).

const INK := Color(0.12, 0.09, 0.07)
const PAPER := Color(0.78, 0.69, 0.53)
const PAPER_DARK := Color(0.55, 0.46, 0.33)
const ACCENT := Color(0.55, 0.12, 0.08)
const THRESHOLD := 150.0
const ITEMS := ["Ржавый клинок", "Кольцо пепла", "Шлем пилигрима", "Амулет вдовы", "Перчатки палача"]

var card_offset := Vector2.ZERO
var dragging := false
var flying := 0          # -1 left, +1 right, 0 none
var item_index := 0
var sold := 0
var equipped := 0
var _rng := RandomNumberGenerator.new()
var _hatch: PackedVector2Array


func _ready() -> void:
	_rng.seed = 7
	for i in 220:
		var p := Vector2(_rng.randf_range(-130, 130), _rng.randf_range(-170, 150))
		_hatch.append(p)


func _process(delta: float) -> void:
	if flying != 0:
		card_offset.x += flying * 2600.0 * delta
		card_offset.y -= 300.0 * delta
		if absf(card_offset.x) > 1100.0:
			if flying < 0:
				sold += 1
			else:
				equipped += 1
			flying = 0
			card_offset = Vector2.ZERO
			item_index = (item_index + 1) % ITEMS.size()
	elif not dragging:
		card_offset = card_offset.lerp(Vector2.ZERO, minf(1.0, 12.0 * delta))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if flying != 0:
		return
	if event.is_action_pressed("swipe_left"):
		flying = -1
	elif event.is_action_pressed("swipe_right"):
		flying = 1
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if not dragging:
			flying = Formulas.swipe_decision(card_offset.x, THRESHOLD)
	elif event is InputEventMouseMotion and dragging:
		card_offset += event.relative


func _draw() -> void:
	var vp := get_viewport_rect().size
	var c := vp / 2.0
	# parchment with darker edges
	draw_rect(Rect2(Vector2.ZERO, vp), PAPER_DARK)
	draw_rect(Rect2(Vector2(40, 30), vp - Vector2(80, 60)), PAPER)
	for i in 60:
		var y := 30.0 + i * (vp.y - 60.0) / 60.0
		draw_line(Vector2(40, y), Vector2(vp.x - 40, y), Color(PAPER_DARK, 0.12), 1.0)
	# enemy silhouette (behind the card) with engraving hatch
	var ec := c + Vector2(0, -10)
	draw_circle(ec + Vector2(0, -150), 55, INK)
	draw_colored_polygon(PackedVector2Array([ec + Vector2(-120, -90), ec + Vector2(120, -90),
		ec + Vector2(170, 260), ec + Vector2(-170, 260)]), INK)
	for p in _hatch:
		var a := ec + p
		draw_line(a, a + Vector2(14, -9), Color(PAPER, 0.18), 1.0)
	# loot card
	var font := ThemeDB.fallback_font
	var rot := card_offset.x / 900.0
	var cc := c + Vector2(0, 90) + card_offset
	draw_set_transform(cc, rot, Vector2.ONE)
	var r := Rect2(Vector2(-130, -170), Vector2(260, 340))
	draw_rect(r.grow(6), INK)
	draw_rect(r, PAPER)
	draw_rect(r.grow(-10), INK, false, 2.0)
	draw_string(font, Vector2(-120, -120), ITEMS[item_index], HORIZONTAL_ALIGNMENT_CENTER, 240, 22, INK)
	draw_string(font, Vector2(-120, -85), "редкое", HORIZONTAL_ALIGNMENT_CENTER, 240, 16, ACCENT)
	draw_string(font, Vector2(-110, 10), "+12 урон", HORIZONTAL_ALIGNMENT_LEFT, 220, 18, INK)
	draw_string(font, Vector2(-110, 40), "+4% крит", HORIZONTAL_ALIGNMENT_LEFT, 220, 18, INK)
	var d := Formulas.swipe_decision(card_offset.x, THRESHOLD)
	if d != 0:
		var label := "ПРОДАТЬ" if d < 0 else "НАДЕТЬ"
		draw_string(font, Vector2(-120, 130), label, HORIZONTAL_ALIGNMENT_CENTER, 240, 28, ACCENT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# hints and counters
	draw_string(font, Vector2(70, vp.y - 60), "← продать", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	draw_string(font, Vector2(vp.x - 230, vp.y - 60), "надеть →", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	draw_string(font, Vector2(70, 80), "продано %d   надето %d" % [sold, equipped], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
