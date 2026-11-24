class_name Combat
extends RefCounted
## M03 auto-battle: deterministic real-time simulation on a fixed step. Emits event dicts:
## {t, kind: hit|crit|block|heal|death|timeout, src: hero|enemy, amount}

const STEP := 0.05

var t: CombatTuning
var rng := RandomNumberGenerator.new()
var time := 0.0
var over := false
var winner := ""
var f := {}   # side -> {hp, max_hp, dmg, speed, armor, crit, block, vamp, cd}


func _init(hero: Dictionary, enemy: Dictionary, tuning: CombatTuning, seed_value: int) -> void:
	t = tuning
	rng.seed = seed_value
	f["hero"] = hero.duplicate()
	f["enemy"] = enemy.duplicate()
	f["hero"]["cd"] = t.hero_first_delay
	f["enemy"]["cd"] = t.enemy_first_delay


## Hero fighter from summed item stats (Russian stat keys as in data).
static func hero_from(stats: Dictionary, hp: float, tuning: CombatTuning) -> Dictionary:
	return {"hp": hp, "max_hp": tuning.hero_base_hp + float(stats.get("жизнь", 0.0)),
		"dmg": tuning.hero_base_dmg + float(stats.get("урон", 0.0)), "speed": maxf(0.2, float(stats.get("скорость", 0.6))),
		"armor": float(stats.get("броня", 0.0)), "crit": float(stats.get("крит", 0.0)),
		"block": float(stats.get("блок", 0.0)), "vamp": float(stats.get("вампиризм", 0.0))}


## Advances by dt (any size); returns the events of that interval in order.
func advance(dt: float) -> Array:
	var out := []
	var left := dt
	while left > 0.0 and not over:
		var h := minf(STEP, left)
		left -= h
		time += h
		for side in ["hero", "enemy"]:   # hero first on ties: deterministic
			var a: Dictionary = f[side]
			a["cd"] -= h
			if a["cd"] <= 0.0 and not over:
				a["cd"] += 1.0 / maxf(0.05, a["speed"])
				_attack(side, out)
		if not over and time >= t.time_limit:
			over = true
			winner = "enemy"
			out.append({"t": time, "kind": "timeout", "src": "enemy", "amount": 0})
	return out


func _attack(side: String, out: Array) -> void:
	var other := "enemy" if side == "hero" else "hero"
	var a: Dictionary = f[side]
	var b: Dictionary = f[other]
	if rng.randf() * 100.0 < minf(b["block"], t.block_cap):
		out.append({"t": time, "kind": "block", "src": side, "amount": 0})
		return
	var is_crit: bool = rng.randf() * 100.0 < float(a["crit"])
	var dmg: float = Formulas.armor_damage(a["dmg"] * (t.crit_mult if is_crit else 1.0), b["armor"], t.armor_k)
	b["hp"] = maxf(0.0, b["hp"] - dmg)
	out.append({"t": time, "kind": "crit" if is_crit else "hit", "src": side, "amount": dmg})
	if a["vamp"] > 0.0 and a["hp"] < a["max_hp"]:
		var heal: float = minf(a["max_hp"] - a["hp"], dmg * a["vamp"] / 100.0)
		if heal > 0.0:
			a["hp"] += heal
			out.append({"t": time, "kind": "heal", "src": side, "amount": heal})
	if b["hp"] <= 0.0:
		over = true
		winner = side
		out.append({"t": time, "kind": "death", "src": other, "amount": 0})
