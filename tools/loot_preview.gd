extends SceneTree
## Pictures of the loot screen and its art. Run from a scratch copy (copy this file to its root), under xvfb
## with the software renderer:
##   MODE=icons  godot --rendering-driver opengl3 --resolution 1600x900 -s res://loot_preview.gd   every item's picture
##   MODE=backs  ...   the inside of each thing you can search, and a bag
##   MODE=screen ...   the screen itself, in the real level. KIND = dresser, wardrobe, counter, fridge,
##                     bookshelf or none (only what you carry); DONE = how many columns are searched;
##                     PART = which drawer; SEED for what is in it.
## OUT=path for the picture. The level behind the screen renders black in the cloud.


class Sheet extends Control:
	var mode := "icons"

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.09, 0.09, 0.11))
		if mode == "icons":
			var x := 30.0
			var y := 40.0
			var row_h := 0.0
			var cats := ["medical", "tool", "material", "clothing", "food", "thrown", "scrap"]
			for cat: String in cats:
				draw_string(font, Vector2(x, y - 10.0), cat.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.3))
				for id: String in Items.DEFS:
					if str(Items.DEFS[id]["cat"]) != cat:
						continue
					var sz := Vector2(Items.size_of(id)) * 40.0
					if x + maxf(sz.x, 120.0) > 1570.0:
						x = 30.0
						y += row_h + 40.0
						row_h = 0.0
					draw_rect(Rect2(x, y, sz.x, sz.y), Color(0.2, 0.19, 0.18))
					draw_texture_rect(ItemArt.icon(id), Rect2(x, y, sz.x, sz.y), false)
					draw_string(font, Vector2(x, y + sz.y + 16.0), Items.name_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.78))
					row_h = maxf(row_h, sz.y + 18.0)
					x += maxf(sz.x, font.get_string_size(Items.name_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 22.0
				if cat == "medical" or cat == "tool" or cat == "clothing":
					x = 30.0
					y += row_h + 40.0
					row_h = 0.0
				else:
					x += 50.0
		else:
			var looks := [["drawer", 0, 6, 3, "A drawer, pine"], ["drawer", 1, 6, 3, "A drawer, oak"], ["drawer", 2, 6, 2, "A kitchen drawer, walnut"],
				["cupboard", 1, 6, 4, "A cupboard"], ["shelf", 1, 6, 4, "Shelves"], ["rail", 1, 5, 5, "A wardrobe's rail"],
				["fridge", 1, 4, 4, "A fridge"], ["freezer", 1, 4, 2, "Its freezer box"], ["bag", 0, 6, 4, "A backpack"]]
			var x := 30.0
			var y := 50.0
			var row_h := 0.0
			for l: Array in looks:
				var sz := Vector2(int(l[2]) * 16 + 12, int(l[3]) * 16 + 12) * 3.0
				if x + sz.x > 1570.0:
					x = 30.0
					y += row_h + 50.0
					row_h = 0.0
				draw_texture_rect(ItemArt.backdrop(str(l[0]), int(l[1]), int(l[2]), int(l[3])), Rect2(x, y, sz.x, sz.y), false)
				draw_string(font, Vector2(x, y - 10.0), str(l[4]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.84, 0.8))
				row_h = maxf(row_h, sz.y)
				x += sz.x + 30.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode := OS.get_environment("MODE")
	var out := OS.get_environment("OUT")
	if mode == "icons" or mode == "backs":
		var sh := Sheet.new()
		sh.mode = mode
		sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sh.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(sh)
		for i in 6:
			await process_frame
		root.get_texture().get_image().save_png(out)
		quit()
		return
	if OS.get_environment("SEED") != "":
		seed(int(OS.get_environment("SEED")))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var p: Player = main.player
	p.invulnerable = true
	for it in [Items.make("boots"), Items.make("helmet"), Items.make("backpack"), Items.make("curtain_tieback"), Items.make("table_runner"), Items.make("throw_blanket")]:
		p.inv.add(it)
		p.use_item(p.inv.find(it["id"]))
	for it in [Items.make("bandage", 3), Items.make("matches"), Items.make("hammer"), Items.make("torch"), Items.make("hatchet"), Items.make("plank")]:
		p.inv.add(it)
	var bag := Items.hold_of(p.inv.worn["back"])
	for it in [Items.make("water"), Items.make("canned_food", 2), Items.make("cooking_pot"), Items.make("antibiotics"), Items.make("plank", 2)]:
		ItemGrid.add(bag, it)
	var kind := OS.get_environment("KIND")
	var st: Stash = null
	for s: Stash in get_nodes_in_group("stashes"):
		if s.kind == kind and (st == null or s.plenty > st.plenty):
			st = s
	if st != null:
		p.global_position = Vector3(st.global_position.x, st._floor_y(), st.global_position.z)
		for i in 20:
			await physics_frame
	p.search_time = 100000.0          # (the picture is of a moment: nothing gets searched while it is taken)
	p.start_search(st)
	for i in 10:
		await process_frame
	var loot: LootScreen = main.hud.loot
	if st != null:
		var part_i := int(OS.get_environment("PART")) if OS.get_environment("PART") != "" else 0
		loot._part = part_i
		var found: Array = st.part(part_i)["found"]
		var done := float(OS.get_environment("DONE")) if OS.get_environment("DONE") != "" else 0.0
		for x in found.size():
			found[x] = clampf(done - x, 0.0, 1.0)
		var col := mini(int(done), found.size() - 1)
		loot._ptr = loot._box_origin() + Vector2((col + 0.5) * loot._box_cell(), loot._box_cell() * 1.4)
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
