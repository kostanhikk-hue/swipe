class_name Combat
extends RefCounted
## M03 auto-battle: deterministic real-time simulation on a fixed step. Emits event dicts:
## {t, kind, src, amount}; kind: hit|crit|block|heal|thorns|regen|poison|riposte|shield|stun|steal|coin|
## enrage|death|timeout. src = the side the event comes from (for death — who died).
## Fighter keys (all optional beyond hp/max_hp/dmg/speed/armor/crit/block/vamp):
## critdmg, pen, thorns, regen, poison (% of a hit as poison over 3 s), riposte (% dmg on block),
## ward (absorb at start), onset (% first hit), execute (% vs <30% hp), fury (% when own hp <35%),
## vuln (% extra damage taken), steal (coins per hit), stun (every N-th hit stuns), flags: Array.

const STEP := 0.05
const POISON_TIME := 3.0
const STUN_TIME := 0.8

var t: CombatTuning
var rng := RandomNumberGenerator.new()
var time := 0.0
var over := false
var winner := ""
var limit := 30.0        # seconds; after it the enemy enrages (no instant loss)
var enrage_rate := 0.25  # enemy damage +x per second past the limit
var hard_mult := 4.0     # safety stop at limit × hard_mult
var enraged := false
var f := {}


func _init(hero: Dictionary, enemy: Dictionary, tuning: CombatTuning, seed_value: int) -> void:
	t = tuning
	limit = t.time_limit
	rng.seed = seed_value
	f["hero"] = hero.duplicate()
	f["enemy"] = enemy.duplicate()
	f["hero"]["cd"] = t.hero_first_delay
	f["enemy"]["cd"] = t.enemy_first_delay
	for side in f:
		var a: Dictionary = f[side]
		a["regen_acc"] = 0.0
		a["poison_pool"] = 0.0
		a["poison_acc"] = 0.0
		a["hits"] = 0
		a["shield"] = float(a.get("ward", 0.0))
		a["thorns"] = float(a.get("thorns", 0.0))
		if not a.has("flags"):
			a["flags"] = []


## Hero fighter from summed item stats (Russian stat keys as in data). Every chance-like stat is
## clamped at 0 here, so "сила", the stat sheet and the fight all read the same numbers.
static func hero_from(stats: Dictionary, hp: float, tuning: CombatTuning, flags: Array = []) -> Dictionary:
	var g := func(k: String) -> float: return float(stats.get(k, 0.0))
	var base_speed: float = g.call("скорость")
	if base_speed <= 0.0:
		base_speed = tuning.fist_speed
	var pos := func(k: String) -> float: return maxf(0.0, g.call(k))
	return {"hp": hp, "max_hp": maxf(1.0, tuning.hero_base_hp + g.call("жизнь")),
		"dmg": maxf(1.0, tuning.hero_base_dmg + g.call("урон")),
		"speed": maxf(0.2, base_speed * (1.0 + g.call("проворство") / 100.0)),
		"armor": pos.call("броня"), "crit": minf(100.0, pos.call("крит")),
		"block": pos.call("блок"), "vamp": pos.call("вампиризм"),
		"critdmg": pos.call("сила крита"), "pen": minf(80.0, pos.call("пробивание")),
		"thorns": pos.call("шипы"), "regen": g.call("регенерация"),
		"greed": maxf(-90.0, g.call("алчность")),
		"poison": pos.call("яд"), "riposte": pos.call("ответный удар"), "ward": pos.call("оберег"),
		"onset": pos.call("натиск"), "execute": pos.call("казнь"), "fury": pos.call("ярость"),
		"vuln": pos.call("уязвимость"), "rest": pos.call("передышка"), "luck": pos.call("удача"),
		"flags": flags.duplicate()}


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
			_tick_regen(side, a, h, out)
			_tick_poison(side, a, h, out)
			if over:
				break
			a["cd"] -= h
			if a["cd"] <= 0.0 and not over:
				a["cd"] += 1.0 / maxf(0.05, a["speed"])
				_attack(side, out)
		if not over and time >= limit and not enraged:
			enraged = true
			out.append({"t": time, "kind": "enrage", "src": "enemy", "amount": 0})
		if not over and time >= limit * hard_mult:
			over = true
			winner = "enemy"
			out.append({"t": time, "kind": "timeout", "src": "enemy", "amount": 0})
	return out


func _die(side: String, out: Array) -> void:
	if over:
		return
	over = true
	winner = "enemy" if side == "hero" else "hero"
	out.append({"t": time, "kind": "death", "src": side, "amount": 0})


func _tick_regen(side: String, a: Dictionary, h: float, out: Array) -> void:
	var rg := float(a.get("regen", 0.0))
	if rg < 0.0:   # M05 curse: bleeding
		a["hp"] = maxf(0.0, a["hp"] + rg * h)
		if a["hp"] <= 0.0:
			_die(side, out)
	elif rg > 0.0 and a["hp"] < a["max_hp"]:
		var add := minf(a["max_hp"] - a["hp"], rg * h)
		a["hp"] += add
		a["regen_acc"] += add
		if a["regen_acc"] >= 1.0:
			out.append({"t": time, "kind": "regen", "src": side, "amount": a["regen_acc"]})
			a["regen_acc"] = 0.0


func _tick_poison(side: String, a: Dictionary, h: float, out: Array) -> void:
	var pool: float = a["poison_pool"]
	if pool <= 0.0:
		return
	var d := minf(pool, maxf(pool / POISON_TIME, 2.0) * h)
	a["poison_pool"] = pool - d
	a["hp"] = maxf(0.0, a["hp"] - d)
	a["poison_acc"] += d
	if a["poison_acc"] >= maxf(3.0, float(a["max_hp"]) * 0.03) or (a["poison_pool"] <= 0.0 and a["poison_acc"] >= 1.0):
		out.append({"t": time, "kind": "poison", "src": side, "amount": a["poison_acc"]})
		a["poison_acc"] = 0.0
	if a["hp"] <= 0.0:
		_die(side, out)


## Damage that reaches `b` after its shield and vulnerability; returns HP actually lost.
func _take(b: Dictionary, raw: float) -> float:
	var dmg := raw * (1.0 + float(b.get("vuln", 0.0)) / 100.0)
	var sh: float = b["shield"]
	if sh > 0.0:
		var ab := minf(sh, dmg)
		b["shield"] = sh - ab
		dmg -= ab
	b["hp"] = maxf(0.0, b["hp"] - dmg)
	return dmg


func _armor_of(a: Dictionary, b: Dictionary) -> float:
	return float(b["armor"]) * (1.0 - minf(80.0, float(a.get("pen", 0.0))) / 100.0)


func _attack(side: String, out: Array) -> void:
	var other := "enemy" if side == "hero" else "hero"
	var a: Dictionary = f[side]
	var b: Dictionary = f[other]
	a["hits"] += 1
	if rng.randf() * 100.0 < minf(float(b["block"]), t.block_cap):
		out.append({"t": time, "kind": "block", "src": side, "amount": 0})
		var rp := float(b.get("riposte", 0.0))
		if rp > 0.0:   # the blocker answers
			var rd := Formulas.armor_damage(float(b["dmg"]) * rp / 100.0, _armor_of(b, a), t.armor_k)
			rd = _take(a, rd)
			out.append({"t": time, "kind": "riposte", "src": other, "amount": rd})
			if a["hp"] <= 0.0:
				_die(side, out)
		return
	var fl: Array = a["flags"]
	var is_crit: bool = rng.randf() * 100.0 < float(a["crit"]) or ("third_crit" in fl and int(a["hits"]) % 3 == 0)
	var cm := t.crit_mult + float(a.get("critdmg", 0.0)) / 100.0
	var raw: float = float(a["dmg"]) * (cm if is_crit else 1.0)
	if int(a["hits"]) == 1:
		raw *= 1.0 + float(a.get("onset", 0.0)) / 100.0
	if b["hp"] < b["max_hp"] * 0.3:
		raw *= 1.0 + float(a.get("execute", 0.0)) / 100.0
	if a["hp"] < a["max_hp"] * 0.35:
		raw *= 1.0 + float(a.get("fury", 0.0)) / 100.0
	if side == "enemy" and enraged:
		raw *= 1.0 + enrage_rate * (time - limit)
	var dmg := Formulas.armor_damage(raw, _armor_of(a, b), t.armor_k)
	var lost := _take(b, dmg)
	out.append({"t": time, "kind": "crit" if is_crit else "hit", "src": side, "amount": lost})
	var po := float(a.get("poison", 0.0))
	if po > 0.0:
		b["poison_pool"] += dmg * po / 100.0
	if "coin_hit" in fl:
		out.append({"t": time, "kind": "coin", "src": side, "amount": 1})
	var st := float(a.get("steal", 0.0))
	if st > 0.0:
		out.append({"t": time, "kind": "steal", "src": side, "amount": st})
	var sn := int(a.get("stun", 0))
	if sn > 0 and int(a["hits"]) % sn == 0:
		b["cd"] += STUN_TIME
		out.append({"t": time, "kind": "stun", "src": side, "amount": STUN_TIME})
	if a["vamp"] > 0.0:
		var heal: float = dmg * a["vamp"] / 100.0
		var room: float = a["max_hp"] - a["hp"]
		if heal > 0.0 and room > 0.0:
			out.append({"t": time, "kind": "heal", "src": side, "amount": minf(room, heal)})
		a["hp"] = minf(a["max_hp"], a["hp"] + heal)
		if "overheal" in fl and heal > room:
			var cap: float = a["max_hp"] * 0.3
			var add := minf(cap - float(a["shield"]), heal - room)
			if add > 0.0:
				a["shield"] += add
				out.append({"t": time, "kind": "shield", "src": side, "amount": add})
	if b["hp"] <= 0.0:
		_die(other, out)
		return
	if "thorns_grow" in (b["flags"] as Array):
		b["thorns"] = float(b["thorns"]) + 2.0
	var th := float(b.get("thorns", 0.0))
	if th > 0.0:
		var tl := _take(a, th)
		out.append({"t": time, "kind": "thorns", "src": other, "amount": tl})
		if a["hp"] <= 0.0:
			_die(side, out)
