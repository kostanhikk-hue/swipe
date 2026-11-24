extends "res://gyms/swipe_gym.gd"
## M03 loop gym: enemy rises from the doorway → real-time auto-battle → drop card (M01) → next enemy.
## Keys as in the swipe gym; Tab = combat tuning (M03). Death → banner, R restarts the run.

const EnemyView := preload("res://views/enemy_view.gd")
const CombatLog := preload("res://views/combat_log.gd")
const StatSheet := preload("res://views/stat_sheet.gd")
const ENEMY_C := Vector2(640, 400)

var ct: CombatTuning
var enemies := {}
var loot := {}
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


func _start() -> void:
	ct = (load("res://data/tuning/m03_combat.tres") as CombatTuning).duplicate()
	enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/enemies.json"))
	loot = JSON.parse_string(FileAccess.get_file_as_string("res://data/m03/loot.json"))
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
	tpanel.bind(ct, "M03")
	_apply_clear()
	hero_hp = _hero_max()
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	_spawn_enemy()


func _clear_rects() -> Array:
	var c := super._clear_rects()
	c.append(_soft(Rect2(380, 20, 520, 134)))
	c.append(_soft(CombatLog.AREA.grow(6)))
	c.append(_soft(StatSheet.AREA.grow(8)))
	return c


func _apply_clear() -> void:
	super._apply_clear()
	if hand:
		hand.clear = back.clear
		hand.queue_redraw()


func _hero_stats() -> Dictionary:
	var s := {}
	for slot in Loadout.SLOTS:
		var st := loadout.slot_stats(slot)
		for k in st:
			s[k] = float(s.get(k, 0.0)) + st[k]
	return s


func _hero_max() -> float:
	return ct.hero_base_hp + float(_hero_stats().get("жизнь", 0.0))


func _spawn_enemy() -> void:
	var types: Array = enemies["types"]
	var d: Dictionary = types[rng.randi() % types.size()]
	enemy_def = d
	cur_enemy = LoopMath.enemy_at(d, depth, ct)
	enemy_v.set_shape(d["shape"])
	enemy_v.visible = true
	enemy_v.appear = 0.0
	hud.enemy_name = "%s · %d" % [d["name"], depth]
	hud.enemy_hp = cur_enemy["hp"]
	hud.enemy_hp_max = cur_enemy["max_hp"]
	_sync_hud()
	log_v.add("— глубина %d: %s" % [depth, d["name"]], E.INK_FADED)
	sfx.play("rise", 0.7)
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
			var k := clampf(ph_t / 0.45, 0.0, 1.0)
			enemy_v.appear = 1.0 - pow(1.0 - k, 3)
			if k >= 1.0:
				combat = Combat.new(Combat.hero_from(_hero_stats(), hero_hp, ct), cur_enemy, ct, seed_value * 1000 + depth)
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
				_next_card()
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
	hero_hp = minf(_hero_max(), combat.f["hero"]["hp"] + _hero_max() * ct.heal_after_win)
	fx.shatter(ENEMY_C, Vector2(380, 560), 0.0, rng)
	fx.ink_burst(ENEMY_C, 220.0)
	enemy_v.visible = false
	var cr: Array = enemies["coins"]
	var c := rng.randi_range(int(cr[0]), int(cr[1])) + depth
	loadout.coins += c
	coin_step = maxi(1, ceili(c / 6.0))
	fx.spray_coins(ENEMY_C, hud.coin_anchor(), 6, rng)
	log_v.add("победа за %.1f с · +%d монет" % [combat.time, c], E.INK)
	sfx.play("win")
	depth += 1
	best = maxi(best, depth)
	_sync_hud()
	phase = "death"
	ph_t = 0.0


func _lose(title: String) -> void:
	hero_hp = 0.0
	_sync_hud()
	hud.banner = "%s\nглубина %d · R — новый забег" % [title, depth]
	hud.queue_redraw()
	log_v.add(title.to_lower(), E.CINNABAR)
	sfx.play("death")
	_shake(2.0)
	phase = "dead"


func _on_card_done() -> void:
	card.visible = false
	swipe_enabled = false
	hud.show_hints = false
	hero_hp = minf(hero_hp, _hero_max())
	panel.set_preview("", "", 0.0)
	_spawn_enemy()


func _pick_item() -> Dictionary:
	return LootLite.roll(depth, rng, loot, ct.depth_loot)
