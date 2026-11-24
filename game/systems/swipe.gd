class_name Swipe
## M01 swipe rules: which decision a drag or a fling means. Pure functions.

enum { NONE, SELL, EQUIP, MELT }


## Decision on release: distance OR fling speed, in the dominant direction.
static func decide(offset: Vector2, velocity: Vector2, t: SwipeTuning) -> int:
	var dir := direction(offset, velocity, t)
	match dir:
		MELT:
			return MELT if -offset.y >= t.threshold_up or -velocity.y >= t.fling_speed else NONE
		EQUIP:
			return EQUIP if offset.x >= t.threshold_x or velocity.x >= t.fling_speed else NONE
		SELL:
			return SELL if -offset.x >= t.threshold_x or -velocity.x >= t.fling_speed else NONE
	return NONE


## Which way the card leans (for the stamp and the preview), ignoring thresholds.
static func direction(offset: Vector2, velocity: Vector2, t: SwipeTuning) -> int:
	var v := offset + velocity * 0.1
	if v.length() < 4.0:
		return NONE
	if t.melt_enabled > 0.5 and v.y < 0.0 and -v.y > absf(v.x):
		return MELT
	return EQUIP if v.x > 0.0 else SELL


## 0..1 progress toward the commit threshold in the leaning direction.
static func progress(offset: Vector2, t: SwipeTuning) -> float:
	match direction(offset, Vector2.ZERO, t):
		MELT:
			return clampf(-offset.y / t.threshold_up, 0.0, 1.0)
		EQUIP, SELL:
			return clampf(absf(offset.x) / t.threshold_x, 0.0, 1.0)
	return 0.0
