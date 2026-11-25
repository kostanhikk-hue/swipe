extends GutTest
## Logic that silently breaks the game: sharpening, curses, combat stats, drops, tiers, economy, saves.

const ECON := {"sell_base": [10, 20, 40, 80], "sell_per_ilvl": 0.0, "melt_bonus": 0.1, "trade_in": 0.5}


func _lo() -> Loadout:
	return Loadout.new(ECON, {})


func _fighter(extra := {}) -> Dictionary:
	var f := {"hp": 100.0, "max_hp": 100.0, "dmg": 10.0, "speed": 1.0, "armor": 0.0, "crit": 0.0, "block": 0.0, "vamp": 0.0}
	f.merge(extra, true)
	return f


func test_sharpening_keeps_drawbacks_of_normal_items() -> void:
	var lo := _lo()
	lo.equip({"slot": "shield", "rarity": 0, "stats": {"блок": 16.0, "проворство": -6.0}})
	lo.rank["shield"] = 5
	var st := lo.slot_stats("shield")
	assert_almost_eq(float(st["блок"]), 24.0, 0.01)
	assert_almost_eq(float(st["проворство"]), -6.0, 0.01, "a normal item's minus must not grow")


func test_sharpening_grows_curses() -> void:
	var lo := _lo()
	lo.equip({"slot": "boots", "rarity": 2, "cursed": true, "stats": {"броня": 10.0, "уязвимость": 15.0, "жизнь": -30.0}})
	lo.rank["boots"] = 2
	var st := lo.slot_stats("boots")
	assert_almost_eq(float(st["жизнь"]), -36.0, 0.01)
	assert_almost_eq(float(st["уязвимость"]), 18.0, 0.01)


func test_negative_chance_stats_are_clamped_everywhere() -> void:
	var ct := CombatTuning.new()
	var a := Combat.hero_from({"блок": -17.0, "крит": -5.0, "урон": -50.0}, 100.0, ct)
	assert_eq(float(a["block"]), 0.0)
	assert_eq(float(a["crit"]), 0.0)
	assert_eq(float(a["dmg"]), 1.0, "damage never goes below 1 (a hit never heals)")
	var b := Combat.hero_from({}, 100.0, ct)
	assert_almost_eq(Formulas.build_power(a, ct), Formulas.build_power(Combat.hero_from({"урон": -50.0}, 100.0, ct), ct), 0.001)
	assert_lt(Formulas.build_power(a, ct), Formulas.build_power(b, ct))


func test_vulnerability_increases_damage_taken() -> void:
	var t := CombatTuning.new()
	var c := Combat.new(_fighter({"speed": 0.01, "vuln": 50.0}), _fighter({"dmg": 20.0}), t, 1)
	c.advance(0.8)   # enemy first hit at 0.7 s
	assert_almost_eq(float(c.f["hero"]["hp"]), 70.0, 0.01)


func test_enrage_instead_of_timeout() -> void:
	var t := CombatTuning.new()
	t.time_limit = 5.0
	t.block_cap = 0.0
	var tank := {"hp": 10000.0, "max_hp": 10000.0, "dmg": 1.0, "speed": 1.0, "armor": 0.0, "crit": 0.0, "block": 0.0, "vamp": 0.0}
	var c := Combat.new(_fighter({"dmg": 1.0, "hp": 500.0, "max_hp": 500.0}), tank, t, 1)
	var evs := c.advance(5.5)
	assert_false(c.over, "no loss at the limit")
	assert_true(evs.any(func(e): return e["kind"] == "enrage"))
	c.advance(200.0)
	assert_true(c.over)
	assert_eq(c.winner, "enemy")


func test_poison_and_riposte_and_third_crit() -> void:
	var t := CombatTuning.new()
	t.block_cap = 100.0
	var c := Combat.new(_fighter({"poison": 100.0}), _fighter({"speed": 0.01, "dmg": 0.0}), t, 3)
	c.advance(0.35)   # one hit for 10, poison starts burning right away
	assert_between(float(c.f["enemy"]["hp"]), 89.0, 90.0)
	c.advance(3.5)
	assert_lt(float(c.f["enemy"]["hp"]), 85.0, "poison keeps burning")
	var r := Combat.new(_fighter({"block": 100.0, "riposte": 50.0, "speed": 0.01}), _fighter({"dmg": 10.0}), t, 1)
	var evs := r.advance(0.8)
	assert_true(evs.any(func(e): return e["kind"] == "riposte" and is_equal_approx(float(e["amount"]), 5.0)))
	t.block_cap = 0.0
	var k := Combat.new(_fighter({"flags": ["third_crit"]}), _fighter({"hp": 1000.0, "max_hp": 1000.0, "speed": 0.01}), t, 1)
	var kinds := k.advance(3.0).filter(func(e): return e["src"] == "hero" and e["kind"] in ["hit", "crit"]).map(func(e): return e["kind"])
	assert_eq(kinds.slice(0, 3), ["hit", "hit", "crit"])


func test_trade_in_and_ring_choice() -> void:
	var lo := _lo()
	lo.equip({"slot": "helm", "rarity": 1, "ilvl": 1, "stats": {}})
	assert_eq(lo.coins, 0)
	lo.equip({"slot": "helm", "rarity": 0, "ilvl": 1, "stats": {}})
	assert_eq(lo.coins, 10, "the replaced magic helm brings 50% of 20")
	lo.equip({"slot": "ring", "name": "a", "rarity": 0, "stats": {"урон": 5.0}})
	lo.equip({"slot": "ring", "name": "b", "rarity": 0, "stats": {"урон": 1.0}})
	lo.ring_pick = "ring1"
	assert_eq(lo.target_slot({"slot": "ring"}), "ring1")
	lo.ring_pick = "ring2"
	assert_eq(lo.target_slot({"slot": "ring"}), "ring2")


func test_reroll_keeps_tags_and_curse_and_relics_have_effects() -> void:
	var ct := CombatTuning.new()
	var rules := RunRules.new(ct)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var it := ItemGen.roll(12, rng, rules.loot, rules.affixes, 2, "Меч", 2, {"tags": ["сталь", "ночь"]})
	it = ItemGen.curse(it, 12, rng, rules.curses)
	var rr := rules.reroll(it, 12, rng)
	assert_eq(rr["tags"], ["сталь", "ночь"])
	assert_true(bool(rr.get("cursed", false)), "reroll must not wash a curse away")
	for i in 20:
		var leg := ItemGen.roll(20, rng, rules.loot, rules.affixes, 3)
		assert_true(bool(leg.get("unique", false)))
		assert_ne(String(leg.get("effect", "")), "")


func test_pity_and_forge_and_tiers() -> void:
	var rules := RunRules.new(CombatTuning.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var lo_c := 0
	var hi_c := 0
	for i in 400:
		lo_c += int(ItemGen._rarity(20, rng, rules.loot, 0) == 3)
		hi_c += int(ItemGen._rarity(20, rng, rules.loot, 40) == 3)
	assert_gt(hi_c, lo_c * 2, "pity raises the relic chance")
	for i in 200:
		var it := ItemGen.roll(10, rng, rules.loot, rules.affixes)
		assert_false(it["type"] in ["Копьё", "Цеп", "Перевязь", "Латные рукавицы", "Кольцо с шипом"], "Forge types are locked")
	for d in [1, 7, 14]:
		for i in 30:
			var e := LoopMath.pick_type(d, rules.enemies, rng)
			assert_true(e["id"] in ["ghoul", "guardian", "archer"], "tier 1 only before depth 16")


func test_sharpen_cost_is_quadratic_and_elites() -> void:
	var c := {"base": 14, "per_rank": 12, "per_rank2": 4, "per_depth": 0.0}
	assert_eq(Formulas.sharpen_cost(0, 0, c), 14)
	assert_eq(Formulas.sharpen_cost(0, 5, c), 14 + 60 + 100)
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/enemies.json"))
	var ct := CombatTuning.new()
	assert_false(LoopMath.is_elite(5, en, ct), "no elite in the tutorial")
	assert_true(LoopMath.is_elite(10, en, ct))
	assert_false(LoopMath.is_elite(15, en, ct), "a boss depth is not an elite")


func test_save_v2_to_v3() -> void:
	var d := Save._migrate({"schema": 2, "best_depth": 30, "souls": 5, "runs": 3, "upgrades": {"omen": 1, "speed": 2}})
	assert_eq(int(d["schema"]), 3)
	assert_eq(int(d["souls"]), 45, "the omen became free: its 40 souls come back")
	assert_false(d["upgrades"].has("omen"))
	assert_eq(int(d["upgrades"]["speed"]), 2)
	assert_eq(d["settings"]["music"], Save.SETTINGS["music"])
	assert_eq(d["seen"], [])
	var fresh := Save._migrate({"schema": 3, "best_depth": 0})
	assert_eq(int(fresh["runs"]), 0)
	assert_eq(int(fresh["souls"]), 0)
