class_name ItemGen
## M02 item generator: type (fixed profile) + rarity (gated by depth) + affixes allowed for the slot
## (one per stat) + 0–2 tags. Flat stats grow +8%/depth, percent stats +3%/depth.


static func roll(depth: int, rng: RandomNumberGenerator, loot: Dictionary, aff: Dictionary) -> Dictionary:
	var types: Array = loot["types"]
	var base: Dictionary = types[rng.randi() % types.size()]
	var r := _rarity(depth, rng, loot)
	var pct: Array = aff["pct_stats"]
	var flat_k := 1.0 + float(aff["flat_growth"]) * (depth - 1)
	var pct_k := 1.0 + float(aff["pct_growth"]) * (depth - 1)
	var stats := {}
	for k in base["stats"]:
		var v := float(base["stats"][k])
		if k == "скорость":
			stats[k] = snappedf(v * rng.randf_range(0.95, 1.05), 0.01)
		elif v < 0.0:
			stats[k] = v
		else:
			stats[k] = roundf(v * (pct_k if k in pct else flat_k) * rng.randf_range(0.9, 1.1))
	var cnt: Array = aff["affix_count"][r]
	var n := rng.randi_range(int(cnt[0]), int(cnt[1]))
	var slot: String = base["slot"]
	var pool: Array = (aff["affixes"] as Array).filter(func(a): return slot in a["slots"])
	var picked := []
	for i in n:
		if pool.is_empty():
			break
		var a: Dictionary = pool.pop_at(rng.randi() % pool.size())
		picked.append(a)
		var k: String = a["stat"]
		var v := float(a["v"]) * (pct_k if k in pct else flat_k) * rng.randf_range(0.8, 1.25)
		if r == 3:
			v *= float(aff["legend_mult"])
		stats[k] = float(stats.get(k, 0.0)) + (snappedf(v, 0.1) if k == "регенерация" else roundf(maxf(1.0, v)))
	var tags := []
	var tpool: Array = loot["tags"]
	for i in rng.randi_range(0, 2):
		var tg: String = tpool[rng.randi() % tpool.size()]
		if tg not in tags:
			tags.append(tg)
	var nm: String = base["name"]
	if r == 1 and not picked.is_empty():
		nm += " " + String(picked[0]["word"])
	elif r >= 2:
		var f: Array = aff["rare_first"]
		var s: Array = aff["rare_second"]
		nm = "%s %s" % [f[rng.randi() % f.size()], s[rng.randi() % s.size()]]
	return {"id": "I%d_%d" % [depth, rng.randi() % 1000000], "slot": slot, "type": base["name"], "name": nm,
		"rarity": r, "ilvl": depth, "tags": tags, "stats": stats}


static func _rarity(depth: int, rng: RandomNumberGenerator, d: Dictionary) -> int:
	var w: Array = d["rarity_weights"].duplicate()
	var min_d: Array = d["rarity_min_depth"]
	var total := 0.0
	for i in w.size():
		w[i] = 0.0 if depth < int(min_d[i]) else float(w[i]) * (1.0 + float(d["rarity_depth_shift"]) * depth * i)
		total += w[i]
	var p := rng.randf() * total
	for i in w.size():
		p -= w[i]
		if p <= 0.0 and w[i] > 0.0:
			return i
	return 0
