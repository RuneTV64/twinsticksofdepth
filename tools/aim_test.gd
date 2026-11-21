extends SceneTree
## Headless test of aiming at things above head height (Player._pick_high, aim_high): the crosshair is put
## where the camera sees a spot on the kit house, and the test reports what it is on, then shoots and throws
## at upstairs windows. Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://aim_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[aim] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## Put the crosshair where the camera sees this point of the world, and say what it is then on.
func _point_at(q: Vector3) -> String:
	var c := root.get_viewport().get_camera_3d().global_position
	var g := c + (q - c) * ((c.y - p.global_position.y) / maxf(c.y - q.y, 0.01))
	p.reticle_offset = g - p.global_position
	p.reticle_offset.y = 0.0
	p.armed = true
	p.reticle_visible = true
	p._update_hover()
	if p.aim_high == null:
		return "nothing above head height (aimed along the floor, %.1f m off)" % p.reticle_offset.length()
	return "the %s (%s), at height %.1f" % [p.aim_high.title, Materials.of(p.aim_high.stuff)["name"], p.aim_high_at.y]


func _pane(at: Vector3) -> String:
	var w := Solid.window_near(at, 0.8)
	return "whole" if not w.is_empty() and is_instance_valid(w["pane"]) and w["pane"].alive() else "broken"


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	p.invulnerable = true
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	p.global_position = Vector3(22.5, 0.05, -20.0)
	await _wait(1.0)
	var spots := [
		["the middle upstairs window", Vector3(22.5, 4.15, -27.99)],
		["the wall between two upstairs windows", Vector3(21.0, 4.2, -27.84)],
		["the roof (a lid: looked through)", Vector3(22.5, 6.3, -29.5)],
		["the far (north) wall's upstairs window, through the roof, from the wrong side", Vector3(22.5, 4.15, -33.9)],
		["a ground-floor window", Vector3(19.5, 1.45, -27.99)],
		["open ground", Vector3(24.0, 0.0, -16.0)],
	]
	for s: Array in spots:
		_say("crosshair over %s: on %s" % [s[0], _point_at(s[1])])
	# Shoot the upstairs window.
	p.weapon = "gun"
	p.mag = 6
	var on := _point_at(Vector3(22.5, 4.15, -27.99))
	_say("prompt with the gun on it: %s" % p.interact_prompt())
	p._fire()
	await _wait(0.6)
	_say("one shot with the crosshair on %s: the window is %s; glass on the ground under it: %s" % [on, _pane(Vector3(22.5, 4.15, -28.0)),
		Wreck.all.any(func(w): return w.lot.has("glass") and w.global_position.distance_to(Vector3(22.5, 0, -28)) < 2.0)])
	# Throw a rock through another upstairs window.
	p.inv.add(Items.make("rock", 3))
	p.weapon = "throw"
	p.global_position = Vector3(25.5, 0.05, -21.0)
	await _wait(0.6)
	on = _point_at(Vector3(25.5, 4.15, -27.99))
	_say("prompt with a rock: %s" % p.interact_prompt())
	p._fire_cd = 0.0
	p._throw()
	await _wait(2.5)
	var where := "nowhere"
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and n.small and n.title == "Rock" and n.global_position.distance_to(Vector3(25.5, 2.7, -29.0)) < 2.5:
			where = "on the floor upstairs, at (%.1f, %.1f, %.1f)" % [n.global_position.x, n.global_position.y, n.global_position.z]
	_say("a rock thrown with the crosshair on %s: the window is %s; the rock lies %s" % [on, _pane(Vector3(25.5, 4.15, -28.0)), where])
	# Throw a rock at the wall beside it.
	p.global_position = Vector3(21.0, 0.05, -21.0)
	await _wait(0.6)
	on = _point_at(Vector3(21.0, 4.2, -27.84))
	var wall := p.aim_high
	var hp0 := wall.hp if wall != null else 0.0
	p._fire_cd = 0.0
	p._throw()
	await _wait(2.5)
	where = "nowhere"
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and n.small and n.title == "Rock" and n.global_position.distance_to(Vector3(21.0, 0.0, -27.3)) < 1.5:
			where = "on the ground at the foot of the wall (y %.2f)" % n.global_position.y
	_say("a rock thrown with the crosshair on %s: the wall took %s damage; the rock lies %s" % [on, "some" if wall != null and is_instance_valid(wall) and wall.hp < hp0 else "no", where])
	# The far side of the house: a window in a wall that faces away from the camera, aimed at from behind it.
	p.global_position = Vector3(20.0, 0.05, -38.0)
	p.weapon = "gun"
	p.mag = 6
	await _wait(1.0)
	on = _point_at(Vector3(22.5, 4.15, -33.9))
	var cut: Cutaway = main.cutaway
	cut._aim_r = 0.0
	cut._aim(p.global_position, 0.0, 1.0)
	_say("north of the house, crosshair over the north wall's upstairs window (it faces away from the camera): on %s; the cursor cutaway is open %.1f m round it, at height %.1f" % [on, cut._aim_r, cut._aim_focus.y])
	_say("  the wall beside that window, the same way: on %s" % _point_at(Vector3(21.0, 4.2, -33.9)))
	on = _point_at(Vector3(22.5, 4.15, -33.9))
	p._fire_cd = 0.0
	p._fire()
	await _wait(0.6)
	_say("one shot: the window is %s" % _pane(Vector3(22.5, 4.15, -34.0)))
	# The cursor cutaway on the flat: weapon Ready, crosshair on the ground behind a wall.
	p.global_position = Vector3(22.5, 0.05, -20.0)
	await _wait(0.5)
	_point_at(Vector3(22.5, 0.0, -25.0))
	cut._aim_r = 0.0
	cut._aim(p.global_position, 0.0, 1.0)
	_say("weapon Ready, crosshair on the ground 5 m off: the cursor cutaway is open %.1f m round it" % cut._aim_r)
	p.armed = false
	p.free_look = false
	cut._aim(p.global_position, 0.0, 1.0)
	_say("weapon away and not looking about: open %.1f m" % cut._aim_r)
	p.reticle_offset = Vector3(0.0, 0.0, -1.0)
	p.armed = true
	cut._aim(p.global_position, 0.0, 1.0)
	_say("weapon Ready, crosshair 1 m from you: open %.1f m" % cut._aim_r)
	# Indoors: the building opens. What is over your head is cut away, so the crosshair isn't on it.
	p.global_position = Vector3(25.5, 0.05, -29.6)
	await _wait(1.0)
	_say("indoors on the ground floor: the building is open %.0f%%; floor %.1f, walls kept below %.2f, everything over %.2f gone" % [Cutaway._room2.w * 100.0, Cutaway._room2.x, Cutaway._room2.y, Cutaway._room2.z])
	_say("  cut away: the south (near) wall at 1.8 m %s, the north (far) wall at 1.8 m %s, a wall between rooms at 1.8 m %s, the floor upstairs %s, the roof %s, the near wall at 0.5 m %s" % [
		Cutaway.hides(Vector3(22.5, 1.8, -28.0)), Cutaway.hides(Vector3(22.5, 1.8, -33.9)), Cutaway.hides(Vector3(24.0, 1.8, -30.0)),
		Cutaway.hides(Vector3(22.5, 2.65, -31.0)), Cutaway.hides(Vector3(22.5, 6.0, -31.0)), Cutaway.hides(Vector3(22.5, 0.5, -28.0))])
	_say("standing indoors on the ground floor, crosshair where the floor above would be: on %s" % _point_at(Vector3(25.5, 2.7, -31.0)))
	# Upstairs at the window, crosshair on the ground outside.
	p.global_position = Vector3(22.5, 2.7, -28.62)
	await _wait(1.0)
	_say("upstairs: floor %.1f, walls kept below %.2f, everything over %.2f gone; the roof cut away %s, the ground floor's near wall %s" % [
		Cutaway._room2.x, Cutaway._room2.y, Cutaway._room2.z, Cutaway.hides(Vector3(22.5, 6.0, -31.0)), Cutaway.hides(Vector3(22.5, 1.8, -28.0))])
	_say("upstairs at the window, crosshair on the ground outside: on %s" % _point_at(Vector3(22.5, 0.0, -20.0)))
	p.global_position = Vector3(22.5, 0.05, -20.0)
	p.armed = false
	await _wait(1.0)
	_say("outside again: the building is open %.0f%%" % (Cutaway._room2.w * 100.0))
	quit()
