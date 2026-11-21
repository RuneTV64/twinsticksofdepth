class_name FenceKit
extends RefCounted
## Timber fences, and a way to put them up. One style, three kinds, each with its own job:
##
##   picket   1.0 m, painted. Low cover: you crouch behind it, vault it, shoot over it. A zombie climbs it,
##            slowly, and lands on its face. It marks a yard and buys a few seconds. It has points: a body
##            going over it, or knocked back onto it, can be impaled there.
##   board    1.875 m, bare boards. It stops sight as well as bodies, and nobody vaults it; one zombie can't
##            climb it alone, so it has to be beaten down (it is thin: it doesn't take long) or gone round.
##            The way through is a gate.
##   rail     1.25 m, posts and three rails. It hides nobody and stops no sight; most shots go through it
##            (GAPS of them; the rest hit a rail). It only slows whoever has to get over it.
##   gate     a hinged leaf in any of the three, opened and shut with interact like a door (door.gd).
##
## A fence is a run from one point to another along X or Z, with gates anywhere along it. Each stretch
## between gates is one thin box (solid.gd: it can be broken, and is cut where it is hit, so a blow knocks a
## gap a person wide); fence.gdshader draws the posts, pickets, boards and rails on it and cuts the gaps out.
## How it looks comes from three things, as with the house: the season and weather (project-wide), how worn
## it is (`wear`, the three stages of damage), and the cutaway. A fence put up worn starts that much weaker.
##
##   var f := FenceKit.new(level, "picket")
##   f.run(Vector2(30, -24), Vector2(36, -24), [3.0])          # a gate 3 m along
## or a fence right round a rectangle:  FenceKit.yard(level, Rect2(30, -28, 6, 4), "picket", "S")

const TEXEL := 1.0 / 16.0
const THICK := 0.125        # two texels
const GATE_W := 1.25
## A fence built worn starts with this share of its strength.
const WEAR_HP := [1.0, 0.6, 0.3]
## h: its height. strength: its share of the strength of a solid wooden wall its size. gaps: the share of it
## that is air (0 = it stops sight and shots like anything solid). spikes: the chance a body going over it
## is impaled on its points (owner, 21 Nov 2026: "if its got spikes bodies can be impaled on them"). paint: what it wears unless told otherwise
## (-1 bare timber, 0 cream, 1 sage, 2 slate, 3 white). bash: how hard its gate is to barge.
const KINDS := {
	"picket": {"id": 0, "h": 1.0, "strength": 0.25, "gaps": 0.0, "spikes": 0.3, "paint": 3, "what": "picket fence", "bash": 5.0},
	"board": {"id": 1, "h": 1.875, "strength": 0.4, "gaps": 0.0, "spikes": 0.0, "paint": -1, "what": "board fence", "bash": 9.0},
	"rail": {"id": 2, "h": 1.25, "strength": 0.3, "gaps": 0.8, "spikes": 0.0, "paint": -1, "what": "rail fence", "bash": 7.0},
}
## The colour of each paint, for the plain stand-ins (wreckage).
const TINTS := {-1: Color(0.55, 0.45, 0.34), 0: Color(0.85, 0.8, 0.7), 1: Color(0.64, 0.71, 0.6),
	2: Color(0.6, 0.67, 0.74), 3: Color(0.92, 0.91, 0.86)}

## Test harnesses on the software renderer set this: the shader then puts out its palette colours directly.
static var raw_colors := false
static var _shader: Shader
static var _mats := {}

var level: Node
var kind := "picket"
var wear := 0                   # 0 sound, 1 damaged, 2 about to give: how the fence is when put up
var paint := -2                 # -2: the kind's own
var ground_y := 0.0
var season := Vector4(-1.0, 0.0, 0.0, 0.0)     # x >= 0 pins this fence's weather (for review sheets)
var parts: Array[Breakable] = []
var gates: Array[Door] = []


func _init(in_level: Node, of_kind := "picket", worn := 0, colour := -2) -> void:
	level = in_level
	kind = of_kind if KINDS.has(of_kind) else "picket"
	wear = worn
	paint = colour


static func reset() -> void:
	_mats.clear()


## One shared material for each set of values and stage of wear.
static func mat(params: Dictionary, stage: int, pin := Vector4(-1.0, 0.0, 0.0, 0.0)) -> ShaderMaterial:
	var key := "%s|%d|%s" % [params, stage, pin]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		var path := "res://assets/buildings/fence/fence.gdshader"
		if raw_colors:
			_shader = Shader.new()
			_shader.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
		else:
			_shader = load(path)
	var m := ShaderMaterial.new()
	m.shader = _shader
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	m.set_shader_parameter("wear", float(stage))
	m.set_shader_parameter("season_override", pin)
	_mats[key] = m
	return m


func _paint() -> int:
	return int(KINDS[kind]["paint"]) if paint < -1 else paint


func _look(params: Dictionary) -> Callable:
	var pin := season
	params["kind"] = int(KINDS[kind]["id"])
	params["paint"] = _paint()
	return func(stage: int) -> Material: return FenceKit.mat(params, stage, pin)


func _worn(b: Breakable) -> Breakable:
	b.thin_to(float(KINDS[kind]["strength"]))
	b.salvage_mult = 0.5                        # boards and rails, not a wall's worth of timber
	b.hp = b.max_hp * float(WEAR_HP[wear])
	if wear > 0:
		b.stage = wear
		if b.on_stage.is_valid():
			b.on_stage.call(wear)
	parts.append(b)
	return b


## A fence from `a` to `b` (x, z in the world; it must run along X or along Z). `gate_at` lists how far from
## the west or north end each gate's middle is. `outward` is the good side (pickets and boards in front, the
## rails behind); left out, it is the side the camera sees (south or east).
func run(a: Vector2, b: Vector2, gate_at: Array = [], outward := Vector2.ZERO) -> void:
	var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
	var line := snappedf(a.y if along_x else a.x, TEXEL)
	var u0 := snappedf(minf(a.x, b.x) if along_x else minf(a.y, b.y), TEXEL)
	var u1 := snappedf(maxf(a.x, b.x) if along_x else maxf(a.y, b.y), TEXEL)
	if outward == Vector2.ZERO:
		outward = Vector2(0, 1) if along_x else Vector2(1, 0)
	var at := u0
	var sorted := gate_at.duplicate()
	sorted.sort()
	for g in sorted:
		var g0 := snappedf(u0 + float(g) - GATE_W * 0.5, TEXEL)
		if g0 < at or g0 + GATE_W > u1:
			continue
		_panel(at, g0, line, along_x, outward)
		_gate(g0, line, along_x, outward)
		at = g0 + GATE_W
	_panel(at, u1, line, along_x, outward)


func _panel(u0: float, u1: float, line: float, along_x: bool, outward: Vector2) -> void:
	var length := u1 - u0
	if length < 4.0 * TEXEL:
		return
	var k: Dictionary = KINDS[kind]
	var h: float = k["h"]
	var mid := (u0 + u1) * 0.5
	var pos := Vector3(mid, ground_y + h * 0.5, line) if along_x else Vector3(line, ground_y + h * 0.5, mid)
	var size := Vector3(length, h, THICK) if along_x else Vector3(THICK, h, length)
	var look := _look({"outward": Vector3(outward.x, 0.0, outward.y), "along_x": along_x, "ground_y": ground_y,
		"run_start": u0, "run_len": length})
	var body := Solid.box(level, pos, size, TINTS[_paint()], "wood", k["what"], {}, 0.0, look, ground_y)
	if float(k["gaps"]) > 0.0:
		Solid.open_up(body, float(k["gaps"]))
	_worn(Breakable.of(body)).spikes = float(k["spikes"])


func _gate(u0: float, line: float, along_x: bool, outward: Vector2) -> void:
	var k: Dictionary = KINDS[kind]
	var door := Door.new()
	door.width = GATE_W
	door.height = float(k["h"]) - (TEXEL if kind != "rail" else 0.0)      # a gate hangs a little under the posts
	door.toughness = float(k["bash"])
	door.noun = "gate"
	if along_x:
		door.position = Vector3(u0, ground_y, line)                      # the hinge; the leaf runs toward +X
	else:
		door.position = Vector3(line, ground_y, u0 + GATE_W)             # turned: the leaf runs toward -Z
		door.rotation.y = PI / 2
	level.add_child(door)
	# The leaf's own +z is the world's +z along X, and the world's +x when turned.
	var good := outward.y if along_x else outward.x
	var look := _look({"gate": true, "leaf": Vector2(GATE_W - 0.05, door.height), "leaf_out": 1.0 if good >= 0.0 else -1.0})
	door._panel.material_override = look.call(wear)
	door.breakable.title = "gate"
	door.breakable.on_stage = func(stage: int) -> void: door._panel.material_override = look.call(stage)
	_worn(door.breakable)
	gates.append(door)


## A fence right round a rectangle (x, z), with a gate in the middle of each side named in `gate_sides`
## ("N", "S", "E", "W" in any mix, or "" for none). The good side faces out.
static func yard(in_level: Node, rect: Rect2, of_kind := "picket", gate_sides := "S", worn := 0, colour := -2,
		pin := Vector4(-1.0, 0.0, 0.0, 0.0), at_y := 0.0) -> FenceKit:
	var f := FenceKit.new(in_level, of_kind, worn, colour)
	f.season = pin
	f.ground_y = at_y
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var inset := THICK * 0.5                      # the sides stop short of the corners the ends fill
	f.run(Vector2(x0, z0), Vector2(x1, z0), [rect.size.x * 0.5] if "N" in gate_sides else [], Vector2(0, -1))
	f.run(Vector2(x0, z1), Vector2(x1, z1), [rect.size.x * 0.5] if "S" in gate_sides else [], Vector2(0, 1))
	f.run(Vector2(x0, z0 + inset), Vector2(x0, z1 - inset), [rect.size.y * 0.5 - inset] if "W" in gate_sides else [], Vector2(-1, 0))
	f.run(Vector2(x1, z0 + inset), Vector2(x1, z1 - inset), [rect.size.y * 0.5 - inset] if "E" in gate_sides else [], Vector2(1, 0))
	return f
