extends SceneTree
## Headless test of the first working items (items.gd), in the real level: boarding a window and prising the
## boards off, boots on glass, a helmet, a fire that wants wood, a match and a pot, torch batteries, tins and
## the needs that run down, antibiotics, washing cloth, dropping and picking up. Run from a scratch copy (copy
## this file to its root):
##   godot --headless --fixed-fps 60 -s res://items_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[items] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## A zombie that only listens: it stands where it is put and records what it hears.
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


func _carry() -> String:
	var out: Array[String] = []
	for sl in p.inv.slot_list():
		var it = p.inv.slots.get(sl[0])
		if it != null:
			out.append(Items.label(it))
	for wr in Inventory.WORN:
		var on = p.inv.worn.get(wr[0])
		if on != null:
			out.append("wearing " + Items.label(on))
	return ", ".join(out) if not out.is_empty() else "nothing"


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
	var b := p.sheet.body

	# ---- the list
	var cats := {}
	for id: String in Items.DEFS:
		var c := str(Items.DEFS[id].get("cat", "?"))
		cats[c] = int(cats.get(c, 0)) + 1
	_say("%d items in all, by kind: %s" % [Items.DEFS.size(), cats])
	for place in ["kitchen", "garage", "bathroom", "bedroom", "shop", "yard"]:
		_say("  found in a %s: %s" % [place, ", ".join(Items.found_in(place))])

	# ---- boarding a window
	var win := Solid.window_near(Vector3(-19, 1, -55.4), 1.5)
	var wp: Vector3 = win["pos"]
	p.global_position = Vector3(wp.x - 0.9, 0.0, wp.z)
	p.velocity = Vector3.ZERO
	await _wait(0.3)
	var near := _ear(p.global_position + Vector3(-10, 0, 0))
	var far := _ear(p.global_position + Vector3(-15, 0, 0))
	p.reticle_offset = wp - p.global_position
	p.work_window()
	_say("at a window with nothing: \"%s\"" % p.status_text)
	p.inv.add(Items.make("hammer"))
	p.inv.add(Items.make("nails"))
	p.inv.add(Items.make("plank", 4))
	p.inv.add(Items.make("crowbar"))
	_say("carrying: %s (%.1f kg)" % [_carry(), p.inv.weight()])
	p.reticle_offset = wp - p.global_position
	p.work_window()
	var t := 0.0
	while p._work != "" and t < 30.0:
		await physics_frame
		t += 1.0 / 60.0
	var boards: Breakable = win["boards"]
	_say("boarding it took %.1f s; boarded: %s; a zombie 10 m off heard it: %s, one 15 m off: %s; left: %s" % [
		t, boards != null and boards.alive(), near._drive > 0.0, far._drive > 0.0, _carry()])
	if boards != null:
		_say("  the boards: %d zombie blows, %d hatchet blows" % [boards.hits_left(12.0, "blunt"), boards.hits_left(40.0, "chop")])
	# Interrupted: walk off half way and nothing is used.
	var win2 := Solid.window_near(Vector3(-14, 1, -59), 3.0)
	var wp2: Vector3 = win2["pos"]
	p.global_position = Vector3(wp2.x, 0.0, wp2.z - 0.9) if absf((win2["size"] as Vector3).x) > absf((win2["size"] as Vector3).z) else Vector3(wp2.x - 0.9, 0.0, wp2.z)
	await _wait(0.3)
	p.reticle_offset = wp2 - p.global_position
	p.work_window()
	var started := p._work
	await _wait(2.0)
	p.global_position += Vector3(0, 0, -1.5) if absf((win2["size"] as Vector3).x) > absf((win2["size"] as Vector3).z) else Vector3(-1.5, 0, 0)
	await _wait(0.3)
	_say("a second window, started (%s) and walked off after 2 s: boarded %s, still carrying %s" % [started, win2["boards"] != null, _carry()])
	# Prising the boards off again.
	p.global_position = Vector3(wp.x - 0.9, 0.0, wp.z)
	await _wait(0.3)
	near._drive = 0.0
	var near2 := _ear(p.global_position + Vector3(-3, 0, 0))
	p.reticle_offset = wp - p.global_position
	p.work_window()
	t = 0.0
	while p._work != "" and t < 30.0:
		await physics_frame
		t += 1.0 / 60.0
	_say("prising them off with the crowbar took %.1f s; boarded now: %s; heard at 3 m: %s, at 10 m: %s; carrying: %s" % [
		t, win["boards"] != null and is_instance_valid(win["boards"]) and win["boards"].alive(), near2._drive > 0.0, near._drive > 0.0, _carry()])
	for z in [near, far, near2]:
		z.queue_free()
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)

	# ---- boots
	p.global_position = Vector3(-30, 0, 20)
	await _wait(0.3)
	_say("as you start: barefoot %s" % p.barefoot)
	p.inv.add(Items.make("boots"))
	p.inv.add(Items.make("helmet"))
	p.use_item(p.inv.find("boots"))
	p.use_item(p.inv.find("helmet"))
	_say("boots and helmet put on from the page: %s; barefoot %s; weight carried %.1f kg" % [_carry(), p.barefoot, p.inv.weight()])
	var glass := Wreck.leave(main, p.global_position, 0.5, {"glass": 1.0}, 3.0 / float(Materials.of("glass")["per_m2"]), "broken glass")
	await _wait(0.1)
	b.wounds.clear()
	for i in 60:
		p._step_side = -p._step_side if p._step_side != 0 else 1
		p._step_in_it()
	_say("60 footfalls on 3 shards in boots: glass %s, wounds %d" % ["still there" if is_instance_valid(glass) and glass.lot.has("glass") else "gone", b.wounds.size()])
	p.use_item("worn:feet")
	var steps := 0
	while is_instance_valid(glass) and glass.lot.has("glass") and steps < 200:
		p._step_side = -p._step_side if p._step_side != 0 else 1
		p._step_in_it()
		steps += 1
	_say("boots off (barefoot %s): the glass was gone in %d footfalls, wounds %d" % [p.barefoot, steps, b.wounds.size()])
	b.reset()

	# ---- helmet
	p.health = p.max_health
	var full := p.max_health
	p.in_cover = false
	# (A head hit is what a shot across the cover you peek over does: take_shot's head branch.)
	var dmg_bare := p.max_health * p.head_hit_fraction
	var dmg_helm := dmg_bare * p.helmet_share
	_say("a shot to the head: %.0f of %.0f health bare, %.0f in a helmet (worn: %s)" % [dmg_bare, full, dmg_helm, p.inv.worn.has("head")])
	p.use_item("worn:head")
	_say("helmet off again: %s" % _carry())
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)
	p.inv.worn.clear()
	p._worn_changed()

	# ---- a fire: the kitchen stove
	var stove: Campfire = null
	for n in get_nodes_in_group("interactables"):
		if n is Campfire and not n.kept:
			stove = n
	if stove == null:
		_say("NO STOVE FOUND")
	else:
		p.global_position = stove.global_position + Vector3(0, 0, 0)
		p.global_position.y = 0.0
		await _wait(0.3)
		_say("the kitchen stove as it stands: %s; with nothing, can use it: %s" % [stove.feel(), stove.can_interact(p)])
		var bottle := Items.make("water")
		bottle["uses"] = 0
		Water.fill(bottle, 0.15, 0.45)
		p.inv.add(bottle)
		_say("  with rain-barrel water only: can use it: %s" % stove.can_interact(p))
		p.inv.add(Items.make("wood_scrap", 1))
		_say("  with splintered wood: \"%s\"" % stove.prompt_text(p))
		stove.interact(p)
		_say("  -> \"%s\"; it is %s, it says \"%s\"" % [p.status_text, stove.feel(), stove.prompt_text(p)])
		p.inv.add(Items.make("matches"))
		stove.interact(p)
		_say("  with matches -> \"%s\"; it is %s; matches left: %s" % [p.status_text, stove.feel(), Items.label(p.inv.slots[p.inv.find("matches")])])
		_say("  water and no pot: \"%s\"" % stove.prompt_text(p))
		stove.interact(p)
		_say("  -> \"%s\"" % p.status_text)
		p.inv.add(Items.make("cooking_pot"))
		stove.interact(p)
		await _wait(Water.BOIL_TIME + 0.5)
		_say("  with a pot, %.0f s later the water is: %s" % [Water.BOIL_TIME, Water.look(p.inv.slots[p.inv.find("water")])])
		# How long one piece of splintered wood lasts (sped up: the fire's own clock).
		var burn := stove.fuel
		stove._process(burn + 1.0)
		_say("  one splintered wood burned %.0f s more (%.0f s in all) and the fire is now %s; a plank burns %.0f s" % [
			burn, float(Items.FUEL["wood_scrap"]), stove.feel(), float(Items.FUEL["plank"])])
		var camp: Campfire = null
		for n in get_nodes_in_group("interactables"):
			if n is Campfire and n.kept:
				camp = n
		if camp != null:
			_say("  a camp fire somebody keeps in: %s, needs wood: %s" % [camp.feel(), camp.can_interact(p) and camp.prompt_text(p).contains("Feed")])
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)

	# ---- the torch and its batteries
	p.inv.add(Items.make("torch"))
	p.inv.add(Items.make("battery", 2))
	var tk := p.inv.find("torch")
	_say("a torch as found: %s" % Items.label(p.inv.slots[tk]))
	p.torch_kind = "torch"
	p.torch_on = true
	await _wait(10.0)
	var used := int(Items.DEFS["torch"]["uses"]) - int(p.inv.slots[tk]["uses"])
	_say("lit for 10 s it used %d s of its %d; that is %.0f minutes of light a set of batteries" % [used, int(Items.DEFS["torch"]["uses"]), int(Items.DEFS["torch"]["uses"]) / 60.0])
	p.inv.slots[tk]["uses"] = 2
	await _wait(3.5)
	_say("run flat: on %s, \"%s\", it reads: %s" % [p.torch_on, p.status_text, Items.label(p.inv.slots[tk])])
	p.use_item(p.inv.find("battery"))
	_say("batteries used from the page: %s; batteries left: %s" % [Items.label(p.inv.slots[tk]), Items.label(p.inv.slots[p.inv.find("battery")])])
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)

	# ---- food, and the needs running down
	_say("needs rate: %.5f game hours a second (a day of %.0f real minutes). Over a day food falls %.0f and water %.0f of 100" % [
		p.sheet.needs_rate, p.day_seconds / 60.0, float(CharacterSheet.NEED_DRAIN["food"]) * 24.0, float(CharacterSheet.NEED_DRAIN["water"]) * 24.0])
	var f0 := float(p.sheet.needs["food"])
	var w0 := float(p.sheet.needs["water"])
	var r0 := float(p.sheet.needs["rest"])
	await _wait(60.0)
	_say("a minute standing: food %.2f -> %.2f, water %.2f -> %.2f, rest %.2f -> %.2f" % [f0, float(p.sheet.needs["food"]), w0, float(p.sheet.needs["water"]), r0, float(p.sheet.needs["rest"])])
	p.sheet.set_need("food", 30.0)
	p.inv.add(Items.make("canned_food", 3))
	p.use_item(p.inv.find("canned_food"))
	_say("a tin and nothing to open it: \"%s\"; food %.0f" % [p.status_text, float(p.sheet.needs["food"])])
	p.inv.add(Items.make("hatchet"))
	p.use_item(p.inv.find("canned_food"))
	_say("hacked open with the hatchet: \"%s\"; food %.0f" % [p.status_text, float(p.sheet.needs["food"])])
	p.inv.add(Items.make("can_opener"))
	p.use_item(p.inv.find("canned_food"))
	_say("with the tin opener: \"%s\"; food %.0f; left: %s" % [p.status_text, float(p.sheet.needs["food"]), _carry()])
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)

	# ---- antibiotics
	for case: Array in [["never washed", false, false], ["never washed", false, true], ["washed once and left open", true, false], ["washed once and left open", true, true]]:
		var dose: bool = case[2]
		b.reset()
		for k in p.inv.slots.keys():
			p.inv.slots.erase(k)
		var cut: Dictionary = b.hurt("deep cut", "ArmL", 30.0)
		cut["germs"] = 0.0 if case[1] else 0.5
		cut["inf"] = 0.7                        # it has taken hold
		if dose:
			p.inv.add(Items.make("antibiotics"))
			p.use_item(p.inv.find("antibiotics"))
		var tt := 0.0
		var bad := -1.0
		var clear := -1.0
		while tt < 900.0 and bad < 0.0 and clear < 0.0:
			cut["closing"] = 0.0
			b._tick_infection(1.0)
			tt += 1.0
			if dose and b.abx_t <= 0.0 and p.inv.has("antibiotics"):
				p.use_item(p.inv.find("antibiotics"))      # the next pill as each wears off
			if float(cut["inf"]) >= 1.0:
				bad = tt
			if float(cut["inf"]) <= 0.0:
				clear = tt
		_say("an arm wound that has taken hold, %s, %s: %s; pills left: %s" % [
			case[0], "on antibiotics" if dose else "nothing taken",
			("fully infected at %.0f s" % bad) if bad >= 0.0 else (("clear of it at %.0f s" % clear) if clear >= 0.0 else "neither in 15 minutes (infection %.2f)" % float(cut["inf"])),
			Items.label(p.inv.slots[p.inv.find("antibiotics")]) if p.inv.has("antibiotics") else "none"])
	b.reset()
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)

	# ---- cloth into rags
	p.inv.add(Items.make("cloth_scrap", 2))
	p.use_item(p.inv.find("cloth_scrap"))
	_say("torn cloth and no water: \"%s\"" % p.status_text)
	var foul := Items.make("water")
	foul["uses"] = 0
	Water.fill(foul, 0.7, 0.9)
	p.inv.add(foul)
	p.use_item(p.inv.find("cloth_scrap"))
	_say("with standing water: \"%s\"" % p.status_text)
	p.inv.slots.erase(p.inv.find("water"))
	p.inv.add(Items.make("water"))
	p.use_item(p.inv.find("cloth_scrap"))
	p.use_item(p.inv.find("cloth_scrap"))
	_say("with a clean bottle, twice: %s" % _carry())

	# ---- putting things down and picking them up
	p.drop_item(p.inv.find("clean_rag"))
	await _wait(0.2)
	var lying: ItemPickup = null
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and n.global_position.distance_to(p.global_position) < 1.0:
			lying = n
	_say("rags put down: carrying %s; on the ground: %s" % [_carry(), lying.title if lying != null else "NOTHING"])
	if lying != null:
		lying.interact(p)
		await _wait(0.1)
		_say("picked up again: carrying %s" % _carry())

	# ---- death leaves what you wore
	p.inv.add(Items.make("boots"))
	p.use_item(p.inv.find("boots"))
	p._die("test")
	await _wait(0.3)
	var left_here := ""
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and (n.title as String).begins_with("Your"):
			left_here = "%s: %s" % [n.title, ", ".join((n.contents as Array).map(func(x): return Items.label(x)))]
	_say("died wearing boots: %s; barefoot again: %s" % [left_here, p.barefoot])
	quit()
