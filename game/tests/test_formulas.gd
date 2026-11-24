extends GutTest

func test_swipe_decision() -> void:
	assert_eq(Formulas.swipe_decision(-200.0, 150.0), -1)
	assert_eq(Formulas.swipe_decision(40.0, 150.0), 0)
	assert_eq(Formulas.swipe_decision(150.0, 150.0), 1)
