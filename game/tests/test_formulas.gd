extends GutTest

func test_swipe_decision() -> void:
	assert_eq(Formulas.swipe_decision(-200.0, 150.0), -1)
	assert_eq(Formulas.swipe_decision(40.0, 150.0), 0)
	assert_eq(Formulas.swipe_decision(150.0, 150.0), 1)


func test_sell_price() -> void:
	assert_eq(Formulas.sell_price(0, 1, [6, 14, 30, 70], 0.1), 7)
	assert_eq(Formulas.sell_price(3, 10, [6, 14, 30, 70], 0.1), 140)


func test_dps_ehp_power() -> void:
	assert_almost_eq(Formulas.dps(10.0, 2.0, 50.0, 2.0), 30.0, 0.001)
	assert_almost_eq(Formulas.ehp(100.0, 100.0, 0.0, 100.0, 60.0), 200.0, 0.001)
	assert_almost_eq(Formulas.power(16.0, 100.0), 40.0, 0.001)


func test_axe_slower_than_sword() -> void:
	# item logic: weapon speed is the weapon's own, sharpening never speeds it up
	var axe := {"stats": {"урон": 19, "скорость": 0.85}}
	var sword := {"stats": {"урон": 13, "скорость": 1.1}}
	assert_lt(float(Loadout.scaled(axe, 1.5)["скорость"]), float(Loadout.scaled(sword, 1.0)["скорость"]))


func test_swipe_rules() -> void:
	var t := SwipeTuning.new()
	assert_eq(Swipe.decide(Vector2(200, 10), Vector2.ZERO, t), Swipe.EQUIP)
	assert_eq(Swipe.decide(Vector2(-60, 0), Vector2(-1500, 0), t), Swipe.SELL)   # flick commits early
	assert_eq(Swipe.decide(Vector2(20, -200), Vector2.ZERO, t), Swipe.MELT)
	assert_eq(Swipe.decide(Vector2(100, 0), Vector2.ZERO, t), Swipe.NONE)
	t.melt_enabled = 0.0
	assert_ne(Swipe.decide(Vector2(20, -200), Vector2.ZERO, t), Swipe.MELT)


func test_spend_prices_escalate() -> void:
	var c := {"base": 4, "per_depth": 0.8, "per_use": 3}
	assert_eq(Formulas.reroll_cost(10, 0, c), 12)
	assert_eq(Formulas.reroll_cost(10, 2, c), 18)
	assert_eq(Formulas.sharpen_cost(10, 1, {"base": 12, "per_rank": 10, "per_depth": 0.5}), 27)
	assert_eq(Formulas.heal_cost(10, {"base": 6, "per_depth": 1.2}), 18)


func test_boss_every_15() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/enemies.json"))
	var ct := CombatTuning.new()
	assert_true(LoopMath.is_boss(15, en))
	assert_false(LoopMath.is_boss(14, en))
	var b := LoopMath.boss_at(15, en, ct)
	var n := LoopMath.enemy_at(en["bosses"][0], 15, ct)
	assert_almost_eq(float(b["hp"]), float(n["hp"]) * float(en["boss_mult"]["hp"]), 0.01)
