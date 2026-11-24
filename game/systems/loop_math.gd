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
