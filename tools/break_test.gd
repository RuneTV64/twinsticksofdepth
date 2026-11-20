extends SceneTree
## Headless test of breaking things (breakable.gd, solid.gd, wreck.gd, wear.gd) in the real test level.
## Run from a scratch copy of the project (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://break_test.gd
## It prints what happened; nothing is drawn.

var main: Node
var player: Player


func _init() -> void:
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var n := int(seconds * 60.0)
	for i in n:
		await physics_frame


func _say(text: String) -> void:
	print("[break] ", text)


func _zombie(pos: Vector3, fresh := true) -> Enemy:
	var e := Enemy.new()
	e.kind = "shambler"
	e.position = pos
	main.add_child(e)
	if e.body != null and e.body.has_method("set_freshness"):
		e.body.call("set_freshness", 1.0 if fresh else 0.1)
	return e


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.5)
	player = main.player
	player.invulnerable = true
	_say("breakables in the level: %d, of them barriers (panes, doors): %d, cover boxes: %d" % [Breakable.count, Breakable.barriers.size(), Cover.boxes.size()])

	# 1) A long wall is cut where it is hit.
	var wall: Breakable = null
	for b in Breakable.near(Vector2(0, -22), 0.5):
		if b.splitter.is_valid():
			wall = b
	var before := Breakable.count
	var boxes := Cover.boxes.size()
	wall.hit(25.0, "pierce", Vector3(2.0, 1.2, -22.0))
	_say("yard house north wall (14.4 m, brick) shot once: breakables %d -> %d, cover boxes %d -> %d" % [before, Breakable.count, boxes, Cover.boxes.size()])
	var sec := Breakable.under(Vector2(2.0, -22.0))
	_say("  the section hit is %.1f m long, %s, shots to go: %.0f; sledgehammer blows: %.0f; fists: %.0f" % [maxf(sec.rect.size.x, sec.rect.size.y), sec.state_word(), sec.hits_left(25.0, "pierce"), sec.hits_left(60.0, "pound"), sec.hits_left(6.0, "blunt")])
	var n := 0
	while sec.alive() and n < 100:
		sec.hit(60.0, "pound", Vector3(2.0, 1.2, -22.0))
		n += 1
	await _wait(0.2)
	_say("  sledgehammer: gone in %d blows; cover boxes now %d; wreckage: %s" % [n, Cover.boxes.size(), _wrecks_near(Vector3(2, 0, -22))])
	var space := root.get_world_3d().direct_space_state
	var ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2, 1.2, -20), Vector3(2, 1.2, -24), 1))
	_say("  a sight ray through the hole: %s" % ("clear" if ray.is_empty() else "blocked"))

	# 2) The player's tools.
	player.global_position = Vector3(-5, 0.05, 2.6)
	player.armed = true
	player.weapon = "fists"
	var crate := Breakable.under(Vector2(-5, 1))
	player.hover_breakable = crate
	player.reticle_offset = Vector3(0, 0, -1.2)
	_say("crate (%s): prompt with fists: %s" % [crate.stuff, crate.feel(player.break_tool(crate)[0], player.break_tool(crate)[1])])
	player.inv.add(Items.make("hatchet"))
	_say("  with the hatchet carried: %s, %s" % [player.break_tool(crate)[2], crate.feel(player.break_tool(crate)[0], player.break_tool(crate)[1])])
	n = 0
	while crate.alive() and n < 200:
		player.hover_breakable = crate
		player._strike_breakable(1.0)
		n += 1
	await _wait(0.2)
	_say("  hatchet blows to break it: %d; wreckage: %s" % [n, _wrecks_near(Vector3(-5, 0, 1))])
	var wr := Wreck.all[Wreck.all.size() - 1]
	wr.interact(player)
	_say("  picked through: carrying %s" % [player.inv.slots.values().map(func(i): return Items.label(i))])

	# 3) Pavement.
	player.inv.add(Items.make("sledgehammer"))
	player.global_position = Vector3(0.5, 0.05, -50.5)
	player.reticle_offset = Vector3(0, 0, -1.0)
	var road := Breakable.under(Vector2(0.5, -51.5))
	_say("pavement: %s, surface %s; fists: %s; with the sledgehammer: %s" % [road.title, road.surface, road.feel(6.0, "blunt"), road.feel(player.break_tool(road)[0], player.break_tool(road)[1])])
	n = 0
	while not road.holed(Vector3(0.5, 0, -51.5)) and n < 500:
		player.hover_breakable = road
		player.stamina = player.max_stamina
		player._strike_breakable(1.0)
		n += 1
	_say("  sledgehammer blows for one square metre: %d; left behind: %s; crosshair there now finds: %s" % [n, _wrecks_near(Vector3(0.5, 0, -51.5)), Breakable.under(Vector2(0.5, -51.5))])

	# 4) Least resistance: what a zombie pressed at each spot would go for.
	for spot: Array in [["yard house door (south)", Vector2(0.3, -9.4), Vector2(0, -1)], ["a house window, from outside", Vector2(-19.7, -53), Vector2(1, 0)], ["plain brick wall", Vector2(-19.7, -57), Vector2(1, 0)]]:
		var w := Breakable.weakest(spot[1], spot[2], 1.2, 10.0)
		_say("zombie at %s goes for: %s (%s), about %.0f blows" % [spot[0], w.title if w != null else "nothing", w.stuff if w != null else "-", w.hits_left(10.0, "blunt") if w != null else 0.0])

	# 5) A zombie that has seen you through a window.
	player.global_position = Vector3(-15, 0.05, -53)
	player.armed = false
	for e in get_nodes_in_group("enemies"):
		if (e as Enemy).global_position.distance_to(player.global_position) < 25.0:
			e.queue_free()
	await _wait(0.2)
	var z := _zombie(Vector3(-23, 0.05, -53))
	var pane := Solid.window_near(Vector3(-19, 1, -53), 1.5)
	var t := 0.0
	while is_instance_valid(pane["pane"]) and pane["pane"].alive() and t < 60.0:
		await _wait(0.25)
		t += 0.25
	_say("zombie outside a shut window, player inside: glass broke after %.1f s (zombie state %s)" % [t, z.state])
	var t2 := 0.0
	while z.global_position.x < -18.5 and t2 < 60.0:
		await _wait(0.25)
		t2 += 0.25
	_say("  and it was through the window %.1f s later (x %.1f, state %s)" % [t2, z.global_position.x, z.state])
	z.queue_free()

	# 6) The same with the window boarded.
	var win2 := Solid.window_near(Vector3(-14, 1, -59), 3.0)
	Solid.board(win2)
	player.global_position = Vector3(win2["pos"].x, 0.05, -56)
	await _wait(0.2)
	for count: int in [1, 4]:
		if not (is_instance_valid(win2["boards"]) and win2["boards"].alive()):
			Solid.board(win2)
		var zs: Array[Enemy] = []
		for i in count:
			zs.append(_zombie(Vector3(win2["pos"].x - 1.0 + i * 0.7, 0.05, -62.5 - 0.3 * (i % 2))))
		t = 0.0
		var glass_t := -1.0
		while is_instance_valid(win2["boards"]) and win2["boards"].alive() and t < 240.0:
			await _wait(0.25)
			t += 0.25
			if glass_t < 0.0 and not (is_instance_valid(win2["pane"]) and win2["pane"].alive()):
				glass_t = t
		_say("boarded window, %d zombie(s): glass went at %.1f s, boards at %.1f s" % [count, glass_t, t])
		for e in zs:
			e.queue_free()
		await _wait(0.2)

	# 7) A door.
	var door: Breakable = null
	for b in Breakable.barriers:
		if b.title == "door" and b.rect.get_center().distance_to(Vector2(-9, -53)) < 2.0:
			door = b
	if door != null:
		player.global_position = Vector3(-12, 0.05, -53)
		await _wait(0.2)
		var zs: Array[Enemy] = []
		for i in 3:
			zs.append(_zombie(Vector3(-6.0, 0.05, -53.6 + i * 0.6)))
		t = 0.0
		while door.alive() and is_instance_valid(door) and t < 300.0:
			await _wait(0.25)
			t += 0.25
		_say("house door, 3 zombies: broke after %.1f s" % t)
		for e in zs:
			e.queue_free()

	# 8) Glass underfoot, and rust and rot.
	_say("wrecks: %d, with glass: %d" % [Wreck.all.size(), Wreck.glass])
	var gw: Wreck = null
	for w in Wreck.all:
		if w.lot.has("glass"):
			gw = w
	if gw != null:
		var steps := 0
		while is_instance_valid(gw) and gw.lot.has("glass") and steps < 100:
			Wreck.step_on(gw.global_position, player)
			steps += 1
		_say("  glass trodden away after %d footfalls on it" % steps)
	var wear := get_first_node_in_group("weathering") as Wear
	for mins: int in [5, 10, 20, 40]:
		wear.pass_time(300.0 if mins == 5 else (mins * 30.0))
		await _wait(0.1)
		var kinds := {}
		for w in Wreck.all:
			for m: String in w.lot:
				kinds[m] = "%s %.0f%% gone" % [m, float(w.lot[m]["gone"]) * 100.0]
		_say("  after %d min dry: %d wrecks left: %s" % [mins, Wreck.all.size(), kinds.values()])
	quit()


func _wrecks_near(p: Vector3) -> String:
	for w in Wreck.all:
		if w.global_position.distance_to(p) < 2.0:
			var parts: Array[String] = []
			for m: String in w.lot:
				parts.append("%s x%d" % [Items.name_of(str(Materials.of(m)["scrap"])), w.left(m)])
			return "%s [%s]" % [w.title, ", ".join(parts)]
	return "none"
