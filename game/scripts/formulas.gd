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


## Expected damage per second with crits.
static func dps(dmg: float, speed: float, crit: float, crit_mult: float) -> float:
	return dmg * speed * (1.0 + minf(100.0, crit) / 100.0 * (crit_mult - 1.0))


## Effective HP: how much raw damage it takes to kill (armor, block, lifesteal stretch HP).
static func ehp(hp: float, armor: float, block: float, k: float, block_cap: float) -> float:
	var through := k / (maxf(0.0, armor) + k) * (1.0 - minf(block, block_cap) / 100.0)
	return hp / maxf(0.05, through)


## "Build power" shown on cards: geometric mean of offence and defence.
static func power(dps_v: float, ehp_v: float) -> float:
	return sqrt(maxf(0.0, dps_v) * maxf(0.0, ehp_v))


## Armor never blocks everything: damage × K / (armor + K).
static func armor_damage(dmg: float, armor: float, k: float) -> float:
	return dmg * k / (maxf(0.0, armor) + k)


## M06 prices: grow with depth; reroll and sharpening also escalate per use (Slay the Spire style).
static func heal_cost(depth: int, c: Dictionary) -> int:
	return roundi(float(c["base"]) + float(c["per_depth"]) * depth)


static func reroll_cost(depth: int, uses: int, c: Dictionary) -> int:
	return roundi(float(c["base"]) + float(c["per_depth"]) * depth + float(c["per_use"]) * uses)


static func sharpen_cost(depth: int, rank: int, c: Dictionary) -> int:
	return roundi(float(c["base"]) + float(c["per_rank"]) * rank + float(c["per_depth"]) * depth)
