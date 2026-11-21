extends SceneTree
## Headless test of water (water.gd, water_source.gd, campfire.gd). Run from a scratch copy (copy this file to
## its root):   godot --headless --fixed-fps 60 -s res://water_test.gd

func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[water] ", t)


func _run() -> void:
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 20:
		await physics_frame
	var p: Player = main.player
	var b := p.sheet.body
	p.inv.add(Items.make("water"))
	p.inv.add(Items.make("purify_tabs"))
	p.inv.add(Items.make("water_filter"))
	var item: Dictionary = p.inv.slots[p.inv.find("water")]
	_say("as found: %s; a wound washed with it is left with germs %.2f" % [Items.label(item), Water.wash_germs(item)])
	var srcs := {}
	for n in get_nodes_in_group("interactables"):
		if n is WaterSource:
			srcs[n.kind] = n
	var fire: Campfire = null
	for n in get_nodes_in_group("interactables"):
		if n is Campfire and n.global_position.distance_to(Vector3(-9, 0, 8)) < 1.0:
			fire = n
	for kind: String in ["rain", "pond"]:
		for how: String in ["nothing", "boil", "tablet", "filter", "filter then tablet", "filter then boil"]:
			item["uses"] = 0
			srcs[kind].interact(p)
			var first := Items.label(item)
			if how.begins_with("filter"):
				p.purify_water()
			if how.ends_with("tablet"):
				p.purify_water() if how != "tablet" else Water.tablet(item)
				Water.tick(item, Water.TAB_WAIT + 1.0)
			if how.ends_with("boil"):
				p.global_position = fire.global_position + Vector3(1, 0.05, 0)
				fire.interact(p)
				for i in int((Water.BOIL_TIME + 1.0) * 60):
					p.global_position = fire.global_position + Vector3(1, 0.05, 0)
					await process_frame
			var ill := 0
			for i in 400:
				b.reset()
				b.drink(Water.bugs(item))
				ill += 1 if b.gut_coming > 0.0 else 0
			_say("%s, %s: %s -> %s; dirt %.2f bugs %.2f; washing leaves germs %.2f (%s); drinking made ill %d in 400" % [Water.SOURCES[kind]["name"], how, first, Items.label(item), Water.dirt(item), Water.bugs(item), Water.wash_germs(item), "clean" if Water.wash_germs(item) <= b.shrug else "not clean", ill])
	# One drink of pond water that takes: how it goes.
	b.reset()
	b.gut_coming = 0.3 + 0.6 * 0.9
	var t := 0.0
	var worst := 0.0
	var feel := ""
	var seen: Array[String] = []
	while t < 3000.0 and (b.gut > 0.0 or b.gut_coming > 0.0):
		b.tick(0.5)
		t += 0.5
		worst = maxf(worst, b.gut)
		if b.gut_feel() != feel:
			feel = b.gut_feel()
			seen.append("%s at %d s" % [feel if feel != "" else "well", roundi(t)])
	_say("one drink of standing water that takes: %s; septic reached %.2f" % [", ".join(seen), b.septic])
	# The barrel breaks: the water goes with it.
	var barrel := Breakable.under(Vector2(-8, 5))
	barrel.hit(100000.0, "pound", Vector3(-8, 0.5, 5))
	await physics_frame
	await physics_frame
	var left := 0
	for n in get_nodes_in_group("interactables"):
		if n is WaterSource:
			left += 1
	_say("the %s smashed: water sources left %d of 2; bottle when emptied: %s" % [barrel.title if is_instance_valid(barrel) else "barrel", left, _empty(p, item)])
	quit()


func _empty(p: Player, item: Dictionary) -> String:
	for i in 6:
		p.inv.use("water")
	return Items.label(item) + (", still carried" if p.inv.has("water") else ", GONE")
