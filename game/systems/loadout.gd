class_name Loadout
extends RefCounted
## Equipped build + coins. Sharpening (melt) belongs to the slot and survives item swaps.
## Build power uses the same formulas as combat (CombatTuning): √(DPS × effective HP).

const SLOTS := ["weapon", "shield", "helm", "armor", "gloves", "boots", "belt", "amulet", "ring1", "ring2"]
const STAT_ORDER := ["урон", "скорость", "проворство", "крит", "броня", "блок", "вампиризм", "жизнь"]

var equipped := {}
var rank := {}
var coins := 0
var econ := {}
var ct: CombatTuning


func _init(econ_: Dictionary, start: Dictionary, tuning: CombatTuning = null) -> void:
	econ = econ_
	ct = tuning if tuning else load("res://data/tuning/m03_combat.tres")
	for s in SLOTS:
		equipped[s] = start.get(s, {})
		rank[s] = 0


func target_slot(item: Dictionary) -> String:
	var s: String = item["slot"]
	if s != "ring":
		return s
	if equipped["ring1"].is_empty():
		return "ring1"
	if equipped["ring2"].is_empty():
		return "ring2"
	return "ring1" if _power_of_slot_swap("ring1", {}) >= _power_of_slot_swap("ring2", {}) else "ring2"


func mult(slot: String) -> float:
	return 1.0 + float(econ["melt_bonus"]) * rank[slot]


static func scaled(it: Dictionary, m: float) -> Dictionary:
	var out := {}
	if it.is_empty():
		return out
	for k in it["stats"]:
		var v := float(it["stats"][k])
		out[k] = v if (k == "скорость" or v < 0.0) else v * m   # sharpening never speeds up a weapon
	return out


func slot_stats(slot: String) -> Dictionary:
	return scaled(equipped.get(slot, {}), mult(slot))


func total_stats(override_slot := "", override_item := {}, override_mult := -1.0) -> Dictionary:
	var s := {}
	for slot in SLOTS:
		var st: Dictionary
		if slot == override_slot:
			st = scaled(override_item, mult(slot) if override_mult < 0.0 else override_mult)
		else:
			st = slot_stats(slot)
		for k in st:
			s[k] = float(s.get(k, 0.0)) + st[k]
	return s


func power_of_stats(stats: Dictionary) -> float:
	var h := Combat.hero_from(stats, 0.0, ct)
	var e: float = Formulas.ehp(h["max_hp"], h["armor"], h["block"], ct.armor_k, ct.block_cap) * (1.0 + h["vamp"] / 50.0)
	return Formulas.power(Formulas.dps(h["dmg"], h["speed"], h["crit"], ct.crit_mult), e)


func power() -> float:
	return power_of_stats(total_stats())


func _power_of_slot_swap(slot: String, item: Dictionary) -> float:
	return power_of_stats(total_stats(slot, item))


func power_if_equipped(item: Dictionary) -> float:
	return _power_of_slot_swap(target_slot(item), item)


func power_if_melted(item: Dictionary) -> float:
	var s := target_slot(item)
	return power_of_stats(total_stats(s, equipped[s], mult(s) + float(econ["melt_bonus"])))


## Rows [stat, before|null, after|null] for the card: equipped (with sharpening) vs new.
func compare(item: Dictionary) -> Array:
	var s := target_slot(item)
	var before := slot_stats(s)
	var after := scaled(item, mult(s))
	var rows := []
	for k in STAT_ORDER:
		if before.has(k) or after.has(k):
			rows.append([k, before.get(k), after.get(k)])
	return rows


func sell_price(item: Dictionary) -> int:
	return Formulas.sell_price(int(item["rarity"]), int(item.get("ilvl", 1)), econ["sell_base"], float(econ["sell_per_ilvl"]))


func equip(item: Dictionary) -> String:
	var s := target_slot(item)
	equipped[s] = item
	return s


func sell(item: Dictionary) -> int:
	var c := sell_price(item)
	coins += c
	return c


func melt(item: Dictionary) -> String:
	var s := target_slot(item)
	rank[s] += 1
	return s
