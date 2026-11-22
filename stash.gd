class_name Stash
extends Node3D
## Somewhere things are kept and have to be looked for: a dresser's drawers, a wardrobe, a kitchen counter's
## drawer and cupboard, a fridge, a bookshelf (owner, 20 and 21 Nov 2026: searching drawers is a minigame of
## its own; the screen shows the actual drawer as a grid; cupboards and dressers need it too). A child of the
## piece of furniture, so breaking the piece ends it, and what was in it spills on the floor.
##
##  - A stash has parts, each a grid of its own with its own look: a dresser is three drawers.
##  - What is in a part is rolled the first time anyone looks in it, from the items that turn up in that kind
##    of place (Items.found_in) and fit. A piece put down worn has been picked over: less in it.
##  - Things lie on each other as they were left (ItemGrid's layers): what is under something can't be seen
##    until the thing on top is moved.
##  - A part is searched a column at a time (`found`, 0 to 1 a column): loot_screen.gd fills the column your
##    hand is over. Things show once every column they lie in has been gone through. A part that has been
##    searched opens at once from then on, for anyone.
## Nothing here runs between visits.

const KINDS := {
	"dresser": {"place": ["bedroom"], "parts": [["Top drawer", "drawer", 6, 3], ["Middle drawer", "drawer", 6, 3], ["Bottom drawer", "drawer", 6, 3]]},
	"wardrobe": {"place": ["bedroom"], "parts": [["Hanging rail", "rail", 5, 5], ["Top shelf", "shelf", 5, 2]]},
	"counter": {"place": ["kitchen"], "parts": [["Drawer", "drawer", 6, 2], ["Cupboard", "cupboard", 6, 4]]},
	"fridge": {"place": ["kitchen"], "only": ["food", "water", "vodka", "bottle"], "parts": [["Shelves", "fridge", 4, 4], ["Freezer box", "freezer", 4, 2]]},
	"bookshelf": {"place": ["living room"], "parts": [["Shelves", "shelf", 6, 4]]},
	"coffee_table": {"place": ["living room"], "parts": [["Shelf underneath", "shelf", 6, 2]]},
	"end_table": {"place": ["living room"], "parts": [["Drawer", "drawer", 3, 2]]},
	"tv_stand": {"place": ["living room"], "parts": [["Cabinet", "cupboard", 6, 3]]},
	"display_cabinet": {"place": ["living room", "kitchen"], "parts": [["Glass shelves", "shelf", 5, 4], ["Cupboard", "cupboard", 5, 2]]},
	"sink": {"place": ["kitchen"], "parts": [["Under the sink", "cupboard", 5, 3]]},
	"pantry": {"place": ["kitchen"], "only": ["food", "water", "matches", "candle", "battery", "bottle", "tea_towel"], "parts": [["Top shelves", "shelf", 5, 3], ["Bottom shelves", "shelf", 5, 3]]},
	"wall_cabinet": {"place": ["kitchen"], "parts": [["Cupboard", "cupboard", 5, 3]]},
	"kitchen_bin": {"place": ["bin"], "parts": [["Bin", "bag", 3, 4]]},
}
## How much of what a sound piece would hold is left in one put down damaged, or worn out.
const PLENTY := [1.0, 0.6, 0.3]
## The chance a thing as found lies on top of another.
const CLUTTER := 0.4

var kind := "dresser"
var title := "dresser"
var stain := 1               # the piece's wood, for the look of its inside
var plenty := 1.0
var parts: Array[Dictionary] = []     # {"name", "look", "grid", "found": [0..1 a column], "rolled"}


## A stash for this kind of furniture, or null if it isn't somewhere things are kept.
static func for_piece(piece: String, what: String, wood: int, wear: int) -> Stash:
	if not KINDS.has(piece):
		return null
	var s := Stash.new()
	s.kind = piece
	s.title = what
	s.stain = wood
	s.plenty = float(PLENTY[clampi(wear, 0, 2)])
	return s


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("stashes")
	if parts.is_empty():
		for p: Array in KINDS[kind]["parts"]:
			var found: Array[float] = []
			found.resize(int(p[2]))
			found.fill(0.0)
			parts.append({"name": str(p[0]), "look": str(p[1]), "grid": ItemGrid.make(int(p[2]), int(p[3])), "found": found, "rolled": false})


# ---------------------------------------------------------------------------------------- interactable
func can_interact(p: Player) -> bool:
	return absf(p.global_position.y - _floor_y()) < 1.2 and not p.is_searching()


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return ("Look in the %s" if all_searched() else "Search the %s") % title


func interact(p: Player) -> void:
	p.start_search(self)


func _floor_y() -> float:
	var host := get_parent() as Node3D
	var br := Breakable.of(host) if host != null else null
	return br.floor_y if br != null else global_position.y


# ------------------------------------------------------------------------------------------- searching
## The part, with what is in it rolled if nobody has looked before.
func part(i: int) -> Dictionary:
	var p: Dictionary = parts[i]
	if not p["rolled"]:
		_roll(p)
	return p


func searched(i: int) -> bool:
	for f: float in parts[i]["found"]:
		if f < 1.0:
			return false
	return true


func all_searched() -> bool:
	for i in parts.size():
		if not searched(i):
			return false
	return true


## How much of this part has been gone through, 0 to 1.
func progress(i: int) -> float:
	var sum := 0.0
	for f: float in parts[i]["found"]:
		sum += minf(f, 1.0)
	return sum / float(parts[i]["found"].size())


## Go through a column for a while (`amount`: the share of a column). True if that finished it.
func search(i: int, column: int, amount: float) -> bool:
	var found: Array = part(i)["found"]
	if column < 0 or column >= found.size() or float(found[column]) >= 1.0:
		return false
	found[column] = minf(float(found[column]) + amount, 1.0)
	return float(found[column]) >= 1.0


## Can this thing be seen yet? Every column it lies in has been gone through, and nothing lies on it.
func shows(i: int, thing: Dictionary) -> bool:
	var p: Dictionary = parts[i]
	var r := ItemGrid.rect_of(thing)
	for x in range(r.position.x, r.end.x):
		if float(p["found"][x]) < 1.0:
			return false
	return not ItemGrid.covered(p["grid"], thing)


## Is there room to lay this down at this square, in what has been searched?
func can_put(i: int, id: String, cell: Vector2i, but := {}) -> bool:
	var p: Dictionary = parts[i]
	var sz := Items.size_of(id)
	for x in range(cell.x, cell.x + sz.x):
		if x < 0 or x >= int(p["grid"]["w"]) or float(p["found"][x]) < 1.0:
			return false
	return ItemGrid.fits(p["grid"], id, cell, but)


## Everything in it (rolling what nobody has looked at yet): what spills when the piece is broken.
func everything() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in parts.size():
		out.append_array(ItemGrid.items(part(i)["grid"]))
	return out


## The piece has been broken: what was in it lies on the floor where it stood.
func spill() -> void:
	var things := everything()
	for p in parts:
		p["grid"]["things"] = []
	if things.is_empty() or get_parent() == null or get_parent().get_parent() == null:
		return
	var box := ItemPickup.new()
	box.title = "What was in the %s" % title
	box.tint = Color(0.62, 0.56, 0.44)
	box.contents = things
	box.position = Vector3(global_position.x, _floor_y(), global_position.z)
	get_parent().get_parent().add_child(box)


# --------------------------------------------------------------------------------------------- rolling
func _roll(p: Dictionary) -> void:
	p["rolled"] = true
	var def: Dictionary = KINDS[kind]
	var pool: Array[String] = []
	for place: String in def["place"]:
		for id in Items.found_in(place):
			if pool.has(id) or id == "water" and not def.has("only") and randf() < 0.5:
				continue
			if def.has("only") and not ((def["only"] as Array).has(id) or (def["only"] as Array).has(str(Items.DEFS[id]["cat"]))):
				continue
			var sz := Items.size_of(id)
			if sz.x <= int(p["grid"]["w"]) and sz.y <= int(p["grid"]["h"]):
				pool.append(id)
	if pool.is_empty():
		return
	var g: Dictionary = p["grid"]
	var squares := int(g["w"]) * int(g["h"])
	var want := roundi(randf_range(0.1, 0.28) * squares * plenty)
	for n in want:
		var id: String = pool.pick_random()
		for again in 6:
			if randf() < float(Items.DEFS[id].get("rare", 1.0)):
				break
			id = pool.pick_random()                    # (a rare thing is mostly something else)
		var item := found_item(id)
		# Mostly it lies on the bottom where there is room; sometimes on top of something that was there.
		var laid := false
		if not g["things"].is_empty() and randf() < CLUTTER:
			laid = _lay_on_top(g, item)
		for tries in 14:
			if laid:
				break
			var sz := Items.size_of(id)
			var cell := Vector2i(randi_range(0, int(g["w"]) - sz.x), randi_range(0, int(g["h"]) - sz.y))
			if ItemGrid.fits(g, id, cell):
				g["things"].append({"item": item, "x": cell.x, "y": cell.y, "z": 0})
				laid = true


## A thing as it is found: part used, part of a stack.
static func found_item(id: String) -> Dictionary:
	var d: Dictionary = Items.DEFS[id]
	var item := Items.make(id)
	if d.has("uses"):
		item["uses"] = randi_range(ceili(int(d["uses"]) / 3.0), int(d["uses"]))
	elif int(d.get("stack", 1)) > 1:
		item["n"] = randi_range(1, int(d["stack"]))
	return item


func _lay_on_top(g: Dictionary, item: Dictionary) -> bool:
	var sz := Items.size_of(item["id"])
	var under: Array = (g["things"] as Array).filter(func(t: Dictionary) -> bool: return int(t.get("z", 0)) == 0)
	under.shuffle()
	for t: Dictionary in under:
		var cell := Vector2i(clampi(int(t["x"]), 0, int(g["w"]) - sz.x), clampi(int(t["y"]), 0, int(g["h"]) - sz.y))
		var r := Rect2i(cell, sz)
		var clear := true
		for o: Dictionary in g["things"]:
			if int(o.get("z", 0)) > 0 and ItemGrid.rect_of(o).intersects(r):
				clear = false
		if clear:
			g["things"].append({"item": item, "x": cell.x, "y": cell.y, "z": 1})
			return true
	return false
