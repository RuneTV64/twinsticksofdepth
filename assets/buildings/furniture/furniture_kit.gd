class_name FurnitureKit
extends RefCounted
## Furniture for the house kit: one plain, sturdy household style, seventeen pieces. Each is a few boxes joined
## into one mesh and painted by furniture.gdshader, standing on a floor, facing north, east, south or west.
##
## What each is for (every object has to do something to the player):
##   couch, armchair     low cover you can crouch behind and vault; wood and cloth when broken up
##   table, chair        low cover (a table hides you crouched); wood
##   counter             low cover along a kitchen wall; cupboards to search, when there is loot
##   stove               a cast-iron wood stove: lay wood on it, light it, and water boils on it (campfire.gd)
##   fridge              high cover: it stops sight; steel and plastic
##   bed                 low cover; cloth and wood; somewhere to sleep, when there is sleep
##   wardrobe, bookshelf high cover: they stop sight, and a zombie has to beat them down or go round
##   dresser             low cover; drawers to search
## The living room's (owner, 21 Nov 2026: the first theme, a middle-class living room, its second session):
##   coffee table        low cover you can get down behind and vault; a shelf underneath to search
##   side table          a drawer to search beside a couch or a chair
##   TV cabinet          low cover; a cabinet to search (the television on it comes with the appliances)
##   display cabinet     high cover; glass shelves and a cupboard to search; smashed, it is broken glass
##   fireplace           brick, and nearly as hard to break as a wall: a fire you lay wood on and light, that
##                       boils water and lights the room (campfire.gd)
##   piano               heavy cover; played, it is heard right across the neighbourhood: a lure (piano.gd)
## And, not pieces of furniture but put down with them: a rug (rug.gd: you walk quieter on it; roll it up and
## lay it where you like) and curtains at a window (window_curtains.gd: drawn, nobody sees in or out).
## Everything goes through Solid (solid.gd), so it is made of something and can be broken like the rest of
## the world; zombies climb the low pieces and beat on the tall ones. `LATER` says what each is meant to do
## once the systems it waits for exist (loot, sleep).
##
## How a piece looks comes from the same three things as the house: how worn it is (`wear` 0, 1, 2: the
## three stages of damage; a piece put down worn starts that much weaker), the season (indoors only the damp
## gets at it, and only once it is worn), and the cutaway (furniture stands while you are indoors, as stairs
## do).
##
##   var f := FurnitureKit.new(level, 0)                       # wear 0..2; then stain and fabric if you like
##   f.put("couch", Vector3(19.5, 0, -28.6), "N")             # where its middle stands on the floor; its front
##   f.counter(Vector2(24.2, -33.55), Vector2(25.9, -33.55), 0.0, "S")
## or a whole ordinary house:  FurnitureKit.furnish(level, house_origin, 2)

## w, h, d: its size, facing south (h is what you walk into and take cover behind). stuff / parts: what it
## is made of. thin: its strength as a share of a solid block of that. what: what the prompt calls it.
const KINDS := {
	"couch": {"w": 2.0, "h": 0.85, "d": 0.9, "stuff": "wood", "parts": {"wood": 0.5, "cloth": 0.5}, "thin": 0.5, "what": "couch"},
	"armchair": {"w": 0.9, "h": 0.85, "d": 0.85, "stuff": "wood", "parts": {"wood": 0.5, "cloth": 0.5}, "thin": 0.5, "what": "armchair"},
	"table": {"w": 1.5, "h": 0.78, "d": 0.9, "stuff": "wood", "parts": {}, "thin": 0.4, "what": "table"},
	"chair": {"w": 0.45, "h": 0.9, "d": 0.45, "stuff": "wood", "parts": {}, "thin": 0.3, "what": "chair"},
	"counter": {"w": 1.5, "h": 0.9, "d": 0.6, "stuff": "wood", "parts": {}, "thin": 0.5, "what": "kitchen counter"},
	"stove": {"w": 0.8, "h": 0.9, "d": 0.6, "stuff": "metal", "parts": {}, "thin": 1.0, "what": "stove"},
	"fridge": {"w": 0.7, "h": 1.8, "d": 0.7, "stuff": "metal", "parts": {"metal": 0.6, "plastic": 0.4}, "thin": 0.3, "what": "fridge"},
	"bed": {"w": 1.5, "h": 0.8, "d": 2.0, "stuff": "wood", "parts": {"wood": 0.4, "cloth": 0.6}, "thin": 0.5, "what": "bed"},
	"wardrobe": {"w": 1.1, "h": 1.9, "d": 0.55, "stuff": "wood", "parts": {}, "thin": 0.5, "what": "wardrobe"},
	"dresser": {"w": 1.0, "h": 0.85, "d": 0.45, "stuff": "wood", "parts": {}, "thin": 0.5, "what": "dresser"},
	"bookshelf": {"w": 0.8125, "h": 1.9, "d": 0.35, "stuff": "wood", "parts": {}, "thin": 0.5, "what": "bookshelf"},
	"coffee_table": {"w": 1.1, "h": 0.45, "d": 0.55, "stuff": "wood", "parts": {}, "thin": 0.35, "what": "coffee table"},
	"end_table": {"w": 0.5, "h": 0.6, "d": 0.45, "stuff": "wood", "parts": {}, "thin": 0.6, "what": "side table"},
	"tv_stand": {"w": 1.1, "h": 0.55, "d": 0.45, "stuff": "wood", "parts": {}, "thin": 0.4, "what": "TV cabinet"},
	"display_cabinet": {"w": 0.9, "h": 1.85, "d": 0.42, "stuff": "wood", "parts": {"wood": 0.75, "glass": 0.25}, "thin": 0.45, "what": "display cabinet"},
	"fireplace": {"w": 1.4, "h": 1.15, "d": 0.45, "stuff": "brick", "parts": {"brick": 0.92, "metal": 0.08}, "thin": 1.0, "what": "fireplace"},
	"piano": {"w": 1.4, "h": 1.25, "d": 0.6, "stuff": "wood", "parts": {"wood": 0.75, "metal": 0.25}, "thin": 0.8, "what": "piano"},
	# The kitchen (22 Nov 2026: the second theme's furniture). `lift`: it hangs this high off the floor.
	"sink": {"w": 0.9, "h": 0.9, "d": 0.6, "stuff": "wood", "parts": {"wood": 0.7, "metal": 0.3}, "thin": 0.5, "what": "kitchen sink"},
	"pantry": {"w": 0.8, "h": 2.0, "d": 0.5, "stuff": "wood", "parts": {}, "thin": 0.5, "what": "pantry cupboard"},
	"wall_cabinet": {"w": 0.8, "h": 0.7, "d": 0.33, "stuff": "wood", "parts": {}, "thin": 0.5, "what": "wall cupboard", "lift": 1.45},
	"kitchen_bin": {"w": 0.36, "h": 0.65, "d": 0.36, "stuff": "plastic", "parts": {"plastic": 0.7, "metal": 0.3}, "thin": 0.5, "what": "kitchen bin"},
}
## What each will do when the system it waits for exists. Nothing here is built.
const LATER := {
	"couch": "sitting to rest; loose change and worse down the back of it",
	"armchair": "sitting to rest",
	"table": "a surface things are left on",
	"chair": "sitting; something to wedge under a door handle",
	"counter": "(its drawer and cupboard are searched now: stash.gd)",
	"stove": "cooking; warmth and light from it",
	"fridge": "what the food in it has turned into (it is searched now: stash.gd)",
	"bed": "sleep; something under the mattress",
	"wardrobe": "clothes to find in it (it is searched now: stash.gd)",
	"dresser": "(its drawers are searched now: stash.gd)",
	"bookshelf": "books: skills to read up on (its shelves are searched now: stash.gd)",
	"coffee_table": "a surface things are left on",
	"end_table": "(a lamp stands on it: appliance.gd)",
	"tv_stand": "(the television stands on it: appliance.gd)",
	"display_cabinet": "the good china, and whatever else was kept for best",
	"fireplace": "warmth, when there is a warmth need; cooking",
	"piano": "",
	"sink": "(its tap runs while the mains do: water.gd; a cupboard under it)",
	"pantry": "(shelves of food and the odds and ends kept with it)",
	"wall_cabinet": "(plates and glasses)",
	"kitchen_bin": "(what was thrown away: there is a use for all of it)",
}
## How far a fire in a fireplace lights the room round it (m).
const FIRE_LIGHT := 5.0
## A piece put down worn starts with this share of its strength.
const WEAR_HP := [1.0, 0.6, 0.3]
const TURN := {"S": 0, "E": 1, "N": 2, "W": 3}       # quarter turns from facing south
# The parts a face can play (furniture.gdshader).
const WOOD := 0
const DRAWERS := 1
const DOORS := 2
const SHELVES := 3
const FABRIC := 4
const SHEET := 5
const BLANKET := 6
const PILLOW := 7
const IRON := 8
const IRON_FRONT := 9
const IRON_TOP := 10
const ENAMEL := 11
const FRIDGE_FRONT := 12
const WORKTOP := 13
const CUPBOARDS := 14
const GLASS_DOORS := 15         # glass doors on shelves of china
const BRICK := 16
const FIRE_FRONT := 17          # a fireplace's front: brick round the firebox, and the fire when it is lit
const LACQUER := 18             # a piano's case
const KEYS := 19                # a piano's keyboard, seen from above
const RUG := 20
const CURTAIN := 21
const TV_FRONT := 22            # a television's front: the screen in its bezel, the knobs; lit when it is on
const PLASTIC := 23             # dark plastic: a television's or a radio's case
const SHADE := 24               # a lamp shade: pleated linen, glowing when the lamp is on
const RADIO_FRONT := 25         # a radio's front: the speaker grille and the dial
const BEIGE := 26               # old beige plastic: a phone, a lamp's base
const KEYPAD := 27              # a phone from above: the handset's cradle and the buttons
const BRASS := 28               # a lamp's brass stem and foot
const SINK_TOP := 29            # a worktop with a steel basin let into it, and the tap
const STEEL := 30               # brushed steel: a pedal bin
const TALL_DOORS := 31          # a pantry's tall pair of doors

## Test harnesses on the software renderer set this: the shader then puts out its palette colours directly.
static var raw_colors := false
static var _shader: Shader
static var _mats := {}
static var _meshes := {}

var level: Node
var wear := 0                   # 0 sound, 1 damaged, 2 about to give: how the furniture is when put down
var stain := 1                  # the wood: 0 pine, 1 oak, 2 walnut
var fabric := 0                 # the cloth: 0 brick red, 1 olive, 2 blue
var season := Vector4(-1.0, 0.0, 0.0, 0.0)     # x >= 0 pins its weather (for review sheets)
var parts: Array[Breakable] = []


func _init(in_level: Node, worn := 0, wood := 1, cloth := 0) -> void:
	level = in_level
	wear = worn
	stain = wood
	fabric = cloth


static func reset() -> void:
	_mats.clear()


## One shared material for each wood, cloth, stage of wear and weather.
static func mat(wood: int, cloth: int, stage: int, burning := false, pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> ShaderMaterial:
	var key := "%d|%d|%d|%s|%s" % [wood, cloth, stage, burning, pin]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		var path := "res://assets/buildings/furniture/furniture.gdshader"
		if raw_colors:
			_shader = Shader.new()
			_shader.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;") \
				.replace("EMISSION=pow(c,vec3(2.2)) * 1.4;", "EMISSION=c * 0.8;")
		else:
			_shader = load(path)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("stain", wood)
	m.set_shader_parameter("fabric", cloth)
	m.set_shader_parameter("burning", burning)
	m.set_shader_parameter("wear", float(stage))
	m.set_shader_parameter("season_override", pin)
	_mats[key] = m
	return m


# ---------------------------------------------------------------- the pieces, as boxes
## One box of a piece: its middle and size (facing south, the floor at y 0), the part its faces play, and
## other parts for its front (+z) and its top if they differ. `n` numbers the box, so no two wear alike.
static func _box(st: SurfaceTool, at: Array, c: Vector3, s: Vector3, role: int, front := -1, top := -1) -> void:
	var n: int = at[0]
	at[0] = n + 1
	var h := s * 0.5
	# normal, right, up, half width, half height, the part
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), h.x, h.y, h.z, front if front >= 0 else role],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), h.x, h.y, h.z, role],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), h.z, h.y, h.x, role],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), h.z, h.y, h.x, role],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), h.x, h.z, h.y, top if top >= 0 else role],
	]
	for i in faces.size():
		var f: Array = faces[i]
		var nrm: Vector3 = f[0]
		var r: Vector3 = f[1]
		var u: Vector3 = f[2]
		var hw: float = f[3]
		var hh: float = f[4]
		var mid := c + nrm * float(f[5])
		var col := Color(float(f[6]) / 32.0, fmod((n * 5 + i) * 0.137 + 0.05, 1.0), 0.0)
		var base: int = at[1]
		# Clockwise as you look at the face: bottom left, top left, top right, bottom right.
		for corner: Array in [[-1, -1], [-1, 1], [1, 1], [1, -1]]:
			st.set_normal(nrm)
			st.set_uv(Vector2((corner[0] + 1) * hw, (corner[1] + 1) * hh))
			st.set_uv2(Vector2(hw * 2.0, hh * 2.0))
			st.set_color(col)
			st.add_vertex(mid + r * (hw * corner[0]) + u * (hh * corner[1]))
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.add_index(base + k)
		at[1] = base + 4


## The mesh of a piece, facing south, its middle on the floor at the origin. `length`: a counter's (a rug's
## width, a curtain panel's width: their own sizes are worked out by rug.gd and window_curtains.gd).
const KINDS_RUG_D := 1.0       # a rug's mesh is 1 m deep: rug.gd scales it to its own depth
static func mesh_of(kind: String, length := 0.0) -> ArrayMesh:
	var key := "%s|%.3f" % [kind, length]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := [0, 0]
	match kind:
		"couch", "armchair":
			var w: float = KINDS[kind]["w"]
			var d: float = KINDS[kind]["d"]
			_box(st, at, Vector3(0, 0.21, 0.02), Vector3(w, 0.42, d - 0.04), FABRIC)                      # the seat
			_box(st, at, Vector3(0, 0.63, -d * 0.5 + 0.12), Vector3(w - 0.3, 0.44, 0.24), FABRIC)         # the back
			for sx: float in [-1.0, 1.0]:
				_box(st, at, Vector3(sx * (w * 0.5 - 0.09), 0.5, 0.0), Vector3(0.18, 0.24, d), FABRIC)   # the arms
		"table":
			_box(st, at, Vector3(0, 0.75, 0), Vector3(1.5, 0.0625, 0.9), WOOD)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_box(st, at, Vector3(sx * 0.66, 0.36, sz * 0.37), Vector3(0.09, 0.72, 0.09), WOOD)
		"chair":
			_box(st, at, Vector3(0, 0.44, 0), Vector3(0.44, 0.0625, 0.44), WOOD)
			_box(st, at, Vector3(0, 0.7, -0.19), Vector3(0.44, 0.4, 0.0625), WOOD)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_box(st, at, Vector3(sx * 0.18, 0.2, sz * 0.18), Vector3(0.0625, 0.41, 0.0625), WOOD)
		"counter":
			_box(st, at, Vector3(0, 0.42, -0.01), Vector3(length, 0.84, 0.56), WOOD, CUPBOARDS)
			_box(st, at, Vector3(0, 0.87, 0), Vector3(length, 0.0625, 0.6), WORKTOP)
		"stove":
			_box(st, at, Vector3(0, 0.4, 0), Vector3(0.74, 0.8, 0.56), IRON, IRON_FRONT)
			_box(st, at, Vector3(0, 0.84, 0), Vector3(0.8, 0.0625, 0.6), IRON, -1, IRON_TOP)
			_box(st, at, Vector3(0.22, 1.72, -0.19), Vector3(0.14, 1.7, 0.14), IRON)                      # the flue
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_box(st, at, Vector3(sx * 0.31, 0.0, sz * 0.22), Vector3(0.08, 0.02, 0.08), IRON)
		"fridge":
			_box(st, at, Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7), ENAMEL, FRIDGE_FRONT)
		"bed":
			_box(st, at, Vector3(0, 0.15, 0.02), Vector3(1.5, 0.3, 1.94), WOOD)                           # the frame
			_box(st, at, Vector3(0, 0.4, 0.02), Vector3(1.4, 0.2, 1.86), SHEET)                           # the mattress
			_box(st, at, Vector3(0, 0.515, 0.36), Vector3(1.44, 0.0625, 1.18), BLANKET)
			for sx: float in [-1.0, 1.0]:
				_box(st, at, Vector3(sx * 0.36, 0.55, -0.68), Vector3(0.56, 0.1, 0.36), PILLOW)
			_box(st, at, Vector3(0, 0.52, -0.96), Vector3(1.5, 1.04, 0.0625), WOOD, DOORS)                # the headboard
		"wardrobe":
			_box(st, at, Vector3(0, 0.95, 0), Vector3(1.1, 1.9, 0.55), WOOD, DOORS)
		"dresser":
			_box(st, at, Vector3(0, 0.405, 0), Vector3(1.0, 0.81, 0.43), WOOD, DRAWERS)
			_box(st, at, Vector3(0, 0.83, 0), Vector3(1.04, 0.04, 0.47), WOOD)
		"bookshelf":
			_box(st, at, Vector3(0, 0.95, 0), Vector3(0.8125, 1.9, 0.35), WOOD, SHELVES)
		"coffee_table":
			_box(st, at, Vector3(0, 0.43, 0), Vector3(1.1, 0.04, 0.55), WOOD)
			_box(st, at, Vector3(0, 0.12, 0), Vector3(1.0, 0.025, 0.47), WOOD)                            # the shelf
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_box(st, at, Vector3(sx * 0.5, 0.205, sz * 0.22), Vector3(0.05, 0.41, 0.05), WOOD)
		"end_table":
			_box(st, at, Vector3(0, 0.47, 0), Vector3(0.46, 0.2, 0.41), WOOD, DRAWERS)
			_box(st, at, Vector3(0, 0.585, 0), Vector3(0.5, 0.03, 0.45), WOOD)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_box(st, at, Vector3(sx * 0.2, 0.185, sz * 0.17), Vector3(0.04, 0.37, 0.04), WOOD)
		"tv_stand":
			_box(st, at, Vector3(0, 0.265, 0), Vector3(1.1, 0.49, 0.43), WOOD, DOORS)
			_box(st, at, Vector3(0, 0.53, 0), Vector3(1.14, 0.04, 0.47), WOOD)
		"display_cabinet":
			_box(st, at, Vector3(0, 0.42, 0), Vector3(0.9, 0.84, 0.42), WOOD, DOORS)
			_box(st, at, Vector3(0, 1.32, -0.02), Vector3(0.86, 0.96, 0.36), WOOD, GLASS_DOORS)
			_box(st, at, Vector3(0, 1.82, 0), Vector3(0.94, 0.06, 0.44), WOOD)
		"fireplace":
			_box(st, at, Vector3(0, 0.55, -0.02), Vector3(1.4, 1.1, 0.41), BRICK, FIRE_FRONT)
			_box(st, at, Vector3(0, 1.13, 0.0), Vector3(1.56, 0.06, 0.47), WOOD)                         # the mantel
			_box(st, at, Vector3(0, 1.86, -0.08), Vector3(1.1, 1.4, 0.29), BRICK)                         # the chimney breast
			_box(st, at, Vector3(0, 0.02, 0.33), Vector3(1.5, 0.04, 0.3), BRICK)                          # the hearth
		"piano":
			_box(st, at, Vector3(0, 0.625, -0.12), Vector3(1.4, 1.25, 0.36), LACQUER)
			_box(st, at, Vector3(0, 0.74, 0.13), Vector3(1.24, 0.07, 0.24), LACQUER, -1, KEYS)          # the keyboard
			for sx: float in [-1.0, 1.0]:
				_box(st, at, Vector3(sx * 0.66, 0.75, 0.14), Vector3(0.08, 0.16, 0.26), LACQUER)       # its cheeks
				_box(st, at, Vector3(sx * 0.62, 0.35, 0.2), Vector3(0.07, 0.7, 0.07), LACQUER)         # the legs
		"rug":
			_box(st, at, Vector3(0, 0.048, 0), Vector3(length, 0.012, KINDS_RUG_D), WOOD, -1, RUG)   # (on a ground floor's boards, 4 cm up)
		"curtain":
			_box(st, at, Vector3(0, 0, 0), Vector3(length, 1.0, 0.03), CURTAIN)
		"sink":
			_box(st, at, Vector3(0, 0.42, -0.01), Vector3(0.9, 0.84, 0.56), WOOD, CUPBOARDS)
			_box(st, at, Vector3(0, 0.87, 0), Vector3(0.9, 0.0625, 0.6), WORKTOP, -1, SINK_TOP)
			_box(st, at, Vector3(0, 1.0, -0.24), Vector3(0.04, 0.2, 0.04), STEEL)                          # the tap
		"pantry":
			_box(st, at, Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.5), WOOD, TALL_DOORS)
		"wall_cabinet":
			_box(st, at, Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.33), WOOD, CUPBOARDS)
		"kitchen_bin":
			_box(st, at, Vector3(0, 0.3, 0), Vector3(0.34, 0.6, 0.34), STEEL)
			_box(st, at, Vector3(0, 0.625, 0), Vector3(0.36, 0.05, 0.36), STEEL)                         # the lid
			_box(st, at, Vector3(0, 0.03, 0.2), Vector3(0.14, 0.03, 0.06), PLASTIC)                       # the pedal
		# ---- appliances (appliance.gd: their sizes, what they do)
		"television":
			_box(st, at, Vector3(0, 0.24, 0.07), Vector3(0.56, 0.48, 0.42), PLASTIC, TV_FRONT)
			_box(st, at, Vector3(0, 0.22, -0.21), Vector3(0.36, 0.34, 0.14), PLASTIC)                     # the tube's back
		"floor_lamp":
			_box(st, at, Vector3(0, 0.02, 0), Vector3(0.28, 0.04, 0.28), BRASS)
			_box(st, at, Vector3(0, 0.66, 0), Vector3(0.04, 1.26, 0.04), BRASS)
			_box(st, at, Vector3(0, 1.45, 0), Vector3(0.4, 0.32, 0.4), SHADE)
		"table_lamp":
			_box(st, at, Vector3(0, 0.11, 0), Vector3(0.15, 0.22, 0.15), BEIGE)
			_box(st, at, Vector3(0, 0.27, 0), Vector3(0.03, 0.12, 0.03), BRASS)
			_box(st, at, Vector3(0, 0.43, 0), Vector3(0.3, 0.24, 0.3), SHADE)
		"radio":
			_box(st, at, Vector3(0, 0.1, 0), Vector3(0.36, 0.2, 0.12), PLASTIC, RADIO_FRONT)
			_box(st, at, Vector3(0, 0.21, 0), Vector3(0.26, 0.02, 0.04), PLASTIC)                         # the handle
		"candle":
			_box(st, at, Vector3(0, 0.008, 0), Vector3(0.09, 0.016, 0.09), BRASS)                        # its dish
			_box(st, at, Vector3(0, 0.08, 0), Vector3(0.045, 0.13, 0.045), BEIGE)                         # the wax
			_box(st, at, Vector3(0, 0.155, 0), Vector3(0.02, 0.03, 0.02), SHADE)                          # the flame
		"toy_robot":
			for sx: float in [-1.0, 1.0]:
				_box(st, at, Vector3(sx * 0.035, 0.035, 0), Vector3(0.04, 0.07, 0.05), PLASTIC)          # legs
			_box(st, at, Vector3(0, 0.115, 0), Vector3(0.12, 0.09, 0.09), BRASS, RADIO_FRONT)           # tin body
			_box(st, at, Vector3(0, 0.19, 0), Vector3(0.08, 0.06, 0.07), BEIGE)                           # head
		"telephone":
			_box(st, at, Vector3(0, 0.04, 0), Vector3(0.22, 0.08, 0.2), BEIGE, -1, KEYPAD)
			_box(st, at, Vector3(0, 0.095, -0.04), Vector3(0.22, 0.03, 0.07), BEIGE)                      # the handset
	var m := st.commit()
	_meshes[key] = m
	return m


# ---------------------------------------------------------------- putting them down
## A rug on the floor (rug.gd), in this kit's fabric and wear.
func rug(at: Vector3, size: Vector2, turns := 0) -> Rug:
	return Rug.lay(level, at, size, turns, fabric, wear)


## Curtains at the window nearest `near` (on its storey), hung on the side toward `inside`. Drawn unless the
## house is worn out (somebody left them open, or took them). Null if there is no window there.
func curtains(near: Vector3, inside: Vector3) -> WindowCurtains:
	var best := {}
	var best_d := 0.9
	for w in Solid.windows:
		var wp: Vector3 = w["pos"]
		if absf(wp.y - near.y) > 1.0:
			continue
		var dd := Vector2(wp.x - near.x, wp.z - near.z).length()
		if dd < best_d:
			best_d = dd
			best = w
	if best.is_empty() or wear >= 2:
		return null
	return WindowCurtains.hang(level, best, inside, fabric, true, near.y - 1.4)

## An appliance (appliance.gd) in this kit's wear and colours: `at` where its middle stands (y the surface: a
## floor, or the top of `on` if it stands on a piece), switched off (somebody left). If the piece under it
## breaks, it falls to the floor.
func appliance(kind: String, at: Vector3, facing := "S", on: Breakable = null) -> Appliance:
	var floor_at := on.floor_y if on != null else at.y
	var a := Appliance.put(level, kind, at, facing, wear, false, floor_at, {}, stain, fabric)
	if on != null:
		on.broke.connect(func(_by: Node) -> void:
			if is_instance_valid(a):
				a.fall_to(floor_at))
	return a


## Things left lying somewhere (an ItemPickup): on a floor, on a mantel. `ids` are items as found.
func lying(title: String, ids: Array, at: Vector3) -> ItemPickup:
	var p := ItemPickup.new()
	p.title = title
	p.small = true
	p.tint = Color(0.55, 0.5, 0.42)
	for id: String in ids:
		p.contents.append(Stash.found_item(id))
	p.position = at
	level.add_child(p)
	return p


## Put a piece down: `at` is where its middle stands (y is the floor's height), `facing` ("N", "E", "S",
## "W") the way its front looks. Returns its Breakable (null for a kind there isn't).
func put(kind: String, at: Vector3, facing := "S") -> Breakable:
	if not KINDS.has(kind) or kind == "counter":
		return null
	var k: Dictionary = KINDS[kind]
	return _piece(kind, at, facing, float(k["w"]), mesh_of(kind))


## A kitchen counter along a wall, from `a` to `b` (x, z: its middle line), on the floor at height `floor_y`.
func counter(a: Vector2, b: Vector2, floor_y := 0.0, facing := "S") -> Breakable:
	var length := snappedf(a.distance_to(b), 0.0625)
	var mid := (a + b) * 0.5
	return _piece("counter", Vector3(mid.x, floor_y, mid.y), facing, length, mesh_of("counter", length))


func _piece(kind: String, at: Vector3, facing: String, width: float, mesh: ArrayMesh) -> Breakable:
	var k: Dictionary = KINDS[kind]
	var turns: int = TURN.get(facing, 0)
	var h: float = k["h"]
	var d: float = k["d"]
	var size := Vector3(width, h, d) if turns % 2 == 0 else Vector3(d, h, width)
	var lift := float(k.get("lift", 0.0))
	var body := Solid.box(level, at + Vector3(0.0, lift + h * 0.5, 0.0), size, Color(0.5, 0.4, 0.3), k["stuff"], k["what"],
		k["parts"], 0.0, Callable(), at.y)
	body.set_meta("furniture", kind)
	# Solid's own plain box is the thing you walk into; what you see is the piece's mesh.
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var burning := false                        # a stove is cold until someone lays wood on it and lights it
	var look := MeshInstance3D.new()
	look.mesh = mesh
	look.position = Vector3(0.0, -h * 0.5, 0.0)
	look.rotation.y = turns * PI * 0.5
	var wood := stain
	var cloth := fabric
	var pin := season
	look.material_override = mat(wood, cloth, wear, burning, pin)
	body.add_child(look)
	var br := Breakable.of(body)
	br.splitter = Callable()                    # a piece of furniture breaks whole
	br.thin_to(float(k["thin"]))
	br.hp = br.max_hp * float(WEAR_HP[wear])
	br.stage = wear
	var fire: Campfire = null
	br.on_stage = func(stage: int) -> void:
		look.material_override = FurnitureKit.mat(wood, cloth, stage, fire != null and is_instance_valid(fire) and fire.lit, pin)
	if (kind == "stove" or kind == "fireplace") and wear < 2:
		# A stove is a fire (campfire.gd): cold as it stands; with wood on it and a match to it, water boils
		# on it. Its door glows while it burns.
		fire = Campfire.new()
		fire.kept = false
		fire.lit = false
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, turns * PI * 0.5)
		fire.position = front * (d * 0.5 + 0.35) + (Vector3.DOWN * (h * 0.5 - 0.3) if kind == "fireplace" else Vector3.ZERO)
		body.add_child(fire)
		fire.changed.connect(func(now: bool) -> void: look.material_override = FurnitureKit.mat(wood, cloth, br.stage, now, pin))
		if kind == "fireplace":
			# A fire in the grate lights the room (daylight.gd: you are seen in it, and see by it) with a warm,
			# low light; it goes out with the fire, or if the fireplace is broken.
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.62, 0.32)
			glow.omni_range = 5.0
			glow.light_energy = 1.4
			glow.visible = false
			fire.add_child(glow)
			fire.changed.connect(func(now: bool) -> void:
				glow.visible = now
				if now:
					Daylight.add_lamp(fire.global_position, FIRE_LIGHT)
				else:
					Daylight.remove_lamp(fire.global_position))
			br.broke.connect(func(_by: Node) -> void:
				if is_instance_valid(fire) and fire.lit:
					Daylight.remove_lamp(fire.global_position))
	if kind == "sink" and wear < 2:
		# The tap (water_source.gd): it runs while the mains do; a worn-out house's has long since run dry.
		var tap := WaterSource.new()
		tap.kind = "tap"
		tap.mains = true
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, turns * PI * 0.5)
		tap.position = front * (d * 0.5 + 0.3) + Vector3.UP * 0.4
		body.add_child(tap)
	if kind == "piano":
		var keys := Piano.new()
		var face := Vector3(0, 0, 1).rotated(Vector3.UP, turns * PI * 0.5)
		keys.position = face * (d * 0.5 + 0.3) + Vector3.DOWN * (h * 0.5 - 0.75)
		keys.worn = wear
		body.add_child(keys)
	# Somewhere things are kept (stash.gd): searched by interacting with it; what is in it spills if it breaks.
	var stash := Stash.for_piece(kind, str(k["what"]), wood, wear)
	if stash != null:
		var face := Vector3(0, 0, 1).rotated(Vector3.UP, turns * PI * 0.5)
		stash.position = face * (d * 0.5 + 0.35)
		body.add_child(stash)
		br.broke.connect(func(_by: Node) -> void:
			if is_instance_valid(stash):
				stash.spill())
	parts.append(br)
	return br


## Furnish an ordinary house as HouseKit.house() builds it, 3 cells wide and 2 deep: a living room inside the
## front door (with a fireplace, a hearth rug and curtains at its windows), a den in the back room (a piano, the
## TV cabinet), a kitchen in the east room; upstairs, if there is one, two bedrooms. `origin` is the house's own.
## Nothing is put in a basement, and other sizes of house are left empty (put the pieces down yourself).
static func furnish(in_level: Node, origin: Vector3, storeys := 1, worn := 0, wood := 1, cloth := 0,
		pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> FurnitureKit:
	var f := FurnitureKit.new(in_level, worn, wood, cloth)
	f.season = pin
	var o := origin
	# The living room: x 0..6, z 3..6. The front door is in the south wall at x 4.5, with a window west of it;
	# a window in the west wall; the stairs come down into its north-west corner; doorways north (the den) and
	# east (the kitchen). Round the fireplace.
	f.put("fireplace", o + Vector3(3.0, 0, 5.775), "N")
	f.rug(o + Vector3(3.0, 0, 4.75), Vector2(1.8, 1.0), 0)
	f.put("couch", o + Vector3(0.5, 0, 4.6), "E")
	var coffee := f.put("coffee_table", o + Vector3(1.65, 0, 4.6), "E")
	var side := f.put("end_table", o + Vector3(0.35, 0, 5.8), "E")
	f.put("armchair", o + Vector3(3.0, 0, 4.0), "S")
	# Its appliances (appliance.gd): a lamp on the side table and one standing in the corner by the door, the
	# radio on the coffee table.
	f.appliance("table_lamp", o + Vector3(0.35, 0.6, 5.8), "E", side)
	f.appliance("floor_lamp", o + Vector3(5.7, 0, 5.68), "N")
	f.appliance("radio", o + Vector3(1.65, 0.45, 4.42), "E", coffee)
	f.appliance("candle", o + Vector3(1.6, 0.45, 4.82), "E", coffee)
	# Its odds and ends (items.gd: the misc session). The fire irons by the fireplace, a trophy on the mantel;
	# books, magazines, records, the remote, toys turn up searching its furniture (the living room's things).
	f.lying("By the fireplace", ["fire_poker"], o + Vector3(3.9, 0, 5.62))
	f.lying("On the mantelpiece", ["trophy", "candle"], o + Vector3(3.45, 1.16, 5.85))
	f.put("bookshelf", o + Vector3(3.46, 0, 3.28), "S")
	f.put("display_cabinet", o + Vector3(5.55, 0, 3.25), "S")
	f.curtains(o + Vector3(1.5, 1.4, 6.0), o + Vector3(1.5, 1.4, 5.0))
	f.curtains(o + Vector3(0.0, 1.4, 4.5), o + Vector3(1.0, 1.4, 4.5))
	# The den (the back room): x 3..6, z 0..3, a window in its north wall at x 4.5.
	f.put("piano", o + Vector3(4.5, 0, 0.33), "S")
	var stand := f.put("tv_stand", o + Vector3(5.75, 0, 0.95), "W")
	var dresser := f.put("dresser", o + Vector3(5.77, 0, 2.3), "W")
	f.appliance("television", o + Vector3(5.72, 0.55, 0.95), "W", stand)
	f.appliance("telephone", o + Vector3(5.77, 0.85, 2.48), "W", dresser)
	f.rug(o + Vector3(4.4, 0, 1.75), Vector2(1.8, 1.2), 0)
	f.curtains(o + Vector3(4.5, 1.4, 0.0), o + Vector3(4.5, 1.4, 1.0))
	# The kitchen: x 6..9, z 0..6, its doorway in the west wall at z 4.5.
	f.counter(Vector2(o.x + 6.2, o.z + 0.46), Vector2(o.x + 7.0, o.z + 0.46), o.y, "S")
	f.put("sink", o + Vector3(7.45, 0, 0.46), "S")                 # under the north window
	f.put("stove", o + Vector3(8.42, 0, 0.46), "S")
	f.put("wall_cabinet", o + Vector3(6.6, 0, 0.33), "S")           # over the counter
	f.put("pantry", o + Vector3(8.6, 0, 5.72), "N")
	f.put("kitchen_bin", o + Vector3(6.3, 0, 5.7), "E")
	f.put("fridge", o + Vector3(6.46, 0, 1.62), "E")
	f.put("table", o + Vector3(7.75, 0, 3.0), "E")
	f.put("chair", o + Vector3(6.98, 0, 3.0), "E")
	f.put("chair", o + Vector3(8.5, 0, 3.0), "W")
	if storeys > 1:
		var up := o + Vector3(0, HouseKit.STOREY, 0)
		# The big bedroom over the kitchen.
		f.put("bed", up + Vector3(7.5, 0, 1.2), "S")
		f.put("wardrobe", up + Vector3(6.4, 0, 3.0), "E")
		f.put("dresser", up + Vector3(7.5, 0, 5.6), "N")
		# The second, over the living room (the stairs come up into its north-west corner).
		f.put("bed", up + Vector3(3.35, 0, 4.82), "N")
		f.put("bookshelf", up + Vector3(3.46, 0, 3.28), "S")
		f.put("chair", up + Vector3(0.6, 0, 5.5), "E")
		# Over the back room.
		f.put("dresser", up + Vector3(4.5, 0, 0.38), "S")
	return f
