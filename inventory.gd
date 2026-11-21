class_name Inventory
extends RefCounted
## What a person carries and wears. Your hands are always there; every other slot comes from what you wear
## (owner, 21 Nov 2026): pockets from the clothes (jeans four, a hoodie its pouch, a coat its pockets), belt slots
## from a belt, a sling or a holster from a weapon strap. No trousers, no pockets. Each slot holds one thing (or one
## stack of the same thing), up to a weight, and some take only certain things (a sling takes something long).
## Bags and containers are full grids (item_grid.gd): a bag worn on your back takes what the slots won't, but what
## is in it can't be used until it is in a slot.
##
## A slot a garment gives is keyed "<place>:<n>" ("legs:0" is the first pocket of what is on your legs). Take the
## garment off and what is in its pockets stays in them (kept on the item as "pocketed"); put it on and it is there.

## The two that are always there: key, name, the most weight it takes (kg).
const HANDS := [["hand_l", "Left hand", 20.0], ["hand_r", "Right hand", 20.0]]
## Where things are worn (clothes.gd), outermost first.
const WORN := Clothes.PLACES

var slots := {}     # key -> item Dictionary, or absent when empty
var worn := {}      # place -> item


## Every slot you have now, hands first: [key, name, the most weight it takes, what it takes ("" anything)].
func slot_list() -> Array:
	var out := []
	for h in HANDS:
		out.append([h[0], h[1], h[2], ""])
	for pl: Array in WORN:
		var it = worn.get(pl[0])
		if it == null:
			continue
		var pk: Array = Items.DEFS[it["id"]].get("pockets", [])
		for i in pk.size():
			out.append([pl[0] + ":" + str(i), str(pk[i][0]), float(pk[i][1]), str(pk[i][2]) if pk[i].size() > 2 else ""])
	return out


## The slot's record ([key, name, kg, takes]) or [] if you haven't got that slot (now).
func slot_info(key: String) -> Array:
	for s in slot_list():
		if s[0] == key:
			return s
	return []


## Will this slot take this thing? (Room aside: by weight and by what the slot is for.)
static func fits(s: Array, item: Dictionary) -> bool:
	if Items.weight(item) > float(s[2]):
		return false
	match str(s[3]):
		"long":       # a sling: something long, or for two hands
			var sz := Items.size_of(item["id"])
			return maxi(sz.x, sz.y) >= 3 or int(Items.hit_of(item["id"]).get("hands", 1)) == 2
		"small":
			var sz2 := Items.size_of(item["id"])
			return sz2.x * sz2.y <= 2
	return true


## Put this in: onto a stack of the same thing if there is room, else into the first empty slot that takes it
## (pockets, then the belt and straps, then the hands). Returns what wouldn't fit ({} if it all went in).
func add(item: Dictionary) -> Dictionary:
	var def: Dictionary = Items.DEFS[item["id"]]
	var list := slot_list()
	if item.has("n"):
		for s in list:
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
	# Smallest first: pockets before belts before hands, so a hand stays free if it can.
	var order := list.slice(HANDS.size())
	order.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	order.append_array(list.slice(0, HANDS.size()))
	for s in order:
		if not slots.has(s[0]) and fits(s, item):
			slots[s[0]] = item
			return {}
	# No slot will take it: into the bag on your back, if you wear one and it has room.
	var bag = worn.get("back")
	if bag != null and not Items.hold_of(bag).is_empty() and ItemGrid.add(Items.hold_of(bag), item):
		return {}
	return item


## The slot holding one of these, or "".
func find(id: String) -> String:
	for s in slot_list():
		var have = slots.get(s[0])
		if have != null and have["id"] == id:
			return s[0]
	return ""


func has(id: String) -> bool:
	return find(id) != ""


## The slot holding something that serves as this kind of tool ("blade", "hammer", "pry": Items `does`), or "".
## Hands first, so what you hold is what you use.
func tool_for(what: String) -> String:
	for s in slot_list():
		var have = slots.get(s[0])
		if have != null and (Items.DEFS[have["id"]].get("does", []) as Array).has(what):
			return s[0]
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
	var seen := []
	for k in worn:
		if not seen.has(worn[k]):
			seen.append(worn[k])
			w += Items.weight(worn[k])
	return w


## Put this on at its place (Items `wear`). What is in its pockets comes back into their slots. Whatever was
## worn there is returned (its pockets emptied into it), or {}.
func don(item: Dictionary) -> Dictionary:
	var place := str(Items.DEFS[item["id"]].get("wear", ""))
	if place == "":
		return {}
	var was := doff(place)
	worn[place] = item
	var kept: Dictionary = item.get("pocketed", {})
	for i in kept:
		slots[place + ":" + str(i)] = kept[i]
	item.erase("pocketed")
	return was


## Take off what is worn there: it is returned with what is in its pockets kept in it ({} if nothing is worn).
func doff(place: String) -> Dictionary:
	var it = worn.get(place)
	if it == null:
		return {}
	worn.erase(place)
	var kept := {}
	var pre := place + ":"
	for k in slots.keys():
		if str(k).begins_with(pre):
			kept[int(str(k).substr(pre.length()))] = slots[k]
			slots.erase(k)
	if not kept.is_empty():
		it["pocketed"] = kept
	return it


## Put on what is in this slot. Whatever was worn there comes off into a slot (or is returned in "left" for the
## caller to put down). Returns the place, or "" if it isn't something you wear.
func wear(key: String) -> String:
	left = {}
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
	var was := don(one)
	if not was.is_empty():
		left = add(was)
	return place


## What wouldn't go anywhere after the last wear(): the caller puts it down.
var left := {}


## Take off what is worn there, into a free slot. False if there is nothing there or no room for it.
func take_off(place: String) -> bool:
	if not worn.has(place):
		return false
	var it := doff(place)
	if not add(it).is_empty():
		don(it)
		return false
	return true


## Everything of this slot comes out of it: what you are about to drop. {} if the slot is empty.
func take(key: String) -> Dictionary:
	var it = slots.get(key)
	if it == null:
		return {}
	slots.erase(key)
	return it


## Everything carried and worn, for a body left behind: the worn things (with their pockets in them) and what is
## in hand. Empties this inventory.
func strip() -> Array:
	var out := []
	for k in ["hand_l", "hand_r"]:
		if slots.has(k):
			out.append(slots[k])
	for pl: Array in WORN:
		var it := doff(pl[0])
		if not it.is_empty():
			out.append(it)
	slots.clear()
	return out
