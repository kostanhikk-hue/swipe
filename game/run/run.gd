extends "res://run/card_stage.gd"
## The run: enemy rises from the doorway → real-time auto-battle → drop card → next enemy.
## Rules (enemies, rewards, drops, prices, vows) live in systems/run_rules.gd, shared with the
## balance simulator. Esc — pause (give up → souls are kept). Debug args: --depth=N, --seed=N,
## --demo, --cursed, --relic.

const EnemyView := preload("res://views/enemy_view.gd")
const CombatLog := preload("res://views/combat_log.gd")
const StatSheet := preload("res://views/stat_sheet.gd")
const TipView := preload("res://views/tip_view.gd")
const ENEMY_C := Vector2(640, 400)

var ct: CombatTuning
var rules: RunRules
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
var rerolls := 0
var is_boss := false
var is_elite := false
var elite_mod := {}
var last_boss := false
var last_elite := false
var shop_cards: Array = []
var shop_items: Array = []
var from_shop := false
var save := {}
var shop_overlay: Node2D
var meta := {}
var meta_speed := 1.0
var haste := 1.0
var junk := false
var run := {"kills": 0, "bosses": 0, "coins": 0, "killer": "", "relics": 0}
var onboarding := {}
var tip: Node2D
var drops_seen := 0
var paused := false


func _start() -> void:
	Engine.time_scale = 1.0
	gym_keys = false
	ct = (load("res://data/tuning/m03_combat.tres") as CombatTuning).duplicate()
	save = Save.load_data()
	best = int(save["best_depth"])
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/m08/meta.json"))
	onboarding = JSON.parse_string(FileAccess.get_file_as_string("res://data/onboarding/tips.json"))
	var vows := []
	for v in meta["vows"]:
		if v["id"] in save["vow_pick"] and Save.upgrade_level(save, "vows") > 0:
			vows.append(v)
	rules = RunRules.new(ct, vows, Save.upgrade_level(save, "forge") > 0)
	for u in meta["upgrades"]:   # M08: only speed and convenience
		var lv := Save.upgrade_level(save, u["id"])
		if lv <= 0:
			continue
		match u["id"]:
			"speed":
				meta_speed = float(u["levels"][lv - 1]["v"])
			"haste":
				haste = float(u["levels"][0]["v"])
			"junk":
				junk = bool(save["settings"].get("junk_on", true))
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
	tip = TipView.new()
	add_child(tip)
	tip.visible = false
	tpanel.bind(ct, "M03")
	tuning.rise_time /= haste if haste > 1.0 else 1.0
	loadout = Loadout.new(loadout.econ, {}, ct)   # the run starts naked (decision #27)
	panel.loadout = loadout
	panel.queue_redraw()
	_apply_clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depth="):   # debug: start deeper with a greedily collected build
			var target := int(a.get_slice("=", 1))
			for dd in range(1, target):
				var it := rules.drop(dd, rng, loadout, false, false)
				if loadout.can_equip(it) and loadout.power_if_equipped(it) > loadout.power():
					loadout.equip(it)
			loadout.coins = 0
			depth = target
	hero_hp = _hero_max()
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	if not vows.is_empty():
		log_v.add("обеты: " + ", ".join(vows.map(func(v): return String(v["name"]).to_lower())), E.CINNABAR)
	Game.music("run")
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


func _hero_fighter(hp: float) -> Dictionary:
	return Combat.hero_from(_hero_stats(), hp, ct, loadout.flags())


func _hero_max() -> float:
	return _hero_fighter(0.0)["max_hp"]


func _spawn_enemy() -> void:
	var info := rules.enemy_for(depth, rng)
	enemy_def = info["def"]
	cur_enemy = info["fighter"]
	is_boss = info["boss"]
	is_elite = info["elite"]
	elite_mod = info["mod"]
	var d := enemy_def
	enemy_v.boss = is_boss
	enemy_v.elite = is_elite
	var note := String(d.get("special", ""))
	if is_elite:
		note = "элитный, %s: %s" % [elite_mod["name"], elite_mod["text"]] + (" · " + note if note != "" else "")
	hud.enemy_note = note
	hud.actions = []
	enemy_v.set_shape(d["shape"])
	enemy_v.visible = true
	enemy_v.appear = 0.0
	var nm := String(d["name"])
	if is_boss:
		nm = "БОСС · " + nm
	elif is_elite:
		nm = "Элита · " + nm
	hud.enemy_name = "%s · %d" % [nm, depth]
	hud.enemy_hp = cur_enemy["hp"]
	hud.enemy_hp_max = cur_enemy["max_hp"]
	_sync_hud()
	_seen(String(d["id"]))
	log_v.add("— глубина %d: %s" % [depth, String(d["name"]).to_lower() if not is_boss else d["name"]], E.CINNABAR if is_boss or is_elite else E.INK_FADED)
	var every := int(rules.enemies["boss_every"])
	if not is_boss and every - depth % every <= 3:   # omen: free for everyone (was a shrine upgrade)
		var nb := LoopMath.boss_def((depth / every + 1) * every, rules.enemies)
		log_v.add("впереди %s: %s" % [nb["name"], nb["special"]], Pal.RARITY_TEXT[3])
	if is_boss:
		_tip("boss")
		Game.music("boss")
	elif depth % every == every - 3:
		_tip("boss_soon")
	elif is_elite:
		_tip("elite")
	if is_boss:
		fx.float_text("БОСС", Vector2(640, 330), E.CINNABAR, 96)
		_shake(1.5)
	elif is_elite:
		fx.float_text("ЭЛИТА", Vector2(640, 330), Pal.RARITY_TEXT[2], 70)
	sfx.play("rise", 0.5 if is_boss else (0.6 if is_elite else 0.7))
	phase = "rise"
	ph_t = 0.0


func _seen(id: String) -> void:
	if id not in save["seen"]:
		save["seen"].append(id)


func _sync_hud() -> void:
	hud.depth = depth
	hud.best = maxi(best, depth)
	hud.hp = hero_hp
	hud.hp_max = _hero_max()
	hud.queue_redraw()


func _process(delta: float) -> void:
	if paused:
		return
	super._process(delta)
	ph_t += delta
	_hand_k = maxf(0.0, _hand_k - delta * 7.0)
	hand.scale = Vector2.ONE * 0.8
	hand.position = Vector2(0, 144) + Vector2(60, -50) * sin(_hand_k * PI)
	var fighting := phase in ["rise", "fight"]
	var hf: Dictionary = combat.f["hero"] if phase == "fight" else _hero_fighter(hero_hp)
	sheet.set_data(hf, cur_enemy if fighting else {}, ct)
	match phase:
		"rise":
			var k := clampf(ph_t / (1.2 if is_boss else 0.45), 0.0, 1.0)
			enemy_v.appear = 1.0 - pow(1.0 - k, 3)
			if k >= 1.0:
				combat = rules.make_combat(_hero_fighter(hero_hp), cur_enemy, is_boss, seed_value * 1000 + depth)
				_tip("fight")
				phase = "fight"
				ph_t = 0.0
		"fight":
			var tut := haste if depth <= ct.tutorial_depth else 1.0
			for ev in combat.advance(delta * ct.fight_speed * meta_speed * tut):
				_on_event(ev)
			if phase == "fight":
				hero_hp = combat.f["hero"]["hp"]
				hud.enemy_hp = combat.f["enemy"]["hp"]
				_sync_hud()
		"death":
			if ph_t > 0.7:
				phase = "drop"
				rise_from = ENEMY_C
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
	pass   # the run demo commits from _process during the drop phase


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
				fx.float_text("−%d" % amt, ENEMY_C + Vector2(rng.randf_range(-110, 110), rng.randf_range(-150, -70)), E.CINNABAR, 66 if crit else 42)
				if crit:
					fx.ink_burst(ENEMY_C + Vector2(0, -80), 110.0, E.CINNABAR)
				log_v.add(("КРИТ −%d" if crit else "удар −%d") % amt, E.CINNABAR if crit else E.INK)
			else:
				enemy_v.lunge()
				fx.float_text("−%d" % amt, Vector2(1000, 150), E.CINNABAR, 56 if crit else 42)
				fx.ink_burst(Vector2(640, 690), 160.0, E.CINNABAR)
				log_v.add(("%s: КРИТ −%d" if crit else "%s бьёт −%d") % [foe, amt], E.CINNABAR)
			sfx.play("crit" if crit else ("hit" if by_hero else "hurt"))
			_impact(ct.crit_hitstop_ms if crit else ct.hit_hitstop_ms, ct.crit_shake_px if crit else ct.hit_shake_px)
		"block":
			var where := Vector2(1090, 140) if not by_hero else ENEMY_C + Vector2(0, -110)
			fx.float_text("блок", where, E.INK, 36)
			log_v.add("блок!" if not by_hero else "%s блокирует" % foe, E.INK_FADED)
			sfx.play("block")
		"riposte":
			fx.float_text("ответ −%d" % amt, ENEMY_C + Vector2(0, -60) if by_hero else Vector2(1000, 175), Pal.text("ответный удар"), 34)
			log_v.add(("ответный удар −%d" if by_hero else foe + " отвечает −%d") % amt, Pal.text("ответный удар"))
		"thorns":
			fx.float_text("шипы −%d" % amt, ENEMY_C + Vector2(0, -40) if by_hero else Vector2(1000, 170), Pal.text("шипы"), 30)
			log_v.add(("шипы ранят: −%d" if by_hero else "шипы врага: −%d") % amt, Pal.text("шипы"))
		"poison":
			if amt >= 1:   # src = the poisoned side
				fx.float_text("яд −%d" % amt, Vector2(1000, 180) if by_hero else ENEMY_C + Vector2(rng.randf_range(-60, 60), 20), Pal.text("яд"), 24)
		"regen":
			if by_hero and amt >= 2:
				fx.float_text("+%d" % amt, Vector2(1000, 175), Pal.text("регенерация"), 24)
		"heal":
			if amt < 1:
				return
			fx.float_text("+%d" % amt, Vector2(1090, 150) if by_hero else ENEMY_C + Vector2(60, -150), E.INK, 30)
			log_v.add(("вампиризм +%d" if by_hero else foe + " пьёт +%d") % amt, E.INK_FADED)
		"shield":
			if amt >= 1:
				fx.float_text("щит +%d" % amt, Vector2(1000, 200), Pal.text("оберег"), 24)
		"stun":
			fx.float_text("оглушён", Vector2(1000, 200), E.CINNABAR, 34)
			log_v.add("%s оглушает героя" % foe, E.CINNABAR)
		"steal":
			var lost := mini(amt, loadout.coins)
			if lost > 0:
				loadout.coins -= lost
				coins_shown = loadout.coins
				hud.set_coins(coins_shown, 0)
				fx.float_text("−%d монет" % lost, hud.coin_anchor() + Vector2(40, 30), E.CINNABAR, 26)
		"coin":
			loadout.coins += amt
			run["coins"] += amt
			coins_shown = loadout.coins
			hud.set_coins(coins_shown, 0)
		"enrage":
			fx.float_text("ЯРОСТЬ", ENEMY_C + Vector2(0, -200), E.CINNABAR, 64)
			log_v.add("%s в ярости: урон растёт с каждой секундой" % foe, E.CINNABAR)
			_shake(1.2)
		"death":
			if ev["src"] == "enemy":
				_win()
			else:
				_lose("Забег окончен")
		"timeout":
			_lose("Ярость врага")


func _impact(stop_ms: float, shake_px: float) -> void:
	if stop_ms > 0.0:
		hit_until = Time.get_ticks_msec() + int(stop_ms)
		Engine.time_scale = 0.02
		get_tree().create_timer(stop_ms / 1000.0, true, false, true).timeout.connect(func(): if not paused: Engine.time_scale = base_scale)
	shake_power = shake_px / maxf(0.5, tuning.shake_px)
	shake_left = tuning.shake_ms / 1000.0


func _win() -> void:
	_tip_done(["fight", "boss", "boss_soon", "elite"])
	var rest := float(_hero_fighter(0.0)["rest"])
	hero_hp = minf(_hero_max(), combat.f["hero"]["hp"] + _hero_max() * rules.heal_share(is_boss, rest))
	last_boss = is_boss
	last_elite = is_elite
	fx.shatter(ENEMY_C, Vector2(380, 560), 0.0, rng)
	fx.ink_burst(ENEMY_C, 220.0)
	enemy_v.visible = false
	var greed := float(_hero_fighter(0.0)["greed"])
	var c := rules.coins_for_win(depth, rng, greed, is_boss, is_elite)
	loadout.coins += c
	run["coins"] += c
	run["kills"] += 1
	if is_boss:
		run["bosses"] += 1
	coin_step = maxi(1, ceili(c / 6.0))
	fx.spray_coins(ENEMY_C, hud.coin_anchor(), 6, rng)
	log_v.add("победа за %.1f с · +%d монет" % [combat.time, c], E.INK)
	sfx.play("win")
	if is_boss:
		log_v.add("босс повержен! реликвия ждёт", Pal.RARITY_TEXT[3])
		fx.float_text("БОСС ПОВЕРЖЕН", Vector2(640, 300), Pal.RARITY_TEXT[3], 64)
		Game.music("run")
	depth += 1
	best = maxi(best, depth)
	_sync_hud()
	phase = "death"
	ph_t = 0.0


func _lose(title: String) -> void:
	hero_hp = 0.0
	_sync_hud()
	run["killer"] = String(enemy_def.get("name", ""))
	_end_run(title)


## Death or giving up: souls, record, bestiary — the run summary (M09).
func _end_run(title: String) -> void:
	var souls := floori(float(run["coins"]) * rules.souls_share(float(meta["souls_share"])))
	save["souls"] = int(save["souls"]) + souls
	save["runs"] = int(save["runs"]) + 1
	var record := depth > int(save["best_depth"])
	var best_it := ""
	var best_r := -1
	for s in Loadout.SLOTS:
		var it: Dictionary = loadout.equipped[s]
		if not it.is_empty() and int(it["rarity"]) > best_r:
			best_r = int(it["rarity"])
			best_it = it["name"]
	hud.enemy_name = ""
	hud.enemy_note = ""
	hud.banner = "%s\nглубина %d%s · рекорд %d\nубито врагов %d · боссов %d · заработано монет %d\nполучено душ +%d (всего %d)%s\nлучший предмет: %s · убийца: %s" % [title, depth,
		" — НОВЫЙ РЕКОРД" if record else "", maxi(depth, int(save["best_depth"])), run["kills"], run["bosses"], run["coins"],
		souls, int(save["souls"]), " · обеты ×%s" % str(snappedf(rules.souls_share(1.0), 0.01)).replace(".", ",") if not rules.vows.is_empty() else "",
		best_it if best_it != "" else "—", String(run["killer"]).to_lower() if run["killer"] != "" else "—"]
	hud.queue_redraw()
	log_v.add(title.to_lower(), E.CINNABAR)
	sfx.play("death")
	_shake(2.0)
	if record:
		save["best_depth"] = depth
	save["history"].push_front({"depth": depth, "kills": run["kills"], "bosses": run["bosses"], "killer": run["killer"]})
	save["history"] = save["history"].slice(0, 10)
	_tip_done(["fight", "boss", "boss_soon", "elite"])
	Save.store(save)
	phase = "dead"
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	_close_shop_cards()
	Game.music("menu")
	_tip("death")
	hud.actions = [{"key": "R", "label": "новый забег", "cost": 0, "ok": true, "do": "restart"},
		{"key": "M", "label": "в меню", "cost": 0, "ok": true, "do": "menu"}]
	hud.queue_redraw()


func _on_card_done() -> void:
	_tip_done(["drop", "compare", "sidegrade", "tags", "cursed", "coins", "relic", "undo", "ring"])
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	hero_hp = minf(hero_hp, _hero_max())
	panel.set_preview("", "", 0.0)
	_sync_hud()
	var won_depth := depth - 1
	if not from_shop and rules.shop_due(won_depth):
		_open_shop()
		return
	from_shop = false
	_spawn_enemy()


func _next_card() -> void:
	item = _pick_item()
	rerolls = 0
	if _auto_junk():
		return
	swipe_enabled = true
	hud.show_hints = true
	_show_card()
	drops_seen += 1
	var plus := false
	var minus := false
	for row in loadout.compare(item):
		var d := (0.0 if row[2] == null else float(row[2])) - (0.0 if row[1] == null else float(row[1]))
		plus = plus or d > 0.001
		minus = minus or d < -0.001
	if bool(item.get("unique", false)):
		_tip("relic")
	if bool(item.get("cursed", false)):
		_tip("cursed")
	_tip("drop")
	if drops_seen >= 2:
		_tip("compare")
	if plus and minus:
		_tip("sidegrade")
	if not (item.get("tags", []) as Array).is_empty():
		_tip("tags")
	if card.ring_hint:
		_tip("ring")
	_refresh_actions()


## Shrine "Сборщик хлама": a common item that would not raise power is sold without a card.
func _auto_junk() -> bool:
	if not junk or from_shop or depth <= 6 or int(item["rarity"]) != 0 or bool(item.get("cursed", false)):
		return false
	if loadout.can_equip(item) and loadout.power_if_equipped(item) > loadout.power():
		return false
	var price := loadout.sell(item)
	run["coins"] += price
	coins_shown = loadout.coins
	hud.set_coins(coins_shown, 0)
	fx.float_text("хлам продан +%d" % price, ENEMY_C + Vector2(0, -120), E.INK_FADED, 30)
	log_v.add("хлам: %s продан за %d" % [String(item["name"]).to_lower(), price], E.INK_FADED)
	sfx.play("coin", 0.9, -4.0)
	phase = "drop"
	_on_card_done()
	return true


func _pick_item() -> Dictionary:
	if from_shop:
		return item
	var won := depth - 1
	var gi := depth - 2   # first drop comes after the first win
	var guided: Array = onboarding["guided_drops"]
	if int(save["runs"]) < int(onboarding["guided_runs"]) and gi >= 0 and gi < guided.size():
		var g: Dictionary = guided[gi]
		return ItemGen.roll(won, rng, rules.loot, rules.affixes, 0, g["type"], 0, {"tags": g["tags"].duplicate()})
	var args := OS.get_cmdline_user_args()
	if "--relic" in args:   # debug: every drop is a relic
		return ItemGen.roll(won, rng, rules.loot, rules.affixes, 3)
	var it := rules.drop(won, rng, loadout, last_boss, last_elite)
	if "--cursed" in args:   # debug: every drop is a cursed relic
		it = ItemGen.curse(it, won, rng, rules.curses)
	if bool(it.get("unique", false)):
		run["relics"] += 1
	return it


func _on_undo() -> void:
	_refresh_actions()


func _on_undo_open() -> void:
	_tip("undo")


# ------------------------------------------------------------- M06 spends

func _refresh_actions() -> void:
	var c := loadout.coins
	var acts := []
	var heal := rules.heal_cost(depth)
	acts.append({"key": "H", "label": "лечить +%d%%" % roundi(float(rules.spend["heal"]["pct"]) * 100.0), "cost": heal, "ok": c >= heal and hero_hp < _hero_max(), "do": "heal"})
	if phase == "drop":
		var rr := rules.reroll_cost(depth, rerolls)
		acts.append({"key": "E", "label": "перебросить", "cost": rr, "ok": c >= rr and state in [St.IDLE, St.RISE], "do": "reroll"})
		var slot := loadout.target_slot(item)
		var sh := rules.sharpen_cost(depth, loadout.rank[slot])
		acts.append({"key": "U", "label": "заточить слот", "cost": sh, "ok": c >= sh and state in [St.IDLE, St.RISE], "do": "sharpen"})
	elif phase == "shop":
		acts.append({"key": "Space", "label": "уйти", "cost": 0, "ok": true, "do": "leave"})
	hud.actions = acts
	hud.queue_redraw()
	if phase == "drop" and acts.any(func(x): return x["ok"]):
		_tip("coins")


func _do_action(what: String) -> void:
	if what in ["reroll", "sharpen"] and not (phase == "drop" and swipe_enabled and state in [St.IDLE, St.RISE]):
		return
	for a in hud.actions:
		if a["do"] == what and not a["ok"]:
			sfx.play("block", 0.6, -6.0)
			return
	match what:
		"restart":
			Save.store(save)
			get_tree().reload_current_scene()
			return
		"menu":
			Save.store(save)
			get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
			return
		"heal":
			loadout.coins -= rules.heal_cost(depth)
			var add := _hero_max() * float(rules.spend["heal"]["pct"])
			hero_hp = minf(_hero_max(), hero_hp + add)
			fx.float_text("+%d" % roundi(add), Vector2(1080, 140), Pal.text("жизнь"), 40)
			fx.ink_burst(Vector2(1080, 85), 60.0, Pal.stat("жизнь"))
			log_v.add("лечение +%d" % roundi(add), Pal.text("жизнь"))
			sfx.play("rise", 1.4)
		"reroll":
			loadout.coins -= rules.reroll_cost(depth, rerolls)
			rerolls += 1
			item = rules.reroll(item, depth - 1, rng)
			_refresh_card()
			fx.ink_burst(card.position, 160.0, Pal.RARITY[int(item["rarity"])])
			card.scale = Vector2.ONE * 0.8
			_set_state(St.RISE)
			rise_from = card.position
			sfx.play("swish", 0.8)
		"sharpen":
			var slot := loadout.target_slot(item)
			loadout.coins -= rules.sharpen_cost(depth, loadout.rank[slot])
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
	_close_shop_cards()
	var sc: Dictionary = rules.spend["shop"]
	for i in int(sc["items"]):
		var it := rules.shop_item(depth, rng, loadout)
		it["price"] = roundi(loadout.sell_price(it) * float(sc["price_mult"]))
		shop_items.append(it)
		var cv := CardView.new()
		add_child(cv)
		move_child(cv, card.get_index())
		cv.show_item(it, loadout.compare(it), Pal.RARITY_NAME[int(it["rarity"])], loadout.power(), loadout.power_if_equipped(it), loadout.resonance_change(it))
		cv.position = Vector2(400 + i * 240, 410)
		cv.scale = Vector2.ONE * 0.66
		shop_cards.append(cv)
	hud.enemy_name = ""
	hud.banner = ""
	log_v.add("— торговец: выберите предмет или уйдите", Pal.text("алчность"))
	_tip("shop")
	_refresh_actions()
	shop_overlay.queue_redraw()


func _close_shop_cards() -> void:
	for n in shop_cards:
		n.queue_free()
	shop_cards.clear()
	shop_items.clear()
	shop_overlay.queue_redraw()


func _close_shop() -> void:
	_tip_done(["shop"])
	_close_shop_cards()
	phase = "rise"


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
		o.draw_string(bold, p + Vector2(-110, -180), "%d монет" % int(shop_items[i]["price"]), HORIZONTAL_ALIGNMENT_CENTER, 220, 26, Pal.text("алчность") if ok else E.CINNABAR)
	o.draw_string_outline(bold, Vector2(340, 612), "торговец · щёлкните карту, чтобы купить", HORIZONTAL_ALIGNMENT_CENTER, 600, 22, 6, E.PAPER_LIGHT)
	o.draw_string(bold, Vector2(340, 612), "торговец · щёлкните карту, чтобы купить", HORIZONTAL_ALIGNMENT_CENTER, 600, 22, E.INK)


# ------------------------------------------------------------- pause

func _set_paused(on: bool) -> void:
	paused = on
	Engine.time_scale = 0.0 if on else base_scale
	hud.banner = "Пауза\nEsc — продолжить\nM — сдаться: забег засчитан, души сохранятся" if on else ""
	hud.queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if tip.visible and e is InputEventMouseButton and e.pressed and tip.rect().has_point(e.position):
		tip.hide_tip()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		if phase == "dead":
			_do_action("menu")
		else:
			_set_paused(not paused)
		return
	if paused:
		if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_M:
			_set_paused(false)
			run["killer"] = ""
			_end_run("Забег прерван")
		return
	if e is InputEventKey and e.pressed and not e.echo and phase in ["drop", "shop", "dead"]:
		var map := {KEY_H: "heal", KEY_E: "reroll", KEY_U: "sharpen", KEY_SPACE: "leave", KEY_M: "menu", KEY_R: "restart"}
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
		if phase == "drop" and card.ring_hint:   # click a worn ring to choose which one to replace
			for r in ["ring1", "ring2"]:
				if Rect2(panel.slot_pos.get(r, Vector2(-999, -999)) - Vector2(20, 20), Vector2(200, 40)).has_point(e.position) and loadout.target_slot(item) != r:
					_toggle_ring()
					return
	super._unhandled_input(e)


func _on_sold(price: int) -> void:
	run["coins"] += price


# ------------------------------------------------------------- onboarding

func _tip(id: String) -> void:
	if not bool(save.get("tips_on", true)) or id in save["tips"] or tip.visible:
		return
	if not onboarding["tips"].has(id):
		return
	tip.show_tip(id, onboarding["tips"][id])
	save["tips"].append(id)
	Save.store(save)


func _tip_done(ids: Array) -> void:
	if tip.visible and tip.id in ids:
		tip.hide_tip()
