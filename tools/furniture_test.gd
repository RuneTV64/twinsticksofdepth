extends SceneTree
## Headless test of the furniture kit (assets/buildings/furniture) in the real level: how strong each piece is and
## what it leaves, which are cover, what a zombie makes of them, and the stove. Run from a scratch copy (copy
## this file to its root):
##   godot --headless --fixed-fps 60 -s res://furniture_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[furniture] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _zombie(at: Vector3) -> Enemy:
	var z: Enemy = null
	for i in 12:
		z = Enemy.new()
		z.kind = "shambler"
		z.position = at
		main.add_child(z)
		z.player = p
		z.body.wits = 1.0
		if z.body.legs() == 2 and not z.crawling:
			break
		z.free()
	return z


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
	var count := {}
	for b: Breakable in get_nodes_in_group("destructible"):
		if b.host != null and b.host.has_meta("furniture"):
			count[b.title] = int(count.get(b.title, 0)) + 1
	_say("in the level: %s; %d breakable things in all" % [count, Breakable.count])
	# ---- each piece, on open ground: strength, cover, what it leaves
	var f := FurnitureKit.new(main, 0)
	var x := -36.0
	for kind: String in FurnitureKit.KINDS:
		var b: Breakable
		if kind == "counter":
			b = f.counter(Vector2(x - 0.75, 60.0), Vector2(x + 0.75, 60.0))
		else:
			b = f.put(kind, Vector3(x, 0, 60.0), "S")
		var box := Cover.box_of(b.host)
		var cov := "no cover"
		if box != null:
			cov = "low cover" if box.low else "high cover"
		var blows := "%.0f zombie blows, %.0f punches, %.0f hatchet, %.0f sledgehammer" % [ceilf(b.hits_left(12.0, "blunt")),
			ceilf(b.hits_left(p.break_fist, "blunt")), ceilf(b.hits_left(p.break_hatchet, "chop")), ceilf(b.hits_left(p.break_sledge, "pound"))]
		var at := Vector3(x, 0, 60.0)
		b.give_way()
		var left := []
		for w in Wreck.all:
			if is_instance_valid(w) and w.global_position.distance_to(at) < 1.2:
				for m: String in w.lot:
					left.append("%d %s" % [w.left(m), Materials.of(m)["name"]])
		_say("%s (%.2f m): %s; %s; leaves %s" % [b.title, b.top - b.foot, cov, blows, ", ".join(left)])
		x += 4.0
	await _wait(0.3)
	# ---- worn pieces are weaker
	var worn := []
	for wear in 3:
		var k := FurnitureKit.new(main, wear)
		var b := k.put("wardrobe", Vector3(-30.0 + wear * 3.0, 0, 70.0), "S")
		worn.append("%.0f" % ceilf(b.hits_left(12.0, "blunt")))
		b.host.queue_free()
	_say("a wardrobe put down sound, damaged, about to give: %s zombie blows" % ", ".join(worn))
	# ---- cover, in the furnished house: the couch in the living room (its back is to the south wall)
	var couch_at := Vector2(19.5, -28.6)
	var c := Cover.find_near(Vector2(19.5, -29.6), 1.6, Vector2(0, 1), 0.05)
	if not c.is_empty():
		var face: Cover.Face = c["face"]
		_say("in front of the living room couch: a %s cover face %.2f m high; hunkered there, hidden from across it: %s" % [
			"low" if face.low else "high", face.top, Cover.shields(face, Cover.spot(face, c["t"]), couch_at + Vector2(0, 0.3))])
	# The fridge stops sight; the table doesn't hide someone standing.
	p.global_position = Vector3(24.46, 0.05, -29.0)       # in the kitchen, south of the fridge
	await _wait(0.3)
	_say("standing in the kitchen: someone the far side of the fridge is seen: %s; someone the far side of the table: %s" % [
		p.can_see(Vector3(24.46, 1.2, -33.4)), p.can_see(Vector3(25.75, 1.2, -32.4))])
	# ---- the stove
	p.inv.add(Items.make("water"))
	var slot: Dictionary = p.inv.slots[p.inv.find("water")]
	Water.fill(slot, 0.7, 0.9)                             # standing water: muddy and teeming
	var fire: Campfire = null
	for n in get_nodes_in_group("interactables"):
		if n is Campfire and n.global_position.distance_to(Vector3(26.42, 0.45, -33.54)) < 1.5:
			fire = n
	if fire != null:
		p.global_position = Vector3(26.42, 0.05, -32.5)
		await _wait(0.3)
		var before := Water.look(slot)
		var cold := fire.prompt_text(p)
		p.inv.add(Items.make("wood_scrap", 2))
		p.inv.add(Items.make("matches"))
		p.inv.add(Items.make("cooking_pot"))
		fire.interact(p)                       # lays the wood and lights it
		var said := fire.prompt_text(p)
		fire.interact(p)                       # the pot goes on
		await _wait(Water.BOIL_TIME + 1.0)
		_say("at the kitchen stove with a bottle of water (%s): cold, it says \"%s\"; with wood and a match it is %s and says \"%s\"; %0.f s later the water is: %s" % [
			before, cold, fire.feel(), said, Water.BOIL_TIME, Water.look(slot)])
	else:
		_say("no fire found at the kitchen stove")
	# ---- zombies: one outside the kitchen's east window with the player behind the table
	p.global_position = Vector3(25.0, 0.05, -29.0)
	await _wait(0.3)
	for trial: Array in [["a chair", Vector3(24.98, 0.1, -32.1), Vector3(24.98, 0.05, -29.9), "chair"],
			["the kitchen table", Vector3(25.75, 0.1, -32.5), Vector3(25.75, 0.05, -29.4), "table"]]:
		var thing: Breakable = null
		for b: Breakable in get_nodes_in_group("destructible"):
			if b.title == trial[3] and b.rect.get_center().distance_to(Vector2((trial[1] as Vector3).x, (trial[1] as Vector3).z)) < 2.6:
				thing = b
		p.global_position = trial[2]
		await _wait(0.2)
		var z := _zombie(trial[1])
		var t := 0.0
		var climbed := false
		var how := "did not reach the player in 40 s"
		while t < 40.0:
			await physics_frame
			t += 1.0 / 60.0
			climbed = climbed or z.state == "climb"
			if not p.held_by.is_empty() or z.global_position.distance_to(p.global_position) < 0.9:
				how = "on the player after %.1f s (%s; the %s is %s)" % [t, "it climbed over" if climbed else "it walked round or through",
					trial[3], "still there" if is_instance_valid(thing) and thing.alive() else "broken"]
				break
		_say("a zombie with %s between it and the player: %s" % [trial[0], how])
		z.queue_free()
		for h in p.held_by.duplicate():
			p.held_by.erase(h)
		await _wait(0.2)
	quit()
