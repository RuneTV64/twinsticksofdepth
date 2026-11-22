extends SceneTree
## Headless test of the living room's appliances (appliance.gd, power.gd) in the real level: what each takes to
## break, the television's light and voice and the zombie that comes to it and smashes it, the power going off
## (houses and street lamps), lamps picked up and stood again (and dead outdoors), the radio as a decoy and its
## batteries, the phone ringing and answered and its cord pulled, a lamp falling when its table goes. Run from a
## scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://appliance_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[appliance] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _ear(at: Vector3) -> Enemy:
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = at
	main.add_child(z)
	z.player = p
	z.set_physics_process(false)
	z.set_process(false)
	z._drive = 0.0
	return z


func _all(kind: String) -> Array[Appliance]:
	var out: Array[Appliance] = []
	for n in get_nodes_in_group("interactables"):
		if n is Appliance and n.kind == kind and is_instance_valid(n):
			out.append(n)
	return out


func _shift(down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SHIFT
	e.physical_keycode = KEY_SHIFT
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	if Horde.it != null:
		Horde.it.set_process(false)
		Horde.it.set_physics_process(false)
	await _wait(0.2)
	var o := Vector3(18, 0, -34)
	var counts := []
	for k in Appliance.KINDS:
		counts.append("%s %d" % [k, _all(k).size()])
	_say("in the level: %s; breakable things %d" % [", ".join(counts), get_nodes_in_group("destructible").size()])

	# ---- what each takes to break
	for k in Appliance.KINDS:
		if _all(k).is_empty():
			continue                                  # (a toy robot lies about only as an item)
		var a: Appliance = _all(k)[0]
		_say("%-11s zombie blows %d, fists %d, hatchet %d; it is %s" % [k, ceili(a.br.hits_left(12.0, "blunt")),
			ceili(a.br.hits_left(4.0, "blunt")), ceili(a.br.hits_left(30.0, "chop")), a.br.feel(4.0, "blunt")])

	# ---- the television: light, voice, and the zombie it brings
	var tv: Appliance = _all("television")[0]
	var tp := tv.global_position
	p.global_position = tp + Vector3(-1.2, -tp.y, 0.0)
	_say("television says: %s" % tv.prompt_text(p))
	var before := Daylight.lamp_light(tp + Vector3(-1.5, 0, 0))
	tv.interact(p)
	_say("  switched on: '%s'; working %s; lamp light 1.5 m in front %.2f before, %.2f now, 3 m %.2f" % [p.status_text, tv.working(),
		before, Daylight.lamp_light(tp + Vector3(-1.5, 0, 0)), Daylight.lamp_light(tp + Vector3(-3.0, 0, 0))])
	_say("  now it says: %s" % tv.prompt_text(p))
	var near := _ear(tp + Vector3(-11.0, -tp.y, 0.0))
	var far := _ear(tp + Vector3(-14.0, -tp.y, 0.0))
	near._noise_t = 0.0
	far._noise_t = 0.0
	await _wait(5.5)
	_say("  over 5.5 s: a zombie 11 m off heard it %s, one 14 m off %s" % [near._noise_t > 0.0, far._noise_t > 0.0])
	near.queue_free()
	far.queue_free()
	# Night: standing in front of it you are lit.
	var was_level := Daylight.level
	Daylight.level = 0.0
	Daylight.want = 0.0
	p.global_position = tp + Vector3(-1.4, -tp.y, 0.0)
	_say("  at night, standing 1.4 m in front of it: light on you %.2f, seen from %.2f of the daytime distance (off: see below)" % [Daylight.at(p.global_position), p.seen_mult()])
	tv.interact(p)
	_say("  switched off: light on you %.2f, seen from %.2f" % [Daylight.at(p.global_position), p.seen_mult()])
	Daylight.level = was_level
	Daylight.want = was_level

	# ---- the power going off
	tv.interact(p)
	var lamp_spot := Vector3.INF
	for l in Daylight.lamps:
		var lp: Vector3 = l["pos"]
		if lp.distance_to(tp) > 6.0:
			lamp_spot = lp
			break
	var n_lamps := Daylight.lamps.size()
	Power.set_on(false)
	await _wait(0.1)
	_say("power off: television working %s, says '%s'; lamps in the level %d -> %d" % [tv.working(), tv.prompt_text(p), n_lamps, Daylight.lamps.size()])
	Power.set_on(true)
	await _wait(0.1)
	_say("power back: television working %s; lamps %d" % [tv.working(), Daylight.lamps.size()])
	tv.interact(p)

	# ---- zombies come to it and smash it
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = o + Vector3(3.6, 0, 2.4)            # across the den from it (there is no path finding: from
	                                                 # outside it would have to blunder in through a window)
	main.add_child(z)
	z.player = p
	p.global_position = Vector3(-30, 0, 30)          # far off and out of the way
	tv.interact(p)
	var t := 0.0
	var reached := -1.0
	while t < 60.0 and is_instance_valid(tv) and tv.br.alive():
		await _wait(0.5)
		t += 0.5
		if reached < 0.0 and z.global_position.distance_to(Vector3(tp.x, 0, tp.z)) < 1.6:
			reached = t
	_say("a zombie across the den with the television on: reached it at %.1f s; the set %s at %.1f s" % [reached,
		"was smashed" if not is_instance_valid(tv) or not tv.br.alive() else "still stands", t])
	await _wait(6.0)
	_say("  6 s later the zombie is %.1f m from where the set stood, drive %.0f" % [z.global_position.distance_to(Vector3(tp.x, 0, tp.z)), z._drive])
	z.queue_free()
	var wr: Array[String] = []
	for w in get_nodes_in_group("interactables"):
		if w is Wreck and (w as Node3D).global_position.distance_to(tp) < 1.5:
			wr.append(str(w.lot))
	_say("  wreckage: %s" % ", ".join(wr))

	# ---- the floor lamp: on, picked up, stood again, and outdoors
	var fl: Appliance = _all("floor_lamp")[0]
	var fp := fl.global_position
	p.global_position = fp + Vector3(-0.6, 0, -0.6)
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)
	fl.interact(p)
	_say("floor lamp switched on: working %s, light 1 m off %.2f, 4 m %.2f" % [fl.working(), Daylight.lamp_light(fp + Vector3(-1, 0, 0)), Daylight.lamp_light(fp + Vector3(-4, 0, 0))])
	_shift(true)
	fl.interact(p)
	_shift(false)
	await _wait(0.1)
	var lk := p.inv.find("floor_lamp")
	_say("  Shift+click: '%s'; carrying it in %s; light where it stood %.2f" % [p.status_text, lk, Daylight.lamp_light(fp + Vector3(-1, 0, 0))])
	_say("  as a weapon: %s" % Items.about("floor_lamp"))
	p.global_position = o + Vector3(4.5, 0, 4.3)
	p.facing = Vector3(1, 0, 0)
	p.use_item(lk)
	await _wait(0.1)
	var fl2: Appliance = _all("floor_lamp")[0]
	_say("  used: '%s'; it stands at %s" % [p.status_text, fl2.global_position - o])
	fl2.interact(p)
	_say("  switched on there: working %s" % fl2.working())
	_shift(true)
	fl2.interact(p)
	_shift(false)
	await _wait(0.1)
	p.global_position = o + Vector3(4.5, 0, 12.0)            # out in the yard
	p.use_item(p.inv.find("floor_lamp"))
	await _wait(0.1)
	var fl3: Appliance = _all("floor_lamp")[0]
	fl3.interact(p)
	_say("  stood out in the yard and switched on: '%s'; working %s" % [p.status_text, fl3.working()])

	# ---- the radio: a decoy on batteries
	var rd: Appliance = _all("radio")[0]
	p.global_position = rd.global_position + Vector3(0, -rd.global_position.y, 0.7)
	_shift(true)
	rd.interact(p)
	_shift(false)
	var rk := p.inv.find("radio")
	_say("radio picked up from the coffee table: %s (%d s of batteries)" % [Items.label(p.inv.slots[rk]), int(p.inv.slots[rk]["uses"])])
	p.inv.slots[rk]["uses"] = 40
	p.inv.slots["legs:0"] = Items.make("battery", 2)
	p.load_battery()
	_say("  batteries in: '%s'; now %d s" % [p.status_text, int(p.inv.slots[rk]["uses"])])
	var spot := Vector3(-6, 0, 20)
	p.global_position = spot
	p.facing = Vector3(0, 0, 1)
	p.use_item(rk)
	await _wait(0.1)
	var r2: Appliance = _all("radio")[0]
	_say("  set down in the open: '%s'; working %s" % [p.status_text, r2.working()])
	p.global_position = Vector3(-40, 0, 40)
	var zs: Array[Enemy] = []
	for i in 3:
		var zz := Enemy.new()
		zz.kind = "shambler"
		zz.position = spot + Vector3(16.0, 0, -4.0 + i * 4.0)
		main.add_child(zz)
		zz.player = p
		zs.append(zz)
	t = 0.0
	var uses0 := int(r2.item["uses"])
	while t < 90.0 and is_instance_valid(r2) and r2.br.alive():
		await _wait(0.5)
		t += 0.5
	_say("  three zombies 16 m off: the radio %s at %.1f s (it had played %d s of its batteries)" % [
		"was smashed" if not is_instance_valid(r2) or not r2.br.alive() else "still plays", t, uses0 - (int(r2.item["uses"]) if is_instance_valid(r2) else uses0 - int(t))])
	for zz in zs:
		zz.queue_free()
	# Flat batteries: it stops by itself.
	var r3 := Appliance.set_down(main, {"id": "radio", "uses": 3}, Vector3(-6, 0, 26), Vector3(0, 0, 1))
	await _wait(1.0)
	var w1 := r3.working()
	await _wait(3.5)
	_say("  a radio with 3 s left: playing %s at 1 s, %s at 4.5 s; it says '%s'" % [w1, r3.working(), r3.prompt_text(p)])

	# ---- the phone
	var ph: Appliance = _all("telephone")[0]
	var pp := ph.global_position
	p.global_position = pp + Vector3(-0.8, -pp.y, 0)
	_say("phone says: %s" % ph.prompt_text(p))
	ph.interact(p)
	_say("  picked up: '%s'" % p.status_text)
	var ez := _ear(pp + Vector3(-13.0, -pp.y, 0))
	ez._noise_t = 0.0
	ph.ring()
	await _wait(3.2)
	_say("  it rings: ringing %s, says '%s'; a zombie 13 m off heard it %s" % [ph.ringing(), ph.prompt_text(p), ez._noise_t > 0.0])
	ez.queue_free()
	ph.interact(p)
	_say("  answered: '%s'; ringing %s" % [p.status_text, ph.ringing()])
	var rings := 0
	for i in 200:
		ph._rings = 0
		ph._ring_t = 0.0
		ph._phone(0.01)
		if ph.ringing():
			rings += 1
	_say("  left alone with you near: it rang %d times in 200 chances (%.0f s each: about once in %.1f minutes)" % [rings, Appliance.RING_CHECK, 200.0 * Appliance.RING_CHECK / maxf(rings, 1) / 60.0])
	ph._rings = 0
	_shift(true)
	ph.interact(p)
	_shift(false)
	ph.ring()
	_say("  Shift+click: '%s'; carrying a cord %s; rung again: ringing %s; says '%s'" % [p.status_text, p.inv.find("electric_cord") != "", ph.ringing(), ph.prompt_text(p)])
	_say("  the cord: %s" % Items.about("electric_cord"))

	# ---- the table lamp falls when its table goes
	var tl: Appliance = _all("table_lamp")[0]
	var side: Breakable = null
	for b in Breakable.near(Vector2(tl.global_position.x, tl.global_position.z), 0.5):
		if b.host != null and str(b.host.get_meta("furniture", "")) == "end_table":
			side = b
	var y0 := tl.global_position.y
	side.give_way(p)
	await _wait(0.2)
	_say("side table broken under the table lamp: it was at %.2f m; now %s" % [y0,
		"at %.2f m" % tl.global_position.y if is_instance_valid(tl) and tl.br.alive() else "smashed on the floor"])

	# ---- a worn-out house's appliance is dead, and stays dead carried
	var dead := Appliance.put(main, "radio", Vector3(-8, 0, 30), "S", 2)
	p.global_position = Vector3(-8, 0, 30.7)
	_shift(true)
	dead.interact(p)
	_shift(false)
	var dk := p.inv.find("radio")
	p.use_item(dk)
	await _wait(0.1)
	_say("a worn-out radio carried off and set down: '%s'" % p.status_text)
	quit()
