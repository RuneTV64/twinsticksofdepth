class_name ItemArt
extends RefCounted
## The pictures for the loot screen (loot_screen.gd), drawn by code, 16 texels to a grid square:
##   icon(id)                      a thing, at its size on the grid (Items.size_of)
##   backdrop(look, stain, w, h)   the inside of what you are searching, behind the grid: an open drawer seen
##                                 from above, a cupboard, a fridge, a wardrobe's rail, shelves, the inside of
##                                 a bag. It is the meter too: the screen shows it a column at a time as you
##                                 search (owner, 20 Nov 2026).
## Both are small images shown big with no smoothing, in the game's banded, dithered look. Each is made once
## and kept.
##
## An icon is a short recipe of shapes (ART). Every shape is shaded by its own outline (light on its upper
## left edges, dark on its lower right) and the whole is given a dark line round it, so a recipe is only the
## shapes and their inks. A new item needs one line there; without one it shows as a parcel.
##   ["R", x0, y0, x1, y1, ink]        a box (corners included)
##   ["E", cx, cy, rx, ry, ink]        a round
##   ["L", x0, y0, x1, y1, thick, ink] a bar from point to point
##   ["P", [x, y, x, y, ...], ink]     any shape, by its corners
##   ["F", x0, y0, x1, y1, ink]        a flat box, no shading (a label, a mark)
##   ["X", x0, y0, x1, y1]             cut a box away

const PX := 16
const EDGE := 6                     # texels of rim round a backdrop
const LINE := Color("1c1a1e")

const INK := {
	"white": Color("e6e4da"), "cloth": Color("cdc4ac"), "rag": Color("9a8f7a"), "steel": Color("9aa2ac"),
	"iron": Color("50545e"), "wood": Color("a9794a"), "pale": Color("cfa672"), "red": Color("b4463c"),
	"blue": Color("4f76a8"), "water": Color("86b4d2"), "glass": Color("b4d0cc"), "green": Color("5f8a56"),
	"amber": Color("c98a3a"), "yellow": Color("d6b648"), "tin": Color("b2b6b2"), "card": Color("b89a6a"),
	"stone": Color("8a867e"), "leather": Color("6a4a34"), "olive": Color("6c7848"), "canvas": Color("7c7658"),
	"blood": Color("7c1c1c"), "wine": Color("6e2a36"), "mustard": Color("b8893a"), "slate": Color("4f6a8a"),
	"lace": Color("efeadc"), "denim": Color("4a6a9a"), "plastic": Color("c6beb0"), "dark": Color("3a3c44"), "crimson": Color("7e2a2c"),
}

const ART := {
	# ---- medical
	"bandage": [["E", 8, 8, 6, 6, "white"], ["E", 8, 8, 2, 2, "rag"], ["F", 12, 9, 14, 10, "white"]],
	"clean_rag": [["R", 2, 4, 13, 12, "cloth"], ["F", 2, 8, 13, 8, "rag"], ["F", 8, 4, 8, 7, "rag"]],
	"needle_thread": [["R", 4, 5, 9, 11, "red"], ["R", 3, 3, 10, 4, "wood"], ["R", 3, 12, 10, 13, "wood"], ["L", 13, 2, 12, 13, 1, "steel"]],
	"tweezers": [["L", 4, 2, 8, 13, 1, "steel"], ["L", 11, 2, 8, 13, 1, "steel"], ["F", 7, 3, 8, 4, "steel"]],
	"vodka": [["R", 4, 11, 11, 29, "glass"], ["R", 6, 4, 9, 10, "glass"], ["R", 6, 1, 9, 3, "red"], ["F", 5, 16, 10, 23, "white"], ["F", 6, 19, 9, 20, "red"]],
	"water": [["R", 4, 9, 11, 29, "water"], ["R", 6, 4, 9, 8, "water"], ["R", 6, 1, 9, 3, "white"], ["F", 5, 14, 10, 20, "white"], ["F", 6, 16, 9, 17, "blue"]],
	"purify_tabs": [["R", 2, 4, 13, 11, "white"], ["F", 4, 6, 5, 7, "blue"], ["F", 7, 6, 8, 7, "blue"], ["F", 10, 6, 11, 7, "blue"], ["F", 4, 9, 5, 9, "blue"], ["F", 7, 9, 8, 9, "blue"], ["F", 10, 9, 11, 9, "blue"]],
	"steroids": [["R", 5, 6, 10, 13, "amber"], ["R", 4, 2, 11, 5, "white"], ["F", 6, 8, 9, 10, "white"]],
	"painkillers": [["R", 5, 6, 10, 13, "white"], ["R", 4, 2, 11, 5, "red"], ["F", 6, 8, 9, 10, "red"]],
	"antibiotics": [["R", 5, 6, 10, 13, "amber"], ["R", 4, 2, 11, 5, "blue"], ["F", 6, 8, 9, 10, "blue"]],
	# ---- tools
	"water_filter": [["R", 4, 5, 11, 25, "blue"], ["R", 5, 1, 10, 4, "dark"], ["R", 7, 26, 8, 30, "white"], ["F", 5, 9, 10, 10, "white"], ["F", 5, 20, 10, 21, "white"]],
	"hatchet": [["R", 7, 5, 8, 45, "wood"], ["P", [8, 3, 14, 1, 14, 14, 8, 11], "steel"], ["R", 6, 4, 9, 10, "iron"]],
	"sledgehammer": [["R", 15, 12, 16, 61, "wood"], ["R", 6, 3, 25, 12, "iron"], ["F", 8, 5, 9, 10, "steel"], ["F", 22, 5, 23, 10, "steel"]],
	"hammer": [["R", 7, 7, 8, 30, "wood"], ["R", 3, 2, 12, 6, "steel"], ["P", [12, 2, 14, 1, 14, 3, 12, 5], "steel"]],
	"crowbar": [["L", 8, 7, 8, 43, 2, "crimson"], ["L", 8, 7, 12, 3, 2, "crimson"], ["L", 8, 43, 5, 46, 2, "crimson"]],
	"torch": [["R", 4, 3, 11, 9, "steel"], ["F", 5, 2, 10, 2, "yellow"], ["R", 6, 10, 9, 29, "dark"], ["F", 7, 14, 8, 16, "red"]],
	"battery": [["R", 3, 5, 7, 13, "yellow"], ["R", 4, 3, 6, 4, "steel"], ["R", 9, 5, 13, 13, "yellow"], ["R", 10, 3, 12, 4, "steel"], ["F", 3, 10, 7, 13, "dark"], ["F", 9, 10, 13, 13, "dark"]],
	"fire_torch": [["R", 7, 18, 8, 45, "wood"], ["E", 8, 10, 3, 8, "rag"], ["F", 6, 8, 10, 8, "leather"], ["F", 6, 12, 10, 12, "leather"]],
	"matches": [["R", 2, 5, 13, 11, "red"], ["F", 3, 10, 12, 10, "leather"], ["F", 5, 7, 10, 8, "yellow"]],
	"cooking_pot": [["R", 6, 12, 25, 26, "steel"], ["R", 5, 9, 26, 11, "steel"], ["R", 1, 13, 4, 15, "iron"], ["R", 27, 13, 30, 15, "iron"], ["F", 7, 12, 24, 13, "iron"]],
	"can_opener": [["L", 3, 13, 8, 7, 2, "red"], ["L", 7, 13, 11, 8, 2, "red"], ["E", 11, 4, 3, 3, "steel"], ["F", 11, 4, 11, 4, "iron"]],
	# ---- materials
	"plank": [["R", 4, 2, 11, 61, "pale"], ["F", 6, 6, 6, 30, "wood"], ["F", 9, 24, 9, 56, "wood"], ["F", 7, 40, 7, 58, "wood"], ["F", 7, 12, 8, 13, "leather"]],
	"nails": [["R", 2, 5, 13, 12, "card"], ["L", 4, 3, 7, 7, 1, "steel"], ["L", 8, 2, 9, 7, 1, "steel"], ["L", 12, 3, 10, 7, 1, "steel"]],
	# ---- clothing
	"boots": [["P", [3, 4, 11, 4, 11, 17, 16, 21, 16, 27, 3, 27], "leather"], ["F", 3, 26, 16, 27, "dark"], ["F", 5, 8, 9, 8, "card"], ["F", 5, 11, 9, 11, "card"], ["F", 5, 14, 9, 14, "card"],
		["P", [17, 6, 25, 6, 25, 18, 29, 22, 29, 28, 17, 28], "leather"], ["F", 17, 27, 29, 28, "dark"], ["F", 19, 10, 23, 10, "card"], ["F", 19, 13, 23, 13, "card"]],
	"helmet": [["E", 16, 18, 12, 11, "olive"], ["X", 0, 21, 31, 31], ["R", 3, 20, 28, 23, "olive"], ["F", 9, 24, 10, 26, "leather"], ["F", 21, 24, 22, 26, "leather"]],
	"backpack": [["R", 10, 12, 37, 43, "canvas"], ["E", 24, 13, 13, 6, "canvas"], ["R", 12, 8, 14, 13, "leather"], ["R", 33, 8, 35, 13, "leather"], ["R", 15, 28, 32, 40, "olive"],
		["F", 15, 28, 32, 29, "dark"], ["F", 11, 21, 36, 21, "dark"], ["F", 23, 22, 24, 25, "steel"], ["R", 20, 4, 27, 6, "leather"]],
	# ---- clothing
	"t_shirt": [["P", [3, 6, 10, 3, 22, 3, 29, 6, 31, 13, 25, 13, 25, 29, 7, 29, 7, 13, 1, 13], "white"], ["F", 12, 3, 20, 5, "rag"]],
	"jeans": [["P", [6, 2, 26, 2, 28, 45, 19, 45, 16, 14, 13, 45, 4, 45], "denim"], ["F", 6, 2, 26, 4, "leather"], ["F", 16, 5, 16, 13, "dark"], ["F", 8, 6, 12, 9, "water"], ["F", 20, 6, 24, 9, "water"]],
	"belt": [["R", 6, 2, 10, 45, "leather"], ["R", 4, 4, 12, 10, "yellow"], ["X", 6, 6, 10, 8], ["F", 8, 14, 8, 15, "dark"], ["F", 8, 20, 8, 21, "dark"]],
	"socks": [["P", [3, 2, 8, 2, 8, 9, 13, 11, 13, 14, 3, 14], "white"], ["F", 3, 2, 8, 4, "red"]],
	"sneakers": [["P", [2, 12, 9, 6, 14, 8, 28, 16, 29, 22, 2, 22], "white"], ["F", 2, 20, 29, 22, "dark"], ["F", 9, 9, 13, 10, "dark"], ["F", 11, 12, 15, 13, "dark"], ["F", 20, 16, 24, 18, "red"], ["P", [2, 27, 9, 24, 14, 25, 28, 28, 29, 31, 2, 31], "white"]],
	"curtains": [["R", 3, 2, 22, 45, "wine"], ["R", 25, 2, 44, 45, "wine"], ["F", 3, 2, 44, 4, "yellow"], ["F", 8, 6, 8, 44, "crimson"], ["F", 15, 6, 15, 44, "crimson"], ["F", 31, 6, 31, 44, "crimson"], ["F", 38, 6, 38, 44, "crimson"]],
	"net_curtain": [["R", 3, 3, 28, 28, "lace"], ["F", 3, 3, 28, 4, "steel"], ["F", 7, 7, 7, 27, "white"], ["F", 13, 7, 13, 27, "white"], ["F", 19, 7, 19, 27, "white"], ["F", 25, 7, 25, 27, "white"]],
	"tablecloth": [["R", 3, 3, 28, 28, "white"], ["F", 3, 6, 28, 8, "red"], ["F", 3, 14, 28, 16, "red"], ["F", 3, 22, 28, 24, "red"], ["F", 6, 3, 8, 28, "red"], ["F", 14, 3, 16, 28, "red"], ["F", 22, 3, 24, 28, "red"]],
	"throw_blanket": [["R", 3, 4, 44, 27, "mustard"], ["F", 3, 9, 44, 11, "olive"], ["F", 3, 17, 44, 19, "olive"], ["F", 3, 27, 44, 29, "mustard"], ["F", 5, 29, 5, 31, "mustard"], ["F", 15, 29, 15, 31, "mustard"], ["F", 25, 29, 25, 31, "mustard"], ["F", 35, 29, 35, 31, "mustard"]],
	"cushion_cover": [["R", 4, 4, 27, 27, "slate"], ["F", 4, 4, 27, 5, "dark"], ["F", 9, 10, 10, 11, "card"], ["F", 19, 10, 20, 11, "card"], ["F", 14, 17, 15, 18, "card"], ["F", 9, 22, 10, 23, "card"], ["F", 19, 22, 20, 23, "card"]],
	"table_runner": [["R", 4, 2, 11, 45, "lace"], ["F", 6, 6, 9, 7, "white"], ["F", 6, 14, 9, 15, "white"], ["F", 6, 22, 9, 23, "white"], ["F", 6, 30, 9, 31, "white"], ["F", 6, 38, 9, 39, "white"]],
	"curtain_tieback": [["L", 8, 2, 8, 20, 2, "yellow"], ["E", 8, 4, 4, 3, "amber"], ["P", [5, 20, 11, 20, 13, 30, 3, 30], "amber"]],
	"rolled_rug": [["R", 3, 2, 12, 61, "wine"], ["F", 3, 2, 12, 3, "mustard"], ["F", 3, 60, 12, 61, "mustard"], ["F", 5, 10, 10, 10, "crimson"], ["F", 5, 22, 10, 22, "crimson"], ["F", 5, 34, 10, 34, "crimson"], ["F", 5, 46, 10, 46, "crimson"], ["E", 7, 2, 3, 2, "crimson"]],
	"table_lamp": [["P", [4, 4, 27, 4, 30, 18, 1, 18], "cloth"], ["F", 4, 4, 27, 5, "card"], ["R", 15, 19, 16, 26, "yellow"], ["E", 15, 35, 8, 8, "plastic"], ["R", 8, 42, 23, 46, "plastic"], ["L", 23, 44, 30, 47, 1, "dark"]],
	"floor_lamp": [["P", [2, 2, 13, 2, 15, 12, 0, 12], "cloth"], ["F", 2, 2, 13, 3, "card"], ["R", 7, 13, 8, 58, "yellow"], ["R", 2, 59, 13, 62, "yellow"], ["L", 13, 60, 15, 63, 1, "dark"]],
	"radio": [["R", 1, 4, 30, 15, "dark"], ["L", 6, 1, 25, 1, 1, "dark"], ["R", 3, 6, 16, 13, "iron"], ["F", 4, 7, 4, 12, "dark"], ["F", 7, 7, 7, 12, "dark"], ["F", 10, 7, 10, 12, "dark"], ["F", 13, 7, 13, 12, "dark"], ["F", 19, 8, 28, 9, "amber"], ["E", 21, 12, 1, 1, "steel"], ["E", 26, 12, 1, 1, "steel"]],
	"electric_cord": [["L", 4, 4, 11, 10, 1, "dark"], ["L", 11, 10, 4, 17, 1, "dark"], ["L", 4, 17, 11, 24, 1, "dark"], ["R", 9, 25, 13, 29, "iron"], ["F", 10, 30, 10, 31, "steel"], ["F", 12, 30, 12, 31, "steel"]],
	"book": [["R", 2, 2, 14, 29, "wine"], ["R", 3, 2, 4, 29, "crimson"], ["F", 6, 8, 12, 9, "yellow"], ["F", 6, 11, 11, 11, "yellow"], ["F", 14, 3, 14, 28, "lace"]],
	"vinyl_record": [["R", 1, 1, 30, 30, "card"], ["F", 3, 3, 27, 4, "red"], ["E", 21, 16, 9, 9, "dark"], ["E", 21, 16, 3, 3, "red"], ["F", 21, 16, 21, 16, "dark"]],
	"dvd": [["R", 2, 2, 13, 29, "dark"], ["R", 3, 3, 12, 28, "slate"], ["E", 8, 16, 4, 4, "steel"], ["E", 8, 16, 1, 1, "dark"], ["F", 4, 4, 11, 6, "red"]],
	"dvd_shard": [["P", [2, 13, 8, 2, 13, 6, 14, 13], "steel"], ["F", 7, 9, 9, 9, "water"], ["L", 2, 13, 14, 13, 1, "white"]],
	"magazine": [["R", 3, 2, 28, 29, "lace"], ["F", 5, 4, 26, 8, "red"], ["R", 7, 11, 24, 22, "slate"], ["F", 5, 24, 18, 25, "dark"], ["F", 5, 27, 14, 27, "dark"]],
	"magazine_bracer": [["R", 6, 3, 25, 28, "lace"], ["F", 8, 6, 23, 9, "red"], ["F", 6, 12, 25, 13, "rag"], ["F", 6, 21, 25, 22, "rag"], ["F", 10, 15, 21, 19, "slate"]],
	"magazine_bracer_r": [["R", 6, 3, 25, 28, "lace"], ["F", 8, 6, 23, 9, "red"], ["F", 6, 12, 25, 13, "rag"], ["F", 6, 21, 25, 22, "rag"], ["F", 10, 15, 21, 19, "slate"]],
	"fire_poker": [["L", 8, 4, 8, 58, 1, "iron"], ["L", 8, 6, 12, 2, 1, "iron"], ["R", 6, 56, 10, 62, "leather"]],
	"trophy": [["E", 8, 6, 5, 5, "yellow"], ["R", 7, 11, 8, 20, "yellow"], ["P", [4, 20, 11, 20, 13, 24, 2, 24], "yellow"], ["R", 2, 25, 13, 30, "lace"], ["F", 4, 27, 11, 27, "dark"]],
	"tv_remote": [["R", 4, 2, 11, 29, "dark"], ["F", 6, 4, 6, 4, "red"], ["F", 6, 9, 9, 9, "steel"], ["F", 6, 12, 9, 12, "steel"], ["F", 6, 15, 9, 15, "steel"], ["F", 6, 18, 9, 18, "steel"], ["F", 6, 21, 9, 21, "steel"]],
	"marbles": [["P", [5, 2, 10, 2, 13, 7, 14, 14, 2, 14, 2, 7], "canvas"], ["F", 4, 4, 11, 4, "leather"], ["E", 6, 10, 1, 1, "blue"], ["E", 10, 11, 1, 1, "red"], ["E", 8, 8, 1, 1, "green"]],
	"candle": [["R", 5, 5, 10, 14, "lace"], ["F", 7, 3, 8, 4, "dark"], ["E", 7, 1, 1, 1, "amber"]],
	"toy_robot": [["R", 4, 2, 11, 8, "steel"], ["F", 5, 4, 6, 5, "red"], ["F", 9, 4, 10, 5, "red"], ["R", 3, 10, 12, 20, "red"], ["F", 5, 12, 10, 14, "steel"], ["R", 4, 21, 6, 29, "steel"], ["R", 9, 21, 11, 29, "steel"]],
	"cloth_strip": [["L", 3, 12, 13, 4, 2, "rag"], ["F", 4, 11, 5, 11, "dark"]],
	# ---- food
	"canned_food": [["R", 4, 3, 11, 13, "tin"], ["F", 4, 6, 11, 10, "red"], ["F", 6, 7, 9, 9, "amber"]],
	# ---- thrown
	"rock": [["P", [3, 9, 6, 4, 11, 4, 14, 8, 12, 13, 5, 13], "stone"]],
	"bottle": [["R", 4, 12, 11, 29, "green"], ["R", 6, 3, 9, 11, "green"], ["F", 6, 2, 9, 2, "dark"]],
	"broken_bottle": [["P", [4, 14, 6, 19, 8, 15, 10, 21, 11, 14, 11, 29, 4, 29], "green"], ["R", 6, 3, 9, 11, "green"], ["F", 6, 2, 9, 2, "dark"], ["F", 5, 24, 6, 27, "glass"]],
	# ---- scrap
	"glass_shard": [["P", [3, 12, 6, 3, 9, 11], "glass"], ["P", [9, 13, 12, 6, 14, 12], "glass"]],
	"bloody_glass": [["P", [3, 12, 6, 3, 9, 11], "glass"], ["P", [9, 13, 12, 6, 14, 12], "glass"], ["F", 5, 6, 6, 9, "blood"], ["F", 11, 9, 12, 11, "blood"]],
	"cloth_scrap": [["P", [2, 5, 9, 3, 14, 7, 12, 13, 6, 11, 3, 12], "rag"], ["F", 6, 6, 9, 6, "dark"]],
	"wood_scrap": [["L", 3, 12, 11, 3, 2, "wood"], ["L", 6, 13, 13, 8, 2, "pale"]],
	"scrap_metal": [["P", [2, 6, 8, 3, 13, 5, 14, 11, 9, 13, 3, 11], "steel"], ["F", 6, 6, 10, 7, "iron"]],
	"plastic_scrap": [["P", [2, 9, 7, 3, 9, 9, 5, 13], "plastic"], ["P", [9, 5, 14, 6, 13, 12, 10, 11], "plastic"]],
}
const PARCEL := [["R", 2, 3, 13, 13, "card"], ["F", 7, 3, 8, 13, "leather"], ["F", 2, 8, 13, 8, "leather"]]

# The 8-shade ramps of the backdrops, light to dark (five stops drawn out to eight, as the kits' ramps are).
const WOODS := [
	["#ecd6a4", "#d2b27a", "#a88654", "#70583a", "#3a2e26"],      # pine
	["#d8a86c", "#b27f4a", "#865a34", "#553826", "#2c1e1c"],      # oak
	["#b08a6c", "#86604a", "#5c4034", "#3a2824", "#1e1618"],      # walnut
]
const ENAMEL := ["#fbfbf6", "#e4e6e2", "#b8bcbc", "#7c8088", "#42444e"]
const STEEL := ["#d8dce0", "#a8aeb6", "#787e8a", "#4c505c", "#262830"]
const CANVAS := ["#b4ac88", "#8c8464", "#646048", "#403e32", "#222220"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _icons := {}
static var _backs := {}


# ------------------------------------------------------------------------------------------------ icons
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = ImageTexture.create_from_image(icon_image(id))
	return _icons[id]


static func icon_image(id: String) -> Image:
	var sz := Items.size_of(id) if Items.DEFS.has(id) else Vector2i.ONE
	var w := sz.x * PX
	var h := sz.y * PX
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for op: Array in ART.get(id, PARCEL):
		var mask := PackedByteArray()
		mask.resize(w * h)
		match str(op[0]):
			"R", "F":
				for y in range(int(op[2]), int(op[4]) + 1):
					for x in range(int(op[1]), int(op[3]) + 1):
						_mark(mask, w, h, x, y)
			"X":
				for y in range(int(op[2]), int(op[4]) + 1):
					for x in range(int(op[1]), int(op[3]) + 1):
						if x >= 0 and y >= 0 and x < w and y < h:
							img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			"E":
				var c := Vector2(float(op[1]) + 0.5, float(op[2]) + 0.5)
				var r := Vector2(float(op[3]) + 0.5, float(op[4]) + 0.5)
				for y in h:
					for x in w:
						var d := (Vector2(x + 0.5, y + 0.5) - c) / r
						if d.length_squared() <= 1.0:
							_mark(mask, w, h, x, y)
			"L":
				var a := Vector2(float(op[1]) + 0.5, float(op[2]) + 0.5)
				var b := Vector2(float(op[3]) + 0.5, float(op[4]) + 0.5)
				var half := float(op[5]) * 0.5 + 0.01
				for y in h:
					for x in w:
						var p := Vector2(x + 0.5, y + 0.5)
						if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= half:
							_mark(mask, w, h, x, y)
			"P":
				var pts := PackedVector2Array()
				var flat: Array = op[1]
				for i in range(0, flat.size(), 2):
					pts.append(Vector2(float(flat[i]) + 0.5, float(flat[i + 1]) + 0.5))
				for y in h:
					for x in w:
						var q := Vector2(x + 0.5, y + 0.5)
						var near := false
						for i in pts.size():
							if q.distance_to(Geometry2D.get_closest_point_to_segment(q, pts[i], pts[(i + 1) % pts.size()])) <= 0.5:
								near = true
						if near or Geometry2D.is_point_in_polygon(q, pts):
							_mark(mask, w, h, x, y)
		var ink: Color = INK[str(op[op.size() - 1])]
		var flat_ink := str(op[0]) == "F"
		for y in h:
			for x in w:
				if mask[y * w + x] == 0:
					continue
				var col := ink
				if not flat_ink:
					var up := _has(mask, w, h, x, y - 1)
					var dn := _has(mask, w, h, x, y + 1)
					var lf := _has(mask, w, h, x - 1, y)
					var rt := _has(mask, w, h, x + 1, y)
					if (not up and not dn) or (not lf and not rt):
						col = ink                            # too thin to have a lit side and a dark one
					elif not up or not lf:
						col = ink.lightened(0.3)
					elif not dn or not rt:
						col = ink.darkened(0.32)
				img.set_pixel(x, y, col)
	# A dark line round the whole of it.
	var out := img.duplicate() as Image
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.0:
					out.set_pixel(x, y, LINE)
					break
	return out


static func _mark(mask: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		mask[y * w + x] = 1


static func _has(mask: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and mask[y * w + x] != 0


# -------------------------------------------------------------------------------------------- backdrops
## The inside of the thing, `w` by `h` squares, with a rim of EDGE texels round it. `look`: "drawer",
## "cupboard", "shelf", "rail", "fridge", "freezer", "bag". `stain`: the wood, as the furniture kit's.
static func backdrop(look: String, stain: int, w: int, h: int) -> Texture2D:
	var key := "%s %d %d %d" % [look, stain, w, h]
	if not _backs.has(key):
		_backs[key] = ImageTexture.create_from_image(backdrop_image(look, stain, w, h))
	return _backs[key]


static func _ramp(stops: Array) -> Array[Color]:
	var out: Array[Color] = []
	for i in 8:
		var f := i * 4.0 / 7.0
		var a := mini(int(f), 3)
		out.append(Color(str(stops[a])).lerp(Color(str(stops[a + 1])), f - a))
	return out


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


# A lightness (0 dark to 1 light) to one of a ramp's eight shades, dithered.
static func _shade(ramp: Array[Color], v: float, x: int, y: int) -> Color:
	var t := (1.0 - clampf(v, 0.0, 1.0)) * 7.0 + (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0 - 0.5
	return ramp[clampi(roundi(t), 0, 7)]


static func backdrop_image(look: String, stain: int, w: int, h: int) -> Image:
	var iw := w * PX + EDGE * 2
	var ih := h * PX + EDGE * 2
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	var wood := _ramp(WOODS[clampi(stain, 0, 2)])
	var enamel := _ramp(ENAMEL)
	var steel := _ramp(STEEL)
	var canvas := _ramp(CANVAS)
	for y in ih:
		for x in iw:
			var ix := x - EDGE                    # inside the rim: 0 .. w*PX-1
			var iy := y - EDGE
			var inside := ix >= 0 and iy >= 0 and ix < w * PX and iy < h * PX
			var rim := float(mini(mini(x, y), mini(iw - 1 - x, ih - 1 - y)))    # how far in from the outer edge
			var deep := float(mini(mini(ix, iy), mini(w * PX - 1 - ix, h * PX - 1 - iy)))   # ... and from the inner one
			var col: Color
			match look:
				"drawer":
					# Seen from above: the four sides, and the thin bottom board a long way down between them.
					if not inside:
						var v := 0.62 + (0.16 if rim < 1.5 else 0.0) - (0.2 if rim > EDGE - 2.5 else 0.0)
						if y >= ih - EDGE:
							v += 0.1                                     # the front: its top edge catches the light
						v += (_hash(x / 9, y) - 0.5) * 0.08
						col = _shade(wood, v, x, y)
						if y >= ih - 3 and absi(x - iw / 2) < 9:
							col = _shade(steel, 0.8 if y == ih - 3 else 0.5, x, y)      # its handle, from above
					else:
						var v2 := 0.74 + (_hash(ix / 28, iy) - 0.5) * 0.1 + (_hash(ix, iy / 2) - 0.5) * 0.05
						if iy % 32 == 31:
							v2 -= 0.14                                   # where two boards of the bottom meet
						v2 -= 0.3 * clampf(1.0 - float(iy) / 7.0, 0.0, 1.0)          # the back's shadow
						v2 -= 0.2 * clampf(1.0 - float(ix) / 5.0, 0.0, 1.0)          # the side's
						v2 -= 0.08 * clampf(1.0 - deep / 3.0, 0.0, 1.0)
						col = _shade(wood, v2, x, y)
				"cupboard", "shelf":
					# Seen from the front: the carcass, a dark back, a shelf across every second row.
					if not inside:
						col = _shade(wood, 0.6 + (0.14 if rim < 1.5 else 0.0) - (0.18 if rim > EDGE - 2.5 else 0.0) + (_hash(x, y / 11) - 0.5) * 0.08, x, y)
					else:
						var row := iy % (PX * 2)
						var board := iy >= PX and row < 3 and iy < h * PX - 2
						var v3 := (0.42 if look == "shelf" else 0.3) + (_hash(ix / 3, iy / 24) - 0.5) * 0.07
						if board:
							v3 = 0.72 if row == 0 else 0.6
						else:
							v3 -= 0.2 * clampf(1.0 - float((row - 3) if iy >= PX else iy) / 8.0, 0.0, 1.0)    # under a shelf
							v3 -= 0.1 * clampf(1.0 - float(mini(ix, w * PX - 1 - ix)) / 5.0, 0.0, 1.0)
						if iy >= h * PX - 2:
							v3 = 0.66                                    # its floor
						col = _shade(wood, v3, x, y)
				"rail":
					# A wardrobe from the front: dark inside, a rail with hooks along the top, a floor.
					if not inside:
						col = _shade(wood, 0.58 + (0.14 if rim < 1.5 else 0.0) - (0.18 if rim > EDGE - 2.5 else 0.0) + (_hash(x, y / 11) - 0.5) * 0.08, x, y)
					else:
						var v4 := 0.26 + (_hash(ix / 3, iy / 30) - 0.5) * 0.06 - 0.12 * clampf(1.0 - float(iy) / 10.0, 0.0, 1.0)
						v4 += 0.1 * clampf(float(iy) / float(h * PX), 0.0, 1.0)
						col = _shade(wood, v4, x, y)
						if iy == 5 or iy == 6:
							col = _shade(steel, 0.8 if iy == 5 else 0.5, x, y)
						elif iy > 6 and iy < 12 and ix % 12 == 6:
							col = _shade(steel, 0.6, x, y)                 # a hanger's hook
						elif iy >= 12 and iy < 15 and absi(ix % 12 - 6) == iy - 11:
							col = _shade(steel, 0.55, x, y)                # ... and its shoulders
						if iy >= h * PX - 2:
							col = _shade(wood, 0.62, x, y)
				"fridge", "freezer":
					if not inside:
						col = _shade(enamel, 0.5 + (0.3 if rim < 1.5 else 0.0) - (0.2 if rim > EDGE - 2.5 else 0.0), x, y)
					else:
						var v5 := 0.86 - 0.16 * clampf(1.0 - float(mini(ix, w * PX - 1 - ix)) / 9.0, 0.0, 1.0) \
							- 0.1 * clampf(1.0 - float(iy) / 6.0, 0.0, 1.0)
						col = _shade(enamel, v5, x, y)
						if look == "freezer":
							# Frost: pale and blue-white, thick in the corners.
							var frost := _hash(ix / 2, iy / 2) * 0.6 + 0.5 * clampf(1.0 - deep / 10.0, 0.0, 1.0)
							col = _shade(enamel, v5 + 0.1, x, y).lerp(Color("cfe4ee"), 0.5 if frost > 0.55 else 0.15)
						else:
							var row2 := iy % (PX * 2)
							if iy >= PX and row2 == 0:
								col = _shade(steel, 0.78, x, y)            # a wire shelf, edge on
							elif iy >= PX and row2 == 1 and ix % 4 == 0:
								col = _shade(steel, 0.5, x, y)
							elif iy >= PX and row2 > 1 and row2 < 5:
								col = _shade(enamel, v5 - 0.1, x, y)       # and its shadow
							if iy < 2 and ix > w * PX / 2 - 10 and ix < w * PX / 2 + 10:
								col = Color("f4e8a8")                      # the lamp
				_:
					# The inside of a bag: canvas, a stitched seam, a zip along its mouth.
					if not inside:
						col = _shade(canvas, 0.6 + (0.14 if rim < 1.5 else 0.0) - (0.16 if rim > EDGE - 2.5 else 0.0), x, y)
						if y < EDGE and rim >= 2.0 and rim < 4.0 and x % 3 == 0:
							col = _shade(steel, 0.75, x, y)                # zip teeth
					else:
						var v6 := 0.34 + (0.05 if (ix + iy) % 2 == 0 else 0.0) + (_hash(ix / 5, iy / 5) - 0.5) * 0.06
						v6 -= 0.14 * clampf(1.0 - deep / 6.0, 0.0, 1.0)
						if deep == 3.0 and (ix + iy) % 4 < 2:
							v6 += 0.22                                   # the seam's stitches
						col = _shade(canvas, v6, x, y)
			img.set_pixel(x, y, col)
	return img
