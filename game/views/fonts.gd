class_name Fonts
## Alegreya (OFL) for text and numbers — sturdy at small sizes; Cormorant Garamond (OFL) for titles.

static var _cache := {}


static func _var(path: String, weight: int) -> FontVariation:
	var key := path + str(weight)
	if not _cache.has(key):
		var f := FontVariation.new()
		f.base_font = load(path)
		f.variation_opentype = {"wght": weight}
		_cache[key] = f
	return _cache[key]


static func regular() -> FontVariation:
	return _var("res://art/fonts/Alegreya.ttf", 500)


static func bold() -> FontVariation:
	return _var("res://art/fonts/Alegreya.ttf", 760)


## Titles: game name, enemy names, item names, banners.
static func title() -> FontVariation:
	return _var("res://art/fonts/CormorantGaramond.ttf", 700)
