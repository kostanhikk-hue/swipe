class_name LoopMath
## Enemy scaling by depth (shared by the run and the balance simulator).
## HP and damage grow by compound %, armor grows linearly (decision: no hidden armor wall).


static func enemy_at(d: Dictionary, depth: int, ct: CombatTuning) -> Dictionary:
	# tutorial: the first enemies are weak and do not grow; growth starts after them
	var grow := maxi(0, depth - ct.tutorial_depth - 1)
	var ramp := clampf(float(depth - ct.tutorial_depth) / maxf(1.0, ct.ramp_depths), 0.0, 1.0)
	var early := lerpf(ct.tutorial_mult, 1.0, ramp)
	var mh := pow(1.0 + ct.depth_hp, grow) * early
	var md := pow(1.0 + ct.depth_dmg, grow) * early
	var ma := (1.0 + ct.depth_armor * grow) * early
	var lin := 1.0 + ct.depth_dmg * 0.5 * grow   # thorns/regen of enemies grow linearly and slowly
	return {"hp": float(d["hp"]) * mh, "max_hp": float(d["hp"]) * mh, "dmg": float(d["dmg"]) * md,
		"speed": float(d["speed"]), "armor": float(d["armor"]) * ma, "crit": float(d.get("crit", 0)),
		"block": float(d.get("block", 0)), "vamp": float(d.get("vamp", 0)),
		"regen": float(d.get("regen", 0)) * lin, "thorns": float(d.get("thorns", 0)) * lin,
		"poison": float(d.get("poison", 0)), "steal": float(d.get("steal", 0)), "stun": int(d.get("stun", 0)),
		"flags": []}


static func is_boss(depth: int, enemies: Dictionary) -> bool:
	return depth % int(enemies.get("boss_every", 15)) == 0


static func is_elite(depth: int, enemies: Dictionary, ct: CombatTuning) -> bool:
	var el: Dictionary = enemies.get("elite", {})
	return not el.is_empty() and depth > ct.tutorial_depth and depth % int(el["every"]) == 0 and not is_boss(depth, enemies)


## Tier of a depth: 1, 2, 3 (data: tier_depths).
static func tier(depth: int, enemies: Dictionary) -> int:
	var td: Array = enemies.get("tier_depths", [1])
	var tr := 1
	for i in td.size():
		if depth >= int(td[i]):
			tr = i + 1
	return tr


## A regular enemy type for this depth: only types whose tiers include the depth's tier.
static func pick_type(depth: int, enemies: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var tr := tier(depth, enemies)
	# JSON numbers are floats: compare as ints (3 in [3.0] is false in GDScript)
	var pool: Array = (enemies["types"] as Array).filter(func(e): return (e.get("tiers", [1, 2, 3]) as Array).any(func(x): return int(x) == tr))
	if pool.is_empty():
		pool = enemies["types"]
	return pool[rng.randi() % pool.size()]


## Elite: stronger copy with one random modifier; returns [fighter, mod].
static func make_elite(e: Dictionary, enemies: Dictionary, rng: RandomNumberGenerator) -> Array:
	var el: Dictionary = enemies["elite"]
	var out := e.duplicate()
	out["hp"] *= float(el["hp"])
	out["max_hp"] = out["hp"]
	out["dmg"] *= float(el["dmg"])
	var mods: Array = el["mods"]
	var m: Dictionary = mods[rng.randi() % mods.size()]
	var k: String = m["stat"]
	if m.has("mult"):
		out[k] = float(out.get(k, 0.0)) * float(m["mult"])
	else:
		out[k] = float(out.get(k, 0.0)) + float(m["add"])
	return [out, m]


## Boss of this depth: 15 → first, 30 → second, … cycling; scaled like regular enemies × boss_mult.
static func boss_def(depth: int, enemies: Dictionary) -> Dictionary:
	var bosses: Array = enemies["bosses"]
	return bosses[(depth / int(enemies["boss_every"]) - 1) % bosses.size()]


static func boss_at(depth: int, enemies: Dictionary, ct: CombatTuning) -> Dictionary:
	var d := boss_def(depth, enemies)
	var e := enemy_at(d, depth, ct)
	var m: Dictionary = enemies["boss_mult"]
	e["hp"] *= float(m["hp"])
	e["max_hp"] = e["hp"]
	e["dmg"] *= float(m["dmg"])
	e["armor"] *= float(m["armor"])
	return e
