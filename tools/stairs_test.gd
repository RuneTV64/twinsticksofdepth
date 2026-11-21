extends SceneTree
## Headless test of stairs, upper floors and basements (assets/buildings/house/house_kit.gd, ground_pit.gd) in
## the real level: a body shaped like the player is walked up to the top floor and down to the basement of the
## kit house, and a zombie is set after someone on another floor.
## Run from a scratch copy (copy this file to its root):  godot --headless --fixed-fps 60 -s res://stairs_test.gd

var main: Node
var probe: CharacterBody3D


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[stairs] ", t)


## Walk the probe in straight lines through these points (x, z), as a person does: sideways speed, gravity.
func _walk(points: Array, speed := 2.2) -> float:
	var lowest := INF
	for p: Vector2 in points:
		var t := 0.0
		while Vector2(probe.global_position.x, probe.global_position.z).distance_to(p) > 0.12 and t < 8.0:
			var d := (p - Vector2(probe.global_position.x, probe.global_position.z)).normalized()
			probe.velocity.x = d.x * speed
			probe.velocity.z = d.y * speed
			probe.velocity.y = 0.0 if probe.is_on_floor() else probe.velocity.y - 25.0 / 60.0
			probe.move_and_slide()
			lowest = minf(lowest, probe.global_position.y)
			await physics_frame
			t += 1.0 / 60.0
	return lowest


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 20:
		await physics_frame
	var p: Player = main.player
	p.invulnerable = true
	for e in get_nodes_in_group("enemies"):
		if (e as Enemy).global_position.distance_to(Vector3(22, 0, -31)) < 30.0:
			e.queue_free()
	probe = CharacterBody3D.new()
	probe.collision_layer = 0
	probe.collision_mask = p.collision_mask
	for c in p.get_children():
		if c is CollisionShape3D:
			probe.add_child(c.duplicate())
	main.add_child(probe)
	# In by the front door's room, to the room south of the stairs.
	probe.global_position = Vector3(19.0, 0.1, -29.5)
	await _walk([Vector2(18.8, -30.2)])
	_say("standing on the ground floor over the basement: y %.2f, on floor %s" % [probe.global_position.y, probe.is_on_floor()])
	# Up: the left flight north to the landing, across, the right flight back south.
	await _walk([Vector2(18.8, -33.3), Vector2(20.2, -33.3)])
	_say("on the half landing: y %.2f" % probe.global_position.y)
	await _walk([Vector2(20.2, -30.0), Vector2(22.5, -29.5)])
	_say("upstairs, walked into the next room: y %.2f, on floor %s (the floor above is at 2.70)" % [probe.global_position.y, probe.is_on_floor()])
	# Back down the same way.
	await _walk([Vector2(20.2, -30.0), Vector2(20.2, -33.3), Vector2(18.8, -33.3), Vector2(18.8, -30.2)])
	_say("back on the ground floor: y %.2f" % probe.global_position.y)
	# Down: the right-hand side goes to the basement.
	await _walk([Vector2(20.2, -30.2), Vector2(20.2, -33.3)])
	_say("on the basement stairs' half landing: y %.2f" % probe.global_position.y)
	await _walk([Vector2(18.8, -33.3), Vector2(18.8, -30.0), Vector2(23.0, -29.5)])
	_say("in the basement, walked across it: y %.2f, on floor %s (its floor is at -2.70)" % [probe.global_position.y, probe.is_on_floor()])
	await _walk([Vector2(18.8, -30.0), Vector2(18.8, -33.3), Vector2(20.2, -33.3), Vector2(20.2, -30.2), Vector2(22.0, -29.5)])
	_say("and back up to the ground floor: y %.2f" % probe.global_position.y)
	# The ground outside still holds, and the pit's edge is closed by the house walls.
	probe.global_position = Vector3(22.5, 0.2, -26.0)
	var low := await _walk([Vector2(22.5, -27.3)])
	_say("walking at the house's south wall from outside: stopped at z %.2f, lowest y %.2f" % [probe.global_position.z, low])
	# What the crosshair picks, by the floor you are on.
	var spot := Vector2(22.5, -31.0)
	for feet: float in [0.05, 2.75, -2.65]:
		var b := Breakable.under(spot, 0.3, feet)
		_say("crosshair at the inside wall, standing at y %.2f: %s (%s), from %.1f to %.1f" % [feet, b.title if b != null else "nothing", b.stuff if b != null else "-", b.foot if b != null else 0.0, b.top if b != null else 0.0])
	# A zombie on the ground floor, the player in the basement right under it, then on the same floor.
	p.global_position = Vector3(25.0, -2.65, -30.0)
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = Vector3(25.0, 0.1, -29.0)
	main.add_child(z)
	z.player = p
	var grabbed := false
	for i in 600:
		await physics_frame
		grabbed = grabbed or not p.held_by.is_empty()
	_say("zombie one floor up, 1 m away on the map, for 10 s: grabbed the player %s, zombie y %.2f, chasing %s" % [grabbed, z.global_position.y, z.chasing])
	z.global_position = Vector3(25.0, -2.65, -28.6)
	grabbed = false
	for i in 600:
		await physics_frame
		grabbed = grabbed or not p.held_by.is_empty()
	_say("the same zombie put in the basement with the player: grabbed %s" % grabbed)
	quit()
