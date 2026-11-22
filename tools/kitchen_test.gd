extends SceneTree
## Headless test of the kitchen theme (22 Nov 2026), session by session, in the real level. Run from a scratch
## copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://kitchen_test.gd
## PART=1..4 runs one session's part only (left out: all of them).

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[kitchen] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _empty() -> void:
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


func _part(n: int) -> bool:
	var want := OS.get_environment("PART")
	return want == "" or int(want) == n


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
	if _part(1):
		await _cloth()
	if _part(2):
		await _furniture()
	if _part(3):
		await _appliances()
	if _part(4):
		await _odds()
	quit()


# ---------------------------------------------------------------------------------------- 1: cloth
func _cloth() -> void:
	# What turns up in a kitchen's drawers and cupboards.
	var tally := {}
	for i in 200:
		var probe := Stash.for_piece("counter", "counter", 1, 0)
		main.add_child(probe)
		for part in probe.parts:
			probe._roll(part)
			for t in part["grid"]["things"]:
				var id: String = t["item"]["id"]
				if ["apron", "oven_mitts", "tea_towel"].has(id):
					tally[id] = int(tally.get(id, 0)) + 1
		probe.free()
	_say("200 kitchen counters searched: %s" % str(tally))
	# The apron: a pocket, and it meets what comes from in front.
	_empty()
	p.inv.slots["hand_l"] = Items.make("apron")
	p.use_item("hand_l")
	_say("apron on: '%s'; slots now include %s" % [p.status_text, str(p.inv.slot_list().map(func(s): return s[1]).filter(func(n): return n == "Apron pocket"))])
	var bare := 0
	var apron := 0
	for i in 400:
		var tee := {"undershirt": Items.make("t_shirt")}
		if not (Clothes.meet(tee, "Torso", "cut", p._body.body_kind)["stopped"] as Dictionary).is_empty():
			bare += 1
		var w := {"outer": Items.make("apron"), "undershirt": Items.make("t_shirt")}
		if not (Clothes.meet(w, "Torso", "cut", p._body.body_kind)["stopped"] as Dictionary).is_empty():
			apron += 1
	_say("  cuts to the body stopped out of 400: t-shirt %d, with the apron over it %d (front only)" % [bare, apron])
	# Oven mitts: glass, bites on the hand, and clumsy aim.
	var aim0 := p.sheet.aim_mult
	p.inv.slots["hand_r"] = Items.make("oven_mitts")
	p.use_item("hand_r")
	p.sheet._rebuild()
	_say("oven mitts on: '%s'; aim %.2f -> %.2f; hand guard against a cut %.2f" % [p.status_text, aim0, p.sheet.aim_mult, p.hand_guard("cut")])
	var cuts_bare := 0
	var cuts_mitts := 0
	p.invulnerable = false
	for i in 2:
		var mitts = p.inv.worn.get("hands")
		if i == 0:
			p.inv.worn.erase("hands")
		else:
			p.inv.worn["hands"] = Items.make("oven_mitts")
		for j in 60:
			var before := p.sheet.body.wounds.size()
			var spot := Vector3(-24.0 + (j % 10) * 2.0, 0, 16.0 + int(j / 10) * 2.0 + i * 13.0)     # a heap of its own each time
			var w := Wreck.leave(main, spot, 0.4, {"glass": 1.0}, 0.5, "broken glass")
			await process_frame
			p.global_position = spot
			_empty()
			w.interact(p)
			if p.sheet.body.wounds.size() > before:
				if i == 0:
					cuts_bare += 1
				else:
					cuts_mitts += 1
			if is_instance_valid(w):
				w.queue_free()
	_say("  broken glass picked up 60 times: cut bare-handed %d times, in oven mitts %d" % [cuts_bare, cuts_mitts])
	var bites_bare := 0
	var bites_mitts := 0
	for i in 400:
		if (Clothes.meet({}, "ArmR", "bite", p._body.body_kind)["stopped"] as Dictionary).is_empty():
			bites_bare += 1
		if (Clothes.meet({"hands": Items.make("oven_mitts")}, "ArmR", "bite", p._body.body_kind)["stopped"] as Dictionary).is_empty():
			bites_mitts += 1
	_say("  bites on the right arm that got through, out of 400: bare %d, in oven mitts %d (they cover the hand and wrist)" % [bites_bare, bites_mitts])
	# The tea towel: two clean rags.
	_empty()
	p.inv.worn.erase("hands")
	p._worn_changed()
	p.invulnerable = true
	p.sheet.body.wounds.clear()
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(-6, 0, 20)
	await _wait(0.5)
	p.inv.slots["hand_l"] = Items.make("tea_towel")
	p.take_apart("hand_l")
	_say("  tearing the tea towel: '%s'" % p.status_text)
	await _wait(2.5)
	p.sheet._rebuild()
	_say("  then: '%s', stagger %.2f, pos %s" % [p.status_text, p._stagger, p.global_position])
	_say("a tea towel torn in two: %s; aim back to %.2f with the mitts off" % [", ".join(p.inv.slots.values().map(func(it): return Items.label(it))), p.sheet.aim_mult])


# ---------------------------------------------------------------------------------------- 2: furniture
func _piece(kind: String) -> Breakable:
	for b in get_nodes_in_group("destructible"):
		if b is Breakable and b.host != null and is_instance_valid(b.host) and str(b.host.get_meta("furniture", "")) == kind:
			return b
	return null


func _furniture() -> void:
	for kind in ["sink", "pantry", "wall_cabinet", "kitchen_bin"]:
		var b := _piece(kind)
		if b == null:
			_say("%s: not in the level" % kind)
			continue
		var c := Cover.box_of(b.host)
		_say("%-13s zombie blows %d, fists %d, hatchet %d; cover: %s; stands %.2f to %.2f m" % [kind, ceili(b.hits_left(12.0, "blunt")),
			ceili(b.hits_left(6.0, "blunt")), ceili(b.hits_left(30.0, "chop")), "none" if c == null else ("high" if c.top > 1.5 else "low"), b.foot, b.top])
	for kind in ["sink", "pantry", "wall_cabinet", "kitchen_bin"]:
		var tot := 0
		var seen := {}
		for i in 200:
			var probe := Stash.for_piece(kind, kind, 1, 0)
			main.add_child(probe)
			for part in probe.parts:
				probe._roll(part)
				for t in part["grid"]["things"]:
					tot += 1
					var id: String = t["item"]["id"]
					seen[id] = int(seen.get(id, 0)) + 1
			probe.free()
		var top: Array = seen.keys()
		top.sort_custom(func(a, b): return seen[a] > seen[b])
		_say("%s holds about %.1f things (200 rolls); most often: %s" % [kind, tot / 200.0, ", ".join(top.slice(0, 6).map(func(k): return "%s %d" % [k, seen[k]]))])
	# The tap.
	var tap: WaterSource = null
	for n in get_nodes_in_group("interactables"):
		if n is WaterSource and n.mains:
			tap = n
	_empty()
	var bottle := Items.make("water")
	bottle["dirt"] = 0.7
	bottle["bugs"] = 0.9
	bottle["uses"] = 0                     # drunk dry: what is left in it is the pond's
	p.inv.slots["hand_l"] = bottle
	p.global_position = Vector3(tap.global_position.x, 0, tap.global_position.z)
	_say("at the tap: '%s'" % tap.prompt_text(p))
	tap.interact(p)
	_say("  filled a bottle of pond water at it: '%s' (dirt %.2f, bugs %.2f)" % [p.status_text, Water.dirt(bottle), Water.bugs(bottle)])
	Power.set_on(false)
	_say("  mains off: '%s'" % tap.prompt_text(p))
	tap.interact(p)
	_say("  '%s'" % p.status_text)
	Power.set_on(true)


# ---------------------------------------------------------------------------------------- 3: appliances
func _app(kind: String) -> Appliance:
	for n in get_nodes_in_group("interactables"):
		if n is Appliance and n.kind == kind and is_instance_valid(n):
			return n
	return null


func _appliances() -> void:
	for kind in ["kettle", "microwave", "dishwasher"]:
		var a := _app(kind)
		if a == null:
			# The dishwasher is searched through itself: its Stash is out of the interactables.
			for b in get_nodes_in_group("destructible"):
				if b is Breakable and b.host != null and str(b.host.get_meta("appliance", "")) == kind:
					for c in b.host.get_children():
						if c is Appliance:
							a = c
		if a == null:
			_say("%s: not in the level" % kind)
			continue
		_say("%-10s zombie blows %d, fists %d; it says '%s'" % [kind, ceili(a.br.hits_left(12.0, "blunt")), ceili(a.br.hits_left(6.0, "blunt")), a.prompt_text(p)])
	# The kettle boils pond water.
	var k := _app("kettle")
	_empty()
	var bottle := Items.make("water")
	bottle["dirt"] = 0.7
	bottle["bugs"] = 0.9
	p.inv.slots["hand_l"] = bottle
	p.global_position = Vector3(k.global_position.x, 0, k.global_position.z + 0.7)
	var ear := _zombie(k.global_position + Vector3(0, -k.global_position.y, 3.5))
	ear._noise_t = 0.0
	k.interact(p)
	_say("kettle: '%s'; bottle left %d washes; kettle says '%s'" % [p.status_text, int(bottle["uses"]), k.prompt_text(p)])
	await _wait(31.0)
	_say("  31 s later: '%s'; a zombie 3.5 m off heard it %s" % [k.prompt_text(p), ear._noise_t > 0.0])
	ear.queue_free()
	k.interact(p)
	_say("  poured back: '%s' (dirt %.2f, bugs %.2f, %d washes)" % [p.status_text, Water.dirt(bottle), Water.bugs(bottle), int(bottle["uses"])])
	# The microwave: a timed ding, and a bang with a tin in it.
	var m := _app("microwave")
	var near := _zombie(m.global_position + Vector3(0, -m.global_position.y, 14.0))
	var far := _zombie(m.global_position + Vector3(0, -m.global_position.y, 19.0))
	near._noise_t = 0.0
	far._noise_t = 0.0
	m.interact(p)
	_say("microwave: '%s'" % p.status_text)
	await _wait(19.0)
	_say("  19 s: '%s'; heard by a zombie 14 m off yet: %s" % [m.prompt_text(p), near._noise_t > 0.0])
	await _wait(1.5)
	_say("  it dinged: a zombie 14 m off heard it %s, one 19 m off %s" % [near._noise_t > 0.0, far._noise_t > 0.0])
	near._noise_t = 0.0
	far._noise_t = 0.0
	p.inv.slots["hand_r"] = Items.make("scrap_metal")
	_shift(true)
	m.interact(p)
	_shift(false)
	_say("  with scrap metal: '%s'" % p.status_text)
	await _wait(21.0)
	_say("  20 s later the microwave is %s; the zombie 19 m off heard the bang %s" % ["gone" if not is_instance_valid(m) or not m.br.alive() else "still there", far._noise_t > 0.0])
	near.queue_free()
	far.queue_free()
	# The dishwasher: searched, and run.
	var d: Appliance = null
	for b in get_nodes_in_group("destructible"):
		if b is Breakable and b.host != null and str(b.host.get_meta("appliance", "")) == "dishwasher":
			for c in b.host.get_children():
				if c is Appliance:
					d = c
	var st := d._stash()
	_say("dishwasher: racks %s; it says '%s'" % [st.parts.map(func(pt): return pt["name"]), d.prompt_text(p)])
	var dz := _zombie(d.global_position + Vector3(8.0, -d.global_position.y, 0))
	dz._noise_t = 0.0
	_shift(true)
	d.interact(p)
	_shift(false)
	await _wait(10.0)
	_say("  run: '%s'; 10 s on, a zombie 8 m off heard it %s; it says '%s'" % [p.status_text, dz._noise_t > 0.0, d.prompt_text(p)])
	dz.queue_free()
	Power.set_on(false)
	_say("  mains off: working %s" % d.working())
	Power.set_on(true)


# ---------------------------------------------------------------------------------------- 4: odds and ends
func _odds() -> void:
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and (n.title == "Knife block" or n.title == "On the stove"):
			_say("%s: %s" % [n.title, ", ".join((n.contents as Array).map(func(it): return Items.label(it)))])
	for id in ["kitchen_knife", "meat_cleaver", "frying_pan", "rolling_pin", "plate"]:
		_say("  %s: %s" % [id, Items.about(id)])
	# Blows to put a fresh zombie down, aimed at the head (the same reckoning as melee_test).
	for id in ["kitchen_knife", "meat_cleaver", "frying_pan", "rolling_pin"]:
		var h: Dictionary = Items.hit_of(id)
		var z := _zombie(Vector3(-20, 0, 24))
		var blows := 0
		while not z.dead and blows < 40:
			z.take_blow("Head", float(h["force"]) * p.melee_mult, str(h["kind"]), Vector3(0, 0, 1))
			blows += 1
		_say("  %s: a fresh zombie down in %d blows to the head (it lasts %d blows, %.2f s a swing)" % [id, blows, int(h["lasts"]), float(h["time"])])
		z.queue_free()
	# A knife opens a tin, and the tin is kept.
	_empty()
	p.inv.slots["hand_l"] = Items.make("canned_food", 2)
	p.inv.slots["hand_r"] = Items.make("kitchen_knife")
	p.sheet.set_need("food", 30.0)
	p.eat()
	_say("a tin and a knife, no opener: '%s'; food %.0f; carrying %s" % [p.status_text, float(p.sheet.needs["food"]), ", ".join(p.inv.slots.values().map(func(it): return Items.label(it)))])
	# A pan boils water on a fire.
	var fire: Campfire = null
	for c in get_nodes_in_group("interactables"):
		if c is Campfire and (c as Campfire).kept:
			fire = c
	_empty()
	var bottle := Items.make("water")
	bottle["bugs"] = 0.6
	p.inv.slots["hand_l"] = bottle
	p.inv.slots["hand_r"] = Items.make("frying_pan")
	p.global_position = fire.global_position + Vector3(0.8, 0, 0)
	_say("at a fire with a frying pan and no pot: '%s'" % fire.prompt_text(p))
	fire.interact(p)
	await _wait(21.0)
	_say("  21 s later: bugs %.2f ('%s')" % [Water.bugs(bottle), Water.look(bottle)])
	# Bleach in water.
	_empty()
	var b2 := Items.make("water")
	b2["bugs"] = 0.6
	p.inv.slots["hand_l"] = b2
	p.inv.slots["hand_r"] = Items.make("bleach")
	p.use_item("hand_r")
	_say("bleach in a bottle: '%s'" % p.status_text)
	await _wait(61.0)
	_say("  a minute later: bugs %.2f; bleach left %d" % [Water.bugs(b2), int(p.inv.slots["hand_r"]["uses"])])
	# A plate thrown: a smash, and glass where it landed.
	_empty()
	p.global_position = Vector3(-6, 0, 20)
	p.facing = Vector3(0, 0, 1)
	p.inv.slots["hand_l"] = Items.make("plate", 2)
	var ear := _zombie(Vector3(-6, 0, 40))
	ear._noise_t = 0.0
	p.weapon = "throw"
	p.armed = true
	p.reticle_offset = Vector3(0, 0, 9)
	p._throw()
	await _wait(1.6)
	p.armed = false
	var glass := 0
	for w in Wreck.all:
		if is_instance_valid(w) and w.global_position.distance_to(Vector3(-6, 0, 29)) < 1.5 and w.lot.has("glass"):
			glass = w.left("glass")
	_say("a plate thrown 9 m: glass lying where it landed %d; a zombie 11 m from there heard it %s" % [glass, ear._noise_t > 0.0])
	ear.queue_free()
	# The kitchen timer: set down, it rings 30 s later.
	_empty()
	p.inv.slots["hand_l"] = Items.make("kitchen_timer")
	p.global_position = Vector3(-10, 0, 26)
	p.use_item("hand_l")
	var tm: Appliance = null
	for n in get_nodes_in_group("interactables"):
		if n is Appliance and n.kind == "kitchen_timer":
			tm = n
	var near := _zombie(tm.global_position + Vector3(13.0, 0, 0))
	var far := _zombie(tm.global_position + Vector3(18.0, 0, 0))
	near._noise_t = 0.0
	far._noise_t = 0.0
	p.global_position = Vector3(-40, 0, 40)
	_say("kitchen timer set down: '%s'; it says '%s'" % [p.status_text, tm.prompt_text(p)])
	await _wait(25.0)
	var early := near._noise_t > 0.0
	await _wait(6.0)
	_say("  rang at 30 s: heard at 13 m %s (not before: %s), at 18 m %s; it says '%s'" % [near._noise_t > 0.0, not early, far._noise_t > 0.0, tm.prompt_text(p)])
	near.queue_free()
	far.queue_free()
	# Tins strung across a doorway.
	_empty()
	p.global_position = Vector3(-14, 0, 22)
	p.facing = Vector3(1, 0, 0)
	p.inv.slots["hand_l"] = Items.make("empty_tin", 3)
	p.inv.slots["hand_r"] = Items.make("cloth_strip")
	p.use_item("hand_l")
	_say("tins strung: '%s'; alarms %d" % [p.status_text, TinAlarm.all.size()])
	var ta: TinAlarm = TinAlarm.all[0]
	var lis := _zombie(ta.global_position + Vector3(0, 0, 10.0))
	lis._noise_t = 0.0
	var walker := _zombie(ta.global_position + Vector3(0.1, 0, 0.2))
	TinAlarm.step_on(walker.global_position, walker)
	_say("  a zombie walks through it: one 10 m off heard the rattle %s" % (lis._noise_t > 0.0))
	walker.queue_free()
	lis.queue_free()
	p.global_position = ta.global_position
	ta.interact(p)
	await _wait(0.1)
	_say("  taken down: '%s'; carrying %s" % [p.status_text, ", ".join(p.inv.slots.values().map(func(it): return Items.label(it)))])
