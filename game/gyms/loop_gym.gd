extends "res://gyms/swipe_gym.gd"
## M03 loop gym: enemy rises from the doorway → real-time auto-battle → drop card (M01) → next enemy.
## Keys as in the swipe gym; Tab = combat tuning (M03). Death → banner, R restarts the run.
## Args: --depth=N (debug: start at depth N with a greedy build), --seed=N, --demo.

const EnemyView := preload("res://views/enemy_view.gd")
const CombatLog := preload("res://views/combat_log.gd")
const StatSheet := preload("res://views/stat_sheet.gd")
const ENEMY_C := Vector2(640, 400)

var ct: CombatTuning
var enemies := {}
var loot := {}
var affixes := {}
var depth := 1
var best := 0
var hero_hp := 0.0
var combat: Combat
var cur_enemy := {}
var enemy_def := {}
var enemy_v: Node2D
var hand: Node2D
var log_v: Node2D
var sheet: Node2D
var phase := "rise"
var ph_t := 0.0
var _hand_k := 0.0
var _demo_i := 0
var spend := {}
var rerolls := 0
var drop_min_rarity := 0
var is_boss := false
var shop_cards: Array = []     # CardView nodes
var shop_items: Array = []
var shop_used := false
var from_shop := false
var save := {}
var shop_overlay: Node2D


func _start() -> void:
	ct = (load("res://data/tuning/m03_combat.tres") as CombatTuning).duplicate()
	enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/enemies.json"))
	loot = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/loot.json"))
	affixes = JSON.parse_string(FileAccess.get_file_as_string("res://data/m02/affixes.json"))
	spend = JSON.parse_string(FileAccess.get_file_as_string("res://data/m06/spend.json"))
	save = Save.load_data()
	best = int(save["best_depth"])
	enemy_v = EnemyView.new()
	add_child(enemy_v)
	move_child(enemy_v, back.get_index() + 1)
	front.layer = "vignette"
	hand = DungeonView.new()
	hand.layer = "hand"
	add_child(hand)
	move_child(hand, enemy_v.get_index() + 1)
	log_v = CombatLog.new()
	add_child(log_v)
	move_child(log_v, hud.get_index() + 1)
	sheet = StatSheet.new()
	add_child(sheet)
	move_child(sheet, log_v.get_index() + 1)
	shop_overlay = Node2D.new()
	add_child(shop_overlay)
	move_child(shop_overlay, fx.get_index())
	shop_overlay.draw.connect(_draw_shop_overlay)
	tpanel.bind(ct, "M03")
	loadout = Loadout.new(loadout.econ, {}, ct)   # the run starts naked (decision #27)
	panel.loadout = loadout
	panel.queue_redraw()
	_apply_clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depth="):   # debug: start deeper with a greedily collected build
			var target := int(a.get_slice("=", 1))
			for dd in range(1, target):
				var it := ItemGen.roll(dd, rng, loot, affixes)
				if loadout.power_if_equipped(it) > loadout.power():
					loadout.equip(it)
			depth = target
	hero_hp = _hero_max()
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	_spawn_enemy()


func _clear_rects() -> Array:
	var c := super._clear_rects()
	c.append(_soft(Rect2(370, 18, 540, 160)))
	c.append(_soft(CombatLog.AREA.grow(6)))
	c.append(_soft(StatSheet.AREA.grow(8)))
	return c


func _apply_clear() -> void:
	super._apply_clear()
	if hand:
		hand.clear = back.clear
		hand.queue_redraw()


func _hero_stats() -> Dictionary:
	return loadout.total_stats()


func _hero_max() -> float:
	return ct.hero_base_hp + float(_hero_stats().get("жизнь", 0.0))


func _spawn_enemy() -> void:
	var types: Array = enemies["types"]
	var d: Dictionary = types[rng.randi() % types.size()]
	is_boss = LoopMath.is_boss(depth, enemies)
	if is_boss:
		var bosses: Array = enemies["bosses"]
		d = bosses[(depth / int(enemies["boss_every"]) - 1) % bosses.size()]
		cur_enemy = LoopMath.boss_at(depth, enemies, ct)
	else:
		cur_enemy = LoopMath.enemy_at(d, depth, ct)
	enemy_def = d
	enemy_v.boss = is_boss
	hud.enemy_note = String(d.get("special", "")) if is_boss else ""
	hud.actions = []
	enemy_v.set_shape(d["shape"])
	enemy_v.visible = true
	enemy_v.appear = 0.0
	hud.enemy_name = ("БОСС · %s · %d" if is_boss else "%s · %d") % [d["name"], depth]
	hud.enemy_hp = cur_enemy["hp"]
	hud.enemy_hp_max = cur_enemy["max_hp"]
	_sync_hud()
	log_v.add("— глубина %d: %s" % [depth, d["name"]], E.CINNABAR if is_boss else E.INK_FADED)
	if is_boss:
		fx.float_text("БОСС", Vector2(640, 330), E.CINNABAR, 96)
		_shake(1.5)
	sfx.play("rise", 0.5 if is_boss else 0.7)
	phase = "rise"
	ph_t = 0.0


func _sync_hud() -> void:
	hud.depth = depth
	hud.best = maxi(best, depth)
	hud.hp = hero_hp
	hud.hp_max = _hero_max()
	hud.queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	ph_t += delta
	_hand_k = maxf(0.0, _hand_k - delta * 7.0)
	hand.scale = Vector2.ONE * 0.8
	hand.position = Vector2(0, 144) + Vector2(60, -50) * sin(_hand_k * PI)
	var fighting := phase in ["rise", "fight"]
	var hf: Dictionary = combat.f["hero"] if phase == "fight" else Combat.hero_from(_hero_stats(), hero_hp, ct)
	sheet.set_data(hf, cur_enemy if fighting else {}, ct)
	match phase:
		"rise":
			var k := clampf(ph_t / (1.2 if is_boss else 0.45), 0.0, 1.0)
			enemy_v.appear = 1.0 - pow(1.0 - k, 3)
			if k >= 1.0:
				combat = Combat.new(Combat.hero_from(_hero_stats(), hero_hp, ct), cur_enemy, ct, seed_value * 1000 + depth)
				if is_boss:
					combat.limit = ct.time_limit * ct.boss_time_mult
				phase = "fight"
				ph_t = 0.0
		"fight":
			for ev in combat.advance(delta * ct.fight_speed):
				_on_event(ev)
			if phase == "fight":
				hero_hp = combat.f["hero"]["hp"]
				hud.enemy_hp = combat.f["enemy"]["hp"]
				_sync_hud()
		"death":
			if ph_t > 0.7:
				phase = "drop"
				rise_from = ENEMY_C
				swipe_enabled = true
				hud.show_hints = true
				hud.enemy_name = ""
				hud.enemy_note = ""
				_next_card()
		"shop":
			if _demo and ph_t > 1.5:
				ph_t = -100.0
				_buy(0) if loadout.coins >= int(shop_items[0]["price"]) else _do_action("leave")
		"drop":
			if _demo and state == St.IDLE and st_t > 0.5:
				var seq := [Swipe.EQUIP, Swipe.SELL, Swipe.MELT, Swipe.EQUIP]
				var dec: int = seq[_demo_i % seq.size()]
				_demo_i += 1
				_commit(dec, Vector2(tuning.exit_speed_min, 0) if dec == Swipe.EQUIP else (Vector2(-tuning.exit_speed_min, 0) if dec == Swipe.SELL else Vector2(0, -tuning.exit_speed_min)))


func _run_demo(_delta: float) -> void:
	pass   # the loop demo commits from _process during the drop phase


func _on_event(ev: Dictionary) -> void:
	var amt := roundi(ev["amount"])
	var by_hero: bool = ev["src"] == "hero"
	var foe: String = String(enemy_def["name"]).to_lower()
	match ev["kind"]:
		"hit", "crit":
			var crit: bool = ev["kind"] == "crit"
			if by_hero:
				_hand_k = 1.0
				enemy_v.hurt(2.0 if crit else 1.0)
				fx.float_text("−%d" % amt, ENEMY_C + Vector2(rng.randf_range(-90, 90), rng.randf_range(-200, -120)), E.CINNABAR, 66 if crit else 42)
				if crit:
					fx.ink_burst(ENEMY_C + Vector2(0, -120), 110.0, E.CINNABAR)
				log_v.add(("КРИТ −%d" if crit else "удар −%d") % amt, E.CINNABAR if crit else E.INK)
			else:
				enemy_v.lunge()
				fx.float_text("−%d" % amt, Vector2(1000, 150), E.CINNABAR, 56 if crit else 42)
				fx.ink_burst(Vector2(640, 690), 160.0, E.CINNABAR)
				log_v.add(("%s: КРИТ −%d" if crit else "%s бьёт −%d") % [foe, amt], E.CINNABAR)
			sfx.play("crit" if crit else ("hit" if by_hero else "hurt"))
			_impact(ct.crit_hitstop_ms if crit else ct.hit_hitstop_ms, ct.crit_shake_px if crit else ct.hit_shake_px)
		"block":
			var where := Vector2(1090, 140) if not by_hero else ENEMY_C + Vector2(0, -170)
			fx.float_text("блок", where, E.INK, 36)
			log_v.add("блок!" if not by_hero else "%s блокирует" % foe, E.INK_FADED)
			sfx.play("block")
		"thorns":
			fx.float_text("шипы −%d" % amt, ENEMY_C + Vector2(0, -160) if by_hero else Vector2(1000, 170), Pal.stat("шипы"), 30)
			log_v.add(("шипы ранят: −%d" if by_hero else "шипы врага: −%d") % amt, Pal.stat("шипы"))
		"regen":
			if by_hero and amt >= 2:
				fx.float_text("+%d" % amt, Vector2(1000, 175), Pal.stat("регенерация"), 24)
		"heal":
			if amt < 1:
				return
			fx.float_text("+%d" % amt, Vector2(1090, 150) if by_hero else ENEMY_C + Vector2(60, -220), E.INK, 30)
			log_v.add(("вампиризм +%d" if by_hero else foe + " пьёт +%d") % amt, E.INK_FADED)
		"death":
			if ev["src"] == "enemy":
				_win()
			else:
				_lose("Забег окончен")
		"timeout":
			_lose("Время вышло")


func _impact(stop_ms: float, shake_px: float) -> void:
	if stop_ms > 0.0:
		hit_until = Time.get_ticks_msec() + int(stop_ms)
		Engine.time_scale = 0.02
		get_tree().create_timer(stop_ms / 1000.0, true, false, true).timeout.connect(func(): Engine.time_scale = base_scale)
	shake_power = shake_px / maxf(0.5, tuning.shake_px)
	shake_left = tuning.shake_ms / 1000.0


func _win() -> void:
	var rw: Dictionary = enemies["boss_reward"]
	hero_hp = minf(_hero_max(), combat.f["hero"]["hp"] + _hero_max() * (float(rw["heal"]) if is_boss else ct.heal_after_win))
	drop_min_rarity = int(rw["min_rarity"]) if is_boss else 0
	fx.shatter(ENEMY_C, Vector2(380, 560), 0.0, rng)
	fx.ink_burst(ENEMY_C, 220.0)
	enemy_v.visible = false
	var cr: Array = enemies["coins"]
	var greed := float(_hero_stats().get("алчность", 0.0))
	var c := roundi((rng.randi_range(int(cr[0]), int(cr[1])) + depth) * (1.0 + greed / 100.0) * (float(rw["coins_mult"]) if is_boss else 1.0))
	loadout.coins += c
	coin_step = maxi(1, ceili(c / 6.0))
	fx.spray_coins(ENEMY_C, hud.coin_anchor(), 6, rng)
	log_v.add("победа за %.1f с · +%d монет" % [combat.time, c], E.INK)
	sfx.play("win")
	if is_boss:
		log_v.add("босс повержен!", Pal.RARITY_TEXT[3])
		fx.float_text("БОСС ПОВЕРЖЕН", Vector2(640, 300), Pal.RARITY_TEXT[3], 64)
	depth += 1
	best = maxi(best, depth)
	_sync_hud()
	phase = "death"
	ph_t = 0.0


func _lose(title: String) -> void:
	hero_hp = 0.0
	_sync_hud()
	hud.banner = "%s\nглубина %d · рекорд %d · R — новый забег" % [title, depth, maxi(best, int(save["best_depth"]))]
	hud.queue_redraw()
	log_v.add(title.to_lower(), E.CINNABAR)
	sfx.play("death")
	_shake(2.0)
	hud.actions = []
	if depth > int(save["best_depth"]):
		save["best_depth"] = depth
		Save.store(save)
	phase = "dead"


func _on_card_done() -> void:
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	hero_hp = minf(hero_hp, _hero_max())
	panel.set_preview("", "", 0.0)
	_sync_hud()
	var won_depth := depth - 1
	if not from_shop and won_depth % int(spend["shop"]["every"]) == 0:
		_open_shop()
		return
	from_shop = false
	_spawn_enemy()


func _next_card() -> void:
	super._next_card()
	rerolls = 0
	drop_min_rarity = 0
	_refresh_actions()


func _pick_item() -> Dictionary:
	if from_shop:
		return item
	return ItemGen.roll(depth, rng, loot, affixes, drop_min_rarity)


# ------------------------------------------------------------- M06 spends

func _refresh_actions() -> void:
	var c := loadout.coins
	var acts := []
	var heal := Formulas.heal_cost(depth, spend["heal"])
	acts.append({"key": "H", "label": "лечить +%d%%" % roundi(float(spend["heal"]["pct"]) * 100.0), "cost": heal, "ok": c >= heal and hero_hp < _hero_max(), "do": "heal"})
	if phase == "drop":
		var rr := Formulas.reroll_cost(depth, rerolls, spend["reroll"])
		acts.append({"key": "E", "label": "перебросить", "cost": rr, "ok": c >= rr and state in [St.IDLE, St.RISE], "do": "reroll"})
		var slot := loadout.target_slot(item)
		var sh := Formulas.sharpen_cost(depth, loadout.rank[slot], spend["sharpen"])
		acts.append({"key": "U", "label": "заточить слот", "cost": sh, "ok": c >= sh and state in [St.IDLE, St.RISE], "do": "sharpen"})
	elif phase == "shop":
		acts.append({"key": "Space", "label": "уйти", "cost": 0, "ok": true, "do": "leave"})
	hud.actions = acts
	hud.queue_redraw()


func _do_action(what: String) -> void:
	if what in ["reroll", "sharpen"] and not (phase == "drop" and swipe_enabled and state in [St.IDLE, St.RISE]):
		return
	for a in hud.actions:
		if a["do"] == what and not a["ok"]:
			sfx.play("block", 0.6, -6.0)
			return
	match what:
		"heal":
			loadout.coins -= Formulas.heal_cost(depth, spend["heal"])
			var add := _hero_max() * float(spend["heal"]["pct"])
			hero_hp = minf(_hero_max(), hero_hp + add)
			fx.float_text("+%d" % roundi(add), Vector2(1080, 140), Pal.stat("жизнь"), 40)
			fx.ink_burst(Vector2(1080, 85), 60.0, Pal.stat("жизнь"))
			log_v.add("лечение +%d" % roundi(add), Pal.stat("жизнь"))
			sfx.play("rise", 1.4)
		"reroll":
			loadout.coins -= Formulas.reroll_cost(depth, rerolls, spend["reroll"])
			rerolls += 1
			item = ItemGen.roll(depth, rng, loot, affixes, 0, String(item.get("type", "")), int(item["rarity"]))
			_refresh_card()
			fx.ink_burst(card.position, 160.0, Pal.RARITY[int(item["rarity"])])
			card.scale = Vector2.ONE * 0.8
			_set_state(St.RISE)
			rise_from = card.position
			sfx.play("swish", 0.8)
		"sharpen":
			var slot := loadout.target_slot(item)
			loadout.coins -= Formulas.sharpen_cost(depth, loadout.rank[slot], spend["sharpen"])
			loadout.rank[slot] += 1
			panel.punch(slot)
			fx.ink_burst(panel.slot_pos.get(slot, Vector2(1100, 300)), 60.0, E.CINNABAR)
			log_v.add("заточка слота: +%d" % loadout.rank[slot], E.INK)
			_refresh_card()
			sfx.play("equip", 1.3)
		"leave":
			_close_shop()
			_spawn_enemy()
			return
	coins_shown = loadout.coins
	hud.set_coins(coins_shown, 0)
	_sync_hud()
	_refresh_actions()


func _open_shop() -> void:
	phase = "shop"
	ph_t = 0.0
	shop_used = false
	shop_items.clear()
	for n in shop_cards:
		n.queue_free()
	shop_cards.clear()
	var sc: Dictionary = spend["shop"]
	for i in int(sc["items"]):
		var it := ItemGen.roll(depth, rng, loot, affixes, int(sc["min_rarity"]))
		it["price"] = roundi(loadout.sell_price(it) * float(sc["price_mult"]))
		shop_items.append(it)
		var cv := CardView.new()
		add_child(cv)
		move_child(cv, card.get_index())
		cv.show_item(it, loadout.compare(it), Pal.RARITY_NAME[int(it["rarity"])], loadout.power(), loadout.power_if_equipped(it), loadout.resonance_change(it))
		cv.position = Vector2(470 + i * 230, 410)
		cv.scale = Vector2.ONE * 0.66
		shop_cards.append(cv)
	hud.enemy_name = ""
	hud.banner = ""
	log_v.add("— торговец: выберите предмет или уйдите", Pal.stat("алчность"))
	_refresh_actions()
	shop_overlay.queue_redraw()


func _close_shop() -> void:
	for n in shop_cards:
		n.queue_free()
	shop_cards.clear()
	shop_items.clear()
	phase = "rise"
	shop_overlay.queue_redraw()


func _buy(i: int) -> void:
	var it: Dictionary = shop_items[i]
	if loadout.coins < int(it["price"]):
		sfx.play("block", 0.6, -6.0)
		fx.float_text("не хватает монет", shop_cards[i].position + Vector2(0, -180), E.CINNABAR, 26)
		return
	loadout.coins -= int(it["price"])
	coins_shown = loadout.coins
	hud.set_coins(coins_shown, 0)
	sfx.play("coin", 0.8)
	var at: Vector2 = shop_cards[i].position
	_close_shop()
	item = it
	from_shop = true
	phase = "drop"
	rise_from = at
	swipe_enabled = true
	hud.show_hints = true
	_next_card()


func _draw_shop_overlay() -> void:
	if phase != "shop":
		return
	var o := shop_overlay
	var bold := Fonts.bold()
	for i in shop_items.size():
		var p: Vector2 = shop_cards[i].position
		var ok := loadout.coins >= int(shop_items[i]["price"])
		o.draw_string_outline(bold, p + Vector2(-110, -180), "%d монет" % int(shop_items[i]["price"]), HORIZONTAL_ALIGNMENT_CENTER, 220, 26, 6, E.PAPER_LIGHT)
		o.draw_string(bold, p + Vector2(-110, -180), "%d монет" % int(shop_items[i]["price"]), HORIZONTAL_ALIGNMENT_CENTER, 220, 26, Pal.stat("алчность") if ok else E.CINNABAR)
	o.draw_string_outline(bold, Vector2(340, 612), "торговец · щёлкните карту, чтобы купить", HORIZONTAL_ALIGNMENT_CENTER, 600, 22, 6, E.PAPER_LIGHT)
	o.draw_string(bold, Vector2(340, 612), "торговец · щёлкните карту, чтобы купить", HORIZONTAL_ALIGNMENT_CENTER, 600, 22, E.INK)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and phase in ["drop", "shop"]:
		var map := {KEY_H: "heal", KEY_E: "reroll", KEY_U: "sharpen", KEY_SPACE: "leave"}
		if map.has(e.physical_keycode):
			for a in hud.actions:
				if a["do"] == map[e.physical_keycode]:
					_do_action(a["do"])
					get_viewport().set_input_as_handled()
					return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in hud.action_rects.size():
			if hud.action_rects[i].has_point(e.position) and i < hud.actions.size():
				_do_action(hud.actions[i]["do"])
				return
		if phase == "shop":
			for i in shop_cards.size():
				var local: Vector2 = shop_cards[i].get_global_transform().affine_inverse() * e.position
				if Rect2(-CardView.SIZE / 2.0, CardView.SIZE).has_point(local):
					_buy(i)
					return
	super._unhandled_input(e)

