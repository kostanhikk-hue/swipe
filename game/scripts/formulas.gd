class_name Formulas
## Pure functions: combat and economy formulas live here (tested by GUT).

## Swipe decision from horizontal drag offset: -1 sell, +1 equip, 0 undecided.
static func swipe_decision(offset_x: float, threshold: float) -> int:
	if offset_x <= -threshold:
		return -1
	if offset_x >= threshold:
		return 1
	return 0


## Coins for selling an item: base by rarity, +per_ilvl share for each item level.
static func sell_price(rarity: int, ilvl: int, base: Array, per_ilvl: float) -> int:
	return int(round(float(base[rarity]) * (1.0 + per_ilvl * ilvl)))


## "Build power": weighted sum of stats, times the slot's sharpening multiplier.
static func power_of(stats: Dictionary, weights: Dictionary, mult := 1.0) -> float:
	var p := 0.0
	for k in stats:
		p += float(stats[k]) * float(weights.get(k, 0.0)) * mult
	return p


## Armor never blocks everything: damage × K / (armor + K).
static func armor_damage(dmg: float, armor: float, k: float) -> float:
	return dmg * k / (maxf(0.0, armor) + k)
