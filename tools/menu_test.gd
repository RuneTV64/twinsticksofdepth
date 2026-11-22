extends SceneTree
## Headless test of the context menu (context_menu.gd), in the real level, driven by real mouse events: a
## tap still interacts, a hold opens the menu, sliding down and letting go picks, letting go first and
## clicking picks, Ready / Esc / a click off it shut it, and the rows for a window, shoes, glass and the
## curtains do what their old keys and Shift+clicks did. Run from a scratch copy (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://menu_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[menu] ", t)


func _wait(s: float) -> void:
	for i in maxi(1, int(s * 60.0)):
		await physics_frame


func _button(b: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = down
	e.button_mask = (MOUSE_BUTTON_MASK_LEFT if b == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if down else 0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _move(rel: Vector2, held := false) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await physics_frame


func _rows() -> String:
	var out: Array[String] = []
	for r in p.menu_rows:
		out.append(("[%s]" % r["head"]) if r.has("head") else str(r["label"]))
	return " | ".join(out)


## The pointer's y for row i (the middle of it).
func _row_y(i: int) -> float:
	return (i + 0.5) * Player.MENU_ROW_H


func _row_of(label_start: String) -> int:
	for i in p.menu_rows.size():
		if not p.menu_rows[i].has("head") and str(p.menu_rows[i]["label"]).begins_with(label_start):
			return i
	return -1


func _hold_open() -> void:
	_button(MOUSE_BUTTON_LEFT, true)
	await _wait(p.menu_hold + 0.1)


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

	# ---- a door: a tap opens it, as a click always did
	var door: Door = null
	for n in get_nodes_in_group("interactables"):
		if n is Door and not n.locked:
			door = n
			break
	var dp: Vector3 = door.interact_point()
	p.global_position = Vector3(dp.x, 0.0, dp.z) + Vector3(0.6, 0, 0.6)
	p.velocity = Vector3.ZERO
	await _wait(0.3)
	_say("by %s: prompt '%s'" % [door.name, p.interact_prompt()])
	var was_open := door._target
	_button(MOUSE_BUTTON_LEFT, true)
	await _wait(0.1)
	_say("tap: held 0.1 s, door changed yet %s, menu open %s" % [door._target != was_open, p.menu_open])
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.1)
	_say("  let go: door changed %s, menu open %s" % [door._target != was_open, p.menu_open])

	# ---- held: the menu opens, the door is left alone. (Back where we stood: the door may have pushed us.)
	await _wait(1.0)
	dp = door.interact_point()                    # (it swings with the door)
	p.global_position = Vector3(dp.x, 0.0, dp.z) + Vector3(0.6, 0, 0.6)
	p.velocity = Vector3.ZERO
	await _wait(0.3)
	_say("back by the door: interact target is the door %s" % (p.interact_target == door))
	was_open = door._target
	await _hold_open()
	_say("held %.1f s: menu open %s, door changed %s, hold ring at open %.2f" % [p.menu_hold + 0.1, p.menu_open, door._target != was_open, p.menu_hold_frac()])
	_say("  rows: %s" % _rows())
	var cross := p.reticle_offset
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.1)
	_say("  let go without moving: still open %s, door changed %s" % [p.menu_open, door._target != was_open])
	# Point at "Your things" and click.
	var i := _row_of("Your things")
	_move(Vector2(10, _row_y(i) - p.menu_vec.y))
	await _wait(0.05)
	_say("  pointer to row %d: choice %d ('%s'); crosshair moved %s" % [i, p.menu_choice, p.menu_rows[i]["label"], p.reticle_offset != cross])
	_button(MOUSE_BUTTON_LEFT, true)
	await _wait(0.05)
	_say("  click: menu open %s, searching (your things) %s" % [p.menu_open, p.searching])
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.1)
	p.stop_search()
	await _wait(0.1)

	# ---- held, slide down, let go: the door's own row
	was_open = door._target
	await _hold_open()
	i = _row_of(door.prompt_text(p))
	_move(Vector2(0, _row_y(i) - p.menu_vec.y), true)
	await _wait(0.05)
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.1)
	_say("slide to '%s' and let go: menu open %s, door changed %s" % [p.menu_rows[i]["label"] if p.menu_open else door.name, p.menu_open, door._target != was_open])

	# ---- shutting it: Ready, Esc, a click off the list
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	_button(MOUSE_BUTTON_RIGHT, true)
	await _wait(0.1)
	_say("Ready held: menu open %s, armed %s" % [p.menu_open, p.armed])
	_button(MOUSE_BUTTON_RIGHT, false)
	await _wait(0.6)
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	await _key(KEY_ESCAPE)
	_say("Esc: menu open %s, mouse still captured-mode untouched %s" % [p.menu_open, true])
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	_move(Vector2(0, -200))
	await _wait(0.05)
	_button(MOUSE_BUTTON_LEFT, true)
	await _wait(0.05)
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	_say("click above the list: menu open %s" % p.menu_open)
	# Key 1 picks the first row.
	was_open = door._target
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	await _key(KEY_1)
	_say("key 1: menu open %s, door changed %s" % [p.menu_open, door._target != was_open])
	p.stop_search()
	await _wait(0.1)

	# ---- nothing in front of you: only your own rows
	p.global_position = Vector3(0, 0, 20)
	await _wait(0.3)
	p.inv.add(Items.make("boots"))
	var g := Items.make("glass_shard"); g["n"] = 3
	p.inv.add(g)
	p.inv.add(Items.make("water"))
	p.inv.add(Items.make("purify_tabs"))
	await _hold_open()
	_say("in the open, interact target %s: rows %s" % [p.interact_target, _rows()])
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	var shoes := p.shoes_job()
	p.menu_choice = _row_of("Take off")
	p._menu_pick()
	await _wait(0.1)
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	p.menu_choice = _row_of("Put on")
	var shoes2 := p.shoes_job()
	p._menu_pick()
	await _wait(0.1)
	shoes += "', then '" + shoes2
	_say("'%s': wearing on the feet %s; the row now reads '%s'" % [shoes, Items.name_of(p.inv.worn["feet"]["id"]) if p.inv.worn.has("feet") else "nothing", p.shoes_job()])
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	p.menu_choice = _row_of("Scatter")
	p._menu_pick()
	await _wait(0.1)
	var wrecks := 0
	for w in get_nodes_in_group("interactables"):
		if w is Wreck and w.global_position.distance_to(p.global_position) < 2.0:
			wrecks += 1
	_say("scatter the glass: glass left on you %s, broken glass on the ground by you %d; status '%s'" % [p.inv.find("glass_shard") != "", wrecks, p.status_text])
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	p.menu_choice = _row_of("Treat your water")
	p._menu_pick()
	_say("treat your water: '%s'" % p.status_text)

	# ---- at a window, with the carpenter's things
	var win := Solid.window_near(Vector3(-19, 1, -55.4), 1.5)
	var wp: Vector3 = win["pos"]
	p.global_position = Vector3(wp.x - 0.9, 0.0, wp.z)
	p.velocity = Vector3.ZERO
	p.reticle_offset = Vector3(wp.x - p.global_position.x, 0.0, wp.z - p.global_position.z)
	for id in ["hammer", "nails", "plank"]:
		var it := Items.make(id)
		if id == "plank":
			it["n"] = 4
		p.inv.add(it)
	await _wait(0.2)
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	_say("at a window: rows %s" % _rows())
	p.menu_choice = _row_of("Board it up")
	p._menu_pick()
	await _wait(p.board_time + 0.5)
	var boarded: bool = win["boards"] != null or not Solid.window_near(wp, 0.5, 0.0)["boards"] == null
	_say("board it up: boarded %s; the row now reads '%s'" % [boarded, p.window_job()])

	# ---- curtains and an appliance: their old Shift+clicks are rows
	var curt: WindowCurtains = null
	for n in get_nodes_in_group("interactables"):
		if n is WindowCurtains:
			curt = n
			break
	var cp := curt.interact_point()
	p.global_position = Vector3(cp.x, curt.floor_y, cp.z)
	p.reticle_offset = Vector3.ZERO
	await _wait(0.3)
	_say("by the curtains: target %s, prompt '%s'" % [p.interact_target is WindowCurtains, p.interact_prompt()])
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	_say("  rows %s" % _rows())
	p.menu_choice = _row_of("Take the curtains down")
	p._menu_pick()
	await _wait(0.1)
	_say("  taken down: curtains gone %s, carrying curtains %s" % [not is_instance_valid(curt), p.inv.find("curtains") != ""])

	var lamp: Appliance = null
	for n in get_nodes_in_group("interactables"):
		if n is Appliance and n.kind == "floor_lamp":
			lamp = n
	var lp := lamp.interact_point()
	p.global_position = Vector3(lp.x, lamp.global_position.y - 0.8, lp.z) + Vector3(0.5, 0, 0)
	p.global_position.y = 0.0
	await _wait(0.3)
	_say("by the floor lamp: prompt '%s'" % p.interact_prompt())
	await _hold_open()
	_button(MOUSE_BUTTON_LEFT, false)
	await _wait(0.05)
	_say("  rows %s" % _rows())

	# ---- the Admin submenu: the old letter test keys, and the torch
	p.inv.add(Items.make("torch"))
	p.open_menu()
	_say("with a torch: its row '%s'" % p.menu_rows[_row_of("Switch the hand torch")]["label"])
	p.menu_choice = _row_of("Admin")
	p._menu_pick()
	await _wait(0.05)
	_say("Admin: menu still open %s, page '%s', rows %s" % [p.menu_open, p.menu_page, _rows()])
	var was_rain: bool = Seasons.it.raining
	p.menu_choice = _row_of("Make it rain" if not was_rain else "Stop the rain")
	p._menu_pick()
	await _wait(0.05)
	_say("  rain row: raining %s -> %s, menu open %s" % [was_rain, Seasons.it.raining, p.menu_open])
	var wounds := p.sheet.body.wounds.size()
	p.open_menu()
	p.menu_choice = _row_of("Admin")
	p._menu_pick()
	p.menu_choice = _row_of("A test wound")
	p._menu_pick()
	_say("  test wound row: wounds %d -> %d" % [wounds, p.sheet.body.wounds.size()])
	p.open_menu()
	p.menu_choice = _row_of("Admin")
	p._menu_pick()
	var was_on: bool = main.cutaway.enabled
	p.menu_choice = _row_of("Cutaway")
	p._menu_pick()
	_say("  cutaway row: %s -> %s" % [was_on, main.cutaway.enabled])
	p.open_menu()
	p.menu_choice = _row_of("Admin")
	p._menu_pick()
	p.menu_choice = _row_of("< Back")
	p._menu_pick()
	_say("  back: open %s, page '%s', first rows %s" % [p.menu_open, p.menu_page, _rows().substr(0, 60)])
	p.close_menu()
	# the old letter keys do nothing now
	var rain_now: bool = Seasons.it.raining
	await _key(KEY_K)
	_say("K pressed: rain changed %s (should be false)" % (Seasons.it.raining != rain_now))
	quit()
