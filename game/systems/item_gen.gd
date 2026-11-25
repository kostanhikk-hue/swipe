class_name ItemGen
## M02 item generator: type (fixed profile) + rarity (gated by depth) + affixes allowed for the slot
## (one per stat) + 0–2 tags. Flat stats grow +8%/depth, percent stats +3%/depth.
## Legendary = a relic: a named unique base with an effect (data: loot.uniques) + 5 affixes ×1.3.
## opts: bias_tag (build's main tag), tags (keep these tags — reroll), pity (drops since a relic),
## luck (% rarer), forge (allow Forge types).


static func roll(depth: int, rng: RandomNumberGenerator, loot: Dictionary, aff: Dictionary, min_rarity := 0,
		force_type := "", force_rarity := -1, opts := {}) -> Dictionary:
	var forge := bool(opts.get("forge", false))
	var types: Array = (loot["types"] as Array).filter(func(t): return forge or not bool(t.get("forge", false)))
	var r := maxi(min_rarity, _rarity(depth, rng, loot, int(opts.get("pity", 0)), float(opts.get("luck", 0.0)))) if force_rarity < 0 else force_rarity
	var base: Dictionary = types[rng.randi() % types.size()]
	var unique := {}
	for u in loot.get("uniques", []):
		if u["name"] == force_type:
			unique = u
	if force_type != "" and unique.is_empty():
		for ty in loot["types"]:
			if ty["name"] == force_type:
				base = ty
	if r == 3 and unique.is_empty() and force_type == "" and not (loot.get("uniques", []) as Array).is_empty():
		var us: Array = loot["uniques"]
		unique = us[rng.randi() % us.size()]
	if not unique.is_empty():
		base = unique
		r = 3
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
		elif k == "регенерация":
			stats[k] = snappedf(v * flat_k * rng.randf_range(0.9, 1.1), 0.1)
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
	var tags: Array = (opts["tags"] as Array).duplicate() if opts.has("tags") else _tags(rng, loot, String(opts.get("bias_tag", "")))
	var nm: String = base["name"]
	if unique.is_empty():
		if r == 1 and not picked.is_empty():
			nm += " " + String(picked[0]["word"])
		elif r >= 2:
			var f: Array = aff["rare_first"]
			var s: Array = aff["rare_second"]
			nm = "%s %s" % [f[rng.randi() % f.size()], s[rng.randi() % s.size()]]
	var it := {"id": "I%d_%d" % [depth, rng.randi() % 1000000], "slot": slot, "type": base["name"], "name": nm,
		"rarity": r, "ilvl": depth, "tags": tags, "stats": stats}
	if not unique.is_empty():
		it["unique"] = true
		it["effect"] = unique["effect"]
		it["flags"] = (unique.get("flags", []) as Array).duplicate()
	return it


static func _tags(rng: RandomNumberGenerator, loot: Dictionary, bias: String) -> Array:
	var tags := []
	var tpool: Array = loot["tags"]
	for i in rng.randi_range(0, 2):
		var tg: String = tpool[rng.randi() % tpool.size()]
		if i == 0 and bias != "" and rng.randf() < float(loot.get("tag_bias", 0.0)):
			tg = bias
		if tg not in tags:
			tags.append(tg)
	return tags


## pity: drops since the last relic → legendary weight +legend_pity% each; luck: % to rarer tiers.
static func _rarity(depth: int, rng: RandomNumberGenerator, d: Dictionary, pity := 0, luck := 0.0) -> int:
	var w: Array = d["rarity_weights"].duplicate()
	var min_d: Array = d["rarity_min_depth"]
	var total := 0.0
	for i in w.size():
		w[i] = 0.0 if depth < int(min_d[i]) else float(w[i]) * (1.0 + float(d["rarity_depth_shift"]) * depth * i) * (1.0 + luck / 100.0 * i)
		if i == 3 and w[i] > 0.0:
			w[i] += pity * float(d.get("legend_pity", 0.0))
		total += w[i]
	var p := rng.randf() * total
	for i in w.size():
		p -= w[i]
		if p <= 0.0 and w[i] > 0.0:
			return i
	return 0


## M05: maybe turn the item into a cursed relic: positives ×boost, one curse (negative stat), rarity ≥ min.
static func maybe_curse(it: Dictionary, depth: int, rng: RandomNumberGenerator, c: Dictionary, boss := false) -> Dictionary:
	if bool(it.get("unique", false)):
		return it   # relics already carry their own twist
	var chance := float(c["boss_chance"]) if boss else (float(c["chance"]) if depth >= int(c["min_depth"]) else 0.0)
	if rng.randf() >= chance:
		return it
	return curse(it, depth, rng, c)


static func curse(it: Dictionary, depth: int, rng: RandomNumberGenerator, c: Dictionary) -> Dictionary:
	var out := it.duplicate(true)
	out["rarity"] = maxi(int(out["rarity"]), int(c["min_rarity"]))
	for k in out["stats"]:
		var v := float(out["stats"][k])
		if v > 0.0 and k != "скорость":
			out["stats"][k] = snappedf(v * float(c["boost"]), 0.1) if k == "регенерация" else roundf(v * float(c["boost"]))
	var cs: Array = c["curses"]
	var cu: Dictionary = cs[rng.randi() % cs.size()]
	var g := 1.0 + float(c["flat_growth"]) * (depth - 1)
	var cv := float(cu["v"]) * (g if cu["stat"] in ["броня", "урон", "жизнь", "регенерация"] else 1.0)
	cv = snappedf(cv, 0.1) if cu["stat"] == "регенерация" else roundf(cv)
	out["stats"][cu["stat"]] = float(out["stats"].get(cu["stat"], 0.0)) + cv
	out["cursed"] = true
	out["curse"] = cu["name"]
	return out
