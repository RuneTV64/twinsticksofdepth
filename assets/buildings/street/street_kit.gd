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

## Test harnesses on the software renderer set this: the shader then puts out its palette colours directly.
static var raw_colors := false
static var _shader: Shader
static var _mats := {}
static var _mesh: PlaneMesh

var level: Node
var origin := Vector3.ZERO      # the world position of the north-west corner of grid cell (0, 0)
var wear := 0
var season := Vector4(-1.0, 0.0, 0.0, 0.0)     # x >= 0 pins this street's weather (for review sheets)
var cells := {}                 # Vector2i -> extra sides it carries on through (see open())
var tiles := {}                 # Vector2i -> its MeshInstance3D, once built
var parts: Array[Breakable] = []


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
