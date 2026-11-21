class_name Inventory
extends RefCounted
## What a person carries when they have no bag: weighted slots. Each slot holds one thing (or one stack of the same
## thing), up to a weight. Hands take anything; the belt takes tools and holstered things; pockets take small
## things, and only some clothes have them (jeans pockets are assumed for now). Bags and containers, which are
## full grids (item_grid.gd): a bag worn on your back takes what the slots won't, but what is in it can't be
## used until it is in a slot.

## key, name, the most weight it takes (kg)
const SLOTS := [
	["pocket1", "Pocket", 0.5], ["pocket2", "Pocket", 0.5], ["pocket3", "Pocket", 0.5], ["pocket4", "Pocket", 0.5],
	["belt1", "Belt", 1.5], ["belt2", "Belt", 1.5],
	["hand_l", "Left hand", 20.0], ["hand_r", "Right hand", 20.0],
]

var slots := {}     # key -> item Dictionary, or absent when empty
## What is worn: place ("feet", "head") -> item. Worn things take no slot. (Clothes proper come later; these are
## the two that already matter: boots keep glass and dirt out of your feet, a helmet takes a blow to the head.)
const WORN := [["feet", "On your feet"], ["head", "On your head"], ["back", "On your back"]]
var worn := {}


## Put this in: onto a stack of the same thing if there is room, else into the first empty slot it fits
## (pockets, then the belt, then the hands). Returns what wouldn't fit ({} if it all went in).
func add(item: Dictionary) -> Dictionary:
	var def: Dictionary = Items.DEFS[item["id"]]
	if item.has("n"):
		for s in SLOTS:
			var have = slots.get(s[0])
			if have != null and have["id"] == item["id"]:
				var room := int(def.get("stack", 1)) - int(have["n"])
				room = mini(room, floori((float(s[2]) - Items.weight(have)) / maxf(float(def["w"]), 0.001)))
				var move := mini(room, int(item["n"]))
				if move > 0:
					have["n"] = int(have["n"]) + move
					item["n"] = int(item["n"]) - move
		if int(item["n"]) <= 0:
			return {}
	for s in SLOTS:
		if not slots.has(s[0]) and Items.weight(item) <= float(s[2]):
			slots[s[0]] = item
			return {}
	# No slot will take it: into the bag on your back, if you wear one and it has room.
	var bag = worn.get("back")
	if bag != null and ItemGrid.add(Items.hold_of(bag), item):
		return {}
	return item


## The slot holding one of these, or "".
func find(id: String) -> String:
	for s in SLOTS:
		var have = slots.get(s[0])
		if have != null and have["id"] == id:
			return s[0]
	return ""


func has(id: String) -> bool:
	return find(id) != ""


## The slot holding something that serves as this kind of tool ("blade", "hammer", "pry": Items `does`), or "".
## Hands first, so what you hold is what you use.
func tool_for(what: String) -> String:
	for key in ["hand_r", "hand_l", "belt1", "belt2", "pocket1", "pocket2", "pocket3", "pocket4"]:
		var have = slots.get(key)
		if have != null and (Items.DEFS[have["id"]].get("does", []) as Array).has(what):
			return key
	return ""


## Use one of these up: one from a stack, or one use. False if you have none.
func use(id: String) -> bool:
	var key := find(id)
	if key == "":
		return false
	var it: Dictionary = slots[key]
	if it.has("uses"):
		var keep: bool = Items.DEFS[id].get("keep", false)       # a bottle is still a bottle when it is empty
		if keep and int(it["uses"]) <= 0:
			return false
		it["uses"] = int(it["uses"]) - 1
		if int(it["uses"]) <= 0 and not keep:
			slots.erase(key)
	elif it.has("n"):
		it["n"] = int(it["n"]) - 1
		if int(it["n"]) <= 0:
			slots.erase(key)
	return true


func weight() -> float:
	var w := 0.0
	for k in slots:
		w += Items.weight(slots[k])
	for k in worn:
		w += Items.weight(worn[k])
	return w


## Put on what is in this slot. Whatever was worn there comes off into the slot. Returns where it went
## ("feet", "head"), or "" if it isn't something you wear.
func wear(key: String) -> String:
	var it = slots.get(key)
	if it == null:
		return ""
	var place := str(Items.DEFS[it["id"]].get("wear", ""))
	if place == "":
		return ""
	var one: Dictionary = it                      # the thing itself (a bag keeps what is in it)
	if int(it.get("n", 1)) > 1:
		one = {"id": it["id"], "n": 1}
		it["n"] = int(it["n"]) - 1
	else:
		slots.erase(key)
	var was = worn.get(place)
	worn[place] = one
	if was != null:
		add(was)
	return place


## Take off what is worn there, into a free slot. False if there is nothing there or no room for it.
func take_off(place: String) -> bool:
	var it = worn.get(place)
	if it == null:
		return false
	worn.erase(place)
	if not add(it).is_empty():
		worn[place] = it
		return false
	return true


## Everything of this slot comes out of it: what you are about to drop. {} if the slot is empty.
func take(key: String) -> Dictionary:
	var it = slots.get(key)
	if it == null:
		return {}
	slots.erase(key)
	return it
