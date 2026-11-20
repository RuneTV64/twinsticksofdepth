class_name GrassBlades
extends MultiMeshInstance3D
## Standing grass: tufts of blades scattered over the ground, one draw call a patch (grass_blades.gdshader).
##
##   add_child(GrassBlades.in_rect("meadow", Rect2(4, -16, 14, 9)))      # a patch
##   add_child(GrassBlades.at_points("tall", points))                    # tufts where you say (x, z)
##   Ground.it.grow_grass()                                              # everywhere the ground is painted as grass
##
## The kinds are in KINDS. A tuft is a few tapered blades leaning out from a point; the mesh for each kind is made
## once and shared. Blades follow the season with the ground (seasons.gd) and part round the player (grass_push).

## height (m), blades in a tuft, how far the tuft spreads at its foot (m), how far the tips lean out (of the
## height), blade width at the foot (m), tufts to the square metre, how much more straw than the season makes.
const KINDS := {
	"short": {"h": 0.2, "blades": 5, "spread": 0.07, "lean": 0.5, "w": 0.045, "density": 18.0, "straw": -0.1},
	"meadow": {"h": 0.5, "blades": 6, "spread": 0.09, "lean": 0.35, "w": 0.05, "density": 14.0, "straw": 0.0},
	"tall": {"h": 1.0, "blades": 7, "spread": 0.1, "lean": 0.3, "w": 0.06, "density": 12.0, "straw": 0.1},
	"tussock": {"h": 0.38, "blades": 10, "spread": 0.16, "lean": 0.6, "w": 0.05, "density": 2.2, "straw": 0.25},
}

static var _meshes := {}
static var _materials := {}
static var _shader: Shader


## A patch of one kind over a rectangle (x, z). `density` tufts to the square metre (0 = the kind's own).
## Nothing grows inside the level's solid boxes (cover.gd).
static func in_rect(kind: String, r: Rect2, density := 0.0, seed_value := 0) -> GrassBlades:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(r) + seed_value
	var n := int(r.size.x * r.size.y * (density if density > 0.0 else float(KINDS[kind]["density"])))
	var pts := PackedVector2Array()
	for i in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		if Cover.has_room(p, null):
			pts.append(p)
	return at_points(kind, pts, seed_value)


## Tufts of one kind at these places (x, z).
static func at_points(kind: String, points: PackedVector2Array, seed_value := 0) -> GrassBlades:
	var g := GrassBlades.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh(kind)
	mm.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + seed_value + points.size()
	for i in points.size():
		var s := rng.randf_range(0.75, 1.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.15), s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(points[i].x, 0.0, points[i].y)))
	g.multimesh = mm
	g.material_override = _material(kind)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Blades lean and part beyond where they were scattered: don't let them be culled early.
	g.extra_cull_margin = 2.0
	return g


static func _material(kind: String) -> ShaderMaterial:
	if not _materials.has(kind):
		if _shader == null:
			_shader = load("res://assets/ground/grass_blades.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("straw_bias", float(KINDS[kind]["straw"]))
		_materials[kind] = m
	return _materials[kind]


## One tuft: blades leaning out from near a point. Each blade is a tapered strip in two pieces, so it can bend.
## UV: x = the blade's own random number (its shade, and whether it goes to straw early), y = 0 foot .. 1 tip.
static func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var k: Dictionary = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for b in int(k["blades"]):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))              # the way it leans
		var across := Vector3(-out.z, 0.0, out.x)             # its flat side faces along its lean
		var foot := out * float(k["spread"]) * rng.randf()
		var tall := float(k["h"]) * rng.randf_range(0.6, 1.0)
		var lean := float(k["lean"]) * rng.randf_range(0.3, 1.0)
		var rnd := rng.randf()
		var base := verts.size()
		for i in 3:
			var h := i * 0.5
			var mid := foot + Vector3.UP * tall * h + out * tall * lean * h * h
			var w := float(k["w"]) * (1.0 - 0.85 * h) * 0.5
			verts.append(mid - across * w)
			verts.append(mid + across * w)
			for j in 2:
				uvs.append(Vector2(rnd, h))
				norms.append(Vector3.UP)
		for i in 2:
			var q := base + i * 2
			idx.append_array([q, q + 1, q + 2, q + 1, q + 3, q + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# The shader moves the blades (wind, parting, the season's height): give the mesh room so it isn't culled.
	mesh.custom_aabb = AABB(Vector3(-1.2, -0.1, -1.2), Vector3(2.4, float(k["h"]) * 1.4 + 0.3, 2.4))
	_meshes[kind] = mesh
	return mesh
