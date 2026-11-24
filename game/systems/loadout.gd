class_name Loadout
extends RefCounted
## Equipped build + coins. Sharpening (melt) belongs to the slot and survives item swaps.

const SLOTS := ["weapon", "shield", "helm", "armor", "gloves", "boots", "belt", "amulet", "ring1", "ring2"]
const STAT_ORDER := ["урон", "скорость", "крит", "броня", "жизнь", "вампиризм", "блок"]

var equipped := {}
var rank := {}
var coins := 0
var econ := {}


func _init(econ_: Dictionary, start: Dictionary) -> void:
	econ = econ_
	for s in SLOTS:
		equipped[s] = start.get(s, {})
		rank[s] = 0


func target_slot(item: Dictionary) -> String:
	var s: String = item["slot"]
	if s != "ring":
		return s
	return "ring1" if slot_power("ring1") <= slot_power("ring2") else "ring2"


func mult(slot: String) -> float:
	return 1.0 + float(econ["melt_bonus"]) * rank[slot]


func slot_stats(slot: String) -> Dictionary:
	var it: Dictionary = equipped.get(slot, {})
	var out := {}
	if it.is_empty():
		return out
	for k in it["stats"]:
		out[k] = float(it["stats"][k]) * mult(slot)
	return out


func slot_power(slot: String) -> float:
	return Formulas.power_of(slot_stats(slot), econ["weights"])


func power() -> float:
	var p := 0.0
	for s in SLOTS:
		p += slot_power(s)
	return p


func power_if_equipped(item: Dictionary) -> float:
	var s := target_slot(item)
	return power() - slot_power(s) + Formulas.power_of(item["stats"], econ["weights"], mult(s))


func power_if_melted(item: Dictionary) -> float:
	var s := target_slot(item)
	var base := slot_power(s) / mult(s) if mult(s) > 0.0 else 0.0
	return power() - slot_power(s) + base * (mult(s) + float(econ["melt_bonus"]))


## Rows [stat, before|null, after|null] for the card: equipped (with sharpening) vs new.
func compare(item: Dictionary) -> Array:
	var s := target_slot(item)
	var before := slot_stats(s)
	var after := {}
	for k in item["stats"]:
		after[k] = float(item["stats"][k]) * mult(s)
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
