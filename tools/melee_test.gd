extends SceneTree
## Headless test of held weapons and taking things apart (items.gd `hit` and `apart`, player.gd wield(),
## wear_weapon(), take_apart(); enemy.gd take_blow()), in the real level. Run from a scratch copy (copy this file
## to its root):
##   godot --headless --fixed-fps 60 -s res://melee_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[melee] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## A zombie that stands where it is put, as fresh as asked (1 fresh, 0 long rotted).
func _zombie(at: Vector3, fresh: float) -> Enemy:
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = at
	main.add_child(z)
	z.player = p
	z.set_physics_process(false)
	z.set_process(false)
	z._drive = 0.0
	z.knockdown_chance = 0.2
	z.body.shambler.freshness.value = fresh
	z.body.refresh()
	z._new_zombie(false)
	z.set_physics_process(false)
	return z


func _hold(id: String, other := "") -> void:
	p.inv.slots.erase("hand_r")
	p.inv.slots.erase("hand_l")
	p.inv.slots["hand_r"] = Items.make(id)
	if other != "":
		p.inv.slots["hand_l"] = Items.make(other)


## Swing at it with what is in hand, the real way (p._punch() starts it, p._land_punch() lands it), aimed at
## `part` as if the crosshair were on it, until it dies or `cap` swings. Returns [swings, seconds, what broke].
func _fight(z: Enemy, part: String, cap: int) -> Array:
	var swings := 0
	var t := 0.0
	var broke := ""
	var had := str(p.inv.slots.get("hand_r", {}).get("id", ""))
	while not z.dead and swings < cap:
		p.stamina = p.max_stamina
		p.winded = false
		p._fire_cd = 0.0
		p._punch()
		swings += 1
		t += p._swing_total
		p.hover_target = z
		p.hover_part = part
		p._land_punch()
		p._swing_t = 0.0
		await physics_frame
		var now := str(p.inv.slots.get("hand_r", {}).get("id", ""))
		if broke == "" and now != had:
			broke = "%s after %d (now holding: %s)" % [had, swings, now if now != "" else "nothing"]
	return [swings, t, broke]


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
	p.set_physics_process(false)       # the tests drive the swing by hand; nothing else moves the player
	p.global_position = Vector3(0, 0, 20)
	p.facing = Vector3(0, 0, -1)
	p.armed = true
	p.weapon = "fists"

	# ---- the list
	var weapons: Array[String] = []
	var aparts: Array[String] = []
	for id: String in Items.DEFS:
		if Items.DEFS[id].has("hit"):
			weapons.append(id)
		if Items.DEFS[id].has("apart"):
			aparts.append(id)
	_say("%d items; weapons in hand: %s" % [Items.DEFS.size(), ", ".join(weapons)])
	_say("  come apart: %s" % ", ".join(aparts))
	_say("  hatchet reads: %s" % Items.about("hatchet"))
	_say("  bottle reads: %s" % Items.about("bottle"))

	# ---- blows to put a zombie down, the real swing, Strength 10, aimed at the head and at the body
	var spot := p.global_position + Vector3(0, 0, -1.0)
	for id in ["", "bottle", "rock", "hammer", "crowbar", "hatchet", "plank", "sledgehammer", "broken_bottle", "torch", "cooking_pot"]:
		var row := "%-14s" % (id if id != "" else "fists")
		for fresh in [1.0, 0.5, 0.05]:
			for part in ["Head", "Torso"]:
				var tot := 0.0
				var tsec := 0.0
				var breaks := 0
				var n := 6
				for i in n:
					if id == "":
						p.inv.slots.erase("hand_r")
						p.inv.slots.erase("hand_l")
					else:
						_hold(id)
					var z := _zombie(spot, fresh)
					var r: Array = await _fight(z, part, 400)
					tot += r[0]
					tsec += r[1]
					if r[2] != "":
						breaks += 1
					z.queue_free()
					await physics_frame
				row += "  %s %s: %.1f (%.1fs)%s" % ["fresh" if fresh > 0.9 else ("half" if fresh > 0.3 else "rotted"), part.to_lower(), tot / n, tsec / n, " broke %d/%d" % [breaks, n] if breaks > 0 else ""]
		_say(row)

	# ---- wear and breaking
	_hold("bottle")
	var z2 := _zombie(spot, 1.0)
	var r2: Array = await _fight(z2, "Torso", 1)
	_say("bottle, one blow: %s; at your feet: %s" % [r2[2], _feet()])
	r2 = await _fight(z2, "Head", 30)
	_say("then the broken bottle: %s" % r2[2])
	z2.queue_free()
	_hold("plank")
	var z3 := _zombie(spot, 1.0)
	z3.skull = 99.0
	z3.hp = 9999.0
	for i in 6:
		await _fight(z3, "Torso", 1)
		if i == 2 or i == 4:
			_say("  plank after %d blows: %s" % [i + 1, Items.label(p.inv.slots.get("hand_r", {"id": "rock", "n": 1}))])
	_say("plank after 6 blows: in hand %s; at your feet: %s" % [str(p.inv.slots.get("hand_r", {}).get("id", "nothing")), _feet()])
	z3.queue_free()
	_hold("plank", "water")
	var w := p.wield()
	_say("plank with water in the other hand: one-handed %s, force %.1f, %.2fs a swing (two hands: %.1f, %.2fs); wheel reads '%s'" % [w["one_handed"], w["force"], w["time"],
		Items.hit_of("plank")["force"], Items.hit_of("plank")["time"], p.weapon_name("fists")])
	_hold("hatchet")
	var z4 := _zombie(spot, 0.5)
	z4.skull = 99.0
	z4.hp = 9999.0
	var limbs := 0
	for i in 40:
		var before := z4.body.part("ArmL")
		await _fight(z4, "ArmL", 1)
		if z4.body.part("ArmL") == "Destroyed" and before != "Destroyed":
			limbs = i + 1
			break
	_say("hatchet at a half-rotted arm: off at blow %d" % limbs)
	z4.queue_free()
	var zl := 0
	for i in 20:
		_hold("crowbar")
		var z5 := _zombie(spot, 1.0)
		z5.skull = 99.0
		z5.hp = 9999.0
		await _fight(z5, "LegL", 1)
		if z5.state == "down" or z5.crawling:
			zl += 1
		z5.queue_free()
	_say("crowbar at a fresh leg: down %d of 20" % zl)

	# ---- breaking things with what is in hand
	var crate: Breakable = null
	for b in get_nodes_in_group("destructible"):
		if b is Breakable and b.stuff == "wood" and b.title == "crate":
			crate = b
			break
	if crate != null:
		p.inv.slots.erase("hand_l")
		_hold("plank")
		p.inv.slots.erase("waist:0")
		p.inv.slots.erase("waist:1")
		_say("crate with a plank in hand: %s; with a hatchet on the belt too: %s" % [p.break_tool(crate)[2], ""])
		p.inv.slots["waist:0"] = Items.make("hatchet")
		_say("  ... with a hatchet on the belt too: %s (%s)" % [p.break_tool(crate)[2], crate.feel(p.break_tool(crate)[0], p.break_tool(crate)[1])])
		p.inv.slots.erase("waist:0")

	# ---- taking apart
	p.set_physics_process(true)
	p.armed = false
	p.global_position = Vector3(0, 0, 20)
	p.velocity = Vector3.ZERO
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)
	p.inv.slots["hand_r"] = Items.make("plank", 2)
	p.take_apart("hand_r")
	_say("plank, nothing to cut with: '%s'" % p.status_text)
	p.inv.slots["hand_l"] = Items.make("broken_bottle")
	p.take_apart("hand_r")
	var t0 := 0.0
	while p._work == "apart":
		await physics_frame
		t0 += 1.0 / 60.0
	_say("plank, broken bottle in the other hand: %.1f s, '%s'; planks left %d" % [t0, p.status_text, int(p.inv.slots.get("hand_r", {"n": 0})["n"])])
	p.take_apart("hand_r")
	await _wait(1.0)
	p.global_position += Vector3(1.0, 0, 0)
	await _wait(0.1)
	_say("walked off a second in: '%s', planks %d" % [p.status_text, int(p.inv.slots.get("hand_r", {"n": 0})["n"])])
	var ear_near := _zombie(p.global_position + Vector3(-8, 0, 0), 1.0)
	var ear_far := _zombie(p.global_position + Vector3(-12, 0, 0), 1.0)
	ear_near._noise_t = 0.0
	ear_far._noise_t = 0.0
	p.inv.slots["waist:0"] = Items.make("bottle")
	p.take_apart("waist:0")
	await _wait(1.4)
	_say("bottle smashed: '%s'; heard 8 m %s, 12 m %s" % [p.status_text, ear_near._noise_t > 0.0, ear_far._noise_t > 0.0])
	p.inv.slots["legs:0"] = Items.make("backpack")
	Items.hold_of(p.inv.slots["legs:0"])["things"].append({"item": Items.make("rock"), "x": 0, "y": 0, "z": 0})
	p.take_apart("legs:0")
	_say("a backpack with a rock in it: '%s'" % p.status_text)
	var carried: Array[String] = []
	for k in p.inv.slots:
		carried.append(Items.label(p.inv.slots[k]))
	_say("carrying: %s" % ", ".join(carried))
	quit()


func _feet() -> String:
	var out: Array[String] = []
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and n.small and (n as Node3D).global_position.distance_to(p.global_position) < 1.5:
			for it in n.contents:
				out.append(Items.label(it))
	return ", ".join(out) if not out.is_empty() else "nothing"
