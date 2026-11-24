extends GutTest

func _fight(seed_value: int) -> Combat:
	var t := CombatTuning.new()
	var hero := {"hp": 100.0, "max_hp": 100.0, "dmg": 20.0, "speed": 1.0, "armor": 20.0, "crit": 10.0, "block": 5.0, "vamp": 3.0}
	var enemy := {"hp": 90.0, "max_hp": 90.0, "dmg": 12.0, "speed": 0.8, "armor": 10.0, "crit": 0.0, "block": 0.0, "vamp": 0.0}
	var c := Combat.new(hero, enemy, t, seed_value)
	c.advance(60.0)
	return c


func test_armor_damage() -> void:
	assert_almost_eq(Formulas.armor_damage(100.0, 50.0, 100.0), 66.667, 0.01)
	assert_eq(Formulas.armor_damage(10.0, 0.0, 100.0), 10.0)


func test_deterministic() -> void:
	var a := _fight(42)
	var b := _fight(42)
	assert_true(a.over)
	assert_eq(a.winner, b.winner)
	assert_almost_eq(a.time, b.time, 0.0001)
	assert_almost_eq(a.f["hero"]["hp"], b.f["hero"]["hp"], 0.0001)


func test_fight_fits_budget() -> void:
	# stronger hero wins well under the 10 s budget
	var c := _fight(1)
	assert_eq(c.winner, "hero")
	assert_lt(c.time, 10.0)


func test_penetration_and_thorns() -> void:
	var t := CombatTuning.new()
	t.block_cap = 0.0
	var tank := {"hp": 1000.0, "max_hp": 1000.0, "dmg": 0.0, "speed": 0.1, "armor": 100.0, "crit": 0.0, "block": 0.0, "vamp": 0.0, "thorns": 50.0}
	var a := {"hp": 100.0, "max_hp": 100.0, "dmg": 10.0, "speed": 1.0, "armor": 0.0, "crit": 0.0, "block": 0.0, "vamp": 0.0, "pen": 50.0}
	var c := Combat.new(a, tank, t, 1)
	var evs := c.advance(0.5)   # first hero hit at 0.3 s
	var hit: Dictionary = evs.filter(func(e): return e["kind"] == "hit")[0]
	assert_almost_eq(float(hit["amount"]), 10.0 * 100.0 / 150.0, 0.01)   # 50% of armor ignored
	c.advance(2.0)
	assert_eq(c.winner, "enemy")   # 50 thorns per hit kill a 100 HP attacker on the 2nd hit


func test_resonance_levels() -> void:
	var lo := Loadout.new({"sell_base": [1, 1, 1, 1], "sell_per_ilvl": 0.0, "melt_bonus": 0.1}, {})
	for s in ["weapon", "helm", "armor"]:
		lo.equipped[s] = {"slot": s, "stats": {}, "tags": ["кровь"]}
	assert_eq(lo.resonance_level(int(lo.tag_counts()["кровь"])), 1)
	assert_almost_eq(float(lo.total_stats()["вампиризм"]), 3.0, 0.001)
