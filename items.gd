class_name Items
extends RefCounted
## What things are. One record per kind of item:
##   name    what it is called
##   w       its weight (kg), each
##   cat     its category: medical, tool, material, clothing, food, thrown, misc, scrap
##   stack   how many go in one slot (left out: 1), or
##   uses    how many uses one has (a box of nails, a bottle's washes, a torch's seconds of light)
##   keep    it is still a thing when its uses are gone (an empty bottle, a flat torch)
##   wear    where it is worn, if it is: one of Clothes.PLACES ("undershirt", "legs", "feet", "head", "back", "strap"...)
##   look    how it is drawn worn (clothes.gd): a cut from Clothes.CUTS (or its own "cover"), "ink" and "ink2"
##           (ItemArt.INK names or "#rrggbb"), "pat" (plain, knit, denim, check, stripes, leather, lace, print,
##           metal, glass), "thick" (m), "shape" (strap, pack, lens, slot), "side" (L or R), "open" (m down the
##           front), "flare", "detail" (buttons, zip, laces, jeans)
##   guard   what it keeps out where it covers, each 0 to 1: "bite", "cut", "blow" (a stop chance; a blow's share
##           kept out), "warm" (for the warmth need to come), "clumsy" (worn on the hands: that much worse aim). Torn, it keeps out less (Clothes.meet)
##   pockets the slots it gives worn: [[name, kg], ...], or [name, kg, takes] ("long": a sling takes something long)
##   size    how many squares it takes in a drawer or a bag, [wide, high] (left out: one square). Squares are
##           not a measure: small, long, bulky. The picture of it (item_art.gd) is drawn to this size.
##   hold    it is a bag: the grid it holds, [wide, high]. What is in it is on the item itself ("grid")
##   found   the kinds of place it turns up in, for the loot tables to come: kitchen, bathroom, bedroom,
##           living room, garage, yard, shop, anywhere
##   rare    how often it is there when it could be, against an ordinary thing (left out: 1)
##   for     what it is for, in a sentence the player reads
##   hit     how it does as a weapon, held in a hand (owner, 21 Nov 2026: anything held in one or two hands is a
##           weapon, but most things don't last long smacked against a head):
##             hands  1 or 2 (two-handed with the other hand full, or one arm, it is swung one-handed: weaker, slower)
##             kind   blunt, chop or pierce (what it does to a body: see Enemy.take_blow)
##             force  how hard a blow is, at Strength 10 (a punch is 2 to 5; a sound skull wants Enemy.SKULL_BLOW)
##             smash  how hard it is on things (Breakable.hit; left out: force), and `breaks` the kind of blow on
##                    things if not the same (a sledgehammer pounds)
##             reach  m from you; time  s a swing, wind-up and recovery together
##             lasts  how many blows before it breaks; into  what is left when it does, [[id, n], ...] (the first
##                    that is a weapon itself stays in your hand: a bottle breaks into a broken bottle)
##             noise  m it is heard when it breaks (left out: not)
##             look   how it shows in the hand: [length m, thickness m, ink] (left out: not shown)
##   throw   it can be thrown (Player.THROWABLES; thrown.gd): {"noise": m heard where it lands, "keep": it lies
##           there to be picked up again, "far": its reach against a rock's, "look": [[x, y, z] m, ink]}
##   pry_mult as a pry, how much slower than a crowbar
##   does    what it serves as a tool for: "blade" (cuts), "hammer", "pry" (see Inventory.tool_for)
##   apart   what it is taken apart into, by hand (Player.take_apart):
##             into [[id, n], ...], tool a `does` it needs ("" or left out: bare hands), time s, noise m
## Every item does something (the owner's rule for objects holds for things you carry too): if nothing in the
## game uses it yet, it isn't here.
##
## A carried item is a small Dictionary: {"id": "bandage", "n": 3} for a stack, {"id": "vodka", "uses": 4} for
## something used up bit by bit. A thing that has been hit with carries "hits", the blows it has taken (for a
## stack, the one on top).

const DEFS := {
	# ---- medical
	"bandage": {"name": "Bandage", "w": 0.05, "cat": "medical", "stack": 5, "found": ["bathroom"], "for": "Dresses a wound: keeps it clean and nearly stops the bleeding."},
	"clean_rag": {"name": "Clean rag", "w": 0.05, "cat": "medical", "stack": 5, "found": ["kitchen", "bathroom"], "for": "Pressed on a wound it stops bleeding faster than a bare hand. A poor dressing, but a dressing."},
	"needle_thread": {"name": "Needle and thread", "w": 0.02, "cat": "medical", "uses": 12, "found": ["bedroom", "living room"], "for": "Stitches a wound shut, one stitch a use."},
	"tweezers": {"name": "Tweezers", "w": 0.02, "cat": "medical", "found": ["bathroom"], "for": "Picks glass, grit and bullets out of a wound."},
	"vodka": {"name": "Vodka", "w": 0.7, "size": [1, 2], "cat": "medical", "uses": 4, "found": ["kitchen", "living room"], "for": "Washes a wound clean. It stings."},
	"water": {"name": "Bottle of water", "w": 0.5, "size": [1, 2], "cat": "medical", "uses": 4, "keep": true, "found": ["kitchen", "anywhere"], "for": "Washes a wound and quenches thirst, if it is clean. Dirty water does neither safely: filter it, boil it or treat it."},
	"purify_tabs": {"name": "Purification tablets", "w": 0.02, "cat": "medical", "uses": 6, "found": ["garage", "shop"], "for": "One in a bottle of water kills what lives in it, after a wait. Poor in cloudy water."},
	"steroids": {"name": "Steroids", "w": 0.03, "cat": "medical", "uses": 4, "rare": 0.3, "found": ["bathroom"], "for": "Holds a bite's infection back for a few minutes. It cures nothing."},
	"painkillers": {"name": "Painkillers", "w": 0.03, "cat": "medical", "uses": 6, "found": ["bathroom", "bedroom"], "for": "Dulls pain for a few minutes: steadier hands, less slowed."},
	"antibiotics": {"name": "Antibiotics", "w": 0.03, "cat": "medical", "uses": 6, "rare": 0.4, "found": ["bathroom"], "for": "A dose fights an ordinary infection for a few minutes: a bad wound stops getting worse and mends faster. They do nothing to a bite."},
	# ---- tools
	"water_filter": {"name": "Water filter", "w": 0.3, "size": [1, 2], "cat": "tool", "uses": 20, "rare": 0.4, "found": ["garage", "shop"], "for": "Takes the dirt out of a bottle of water, and most of what lives in it. Not all.", "apart": {"into": [["plastic_scrap", 1]], "time": 2.0}},
	"hatchet": {"name": "Hatchet", "w": 1.2, "size": [1, 3], "cat": "tool", "found": ["garage", "yard"], "for": "Chops. In the last resort, a limb.", "does": ["blade"], "hit": {"hands": 1, "kind": "chop", "force": 24.0, "smash": 30.0, "reach": 1.5, "time": 0.7, "lasts": 400, "into": [["scrap_metal", 1], ["wood_scrap", 1]], "look": [0.42, 0.04, "wood"]}},
	"sledgehammer": {"name": "Sledgehammer", "w": 4.5, "size": [2, 4], "cat": "tool", "rare": 0.4, "found": ["garage"], "for": "Pounds. The tool for brick, concrete and pavement; slow and tiring.", "does": ["hammer"], "hit": {"hands": 2, "kind": "blunt", "breaks": "pound", "force": 40.0, "smash": 60.0, "reach": 1.8, "time": 1.4, "lasts": 600, "into": [["scrap_metal", 1], ["wood_scrap", 1]], "look": [0.9, 0.05, "iron"]}},
	"hammer": {"name": "Hammer", "w": 0.6, "size": [1, 2], "cat": "tool", "found": ["garage", "kitchen"], "for": "Drives nails. With planks and nails it boards up a window; every blow is heard.", "does": ["hammer"], "hit": {"hands": 1, "kind": "blunt", "force": 13.0, "reach": 1.2, "time": 0.5, "lasts": 300, "into": [["scrap_metal", 1]], "look": [0.3, 0.035, "wood"]}},
	"crowbar": {"name": "Crowbar", "w": 1.4, "size": [1, 3], "cat": "tool", "rare": 0.5, "found": ["garage"], "for": "Prises the boards off a window, quietly, and gives you the planks back.", "does": ["pry"], "hit": {"hands": 1, "kind": "blunt", "force": 18.0, "reach": 1.5, "time": 0.65, "lasts": 1500, "into": [["scrap_metal", 1]], "look": [0.6, 0.03, "crimson"]}},
	"torch": {"name": "Torch", "w": 0.3, "size": [1, 2], "cat": "tool", "uses": 600, "keep": true, "found": ["garage", "kitchen", "bedroom"], "for": "A hand torch: a beam of light where you point. You see by it, and everyone sees you. It runs its batteries down.", "hit": {"hands": 1, "kind": "blunt", "force": 8.0, "reach": 1.1, "time": 0.5, "lasts": 12, "into": [["plastic_scrap", 1], ["scrap_metal", 1]], "look": [0.25, 0.045, "dark"]}, "apart": {"into": [["plastic_scrap", 1], ["scrap_metal", 1]], "time": 4.0}},
	"battery": {"name": "Batteries", "w": 0.05, "cat": "tool", "stack": 4, "found": ["kitchen", "living room", "garage"], "for": "A fresh set for the torch, the radio or a toy (whichever is flattest)."},
	"fire_torch": {"name": "Burning torch", "w": 0.6, "size": [1, 3], "cat": "tool", "uses": 300, "found": [], "for": "A stick wound with rag and fat. Lit, it lights all round you for a few minutes and then it is gone.", "hit": {"hands": 1, "kind": "blunt", "force": 7.0, "reach": 1.3, "time": 0.55, "lasts": 5, "into": [["wood_scrap", 1]], "look": [0.5, 0.04, "wood"]}},
	"matches": {"name": "Matches", "w": 0.02, "cat": "tool", "uses": 10, "found": ["kitchen", "living room"], "for": "Lights a fire that has wood on it: a stove, a camp fire."},
	"cooking_pot": {"name": "Cooking pot", "w": 1.0, "size": [2, 2], "cat": "tool", "found": ["kitchen"], "for": "Water boils in it on a fire. Without one there is nothing to boil it in.", "hit": {"hands": 1, "kind": "blunt", "force": 10.0, "reach": 1.1, "time": 0.55, "lasts": 25, "into": [["scrap_metal", 1]], "look": [0.22, 0.2, "steel"]}},
	"can_opener": {"name": "Tin opener", "w": 0.1, "cat": "tool", "found": ["kitchen"], "for": "Opens a tin cleanly. Without it a tin has to be hacked open, and half of it is lost."},
	# ---- materials
	"plank": {"name": "Plank", "w": 1.5, "size": [1, 4], "cat": "material", "stack": 4, "found": ["garage", "yard"], "for": "A sound board. Two of them, nails and a hammer board up a window. It burns, too.", "hit": {"hands": 2, "kind": "blunt", "force": 15.0, "reach": 1.9, "time": 0.85, "lasts": 6, "into": [["wood_scrap", 2]], "noise": 6.0, "look": [1.1, 0.05, "pale"]}, "apart": {"into": [["wood_scrap", 3]], "tool": "blade", "time": 6.0, "noise": 6.0}},
	"nails": {"name": "Box of nails", "w": 0.3, "cat": "material", "uses": 20, "found": ["garage"], "for": "Four to board a window."},
	# ---- clothing
	"boots": {"name": "Boots", "w": 1.2, "size": [2, 2], "cat": "clothing", "wear": "feet", "rare": 0.5, "found": ["bedroom", "garage"], "for": "On your feet, broken glass only crunches, and a cut foot is out of the dirt.", "look": {"cut": "boots", "ink": "leather", "pat": "leather", "thick": 0.022, "detail": "laces"}, "guard": {"bite": 0.6, "cut": 0.9, "warm": 0.15}, "apart": {"into": [["cloth_scrap", 1], ["plastic_scrap", 1]], "tool": "blade", "time": 6.0}},
	"helmet": {"name": "Helmet", "w": 1.2, "size": [2, 2], "cat": "clothing", "wear": "head", "rare": 0.3, "found": ["garage", "bedroom"], "for": "On your head, a blow or a bullet there takes far less out of you.", "apart": {"into": [["plastic_scrap", 2], ["cloth_scrap", 1]], "tool": "blade", "time": 5.0}, "look": {"cut": "helmet", "ink": "olive", "pat": "plain", "thick": 0.03}, "guard": {"bite": 0.9, "cut": 0.9, "blow": 0.6}},
	"backpack": {"name": "Backpack", "w": 0.8, "size": [3, 3], "cat": "clothing", "wear": "back", "hold": [6, 4], "rare": 0.25, "found": ["bedroom", "garage"], "for": "On your back it holds a grid of things. What is in it has to come out into a hand, your belt or a pocket before you can use it.", "apart": {"into": [["cloth_scrap", 4]], "tool": "blade", "time": 8.0}, "look": {"cut": "pack", "shape": "pack", "ink": "canvas", "pat": "plain", "thick": 0.1}},
	# ---- clothing: what everyone starts in (owner, 21 Nov 2026: all have clothes from the beginning). The themed
	# bedrooms bring the rest, in every fashion.
	"t_shirt": {"name": "T-shirt", "w": 0.15, "size": [2, 2], "cat": "clothing", "wear": "undershirt", "found": ["bedroom"], "for": "Worn under everything. Thin: it keeps nothing much out. Torn up it is rags and strips.", "look": {"cut": "tee", "ink": "white", "pat": "plain", "thick": 0.006}, "guard": {"bite": 0.05, "cut": 0.05, "warm": 0.1}, "apart": {"into": [["cloth_scrap", 2], ["cloth_strip", 2]], "time": 5.0}},
	"jeans": {"name": "Jeans", "w": 0.7, "size": [2, 3], "cat": "clothing", "wear": "legs", "found": ["bedroom"], "for": "Tough cloth: a bite or a cut on the legs has to get through it. Four pockets.", "look": {"cut": "jeans", "ink": "blue", "pat": "denim", "ink2": "water", "detail": "jeans", "thick": 0.01}, "guard": {"bite": 0.3, "cut": 0.4, "warm": 0.25}, "pockets": [["Front pocket", 0.5], ["Front pocket", 0.5], ["Back pocket", 0.4], ["Back pocket", 0.4]], "apart": {"into": [["cloth_scrap", 3], ["cloth_strip", 2]], "tool": "blade", "time": 8.0}},
	"belt": {"name": "Leather belt", "w": 0.3, "size": [1, 3], "cat": "clothing", "wear": "waist", "found": ["bedroom"], "for": "Two things hang on it: a hatchet, a torch, a hammer.", "look": {"cut": "belt", "ink": "leather", "pat": "leather", "thick": 0.014}, "pockets": [["On your belt", 1.5], ["On your belt", 1.5]], "hit": {"hands": 1, "kind": "blunt", "force": 5.0, "reach": 1.5, "time": 0.55, "lasts": 40, "into": [["cloth_strip", 1]], "look": [0.5, 0.02, "leather"]}},
	"socks": {"name": "Socks", "w": 0.08, "cat": "clothing", "wear": "socks", "found": ["bedroom"], "for": "Warm feet. Nothing against glass.", "look": {"cut": "socks", "ink": "white", "pat": "knit", "thick": 0.006}, "guard": {"cut": 0.05, "warm": 0.08}, "apart": {"into": [["cloth_scrap", 1]], "time": 2.0}},
	"sneakers": {"name": "Sneakers", "w": 0.7, "size": [2, 2], "cat": "clothing", "wear": "feet", "found": ["bedroom", "living room"], "for": "Light and quiet. Glass mostly only crunches under them; they are no boots.", "look": {"cut": "shoes", "ink": "white", "ink2": "dark", "detail": "laces", "thick": 0.02}, "guard": {"bite": 0.15, "cut": 0.75, "warm": 0.1}, "apart": {"into": [["plastic_scrap", 1], ["cloth_scrap", 1]], "tool": "blade", "time": 5.0}},
	# ---- the living room's cloth (owner, 21 Nov 2026: "Do clothes like drapes and table cloths. Stuff like that.")
	"curtains": {"name": "Curtains", "w": 2.4, "size": [3, 3], "cat": "clothing", "wear": "cloak", "rare": 0.6, "found": ["living room"], "for": "Heavy drapes from the front room. Round your shoulders they are a warm cloak a bite has to get through. Torn up, a lot of cloth.", "look": {"cut": "cloak", "ink": "#6e2a36", "ink2": "#8c4450", "pat": "print", "thick": 0.025, "flare": 0.12, "open": 0.16}, "guard": {"bite": 0.25, "cut": 0.2, "warm": 0.45}, "apart": {"into": [["cloth_scrap", 5], ["cloth_strip", 4]], "time": 10.0}},
	"net_curtain": {"name": "Net curtain", "w": 0.3, "size": [2, 2], "cat": "tool", "found": ["living room"], "for": "Fine white netting. Muddy water poured through it comes out far clearer; what lives in it goes straight through.", "does": ["strain"], "apart": {"into": [["cloth_strip", 3]], "time": 3.0}},
	"tablecloth": {"name": "Tablecloth", "w": 0.6, "size": [2, 2], "cat": "clothing", "wear": "back", "hold": [4, 3], "found": ["living room", "kitchen"], "for": "Its corners knotted, it is a bundle on your back: a small bag. Torn up, cloth and strips.", "look": {"cut": "pack", "shape": "pack", "ink": "white", "ink2": "red", "pat": "check", "thick": 0.07}, "apart": {"into": [["cloth_scrap", 2], ["cloth_strip", 3]], "time": 5.0}},
	"throw_blanket": {"name": "Throw blanket", "w": 1.0, "size": [3, 2], "cat": "clothing", "wear": "cloak", "found": ["living room", "bedroom"], "for": "Knitted, off the back of the couch. Round your shoulders it is warm, if not much else.", "look": {"cut": "shawl", "ink": "#b8893a", "ink2": "#6c7848", "pat": "stripes", "thick": 0.02, "open": 0.12}, "guard": {"bite": 0.12, "cut": 0.1, "warm": 0.4}, "apart": {"into": [["cloth_scrap", 4]], "time": 6.0}},
	"cushion_cover": {"name": "Cushion cover", "w": 0.15, "size": [2, 2], "cat": "clothing", "wear": "back", "hold": [3, 3], "found": ["living room"], "for": "Zipped off a couch cushion, it is a sack: slung on your back it carries a few things.", "look": {"cut": "pack", "shape": "pack", "ink": "#4f6a8a", "ink2": "#c9b98a", "pat": "print", "thick": 0.05}, "apart": {"into": [["cloth_scrap", 1], ["cloth_strip", 1]], "time": 3.0}},
	"table_runner": {"name": "Lace table runner", "w": 0.1, "size": [1, 3], "cat": "clothing", "wear": "neck", "found": ["living room"], "for": "A long strip of lace off the sideboard. Round your neck it is a thin scarf; torn, it is strips to tie with.", "look": {"cut": "scarf", "ink": "lace", "pat": "lace", "thick": 0.008}, "guard": {"warm": 0.05}, "apart": {"into": [["cloth_strip", 2]], "time": 2.0}},
	"curtain_tieback": {"name": "Curtain tie-back", "w": 0.1, "size": [1, 2], "cat": "clothing", "wear": "strap", "found": ["living room"], "for": "A braided cord with a tassel. Knotted round something long (a plank, a sledgehammer) it carries it across your back, out of your hands.", "look": {"cut": "strap", "shape": "strap", "ink": "yellow", "ink2": "amber", "pat": "stripes", "thick": 0.014}, "pockets": [["Slung across your back", 6.0, "long"]]},
	# ---- food
	"canned_food": {"name": "Tin of beans", "w": 0.45, "cat": "food", "stack": 3, "found": ["kitchen", "shop"], "for": "A meal that keeps for years. It wants a tin opener."},
	# ---- thrown
	"rock": {"name": "Rock", "w": 0.4, "cat": "thrown", "stack": 3, "found": ["yard"], "throw": {"noise": 9.0, "keep": true, "look": [[0.16, 0.12, 0.14], "stone"]}, "for": "Thrown, it makes a noise where it lands. It can be picked up again.", "hit": {"hands": 1, "kind": "blunt", "force": 11.0, "reach": 1.0, "time": 0.55, "lasts": 60, "into": [["rock", 1]], "look": [0.12, 0.1, "stone"]}},
	"bottle": {"name": "Bottle", "w": 0.4, "size": [1, 2], "cat": "thrown", "stack": 3, "found": ["kitchen", "living room"], "throw": {"noise": 14.0, "keep": false, "look": [[0.08, 0.08, 0.26], "green"]}, "for": "Thrown, it smashes: louder than a rock, and gone.", "hit": {"hands": 1, "kind": "blunt", "force": 10.0, "reach": 1.1, "time": 0.45, "lasts": 1, "into": [["broken_bottle", 1], ["glass_shard", 1]], "noise": 9.0, "look": [0.28, 0.07, "green"]}, "apart": {"into": [["broken_bottle", 1], ["glass_shard", 1]], "time": 1.0, "noise": 9.0}},
	# ---- scrap: what broken things leave
	"glass_shard": {"name": "Broken glass", "w": 0.1, "cat": "scrap", "stack": 5, "found": [], "for": "Shards from something glass that broke. Sharp: laid on the ground it is an alarm, and a trap for bare feet.", "does": ["blade"]},
	"broken_bottle": {"name": "Broken bottle", "w": 0.3, "size": [1, 2], "cat": "thrown", "found": [], "for": "The neck of a bottle with a jagged end. It stabs, and it cuts what needs cutting. Thrown, it is just broken glass.", "does": ["blade"], "hit": {"hands": 1, "kind": "pierce", "force": 9.0, "reach": 1.0, "time": 0.4, "lasts": 5, "into": [["glass_shard", 1]], "look": [0.2, 0.06, "green"]}, "apart": {"into": [["glass_shard", 2]], "time": 1.0, "noise": 4.0}},
	"bloody_glass": {"name": "Bloody glass", "w": 0.1, "cat": "scrap", "stack": 5, "found": [], "for": "A shard drawn out of a wound. The blood stays on it."},
	"rolled_rug": {"name": "Rolled-up rug", "w": 6.0, "size": [1, 4], "cat": "material", "found": [], "for": "A rug, rolled up under your arm. Laid on a floor, footsteps on it are muffled: lay it where you come and go.", "hit": {"hands": 2, "kind": "blunt", "force": 9.0, "reach": 1.6, "time": 1.0, "lasts": 40, "into": [["cloth_scrap", 3]], "look": [1.0, 0.12, "wine"]}, "apart": {"into": [["cloth_scrap", 5], ["cloth_strip", 2]], "tool": "blade", "time": 9.0}},
	# ---- appliances you can carry (appliance.gd: stood where you are, they work again)
	"table_lamp": {"name": "Table lamp", "w": 2.2, "size": [2, 3], "cat": "tool", "found": [], "for": "Stood on a floor or a table indoors where there is power, it lights the room: you see, and you are seen. Swung, it breaks on the first blow into glass and its cord.", "hit": {"hands": 1, "kind": "blunt", "force": 9.0, "reach": 1.1, "time": 0.6, "lasts": 1, "into": [["glass_shard", 1], ["electric_cord", 1]], "noise": 7.0, "look": [0.5, 0.15, "plastic"]}, "apart": {"into": [["electric_cord", 1], ["glass_shard", 1], ["scrap_metal", 1], ["cloth_scrap", 1]], "time": 4.0}},
	"floor_lamp": {"name": "Floor lamp", "w": 4.0, "size": [1, 4], "cat": "tool", "found": [], "for": "Stood up indoors where there is power, it lights a room. A long brass pole: a two-handed club, if a flimsy one.", "hit": {"hands": 2, "kind": "blunt", "force": 11.0, "reach": 2.0, "time": 0.95, "lasts": 3, "into": [["scrap_metal", 1], ["electric_cord", 1], ["glass_shard", 1]], "noise": 6.0, "look": [1.5, 0.04, "yellow"]}, "apart": {"into": [["electric_cord", 1], ["scrap_metal", 2], ["cloth_scrap", 1], ["glass_shard", 1]], "time": 5.0}},
	"radio": {"name": "Portable radio", "w": 1.4, "size": [2, 1], "cat": "tool", "uses": 1200, "keep": true, "rare": 0.5, "found": ["living room", "kitchen", "garage"], "for": "On batteries, so it plays anywhere. Set down playing (use it), it goes on by itself, heard a long way off, until the batteries go or something smashes it: a decoy. Batteries load into it as into a torch.", "hit": {"hands": 1, "kind": "blunt", "force": 7.0, "reach": 1.0, "time": 0.55, "lasts": 2, "into": [["plastic_scrap", 2], ["scrap_metal", 1]], "noise": 6.0, "look": [0.36, 0.12, "dark"]}, "apart": {"into": [["plastic_scrap", 2], ["scrap_metal", 1]], "time": 3.0}},
	"electric_cord": {"name": "Electric cord", "w": 0.2, "size": [1, 2], "cat": "material", "wear": "strap", "found": ["living room", "garage"], "for": "Pulled out of a lamp, a phone or a television. Knotted round something long it slings it across your back; it ties a limb off, if cruelly. Inside it is copper.", "look": {"cut": "strap", "shape": "strap", "ink": "dark", "pat": "plain", "thick": 0.008}, "pockets": [["Slung across your back", 6.0, "long"]], "hit": {"hands": 1, "kind": "blunt", "force": 2.0, "reach": 1.4, "time": 0.5, "lasts": 60, "into": [], "look": [0.6, 0.01, "dark"]}, "apart": {"into": [["scrap_metal", 1], ["plastic_scrap", 1]], "tool": "blade", "time": 4.0}},
	# ---- the kitchen's cloth (22 Nov 2026: the second theme, a middle-class kitchen, its clothes session)
	"apron": {"name": "Kitchen apron", "w": 0.35, "size": [2, 2], "cat": "clothing", "wear": "outer", "found": ["kitchen"], "for": "Heavy canvas down the front, with a deep pocket: a little against a blade or a bite from in front, nothing behind.", "look": {"cut": "apron", "shape": "front", "ink": "#3e5a6e", "pat": "plain", "thick": 0.012}, "guard": {"bite": 0.3, "cut": 0.4, "warm": 0.05}, "pockets": [["Apron pocket", 1.0]], "apart": {"into": [["cloth_scrap", 2], ["cloth_strip", 2]], "tool": "blade", "time": 5.0}},
	"oven_mitts": {"name": "Oven mitts", "w": 0.25, "size": [2, 2], "cat": "clothing", "wear": "hands", "found": ["kitchen"], "for": "Thick quilted mitts. Broken glass can be picked up or punched through in them without a cut, and a bite on the hand meets padding; but your fingers are clumsy in them: your aim is worse.", "look": {"cut": "mitts", "ink": "#b8463c", "ink2": "#e8dcc4", "pat": "check", "thick": 0.016}, "guard": {"bite": 0.45, "cut": 0.6, "warm": 0.2, "clumsy": 0.25}, "apart": {"into": [["cloth_scrap", 2]], "tool": "blade", "time": 3.0}},
	"tea_towel": {"name": "Tea towel", "w": 0.08, "size": [1, 1], "cat": "medical", "stack": 3, "found": ["kitchen"], "for": "Clean, folded in a drawer: torn in two (take it apart) it is two clean rags for a wound, with no water spent washing them.", "apart": {"into": [["clean_rag", 2]], "time": 2.0}},
	# ---- the living room's odds and ends (22 Nov 2026: the theme's miscellaneous session)
	"book": {"name": "Hardback book", "w": 0.8, "size": [1, 2], "cat": "misc", "found": ["living room", "bedroom"], "for": "Thrown, it lands with a thud and can be picked up again: something to throw indoors, where there are no rocks. It burns, slowly. (One day, something to read up on.)", "throw": {"noise": 8.0, "keep": true, "look": [[0.16, 0.04, 0.22], "wine"]}, "hit": {"hands": 1, "kind": "blunt", "force": 4.0, "reach": 0.9, "time": 0.5, "lasts": 8, "into": [], "look": [0.22, 0.05, "wine"]}},
	"vinyl_record": {"name": "Vinyl record", "w": 0.2, "size": [2, 2], "cat": "misc", "found": ["living room"], "for": "Spun like a disc it sails further than anything else you can throw, and clatters where it lands. The music on it waits for something to play it on.", "throw": {"noise": 9.0, "keep": true, "far": 1.5, "look": [[0.3, 0.01, 0.3], "dark"]}, "hit": {"hands": 1, "kind": "blunt", "force": 2.0, "reach": 1.0, "time": 0.45, "lasts": 1, "into": [["plastic_scrap", 1]], "look": [0.3, 0.01, "dark"]}},
	"dvd": {"name": "DVD", "w": 0.1, "size": [1, 2], "cat": "misc", "stack": 5, "found": ["living room", "bedroom"], "for": "A film in its case, with nothing to play it on. Thrown like a disc it flies nearly as far as a record and lands quietly. Snapped in half (take it apart), its edge is sharp enough to cut with.", "throw": {"noise": 5.0, "keep": true, "far": 1.3, "look": [[0.14, 0.015, 0.19], "slate"]}, "hit": {"hands": 1, "kind": "blunt", "force": 1.5, "reach": 0.9, "time": 0.4, "lasts": 1, "into": [["dvd_shard", 1]], "look": [0.19, 0.015, "slate"]}, "apart": {"into": [["dvd_shard", 1], ["plastic_scrap", 1]], "time": 1.0, "noise": 3.0}},
	"dvd_shard": {"name": "Snapped DVD", "w": 0.02, "cat": "tool", "found": [], "for": "Half a DVD with a jagged edge: it cuts cloth, cord and a plank's grain, poorly, where you have no knife. A wretched thing to stab with.", "does": ["blade"], "hit": {"hands": 1, "kind": "pierce", "force": 4.0, "reach": 0.8, "time": 0.4, "lasts": 4, "into": [["plastic_scrap", 1]], "look": [0.1, 0.01, "steel"]}},
	"magazine": {"name": "Magazine", "w": 0.25, "size": [2, 2], "cat": "misc", "stack": 6, "found": ["living room", "bedroom", "bathroom"], "for": "Two of them rolled round a forearm and tied with a strip of cloth or a cord (use them) are a guard a bite struggles to get through. They burn, quickly."},
	"magazine_bracer": {"name": "Magazine guard (left arm)", "w": 0.5, "size": [2, 2], "cat": "clothing", "wear": "wrist_l", "found": [], "for": "Magazines tied round the left forearm: a bite there mostly meets paper. They tear with every bite they stop.", "look": {"cut": "bracer", "ink": "#c8c0a4", "ink2": "red", "pat": "print", "thick": 0.016, "side": "L"}, "guard": {"bite": 0.75, "cut": 0.6, "blow": 0.2, "warm": 0.02}, "apart": {"into": [["magazine", 2]], "time": 2.0}},
	"magazine_bracer_r": {"name": "Magazine guard (right arm)", "w": 0.5, "size": [2, 2], "cat": "clothing", "wear": "wrist_r", "found": [], "for": "Magazines tied round the right forearm: a bite there mostly meets paper. They tear with every bite they stop.", "look": {"cut": "bracer", "ink": "#c8c0a4", "ink2": "red", "pat": "print", "thick": 0.016, "side": "R"}, "guard": {"bite": 0.75, "cut": 0.6, "blow": 0.2, "warm": 0.02}, "apart": {"into": [["magazine", 2]], "time": 2.0}},
	"fire_poker": {"name": "Fire poker", "w": 1.2, "size": [1, 4], "cat": "tool", "found": [], "for": "From beside the fireplace: it pokes a fire, and a skull. Its hooked end prises the boards off a window, slower than a crowbar.", "does": ["pry"], "pry_mult": 1.7, "hit": {"hands": 1, "kind": "pierce", "force": 14.0, "reach": 1.5, "time": 0.6, "lasts": 40, "into": [["scrap_metal", 1]], "look": [0.75, 0.025, "iron"]}},
	"trophy": {"name": "Trophy", "w": 1.6, "size": [1, 2], "cat": "misc", "rare": 0.5, "found": ["living room", "bedroom"], "for": "Somebody's bowling trophy on a marble base: heavy enough in the hand to cave a head in.", "hit": {"hands": 1, "kind": "blunt", "force": 13.0, "reach": 1.0, "time": 0.6, "lasts": 25, "into": [["scrap_metal", 1], ["rock", 1]], "look": [0.3, 0.09, "yellow"]}, "apart": {"into": [["scrap_metal", 1], ["rock", 1]], "time": 3.0}},
	"tv_remote": {"name": "TV remote", "w": 0.15, "size": [1, 2], "cat": "misc", "found": ["living room"], "for": "There are batteries in the back, good for a torch or a radio: take it apart.", "apart": {"into": [["battery", 1], ["plastic_scrap", 1]], "time": 2.0}},
	"marbles": {"name": "Bag of marbles", "w": 0.4, "cat": "misc", "found": ["living room", "bedroom"], "for": "Scattered on a floor (use them), they rattle under whoever walks on them and roll a foot from under anyone in a hurry: a zombie goes down, a raider stumbles, and so do you. Picked up again by hand.", "hit": {"hands": 1, "kind": "blunt", "force": 5.0, "reach": 0.9, "time": 0.5, "lasts": 10, "into": [], "look": [0.1, 0.08, "blue"]}},
	"candle": {"name": "Candle", "w": 0.1, "cat": "tool", "uses": 1800, "found": ["living room", "kitchen", "bedroom"], "for": "Lit with a match and set down (use it), a little light without power, for half an hour. Click it to blow it out; Shift+click to pick it up.", "apart": {"into": [], "time": 1.0}},
	"toy_robot": {"name": "Toy robot", "w": 0.5, "size": [1, 2], "cat": "misc", "uses": 300, "keep": true, "rare": 0.4, "found": ["living room", "bedroom"], "for": "Set down (use it), it marches off the way you face, clanking, heard 10 m off, turning at walls, until its batteries go or a zombie catches it: a decoy that leads them away. Batteries load into it.", "hit": {"hands": 1, "kind": "blunt", "force": 3.0, "reach": 0.9, "time": 0.5, "lasts": 2, "into": [["plastic_scrap", 1]], "look": [0.2, 0.1, "steel"]}, "apart": {"into": [["plastic_scrap", 1], ["scrap_metal", 1]], "time": 3.0}},
	"cloth_strip": {"name": "Strip of cloth", "w": 0.03, "cat": "scrap", "stack": 6, "found": [], "for": "Torn from cloth. It ties: a limb off above a wound before it comes off, and more to come."},
	"cloth_scrap": {"name": "Torn cloth", "w": 0.1, "cat": "scrap", "stack": 5, "found": [], "for": "Ripped from a couch or a mattress. Filthy as it is; washed in clean water, it is a rag."},
	"wood_scrap": {"name": "Splintered wood", "w": 0.4, "cat": "scrap", "stack": 3, "found": [], "for": "Broken wood: no use as a plank any more, but it burns."},
	"scrap_metal": {"name": "Scrap metal", "w": 0.6, "cat": "scrap", "stack": 2, "found": [], "for": "Bent and torn metal from something that broke."},
	"plastic_scrap": {"name": "Broken plastic", "w": 0.15, "cat": "scrap", "stack": 4, "found": [], "for": "Cracked pieces of something plastic."},
}

## What burns on a fire, and for how long (s) each. Stand-ins until there is a clock.
const FUEL := {"wood_scrap": 240.0, "plank": 480.0, "book": 150.0, "magazine": 40.0}


## The items that turn up in a kind of place ("kitchen", "garage"...), for the loot tables to come.
static func found_in(place: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:
		var f: Array = DEFS[id].get("found", [])
		if f.has(place) or f.has("anywhere"):
			out.append(id)
	return out


## How it does as a weapon in a hand ({} if it is no weapon: you hit with your fist round it).
static func hit_of(id: String) -> Dictionary:
	return DEFS[id].get("hit", {}) if DEFS.has(id) else {}


## How the thing in this hand is holding up as a weapon, in words ("" while it is sound).
static func wear_word(item: Dictionary) -> String:
	var h := hit_of(item["id"])
	if h.is_empty() or int(h["lasts"]) <= 1 or not item.has("hits"):
		return ""
	var f := float(item["hits"]) / float(h["lasts"])
	return "" if f < 0.4 else ("worn" if f < 0.8 else "about to go")


## What it is for, and then how it does as a weapon and what it comes apart into, as the player reads it.
static func about(id: String) -> String:
	var d: Dictionary = DEFS[id]
	var t := str(d["for"])
	var h := hit_of(id)
	if not h.is_empty():
		var kind := {"blunt": "clubs", "chop": "chops", "pierce": "stabs"}[h["kind"]] as String
		var lasts := int(h["lasts"])
		t += " As a weapon: %s, it %s; %s." % ["two hands" if int(h["hands"]) == 2 else "one hand", kind,
			"one blow and it breaks" if lasts <= 1 else ("it won't last" if lasts <= 8 else ("it lasts a while" if lasts <= 60 else "it lasts"))]
	if d.has("apart"):
		var a: Dictionary = d["apart"]
		var into: Array[String] = []
		for pr: Array in a["into"]:
			into.append(name_of(pr[0]).to_lower())
		t += " Taken apart%s: %s." % [" (it wants something to cut with)" if str(a.get("tool", "")) == "blade" else \
			(" (it wants a %s)" % a["tool"] if str(a.get("tool", "")) != "" else ""), ", ".join(into)]
	return t


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
	var w := float(d["w"]) * (int(item["n"]) if item.has("n") else 1)
	if item.has("grid"):
		w += ItemGrid.weight(item["grid"])       # a bag weighs what is in it
	for k in item.get("pocketed", {}):
		w += weight(item["pocketed"][k])        # and clothes what is in their pockets
	return w


## How many squares it takes in a grid: wide, high.
static func size_of(id: String) -> Vector2i:
	var sz: Array = DEFS[id].get("size", [1, 1])
	return Vector2i(int(sz[0]), int(sz[1]))


## The grid a bag holds its things in (made the first time it is asked for), or {} if this isn't a bag.
static func hold_of(item: Dictionary) -> Dictionary:
	if not DEFS[item["id"]].has("hold"):
		return {}
	if not item.has("grid"):
		var h: Array = DEFS[item["id"]]["hold"]
		item["grid"] = ItemGrid.make(int(h[0]), int(h[1]))
		item["grid"]["bag"] = true
	return item["grid"]


## How it reads in a list: "Bandage x3", "Vodka (4 left)".
static func label(item: Dictionary) -> String:
	var nm := name_of(item["id"])
	if item["id"] == "water":
		return "%s (%s, %s)" % [nm, "empty" if int(item["uses"]) <= 0 else "%d left" % int(item["uses"]), Water.look(item)]
	if item["id"] == "torch":
		return "%s (%s)" % [nm, "flat" if int(item["uses"]) <= 0 else ("%d min left" % ceili(int(item["uses"]) / 60.0))]
	var ww := wear_word(item)
	if ww != "":
		nm += " (%s)" % ww
	if item.has("uses"):
		return "%s (%d left)" % [nm, int(item["uses"])]
	return "%s x%d" % [nm, int(item["n"])] if int(item["n"]) > 1 else nm
