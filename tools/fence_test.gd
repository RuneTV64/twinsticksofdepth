extends SceneTree
## Headless test of the fence kit (assets/buildings/fence) in the real level: how strong each kind is, what it
## does to sight, shots, cover and vaulting, and what a zombie makes of it. Run from a scratch copy (copy this
## file to its root):
##   godot --headless --fixed-fps 60 -s res://fence_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[fence] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## A zombie on two legs (it is rolled again until it has both: a crawler can't climb anything).
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


## Level shots from the player at a zombie: how many of `n` reach it.
func _volley(z: Enemy, n: int) -> int:
	var hits := 0
	for i in n:
		var hp0 := z.hp
		z.hp = 100000.0
		hp0 = z.hp
		var shot := Projectile.new()
		shot.dir = (z.global_position + Vector3(0, 1.1, 0) - p.muzzle_position()).normalized()
		shot.damage = 1.0
		shot.exclude = p.shot_skips()
		shot.position = p.muzzle_position()
		main.add_child(shot)
		await _wait(0.12)
		if z.hp < hp0:
			hits += 1
	return hits


func _wrecks(near: Vector3) -> int:
	var n := 0
	for w in Wreck.all:
		if is_instance_valid(w) and w.global_position.distance_to(near) < 4.0:
			n += 1
	return n


## A zombie put the far side of a fence from the player: how long until it is on the player's side, and how.
func _crossing(name: String, zat: Vector3, pat: Vector3, axis: int, line: float, limit: float) -> void:
	p.global_position = pat
	await _wait(0.3)
	var z := _zombie(zat)
	var side := signf(zat[axis] - line)
	var t := 0.0
	var how := "did not get across in %.0f s" % limit
	var before := _wrecks(zat)
	var climbed := false
	while t < limit:
		await physics_frame
		t += 1.0 / 60.0
		if not is_instance_valid(z) or z.dead:
			break
		climbed = climbed or z.state == "climb"
		if signf(z.global_position[axis] - line) != side and z.state != "climb":
			how = "across after %.1f s (%s%s)" % [t, "it climbed over" if climbed else "it walked through",
				"; it broke something first" if _wrecks(zat) > before else ""]
			break
	_say("%s: a zombie the far side with the player in sight: %s" % [name, how])
	if is_instance_valid(z):
		z.queue_free()
	await _wait(0.2)


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	p.invulnerable = true
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.2)
	# ---- what is there, and how strong
	var by_kind := {}
	for b: Breakable in get_nodes_in_group("destructible"):
		if b.title.ends_with("fence") or b.title == "gate":
			by_kind[b.title] = int(by_kind.get(b.title, 0)) + 1
	_say("in the level: %s; %d breakable things in all" % [by_kind, Breakable.count])
	for kind: String in ["picket", "board", "rail"]:
		var holder := Node3D.new()
		main.add_child(holder)
		var out := []
		for wear in 3:
			var f := FenceKit.new(holder, kind, wear)
			f.run(Vector2(-30.0 + wear * 6.0, 60.0), Vector2(-25.2 + wear * 6.0, 60.0))
			var b: Breakable = f.parts[0]
			if wear == 0:
				_say("%s, sound, a 1.2 m section: %.0f blows from a zombie, %.0f punches, %.0f with the hatchet, %.0f with the sledgehammer, %.0f shots" % [
					b.title, ceilf(b.hits_left(12.0, "blunt")), ceilf(b.hits_left(p.break_fist, "blunt")), ceilf(b.hits_left(p.break_hatchet, "chop")),
					ceilf(b.hits_left(p.break_sledge, "pound")), ceilf(b.hits_left(25.0, "pierce"))])
			out.append("%.0f" % ceilf(b.hits_left(12.0, "blunt")))
		_say("  put up sound, damaged, about to give: %s zombie blows" % ", ".join(out))
		holder.queue_free()
	await _wait(0.2)
	# ---- sight and shots: the rail fence round the field (its west side is x 18), the board fence (x 18, z -39.5..-34)
	p.global_position = Vector3(14.0, 0.05, 22.0)
	p.facing = Vector3(1, 0, 0)
	await _wait(0.4)
	var z := _zombie(Vector3(22.0, 0.1, 22.0))
	z.set_physics_process(false)
	await _wait(0.2)
	_say("rail fence between you and a zombie 8 m off: seen %s; %d of 40 level shots reached it" % [p.can_see(z.global_position + Vector3(0, 1.2, 0)), await _volley(z, 40)])
	z.queue_free()
	p.global_position = Vector3(14.0, 0.05, -37.0)
	await _wait(0.4)
	z = _zombie(Vector3(22.0, 0.1, -37.0))
	z.set_physics_process(false)
	await _wait(0.2)
	_say("board fence between you and a zombie 8 m off: seen %s; %d of 10 level shots reached it" % [p.can_see(z.global_position + Vector3(0, 1.2, 0)), await _volley(z, 10)])
	z.queue_free()
	p.global_position = Vector3(33.0, 0.05, -19.5)
	p.facing = Vector3(0, 0, -1)
	await _wait(0.4)
	z = _zombie(Vector3(33.0, 0.1, -26.0))
	z.set_physics_process(false)
	await _wait(0.2)
	_say("picket fence between you and a zombie 6.5 m off, standing: seen %s; %d of 10 level shots reached it" % [p.can_see(z.global_position + Vector3(0, 1.2, 0)), await _volley(z, 10)])
	# ---- cover
	p.global_position = Vector3(34.5, 0.05, -23.0)
	await _wait(0.3)
	var c := Cover.find_near(Vector2(34.5, -23.0), 1.6, Vector2(0, -1), 0.05)
	if not c.is_empty():
		var f: Cover.Face = c["face"]
		_say("by the picket fence: a %s cover face %.2f m high; someone hunkered there is hidden from across it: %s" % [
			"low" if f.low else "high", f.top, Cover.shields(f, Cover.spot(f, c["t"]), Vector2(34.5, -27.0))])
	c = Cover.find_near(Vector2(17.4, 22.0), 1.6, Vector2(1, 0), 0.05)
	if not c.is_empty():
		var f: Cover.Face = c["face"]
		_say("by the rail fence: a %s cover face %.2f m high (to vault); hidden from across it: %s" % [
			"low" if f.low else "high", f.top, Cover.shields(f, Cover.spot(f, c["t"]), Vector2(22.0, 22.0))])
	c = Cover.find_near(Vector2(17.4, -37.0), 1.6, Vector2(1, 0), 0.05)
	if not c.is_empty():
		var f: Cover.Face = c["face"]
		_say("by the board fence: a %s cover face %.2f m high; hidden from across it: %s" % [
			"low" if f.low else "high", f.top, Cover.shields(f, Cover.spot(f, c["t"]), Vector2(22.0, -37.0))])
	z.queue_free()
	# ---- vaulting
	for v: Array in [["picket", Vector3(34.5, 0.05, -22.9), Vector3(0, 0, -1), 2, -23.5], ["rail", Vector3(17.3, 0.05, 20.0), Vector3(1, 0, 0), 0, 18.0],
			["board", Vector3(17.3, 0.05, -37.0), Vector3(1, 0, 0), 0, 18.0]]:
		p.leave_cover()
		p.global_position = v[1]
		await _wait(0.3)
		p._cover_tap(v[2])
		await _wait(1.0)
		var into := p.in_cover
		if into:
			p._cover_tap(v[2])
		await _wait(1.2)
		var axis: int = v[3]
		var over := signf(p.global_position[axis] - float(v[4])) != signf((v[1] as Vector3)[axis] - float(v[4]))
		_say("%s fence: got over it with the cover button %s" % [v[0], over])
	p.leave_cover()
	# ---- the gate
	var gate: Door = null
	for d in get_nodes_in_group("interactables"):
		if d is Door and d.noun == "gate" and d.global_position.distance_to(Vector3(33, 0, -23.5)) < 2.0:
			gate = d
	if gate != null:
		p.global_position = Vector3(33.0, 0.05, -22.6)
		await _wait(0.3)
		var said := gate.prompt_text(p)
		gate.interact(p)
		await _wait(1.0)
		_say("the picket gate: \"%s\"; after interact it is %s; then \"%s\"" % [said, "shut" if gate.is_shut() else "open", gate.prompt_text(p)])
		gate.interact(p)
		await _wait(1.0)
	# ---- zombies
	await _crossing("picket fence (worn out, as the derelict house's is)", Vector3(34.8, 0.1, -21.5), Vector3(34.8, 0.05, -26.0), 2, -23.5, 40.0)
	await _crossing("rail fence", Vector3(15.5, 0.1, 27.0), Vector3(22.0, 0.05, 27.0), 0, 18.0, 40.0)
	await _crossing("board fence", Vector3(15.5, 0.1, -37.0), Vector3(22.0, 0.05, -37.0), 0, 18.0, 90.0)
	await _crossing("the board fence's gate, shut", Vector3(28.5, 0.1, -31.5), Vector3(28.5, 0.05, -37.0), 2, -34.0, 90.0)
	# ---- what is left
	var scraps := 0
	for wr: Wreck in Wreck.all:
		if is_instance_valid(wr) and wr.lot.has("wood") and wr.global_position.distance_to(Vector3(18, 0, -37)) < 3.0:
			scraps += 1
	_say("where the board fence was broken through: %d heap(s) of splintered wood to pick through" % scraps)
	quit()
