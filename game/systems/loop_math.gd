class_name LoopMath
## Enemy scaling by depth (shared by the loop gym and the balance simulator).


static func enemy_at(d: Dictionary, depth: int, ct: CombatTuning) -> Dictionary:
	# tutorial: the first enemies are weak and do not grow; growth starts after them
	var grow := maxi(0, depth - ct.tutorial_depth - 1)
	var ramp := clampf(float(depth - ct.tutorial_depth) / maxf(1.0, ct.ramp_depths), 0.0, 1.0)
	var early := lerpf(ct.tutorial_mult, 1.0, ramp)
	var mh := pow(1.0 + ct.depth_hp, grow) * early
	var md := pow(1.0 + ct.depth_dmg, grow) * early
	return {"hp": float(d["hp"]) * mh, "max_hp": float(d["hp"]) * mh, "dmg": float(d["dmg"]) * md,
		"speed": float(d["speed"]), "armor": float(d["armor"]) * md, "crit": float(d["crit"]),
		"block": float(d["block"]), "vamp": float(d["vamp"])}


static func is_boss(depth: int, enemies: Dictionary) -> bool:
	return depth % int(enemies.get("boss_every", 15)) == 0


## Boss of this depth: 15 → first, 30 → second, … cycling; scaled like regular enemies × boss_mult.
static func boss_at(depth: int, enemies: Dictionary, ct: CombatTuning) -> Dictionary:
	var bosses: Array = enemies["bosses"]
	var i := (depth / int(enemies["boss_every"]) - 1) % bosses.size()
	var d: Dictionary = bosses[i]
	var e := enemy_at(d, depth, ct)
	var m: Dictionary = enemies["boss_mult"]
	e["hp"] *= float(m["hp"])
	e["max_hp"] = e["hp"]
	e["dmg"] *= float(m["dmg"])
	e["armor"] *= float(m["armor"])
	e["regen"] = float(d.get("regen", 0.0)) * (1.0 + ct.depth_dmg * depth)
	e["thorns"] = float(d.get("thorns", 0.0)) * (1.0 + ct.depth_dmg * depth)
	return e
