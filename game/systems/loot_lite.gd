class_name LootLite
## Temporary item generator for the loop gym (M02 replaces it): item type (fixed profile) + rarity
## (gated by depth, rare) + one extra affix per rarity step + tags. Attack speed lives only on weapons.


static func roll(depth: int, rng: RandomNumberGenerator, d: Dictionary, depth_loot: float) -> Dictionary:
	var types: Array = d["types"]
	var base: Dictionary = types[rng.randi() % types.size()]
	var w: Array = d["rarity_weights"].duplicate()
	var min_d: Array = d["rarity_min_depth"]
	for i in w.size():
		w[i] = 0.0 if depth < int(min_d[i]) else float(w[i]) * (1.0 + float(d["rarity_depth_shift"]) * depth * i)
	var r := _weighted(w, rng)
	var lvl := 1.0 + depth_loot * (depth - 1)
	var mult := float(d["rarity_mult"][r]) * lvl
	var stats := {}
	for k in base["stats"]:
		var v := float(base["stats"][k])
		if k == "скорость":
			stats[k] = snappedf(v * rng.randf_range(0.95, 1.05), 0.01)   # weapon speed does not scale
		elif v < 0.0:
			stats[k] = v   # penalties stay fixed
		else:
			stats[k] = roundf(v * mult * rng.randf_range(0.9, 1.1))
	var aff: Dictionary = d["affixes"]
	var keys := aff.keys()
	for i in r:
		var k: String = keys[rng.randi() % keys.size()]
		stats[k] = roundf(float(stats.get(k, 0.0)) + float(aff[k]) * lvl * rng.randf_range(0.8, 1.3))
	var tags := []
	var pool: Array = d["tags"]
	for i in rng.randi_range(0, 2):
		var tg: String = pool[rng.randi() % pool.size()]
		if tg not in tags:
			tags.append(tg)
	var nm: String = base["name"]
	if r >= 1:
		var sfx: Array = d["suffix"]
		nm += " " + sfx[rng.randi() % sfx.size()]
	return {"id": "L%d_%d" % [depth, rng.randi() % 100000], "slot": base["slot"], "name": nm, "rarity": r,
		"ilvl": depth, "tags": tags, "stats": stats}


static func _weighted(w: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for x in w:
		total += float(x)
	var p := rng.randf() * total
	for i in w.size():
		p -= float(w[i])
		if p <= 0.0 and float(w[i]) > 0.0:
			return i
	return 0
