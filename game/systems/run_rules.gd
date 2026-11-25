class_name RunRules
## Rules of one run that both the game (run/run.gd) and the balance simulator use, so the
## simulator measures the real game: which enemy comes, rewards, drops, healing, vows.

var ct: CombatTuning
var enemies := {}
var loot := {}
var affixes := {}
var curses := {}
var spend := {}
var vows: Array = []         # chosen vow dicts (data/m08/meta.json)
var forge := false           # meta: Forge unlocks extra item types
var pity := 0                # drops since the last relic
var price_mult := 1.0


func _init(tuning: CombatTuning, vow_list: Array = [], forge_on := false) -> void:
	ct = tuning
	enemies = _j("res://data/m03/enemies.json")
	loot = _j("res://data/m03/loot.json")
	affixes = _j("res://data/m02/affixes.json")
	curses = _j("res://data/m05/curses.json")
	spend = _j("res://data/m06/spend.json")
	vows = vow_list
	forge = forge_on
	for v in vows:
		price_mult *= float(v.get("price", 1.0))


static func _j(p: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func vow_mult(key: String) -> float:
	var m := 1.0
	for v in vows:
		m *= float(v.get(key, 1.0))
	return m


func has_vow_flag(key: String) -> bool:
	return vows.any(func(v): return bool(v.get(key, false)))


func souls_share(base: float) -> float:
	var s := base
	for v in vows:
		s += float(v.get("souls", 0.0)) * base
	return s


## {def, fighter, boss, elite, mod} for this depth.
func enemy_for(depth: int, rng: RandomNumberGenerator) -> Dictionary:
	var boss := LoopMath.is_boss(depth, enemies)
	var d: Dictionary
	var e: Dictionary
	var mod := {}
	var elite := false
	if boss:
		d = LoopMath.boss_def(depth, enemies)
		e = LoopMath.boss_at(depth, enemies, ct)
	else:
		d = LoopMath.pick_type(depth, enemies, rng)
		e = LoopMath.enemy_at(d, depth, ct)
		if LoopMath.is_elite(depth, enemies, ct):
			var r := LoopMath.make_elite(e, enemies, rng)
			e = r[0]
			mod = r[1]
			elite = true
	e["hp"] *= vow_mult("enemy_hp")
	e["max_hp"] = e["hp"]
	e["dmg"] *= vow_mult("enemy_dmg")
	return {"def": d, "fighter": e, "boss": boss, "elite": elite, "mod": mod}


func time_limit(boss: bool) -> float:
	return ct.time_limit * (ct.boss_time_mult if boss else 1.0)


func make_combat(hero: Dictionary, foe: Dictionary, boss: bool, seed_value: int) -> Combat:
	var c := Combat.new(hero, foe, ct, seed_value)
	c.limit = time_limit(boss)
	var en: Dictionary = enemies.get("enrage", {})
	c.enrage_rate = float(en.get("rate", 0.25))
	c.hard_mult = float(en.get("hard_mult", 4.0))
	return c


func coins_for_win(depth: int, rng: RandomNumberGenerator, greed: float, boss: bool, elite: bool) -> int:
	var cr: Array = enemies["coins"]
	var m := 1.0
	if boss:
		m = float(enemies["boss_reward"]["coins_mult"])
	elif elite:
		m = float(enemies["elite"]["coins_mult"])
	return roundi((rng.randi_range(int(cr[0]), int(cr[1])) + depth * float(enemies.get("coins_per_depth", 1.0))) * (1.0 + greed / 100.0) * m)


## Share of max HP restored after a win (passive + "передышка" stat; bosses heal more).
func heal_share(boss: bool, rest: float) -> float:
	return (float(enemies["boss_reward"]["heal"]) if boss else ct.heal_after_win) + rest / 100.0


func min_rarity(boss: bool, elite: bool) -> int:
	if boss:
		return int(enemies["boss_reward"]["min_rarity"])
	if elite:
		return int(enemies["elite"]["min_rarity"])
	return 0


## A drop for this depth: pity for relics, tag bias towards the build, curses, Forge types.
func drop(depth: int, rng: RandomNumberGenerator, lo: Loadout, boss: bool, elite: bool) -> Dictionary:
	var st := lo.total_stats()
	var opts := {"bias_tag": lo.top_tag(), "pity": pity, "luck": maxf(0.0, float(st.get("удача", 0.0))), "forge": forge}
	var it := ItemGen.roll(depth, rng, loot, affixes, min_rarity(boss, elite), "", -1, opts)
	pity = 0 if int(it["rarity"]) == 3 else (pity + 1 if depth >= int(loot["rarity_min_depth"][3]) else pity)
	return ItemGen.maybe_curse(it, depth, rng, curses, boss)


func shop_item(depth: int, rng: RandomNumberGenerator, lo: Loadout) -> Dictionary:
	var opts := {"bias_tag": lo.top_tag(), "forge": forge}
	return ItemGen.roll(depth, rng, loot, affixes, int(spend["shop"]["min_rarity"]), "", -1, opts)


func reroll(item: Dictionary, depth: int, rng: RandomNumberGenerator) -> Dictionary:
	# reroll keeps type, rarity and tags: only the numbers change (tags are the build's spine)
	var opts := {"tags": (item.get("tags", []) as Array).duplicate(), "forge": true}
	var out := ItemGen.roll(depth, rng, loot, affixes, 0, String(item.get("type", "")), int(item["rarity"]), opts)
	if bool(item.get("cursed", false)):
		out = ItemGen.curse(out, depth, rng, curses)
	return out


func heal_cost(depth: int) -> int:
	return roundi(Formulas.heal_cost(depth, spend["heal"]) * price_mult)


func reroll_cost(depth: int, uses: int) -> int:
	return Formulas.reroll_cost(depth, uses, spend["reroll"])


func sharpen_cost(depth: int, rank: int) -> int:
	return roundi(Formulas.sharpen_cost(depth, rank, spend["sharpen"]) * price_mult)


func shop_due(won_depth: int) -> bool:
	return not has_vow_flag("no_shop") and won_depth % int(spend["shop"]["every"]) == 0
