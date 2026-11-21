class_name StreetKit
extends RefCounted
## Streets, laid as flat 9 m tiles on a grid: a 6 m carriageway with a kerb and a 1.5 m sidewalk each side (so a
## tile is three of the house kit's cells wide). You say which grid cells are street; each tile works out for
## itself which of its neighbours it joins, and so whether it is a straight, a bend, a T, a crossroads or a dead
## end. One shader (street.gdshader) draws all of them.
##
## What a street does (every object has to do something to the player):
##   - It is firm in all weather. No mud, so nothing slows you, and no prints, so nothing follows your trail:
##     except in lying snow, where a street shows your tracks like anywhere else.
##   - It is open. There is no cover on it, and you are seen on it from as far as anywhere.
##   - It is pavement: broken up a square metre at a time with a sledgehammer, it gives rock, and leaves a
##     hole down to the stone bed. A worn street breaks up sooner.
##   - Water stands in its gutters and potholes when it rains.
##
## How it looks comes from three things, as with the house: the season and weather (project-wide), how worn
## it is (`wear` 0 sound, 1 cracked, 2 breaking up), and the cutaway.
##
##   var s := StreetKit.new(level, Vector3(-13.5, 0, -94))       # the north-west corner of grid cell (0, 0)
##   s.plan([" # ",
##           "###",
##           " # "])                                               # rows north to south, "#" = street
##   s.open(Vector2i(1, 2), "S")                                   # it carries on south, off the plan
##   s.build()

const TILE := 9.0
const HALF_ROAD := 3.0
const KERB := 0.125
const WALK := 1.5
const FILLET := 1.5
const LIFT := 0.03             # how far above the ground the tiles lie
const N := 1
const E := 2
const S := 4
const W := 8
const SIDES := {"N": N, "E": E, "S": S, "W": W}
const STEP := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}
## A street laid worn has this share of its strength.
const WEAR_HP := [1.0, 0.6, 0.3]
## What stands along it (lamp(), signpost(), furnish()).
const LAMP_H := 3.5                              # a lamp post, to the foot of its lantern
const LAMP_POST := 0.1875
const LANTERN := Vector3(0.4375, 0.5, 0.4375)
const LAMP_LIGHT := 8.0                          # m: how far a lit lamp's light reaches along the ground
const SIGN_H := 2.625
const SIGN_POST := 0.125
## A sign's plate, by its face: the shader's number for it, its width and height, what it is called.
const FACES := {
	"stop": {"id": 0, "w": 0.75, "h": 0.75, "what": "stop sign", "says": "STOP"},
	"name": {"id": 1, "w": 0.875, "h": 0.1875, "what": "street sign", "says": ""},
	"warning": {"id": 2, "w": 0.75, "h": 0.75, "what": "warning sign", "says": "Dead end"},
}

## Test harnesses on the software renderer set this: the shader then puts out its palette colours directly.
static var raw_colors := false
static var _shader: Shader
static var _mats := {}
static var _mesh: PlaneMesh
static var _prop_shader: Shader

var level: Node
var origin := Vector3.ZERO      # the world position of the north-west corner of grid cell (0, 0)
var wear := 0
var season := Vector4(-1.0, 0.0, 0.0, 0.0)     # x >= 0 pins this street's weather (for review sheets)
var cells := {}                 # Vector2i -> extra sides it carries on through (see open())
var tiles := {}                 # Vector2i -> its MeshInstance3D, once built
var parts: Array[Breakable] = []
var lit := true                 # its lamps have power (a stand-in until there is a grid to lose)
var names := {"NS": "Maple Street", "EW": "Cedar Lane"}     # what its name signs say, by the way a street runs
var lamps: Array[Breakable] = []     # each lamp's lantern (break it and the light goes out)
var signs: Array[Breakable] = []     # each sign's post


func _init(in_level: Node, at: Vector3, worn := 0) -> void:
	level = in_level
	# Whole metres, so a tile's 81 square metres are the same ones the breaking code counts in.
	origin = Vector3(roundf(at.x), at.y, roundf(at.z))
	wear = worn


static func reset() -> void:
	_mats.clear()


## One shared material for each shape, stage of wear and weather. (A tile that has been broken into gets
## one of its own.)
static func mat(links: int, stage: int, pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> ShaderMaterial:
	var key := "%d|%d|%s" % [links, stage, pin]
	if _mats.has(key):
		return _mats[key]
	var m := _new_mat(links, stage, pin)
	_mats[key] = m
	return m


static func _new_mat(links: int, stage: int, pin: Vector4) -> ShaderMaterial:
	if _shader == null:
		var path := "res://assets/buildings/street/street.gdshader"
		if raw_colors:
			_shader = Shader.new()
			_shader.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
		else:
			_shader = load(path)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("links", links)
	m.set_shader_parameter("wear", float(stage))
	m.set_shader_parameter("season_override", pin)
	if Ground.it != null and Ground.it.tracks_texture() != null:
		m.set_shader_parameter("track_map", Ground.it.tracks_texture())
		m.set_shader_parameter("track_rect", Ground.it.tracks_rect())
		m.set_shader_parameter("has_tracks", true)
	return m


## Mark grid cells as street.
func add(list: Array) -> void:
	for c: Vector2i in list:
		if not cells.has(c):
			cells[c] = 0


## Mark them from a plan: one string a row, north to south; "#" is street, anything else is not.
func plan(rows: Array) -> void:
	for z in rows.size():
		var row: String = rows[z]
		for x in row.length():
			if row[x] == "#":
				cells[Vector2i(x, z)] = int(cells.get(Vector2i(x, z), 0))


## A straight run of cells from `a` to `b` (along a row or a column).
func line(a: Vector2i, b: Vector2i) -> void:
	var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var c := a
	cells[c] = int(cells.get(c, 0))
	while c != b:
		c += d
		cells[c] = int(cells.get(c, 0))


## This cell's street carries on through that side ("N", "E", "S" or "W") though nothing is laid beyond it:
## the edge of the map, or where it meets a dirt road.
func open(cell: Vector2i, side: String) -> void:
	cells[cell] = int(cells.get(cell, 0)) | int(SIDES[side])


## Which sides a cell's street goes through: toward every neighbour that is street, and any side opened.
func links_of(cell: Vector2i) -> int:
	var l := int(cells.get(cell, 0))
	for side: int in STEP:
		if cells.has(cell + STEP[side]):
			l |= side
	return l


## The middle of a cell, on the ground (x, z).
func mid(cell: Vector2i) -> Vector2:
	return Vector2(origin.x + (cell.x + 0.5) * TILE, origin.z + (cell.y + 0.5) * TILE)


## How far a spot is from the carriageway's edge on a tile with these links: `q` from the tile's middle (x
## east, y south). Under 0 on the carriageway, up to KERB on the kerb, up to WALK on the sidewalk. (The same
## sum as street_d() in street.gdshader: keep them in step.)
static func edge(q: Vector2, links: int) -> float:
	var d := q.length() - HALF_ROAD
	if links & N:
		d = minf(d, _box(q, Vector2(0.0, -2.5), Vector2(HALF_ROAD, 2.5)))
	if links & S:
		d = minf(d, _box(q, Vector2(0.0, 2.5), Vector2(HALF_ROAD, 2.5)))
	if links & E:
		d = minf(d, _box(q, Vector2(2.5, 0.0), Vector2(2.5, HALF_ROAD)))
	if links & W:
		d = minf(d, _box(q, Vector2(-2.5, 0.0), Vector2(2.5, HALF_ROAD)))
	var ax := (links & E) != 0 if q.x > 0.0 else (links & W) != 0
	var az := (links & S) != 0 if q.y > 0.0 else (links & N) != 0
	if ax and az and absf(q.x) > HALF_ROAD and absf(q.y) > HALF_ROAD:
		d = minf(d, FILLET - (q.abs() - Vector2(HALF_ROAD + FILLET, HALF_ROAD + FILLET)).length())
	return d


static func _box(p: Vector2, c: Vector2, h: Vector2) -> float:
	var d := (p - c).abs() - h
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


## What is at a spot on the ground: "" (no street), "road", "kerb" or "sidewalk".
func what_at(p: Vector2) -> String:
	var cell := Vector2i(floori((p.x - origin.x) / TILE), floori((p.y - origin.z) / TILE))
	if not cells.has(cell):
		return ""
	var d := edge(p - mid(cell), links_of(cell))
	return "road" if d < 0.0 else ("kerb" if d < KERB else ("sidewalk" if d < WALK else ""))


## Lay every cell marked so far that isn't laid yet.
func build() -> void:
	for cell: Vector2i in cells:
		if not tiles.has(cell):
			_tile(cell)
	if Ground.it != null:
		Ground.it.apply()


func _tile(cell: Vector2i) -> void:
	var links := links_of(cell)
	var c := mid(cell)
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2(TILE, TILE)
	var m := MeshInstance3D.new()
	m.mesh = _mesh
	m.material_override = mat(links, wear, season)
	m.position = Vector3(c.x, origin.y + LIFT, c.y)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(m)
	tiles[cell] = m
	# Under it, the ground is the street's stone bed: firm, and what a hole shows.
	var rect := Rect2(c - Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE))
	if Ground.it != null:
		Ground.it.paint("bed", rect, func(p: Vector2) -> bool: return edge(p - c, links) < WALK)
	# It is pavement: broken up a square metre at a time (solid.gd, breakable.gd).
	var br := Solid.surface(m, m.position, Vector3(TILE, 0.04, TILE), "asphalt", "street")
	br.thin = float(WEAR_HP[wear])
	br.on_shape = func(p: Vector2) -> bool: return edge(p - c, links) < WALK
	var holes := [0, 0, 0]          # 81 bits, 27 to a number (a list, so the callback below keeps what it sets)
	var pin := season
	var stage := wear
	br.on_cell = func(hit: Vector2i) -> void:
		# Cut that square metre out of the tile: it gets a material of its own, with the hole in it.
		var bit := clampi(hit.x - floori(rect.position.x), 0, 8) + clampi(hit.y - floori(rect.position.y), 0, 8) * 9
		holes[bit / 27] |= 1 << (bit % 27)
		var own := _new_mat(links, stage, pin)
		own.set_shader_parameter("holes", Vector3i(holes[0], holes[1], holes[2]))
		m.material_override = own
	parts.append(br)


# ---------------------------------------------------------------- lamps and signs
## A material for a post, a lantern or a sign's plate (street_prop.gdshader): one shared for each set of values.
static func prop_mat(params: Dictionary, stage: int, pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> ShaderMaterial:
	var key := "prop|%s|%d|%s" % [params, stage, pin]
	if _mats.has(key):
		return _mats[key]
	if _prop_shader == null:
		var path := "res://assets/buildings/street/street_prop.gdshader"
		if raw_colors:
			_prop_shader = Shader.new()
			_prop_shader.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;") \
				.replace("EMISSION=pow(c,vec3(2.2)) * 1.6;", "EMISSION=c * 0.9;")
		else:
			_prop_shader = load(path)
	var m := ShaderMaterial.new()
	m.shader = _prop_shader
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	m.set_shader_parameter("wear", float(stage))
	m.set_shader_parameter("season_override", pin)
	_mats[key] = m
	return m


func _prop_look(params: Dictionary) -> Callable:
	var pin := season
	params["ground_y"] = origin.y
	return func(stage: int) -> Material: return StreetKit.prop_mat(params, stage, pin)


func _worn(b: Breakable) -> Breakable:
	b.hp = b.max_hp * float(WEAR_HP[wear])
	if wear > 0:
		b.stage = wear
		if b.on_stage.is_valid():
			b.on_stage.call(wear)
	return b


## A street lamp at a spot on the ground (x, z): a steel post with a glass lantern on top. `on`: it is lit
## (left out: as the street's `lit` says; one put up worn out is dark whatever).
##
## What it does: at night it lights the ground round it, so whoever stands there is seen from as far as by
## day, and so is what they are looking at. The lantern is glass, above your head: put the crosshair on it and
## shoot it out (or throw a rock), and that stretch of street goes dark. Bring the post down and the lantern
## comes with it. Returns the lantern's Breakable.
func lamp(p: Vector2, on := true) -> Breakable:
	p = Vector2(snappedf(p.x, 1.0 / 16.0), snappedf(p.y, 1.0 / 16.0))
	var burning := on and lit and wear < 2
	var post := Solid.box(level, Vector3(p.x, origin.y + LAMP_H * 0.5, p.y), Vector3(LAMP_POST, LAMP_H, LAMP_POST),
		Color(0.6, 0.62, 0.65), "metal", "lamp post", {}, 0.0,
		_prop_look({"part": 0, "size": Vector3(LAMP_POST, LAMP_H, LAMP_POST)}), origin.y)
	var post_br := _worn(Breakable.of(post))
	# The lantern: glass. It stops nothing that walks (it is over their heads) and a shot goes through it.
	var at := Vector3(p.x, origin.y + LAMP_H + LANTERN.y * 0.5, p.y)
	var head := StaticBody3D.new()
	head.collision_layer = Solid.GLASS_LAYER
	head.collision_mask = 0
	head.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = LANTERN
	shape.shape = bs
	head.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = LANTERN
	mesh.mesh = bm
	mesh.material_override = prop_mat({"part": 1, "size": LANTERN, "lit": burning, "ground_y": origin.y}, wear, season)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(mesh)
	level.add_child(head)
	var br := Breakable.attach(head, at, LANTERN, "glass", "street lamp")
	br.lets_shots = true
	br.floor_y = origin.y
	_worn(br)
	var spot := Vector3(p.x, origin.y, p.y)
	if burning:
		Daylight.add_lamp(spot, LAMP_LIGHT)
		var l := OmniLight3D.new()
		l.omni_range = LAMP_LIGHT + 1.5
		l.light_color = Color(1.0, 0.86, 0.6)
		l.light_energy = 1.5
		l.shadow_enabled = false
		head.add_child(l)
		br.broke.connect(func(_by: Node) -> void: Daylight.remove_lamp(spot))
	# The post going takes the lantern with it.
	post_br.broke.connect(func(by: Node) -> void:
		if is_instance_valid(br) and br.alive():
			br.give_way(by))
	lamps.append(br)
	parts.append(post_br)
	parts.append(br)
	return br


## A sign on a post at a spot on the ground. `face`: "stop", "name" or "warning". `toward` ("N", "E", "S" or
## "W") is the way its face looks. `says` is what it reads (left out: the face's own; a name sign's is the
## street's name).
##
## What it does: it tells whoever walks up to it where they are. It is steel on a thin post, so it is no
## cover, and it rings when it is hit: a noise you can make on purpose without firing a shot. Returns the
## post's Breakable.
func signpost(p: Vector2, face := "stop", toward := "S", says := "") -> Breakable:
	p = Vector2(snappedf(p.x, 1.0 / 16.0), snappedf(p.y, 1.0 / 16.0))
	var f: Dictionary = FACES[face] if FACES.has(face) else FACES["stop"]
	var post := Solid.box(level, Vector3(p.x, origin.y + SIGN_H * 0.5, p.y), Vector3(SIGN_POST, SIGN_H, SIGN_POST),
		Color(0.6, 0.62, 0.65), "metal", f["what"], {}, 0.0,
		_prop_look({"part": 0, "size": Vector3(SIGN_POST, SIGN_H, SIGN_POST)}), origin.y)
	var br := _worn(Breakable.of(post))
	var read := StreetSign.new()
	read.text = says if says != "" else str(f["says"])
	read.position = Vector3(0.0, 1.0 - SIGN_H * 0.5, 0.0)
	post.add_child(read)
	_plate(post, f, toward, SIGN_H - float(f["h"]) * 0.5)
	signs.append(br)
	parts.append(br)
	return br


## One plate on a post: nothing of its own to walk into, it is part of the sign and goes when the post does.
func _plate(post: Node3D, f: Dictionary, toward: String, mid_y: float) -> void:
	var along_x := toward == "N" or toward == "S"
	var out := -1.0 if (toward == "N" or toward == "W") else 1.0
	var w: float = f["w"]
	var h: float = f["h"]
	var t := 1.0 / 16.0
	var size := Vector3(w, h, t) if along_x else Vector3(t, h, w)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var look := _prop_look({"part": 2, "face": int(f["id"]), "size": size, "along_x": along_x, "front": out})
	m.material_override = look.call(wear)
	var off := out * (SIGN_POST * 0.5 + t * 0.5)
	m.position = Vector3(0.0, mid_y - SIGN_H * 0.5, off) if along_x else Vector3(off, mid_y - SIGN_H * 0.5, 0.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.add_child(m)
	var br := Breakable.of(post)
	var before := br.on_stage
	br.on_stage = func(stage: int) -> void:
		if before.is_valid():
			before.call(stage)
		m.material_override = look.call(stage)


## A street name's sign for a corner: two blades on one post, one for each street.
func name_sign(p: Vector2) -> Breakable:
	var br := signpost(p, "name", "S", "%s / %s" % [names["EW"], names["NS"]])
	_plate(br.host, FACES["name"], "E", SIGN_H - 0.1875 * 1.5 - 0.03)
	return br


## Stand lamps and signs along every tile laid so far, where a street would have them: a lamp on each straight
## (on alternate sides), a stop sign facing what comes in on every arm of a junction and a name sign at its
## corner, a warning where a dead end begins.
func furnish() -> void:
	for cell: Vector2i in tiles:
		var links := links_of(cell)
		var c := mid(cell)
		var sides: Array[int] = []
		for side: int in STEP:
			if links & side:
				sides.append(side)
		if sides.size() == 2 and (links == (N | S) or links == (E | W)):
			var which := 1.0 if (cell.x + cell.y) % 2 == 0 else -1.0
			lamp(c + (Vector2(4.1 * which, 0.0) if links == (N | S) else Vector2(0.0, 4.1 * which)))
		elif sides.size() >= 3:
			for side in sides:
				var a := Vector2(STEP[side])
				var right := Vector2(a.y, -a.x)                       # the side of the lane coming in
				signpost(c + a * 4.2 + right * 3.75, "stop", SIDES.find_key(side))
			name_sign(c + Vector2(3.9 if links & E else -3.9, 3.9 if links & S else -3.9))
		elif sides.size() == 1:
			var a := Vector2(STEP[sides[0]])
			signpost(c + a * 4.2 + Vector2(a.y, -a.x) * 3.75, "warning", SIDES.find_key(sides[0]))
