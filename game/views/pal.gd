class_name Pal
## ART_BIBLE colors for rarities and stats (Diablo-bright, decision #24) + engraved stat icons.

const RARITY := [Color("#1F150E"), Color("#2457C5"), Color("#D9A400"), Color("#E0701A")]
const RARITY_TEXT := [Color("#1F150E"), Color("#2457C5"), Color("#9A7400"), Color("#C55A0C")]
const RARITY_NAME := ["обычное", "магическое", "редкое", "легендарное"]
const STAT := {"урон": Color("#C62828"), "скорость": Color("#00897B"), "крит": Color("#D81B60"),
	"броня": Color("#546E7A"), "жизнь": Color("#2E7D32"), "вампиризм": Color("#7B1FA2"), "блок": Color("#6D4C41"), "проворство": Color("#0277BD"),
	"сила крита": Color("#AD1457"), "пробивание": Color("#37474F"), "шипы": Color("#558B2F"),
	"регенерация": Color("#43A047"), "алчность": Color("#B8860B")}
const PCT := ["крит", "сила крита", "пробивание", "проворство", "вампиризм", "блок", "алчность"]


static func stat(k: String) -> Color:
	return STAT.get(k, Color("#1F150E"))


## Small filled icon for a stat, centred at c, radius s.
static func stat_icon(ci: CanvasItem, k: String, c: Vector2, s: float) -> void:
	var col := stat(k)
	var ink := Color("#1F150E")
	var poly := PackedVector2Array()
	match k:
		"урон":   # sword
			poly = PackedVector2Array([c + Vector2(-s, s * 0.75), c + Vector2(-s * 0.75, s), c + Vector2(s, -s * 0.75), c + Vector2(s * 0.75, -s)])
			ci.draw_colored_polygon(poly, col)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.1), c + Vector2(-s * 0.1, s * 0.7), ink, maxf(1.5, s * 0.25))
		"скорость":   # double chevron
			for dx in [-0.45, 0.25]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * (dx - 0.3), -s * 0.75), c + Vector2(s * (dx + 0.3), 0), c + Vector2(s * (dx - 0.3), s * 0.75)]), col, maxf(2.0, s * 0.35), true)
			return
		"крит":   # four-point star
			for i in 8:
				var r := s if i % 2 == 0 else s * 0.35
				poly.append(c + Vector2.from_angle(TAU * i / 8.0 - PI / 2) * r)
			ci.draw_colored_polygon(poly, col)
		"броня":   # breastplate
			poly = PackedVector2Array([c + Vector2(-s, -s * 0.8), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.8, s * 0.3), c + Vector2(0, s), c + Vector2(-s * 0.8, s * 0.3)])
			ci.draw_colored_polygon(poly, col)
		"жизнь":   # heart
			ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.25), s * 0.5, col)
			ci.draw_circle(c + Vector2(s * 0.45, -s * 0.25), s * 0.5, col)
			poly = PackedVector2Array([c + Vector2(-s * 0.93, -s * 0.05), c + Vector2(s * 0.93, -s * 0.05), c + Vector2(0, s)])
			ci.draw_colored_polygon(poly, col)
			return
		"вампиризм":   # drop
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.62, col)
			poly = PackedVector2Array([c + Vector2(-s * 0.55, s * 0.05), c + Vector2(0, -s), c + Vector2(s * 0.55, s * 0.05)])
			ci.draw_colored_polygon(poly, col)
			return
		"проворство":   # feather-like arrow
			poly = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, s * 0.1), c + Vector2(s * 0.25, s * 0.1), c + Vector2(s * 0.25, s), c + Vector2(-s * 0.25, s), c + Vector2(-s * 0.25, s * 0.1), c + Vector2(-s * 0.7, s * 0.1)])
			ci.draw_colored_polygon(poly, col)
		"сила крита":   # star in a ring
			ci.draw_arc(c, s * 0.95, 0, TAU, 20, col, maxf(1.5, s * 0.22), true)
			for i in 8:
				var r := s * 0.7 if i % 2 == 0 else s * 0.25
				poly.append(c + Vector2.from_angle(TAU * i / 8.0 - PI / 2) * r)
			ci.draw_colored_polygon(poly, col)
			return
		"пробивание":   # arrow through a bar
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s * 0.5, 0), col, maxf(2.0, s * 0.3))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(s * 0.3, -s * 0.55), c + Vector2(s * 0.3, s * 0.55)]), col)
			ci.draw_line(c + Vector2(-s * 0.2, -s), c + Vector2(-s * 0.2, s), ink, maxf(1.5, s * 0.2))
			return
		"шипы":   # thorny branch
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, maxf(2.0, s * 0.3))
			for f in [-0.5, 0.0, 0.5]:
				var p := c + Vector2(s * f, -s * f)
				ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-s * 0.15, -s * 0.5), p + Vector2(s * 0.2, -s * 0.1)]), col)
			return
		"регенерация":   # cross
			ci.draw_rect(Rect2(c - Vector2(s * 0.3, s), Vector2(s * 0.6, s * 2)), col)
			ci.draw_rect(Rect2(c - Vector2(s, s * 0.3), Vector2(s * 2, s * 0.6)), col)
			return
		"алчность":   # coin
			ci.draw_circle(c, s * 0.9, col)
			ci.draw_arc(c, s * 0.55, 0, TAU, 14, ink, 1.0, true)
			return
		"блок":   # round shield with boss
			ci.draw_circle(c, s * 0.9, col)
			ci.draw_circle(c, s * 0.3, ink)
			return
	if poly.size() > 2:
		var closed := poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, ink, 1.0, true)
