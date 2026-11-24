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
