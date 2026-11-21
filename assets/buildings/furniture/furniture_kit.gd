class_name FurnitureKit
extends RefCounted
## Furniture for the house kit: one plain, sturdy household style, eleven pieces. Each is a few boxes joined
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
##   dresser             low cover; drawers to search, when there is loot
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
}
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


## The mesh of a piece, facing south, its middle on the floor at the origin. `length`: a counter's.
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
	var m := st.commit()
	_meshes[key] = m
	return m


# ---------------------------------------------------------------- putting them down
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
	var body := Solid.box(level, at + Vector3(0.0, h * 0.5, 0.0), size, Color(0.5, 0.4, 0.3), k["stuff"], k["what"],
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
	if kind == "stove" and wear < 2:
		# A stove is a fire (campfire.gd): cold as it stands; with wood on it and a match to it, water boils
		# on it. Its door glows while it burns.
		fire = Campfire.new()
		fire.kept = false
		fire.lit = false
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, turns * PI * 0.5)
		fire.position = front * (d * 0.5 + 0.35)
		body.add_child(fire)
		fire.changed.connect(func(now: bool) -> void: look.material_override = FurnitureKit.mat(wood, cloth, br.stage, now, pin))
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
## front door, a kitchen in the east room, a dresser in the back room; upstairs, if there is one, two
## bedrooms. `origin` is the house's own. Nothing is put in a basement, and other sizes of house are left
## empty (put the pieces down yourself).
static func furnish(in_level: Node, origin: Vector3, storeys := 1, worn := 0, wood := 1, cloth := 0,
		pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> FurnitureKit:
	var f := FurnitureKit.new(in_level, worn, wood, cloth)
	f.season = pin
	var o := origin
	# The living room: x 0..6, z 3..6. The front door is in the south wall at x 4.5; the stairs come down
	# into its north-west corner.
	f.put("couch", o + Vector3(1.5, 0, 5.4), "N")
	f.put("armchair", o + Vector3(5.43, 0, 3.55), "S")
	f.put("bookshelf", o + Vector3(3.46, 0, 3.28), "S")
	# The back room: x 3..6, z 0..3.
	f.put("dresser", o + Vector3(4.5, 0, 0.38), "S")
	# The kitchen: x 6..9, z 0..6, its doorway in the west wall at z 4.5.
	f.counter(Vector2(o.x + 6.2, o.z + 0.46), Vector2(o.x + 7.9, o.z + 0.46), o.y, "S")
	f.put("stove", o + Vector3(8.42, 0, 0.46), "S")
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
