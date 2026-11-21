extends SceneTree
## Headless test of impaling (owner, 21 Nov 2026: "if its got spikes bodies can be impaled on them"), on a
## picket fence put up for it in the real level. Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://impale_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[impale] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## A zombie on two legs.
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
	# A sound picket fence across the meadow, running north to south at x -31.
	var f := FenceKit.new(main, "picket")
	f.run(Vector2(-31.0, -26.0), Vector2(-31.0, 0.0))
	_say("a picket fence has points: its chance of catching a body going over it is %.2f; board %.2f, rail %.2f" % [
		f.parts[0].spikes, float(FenceKit.KINDS["board"]["spikes"]), float(FenceKit.KINDS["rail"]["spikes"])])
	# ---- zombies climbing it, one at a time, each at a fresh stretch
	var n := 14
	var stuck := 0
	var died := 0
	var got_off := 0
	var fence_gave := 0
	var limbs := 0
	var hang := 0.0
	var finish_ok := false
	for i in n:
		var zpos := Vector3(-32.2, 0.1, -24.0 + i * 1.7)
		p.global_position = Vector3(-28.5, 0.05, zpos.z)
		var z := _zombie(zpos)
		var t := 0.0
		var was := false
		var t_on := 0.0
		var parts0 := 0
		while t < 34.0:
			await physics_frame
			t += 1.0 / 60.0
			if not is_instance_valid(z):
				break
			if z.state == "impaled" and not was:
				was = true
				t_on = t
				stuck += 1
				parts0 = z.body.legs() + z.body.hands()
				if not finish_ok:
					finish_ok = z.is_down() and absf(z.aim_point().y - (z.global_position.y + z.perch)) < 0.01
			if was and (z.dead or z.state != "impaled"):
				hang += t - t_on
				if z.dead:
					died += 1
				elif Breakable.spiked(Vector2(z._impale_at.x, z._impale_at.z), 0.3, 0.1) == null:
					fence_gave += 1
				else:
					got_off += 1
				limbs += parts0 - (z.body.legs() + z.body.hands())
				break
			if not was and z.global_position.x > -30.4 and z.state != "climb":
				break
		if is_instance_valid(z):
			z.queue_free()
		await _wait(0.1)
	_say("%d zombies sent over a sound picket fence, one at a time: %d stuck on the points" % [n, stuck])
	if stuck > 0:
		var done := died + got_off + fence_gave
		_say("  of those: %d died there, %d pulled themselves off, %d came down when the fence gave way, %d still hanging after half a minute; %d limbs torn off; %.1f s on the points on average for those that came off" % [
			died, got_off, fence_gave, stuck - done, limbs, hang / maxf(float(done), 1.0)])
	_say("  one hanging there counts as down (it can be finished), and is aimed at where it hangs: %s" % finish_ok)
	# ---- a body already on the points covers them
	var a := _zombie(Vector3(-31.0, 0.1, -40.0))
	a.set_physics_process(false)
	a.hung = true
	Enemy.impaled.append(a)
	_say("points with a body already on them count as covered: %s; 1 m along: %s" % [
		Enemy._points_covered(Vector3(-31.0, 0.1, -40.2)), Enemy._points_covered(Vector3(-31.0, 0.1, -41.2))])
	Enemy.impaled.erase(a)
	a.queue_free()
	# ---- knocked backward onto it
	var f2 := FenceKit.new(main, "picket")
	f2.run(Vector2(-36.0, 3.0), Vector2(-25.0, 3.0))
	var m := 30
	var on := 0
	for i in m:
		var z := _zombie(Vector3(-35.5 + i * 0.34, 0.1, 2.45))
		z.set_physics_process(false)
		z.facing = Vector3(0, 0, -1)                 # its back to the fence
		z._knock_down(Vector3(0, 0, 1))
		if z.state == "impaled" or z.hung:
			on += 1
		z.hung = false
		Enemy.impaled.erase(z)
		z.free()
	_say("%d zombies standing with their backs to a picket fence, knocked down backward: %d came down on the points" % [m, on])
	# ---- the player vaulting it
	var f3 := FenceKit.new(main, "picket")
	f3.run(Vector2(-36.0, -34.0), Vector2(-25.0, -34.0))
	var b3: Breakable = f3.parts[0]
	p.invulnerable = false
	var cuts := 0
	var tries := 60
	for i in tries:
		p.sheet.body.wounds.clear()
		p.health = p.max_health
		p.global_position = Vector3(-30.0, 0.05, -33.3)
		p._vault_from = p.global_position
		p._vault_to = Vector3(-30.0, 0.05, -34.9)
		p._vault_h = 0.55
		p._vault_t = p.vault_time
		p._vault_spiked = b3
		await _wait(p.vault_time + 0.1)
		if not p.sheet.body.wounds.is_empty():
			cuts += 1
	_say("the player vaulting a picket fence %d times, calm: caught a leg on the points %d times" % [tries, cuts])
	# ---- falling onto it
	p.sheet.body.wounds.clear()
	p.health = p.max_health
	p._stagger = 0.0
	p.global_position = Vector3(-30.0, 3.4, -33.7)
	p.velocity = Vector3.ZERO
	var hp0 := p.health
	await _wait(1.6)
	var kinds := []
	for w in p.sheet.body.wounds:
		kinds.append("%s on %s" % [w["kind"], w["part"]])
	_say("the player dropped 3.4 m beside the fence: health %.0f to %.0f; wounds: %s; the fence there is %s" % [hp0, p.health, ", ".join(kinds),
		"still standing" if Breakable.spiked(Vector2(-30.0, -34.0), 0.3, 0.05) != null else "broken"])
	quit()
