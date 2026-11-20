class_name TallGrass
extends Node3D
## A patch of tall grass: somewhere to go to ground. Down low in it you are much harder to see (Player.seen_mult):
## flat on the ground most of all, crouched somewhat, standing not at all. It hides nothing from you, and
## nothing else uses it yet (zombies and raiders don't hide in it).
## The look is a stand-in: plain blades scattered over the patch. The real grass is for the art pass.

static var patches: Array[Rect2] = []

@export var area := Rect2(0, 0, 8, 6)     # on the ground: position (x, z), size (x, z)
@export var height := 0.95
@export var blades_per_m2 := 14.0


static func clear() -> void:
	patches.clear()


## Is this spot in tall grass?
static func at(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for r in patches:
		if r.has_point(p):
			return true
	return false


func _ready() -> void:
	patches.append(area)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, height, 0.16)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	blade.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	var n := int(area.size.x * area.size.y * blades_per_m2)
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(area)
	for i in n:
		var x := area.position.x + rng.randf() * area.size.x
		var z := area.position.y + rng.randf() * area.size.y
		var s := rng.randf_range(0.6, 1.15)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(1.0, s, 1.0)), Vector3(x, height * s * 0.5, z)))
		# Summer grass: greens going to straw at the tips of the range.
		mm.set_instance_color(i, Color(0.36, 0.5, 0.22).lerp(Color(0.62, 0.6, 0.3), rng.randf() * 0.7))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _exit_tree() -> void:
	patches.erase(area)
