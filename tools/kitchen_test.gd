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
