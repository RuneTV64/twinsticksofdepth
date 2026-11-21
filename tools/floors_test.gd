extends SceneTree
## Headless test of cover and shooting between floors (cover.gd, player.gd, projectile.gd, enemy.gd,
## raider.gd) at the kit house in the real level: an upstairs window in its south wall, people on the ground
## outside it. Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://floors_test.gd

const WIN := Vector3(22.5, 2.7, -28.62)      # standing at the middle upstairs window of the south wall (z -28)
var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[floors] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _zombie(pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.kind = "shambler"
	e.position = pos
	main.add_child(e)
	e.player = p
	e.set_physics_process(false)
	e.set_process(false)
	return e


func _parts(e: Enemy, skip: Array[RID]) -> String:
	var out: Array[String] = []
	var pts := _points(e)
	for k: String in ["Head", "Torso", "LegL"]:
		if p.line_clear(pts[k], p.muzzle_position(), skip):
			out.append(k)
	return "nothing" if out.is_empty() else ", ".join(out)


## Where its head, chest and shin are (worked out here: a test zombie may have rolled no head).
func _points(e: Enemy) -> Dictionary:
	var at := e.global_position
	return {"Head": at + Vector3(0, 1.6, 0), "Torso": at + Vector3(0, 1.15, 0), "LegL": at + Vector3(0, 0.4, 0)}


func _shoot_at(e: Enemy, part: String) -> String:
	var hp0 := e.hp
	var was_dead := e.dead
	var shot := Projectile.new()
	shot.dir = ((_points(e)[part] as Vector3) - p.muzzle_position()).normalized()
	shot.damage = 5.0
	shot.exclude = p.shot_skips()
	shot.position = p.muzzle_position()
	main.add_child(shot)
	await _wait(0.5)
	return "hit" if (e.hp < hp0 or (e.dead and not was_dead)) else "stopped"


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	p.invulnerable = true
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.1)
	# 1) Cover knows its floor.
	var by := {}
	for f in Cover.faces:
		by[snappedf(f.base, 0.1)] = int(by.get(snappedf(f.base, 0.1), 0)) + 1
	_say("cover faces by floor height: %s" % by)
	for feet: float in [-2.7, 0.02, 2.7]:
		var c := Cover.find_near(Vector2(22.5, -28.7), 1.2, Vector2.ZERO, feet)
		var f: Cover.Face = c.get("face")
		_say("slide into cover by the south wall, feet at %.2f: %s" % [feet, "none" if f == null else "a %s face on the floor at %.1f, %.1f m high" % ["low" if f.low else "high", f.base, f.top]])

	# 2) Shooting out of the upstairs window at someone on the ground outside.
	p.global_position = WIN
	p.facing = Vector3(0, 0, 1)
	await _wait(0.2)
	var sill: Cover.Face = Cover.find_near(Vector2(WIN.x, WIN.z), 1.2, Vector2.ZERO, 2.7)["face"]
	for d: float in [1.0, 2.5, 5.0, 9.0, 16.0]:
		var z := _zombie(Vector3(22.5, 0.05, -28.0 + d))
		await _wait(0.1)
		p.in_cover = false
		p.cover_face = null
		p.global_position = WIN
		p.facing = Vector3(0, 0, 1)
		await _wait(0.1)
		var free := _parts(z, p.shot_skips())
		var free_res: String = await _shoot_at(z, "Torso")
		var sees := p.can_see(z.global_position)
		var lean_skip: Array[RID] = [p.get_rid(), (sill.box.body as CollisionObject3D).get_rid()]
		var lean := _parts(z, lean_skip)
		var res := free_res
		_say("from the window, someone %4.1f m out from the wall: seen %s; standing back, a shot reaches %s; leaning out over the sill, %s (a shot at the chest from standing back: %s)" % [d, sees, free, lean, res])
		z.queue_free()
	var pane := Solid.window_near(Vector3(22.5, 4.1, -28.0), 1.0)
	_say("the window's glass after shooting through it: %s" % ("whole" if is_instance_valid(pane.get("pane")) and pane["pane"].alive() else "shattered"))

	# 3) Shooting in: someone upstairs, the player on the ground outside.
	for back: float in [0.5, 2.0]:
		var z := _zombie(Vector3(22.5, 2.7, -28.0 - back))
		await _wait(0.1)
		for d: float in [3.0, 8.0, 16.0]:
			p.global_position = Vector3(22.5, 0.05, -28.0 + d)
			p.facing = Vector3(0, 0, -1)
			await _wait(0.15)
			var shows := _parts(z, p.shot_skips())
			var res := "-"
			if shows != "nothing":
				res = await _shoot_at(z, "Head")
			_say("someone upstairs %.1f m back from the window, you %4.1f m out on the ground: seen %s; a shot reaches %s (at the head: %s)" % [back, d, p.can_see(z.global_position), shows, res])
		z.queue_free()

	# 4) A raider upstairs at the window shooting down.
	var r: Raider = main._raider(WIN)
	await _wait(0.2)
	r.set_physics_process(false)
	p.invulnerable = false
	for d: float in [2.0, 5.0, 10.0]:
		p.global_position = Vector3(22.5, 0.05, -28.0 + d)
		await _wait(0.2)
		var hits := 0
		for i in 10:
			p.health = p.max_health
			p.sheet.body.reset()
			r.mag = 5
			r._shot_cd = 0.0
			r._fire(p.global_position, 0.0)
			await _wait(0.3)
			hits += 1 if p.health < p.max_health else 0
		_say("a raider at the upstairs window firing at you %4.1f m out: %d of 10 shots hit" % [d, hits])
	p.invulnerable = true
	r.queue_free()

	# 5) Low cover against someone above: hunkered behind a crate on the ground.
	for d: float in [3.0, 6.0, 12.0]:
		var crate: StaticBody3D = main._box(Vector3(22.5, 0.6, -28.0 + d), Vector3(1.2, 1.2, 1.2), Color(0.45, 0.36, 0.25), "wood", "crate")
		var c := Cover.find_near(Vector2(22.5, -28.0 + d + 1.0), 1.5, Vector2.ZERO, 0.0)
		p.global_position = Vector3(22.5, 0.05, -28.0 + d + 1.08)
		p.in_cover = true
		p.cover_face = c["face"]
		p.cover_t = c["t"]
		p.cover_mode = "hunker"
		_say("hunkered behind a crate %4.1f m from the house: hidden from the ground floor window %s, from the upstairs window %s" % [d,
			p.hidden_from(Vector3(22.5, 1.15, -28.6)), p.hidden_from(Vector3(22.5, 2.7 + 1.15, -28.6))])
		p.in_cover = false
		Breakable.of(crate).give_way()
		await _wait(0.1)

	# 6) Out of the window.
	p.invulnerable = false
	p.sheet.body.reset()
	p.health = p.max_health
	p.global_position = WIN
	await _wait(0.3)
	p.global_position = Vector3(22.5, 2.75, -27.0)
	await _wait(1.5)
	_say("dropped from the upstairs window: y %.2f, health %d of %d, legs: %s" % [p.global_position.y, roundi(p.health), roundi(p.max_health), p.sheet.body.wounds.map(func(w): return "%s %s %.2f" % [w["part"], w["kind"], w["sev"]])])
	p.invulnerable = true

	# 7) A zombie on the ground and someone upstairs.
	await _wait(3.0)
	for back: float in [0.5, 2.6]:
		p.global_position = Vector3(22.5, 2.7, -28.0 - back)
		var z := Enemy.new()
		z.kind = "shambler"
		z.position = Vector3(22.5, 0.05, -21.0)
		main.add_child(z)
		z.player = p
		z.body.wits = 1.0            # a fresh one: it notices someone standing still (a rotted one wouldn't)
		z._drive = 0.0
		z._noise_t = 0.0
		await _wait(6.0)
		_say("zombie 7 m out on the ground, you upstairs %.1f m back from the window, 6 s: it %s (now %.1f m from the wall), grabbed you %s" % [back,
			"came toward the house" if z.global_position.z < -22.0 else "stayed where it was", z.global_position.z + 28.0, not p.held_by.is_empty()])
		z.queue_free()
		await _wait(0.1)
	quit()
