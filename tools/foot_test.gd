extends SceneTree
## Headless test of bare feet, glass, blood and ordinary infection (wreck.gd, spill.gd, body_health.gd,
## Player._step_in_it). Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://foot_test.gd

func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[foot] ", t)


func _run() -> void:
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 20:
		await physics_frame
	var p: Player = main.player
	var b := p.sheet.body
	b.medical = 4
	# A window's worth of broken glass.
	var w := Wreck.leave(main, Vector3(3, 0, 12), 0.6, {"glass": 1.0}, 1.54, "window")
	var shards := w.left("glass")
	p.global_position = Vector3(3, 0.05, 12)
	var steps := 0
	while is_instance_valid(w) and w.lot.has("glass") and steps < 200:
		p._step_side = -p._step_side
		p._step_in_it()
		steps += 1
	_say("barefoot on a broken window (%d shards): gone after %d footfalls; wounds: %s" % [shards, steps, b.wounds.map(func(x): return "%s %s %s sev %.2f glass %d" % [x["part"], x["where"], x["kind"], x["sev"], x["glass"]])])
	_say("  left leg reads: %s" % [b.describe("LegL")])
	_say("  leg pain %.2f, bleeding %.2f a second" % [b.leg_pain, b.bleeding])
	# Shod, for comparison.
	b.reset()
	p.barefoot = false
	w = Wreck.leave(main, Vector3(3, 0, 12), 0.6, {"glass": 1.0}, 1.54, "window")
	steps = 0
	while is_instance_valid(w) and w.lot.has("glass") and steps < 200:
		p._step_in_it()
		steps += 1
	_say("in boots: after %d footfalls the glass is %s, wounds %d" % [steps, "still there" if is_instance_valid(w) and w.lot.has("glass") else "gone", b.wounds.size()])
	w.interact(p)
	await physics_frame
	_say("  picked up by hand: carrying %s; glass left on the ground: %s" % [p.inv.slots.values().map(func(i): return Items.label(i)), is_instance_valid(w) and w.lot.has("glass")])
	# Laid as a trap, and a raider walks over it.
	p.global_position = Vector3(10, 0.05, 12)
	p.lay_glass()
	var trap := Wreck.all[Wreck.all.size() - 1]
	_say("laid as a trap: %s with %d shards" % [trap.title, trap.left("glass")])
	var r: Raider = main._raider(trap.global_position)
	await physics_frame
	var hp0 := r.hp
	var n := 0
	var cuts := 0
	while is_instance_valid(trap) and trap.lot.has("glass") and n < 100:
		if Wreck.step_on(trap.global_position, r, 1.0, true) == 2:
			r.cut_foot()
			cuts += 1
		n += 1
	_say("  a raider walking on it: %d shards in his feet over %d footfalls, health %d -> %d, limping %s, trap %s" % [cuts, n, roundi(hp0), roundi(r.hp), r._glass_t > 0.0, "used up" if not (is_instance_valid(trap) and trap.lot.has("glass")) else "still there"])
	r.queue_free()
	# Crawling over a window's worth, in boots.
	b.reset()
	p.barefoot = false
	p.posture = 2
	w = Wreck.leave(main, Vector3(-8, 0, 12), 0.6, {"glass": 1.0}, 3.0, "window")
	p.global_position = Vector3(-8, 0.05, 12)
	n = 0
	while is_instance_valid(w) and w.lot.has("glass") and n < 100:
		p._step_in_it()
		n += 1
	_say("crawling over 6 shards in boots: all in you after %d drags (about %.1f m); wounds: %s; pain %.2f, bleeding %.2f a second" % [n, n * 0.2, b.wounds.map(func(x): return "%s sev %.2f glass %d" % [x["part"], x["sev"], x["glass"]]), b.pain, b.bleeding])
	p.posture = 0
	# A zombie walking over a trap.
	w = Wreck.leave(main, Vector3(-8, 0, 16), 0.6, {"glass": 1.0}, 1.5, "window")
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = Vector3(-8, 0.05, 16)
	main.add_child(z)
	await physics_frame
	var zhp := z.hp
	n = 0
	while is_instance_valid(w) and w.lot.has("glass") and n < 100:
		z._step_from = z.global_position + Vector3(2, 0, 0)
		z._leave_tracks()
		n += 1
	_say("a zombie walking on 3 shards: gone into its feet after %d footfalls; its health %d -> %d" % [n, roundi(zhp), roundi(z.hp)])
	z.queue_free()
	p.barefoot = true

	# How long each kind of ground takes to turn an open cut foot bad, walking (one stride 0.7 m, 2 a second).
	for case: Array in [["ordinary ground", 0], ["fresh zombie blood, one step then ordinary ground", 1], ["old blood, one step then standing still", 2], ["old blood, one step, washed 20 s later", 3], ["old blood, one step, washed 70 s later", 4]]:
		b.reset()
		Spill.it.stains.clear()
		var cut := b.hurt("cut", "LegL", 7.0, "foot")
		cut["debris"] = 0
		p.global_position = Vector3(3, 0.05, 14)
		if case[1] == 1:
			Spill.leave(p.global_position, true)
		elif case[1] >= 2:
			Spill.leave(p.global_position, true)
			Spill.it.age(600.0, 0.0)
		p._step_side = 1
		p._step_in_it()
		Spill.it.stains.clear()
		var t := 0.0
		var hold_t := -1.0
		var bad_t := -1.0
		var dead_t := -1.0
		var washed := false
		while t < 3000.0 and dead_t < 0.0:
			if case[1] <= 1:
				p._step_in_it()      # every half second: a stride
			if (case[1] == 3 and t >= 20.0 or case[1] == 4 and t >= 70.0) and not washed:
				washed = true
				b.wash(cut)
				b.dress(cut, "bandage")
			b.tick(0.5)
			t += 0.5
			if not b.wounds.has(cut):
				break
			if hold_t < 0.0 and float(cut["inf"]) >= b.hold:
				hold_t = t
			if bad_t < 0.0 and float(cut["inf"]) >= 1.0:
				bad_t = t
			if b.dead_from_sepsis():
				dead_t = t
		_say("%s: took hold at %s, fully infected at %s, dead at %s%s; zombie infection: %s" % [case[0], _t(hold_t), _t(bad_t), _t(dead_t), "" if b.wounds.has(cut) else " (the wound closed at %s)" % _t(t), b.infected])
	# Zombie blood: how often one step takes.
	var took := 0
	for i in 400:
		b.reset()
		b.hurt("cut", "LegL", 7.0, "foot")
		Spill.it.stains.clear()
		Spill.leave(p.global_position, true)
		p._step_in_it()
		took += 1 if b.infected else 0
	_say("one step in fresh zombie blood with an open cut foot: infected %d times in 400" % took)
	b.reset()
	var c2 := b.hurt("cut", "LegL", 7.0, "foot")
	c2["debris"] = 0
	c2["clean"] = true
	b.dress(c2, "bandage")
	p._step_in_it()
	_say("the same with the foot bandaged: germs %.2f, infected %s" % [float(c2["germs"]), b.infected])
	quit()


func _t(s: float) -> String:
	return "never" if s < 0.0 else "%d s" % roundi(s)
