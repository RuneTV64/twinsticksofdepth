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
	_say("in boots: gone after %d footfalls, wounds %d" % [steps, b.wounds.size()])
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
