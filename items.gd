class_name Items
extends RefCounted
## What things are. One record per kind of item: its name, weight (kg), category, how many stack in one slot or
## how many uses one has, and what it is for. Only the medical things exist so far (enough to treat wounds);
## household things, food, clothes and guns come with the loot system.
##
## A carried item is a small Dictionary: {"id": "bandage", "n": 3} for a stack, {"id": "vodka", "uses": 4} for
## something used up bit by bit.

const DEFS := {
	"bandage": {"name": "Bandage", "w": 0.05, "cat": "medical", "stack": 5, "for": "Dresses a wound: keeps it clean and nearly stops the bleeding."},
	"clean_rag": {"name": "Clean rag", "w": 0.05, "cat": "medical", "stack": 5, "for": "Pressed on a wound it stops bleeding faster than a bare hand. A poor dressing, but a dressing."},
	"needle_thread": {"name": "Needle and thread", "w": 0.02, "cat": "medical", "uses": 12, "for": "Stitches a wound shut, one stitch a use."},
	"tweezers": {"name": "Tweezers", "w": 0.02, "cat": "medical", "for": "Picks glass, grit and bullets out of a wound."},
	"vodka": {"name": "Vodka", "w": 0.7, "cat": "medical", "uses": 4, "for": "Washes a wound clean. It stings."},
	"water": {"name": "Bottle of water", "w": 0.5, "cat": "medical", "uses": 4, "for": "Washes a wound clean, as well as spirits do and without the sting. To drink, too, once thirst runs."},
	"steroids": {"name": "Steroids", "w": 0.03, "cat": "medical", "uses": 4, "for": "Holds a bite's infection back for a few minutes. It cures nothing."},
	"hatchet": {"name": "Hatchet", "w": 1.2, "cat": "tool", "for": "Chops. In the last resort, a limb."},
	"torch": {"name": "Torch", "w": 0.3, "cat": "tool", "for": "A hand torch: a beam of light where you point. You see by it, and everyone sees you."},
	"fire_torch": {"name": "Burning torch", "w": 0.6, "cat": "tool", "uses": 300, "for": "A stick wound with rag and fat. Lit, it lights all round you for a few minutes and then it is gone."},
	"rock": {"name": "Rock", "w": 0.4, "cat": "thrown", "stack": 3, "for": "Thrown, it makes a noise where it lands. It can be picked up again."},
	"bottle": {"name": "Bottle", "w": 0.4, "cat": "thrown", "stack": 3, "for": "Thrown, it smashes: louder than a rock, and gone."},
	"sledgehammer": {"name": "Sledgehammer", "w": 4.5, "cat": "tool", "for": "Pounds. The tool for brick, concrete and pavement; slow and tiring."},
	"glass_shard": {"name": "Broken glass", "w": 0.1, "cat": "scrap", "stack": 5, "for": "Shards from something glass that broke. Sharp."},
	"bloody_glass": {"name": "Bloody glass", "w": 0.1, "cat": "scrap", "stack": 5, "for": "A shard drawn out of a wound. The blood stays on it."},
	"wood_scrap": {"name": "Splintered wood", "w": 0.4, "cat": "scrap", "stack": 3, "for": "Broken wood: no use as a plank any more, but it is still wood."},
	"scrap_metal": {"name": "Scrap metal", "w": 0.6, "cat": "scrap", "stack": 2, "for": "Bent and torn metal from something that broke."},
	"plastic_scrap": {"name": "Broken plastic", "w": 0.15, "cat": "scrap", "stack": 4, "for": "Cracked pieces of something plastic."},
	"painkillers": {"name": "Painkillers", "w": 0.03, "cat": "medical", "uses": 6, "for": "Dulls pain for a few minutes: steadier hands, less slowed."},
}


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
	if item.has("uses"):
		return "%s (%d left)" % [nm, int(item["uses"])]
	return "%s x%d" % [nm, int(item["n"])] if int(item["n"]) > 1 else nm
