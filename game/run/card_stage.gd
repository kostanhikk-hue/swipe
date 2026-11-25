extends Node2D
## Drop card + swipe (M01): ← sell, → equip, ↑ melt (sharpen slot). Base of the run (run/run.gd);
## alone it is the M01 gym (scenes/gyms/swipe_gym.tscn).
## Keys: A/D/W or arrows · Z undo a costly decision · Q other ring · R restart (gym) · Tab tuning ·
## O overlay · T slow-mo ×0.25 · 1/2 presets.
## Args: --seed=N, --overlay, --demo (scripted drags for capture).

const E := preload("res://scripts/engrave.gd")
const DungeonView := preload("res://views/dungeon_view.gd")
const CardView := preload("res://views/card_view.gd")
const BuildPanel := preload("res://views/build_panel.gd")
const HudView := preload("res://views/hud_view.gd")
const FxView := preload("res://views/fx_view.gd")
const SfxNode := preload("res://views/sfx.gd")
const TuningPanel := preload("res://debug/tuning_panel.gd")
const HOME := Vector2(640, 400)
const DOOR_C := Vector2(640, 280)
const UNDO_TIME := 1.6   # s to take back a costly decision (sold a rare, equipped a worse item)
const PRESET_B := {"threshold_x": 130.0, "fling_speed": 700.0, "max_tilt_deg": 18.0, "hitstop_ms": 90.0,
	"shake_px": 14.0, "punch_scale": 1.35}

enum St { RISE, IDLE, DRAG, RETURN, HIT, FLY_EQUIP, FLY_SELL, GONE }

var tuning: SwipeTuning
var loadout: Loadout
var items := {}
var rng := RandomNumberGenerator.new()
var seed_value := 7
var deck_i := 0
var item: Dictionary = {}

var state := St.RISE
var st_t := 0.0
var grab := Vector2.ZERO
var vel := Vector2.ZERO
var decision := 0
var fly_from := Vector2.ZERO
var fly_slot := ""
var hit_until := 0
var shake_left := 0.0
var shake_power := 1.0
var coins_shown := 0
var coin_step := 0
var base_scale := 1.0
var input_frame := -1
var react_frames := -1
var _preset_a := {}
var _demo := false
var _demo_t := 0.0
var _demo_step := 0
var swipe_enabled := true      # the run turns swipes off during fights
var rise_from := DOOR_C
var undo_snap := {}            # loadout state before the last decision
var undo_open := false         # a costly decision can still be taken back
var gym_keys := true           # R/T/1/2/O debug keys (off in the real run)

var back: Node2D
var front: Node2D
var hud: Node2D
var panel: Node2D
var card: Node2D
var fx: Node2D
var cam: Camera2D
var sfx: Node
var tpanel: CanvasLayer
var overlay: Label


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
		elif a == "--demo":
			_demo = true
	tuning = (load("res://data/tuning/m01_swipe.tres") as SwipeTuning).duplicate()
	for p in tuning.get_property_list():
		if p["hint"] == PROPERTY_HINT_RANGE:
			_preset_a[p["name"]] = tuning.get(p["name"])
	items = JSON.parse_string(FileAccess.get_file_as_string("res://data/m01/items.json"))
	var econ: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/m01/economy.json"))
	loadout = Loadout.new(econ, items["start"])
	rng.seed = seed_value

	back = DungeonView.new()
	front = DungeonView.new()
	front.layer = "front"
	hud = HudView.new()
	panel = BuildPanel.new()
	panel.loadout = loadout
	card = CardView.new()
	fx = FxView.new()
	for n in [back, front, hud, panel, card, fx]:
		add_child(n)
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	sfx = SfxNode.new()
	add_child(sfx)
	tpanel = TuningPanel.new()
	add_child(tpanel)
	tpanel.bind(tuning, "M01")
	var ol := CanvasLayer.new()
	ol.layer = 90
	add_child(ol)
	overlay = Label.new()
	overlay.position = Vector2(30, 130)
	overlay.add_theme_color_override("font_color", E.INK)
	overlay.add_theme_color_override("font_outline_color", E.PAPER_LIGHT)
	overlay.add_theme_constant_override("outline_size", 6)
	overlay.visible = "--overlay" in OS.get_cmdline_user_args()
	ol.add_child(overlay)
	fx.coin_arrived.connect(_on_coin)
	_apply_clear()
	_start()


func _start() -> void:
	_next_card()


func _clear_rects() -> Array:
	var c := [_soft(Rect2(36, 40, 330, 66)), _soft(Rect2(930, 40, 314, 66)), _soft(BuildPanel.PANEL.grow(8)),
		_soft(Rect2(290, 642, 280, 38)), _soft(Rect2(770, 642, 240, 38))]
	if tuning.melt_enabled > 0.5:
		c.append(_soft(Rect2(480, 104, 320, 34)))
	return c


func _apply_clear() -> void:
	hud.melt_on = tuning.melt_enabled > 0.5
	var c := _clear_rects()
	back.clear = c
	front.clear = c
	back.queue_redraw()
	front.queue_redraw()
	hud.queue_redraw()


# ------------------------------------------------------------- flow

func _pick_item() -> Dictionary:
	var deck: Array = items["deck"]
	deck_i += 1
	return deck[(deck_i - 1) % deck.size()]


func _on_card_done() -> void:
	_next_card()


func _refresh_card() -> void:
	card.locked = not loadout.can_equip(item)
	card.trade_in = 0 if card.locked else loadout.trade_in_value(item)
	var both_rings: bool = item.get("slot", "") == "ring" and not loadout.equipped["ring1"].is_empty() and not loadout.equipped["ring2"].is_empty() \
		and not loadout.is_locked("ring1") and not loadout.is_locked("ring2")
	card.ring_hint = both_rings
	if both_rings:
		var ts := loadout.target_slot(item)
		card.ring_name = String(loadout.equipped[ts]["name"]) + (" (1)" if ts == "ring1" else " (2)")
	var pa := loadout.power() if card.locked else loadout.power_if_equipped(item)
	card.show_item(item, loadout.compare(item), Pal.RARITY_NAME[int(item["rarity"])],
		loadout.power(), pa, "" if card.locked else loadout.resonance_change(item),
		[loadout.parts(), loadout.parts() if card.locked else loadout.parts_if_equipped(item)])


func _next_card() -> void:
	item = _pick_item()
	_show_card()


func _show_card() -> void:
	_refresh_card()
	card.visible = true
	card.position = rise_from
	card.scale = Vector2.ONE * 0.25
	card.rotation = 0.0
	_set_state(St.RISE)
	sfx.play("rise", 1.0, -6.0)


func _set_state(s: int) -> void:
	state = s
	st_t = 0.0


func _commit(dec: int, v: Vector2) -> void:
	if dec == Swipe.MELT and tuning.melt_enabled < 0.5:
		return
	if dec == Swipe.EQUIP and not loadout.can_equip(item):   # M05: cursed slot
		fx.float_text("слот проклят", card.position + Vector2(0, -260), E.CINNABAR, 34)
		sfx.play("block", 0.6)
		_set_state(St.RETURN)
		return
	undo_snap = _snapshot(dec)
	decision = dec
	vel = v
	react_frames = Engine.get_process_frames() - input_frame if input_frame >= 0 else -1
	card.set_stamp(dec, 1.0)
	panel.set_preview("", "", 0.0)
	hud.set_coins(coins_shown, 0)
	fx.ink_burst(card.position, 120.0, E.CINNABAR if dec == Swipe.MELT else E.INK)
	sfx.play("swish", 1.1)
	_shake(0.5)
	hit_until = Time.get_ticks_msec() + int(tuning.hitstop_ms)
	Engine.time_scale = 0.02
	_set_state(St.HIT)


func _after_hit() -> void:
	Engine.time_scale = base_scale
	undo_open = _costly(decision)
	if undo_open:
		_on_undo_open()
	match decision:
		Swipe.EQUIP:
			fly_slot = loadout.target_slot(item)
			fly_from = card.position
			_set_state(St.FLY_EQUIP)
		Swipe.SELL:
			var price := loadout.sell(item)
			_on_sold(price)
			var n := clampi(price / 3, 5, 16)
			coin_step = maxi(1, ceili(price / float(n)))
			fx.spray_coins(card.position, hud.coin_anchor(), n, rng)
			fx.float_text("+%d" % price, card.position + Vector2(0, -60), E.INK, 44)
			vel = Vector2(minf(vel.x, -tuning.exit_speed_min), vel.y * 0.5 - 200.0)
			_set_state(St.FLY_SELL)
		Swipe.MELT:
			var before := loadout.power()
			var slot := loadout.melt(item)
			fx.shatter(card.position, CardView.SIZE * card.scale, card.rotation, rng)
			card.visible = false
			var sp: Vector2 = panel.slot_pos.get(slot, BuildPanel.PANEL.get_center())
			fx.ink_burst(sp, 70.0, E.CINNABAR)
			fx.float_text("+%d%% к слоту" % roundi(float(loadout.econ["melt_bonus"]) * 100.0), sp + Vector2(-60, -10), E.CINNABAR, 26)
			fx.float_text("+%d сила" % roundi(loadout.power() - before), card.position, E.INK, 40)
			panel.punch(slot)
			sfx.play("melt")
			_shake(1.4)
			_set_state(St.GONE)


func _on_sold(_price: int) -> void:
	pass


func _on_coin() -> void:
	coins_shown = mini(coins_shown + coin_step, loadout.coins)
	hud.set_coins(coins_shown, 0)
	hud.punch_coins()
	sfx.play("coin", 1.0 + 0.04 * (coins_shown % 7), -4.0)
	if not fx.coins.size():
		coins_shown = loadout.coins
		hud.set_coins(coins_shown, 0)


func _shake(power: float) -> void:
	shake_power = power
	shake_left = tuning.shake_ms / 1000.0


# ------------------------------------------------------------- frame

func _process(delta: float) -> void:
	st_t += delta
	if _demo:
		_run_demo(delta)
	match state if swipe_enabled else -1:
		St.RISE:
			var k := clampf(st_t / tuning.rise_time, 0.0, 1.0)
			var e := 1.0 + 2.2 * pow(k - 1.0, 3) + 1.2 * pow(k - 1.0, 2)   # ease-out-back
			card.position = rise_from.lerp(HOME, e)
			card.scale = Vector2.ONE * lerpf(0.25, 1.0, e)
			if k >= 1.0:
				_set_state(St.IDLE)
		St.IDLE:
			card.position = HOME + Vector2(0, sin(st_t * 2.0) * 2.0)
		St.DRAG:
			card.scale = card.scale.lerp(Vector2.ONE * 1.04, 0.3)
		St.RETURN:
			card.position = card.position.lerp(HOME, 1.0 - exp(-delta * 5.0 / tuning.return_time))
			card.scale = card.scale.lerp(Vector2.ONE, 0.3)
			if card.position.distance_to(HOME) < 1.0:
				_set_state(St.IDLE)
		St.HIT:
			if Time.get_ticks_msec() >= hit_until:
				_after_hit()
		St.FLY_EQUIP:
			var k := clampf(st_t / tuning.equip_fly_time, 0.0, 1.0)
			var target: Vector2 = panel.slot_pos.get(fly_slot, BuildPanel.PANEL.get_center())
			card.position = fly_from.lerp(target, k * k)
			card.scale = Vector2.ONE * lerpf(1.0, 0.1, k * k)
			card.rotation = lerpf(card.rotation, 0.0, 0.3)
			if k >= 1.0:
				var before := loadout.power()
				loadout.equip(item)
				card.visible = false
				panel.punch(fly_slot)
				fx.ink_burst(target, 60.0)
				var dp := loadout.power() - before
				fx.float_text(("+%d сила" if dp >= 0 else "−%d сила") % absi(roundi(dp)), target + Vector2(-90, -20), E.INK if dp >= 0 else E.CINNABAR, 30)
				if loadout.last_refund > 0:
					_on_sold(loadout.last_refund)
					coin_step = maxi(1, ceili(loadout.last_refund / 5.0))
					fx.spray_coins(target, hud.coin_anchor(), 5, rng)
					fx.float_text("+%d за старое" % loadout.last_refund, target + Vector2(-110, 14), E.INK_FADED, 22)
				sfx.play("equip")
				_shake(1.0)
				_set_state(St.GONE)
		St.FLY_SELL:
			vel += Vector2(0, 1800) * delta
			card.position += vel * delta
			card.rotation -= 6.0 * delta
			if st_t > 0.45:
				card.visible = false
				_set_state(St.GONE)
		St.GONE:
			if undo_open:
				hud.undo_hint = clampf(1.0 - st_t / UNDO_TIME, 0.0, 1.0)
				hud.queue_redraw()
			if st_t > (UNDO_TIME if undo_open else 0.3):
				_close_undo()
				_on_card_done()
	if swipe_enabled and state in [St.DRAG, St.RETURN, St.IDLE]:
		_update_lean()
	# camera shake with quadratic decay
	if shake_left > 0.0:
		shake_left -= delta
		var k := maxf(0.0, shake_left / maxf(0.001, tuning.shake_ms / 1000.0))
		cam.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * tuning.shake_px * shake_power * k * k * Game.shake()
	else:
		cam.offset = Vector2.ZERO
	if overlay.visible:
		_update_overlay()


func _update_lean() -> void:
	var off: Vector2 = card.position - HOME
	if state != St.IDLE:
		card.rotation = deg_to_rad(clampf(off.x / tuning.threshold_x, -1.6, 1.6) * tuning.max_tilt_deg)
	var dir := Swipe.direction(off, Vector2.ZERO, tuning) if off.length() > 6.0 else Swipe.NONE
	var p := Swipe.progress(off, tuning)
	card.set_stamp(dir, p)
	var show := tuning.preview > 0.5 and p > 0.15
	var slot := loadout.target_slot(item)
	if show and dir == Swipe.EQUIP and loadout.can_equip(item):
		panel.set_preview(slot, "%s → %s" % [BuildPanel.SLOT_NAMES[slot], item["name"]], loadout.power_if_equipped(item) - loadout.power())
	elif show and dir == Swipe.MELT:
		var warn := " · проклятие тоже" if loadout.is_locked(slot) else ""
		panel.set_preview(slot, "%s: +1 заточка (+%d%%)%s" % [BuildPanel.SLOT_NAMES[slot], roundi(float(loadout.econ["melt_bonus"]) * 100.0), warn], loadout.power_if_melted(item) - loadout.power())
	else:
		panel.set_preview("", "", 0.0)
	hud.set_coins(coins_shown, loadout.sell_price(item) if show and dir == Swipe.SELL else 0)


# ------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode in [KEY_Z, KEY_BACKSPACE] and undo_open and state == St.GONE:
			_undo()
			return
		if e.physical_keycode == KEY_Q and card.ring_hint and swipe_enabled and state in [St.IDLE, St.RISE, St.RETURN]:
			_toggle_ring()
			return
		if gym_keys:
			_gym_key(e.physical_keycode)
	var ready_state := swipe_enabled and state in [St.IDLE, St.RISE, St.RETURN]
	if ready_state:
		var k := tuning.exit_speed_min
		if e.is_action_pressed("swipe_left"):
			input_frame = Engine.get_process_frames()
			_commit(Swipe.SELL, Vector2(-k, 0))
		elif e.is_action_pressed("swipe_right"):
			input_frame = Engine.get_process_frames()
			_commit(Swipe.EQUIP, Vector2(k, 0))
		elif e.is_action_pressed("swipe_up") and tuning.melt_enabled > 0.5:
			input_frame = Engine.get_process_frames()
			_commit(Swipe.MELT, Vector2(0, -k))
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and ready_state and _hit_card(e.position):
			_begin_drag(e.position)
		elif not e.pressed and state == St.DRAG:
			_release()
	elif e is InputEventMouseMotion and state == St.DRAG:
		_drag_to(e.position, e.velocity)


func _gym_key(k: int) -> void:
	match k:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_O:
			overlay.visible = not overlay.visible
		KEY_T:
			base_scale = 0.25 if base_scale == 1.0 else 1.0
			Engine.time_scale = base_scale
		KEY_1:
			_apply_preset(_preset_a)
		KEY_2:
			_apply_preset(PRESET_B)


# ------------------------------------------------------------- undo and rings

## Costly = easy to regret: selling or melting a rare+ item, equipping something that lowers power.
func _costly(dec: int) -> bool:
	var r := int(item.get("rarity", 0))
	match dec:
		Swipe.SELL, Swipe.MELT:
			return r >= 2
		Swipe.EQUIP:
			return loadout.power_if_equipped(item) < loadout.power() * 0.97
	return false


func _snapshot(dec: int) -> Dictionary:
	return {"equipped": loadout.equipped.duplicate(), "rank": loadout.rank.duplicate(), "coins": loadout.coins,
		"item": item, "dec": dec, "ring_pick": loadout.ring_pick}


func _undo() -> void:
	var snap := undo_snap
	var gained := loadout.coins - int(snap["coins"])
	loadout.equipped = snap["equipped"]
	loadout.rank = snap["rank"]
	loadout.coins = snap["coins"]
	loadout.ring_pick = snap["ring_pick"]
	if gained != 0:
		_on_sold(-gained)
	coins_shown = loadout.coins
	hud.set_coins(coins_shown, 0)
	fx.coins.clear()
	_close_undo()
	panel.queue_redraw()
	item = snap["item"]
	_refresh_card()
	card.visible = true
	card.rotation = 0.0
	card.scale = Vector2.ONE * 0.6
	rise_from = HOME + Vector2(0, 40)
	_set_state(St.RISE)
	fx.float_text("отменено", HOME + Vector2(0, -280), E.INK, 34)
	sfx.play("swish", 0.7)
	_on_undo()


func _on_undo() -> void:
	pass


func _on_undo_open() -> void:
	pass


func _close_undo() -> void:
	undo_open = false
	hud.undo_hint = 0.0
	hud.queue_redraw()


func _toggle_ring() -> void:
	var cur := loadout.target_slot(item)
	loadout.ring_pick = "ring2" if cur == "ring1" else "ring1"
	_refresh_card()
	panel.punch(loadout.ring_pick)
	sfx.play("grab", 1.2, -6.0)


func _hit_card(p: Vector2) -> bool:
	var local: Vector2 = card.get_global_transform().affine_inverse() * p
	return Rect2(-CardView.SIZE / 2.0, CardView.SIZE).has_point(local)


func _begin_drag(p: Vector2) -> void:
	grab = card.position - p
	vel = Vector2.ZERO
	sfx.play("grab", 1.0, -8.0)
	_set_state(St.DRAG)


func _drag_to(p: Vector2, v: Vector2) -> void:
	card.position = p + grab
	vel = vel.lerp(v, 0.5)


func _release() -> void:
	input_frame = Engine.get_process_frames()
	var dec := Swipe.decide(card.position - HOME, vel, tuning)
	if dec == Swipe.NONE:
		_set_state(St.RETURN)
	else:
		_commit(dec, vel)


func _apply_preset(d: Dictionary) -> void:
	for k in d:
		tuning.set(k, d[k])
	if tpanel.visible:
		tpanel.refresh()
	_apply_clear()
	fx.float_text("пресет " + ("A" if d == _preset_a else "B"), Vector2(640, 600), E.INK, 26)


# ------------------------------------------------------------- debug

func _update_overlay() -> void:
	var off: Vector2 = card.position - HOME
	overlay.text = "fps %d\n%s  off %d,%d  vel %d,%d\nлинейка %.0f px · реакция %d кадр.\nseed %d  ×%.2f" % [
		Engine.get_frames_per_second(), St.keys()[state], off.x, off.y, vel.x, vel.y,
		tuning.threshold_x, react_frames, seed_value, base_scale]


## Scripted drags for capture: equip (slow, preview visible), sell (flick), melt.
func _run_demo(delta: float) -> void:
	_demo_t += delta
	var plan := [
		[0.6, "grab"], [0.6, 1.3, Vector2(150, -15)], [1.4, "release", Vector2(1300, 0)],
		[2.6, "grab"], [2.6, 3.0, Vector2(-120, 25)], [3.05, "release", Vector2(-1600, 100)],
		[4.4, "grab"], [4.4, 5.0, Vector2(15, -175)], [5.1, "release", Vector2(0, -400)]]
	while _demo_step < plan.size():
		var s: Array = plan[_demo_step]
		if s.size() == 2 and _demo_t >= s[0]:
			if state in [St.IDLE, St.RISE, St.RETURN]:
				_begin_drag(card.position)
			_demo_step += 1
		elif s.size() == 3 and s[1] is String and _demo_t >= s[0]:
			if state == St.DRAG:
				vel = s[2]
				_release()
			_demo_step += 1
		elif s.size() == 3 and s[1] is float:
			if _demo_t >= s[0] and state == St.DRAG:
				var k := clampf((_demo_t - s[0]) / (s[1] - s[0]), 0.0, 1.0)
				card.position = HOME + (s[2] as Vector2) * k
				if k >= 1.0:
					_demo_step += 1
				break
			elif _demo_t >= s[1]:
				_demo_step += 1
			else:
				break
		else:
			break


func _soft(r: Rect2) -> PackedVector2Array:
	var g := RandomNumberGenerator.new()
	g.seed = int(r.position.x * 7 + r.position.y)
	var pts := PackedVector2Array()
	var c := r.get_center()
	for i in 28:
		var d := Vector2.from_angle(TAU * i / 28.0)
		var k := 1.0 / maxf(absf(d.x) / (r.size.x * 0.5), absf(d.y) / (r.size.y * 0.5))
		pts.append(c + d * k * g.randf_range(0.97, 1.12))
	return pts
