extends SceneTree
## Balance check: N runs of a simulated player on the real run rules (systems/run_rules.gd).
## greedy — equip if build power grows, else sell, heal below 50%;
## smart — also sharpens/melts into strong slots, heals before bosses, buys the best shop item.
## godot --headless --path . -s res://tools/balance_sim.gd -- [--runs=200] [--policy=greedy|smart] [--set=k:v,...] [--forge]
## Prints death-depth percentiles, run length, boss pass rates, relics, fight length by depth.

func _initialize() -> void:
	var runs := 200
	var policy := "greedy"
	var forge := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
		elif a.begins_with("--policy="):
			policy = a.get_slice("=", 1)
		elif a == "--forge":
			forge = true
	var ct: CombatTuning = (load("res://data/tuning/m03_combat.tres") as CombatTuning).duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):   # --set=depth_hp:0.14,heal_after_win:0.1
			for kv in a.get_slice("=", 1).split(","):
				ct.set(kv.get_slice(":", 0), float(kv.get_slice(":", 1)))
	var econ: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m01/economy.json"))
	var deaths := []
	var tutorial_deaths := 0
	var res_runs := 0
	var relics := []
	var boss_pass := {15: 0, 30: 0, 45: 0, 60: 0}
	var boss_seen := {15: 0, 30: 0, 45: 0, 60: 0}
	var run_secs := []
	var times := {}
	var boss_times := []
	var enrages := 0
	var fights := 0
	var coins_at := {5: [], 15: [], 30: []}
	var shop_buys := 0
	var sharpens := 0
	var shops := 0
	var killers := {}
	for r in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + r
		var rules := RunRules.new(ct, [], forge)
		var lo := Loadout.new(econ, {}, ct)
		var secs := 0.0
		var depth := 1
		var hp := -1.0
		var got_relics := 0
		while depth < 300:
			var hero := Combat.hero_from(lo.total_stats(), 0.0, ct, lo.flags())
			var maxhp: float = hero["max_hp"]
			hp = maxhp if hp < 0.0 else minf(hp, maxhp)
			hero["hp"] = hp
			var info := rules.enemy_for(depth, rng)
			var boss: bool = info["boss"]
			var elite: bool = info["elite"]
			if boss and depth in boss_seen:
				boss_seen[depth] += 1
			var c := rules.make_combat(hero, info["fighter"], boss, r * 1000 + depth)
			var evs := c.advance(1000.0)
			fights += 1
			if c.enraged:
				enrages += 1
			for ev in evs:
				if ev["kind"] == "steal":
					lo.coins = maxi(0, lo.coins - int(ev["amount"]))
				elif ev["kind"] == "coin":
					lo.coins += int(ev["amount"])
			secs += c.time + 4.0   # + rise, death, swipe
			if boss:
				boss_times.append(c.time)
			else:
				var b := depth / 10 * 10
				times[b] = times.get(b, []) + [c.time]
			if c.winner != "hero":
				if depth <= ct.tutorial_depth:
					tutorial_deaths += 1
				var kn := String(info["def"]["name"]) + (" (элита)" if elite else "") + " @" + str(depth / 10 * 10)
				killers[kn] = int(killers.get(kn, 0)) + 1
				break
			if boss and depth in boss_pass:
				boss_pass[depth] += 1
			hp = minf(maxhp, float(c.f["hero"]["hp"]) + maxhp * rules.heal_share(boss, float(hero["rest"])))
			lo.coins += rules.coins_for_win(depth, rng, float(hero["greed"]), boss, elite)
			if depth in coins_at:
				coins_at[depth].append(lo.coins)
			var every := int(rules.enemies["boss_every"])
			var pre_boss := (depth + 1) % every == 0
			var heal_at := 0.5 if policy == "greedy" else (0.9 if pre_boss else 0.6)
			for _i in 3:
				var hc := rules.heal_cost(depth + 1)
				if hp < maxhp * heal_at and lo.coins >= hc:
					lo.coins -= hc
					hp = minf(maxhp, hp + maxhp * float(rules.spend["heal"]["pct"]))
			var it := rules.drop(depth, rng, lo, boss, elite)
			if bool(it.get("unique", false)):
				got_relics += 1
			if lo.can_equip(it) and lo.power_if_equipped(it) > lo.power():
				lo.equip(it)
			elif policy == "melt":
				lo.melt(it)
			elif policy == "smart" and lo.power_if_melted(it) - lo.power() > 0.04 * lo.power():
				lo.melt(it)   # sharpening a strong slot beats a few coins
			else:
				lo.sell(it)
			if rules.shop_due(depth):
				shops += 1
				if policy == "smart":
					var best_it := {}
					var best_gain := 0.0
					for _k in int(rules.spend["shop"]["items"]):
						var s_it := rules.shop_item(depth + 1, rng, lo)
						var price := roundi(lo.sell_price(s_it) * float(rules.spend["shop"]["price_mult"]))
						var gain := lo.power_if_equipped(s_it) - lo.power()
						if lo.can_equip(s_it) and gain > best_gain and lo.coins - price >= rules.heal_cost(depth):
							best_gain = gain
							best_it = s_it
							best_it["price"] = price
					if not best_it.is_empty():
						lo.coins -= int(best_it["price"])
						lo.equip(best_it)
						shop_buys += 1
			if policy == "smart":   # spend the surplus over a heal reserve on the best sharpening
				for _s in 6:
					var reserve := rules.heal_cost(depth + 1) * 3
					var best_slot := ""
					var best_val := 0.0
					for sl in Loadout.SLOTS:
						if lo.equipped[sl].is_empty():
							continue
						var cost := rules.sharpen_cost(depth + 1, lo.rank[sl])
						if lo.coins - cost < reserve:
							continue
						var gain := lo.power_of_stats(lo.total_stats(sl, lo.equipped[sl], lo.mult(sl) + float(econ["melt_bonus"])), lo.flags()) - lo.power()
						if gain / cost > best_val:
							best_val = gain / cost
							best_slot = sl
					if best_slot == "":
						break
					lo.coins -= rules.sharpen_cost(depth + 1, lo.rank[best_slot])
					lo.rank[best_slot] += 1
					sharpens += 1
			depth += 1
		deaths.append(depth)
		relics.append(got_relics)
		for tg in lo.tag_counts().values():
			if lo.resonance_level(int(tg)) > 0:
				res_runs += 1
				break
		run_secs.append(secs)
	deaths.sort()
	var pct := func(p: float) -> int: return deaths[clampi(int(p * deaths.size()), 0, deaths.size() - 1)]
	print("policy=%s runs=%d forge=%s  death depth: p10=%d p25=%d median=%d p75=%d p90=%d max=%d" % [policy, runs, forge,
		pct.call(0.1), pct.call(0.25), pct.call(0.5), pct.call(0.75), pct.call(0.9), deaths[-1]])
	run_secs.sort()
	var avg := func(a: Array) -> float:
		var s := 0.0
		for x in a:
			s += float(x)
		return s / maxf(1.0, a.size())
	print("tutorial deaths: %d · run length median %.1f min (p90 %.1f) · relics found per run %.2f" % [tutorial_deaths,
		run_secs[run_secs.size() / 2] / 60.0, run_secs[int(run_secs.size() * 0.9)] / 60.0, avg.call(relics)])
	print("runs with an active resonance at death: %d%% · fights that hit enrage: %.1f%%" % [roundi(100.0 * res_runs / runs), 100.0 * enrages / maxf(1, fights)])
	var bl := "boss pass rate:"
	for d in boss_pass:
		bl += " %d → %d/%d" % [d, boss_pass[d], boss_seen[d]]
	print(bl)
	print("coins after win: d5 %.0f · d15 %.0f · d30 %.0f · shop buys %d/%d · sharpens/run %.1f · boss fight avg %.1f s" % [avg.call(coins_at[5]), avg.call(coins_at[15]), avg.call(coins_at[30]), shop_buys, shops, float(sharpens) / runs, avg.call(boss_times)])
	var keys := times.keys()
	keys.sort()
	var line := "fight seconds by depth: "
	for k in keys:
		var arr: Array = times[k]
		line += "%d-%d: %.1f  " % [k, k + 9, avg.call(arr)]
		if k >= 70:
			break
	print(line)
	var ks := killers.keys()
	ks.sort_custom(func(a, b): return killers[a] > killers[b])
	print("top killers: " + ", ".join(ks.slice(0, 8).map(func(k): return "%s %d" % [k, killers[k]])))
	quit(0)
