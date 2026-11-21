extends SceneTree
## Headless test of the living room's furniture (furniture_kit.gd's living-room pieces, rug.gd,
## window_curtains.gd, piano.gd) in the real level: what each takes to break and leaves, what is in the ones
## that are searched, the fireplace lit (light and boiling), the piano heard, the rug muffling footsteps and
## rolled up and laid again, and drawn curtains hiding the player from a raider. Run from a scratch copy (copy
## this file to its root):
##   godot --headless --fixed-fps 60 -s res://living_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[living] ", t)


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


func _piece(kind: String, near: Vector3) -> Breakable:
	var best: Breakable = null
	for b in get_nodes_in_group("destructible"):
		if b is Breakable and b.host != null and is_instance_valid(b.host) and str(b.host.get_meta("furniture", "")) == kind:
			if best == null or b.host.global_position.distance_to(near) < best.host.global_position.distance_to(near):
				best = b
	return best


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

	# ---- what each takes to break, and what is in the ones that hold things
	_say("rugs in the level: %d; curtains: %d" % [Rug.all.size(), get_nodes_in_group("interactables").filter(func(n): return n is WindowCurtains).size()])
	for kind in ["coffee_table", "end_table", "tv_stand", "display_cabinet", "fireplace", "piano"]:
		var b := _piece(kind, o + Vector3(3, 0, 3))
		if b == null:
			_say("%s: not found" % kind)
			continue
		_say("%-16s zombie blows %d, hatchet %d, sledgehammer %d, fists %d; it is %s" % [kind, ceili(b.hits_left(12.0, "blunt")),
			ceili(b.hits_left(30.0, "chop")), ceili(b.hits_left(60.0, "pound")), ceili(b.hits_left(6.0, "blunt")), b.feel(6.0, "blunt")])
	var tally := {}
	for kind in ["coffee_table", "end_table", "tv_stand", "display_cabinet"]:
		var tot := 0
		for i in 200:
			var probe := Stash.for_piece(kind, kind, 1, 0)
			main.add_child(probe)
			for k in probe.parts.size():
				probe._roll(probe.parts[k])
				tot += (probe.parts[k]["grid"]["things"] as Array).size()
			for t in probe.parts[0]["grid"]["things"]:
				var id: String = t["item"]["id"]
				tally[id] = int(tally.get(id, 0)) + 1
			probe.free()
		_say("%s holds about %.1f things (200 rolls)" % [kind, tot / 200.0])
	var top: Array = tally.keys()
	top.sort_custom(func(a, b): return tally[a] > tally[b])
	_say("  most often found: %s" % ", ".join(top.slice(0, 10).map(func(k): return "%s %d" % [k, tally[k]])))
	var cab := _piece("display_cabinet", o)
	var cpos := cab.host.global_position
	cab.hit(100000.0, "pound", cpos, p)
	await _wait(0.2)
	var left: Array[String] = []
	for w in get_nodes_in_group("interactables"):
		if w is Wreck and (w as Node3D).global_position.distance_to(cpos) < 2.0:
			left.append(str(w.lot))
	_say("display cabinet smashed: wreckage %s" % ", ".join(left))

	# ---- the fireplace
	var fire: Campfire = null
	for c in get_nodes_in_group("interactables"):
		if c is Campfire and (c as Node3D).global_position.distance_to(o + Vector3(3.0, 0, 5.4)) < 1.0:
			fire = c
	var fp: Vector3 = fire.global_position
	var before := Daylight.lamp_light(fp + Vector3(0, 0, -1.5))
	p.global_position = fp + Vector3(0, 0, -0.8)
	p.inv.slots["hand_l"] = Items.make("wood_scrap", 2)
	p.inv.slots["hand_r"] = Items.make("matches")
	_say("cold fireplace says: %s" % fire.prompt_text(p))
	fire.interact(p)
	_say("  then: %s" % fire.prompt_text(p))
	fire.interact(p)
	_say("  lit %s; lamp light 1.5 m out %.2f before, %.2f after; 4 m out %.2f" % [fire.lit, before, Daylight.lamp_light(fp + Vector3(0, 0, -1.5)), Daylight.lamp_light(fp + Vector3(0, 0, -4.0))])
	var wt := Items.make("water")
	wt["bugs"] = 0.5
	p.inv.slots["hand_l"] = wt
	p.inv.slots["legs:0"] = Items.make("cooking_pot")
	_say("  with water and a pot it says: %s" % fire.prompt_text(p))
	fire.interact(p)
	await _wait(21.0)
	_say("  21 s later the water is %s (bugs %.2f)" % [Water.look(wt), Water.bugs(wt)])

	# ---- the piano
	var keys: Piano = null
	for n in get_nodes_in_group("interactables"):
		if n is Piano:
			keys = n
	var kp := keys.global_position
	p.global_position = kp + Vector3(0, 0, 0.6)
	var near := _ear(kp + Vector3(24, 0, 0))
	var far := _ear(kp + Vector3(32, 0, 0))
	near._noise_t = 0.0
	far._noise_t = 0.0
	_say("piano says: %s" % keys.prompt_text(p))
	keys.interact(p)
	_say("  played: '%s'; a zombie 24 m off heard it %s, one 32 m off %s; again at once: %s" % [p.status_text, near._noise_t > 0.0, far._noise_t > 0.0, keys.can_interact(p)])
	near.queue_free()
	far.queue_free()

	# ---- the rug
	var hearth: Rug = null
	var den: Rug = null
	for r in Rug.all:
		if r.global_position.distance_to(o + Vector3(3.0, 0, 4.75)) < 0.5:
			hearth = r
		if r.global_position.distance_to(o + Vector3(4.4, 0, 1.75)) < 0.5:
			den = r
	p.global_position = hearth.global_position
	p.velocity = Vector3(2, 0, 0)
	var on := p.noise_radius()
	p.global_position = hearth.global_position + Vector3(0, 0, -2.0)
	var off := p.noise_radius()
	_say("walking: heard %.2f m on the rug, %.2f m off it" % [on, off])
	p.velocity = Vector3.ZERO
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)
	_say("hearth rug says: %s (anything on it: %s)" % [hearth.prompt_text(p), hearth._weighed_down()])
	hearth.interact(p)
	await _wait(0.1)
	var rk := p.inv.find("rolled_rug")
	_say("  rolled up: carrying %s in %s; rugs now %d" % [Items.label(p.inv.slots.get(rk, {"id": "rock", "n": 1})), rk, Rug.all.size()])
	p.global_position = o + Vector3(4.5, 0, 4.3)
	p.facing = Vector3(1, 0, 0)
	p.use_item(rk)
	await _wait(0.1)
	_say("  laid again: '%s'; rugs %d; walking where it now lies: heard %.2f m" % [p.status_text, Rug.all.size(), _noise_at(o + Vector3(5.0, 0, 4.3))])

	# ---- the curtains
	var curt: WindowCurtains = null
	for n in get_nodes_in_group("interactables"):
		if n is WindowCurtains and (n as Node3D).global_position.distance_to(o + Vector3(1.5, 1.4, 5.9)) < 0.6:
			curt = n
	var r := Raider.new()
	r.position = o + Vector3(1.5, 0, 12.0)
	main.add_child(r)
	r.set_physics_process(false)
	r.set_process(false)
	r.player = p
	r.facing = Vector3(0, 0, -1)
	p.global_position = o + Vector3(1.5, 0, 5.0)
	p.velocity = Vector3.ZERO
	await _wait(0.3)
	curt.set_drawn(true)
	await _wait(0.1)
	var seen_drawn: bool = r._can_see_player()
	var eye_drawn := p.line_clear(r.global_position + Vector3(0, 1.5, 0))
	curt.set_drawn(false)
	await _wait(0.1)
	var seen_open: bool = r._can_see_player()
	var eye_open := p.line_clear(r.global_position + Vector3(0, 1.5, 0))
	_say("raider 7 m outside the south window, player 1 m in: curtains drawn, he sees the player %s, the player sees him %s; open, %s and %s" % [seen_drawn, eye_drawn, seen_open, eye_open])
	curt.set_drawn(true)
	await _wait(0.1)
	var shot := p.line_clear(r.global_position + Vector3(0, 1.5, 0), Vector3.INF, [], 1)
	_say("  with them drawn, a shot's line to him is clear: %s" % shot)
	_say("  curtains say: %s" % curt.prompt_text(p))
	r.queue_free()
	quit()


func _noise_at(at: Vector3) -> float:
	p.global_position = at
	p.velocity = Vector3(2, 0, 0)
	var n := p.noise_radius()
	p.velocity = Vector3.ZERO
	return n
