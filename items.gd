class_name Items
extends RefCounted
## What things are. One record per kind of item:
##   name    what it is called
##   w       its weight (kg), each
##   cat     its category: medical, tool, material, clothing, food, thrown, scrap
##   stack   how many go in one slot (left out: 1), or
##   uses    how many uses one has (a box of nails, a bottle's washes, a torch's seconds of light)
##   keep    it is still a thing when its uses are gone (an empty bottle, a flat torch)
##   wear    where it is worn, if it is: "feet" or "head" (inventory.gd)
##   found   the kinds of place it turns up in, for the loot tables to come: kitchen, bathroom, bedroom,
##           living room, garage, yard, shop, anywhere
##   for     what it is for, in a sentence the player reads
## Every item does something (the owner's rule for objects holds for things you carry too): if nothing in the
## game uses it yet, it isn't here.
##
## A carried item is a small Dictionary: {"id": "bandage", "n": 3} for a stack, {"id": "vodka", "uses": 4} for
## something used up bit by bit.

const DEFS := {
	# ---- medical
	"bandage": {"name": "Bandage", "w": 0.05, "cat": "medical", "stack": 5, "found": ["bathroom"], "for": "Dresses a wound: keeps it clean and nearly stops the bleeding."},
	"clean_rag": {"name": "Clean rag", "w": 0.05, "cat": "medical", "stack": 5, "found": ["kitchen", "bathroom"], "for": "Pressed on a wound it stops bleeding faster than a bare hand. A poor dressing, but a dressing."},
	"needle_thread": {"name": "Needle and thread", "w": 0.02, "cat": "medical", "uses": 12, "found": ["bedroom", "living room"], "for": "Stitches a wound shut, one stitch a use."},
	"tweezers": {"name": "Tweezers", "w": 0.02, "cat": "medical", "found": ["bathroom"], "for": "Picks glass, grit and bullets out of a wound."},
	"vodka": {"name": "Vodka", "w": 0.7, "cat": "medical", "uses": 4, "found": ["kitchen", "living room"], "for": "Washes a wound clean. It stings."},
	"water": {"name": "Bottle of water", "w": 0.5, "cat": "medical", "uses": 4, "keep": true, "found": ["kitchen", "anywhere"], "for": "Washes a wound and quenches thirst, if it is clean. Dirty water does neither safely: filter it, boil it or treat it."},
	"purify_tabs": {"name": "Purification tablets", "w": 0.02, "cat": "medical", "uses": 6, "found": ["garage", "shop"], "for": "One in a bottle of water kills what lives in it, after a wait. Poor in cloudy water."},
	"steroids": {"name": "Steroids", "w": 0.03, "cat": "medical", "uses": 4, "found": ["bathroom"], "for": "Holds a bite's infection back for a few minutes. It cures nothing."},
	"painkillers": {"name": "Painkillers", "w": 0.03, "cat": "medical", "uses": 6, "found": ["bathroom", "bedroom"], "for": "Dulls pain for a few minutes: steadier hands, less slowed."},
	"antibiotics": {"name": "Antibiotics", "w": 0.03, "cat": "medical", "uses": 6, "found": ["bathroom"], "for": "A dose fights an ordinary infection for a few minutes: a bad wound stops getting worse and mends faster. They do nothing to a bite."},
	# ---- tools
	"water_filter": {"name": "Water filter", "w": 0.3, "cat": "tool", "uses": 20, "found": ["garage", "shop"], "for": "Takes the dirt out of a bottle of water, and most of what lives in it. Not all."},
	"hatchet": {"name": "Hatchet", "w": 1.2, "cat": "tool", "found": ["garage", "yard"], "for": "Chops. In the last resort, a limb."},
	"sledgehammer": {"name": "Sledgehammer", "w": 4.5, "cat": "tool", "found": ["garage"], "for": "Pounds. The tool for brick, concrete and pavement; slow and tiring."},
	"hammer": {"name": "Hammer", "w": 0.6, "cat": "tool", "found": ["garage", "kitchen"], "for": "Drives nails. With planks and nails it boards up a window; every blow is heard."},
	"crowbar": {"name": "Crowbar", "w": 1.4, "cat": "tool", "found": ["garage"], "for": "Prises the boards off a window, quietly, and gives you the planks back."},
	"torch": {"name": "Torch", "w": 0.3, "cat": "tool", "uses": 600, "keep": true, "found": ["garage", "kitchen", "bedroom"], "for": "A hand torch: a beam of light where you point. You see by it, and everyone sees you. It runs its batteries down."},
	"battery": {"name": "Batteries", "w": 0.05, "cat": "tool", "stack": 4, "found": ["kitchen", "living room", "garage"], "for": "A fresh set for the torch."},
	"fire_torch": {"name": "Burning torch", "w": 0.6, "cat": "tool", "uses": 300, "found": [], "for": "A stick wound with rag and fat. Lit, it lights all round you for a few minutes and then it is gone."},
	"matches": {"name": "Matches", "w": 0.02, "cat": "tool", "uses": 10, "found": ["kitchen", "living room"], "for": "Lights a fire that has wood on it: a stove, a camp fire."},
	"cooking_pot": {"name": "Cooking pot", "w": 1.0, "cat": "tool", "found": ["kitchen"], "for": "Water boils in it on a fire. Without one there is nothing to boil it in."},
	"can_opener": {"name": "Tin opener", "w": 0.1, "cat": "tool", "found": ["kitchen"], "for": "Opens a tin cleanly. Without it a tin has to be hacked open, and half of it is lost."},
	# ---- materials
	"plank": {"name": "Plank", "w": 1.5, "cat": "material", "stack": 4, "found": ["garage", "yard"], "for": "A sound board. Two of them, nails and a hammer board up a window. It burns, too."},
	"nails": {"name": "Box of nails", "w": 0.3, "cat": "material", "uses": 20, "found": ["garage"], "for": "Four to board a window."},
	# ---- clothing
	"boots": {"name": "Boots", "w": 1.2, "cat": "clothing", "wear": "feet", "found": ["bedroom", "garage"], "for": "On your feet, broken glass only crunches, and a cut foot is out of the dirt."},
	"helmet": {"name": "Helmet", "w": 1.2, "cat": "clothing", "wear": "head", "found": ["garage", "bedroom"], "for": "On your head, a blow or a bullet there takes far less out of you."},
	# ---- food
	"canned_food": {"name": "Tin of beans", "w": 0.45, "cat": "food", "stack": 3, "found": ["kitchen", "shop"], "for": "A meal that keeps for years. It wants a tin opener."},
	# ---- thrown
	"rock": {"name": "Rock", "w": 0.4, "cat": "thrown", "stack": 3, "found": ["yard"], "for": "Thrown, it makes a noise where it lands. It can be picked up again."},
	"bottle": {"name": "Bottle", "w": 0.4, "cat": "thrown", "stack": 3, "found": ["kitchen", "living room"], "for": "Thrown, it smashes: louder than a rock, and gone."},
	# ---- scrap: what broken things leave
	"glass_shard": {"name": "Broken glass", "w": 0.1, "cat": "scrap", "stack": 5, "found": [], "for": "Shards from something glass that broke. Sharp: laid on the ground it is an alarm, and a trap for bare feet."},
	"bloody_glass": {"name": "Bloody glass", "w": 0.1, "cat": "scrap", "stack": 5, "found": [], "for": "A shard drawn out of a wound. The blood stays on it."},
	"cloth_scrap": {"name": "Torn cloth", "w": 0.1, "cat": "scrap", "stack": 5, "found": [], "for": "Ripped from a couch or a mattress. Filthy as it is; washed in clean water, it is a rag."},
	"wood_scrap": {"name": "Splintered wood", "w": 0.4, "cat": "scrap", "stack": 3, "found": [], "for": "Broken wood: no use as a plank any more, but it burns."},
	"scrap_metal": {"name": "Scrap metal", "w": 0.6, "cat": "scrap", "stack": 2, "found": [], "for": "Bent and torn metal from something that broke."},
	"plastic_scrap": {"name": "Broken plastic", "w": 0.15, "cat": "scrap", "stack": 4, "found": [], "for": "Cracked pieces of something plastic."},
}

## What burns on a fire, and for how long (s) each. Stand-ins until there is a clock.
const FUEL := {"wood_scrap": 240.0, "plank": 480.0}


## The items that turn up in a kind of place ("kitchen", "garage"...), for the loot tables to come.
static func found_in(place: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:
		var f: Array = DEFS[id].get("found", [])
		if f.has(place) or f.has("anywhere"):
			out.append(id)
	return out


static func name_of(id: String) -> String:
	return DEFS[id]["name"] if DEFS.has(id) else id


## A fresh one of these (a full stack of `n`, or with all its uses).
static func make(id: String, n := 1) -> Dictionary:
	var d: Dictionary = DEFS[id]
	if d.has("uses"):
		return {"id": id, "uses": int(d["uses"])}
	return {"id": id, "n": n}


static func weight(item: Dictionary) -> float:
	var d: Dictionary = DEFS[item["id"]]
	return float(d["w"]) * (int(item["n"]) if item.has("n") else 1)


## How it reads in a list: "Bandage x3", "Vodka (4 left)".
static func label(item: Dictionary) -> String:
	var nm := name_of(item["id"])
	if item["id"] == "water":
		return "%s (%s, %s)" % [nm, "empty" if int(item["uses"]) <= 0 else "%d left" % int(item["uses"]), Water.look(item)]
	if item["id"] == "torch":
		return "%s (%s)" % [nm, "flat" if int(item["uses"]) <= 0 else ("%d min left" % ceili(int(item["uses"]) / 60.0))]
	if item.has("uses"):
		return "%s (%d left)" % [nm, int(item["uses"])]
	return "%s x%d" % [nm, int(item["n"])] if int(item["n"]) > 1 else nm
