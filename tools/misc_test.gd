extends SceneTree
## Headless test of the living room's odds and ends (items.gd's misc session; marbles.gd; the candle and toy
## robot in appliance.gd) in the real level: what lies about and what turns up searching; books and records
## thrown (noise, how far, picked up again); magazines made into a forearm guard and the bites it stops; the
## poker prising boards; the remote's batteries; marbles tripping zombies, a raider and you; a candle's light
## without power; the toy robot leading a zombie off. Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://misc_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[misc] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _empty_hands() -> void:
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)


func _zombie(at: Vector3, still := true) -> Enemy:
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = at
	main.add_child(z)
	z.player = p
	if still:
		z.set_physics_process(false)
		z.set_process(false)
	z._drive = 0.0
	return z


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
	p.invulnerable = true
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	if Horde.it != null:
		Horde.it.set_process(false)
		Horde.it.set_physics_process(false)
	await _wait(0.2)
	var o := Vector3(18, 0, -34)

	# ---- what lies about, and what searching the living room turns up
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and (n.title == "By the fireplace" or n.title == "On the mantelpiece"):
			_say("%s: %s" % [n.title, ", ".join((n.contents as Array).map(func(it): return Items.label(it)))])
	var mine := ["book", "vinyl_record", "magazine", "trophy", "tv_remote", "marbles", "candle", "toy_robot", "radio"]
	var tally := {}
	var rolls := 0
	for kind in ["bookshelf", "coffee_table", "end_table", "tv_stand", "display_cabinet"]:
		for i in 100:
			var probe := Stash.for_piece(kind, kind, 1, 0)
			main.add_child(probe)
			for part in probe.parts:
				probe._roll(part)
				for t in part["grid"]["things"]:
					var id: String = t["item"]["id"]
					if mine.has(id):
						tally[id] = int(tally.get(id, 0)) + 1
			probe.free()
			rolls += 1
	_say("searching the living room's furniture, %d searches: %s" % [rolls, ", ".join(tally.keys().map(func(k): return "%s %d" % [k, tally[k]]))])

	# ---- throwing indoors: a book, a record
	p.global_position = Vector3(-6, 0, 20)
	p.facing = Vector3(0, 0, 1)
	_empty_hands()
	p.inv.slots["hand_l"] = Items.make("book")
	var book_reach := p.throw_range()
	p.inv.slots["hand_l"] = Items.make("vinyl_record")
	var rec_reach := p.throw_range()
	p.inv.slots["hand_l"] = Items.make("rock")
	_say("throw reach at Strength %d: rock %.1f m, book %.1f m, record %.1f m" % [int(p.strength), p.throw_range(), book_reach, rec_reach])
	_empty_hands()
	p.inv.slots["hand_l"] = Items.make("book")
	var ear := _zombie(Vector3(-6, 0, 33))
	var far := _zombie(Vector3(-6, 0, 38))
	ear._noise_t = 0.0
	far._noise_t = 0.0
	p.weapon = "throw"
	p.armed = true
	p.reticle_offset = Vector3(0, 0, 8)
	p._throw()
	await _wait(1.6)
	var landed: ItemPickup = null
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and n.title == "Hardback book":
			landed = n
	_say("a book thrown 8 m: it lies there to pick up: %s (%.1f m off); a zombie 5 m from where it landed heard it %s, one 10 m off %s" % [
		landed != null, landed.global_position.distance_to(p.global_position) if landed != null else -1.0, ear._noise_t > 0.0, far._noise_t > 0.0])
	ear.queue_free()
	far.queue_free()
	if landed != null:
		landed.queue_free()

	# ---- magazines round a forearm
	_empty_hands()
	p.inv.slots["hand_l"] = Items.make("magazine", 4)
	p.use_item("hand_l")
	_say("magazines, nothing to tie them with: '%s'" % p.status_text)
	p.inv.slots["hand_r"] = Items.make("cloth_strip", 2)
	p.use_item("hand_l")
	_say("  with a strip of cloth: '%s'; left wrist: %s" % [p.status_text, Items.name_of(p.inv.worn["wrist_l"]["id"]) if p.inv.worn.has("wrist_l") else "-"])
	p.use_item("hand_l")
	_say("  again: '%s'; right wrist: %s; magazines left %s, strips left %s" % [p.status_text,
		Items.name_of(p.inv.worn["wrist_r"]["id"]) if p.inv.worn.has("wrist_r") else "-", p.inv.slots.get("hand_l", {}).get("n", 0), p.inv.slots.get("hand_r", {}).get("n", 0)])
	var stopped := 0
	var bare := 0
	for i in 200:
		var worn := {"wrist_l": Items.make("magazine_bracer"), "undershirt": Items.make("t_shirt")}
		if not (Clothes.meet(worn, "ArmL", "bite", p._body.body_kind)["stopped"] as Dictionary).is_empty():
			stopped += 1
		var tee := {"undershirt": Items.make("t_shirt")}
		if not (Clothes.meet(tee, "ArmL", "bite", p._body.body_kind)["stopped"] as Dictionary).is_empty():
			bare += 1
	_say("  bites on the left arm stopped, out of 200: in a t-shirt %d; with the magazine guard %d (it covers the forearm only)" % [bare, stopped])
	var g := Items.make("magazine_bracer")
	var bites := 0
	while bites < 60:
		var w := {"wrist_l": g}
		Clothes.meet(w, "ArmL", "bite", p._body.body_kind)
		bites += 1
		if float(g.get("tatter", 0.0)) >= 0.99:
			break
	_say("  a guard on its own took %d bites on the arm before it was in tatters (tatter %.2f)" % [bites, float(g.get("tatter", 0.0))])

	# ---- the poker at a boarded window
	_empty_hands()
	var win := {}
	for w in Solid.windows:
		var wp: Vector3 = w["pos"]
		if wp.y < 2.0 and Vector2(wp.x - o.x - 1.5, wp.z - o.z - 6.0).length() < 0.6:
			win = w
	Solid.board(win)
	p.global_position = Vector3((win["pos"] as Vector3).x, 0.0, (win["pos"] as Vector3).z - 0.7)
	p.reticle_offset = Vector3(0, 0, 0.7)
	p.inv.slots["hand_r"] = Items.make("fire_poker")
	var t0 := Time.get_ticks_msec()
	p.work_window()
	var took := 0.0
	while p._work != "" and took < 12.0:
		await _wait(0.1)
		took += 0.1
	_say("a boarded window prised with the fire poker: %.1f s (a crowbar takes %.1f); boards gone %s; planks back %s" % [took, p.pry_time,
		not (win["boards"] != null and is_instance_valid(win["boards"]) and win["boards"].alive()), p.inv.has("plank")])
	_say("  the poker: %s" % Items.about("fire_poker"))
	_say("  the trophy: %s" % Items.about("trophy"))

	# ---- the remote's batteries
	_empty_hands()
	p.inv.slots["hand_l"] = Items.make("tv_remote")
	p.take_apart("hand_l")
	await _wait(2.5)
	_say("the remote taken apart: %s" % ", ".join(p.inv.slots.values().map(func(it): return Items.label(it))))

	# ---- marbles
	_empty_hands()
	p.global_position = Vector3(-10, 0, 24)
	p.facing = Vector3(1, 0, 0)
	p.inv.slots["hand_l"] = Items.make("marbles")
	p.use_item("hand_l")
	var mb: Marbles = Marbles.all[0]
	_say("marbles scattered: '%s' at %.1f m" % [p.status_text, mb.global_position.distance_to(p.global_position)])
	var fell := 0
	for i in 40:
		var z := _zombie(mb.global_position + Vector3(0.2, 0, 0))
		z.facing = Vector3(-1, 0, 0)
		if Marbles.step_on(mb.global_position, z) and z.state == "down":
			fell += 1
		z.free()
	var ears := _zombie(mb.global_position + Vector3(4.5, 0, 0))
	var deaf := _zombie(mb.global_position + Vector3(7.0, 0, 0))
	ears._noise_t = 0.0
	deaf._noise_t = 0.0
	mb._quiet = 0.0
	var walker := _zombie(mb.global_position + Vector3(0.1, 0, 0))
	Marbles.step_on(mb.global_position, walker)
	_say("  40 zombies stepping on them: %d went down; the rattle was heard 4.5 m off %s, 7 m off %s" % [fell, ears._noise_t > 0.0, deaf._noise_t > 0.0])
	walker.queue_free()
	ears.queue_free()
	deaf.queue_free()
	var r := Raider.new()
	r.position = mb.global_position
	main.add_child(r)
	r.set_physics_process(false)
	r.set_process(false)
	var rs := 0
	for i in 40:
		if Marbles.step_on(mb.global_position, r):
			rs += 1
	_say("  a raider stepping on them 40 times stumbled %d times (slowed %.1f s)" % [rs, r._glass_t])
	r.queue_free()
	var walk_slips := 0
	var run_slips := 0
	var crouch_slips := 0
	for i in 100:
		p.posture = 0
		p._stagger = 0.0
		p.velocity = Vector3(p.walk_speed, 0, 0)
		if Marbles.step_on(mb.global_position, p):
			walk_slips += 1
		p.posture = 0
		p.velocity = Vector3(p.walk_speed * 1.8, 0, 0)
		if Marbles.step_on(mb.global_position, p):
			run_slips += 1
		p.posture = 1
		p.velocity = Vector3(p.walk_speed * 0.5, 0, 0)
		if Marbles.step_on(mb.global_position, p):
			crouch_slips += 1
	p.posture = 0
	p.velocity = Vector3.ZERO
	_say("  you, 100 strides each: walking slipped %d, running %d (and went flat), crouched %d" % [walk_slips, run_slips, crouch_slips])
	p.global_position = mb.global_position
	_empty_hands()
	mb.interact(p)
	await _wait(0.1)
	_say("  gathered up: '%s'; carrying marbles %s; piles left %d" % [p.status_text, p.inv.has("marbles"), Marbles.all.size()])

	# ---- a candle, with the power off
	Power.set_on(false)
	_empty_hands()
	p.global_position = o + Vector3(4.5, 0, 4.3)
	p.facing = Vector3(1, 0, 0)
	p.inv.slots["hand_l"] = Items.make("candle")
	p.use_item("hand_l")
	_say("a candle and no match: '%s'" % p.status_text)
	p.inv.slots["hand_r"] = Items.make("matches")
	p.use_item("hand_l")
	await _wait(0.1)
	var cd: Appliance = null
	for n in get_nodes_in_group("interactables"):
		if n is Appliance and n.kind == "candle" and n.working():
			cd = n
	_say("  with a match: '%s'; lit %s with the power off; light 0.5 m off %.2f, 1.5 m %.2f, 2.5 m %.2f" % [p.status_text, cd != null and cd.working(),
		Daylight.lamp_light(cd.global_position + Vector3(0.5, 0, 0)), Daylight.lamp_light(cd.global_position + Vector3(1.5, 0, 0)), Daylight.lamp_light(cd.global_position + Vector3(2.5, 0, 0))])
	cd.item["uses"] = 2
	await _wait(3.0)
	_say("  burned down (2 s left): gone %s; light where it stood %.2f" % [not is_instance_valid(cd) or cd.is_queued_for_deletion(), Daylight.lamp_light(o + Vector3(5.0, 0, 4.3))])
	Power.set_on(true)

	# ---- the toy robot leads a zombie off
	_empty_hands()
	var start := Vector3(-14, 0, 28)
	p.global_position = start
	p.facing = Vector3(0, 0, 1)
	var toy := Items.make("toy_robot")
	toy["uses"] = 120
	p.inv.slots["hand_l"] = toy
	p.use_item("hand_l")
	await _wait(0.1)
	var bot: Appliance = null
	for n in get_nodes_in_group("interactables"):
		if n is Appliance and n.kind == "toy_robot":
			bot = n
	_say("toy robot set down: '%s'; working %s" % [p.status_text, bot.working()])
	p.global_position = Vector3(-40, 0, 40)
	var at0 := bot.global_position
	var fz := _zombie(start + Vector3(7.0, 0, 0), false)
	var t := 0.0
	var caught := -1.0
	while t < 60.0 and is_instance_valid(bot) and bot.br.alive():
		await _wait(0.5)
		t += 0.5
	if not is_instance_valid(bot) or not bot.br.alive():
		caught = t
	_say("  a zombie 7 m off: it caught and smashed the robot at %.1f s, %.1f m from where it was set down; the zombie is %.1f m from where it started" % [caught,
		(fz.global_position - at0).length() if caught >= 0.0 else -1.0, fz.global_position.distance_to(start + Vector3(7.0, 0, 0))])
	fz.queue_free()
	var bot2 := Appliance.set_down(main, {"id": "toy_robot", "uses": 40}, Vector3(-20, 0, 30), Vector3(1, 0, 0))
	var a0 := bot2.global_position
	var path := 0.0
	var last := a0
	for i in 30:
		await _wait(1.0)
		if not is_instance_valid(bot2):
			break
		path += bot2.global_position.distance_to(last)
		last = bot2.global_position
	_say("  left alone with 40 s of batteries: walked %.1f m, ends %.1f m from its start, still going %s" % [path, last.distance_to(a0), is_instance_valid(bot2) and bot2.working()])
	quit()
