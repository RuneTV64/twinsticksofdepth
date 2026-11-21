class_name Materials
extends RefCounted
## What things are made of. Every object in the world is made of one or more of these, and that decides how it
## breaks, what is left of it, and how what is left goes away (breakable.gd, wreck.gd).
##
##   hp       how much it takes, per square metre of the thing's biggest face
##   hard     a blow with less force than this only scratches it (SCRATCH of its force): nothing is
##            unbreakable, but the wrong tool takes a very long time
##   blunt, chop, pound, pierce   how well each kind of blow works on it (1 = as given)
##            blunt  fists, a boot, a rifle butt, a zombie's hands
##            chop   a hatchet, an axe
##            pound  a sledgehammer, a pick
##            pierce a bullet
##   scrap    the item its broken pieces are, and how many a square metre gives ("" = nothing worth taking)
##   agent    what clears the wreckage away in the end:
##            rot    wood, cloth, plaster: quicker in the wet
##            rust   metal: slower than rot, quicker in the wet
##            none   glass, stone, plastic: it stays until someone takes it (glass also goes shard by shard
##                   into bare feet: wreck.gd)
##   noise    how far a blow on it is heard (m); it breaking is heard BREAK_NOISE times as far
##   tint     the colour of its wreckage
##
## All of these numbers are first guesses.

const SCRATCH := 0.04
const BREAK_NOISE := 1.8

const DEFS := {
	"glass": {"name": "glass", "hp": 8.0, "hard": 0.0, "blunt": 1.0, "chop": 1.0, "pound": 1.0, "pierce": 1.0,
		"scrap": "glass_shard", "per_m2": 2.0, "agent": "none", "noise": 7.0, "tint": Color(0.72, 0.86, 0.92)},
	"wood": {"name": "wood", "hp": 120.0, "hard": 5.0, "blunt": 1.0, "chop": 2.5, "pound": 1.5, "pierce": 0.2,
		"scrap": "wood_scrap", "per_m2": 1.2, "agent": "rot", "noise": 6.0, "tint": Color(0.5, 0.38, 0.24)},
	"plaster": {"name": "plaster", "hp": 60.0, "hard": 4.0, "blunt": 1.0, "chop": 1.5, "pound": 2.0, "pierce": 0.3,
		"scrap": "", "per_m2": 0.0, "agent": "rot", "noise": 5.0, "tint": Color(0.8, 0.78, 0.72)},
	"brick": {"name": "brick", "hp": 300.0, "hard": 25.0, "blunt": 1.0, "chop": 0.3, "pound": 1.0, "pierce": 0.1,
		"scrap": "rock", "per_m2": 1.5, "agent": "none", "noise": 8.0, "tint": Color(0.56, 0.4, 0.34)},
	"concrete": {"name": "concrete", "hp": 500.0, "hard": 40.0, "blunt": 1.0, "chop": 0.2, "pound": 1.0, "pierce": 0.05,
		"scrap": "rock", "per_m2": 1.5, "agent": "none", "noise": 9.0, "tint": Color(0.6, 0.6, 0.58)},
	"asphalt": {"name": "pavement", "hp": 600.0, "hard": 35.0, "blunt": 1.0, "chop": 0.2, "pound": 1.0, "pierce": 0.02,
		"scrap": "rock", "per_m2": 3.0, "agent": "none", "noise": 9.0, "tint": Color(0.3, 0.3, 0.32)},
	"metal": {"name": "metal", "hp": 400.0, "hard": 30.0, "blunt": 1.0, "chop": 0.3, "pound": 1.0, "pierce": 0.15,
		"scrap": "scrap_metal", "per_m2": 1.0, "agent": "rust", "noise": 11.0, "tint": Color(0.5, 0.52, 0.55)},
	"cloth": {"name": "cloth", "hp": 30.0, "hard": 0.0, "blunt": 0.4, "chop": 2.0, "pound": 0.4, "pierce": 0.6,
		"scrap": "cloth_scrap", "per_m2": 1.0, "agent": "rot", "noise": 2.0, "tint": Color(0.5, 0.42, 0.4)},
	"plastic": {"name": "plastic", "hp": 50.0, "hard": 4.0, "blunt": 1.0, "chop": 1.5, "pound": 1.5, "pierce": 0.4,
		"scrap": "plastic_scrap", "per_m2": 1.0, "agent": "none", "noise": 5.0, "tint": Color(0.85, 0.85, 0.8)},
}

## How fast each agent clears wreckage away, as a share of it a second in dry weather, and how much quicker
## soaked. Stand-ins until the game has a clock: wood is gone in about 15 minutes dry, metal in 30.
const AGENTS := {
	"rot": {"rate": 1.0 / 900.0, "wet": 2.0, "word": "rotting", "tint": Color(0.16, 0.13, 0.09)},
	"rust": {"rate": 1.0 / 1800.0, "wet": 3.0, "word": "rusting", "tint": Color(0.45, 0.22, 0.1)},
	"none": {"rate": 0.0, "wet": 0.0, "word": "", "tint": Color(0.4, 0.4, 0.4)},
}


static func of(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["wood"])


## What a blow of this force and kind really does to this material.
static func dealt(id: String, force: float, kind: String) -> float:
	var m := of(id)
	var d := force * float(m.get(kind, 1.0))
	return d if force >= float(m["hard"]) else d * SCRATCH
