class_name ContextMenu
extends RefCounted
## The context menu (owner, 22 Nov 2026: every new piece of player work had been put on a key of its own; "Lets
## create a context menu and put some of this functionality inside there instead"). Hold left-click with the
## weapon lowered (`Player.menu_hold` 0.3 s) and it opens at the crosshair; a tap still does the one thing the
## prompt names. Move the mouse down the list and let go to pick, or let go first and click. Esc, Ready or a
## click off the list shuts it. Keys 1 to 9 pick a row too. Which button opens it may move later (owner).
##
## New things the player does go here, not on a key: an entry for the thing in front of you (an interactable's
## `context_actions(p) -> [[label, id], ...]`, done by its `context_do(p, id)`), or one for yourself below.
## Each row: {"label", "do": Callable, "key": a key that does the same (shown greyed; "" for none)}; a section
## title is {"head": text}. Only what can be done now (or what you'd want told you can't) is listed.


static func build(p: Player) -> Array:
	var rows: Array = []
	var t: Node = p.interact_target
	if t != null and is_instance_valid(t):
		var here: Array = []
		var what := str(t.call("prompt_text", p))
		if what != "":
			here.append({"label": what, "do": p.menu_interact.bind(t), "key": "click"})
		if t.has_method("context_actions"):
			for a in t.call("context_actions", p):
				here.append({"label": str(a[0]), "do": p.menu_thing.bind(t, str(a[1])), "key": ""})
		if not here.is_empty():
			rows.append({"head": "HERE"})
			rows.append_array(here)

	var win := p.window_job()
	if win != "":
		rows.append({"head": "THE WINDOW"})
		rows.append({"label": win, "do": p.work_window, "key": ""})

	rows.append({"head": "YOU"})
	rows.append({"label": "Your things", "do": p.toggle_things, "key": "I"})
	rows.append({"label": "See to your wounds", "do": p.toggle_treat, "key": "H"})
	if p.hud != null:
		rows.append({"label": "Character page", "do": p.hud.toggle_sheet, "key": "C"})
	var wk := p.inv.find("water")
	if wk != "" and int(p.inv.slots[wk].get("uses", 0)) > 0:
		rows.append({"label": "Drink from your bottle", "do": p.drink_water, "key": ""})
		if p.inv.has("water_filter") or p.inv.has("purify_tabs") or p.inv.tool_for("strain") != "":
			rows.append({"label": "Treat your water (filter, cloth or tablets)", "do": p.purify_water, "key": ""})
	var shoes := p.shoes_job()
	if shoes != "":
		rows.append({"label": shoes, "do": p.toggle_shoes, "key": ""})
	if p.inv.find("glass_shard") != "" or p.inv.find("bloody_glass") != "":
		rows.append({"label": "Scatter your broken glass here (a trap, an alarm)", "do": p.lay_glass, "key": ""})
	return rows
