class_name LoopMath
## Enemy scaling by depth (shared by the loop gym and the balance simulator).


static func enemy_at(d: Dictionary, depth: int, ct: CombatTuning) -> Dictionary:
	var mh := pow(1.0 + ct.depth_hp, depth - 1)
	var md := pow(1.0 + ct.depth_dmg, depth - 1)
	return {"hp": float(d["hp"]) * mh, "max_hp": float(d["hp"]) * mh, "dmg": float(d["dmg"]) * md,
		"speed": float(d["speed"]), "armor": float(d["armor"]) * md, "crit": float(d["crit"]),
		"block": float(d["block"]), "vamp": float(d["vamp"])}
