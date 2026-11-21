class_name HouseKit
extends RefCounted
## The parts of a house, and a way to put them together. One style: a timber house with painted clapboard
## outside and plaster inside, floorboards, a pitched shingle roof. Houses of any number of rooms and storeys
## are laid out on a grid of CELL metres.
##
## The parts (each is made of something and can be broken: solid.gd, breakable.gd):
##   wall cell      solid, with a window (W), with a door (D), with an open doorway (O); outside or inside wall
##   floor cell     floorboards: the ground floor, and the floor over a room (leave a cell out for the stairs)
##   stairs         a straight flight in one cell
##   roof           a gable roof over any rectangle of cells
##
## How a part looks is the shader's business (house_wall, house_roof, house_floor, house_trim), from three
## things: the season and weather (project-wide, seasons.gd), how worn it is (`wear`: the part's damage stage,
## 0 sound, 1 damaged, 2 about to give), and the cutaway. A house can be built already worn (`wear`): its
## parts then start that much weaker, so a derelict house really is easier to break into.
##
##   var k := HouseKit.new(level, Vector3(20, 0, -33))
##   k.wall(Vector2i(0, 2), Vector2i(3, 2), 0, "WDW", Vector2(0, 1))     # the south wall: window, door, window
##   k.floor(Rect2i(0, 0, 3, 2), 0)
##   k.roof(Rect2i(0, 0, 3, 2), 1)
## or the whole of an ordinary house:  HouseKit.house(level, origin, 3, 2, 2)

const CELL := 3.0          # a wall cell is this long; rooms are whole cells
const WALL_H := 2.6        # a wall's height
const STOREY := 2.7        # from one floor to the next (the wall and the floor over it)
const THICK := 0.3         # outside walls
const THIN := 0.2          # inside walls
const SILL := 0.9
const HEAD := 2.0
const WINDOW_W := 1.4
const DOOR_W := 1.1
const DOOR_H := 2.1
const EAVES := 0.35        # how far the roof overhangs
const PITCH := 0.6         # the roof's rise for each metre of half-span
const LIFT := 0.14         # the roof sits this far above the wall line, so the wall tops don't show through
const STEPS := 12
## A part built worn starts with this share of its strength.
const WEAR_HP := [1.0, 0.6, 0.3]
const PAINTS := [Color(0.85, 0.8, 0.7), Color(0.64, 0.71, 0.6), Color(0.6, 0.67, 0.74)]

## Test harnesses on the software renderer set this: the shaders then put out their palette colours directly.
static var raw_colors := false
static var _shaders := {}
static var _mats := {}

var level: Node
var origin := Vector3.ZERO      # the world position of grid point (0, 0), on the ground
var wear := 0                   # 0 sound, 1 damaged, 2 about to give: how the house is when built
var paint := 0                  # 0 cream, 1 sage, 2 slate
var season := Vector4(-1.0, 0.0, 0.0, 0.0)     # x >= 0 pins this house's weather (for review sheets)
var parts: Array[Breakable] = []


func _init(in_level: Node, at: Vector3, worn := 0, colour := 0) -> void:
	level = in_level
	origin = at
	wear = worn
	paint = colour


static func reset() -> void:
	_mats.clear()


## One shared material for each shader, set of values and stage of wear.
static func mat(kind: String, params: Dictionary, stage: int, pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> ShaderMaterial:
	var key := "%s|%s|%d|%s" % [kind, params, stage, pin]
	if _mats.has(key):
		return _mats[key]
	if not _shaders.has(kind):
		var path := "res://assets/buildings/house/house_%s.gdshader" % kind
		if raw_colors:
			var sh := Shader.new()
			sh.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
			_shaders[kind] = sh
		else:
			_shaders[kind] = load(path)
	var m := ShaderMaterial.new()
	m.shader = _shaders[kind]
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	m.set_shader_parameter("wear", float(stage))
	m.set_shader_parameter("season_override", pin)
	_mats[key] = m
	return m


func _look(kind: String, params: Dictionary) -> Callable:
	var pin := season
	return func(stage: int) -> Material: return HouseKit.mat(kind, params, stage, pin)


## Where a grid point is in the world (x, z).
func at(g: Vector2) -> Vector2:
	return Vector2(origin.x + g.x * CELL, origin.z + g.y * CELL)


func _base(storey: int) -> float:
	return origin.y + storey * STOREY


func _worn(b: Breakable) -> Breakable:
	b.hp = b.max_hp * float(WEAR_HP[wear])
	if wear > 0:
		b.stage = wear
		if b.on_stage.is_valid():
			b.on_stage.call(wear)
	parts.append(b)
	return b


## A wall from grid point `a` to grid point `b` (in a straight line along X or Z), on `storey`. `cells` has one
## letter for each cell along it: "." solid, "W" window, "D" door, "O" open doorway. `outward` points out of
## the house (it decides which side is clapboard); leave it zero for an inside wall, plaster on both sides.
func wall(a: Vector2i, b: Vector2i, storey: int, cells: String, outward := Vector2.ZERO) -> void:
	if a.x > b.x or a.y > b.y:
		var t := a
		a = b
		b = t
	var along_x := a.y == b.y
	var n := (b.x - a.x) if along_x else (b.y - a.y)
	var inside := outward == Vector2.ZERO
	var thick := THIN if inside else THICK
	var p0 := at(Vector2(a))
	var look := _look("wall", {"outward": Vector3(outward.x, 0.0, outward.y), "inside_wall": inside, "paint": paint,
		"ground_y": _base(storey), "footing": storey == 0})
	var piece := func(d0: float, d1: float, y0: float, y1: float) -> void:
		if d1 - d0 < 0.02:
			return
		var mid := (d0 + d1) * 0.5
		var y := _base(storey) + (y0 + y1) * 0.5
		var pos := Vector3(p0.x + mid, y, p0.y) if along_x else Vector3(p0.x, y, p0.y + mid)
		var size := Vector3(d1 - d0, y1 - y0, thick) if along_x else Vector3(thick, y1 - y0, d1 - d0)
		_worn(Breakable.of(Solid.box(level, pos, size, PAINTS[paint], "plaster" if inside else "wood", "wall", {}, 0.0, look)))
	for i in n:
		var d0 := i * CELL - (thick * 0.5 if i == 0 and not inside else 0.0)       # outside walls close the corners
		var d1 := (i + 1) * CELL + (thick * 0.5 if i == n - 1 and not inside else 0.0)
		var c := (i + 0.5) * CELL
		var kind := cells[i] if i < cells.length() else "."
		match kind:
			"W":
				piece.call(d0, c - WINDOW_W * 0.5, 0.0, WALL_H)
				piece.call(c + WINDOW_W * 0.5, d1, 0.0, WALL_H)
				piece.call(c - WINDOW_W * 0.5, c + WINDOW_W * 0.5, 0.0, SILL)
				piece.call(c - WINDOW_W * 0.5, c + WINDOW_W * 0.5, HEAD, WALL_H)
				var y := _base(storey) + (SILL + HEAD) * 0.5
				if along_x:
					parts.append(Solid.pane(level, Vector3(p0.x + c, y, p0.y), Vector3(WINDOW_W, HEAD - SILL, 0.05)))
				else:
					parts.append(Solid.pane(level, Vector3(p0.x, y, p0.y + c), Vector3(0.05, HEAD - SILL, WINDOW_W)))
			"D", "O":
				piece.call(d0, c - DOOR_W * 0.5, 0.0, WALL_H)
				piece.call(c + DOOR_W * 0.5, d1, 0.0, WALL_H)
				piece.call(c - DOOR_W * 0.5, c + DOOR_W * 0.5, DOOR_H, WALL_H)
				if kind == "D":
					_door(Vector3(p0.x + c, _base(storey), p0.y) if along_x else Vector3(p0.x, _base(storey), p0.y + c), along_x, not inside)
			_:
				piece.call(d0, d1, 0.0, WALL_H)


func _door(mid: Vector3, along_x: bool, outdoors: bool) -> void:
	var door := Door.new()
	door.width = DOOR_W
	door.height = DOOR_H
	if along_x:
		door.position = mid - Vector3(DOOR_W * 0.5, 0.0, 0.0)       # the hinge; the leaf runs toward +X
	else:
		door.position = mid + Vector3(0.0, 0.0, DOOR_W * 0.5)       # turned: the leaf runs toward -Z
		door.rotation.y = PI / 2
	level.add_child(door)
	var look := _look("trim", {"outdoors": outdoors})
	door._panel.material_override = look.call(wear)
	door.breakable.on_stage = func(stage: int) -> void: door._panel.material_override = look.call(stage)
	_worn(door.breakable)


## Floorboards over a rectangle of cells: the ground floor on storey 0, otherwise the floor over the storey
## below. Cells in `skip` are left open (where the stairs come up).
func floor(cells: Rect2i, storey: int, skip: Array[Vector2i] = []) -> void:
	var thick := 0.04 if storey == 0 else STOREY - WALL_H
	var y := origin.y + 0.02 if storey == 0 else _base(storey) - thick * 0.5
	for cx in range(cells.position.x, cells.end.x):
		for cz in range(cells.position.y, cells.end.y):
			if skip.has(Vector2i(cx, cz)):
				continue
			var mid := at(Vector2(cx + 0.5, cz + 0.5))
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(CELL, thick, CELL)
			m.mesh = bm
			m.position = Vector3(mid.x, y, mid.y)
			m.material_override = HouseKit.mat("floor", {"along_x": true}, wear, season)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if storey == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			level.add_child(m)
			var b := Solid.surface(m, m.position, bm.size, "wood", "floor")
			parts.append(b)


## A straight flight of stairs in one cell, from `storey` up to the next, rising the way `dir` points, set
## against the side of the cell to the left of `dir`. (It is a part, and it can be broken; nobody can walk up
## it yet: the game has no upstairs.)
func stairs(cell: Vector2i, storey: int, dir: Vector2i) -> void:
	var d := Vector2(dir)
	var side := Vector2(d.y, -d.x)                            # to the left of the way up
	var mid := at(Vector2(cell) + Vector2(0.5, 0.5)) + side * (CELL * 0.5 - 0.5 - THICK * 0.5)
	var run := CELL - THICK
	var along_x := dir.x != 0
	var look := _look("trim", {"outdoors": false})
	var size := Vector3(run, STOREY * 0.5, 1.0) if along_x else Vector3(1.0, STOREY * 0.5, run)
	var body := Solid.box(level, Vector3(mid.x, _base(storey) + STOREY * 0.25, mid.y), size, Color(0.8, 0.78, 0.72), "wood", "stairs")
	(body.get_child(1) as MeshInstance3D).visible = false         # the box is only what you bump into
	var steps: Array[MeshInstance3D] = []
	for i in STEPS:
		var h := STOREY * (i + 1) / STEPS
		var u := (i + 0.5) / STEPS - 0.5
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(run / STEPS, h, 1.0) if along_x else Vector3(1.0, h, run / STEPS)
		m.mesh = bm
		var off := d * (u * run)
		m.position = Vector3(off.x, h * 0.5 - STOREY * 0.25, off.y)
		m.material_override = look.call(wear)
		body.add_child(m)
		steps.append(m)
	var b := Breakable.of(body)
	b.on_stage = func(stage: int) -> void:
		for m in steps:
			m.material_override = look.call(stage)
	_worn(b)


## A gable roof over a rectangle of cells, its eaves at the top of storey `storeys - 1`. The ridge runs the
## long way unless `ridge_x` says otherwise (1 along X, 0 along Z, -1 choose).
func roof(cells: Rect2i, storeys: int, ridge_x := -1) -> void:
	var rx := cells.size.x >= cells.size.y if ridge_x < 0 else ridge_x == 1
	var a := at(Vector2(cells.position))
	var b := at(Vector2(cells.end))
	var y0 := _base(storeys) - (STOREY - WALL_H) + LIFT      # lifted clear of the tops of the walls
	var half := ((b.y - a.y) if rx else (b.x - a.x)) * 0.5
	var rise := half * PITCH
	var eave_drop := EAVES * PITCH
	# In the roof's own frame: u along the ridge, v across it.
	var u0 := (a.x if rx else a.y) - EAVES
	var u1 := (b.x if rx else b.y) + EAVES
	var vm := ((a.y + b.y) if rx else (a.x + b.x)) * 0.5
	var p := func(u: float, v: float, y: float) -> Vector3: return Vector3(u, y, v) if rx else Vector3(v, y, u)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sgn: float in [-1.0, 1.0]:
		var e0: Vector3 = p.call(u0, vm + sgn * (half + EAVES), y0 - eave_drop)
		var e1: Vector3 = p.call(u1, vm + sgn * (half + EAVES), y0 - eave_drop)
		var r0: Vector3 = p.call(u0, vm, y0 + rise)
		var r1: Vector3 = p.call(u1, vm, y0 + rise)
		var nrm := (r0 - e0).cross(e1 - e0).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		_tri(st, e0, r0, r1, nrm)
		_tri(st, e0, r1, e1, nrm)
	st.commit(mesh)
	# The gable ends: wall, up to the ridge.
	for end: float in [-1.0, 1.0]:
		var gu := (a.x if rx else a.y) if end < 0.0 else (b.x if rx else b.y)
		var gs := SurfaceTool.new()
		gs.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tri(gs, p.call(gu, vm - half - THICK * 0.5, y0 - LIFT), p.call(gu, vm + half + THICK * 0.5, y0 - LIFT),
			p.call(gu, vm, y0 + rise - 0.02), p.call(end, 0.0, 0.0))
		gs.commit(mesh)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	level.add_child(m)
	var looks: Array[Callable] = [_look("roof", {"ridge_x": rx, "eave_y": y0})]
	for end: float in [-1.0, 1.0]:
		looks.append(_look("wall", {"outward": p.call(end, 0.0, 0.0), "inside_wall": false, "paint": paint, "ground_y": y0, "footing": false}))
	var dress := func(stage: int) -> void:
		for i in 3:
			m.set_surface_override_material(i, looks[i].call(stage))
	dress.call(wear)
	var mid := (a + b) * 0.5
	var br := Breakable.attach(m, Vector3(mid.x, y0 + rise * 0.5, mid.y), Vector3(b.x - a.x + EAVES * 2.0, rise, b.y - a.y + EAVES * 2.0), "wood", "roof")
	br.on_stage = dress
	_worn(br)


## One triangle facing `nrm` (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	var pts := [a, b, c] if (b - a).cross(c - a).dot(nrm) < 0.0 else [a, c, b]
	for q: Vector3 in pts:
		st.set_normal(nrm)
		st.add_vertex(q)


## An ordinary house, `wide` by `deep` cells and `storeys` high: a front door in the south wall, windows all
## round, the inside walled into rooms with open doorways, stairs in the north-west corner, a gable roof.
static func house(in_level: Node, at_pos: Vector3, wide: int, deep: int, storeys := 1, worn := 0, colour := 0,
		pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> HouseKit:
	var k := HouseKit.new(in_level, at_pos, worn, colour)
	k.season = pin
	var all := Rect2i(0, 0, wide, deep)
	for s in storeys:
		var top := s == storeys - 1
		var south := ""
		var north := ""
		for i in wide:
			south += "D" if s == 0 and i == wide / 2 else "W"
			north += "." if i == 0 and storeys > 1 else "W"      # the stairs stand against the north wall
		var sides := ""
		for i in deep:
			sides += "W"
		k.wall(Vector2i(0, 0), Vector2i(wide, 0), s, north, Vector2(0, -1))
		k.wall(Vector2i(0, deep), Vector2i(wide, deep), s, south, Vector2(0, 1))
		k.wall(Vector2i(0, 0), Vector2i(0, deep), s, sides, Vector2(-1, 0))
		k.wall(Vector2i(wide, 0), Vector2i(wide, deep), s, sides, Vector2(1, 0))
		# Rooms: a wall across the house, and one dividing the back half, each with a doorway.
		if wide >= 3:
			var x := wide - 1
			var inner := ""
			for i in deep:
				inner += "O" if i == deep - 1 else "."
			k.wall(Vector2i(x, 0), Vector2i(x, deep), s, inner)
		if deep >= 2 and wide >= 2:
			var across := ""
			for i in maxi(wide - 1, 1):
				across += "O" if i == maxi(wide - 2, 0) else "."
			k.wall(Vector2i(0, 1), Vector2i(maxi(wide - 1, 1), 1), s, across)
		var open: Array[Vector2i] = []
		if s > 0:
			open.append(Vector2i(0, 0))
		k.floor(all, s, open)
		if not top:
			k.stairs(Vector2i(0, 0), s, Vector2i(1, 0))
	k.roof(all, storeys)
	return k
