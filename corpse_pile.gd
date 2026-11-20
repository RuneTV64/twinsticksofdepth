class_name CorpsePile
extends Node3D
## What is left when a horde crushes its own. Zombies trampled under a dense crowd first make a heap of live
## bodies (enemy.gd); when a heap is full and the crowd keeps coming, the one at the bottom is crushed flat. It
## stops being a zombie and becomes part of this: one mound for the whole level, however many bodies are in it.
##
##   height    each crushed body adds LAYER to its 0.8 m cell, up to max_height. Everyone walks on top of it
##             (Enemy.heap_height), zombies and people alike, and from high enough the top of a wall is in reach.
##   the mess  the mound is drawn as one lumpy mesh, with a stain round its foot.
##   alive     about one crushed zombie in eight is still alive in there, trapped. Where one is, an arm sticks
##             out and gropes about. Anyone who steps near it may be grabbed or bitten. A finisher puts it down.
##
## Nothing here runs every tick: the mesh is rebuilt at most twice a second when the pile has changed, and the
## trapped ones are checked four times a second.

const CELL := 0.8
const LAYER := 0.15            # m of height one crushed body adds (flattened: an intact one in a heap is 0.4)

static var it: CorpsePile      # the pile in this level, made when the first zombie is crushed

@export var max_height := 7.0  # m: about two and a half storeys. Past this they can't keep their footing to add to it
@export var live_chance := 0.125   # chance a crushed zombie is still alive in the pile
@export var grab_reach := 1.0      # m: how close a trapped one can get hold of you
@export var grab_chance := 0.35    # per second, per trapped one in reach
@export var bite_chance := 0.5     # a grab that is also a bite
@export var bite_damage := 10.0

var cells := {}                # Vector2i -> how many are crushed there
var total := 0                 # crushed bodies in the whole pile
var arms: Array[Dictionary] = []   # the trapped ones: {"cell", "node", "phase"}

var _mesh: MeshInstance3D
var _dirty := false
var _mesh_t := 0.0
var _tick_t := 0.0
var _grab_cd := {}             # victim instance id -> seconds until it can be grabbed again
var _solid := {}               # cell -> is it inside a wall (worked out once per cell)

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
// The corpse pile: chunky 8-shade gore, darker in the hollows, with a ragged stain round the foot.
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 px = floor(wp.xz * 22.0) / 22.0;                       // art pixels, fixed to the ground
	float n = 0.55 * noise(px * 2.3) + 0.3 * noise(px * 6.1 + 9.0) + 0.15 * hash(px * 31.0);
	// Clotted blood, raw and rotting flesh, dusky grey-green, pale skin.
	vec3 pal[8] = vec3[8](vec3(0.07, 0.02, 0.02), vec3(0.16, 0.04, 0.04), vec3(0.27, 0.07, 0.06), vec3(0.36, 0.11, 0.09),
		vec3(0.28, 0.22, 0.17), vec3(0.34, 0.33, 0.25), vec3(0.47, 0.40, 0.34), vec3(0.60, 0.53, 0.47));
	vec3 c = pal[int(clamp(n * 8.0, 0.0, 7.0))];
	if (wp.y < 0.05) {
		// The stain on the ground: dark, and ragged at the edge.
		if (noise(wp.xz * 3.0) + 0.5 * COLOR.r < 0.62) {
			discard;
		}
		c = mix(pal[0], pal[1], step(0.5, hash(px * 13.0)));
	}
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
"""


## How high the pile stands at this spot (smoothed between cells).
static func height_at(p: Vector3) -> float:
	if it == null:
		return 0.0
	var fx := p.x / CELL - 0.5
	var fz := p.z / CELL - 0.5
	var x0 := floori(fx)
	var z0 := floori(fz)
	var tx := fx - x0
	var tz := fz - z0
	var c := it.cells
	var h00: int = c.get(Vector2i(x0, z0), 0)
	var h10: int = c.get(Vector2i(x0 + 1, z0), 0)
	var h01: int = c.get(Vector2i(x0, z0 + 1), 0)
	var h11: int = c.get(Vector2i(x0 + 1, z0 + 1), 0)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz) * LAYER


## One more crushed into the pile at this cell. `parent` is where the pile lives if this is the first.
## False if the pile is as high as it gets there.
static func crush(cell: Vector2i, parent: Node) -> bool:
	if it == null:
		it = CorpsePile.new()
		parent.add_child(it)
	return it._add(cell)


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _exit_tree() -> void:
	if it == self:
		it = null


func _add(cell: Vector2i) -> bool:
	var n: int = cells.get(cell, 0)
	if (n + 1) * LAYER > max_height:
		return false
	cells[cell] = n + 1
	total += 1
	_dirty = true
	if randf() < live_chance:
		_trap(cell)
	return true


## One still alive in there: an arm out of the mess, groping.
func _trap(cell: Vector2i) -> void:
	var arm := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.5, 0.42)
	mat.roughness = 0.9
	var fore := MeshInstance3D.new()
	var fm := CapsuleMesh.new()
	fm.radius = 0.045
	fm.height = 0.42
	fore.mesh = fm
	fore.material_override = mat
	fore.position.y = 0.2
	arm.add_child(fore)
	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.1, 0.13, 0.05)
	hand.mesh = hm
	hand.material_override = mat
	hand.position.y = 0.45
	arm.add_child(hand)
	arm.position = Vector3((cell.x + randf_range(0.25, 0.75)) * CELL, 0.0, (cell.y + randf_range(0.25, 0.75)) * CELL)
	add_child(arm)
	arms.append({"cell": cell, "node": arm, "phase": randf() * TAU})


## The trapped one nearest `point` within `radius`, as its place in the world; or null.
func live_near(point: Vector3, radius: float):
	var best = null
	var best_d := radius
	for a in arms:
		var p: Vector3 = (a["node"] as Node3D).global_position
		var d := Vector2(p.x - point.x, p.z - point.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


## Finish the trapped one nearest `point`. True if there was one.
func kill_near(point: Vector3, radius: float) -> bool:
	for i in arms.size():
		var p: Vector3 = (arms[i]["node"] as Node3D).global_position
		if Vector2(p.x - point.x, p.z - point.z).length() < radius:
			(arms[i]["node"] as Node3D).queue_free()
			arms.remove_at(i)
			return true
	return false


func _process(delta: float) -> void:
	# The arms grope about (only the few that exist, and it is a couple of rotations each).
	var t := Time.get_ticks_msec() * 0.001
	for a in arms:
		var n := a["node"] as Node3D
		var ph: float = a["phase"]
		n.position.y = height_at(n.position) - 0.05
		n.rotation = Vector3(0.5 * sin(t * 1.7 + ph), ph, 0.45 * sin(t * 2.3 + ph * 1.7))
	_mesh_t -= delta
	if _dirty and _mesh_t <= 0.0:
		_dirty = false
		_mesh_t = 0.5
		_rebuild()


func _physics_process(delta: float) -> void:
	_tick_t -= delta
	if _tick_t > 0.0 or arms.is_empty():
		return
	_tick_t = 0.25
	for id in _grab_cd.keys():
		_grab_cd[id] -= 0.25
		if _grab_cd[id] <= 0.0:
			_grab_cd.erase(id)
	var people: Array = get_tree().get_nodes_in_group("player")
	people.append_array(get_tree().get_nodes_in_group("raiders"))
	for who in people:
		if who.dead or _grab_cd.has(who.get_instance_id()):
			continue
		for a in arms:
			var p: Vector3 = (a["node"] as Node3D).global_position
			var to: Vector3 = who.global_position - p
			to.y = 0.0
			if to.length() < grab_reach and randf() < grab_chance * 0.25:
				_grab_cd[who.get_instance_id()] = 1.5
				who.pile_grab(to.normalized(), bite_damage if randf() < bite_chance else 0.0)
				break


func _is_solid(cell: Vector2i) -> bool:
	if not _solid.has(cell):
		var c := Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)
		var inside := false
		for b in Cover.boxes:
			if b.rect.has_point(c):
				inside = true
				break
		_solid[cell] = inside
	return _solid[cell]


## The mound as one mesh: a height at every cell corner, sloping to nothing one cell out (where the stain is).
## Against a wall it doesn't slope away: it banks up on it.
func _rebuild() -> void:
	var corners := {}
	for cell: Vector2i in cells:
		for dx in range(-1, 3):
			for dz in range(-1, 3):
				corners[Vector2i(cell.x + dx, cell.y + dz)] = 0.0
	for k: Vector2i in corners:
		var sum := 0.0
		var top := 0.0
		var n := 0
		var walled := false
		for dx in [-1, 0]:
			for dz in [-1, 0]:
				var c := Vector2i(k.x + dx, k.y + dz)
				if _is_solid(c):
					walled = true
					continue
				var h: float = int(cells.get(c, 0)) * LAYER
				sum += h
				top = maxf(top, h)
				n += 1
		var hh := top if walled else (sum / n if n > 0 else 0.0)
		if hh > 0.0:
			hh += 0.12 * sin(k.x * 12.9898 + k.y * 78.233)   # lumps
		corners[k] = maxf(hh, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: Vector2i in corners:
		var ks := [k, Vector2i(k.x + 1, k.y), Vector2i(k.x + 1, k.y + 1), Vector2i(k.x, k.y + 1)]
		if not (corners.has(ks[1]) and corners.has(ks[2]) and corners.has(ks[3])):
			continue
		var v: Array[Vector3] = []
		for c: Vector2i in ks:
			v.append(Vector3(c.x * CELL, float(corners[c]) + 0.03, c.y * CELL))
		var stain := Color(1.0 if maxf(maxf(v[0].y, v[1].y), maxf(v[2].y, v[3].y)) > 0.05 else 0.0, 0, 0)
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(stain)
			st.add_vertex(v[i])
	st.generate_normals()
	_mesh.mesh = st.commit()
