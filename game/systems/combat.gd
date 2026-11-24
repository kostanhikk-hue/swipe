class_name Combat
extends RefCounted
## M03 auto-battle: deterministic real-time simulation on a fixed step. Emits event dicts:
## {t, kind: hit|crit|block|heal|thorns|regen|death|timeout, src: hero|enemy, amount}
## Optional fighter keys: critdmg (% extra crit multiplier), pen (% armor ignored), thorns (flat back
## when hit), regen (HP/s), greed (% coins; not used in combat).

const STEP := 0.05

var t: CombatTuning
var rng := RandomNumberGenerator.new()
var time := 0.0
var over := false
var winner := ""
var limit := 30.0   # seconds; bosses get longer (CombatTuning.boss_time_mult)
var f := {}   # side -> {hp, max_hp, dmg, speed, armor, crit, block, vamp, cd}


func _init(hero: Dictionary, enemy: Dictionary, tuning: CombatTuning, seed_value: int) -> void:
	t = tuning
	limit = t.time_limit
	rng.seed = seed_value
	f["hero"] = hero.duplicate()
	f["enemy"] = enemy.duplicate()
	f["hero"]["cd"] = t.hero_first_delay
	f["enemy"]["cd"] = t.enemy_first_delay
	for side in f:
		f[side]["regen_acc"] = 0.0


## Hero fighter from summed item stats (Russian stat keys as in data).
## Attack speed = weapon speed (or fists) × (1 + проворство%).
static func hero_from(stats: Dictionary, hp: float, tuning: CombatTuning) -> Dictionary:
	var base_speed := float(stats.get("скорость", 0.0))
	if base_speed <= 0.0:
		base_speed = tuning.fist_speed
	return {"hp": hp, "max_hp": tuning.hero_base_hp + float(stats.get("жизнь", 0.0)),
		"dmg": tuning.hero_base_dmg + float(stats.get("урон", 0.0)),
		"speed": maxf(0.2, base_speed * (1.0 + float(stats.get("проворство", 0.0)) / 100.0)),
		"armor": maxf(0.0, float(stats.get("броня", 0.0))), "crit": float(stats.get("крит", 0.0)),
		"block": float(stats.get("блок", 0.0)), "vamp": float(stats.get("вампиризм", 0.0)),
		"critdmg": float(stats.get("сила крита", 0.0)), "pen": float(stats.get("пробивание", 0.0)),
		"thorns": float(stats.get("шипы", 0.0)), "regen": float(stats.get("регенерация", 0.0)),
		"greed": float(stats.get("алчность", 0.0))}


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
			var rg := float(a.get("regen", 0.0))
			if rg < 0.0:   # M05 curse: bleeding
				a["hp"] = maxf(0.0, a["hp"] + rg * h)
				if a["hp"] <= 0.0 and not over:
					over = true
					winner = "enemy" if side == "hero" else "hero"
					out.append({"t": time, "kind": "death", "src": side, "amount": 0})
			elif rg > 0.0 and a["hp"] < a["max_hp"]:
				var add := minf(a["max_hp"] - a["hp"], rg * h)
				a["hp"] += add
				a["regen_acc"] += add
				if a["regen_acc"] >= 1.0:
					out.append({"t": time, "kind": "regen", "src": side, "amount": a["regen_acc"]})
					a["regen_acc"] = 0.0
			a["cd"] -= h
			if a["cd"] <= 0.0 and not over:
				a["cd"] += 1.0 / maxf(0.05, a["speed"])
				_attack(side, out)
		if not over and time >= limit:
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
	var cm := t.crit_mult + float(a.get("critdmg", 0.0)) / 100.0
	var armor: float = float(b["armor"]) * (1.0 - minf(80.0, float(a.get("pen", 0.0))) / 100.0)
	var dmg: float = Formulas.armor_damage(a["dmg"] * (cm if is_crit else 1.0), armor, t.armor_k)
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
		return
	var th := float(b.get("thorns", 0.0))
	if th > 0.0:
		a["hp"] = maxf(0.0, a["hp"] - th)
		out.append({"t": time, "kind": "thorns", "src": other, "amount": th})
		if a["hp"] <= 0.0:
			over = true
			winner = other
			out.append({"t": time, "kind": "death", "src": side, "amount": 0})
