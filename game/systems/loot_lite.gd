class_name LootLite
## Temporary item generator for the loop gym (M02 replaces it): base + rarity + extra stats + tags.


static func roll(depth: int, rng: RandomNumberGenerator, d: Dictionary, depth_loot: float) -> Dictionary:
	var bases: Array = d["bases"]
	var base: Dictionary = bases[rng.randi() % bases.size()]
	var w: Array = d["rarity_weights"].duplicate()
	for i in range(1, w.size()):
		w[i] = float(w[i]) * (1.0 + float(d["rarity_depth_shift"]) * depth * 0.1 * i)
	var r := _weighted(w, rng)
	var mult := float(d["rarity_mult"][r]) * (1.0 + depth_loot * depth)
	var stats := {}
	for k in base["stats"]:
		stats[k] = _rnd(float(base["stats"][k]) * mult * rng.randf_range(0.85, 1.15), k)
	var extra: Dictionary = d["extra_stats"]
	var keys := extra.keys()
	for i in r:
		var k: String = keys[rng.randi() % keys.size()]
		stats[k] = _rnd(float(stats.get(k, 0.0)) + float(extra[k]) * (1.0 + depth_loot * depth) * rng.randf_range(0.8, 1.3), k)
	var tags := []
	var pool: Array = d["tags"]
	for i in rng.randi_range(0, 2):
		var tg: String = pool[rng.randi() % pool.size()]
		if tg not in tags:
			tags.append(tg)
	var names: Array = base["name"]
	var nm: String = names[rng.randi() % names.size()]
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
		if p <= 0.0:
			return i
	return w.size() - 1


static func _rnd(v: float, stat: String) -> float:
	return snappedf(v, 0.01) if stat == "скорость" else roundf(v)
