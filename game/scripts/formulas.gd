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


## Build power from a hero fighter (Combat.hero_from): √(offence × defence) against a reference
## enemy (armor 20, ~1 hit/s, ~10 s fight), so every combat stat moves it the same way it moves a fight.
static func build_power(h: Dictionary, t: CombatTuning) -> float:
	var p := build_parts(h, t)
	return power(p.x, p.y)


## (attack, defence): attack — damage per second vs the reference enemy (armor 20) with crits,
## poison, thorns…; defence — raw damage the hero can take (HP + regen + ward, armor, block, lifesteal).
static func build_parts(h: Dictionary, t: CombatTuning) -> Vector2:
	var ref_armor := 20.0 * (1.0 - minf(80.0, float(h["pen"])) / 100.0)
	var cm := t.crit_mult + float(h["critdmg"]) / 100.0
	var crit := float(h["crit"])
	var fl: Array = h.get("flags", [])
	if "third_crit" in fl:
		crit = crit + (100.0 - crit) / 3.0
	var mult := 1.0 + float(h["poison"]) / 100.0 + float(h["execute"]) / 100.0 * 0.25 + float(h["fury"]) / 100.0 * 0.2
	var hits := maxf(1.0, float(h["speed"]) * 8.0)
	mult += float(h["onset"]) / 100.0 / hits
	var d := dps(float(h["dmg"]) * mult, float(h["speed"]), crit, cm) * t.armor_k / (ref_armor + t.armor_k)
	var blocked := minf(float(h["block"]), t.block_cap) / 100.0
	var thorns := float(h["thorns"]) + (6.0 if "thorns_grow" in fl else 0.0)   # ~3 hits taken per fight
	d += thorns * (1.0 - blocked) + float(h["riposte"]) / 100.0 * float(h["dmg"]) * blocked
	var hp := float(h["max_hp"]) + float(h["regen"]) * 8.0 + float(h["ward"])
	if "overheal" in fl:
		hp += float(h["max_hp"]) * 0.15
	var e := ehp(hp, float(h["armor"]), float(h["block"]), t.armor_k, t.block_cap) * (1.0 + float(h["vamp"]) / 50.0)
	e /= 1.0 + float(h["vuln"]) / 100.0
	return Vector2(d, e)


## Armor never blocks everything: damage × K / (armor + K).
static func armor_damage(dmg: float, armor: float, k: float) -> float:
	return dmg * k / (maxf(0.0, armor) + k)


## M06 prices: grow with depth; reroll and sharpening also escalate per use (Slay the Spire style).
static func heal_cost(depth: int, c: Dictionary) -> int:
	return roundi(float(c["base"]) + float(c["per_depth"]) * depth)


static func reroll_cost(depth: int, uses: int, c: Dictionary) -> int:
	return roundi(float(c["base"]) + float(c["per_depth"]) * depth + float(c["per_use"]) * uses)


## Sharpening grows quadratically with the rank: coins can't snowball one slot forever.
static func sharpen_cost(depth: int, rank: int, c: Dictionary) -> int:
	return roundi(float(c["base"]) + float(c["per_rank"]) * rank + float(c.get("per_rank2", 0.0)) * rank * rank + float(c["per_depth"]) * depth)
