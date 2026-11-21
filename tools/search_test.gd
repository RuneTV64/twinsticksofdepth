extends SceneTree
## Headless test of searching (stash.gd, loot_screen.gd, item_grid.gd) in the real level: what is in the
## furniture, how long a drawer takes carefully and in a hurry and who hears it, what you see meanwhile,
## taking and putting back, things lying on things, a bag, and what breaking the piece does. Run from a
## scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://search_test.gd

var main: Node
var p: Player
var loot: LootScreen


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[search] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _ear(at: Vector3) -> Enemy:
	var z := Enemy.new()
	z.kind = "shambler"
	z.position = at
	main.add_child(z)
	z.player = p
	z.set_physics_process(false)
	z.set_process(false)
	z._drive = 0.0
	return z


func _carry() -> String:
	var out: Array[String] = []
	for sl in p.inv.slot_list():
		var it = p.inv.slots.get(sl[0])
		if it != null:
			out.append(Items.label(it))
	for wr in Inventory.WORN:
		var on = p.inv.worn.get(wr[0])
		if on != null:
			out.append("wearing " + Items.label(on))
	var bag = p.inv.worn.get("back")
	if bag != null:
		for it in ItemGrid.items(Items.hold_of(bag)):
			out.append("in the bag " + Items.label(it))
	return ", ".join(out) if not out.is_empty() else "nothing"


func _names(things: Array) -> String:
	return ", ".join(things.map(func(t: Dictionary) -> String: return Items.label(t["item"]) + (" (on top)" if int(t.get("z", 0)) > 0 else ""))) if not things.is_empty() else "nothing"


# The middle of a thing in the open part, on the screen.
func _at_thing(t: Dictionary) -> Vector2:
	var rc := ItemGrid.rect_of(t)
	return loot._box_origin() + (Vector2(rc.position) + Vector2(rc.size) * 0.5) * loot._box_cell()


func _stand_at(st: Stash) -> void:
	p.global_position = Vector3(st.global_position.x, st._floor_y(), st.global_position.z)
	p.velocity = Vector3.ZERO
	await _wait(0.3)


func _run() -> void:
	root.size = Vector2i(1600, 900)             # (headless has no window: the screen lays itself out by this)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	loot = main.hud.loot
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	if Horde.it != null:
		Horde.it.set_process(false)
		Horde.it.set_physics_process(false)
	await _wait(0.2)

	# ---- what there is to search
	var count := {}
	for s: Stash in get_nodes_in_group("stashes"):
		count[s.kind] = int(count.get(s.kind, 0)) + 1
	_say("in the level: %s" % count)
	seed(4)
	for kind: String in Stash.KINDS:
		for wear in [0, 2]:
			var things := 0
			var on_top := 0
			var empty := 0
			var squares := 0
			var sample := ""
			for n in 200:
				var s := Stash.for_piece(kind, kind, 1, wear)
				s._ready()
				for i in s.parts.size():
					var g: Dictionary = s.part(i)["grid"]
					things += g["things"].size()
					for t: Dictionary in g["things"]:
						on_top += int(t.get("z", 0))
					if g["things"].is_empty():
						empty += 1
					if n == 0:
						squares += int(g["w"]) * int(g["h"])
						sample += "%s%s: %s" % ["" if i == 0 else "; ", s.parts[i]["name"], _names(g["things"])]
				s.remove_from_group("interactables")
				s.remove_from_group("stashes")
				s.free()
			var parts_n: int = (Stash.KINDS[kind]["parts"] as Array).size()
			_say("%s, %s (%d parts, %d squares): %.1f things a piece, %.0f%% of them lying on something, %.0f%% of parts empty. One: %s" % [
				kind, "sound" if wear == 0 else "worn out", parts_n, squares, things / 200.0, 100.0 * on_top / maxf(things, 1.0), 100.0 * empty / (200.0 * parts_n), sample])

	# ---- searching the kit house's dresser
	var st: Stash = null
	for s: Stash in get_nodes_in_group("stashes"):
		if s.kind == "dresser" and s.plenty >= 1.0:
			st = s
	await _stand_at(st)
	var near := _ear(p.global_position + Vector3(6, 0, 0))
	var far := _ear(p.global_position + Vector3(11, 0, 0))
	_say("at the dresser: \"%s\"" % st.prompt_text(p))
	var range0 := p.view_range
	var near0 := p.view_near
	st.interact(p)
	await _wait(0.2)
	_say("searching %s, screen open %s, drawer %d (%s)" % [p.searching, loot.visible, loot._part + 1, st.parts[loot._part]["name"]])
	var drawer: Dictionary = st.part(0)
	_say("  what is really in the top drawer: %s" % _names(drawer["grid"]["things"]))
	# Carefully: the hand over each column in turn.
	var t := 0.0
	var seen_at := []
	for col in int(drawer["grid"]["w"]):
		loot._ptr = loot._box_origin() + Vector2((col + 0.5) * loot._box_cell(), loot._box_cell() * 0.5)
		while float(drawer["found"][col]) < 1.0 and t < 120.0:
			await physics_frame
			t += 1.0 / 60.0
		var showing := (drawer["grid"]["things"] as Array).filter(func(x: Dictionary) -> bool: return st.shows(0, x)).size()
		seen_at.append("%d after %.0f s" % [showing, t])
	_say("  carefully, a column at a time: things showing %s. Heard at 6 m: %s" % [", ".join(seen_at), near._drive > 0.0])
	_say("  while searching you see %.1f m ahead and %.1f m round you (before: %.0f and %.1f)" % [p.view_range, p.view_near, range0, near0])
	Input.action_press("look_up")
	await _wait(1.0)
	_say("  ALT held: you see %.0f m ahead and %.1f m round you; the screen fades to %.2f" % [p.view_range, p.view_near, loot.modulate.a])
	Input.action_release("look_up")
	await _wait(0.5)
	# In a hurry: the middle drawer.
	loot._part = 1
	var d2: Dictionary = st.part(1)
	Input.action_press("sprint")
	t = 0.0
	for col in int(d2["grid"]["w"]):
		loot._ptr = loot._box_origin() + Vector2((col + 0.5) * loot._box_cell(), loot._box_cell() * 0.5)
		while float(d2["found"][col]) < 1.0 and t < 120.0:
			await physics_frame
			t += 1.0 / 60.0
	Input.action_release("sprint")
	_say("  the middle drawer in a hurry (Shift): %.1f s. Heard at 6 m: %s, at 11 m: %s" % [t, near._drive > 0.0, far._drive > 0.0])
	near.queue_free()
	far.queue_free()

	# ---- taking, putting back, dragging
	var things: Array = (drawer["grid"]["things"] as Array).filter(func(x: Dictionary) -> bool: return st.shows(0, x))
	loot._part = 0
	if things.is_empty():
		drawer["grid"]["things"].append({"item": Items.make("bandage", 2), "x": 0, "y": 0, "z": 0})
		things = drawer["grid"]["things"]
	var first: Dictionary = things[0]
	loot._ptr = _at_thing(first)
	loot._press()
	loot._release()
	loot._press()                                   # the second click of a double-click
	loot._release()
	_say("double-click on the %s in the drawer: carrying %s; \"%s\"" % [Items.name_of(first["item"]["id"]).to_lower(), _carry(), loot._msg])
	# Drag it back out of the slot into the drawer.
	var key := p.inv.find(first["item"]["id"])
	var back_cell := Vector2i(-1, -1)
	for y in int(drawer["grid"]["h"]):
		for x in int(drawer["grid"]["w"]):
			if back_cell.x < 0 and st.can_put(0, first["item"]["id"], Vector2i(x, y)):
				back_cell = Vector2i(x, y)
	for b in loot._slot_boxes():
		if b["key"] == key:
			loot._ptr = (b["rect"] as Rect2).get_center()
	loot._press()
	var held := not loot._held.is_empty()
	loot._ptr = loot._box_origin() + (Vector2(back_cell) + Vector2(0.5, 0.5)) * loot._box_cell() + Vector2(0, 0)
	loot._held["grab"] = Vector2(loot._box_cell(), loot._box_cell()) * 0.5
	loot._release()
	_say("dragged from the slot (held: %s) to square %s of the drawer: carrying %s; the drawer has %s" % [held, back_cell, _carry(), _names(drawer["grid"]["things"])])
	# Drag a thing up out of the panel: it goes on the ground.
	var showing_now: Array = (drawer["grid"]["things"] as Array).filter(func(x: Dictionary) -> bool: return st.shows(0, x))
	if not showing_now.is_empty():
		var t0: Dictionary = showing_now[0]
		loot._ptr = _at_thing(t0)
		loot._press()
		loot._ptr = Vector2(800, 120)
		loot._release()
		await _wait(0.2)
		var lying := ""
		for n in get_nodes_in_group("interactables"):
			if n is ItemPickup and n.global_position.distance_to(p.global_position) < 1.2:
				lying = n.title
		_say("dragged up out of the panel: on the ground by you: %s" % (lying if lying != "" else "NOTHING"))

	# ---- things lying on things
	var g := ItemGrid.make(6, 3)
	g["things"].append({"item": Items.make("antibiotics"), "x": 1, "y": 1, "z": 0})
	g["things"].append({"item": Items.make("boots"), "x": 1, "y": 0, "z": 1})
	st.parts[2]["grid"] = g
	st.parts[2]["rolled"] = true
	st.parts[2]["found"].fill(1.0)
	loot._part = 2
	var under: Dictionary = g["things"][0]
	var over: Dictionary = g["things"][1]
	_say("boots lying on a bottle of antibiotics: the antibiotics show: %s; the square reads as: %s" % [
		st.shows(2, under), Items.name_of(loot._hit(loot._box_origin() + Vector2(1.5, 1.5) * loot._box_cell())["thing"]["item"]["id"])])
	loot._ptr = _at_thing(over)
	loot._press()
	loot._ptr = loot._box_origin() + Vector2(4.0, 1.0) * loot._box_cell()
	loot._held["grab"] = Vector2(loot._box_cell(), loot._box_cell())
	loot._release()
	_say("  boots dragged aside to %s: the antibiotics show: %s" % [Vector2i(int(over["x"]), int(over["y"])) if g["things"].has(over) else g["things"].map(func(x: Dictionary) -> String: return "%s at %d,%d" % [x["item"]["id"], x["x"], x["y"]]), st.shows(2, under)])
	# Putting a thing where you haven't looked.
	st.parts[2]["found"][5] = 0.0
	_say("  a column not yet looked in takes nothing: %s" % (not st.can_put(2, "bandage", Vector2i(5, 0))))
	st.parts[2]["found"][5] = 1.0

	# ---- shutting it
	Input.action_press("move_up")
	await _wait(0.3)
	Input.action_release("move_up")
	_say("a step away: searching %s, screen open %s" % [p.searching, loot.visible])
	await _stand_at(st)
	_say("back at it: \"%s\"" % st.prompt_text(p))
	st.interact(p)
	await _wait(0.2)
	_say("  open again: nothing left to go through: %s; things showing in the top drawer: %d of %d (the rest lie under something)" % [
		st.all_searched(), (st.parts[0]["grid"]["things"] as Array).filter(func(x: Dictionary) -> bool: return st.shows(0, x)).size(), st.parts[0]["grid"]["things"].size()])
	p.take_damage(5.0, Vector3(1, 0, 0), 0.0)
	await _wait(0.2)
	_say("hit while searching: searching %s" % p.searching)
	p.health = p.max_health
	p.sheet.body.reset()

	# ---- a bag
	for k in p.inv.slots.keys():
		p.inv.slots.erase(k)
	p.inv.add(Items.make("backpack"))
	p.use_item(p.inv.find("backpack"))
	for it in [Items.make("hammer"), Items.make("crowbar"), Items.make("sledgehammer"), Items.make("plank", 4), Items.make("bandage", 5),
			Items.make("matches"), Items.make("antibiotics"), Items.make("painkillers"), Items.make("cooking_pot"), Items.make("canned_food", 3), Items.make("water")]:
		var rest := p.inv.add(it)
		if not rest.is_empty():
			_say("  no room at all for: %s" % Items.label(rest))
	_say("with a backpack on, picking things up until nothing takes them: %s (%.1f kg)" % [_carry(), p.inv.weight()])
	_say("  the hammer can be used from where it is: %s; the tin in the bag: %s" % [p.inv.has("hammer"), p.inv.has("canned_food")])
	p.toggle_things()
	await _wait(0.2)
	_say("I: searching %s, a stash open: %s" % [p.searching, p.search != null])
	p.toggle_things()
	p.use_item("worn:back")
	_say("  taking the bag off with both hands full: \"%s\"" % p.status_text)
	p.inv.slots.erase("hand_l")
	p.use_item("worn:back")
	_say("  with a hand free it comes off into the hand with what is in it: %s (%.1f kg in that hand)" % [Items.label(p.inv.slots["hand_l"]), Items.weight(p.inv.slots["hand_l"])])
	p.use_item(p.inv.find("backpack"))
	_say("  and back on: %s" % _carry())

	# ---- breaking the piece
	var fridge: Stash = null
	for s: Stash in get_nodes_in_group("stashes"):
		if s.kind == "bookshelf" and s.plenty >= 1.0:
			fridge = s
	var inside := fridge.everything().size()
	var where := fridge.global_position
	var br := Breakable.of(fridge.get_parent())
	for i in 400:
		if not is_instance_valid(br) or not br.alive():
			break
		br.hit(60.0, "chop", where, p)
	await _wait(0.3)
	var spilled := ""
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and (n.title as String).begins_with("What was in"):
			spilled = "%s: %s" % [n.title, ", ".join((n.contents as Array).map(func(x): return Items.label(x)))]
	_say("a bookshelf with %d things in it, chopped up: %s" % [inside, spilled if spilled != "" else ("nothing on the floor" if inside == 0 else "NOTHING SPILLED")])

	# ---- dying with a bag
	p.invulnerable = false
	p._die("test")
	await _wait(0.3)
	for n in get_nodes_in_group("interactables"):
		if n is ItemPickup and (n.title as String).begins_with("Your"):
			_say("died: %s holds %d things, the bag among them with %d in it" % [n.title, n.contents.size(),
				(n.contents as Array).filter(func(x): return x["id"] == "backpack").map(func(x): return ItemGrid.items(x["grid"]).size())[0]])
	quit()
