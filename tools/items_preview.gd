extends SceneTree
## A picture of the character page with things carried and worn (the Carrying rows: Enter uses, Delete puts
## down). Run from a scratch copy (copy this file to its root), under xvfb with the software renderer:
##   godot --rendering-driver opengl3 --resolution 1600x900 -s res://items_preview.gd
## OUT=path for the picture. The level behind it renders black in the cloud; only the page is to be looked at.


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var p: Player = main.player
	p.invulnerable = true
	for it in [Items.make("boots"), Items.make("helmet")]:
		p.inv.add(it)
		p.use_item(p.inv.find(it["id"]))
	for it in [Items.make("bandage", 3), Items.make("matches"), Items.make("antibiotics"), Items.make("torch"),
			Items.make("canned_food", 2), Items.make("hammer"), Items.make("plank", 4), Items.make("cooking_pot")]:
		p.inv.add(it)
	p.sheet.set_need("food", 62.0)
	p.sheet.set_need("water", 48.0)
	main.hud.toggle_sheet()
	var rows: Array = main.hud._sheet_rows()
	main.hud.sheet_select(rows.find("slot:" + p.inv.find("canned_food")))
	for i in 40:
		await process_frame
	var img := root.get_texture().get_image()
	var out := OS.get_environment("OUT")
	img.save_png(out if out != "" else "res://items_page.png")
	quit()
