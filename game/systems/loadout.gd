class_name Loadout
extends RefCounted
## Equipped build + coins. Sharpening (melt) belongs to the slot and survives item swaps.
## Build power uses the same formulas as combat (CombatTuning): √(DPS × effective HP).

const SLOTS := ["weapon", "shield", "helm", "armor", "gloves", "boots", "belt", "amulet", "ring1", "ring2"]
const STAT_ORDER := ["урон", "скорость", "проворство", "крит", "сила крита", "пробивание", "яд", "натиск", "казнь",
	"ярость", "броня", "блок", "ответный удар", "оберег", "шипы", "вампиризм", "регенерация", "жизнь", "передышка",
	"уязвимость", "алчность", "удача"]

var equipped := {}
var rank := {}
var coins := 0
var econ := {}
var ct: CombatTuning
var resonance := {}   # data/m04/resonance.json; empty = off
var ring_pick := ""   # player's choice which ring to replace when both are worn ("" = auto)
var last_refund := 0  # coins from the trade-in of the replaced item on the last equip


func _init(econ_: Dictionary, start: Dictionary, tuning: CombatTuning = null) -> void:
	econ = econ_
	ct = tuning if tuning else load("res://data/tuning/m03_combat.tres")
	if FileAccess.file_exists("res://data/m04/resonance.json"):
		resonance = JSON.parse_string(FileAccess.get_file_as_string("res://data/m04/resonance.json"))
	for s in SLOTS:
		equipped[s] = start.get(s, {})
		rank[s] = 0


func target_slot(item: Dictionary) -> String:
	var s: String = item["slot"]
	if s != "ring":
		return s
	for r in ["ring1", "ring2"]:
		if equipped[r].is_empty():
			return r
	if ring_pick != "" and not is_locked(ring_pick):
		return ring_pick
	if is_locked("ring1") != is_locked("ring2"):
		return "ring2" if is_locked("ring1") else "ring1"
	return "ring1" if _power_of_slot_swap("ring1", {}) >= _power_of_slot_swap("ring2", {}) else "ring2"


## M05: a slot holding a cursed relic cannot be changed.
func is_locked(slot: String) -> bool:
	return bool(equipped.get(slot, {}).get("cursed", false))


func can_equip(item: Dictionary) -> bool:
	return not is_locked(target_slot(item))


func mult(slot: String) -> float:
	return 1.0 + float(econ["melt_bonus"]) * rank[slot]


## Sharpening multiplies an item's stats. It never speeds up a weapon and never grows the drawbacks
## of a normal item (Павеза's −проворство); a cursed relic's curse does grow (M05 rule).
static func scaled(it: Dictionary, m: float) -> Dictionary:
	var out := {}
	if it.is_empty():
		return out
	var cursed := bool(it.get("cursed", false))
	for k in it["stats"]:
		var v := float(it["stats"][k])
		var bad: bool = v < 0.0 or k == "уязвимость"
		out[k] = v if k == "скорость" or (bad and not cursed) else v * m
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
	var res := resonance_stats(tag_counts(override_slot, override_item))
	for k in res:
		s[k] = float(s.get(k, 0.0)) + res[k]
	return s


## M04: how many equipped items carry each tag (optionally with one slot swapped).
func tag_counts(override_slot := "", override_item := {}) -> Dictionary:
	var c := {}
	for slot in SLOTS:
		var it: Dictionary = override_item if slot == override_slot else equipped[slot]
		if it.is_empty():
			continue
		for tg in it.get("tags", []):
			c[tg] = int(c.get(tg, 0)) + 1
	return c


## Resonance level of a tag: 0 (none) .. 3 (7+ items).
func resonance_level(count: int) -> int:
	var lv := 0
	if resonance.is_empty():
		return 0
	for th in resonance["thresholds"]:
		if count >= int(th):
			lv += 1
	return lv


func resonance_stats(counts: Dictionary) -> Dictionary:
	var out := {}
	if resonance.is_empty():
		return out
	for tg in counts:
		var lv := resonance_level(int(counts[tg]))
		if lv > 0 and resonance["tags"].has(tg):
			var r: Dictionary = resonance["tags"][tg]
			out[r["stat"]] = float(out.get(r["stat"], 0.0)) + float(r["v"][lv - 1])
	return out


## Text for the card when equipping changes a resonance level ("кровь 3: +3% вампиризм").
func resonance_change(item: Dictionary) -> String:
	if resonance.is_empty():
		return ""
	var before := tag_counts()
	var after := tag_counts(target_slot(item), item)
	var parts := []
	for tg in after.keys() + before.keys():
		var b := resonance_level(int(before.get(tg, 0)))
		var a := resonance_level(int(after.get(tg, 0)))
		if a != b and resonance["tags"].has(tg):
			var r: Dictionary = resonance["tags"][tg]
			var s := "%s %d: " % [tg, int(after.get(tg, 0))]
			s += ("+%d %s" % [roundi(float(r["v"][a - 1])), r["stat"]]) if a > b else "теряется резонанс"
			if s not in parts:
				parts.append(s)
	return " · ".join(parts)


## All relic flags of the worn items (third_crit, overheal, …) for the fighter.
func flags(override_slot := "", override_item := {}) -> Array:
	var out := []
	for slot in SLOTS:
		var it: Dictionary = override_item if slot == override_slot else equipped[slot]
		for fl in it.get("flags", []):
			if fl not in out:
				out.append(fl)
	return out


func power_of_stats(stats: Dictionary, fl: Array = []) -> float:
	return Formulas.build_power(Combat.hero_from(stats, 0.0, ct, fl), ct)


## (attack, defence) of the build now / with the item worn — the two halves of "сила".
func parts() -> Vector2:
	return Formulas.build_parts(Combat.hero_from(total_stats(), 0.0, ct, flags()), ct)


func parts_if_equipped(item: Dictionary) -> Vector2:
	var s := target_slot(item)
	return Formulas.build_parts(Combat.hero_from(total_stats(s, item), 0.0, ct, flags(s, item)), ct)


func power() -> float:
	return power_of_stats(total_stats(), flags())


func _power_of_slot_swap(slot: String, item: Dictionary) -> float:
	return power_of_stats(total_stats(slot, item), flags(slot, item))


func power_if_equipped(item: Dictionary) -> float:
	return _power_of_slot_swap(target_slot(item), item)


func power_if_melted(item: Dictionary) -> float:
	var s := target_slot(item)
	return power_of_stats(total_stats(s, equipped[s], mult(s) + float(econ["melt_bonus"])), flags())


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
	var greed := maxf(-90.0, float(total_stats().get("алчность", 0.0)))
	return roundi(Formulas.sell_price(int(item["rarity"]), int(item.get("ilvl", 1)), econ["sell_base"], float(econ["sell_per_ilvl"])) * (1.0 + greed / 100.0))


## Coins the currently worn item in the target slot brings when it is replaced (trade-in).
func trade_in_value(item: Dictionary) -> int:
	var old: Dictionary = equipped[target_slot(item)]
	if old.is_empty():
		return 0
	return roundi(sell_price(old) * float(econ.get("trade_in", 0.0)))


func equip(item: Dictionary) -> String:
	var s := target_slot(item)
	last_refund = trade_in_value(item)
	coins += last_refund
	equipped[s] = item
	ring_pick = ""
	return s


## The build's most common tag (for tag-biased drops); "" when no tags.
func top_tag() -> String:
	var c := tag_counts()
	var best := ""
	for tg in c:
		if best == "" or int(c[tg]) > int(c[best]):
			best = tg
	return best


func sell(item: Dictionary) -> int:
	var c := sell_price(item)
	coins += c
	return c


func melt(item: Dictionary) -> String:
	var s := target_slot(item)
	rank[s] += 1
	return s
