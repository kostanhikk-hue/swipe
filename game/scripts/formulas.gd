class_name Formulas
## Pure functions: combat and economy formulas live here (tested by GUT).

## Swipe decision from horizontal drag offset: -1 sell, +1 equip, 0 undecided.
static func swipe_decision(offset_x: float, threshold: float) -> int:
	if offset_x <= -threshold:
		return -1
	if offset_x >= threshold:
		return 1
	return 0
