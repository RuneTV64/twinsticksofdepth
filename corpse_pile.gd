class_name CorpsePile
extends Node3D
## What is left when a horde crushes its own. Zombies trampled under a dense crowd first make a heap of live
## bodies (enemy.gd); when a heap is full and the crowd keeps coming, the one at the bottom is crushed flat. It
## stops being a zombie and becomes part of this: one mound for the whole level, however many bodies are in it.
##
##   height    each crushed body adds LAYER to its 0.8 m cell, up to max_height. Everyone walks on top of it
##             (Enemy.heap_height), zombies and people alike, and from high enough the top of a wall is in reach.
##   the mess  the mound is one lumpy mesh painted with gore_tiles.gd's tiles (bones, ribs, skulls, gut, sinew),
##             a different one on every cell, with a stain round its foot. Sticking out of it are real pieces of
##             the zombies that went into it: forearms, lower legs, heads, each with its owner's skin and rot.
##   alive     about one crushed zombie in eight is still alive in there, trapped. Its arm (or head) is one of
##             those pieces and looks like any other: there is no telling which until it takes hold of you.
##             Any piece can be stomped; if it was alive, that finishes it.
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
var pieces: Array[Dictionary] = []   # limbs and heads sticking out: {"node", "slot", "live"}
var slump := 3                 # a spot this many bodies higher than its neighbour spills onto it
var max_pieces := 140          # the oldest dead ones go when there are more

var _mesh: MeshInstance3D
var _dirty := false
var _mesh_t := 0.0
var _tick_t := 0.0
var _grab_cd := {}             # victim instance id -> seconds until it can be grabbed again
var _solid := {}               # cell -> is it inside a wall (worked out once per cell)

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
// The corpse pile. Underneath, pulped meat and clotted blood. Over it, for every 0.8 m cell, one of the painted
// tiles from gore_tiles.gd (bones, ribs, skulls, limbs, gut, sinew), picked, turned and flipped by the cell's own
// roll, so the pieces fit together without end and no stretch of the pile repeats.
uniform sampler2D tiles : filter_nearest, repeat_disable;
const float CELL = 0.8;
const int TILE = 40;
const int COLS = 6;
const int COUNT = 24;
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
	vec3 pal[16] = vec3[16](vec3(0.07, 0.02, 0.02), vec3(0.17, 0.03, 0.03), vec3(0.33, 0.05, 0.05), vec3(0.47, 0.12, 0.10),
		vec3(0.36, 0.20, 0.18), vec3(0.33, 0.34, 0.25), vec3(0.18, 0.19, 0.13), vec3(0.80, 0.70, 0.60),
		vec3(0.72, 0.62, 0.40), vec3(0.45, 0.36, 0.24), vec3(0.82, 0.80, 0.70), vec3(0.74, 0.64, 0.36),
		vec3(0.55, 0.38, 0.36), vec3(0.66, 0.60, 0.52), vec3(0.30, 0.22, 0.18), vec3(0.45, 0.47, 0.38));
	// Painted from above on the flatter parts, and from the side on the steep ones, so nothing smears down a slope.
	vec2 q = wp.xz;
	vec3 fn = normalize(cross(dFdx(wp), dFdy(wp)));      // the face's own slope (the mesh's normals are smoothed)
	if (abs(fn.y) < 0.75) {
		q = abs(fn.x) > abs(fn.z) ? vec2(wp.z, wp.y * 1.15 + 17.0) : vec2(wp.x, wp.y * 1.15 + 31.0);
	}
	// The base: pulp, in art pixels. Mostly blood and red meat, patches gone dusky or green.
	vec2 px = floor(q * 50.0) / 50.0;
	float n = 0.5 * noise(px * 2.1) + 0.3 * noise(px * 5.3 + 9.0) + 0.2 * hash(px * 31.0);
	int base[8] = int[8](0, 1, 1, 2, 3, 2, 4, 5);
	int idx = base[int(clamp(n * 8.0, 0.0, 7.0))];
	float h = 0.2 + 0.25 * noise(px * 7.0);
	// The tile for this cell.
	vec2 g = q / CELL;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	int tile = int(hash(cell) * float(COUNT)) % COUNT;
	int turn = int(hash(cell + 3.7) * 4.0);
	if (hash(cell + 9.1) > 0.5) {
		f.x = 1.0 - f.x;
	}
	for (int i = 0; i < turn; i++) {
		f = vec2(f.y, 1.0 - f.x);
	}
	ivec2 t = clamp(ivec2(f * float(TILE)), ivec2(0), ivec2(TILE - 1)) + ivec2(tile % COLS, tile / COLS) * TILE;
	vec4 s = texelFetch(tiles, t, 0);
	if (s.b > 0.5) {
		idx = int(s.r * 255.0 / 16.0 + 0.5);
		h = s.g;
	}
	vec3 c = pal[idx] * (0.7 + 0.45 * h);       // what stands up catches the light
	bool wet = idx <= 3;
	if (wp.y < 0.05) {
		// The stain on the ground: blood only, ragged at the edge.
		if (noise(wp.xz * 3.0) + 0.5 * COLOR.r < 0.62) {
			discard;
		}
		c = pal[hash(px * 13.0) > 0.5 ? 1 : 0];
		wet = true;
	}
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = wet ? 0.3 : 0.85;
	SPECULAR = wet ? 0.6 : 0.2;
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


## One more crushed into the pile at this cell. `parent` is where the pile lives if this is the first; `donor`
## is the zombie being crushed, whose limbs may be left sticking out. False if the pile is as high as it gets there.
static func crush(cell: Vector2i, parent: Node, donor: Enemy = null) -> bool:
	if it == null:
		it = CorpsePile.new()
		parent.add_child(it)
	return it._add(cell, donor)


## How many are still alive in the pile.
func trapped() -> int:
	var n := 0
	for e in pieces:
		if e["live"]:
			n += 1
	return n


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("tiles", GoreTiles.texture())
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _exit_tree() -> void:
	if it == self:
		it = null


func _add(cell: Vector2i, donor: Enemy) -> bool:
	# A pile slumps: what lands on a spot standing well above the one beside it slides down to that one. So it
	# spreads into a mound that can be walked up, not a pillar.
	for i in 4:
		var here: int = cells.get(cell, 0)
		var low := cell
		var low_n := here
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k := Vector2i(cell.x + dx, cell.y + dz)
				var kn: int = cells.get(k, 0)
				if kn < low_n and not _is_solid(k):
					low_n = kn
					low = k
		if here - low_n < slump or low == cell:
			break
		cell = low
	var n: int = cells.get(cell, 0)
	if (n + 1) * LAYER > max_height:
		return false
	cells[cell] = n + 1
	total += 1
	_dirty = true
	if donor != null and donor.body != null and donor.body.shambler != null:
		_leave_pieces(cell, donor)
	return true


## What the crushed zombie leaves showing: up to two of its limbs or its head, where it went under. If it is one
## of those still alive in there, one of them (an arm if it has one) is its.
func _leave_pieces(cell: Vector2i, donor: Enemy) -> void:
	var alive := not donor.dead and randf() < live_chance
	var slots: Array[String] = []
	for slot in ["ArmL", "ArmR", "LegL", "LegR", "Head"]:
		var st: String = donor.body.part(slot)
		if st == "Intact" or st == "Rotted":
			slots.append(slot)
	slots.shuffle()
	if alive:
		# Its grabbing arm first (or, with no arms left, its head, which only bites).
		slots.sort_custom(func(x: String, y: String) -> bool:
			return (0 if x.begins_with("Arm") else (1 if x == "Head" else 2)) < (0 if y.begins_with("Arm") else (1 if y == "Head" else 2)))
	var left := 0
	for slot in slots:
		if left >= 3 or (left >= 1 and randf() < 0.35 and not alive):
			break
		Enemy.for_pile = true
		var node = donor.body.shambler.call("spawn_piece", slot, donor.body.part(slot), Vector3.ZERO)
		Enemy.for_pile = false
		if node == null:
			continue
		var piece := node as RigidBody3D
		# It is part of the pile now: it doesn't tumble, rot or fade.
		piece.freeze = true
		piece.collision_layer = 0
		piece.collision_mask = 0
		piece.set("rot_seconds", 0.0)
		piece.set("auto_fade", false)
		piece.set_physics_process(false)
		piece.set_process(false)
		var at := Vector3((cell.x + randf_range(0.15, 0.85)) * CELL, 0.0, (cell.y + randf_range(0.15, 0.85)) * CELL)
		at.y = height_at(at) + randf_range(-0.05, 0.06)   # half in the pile
		piece.global_transform = Transform3D(Basis.from_euler(Vector3(randf_range(-1.3, 0.4), randf() * TAU, randf_range(-0.8, 0.8))), at)
		var is_live := alive and left == 0 and slot != "LegL" and slot != "LegR"
		pieces.append({"node": piece, "slot": slot, "live": is_live})
		left += 1
	# Too many showing: the oldest dead ones are trodden under.
	var i := 0
	while pieces.size() > max_pieces and i < pieces.size():
		if not pieces[i]["live"]:
			(pieces[i]["node"] as Node).queue_free()
			pieces.remove_at(i)
		else:
			i += 1


func _valid(e: Dictionary) -> bool:
	return is_instance_valid(e["node"])


## The piece nearest `point` within `radius`, as its place in the world; or null. Alive or not: you can't tell.
func piece_near(point: Vector3, radius: float):
	var best = null
	var best_d := radius
	for e in pieces:
		if not _valid(e):
			continue
		var p: Vector3 = (e["node"] as Node3D).global_position
		var d := Vector2(p.x - point.x, p.z - point.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


## A blow on the piece at `point`. `power` is the chance it finishes one that is alive (1 = certain).
## Returns "killed" (it was alive, and isn't), "alive" (it was alive, and still is), or "dead" (it was only meat).
func stomp_at(point: Vector3, power: float) -> String:
	for e in pieces:
		if not _valid(e):
			continue
		var p: Vector3 = (e["node"] as Node3D).global_position
		if Vector2(p.x - point.x, p.z - point.z).length() < 0.35:
			if not e["live"]:
				return "dead"
			if randf() < power:
				e["live"] = false
				return "killed"
			return "alive"
	return "dead"


func _process(delta: float) -> void:
	_mesh_t -= delta
	if _dirty and _mesh_t <= 0.0:
		_dirty = false
		_mesh_t = 0.5
		_rebuild()
		_resettle()


## After the pile has grown: pieces the pile has risen over are gone (buried), and the live ones work their way
## back to the surface.
func _resettle() -> void:
	var i := 0
	while i < pieces.size():
		var e := pieces[i]
		if not _valid(e):
			pieces.remove_at(i)
			continue
		var n := e["node"] as Node3D
		var top := height_at(n.global_position)
		if e["live"]:
			n.global_position.y = top + 0.05
		elif top - n.global_position.y > 0.4:
			n.queue_free()
			pieces.remove_at(i)
			continue
		i += 1


func _physics_process(delta: float) -> void:
	_tick_t -= delta
	if _tick_t > 0.0 or pieces.is_empty():
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
		for e in pieces:
			if not e["live"] or not _valid(e):
				continue
			var n := e["node"] as Node3D
			var to: Vector3 = who.global_position - n.global_position
			to.y = 0.0
			if to.length() < grab_reach and randf() < grab_chance * 0.25:
				_grab_cd[who.get_instance_id()] = 1.5
				# It goes for them: the arm snaps out, then back. A head can only bite.
				var home := n.global_position
				var tw := create_tween()
				tw.tween_property(n, "global_position", home + to.normalized() * minf(to.length() * 0.6, 0.4) + Vector3.UP * 0.15, 0.1)
				tw.tween_property(n, "global_position", home, 0.5)
				var bites: bool = e["slot"] == "Head" or randf() < bite_chance
				who.pile_grab(to.normalized(), bite_damage if bites else 0.0)
				break


func _is_solid(cell: Vector2i) -> bool:
	if not _solid.has(cell):
		var c := Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)
		var inside := false
		for b in Cover.boxes:
			if b.on(0.0) and b.rect.has_point(c):
				inside = true
				break
		_solid[cell] = inside
	return _solid[cell]


## The mound as one mesh. Its points are the middles of the cells, each as high as that cell's pile, so the drawn
## surface is exactly the height everything stands at (height_at). Two cells out it is flat on the ground: the stain.
func _rebuild() -> void:
	var pts := {}
	for cell: Vector2i in cells:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var k := Vector2i(cell.x + dx, cell.y + dz)
				if not pts.has(k):
					pts[k] = int(cells.get(k, 0)) * LAYER
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: Vector2i in pts:
		var ks := [k, Vector2i(k.x + 1, k.y), Vector2i(k.x + 1, k.y + 1), Vector2i(k.x, k.y + 1)]
		if not (pts.has(ks[1]) and pts.has(ks[2]) and pts.has(ks[3])):
			continue
		var v: Array[Vector3] = []
		for c: Vector2i in ks:
			v.append(Vector3((c.x + 0.5) * CELL, float(pts[c]) + 0.03, (c.y + 0.5) * CELL))
		var stain := Color(1.0 if maxf(maxf(v[0].y, v[1].y), maxf(v[2].y, v[3].y)) > 0.05 else 0.0, 0, 0)
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(stain)
			st.add_vertex(v[i])
	st.generate_normals()
	_mesh.mesh = st.commit()
