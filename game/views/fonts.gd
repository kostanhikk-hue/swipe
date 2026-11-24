class_name Fonts
## Cormorant Garamond (OFL) at two weights.

static var _cache := {}


static func get_font(weight: int) -> FontVariation:
	if not _cache.has(weight):
		var f := FontVariation.new()
		f.base_font = load("res://art/fonts/CormorantGaramond.ttf")
		f.variation_opentype = {"wght": weight}
		_cache[weight] = f
	return _cache[weight]


static func regular() -> FontVariation:
	return get_font(500)


static func bold() -> FontVariation:
	return get_font(700)
