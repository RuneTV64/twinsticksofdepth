class_name ItemGrid
extends RefCounted
## A grid of squares with things lying in it: a drawer, a cupboard shelf, the inside of a bag (owner, 20 Nov
## 2026: "Bags and containers are a full grid"). It is plain data, so it can sit on a bag's own item record
## and on a piece of furniture alike:
##   {"w": 6, "h": 3, "things": [ {"item": {...}, "x": 0, "y": 1, "z": 0}, ... ]}
## x, y is the thing's top left square; its size comes from the item (Items.size_of). z is which layer it is
## in: 0 lying on the bottom, 1 lying on top of something. Things as they are found lie on each other (the
## owner's layered clutter); something with a thing on top of any of it can't be seen or taken until what is
## on it has been moved. Whatever a person puts down goes where there is clear room, so nothing they place
## ever covers anything.


static func make(w: int, h: int) -> Dictionary:
	return {"w": w, "h": h, "things": []}


static func rect_of(t: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(t["x"]), int(t["y"])), Items.size_of(t["item"]["id"]))


## Is some thing lying on top of this one?
static func covered(g: Dictionary, t: Dictionary) -> bool:
	if int(t.get("z", 0)) > 0:
		return false
	var r := rect_of(t)
	for o: Dictionary in g["things"]:
		if int(o.get("z", 0)) > 0 and rect_of(o).intersects(r):
			return true
	return false


## The thing you can see in this square (the one on top), or {}.
static func at(g: Dictionary, cell: Vector2i) -> Dictionary:
	var found := {}
	for t: Dictionary in g["things"]:
		if rect_of(t).has_point(cell) and (found.is_empty() or int(t.get("z", 0)) > int(found.get("z", 0))):
			found = t
	return found


## Would this item lie here with nothing under or over it? (`but`: a thing to leave out of the reckoning.)
static func fits(g: Dictionary, id: String, cell: Vector2i, but := {}) -> bool:
	var r := Rect2i(cell, Items.size_of(id))
	if r.position.x < 0 or r.position.y < 0 or r.end.x > int(g["w"]) or r.end.y > int(g["h"]):
		return false
	for t: Dictionary in g["things"]:
		if not is_same(t, but) and rect_of(t).intersects(r):
			return false
	return true


## The first clear place for it, reading across and then down, or (-1, -1).
static func room_for(g: Dictionary, id: String) -> Vector2i:
	for y in int(g["h"]):
		for x in int(g["w"]):
			if fits(g, id, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Lay it at this square. False if it doesn't fit there.
static func put(g: Dictionary, item: Dictionary, cell: Vector2i) -> bool:
	if Items.DEFS[item["id"]].has("hold") and g.get("bag", false):
		return false                                  # no bag goes in a bag
	if not fits(g, item["id"], cell):
		return false
	g["things"].append({"item": item, "x": cell.x, "y": cell.y, "z": 0})
	return true


## Put it in wherever there is room: onto a stack of the same thing first, then the first clear place.
## False (and the item is left with whatever would not go in) if there is no room.
static func add(g: Dictionary, item: Dictionary) -> bool:
	if Items.DEFS[item["id"]].has("hold") and g.get("bag", false):
		return false
	if item.has("n"):
		var most := int(Items.DEFS[item["id"]].get("stack", 1))
		for t: Dictionary in g["things"]:
			var have: Dictionary = t["item"]
			if have["id"] == item["id"] and have.has("n") and not covered(g, t):
				var move := mini(most - int(have["n"]), int(item["n"]))
				if move > 0:
					have["n"] = int(have["n"]) + move
					item["n"] = int(item["n"]) - move
		if int(item["n"]) <= 0:
			return true
	var cell := room_for(g, item["id"])
	if cell.x < 0:
		return false
	return put(g, item, cell)


static func remove(g: Dictionary, t: Dictionary) -> void:
	var things: Array = g["things"]
	for i in things.size():
		if is_same(things[i], t):
			things.remove_at(i)
			return


static func weight(g: Dictionary) -> float:
	var w := 0.0
	for t: Dictionary in g["things"]:
		w += Items.weight(t["item"])
	return w


## Every item in it, whatever it lies under.
static func items(g: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in g["things"]:
		out.append(t["item"])
	return out
