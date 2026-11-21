extends SceneTree
## Headless test of clothes (clothes.gd, inventory.gd, the clothing items): what you start in, the slots your
## clothes give you and what stays in their pockets, a sling, bites and cuts met by what you wear, a helmet, a
## tablecloth bundle, straining water through a net curtain, taking cloth apart, and dying dressed. In the real
## level. Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://clothes_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[clothes] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _slots() -> String:
	var out: Array[String] = []
	for sl in p.inv.slot_list():
		var it = p.inv.slots.get(sl[0])
		out.append("%s %s" % [sl[1], ("[" + Items.label(it) + "]") if it != null else "-"])
	return ", ".join(out)


func _worn() -> String:
	var out: Array[String] = []
	for wr in Inventory.WORN:
		if p.inv.worn.has(wr[0]):
			out.append("%s: %s" % [wr[0], Items.label(p.inv.worn[wr[0]])])
	return ", ".join(out)


## Bites on each part, `n` times, against what is worn now: how many got through to the skin.
func _bites(n: int, kind := "bite") -> String:
	var out: Array[String] = []
	for part in ["ArmL", "Torso", "LegL", "Head"]:
		var through := 0
		for i in n:
			p.sheet.body.wounds.clear()
			for k in p.inv.worn:           # each bite on clothes as they were (how fast they go: below)
				p.inv.worn[k].erase("tatter")
			p._wound(kind, 10.0, part)
			for w in p.sheet.body.wounds:
				if w["kind"] == kind:
					through += 1
					break
		out.append("%s %d/%d" % [part, through, n])
	p.sheet.body.reset()
	return ", ".join(out)


func _fresh() -> void:
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)
	for k in p.inv.worn.keys():
		p.inv.worn.erase(k)


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	if Horde.it != null:
		Horde.it.set_process(false)
		Horde.it.set_physics_process(false)
	await _wait(0.2)

	var cloth: Array[String] = []
	for id: String in Items.DEFS:
		if Items.DEFS[id].has("wear"):
			cloth.append("%s (%s)" % [id, Items.DEFS[id]["wear"]])
	_say("%d items; worn things: %s" % [Items.DEFS.size(), ", ".join(cloth)])
	_say("found in a living room: %s" % ", ".join(Items.found_in("living room")))
	_say("you start in: %s; barefoot %s" % [_worn(), p.barefoot])
	_say("  slots: %s" % _slots())
	_say("  drawn: %d layers; warmth %.2f" % [Clothes.layers_of(p.inv.worn).size(), Clothes.warmth(p.inv.worn)])

	# ---- pockets go with the trousers
	p.inv.add(Items.make("painkillers"))
	p.inv.add(Items.make("matches"))
	p.inv.add(Items.make("hatchet"))
	_say("picked up painkillers, matches, a hatchet: %s" % _slots())
	var w0 := p.inv.weight()
	p.use_item("worn:legs")
	_say("jeans off: %s; weight %.2f -> %.2f; the jeans' label %s" % [_slots(), w0, p.inv.weight(), Items.label(p.inv.slots.get(p.inv.find("jeans"), {"id": "rock", "n": 1}))])
	p.use_item(p.inv.find("jeans"))
	_say("jeans back on: %s" % _slots())
	p.use_item("worn:waist")
	p.use_item("worn:legs")
	_say("jeans and belt off: %s" % _slots())
	p.drop_item("hand_l")
	p.drop_item("hand_r")
	p.inv.add(Items.make("rock"))
	var r := p.inv.add(Items.make("bottle"))
	var r2 := p.inv.add(Items.make("water"))
	_say("in nothing but a t-shirt, socks and sneakers, picked up a rock, a bottle, a bottle of water: %s; left over: %s" % [_slots(), Items.label(r2) if not r2.is_empty() else "nothing"])

	# ---- a sling
	_fresh()
	p.inv.don(Items.make("curtain_tieback"))
	p._worn_changed()
	var pl := p.inv.add(Items.make("plank"))
	var bt := p.inv.add(Items.make("bottle"))
	_say("tie-back worn, picked up a plank and a bottle: %s" % _slots())
	_say("  so the plank is %s, and the bottle %s" % ["slung" if p.inv.slots.get("strap:0", {}).get("id", "") == "plank" else "in a hand",
		"in a hand" if p.inv.find("bottle").begins_with("hand") else "slung"])

	# ---- bites
	_fresh()
	p._worn_changed()
	_say("bites that broke the skin, naked: %s" % _bites(200))
	p.dress_start()
	_say("bites, in the clothes you start in: %s" % _bites(200))
	var jeans: Dictionary = p.inv.worn["legs"]
	jeans.erase("tatter")
	var nb := 0
	var stopped := 0
	while float(jeans.get("tatter", 0.0)) < 0.75 and nb < 500:
		p.sheet.body.wounds.clear()
		var before := float(jeans.get("tatter", 0.0))
		p._wound("bite", 10.0, "LegL")
		nb += 1
		if p.sheet.body.wounds.filter(func(w): return w["kind"] == "bite").is_empty():
			stopped += 1
	_say("  bites on the legs until the jeans are in tatters: %d (they stopped %d of them); now %s" % [nb, stopped, Items.label(jeans)])
	_fresh()
	p.dress_start()
	p.inv.don(Items.make("curtains"))
	p.inv.don(Items.make("boots"))
	p.inv.don(Items.make("helmet"))
	p._worn_changed()
	_say("bites, with curtains round the shoulders, boots and a helmet: %s" % _bites(200))
	_say("glass cuts crawling, same clothes: %s" % _bites(200, "cut"))
	_say("a head hit: %.0f%% gets through the helmet; bare-headed %.0f%%" % [p.head_share() * 100.0, 100.0])
	_say("warmth now %.2f; layers drawn %d" % [Clothes.warmth(p.inv.worn), Clothes.layers_of(p.inv.worn).size()])

	# ---- a tablecloth bundle
	_fresh()
	p.dress_start()
	p.inv.don(Items.make("tablecloth"))
	for id in ["cooking_pot", "canned_food", "plank", "torch", "water", "hammer", "crowbar", "vodka", "matches", "rock", "battery", "bandage", "hatchet"]:
		p.inv.add(Items.make(id))
	var bag := Items.hold_of(p.inv.worn["back"])
	var inbag: Array[String] = []
	for it in ItemGrid.items(bag):
		inbag.append(Items.label(it))
	_say("tablecloth bundle on, picked up thirteen things: slots %s; in the bundle: %s" % [_slots(), ", ".join(inbag)])

	# ---- straining
	_fresh()
	p.dress_start()
	var wt := Items.make("water")
	wt["dirt"] = 0.7
	wt["bugs"] = 0.9
	p.inv.slots["hand_r"] = wt
	p.inv.slots["hand_l"] = Items.make("net_curtain")
	p.purify_water()
	_say("muddy water through the net curtain: '%s'; dirt %.2f, bugs %.2f" % [p.status_text, Water.dirt(wt), Water.bugs(wt)])

	# ---- taking cloth apart
	p.inv.slots.erase("hand_l")
	p.inv.slots.erase("hand_r")
	p.inv.slots["hand_r"] = Items.make("curtains")
	p.take_apart("hand_r")
	var t := 0.0
	while p._work == "apart":
		await physics_frame
		t += 1.0 / 60.0
	_say("curtains torn up: %.1f s, '%s'" % [t, p.status_text])

	# ---- dying dressed
	p.inv.add(Items.make("bandage", 2))
	p.sheet.body.infected = false
	p._die("Test.")
	var body: ItemPickup = null
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and n.title == "Your body":
			body = n
	var left: Array[String] = []
	if body != null:
		for it in body.contents:
			left.append(Items.label(it) + (" (with %d things in its pockets)" % (it["pocketed"] as Dictionary).size() if it.has("pocketed") else ""))
	_say("died dressed; your body holds: %s" % ", ".join(left))
	await _wait(3.5)
	_say("the next one starts in: %s" % _worn())
	quit()
