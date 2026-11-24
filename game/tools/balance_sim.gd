extends SceneTree
## Balance check: N runs of a greedy player (equip if build power grows, else sell).
## godot --headless --path . -s res://tools/balance_sim.gd -- [--runs=200] [--policy=greedy|melt]
## Prints death-depth percentiles and fight length by depth.

func _initialize() -> void:
	var runs := 200
	var policy := "greedy"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
		elif a.begins_with("--policy="):
			policy = a.get_slice("=", 1)
	var ct: CombatTuning = (load("res://data/tuning/m03_combat.tres") as CombatTuning).duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):   # --set=depth_hp:0.14,heal_after_win:0.1
			for kv in a.get_slice("=", 1).split(","):
				ct.set(kv.get_slice(":", 0), float(kv.get_slice(":", 1)))
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m01/items.json"))
	var econ: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m01/economy.json"))
	var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/enemies.json"))
	var loot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/loot.json"))
	var deaths := []
	var times := {}
	for r in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + r
		var lo := Loadout.new(econ, items["start"])
		var depth := 1
		var hp := -1.0
		while depth < 200:
			var stats := {}
			for s in Loadout.SLOTS:
				var st := lo.slot_stats(s)
				for k in st:
					stats[k] = float(stats.get(k, 0.0)) + st[k]
			var maxhp := ct.hero_base_hp + float(stats.get("жизнь", 0.0))
			if hp < 0.0:
				hp = maxhp
			var types: Array = enemies["types"]
			var d: Dictionary = types[rng.randi() % types.size()]
			var e := LoopMath.enemy_at(d, depth, ct)
			var c := Combat.new(Combat.hero_from(stats, minf(hp, maxhp), ct), e, ct, r * 1000 + depth)
			c.advance(120.0)
			var b := depth / 5 * 5
			times[b] = times.get(b, []) + [c.time]
			if c.winner != "hero":
				break
			hp = minf(maxhp, float(c.f["hero"]["hp"]) + maxhp * ct.heal_after_win)
			var it := LootLite.roll(depth, rng, loot, ct.depth_loot)
			if lo.power_if_equipped(it) > lo.power():
				lo.equip(it)
			elif policy == "melt":
				lo.melt(it)
			else:
				lo.sell(it)
			depth += 1
		deaths.append(depth)
	deaths.sort()
	var pct := func(p: float) -> int: return deaths[clampi(int(p * deaths.size()), 0, deaths.size() - 1)]
	print("policy=%s runs=%d  death depth: p10=%d p25=%d median=%d p75=%d p90=%d max=%d" % [policy, runs,
		pct.call(0.1), pct.call(0.25), pct.call(0.5), pct.call(0.75), pct.call(0.9), deaths[-1]])
	var keys := times.keys()
	keys.sort()
	var line := "fight seconds by depth: "
	for k in keys:
		var arr: Array = times[k]
		var s := 0.0
		for x in arr:
			s += float(x)
		line += "%d-%d: %.1f  " % [k, k + 4, s / arr.size()]
		if k >= 40:
			break
	print(line)
	quit(0)
