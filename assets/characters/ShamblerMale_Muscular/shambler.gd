# ShamblerMale_Muscular spawner for Godot 4.
# Rolls one part per slot (Head, Torso, ArmL, ArmR, LegL, LegR) so every shambler looks different, and rolls how
# long he's been dead (his Freshness): fresh ones are pale and drained, older ones go green, then black, then leathery.
# A destroyed leg makes a crawler: read is_crawler (or listen to `rolled`) to pick crawler movement and animations.
# Head_Decapitated is never rolled at spawn. Call dismember("Head") when a hit takes the head off.
# With pieces_scene set, dismember() also throws off the part that came away (the forearm and hand, the lower leg and
# foot, or the head) as a physics piece (shambler_piece.gd) that starts exactly where that part was, with the hand or
# foot in the pose it had. Its joints then move like a dead limb's, and it rots and fades away.
#
# Use: make a scene from ShamblerMale_Muscular.glb (New Inherited Scene), attach this script to its root, save it.
# Each instance of that scene rolls itself when it enters the tree.
# Needs freshness.gd, living_body.gd and anatomy_map.gd somewhere in the project (they register the Freshness,
# LivingBody and AnatomyMap classes).
extends Node3D

signal rolled(parts: Dictionary, crawler: bool)
signal dismembered(slot: String, crawler: bool)
signal piece_spawned(slot: String, piece: ShamblerPiece)

const SLOTS := ["Head", "Torso", "ArmL", "ArmR", "LegL", "LegR"]
const STATES := ["Intact", "Rotted", "Destroyed"]   # what a spawn can roll
const PLAY_STATES := {"Head": ["Decapitated"]}       # only switched to in play

@export var roll_on_ready := true
## -1 rolls a new shambler every time. Any other number always gives the same shambler.
@export var roll_seed := -1
@export_range(0.0, 1.0) var chance_rotted := 0.4
@export_range(0.0, 1.0) var chance_destroyed := 0.15
## Most legs one shambler can lose (0, 1 or 2). Two lost legs still crawls, on the arms alone.
@export_range(0, 2) var max_lost_legs := 1

@export_group("Freshness")
## How often each stage of decay is rolled at spawn. Set a stage to 0 to never roll it.
@export var stage_weights := {"Fresh": 2, "Rigor": 2, "Bloated": 3, "Putrid": 3, "Dried": 1}
## Fresh bodies haven't had time to rot: at Freshness 1 the Rotted chance is scaled by this, rising to
## rotted_scale_old for the oldest. Fresh "Rotted" parts read as fresh bites and tears, wet and red.
@export var rotted_scale_fresh := 0.6
@export var rotted_scale_old := 1.25
## Who he was: which skin tone groups to roll from, and an extra weight on each look (freckles, clean shaven,
## hairy, old, vitiligo), the same as on a living body. Tones, looks and hair come from living_body.gd.
@export var groups: Array[String] = ["european", "african", "latin", "asian", "mideast_southasia"]
@export var variant_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]
## Range of grime (mud, dust, stains and smears): 0 clean, 1 caked.
@export var grime_range := Vector2(0.1, 0.9)
## Range of blood spattered on the hands, arms and chest.
@export var gore_range := Vector2(0.15, 0.85)
@export var skin_shader: Shader = preload("zombie_decay.gdshader")

## Draw the parts shown as one merged mesh (one draw call, one shadow, one set of per-shambler shader values) instead
## of 6 or 7 separate ones. Shamblers with the same model and the same parts share the merged mesh; a new mix is
## built once, the first time it's needed (when a part comes off, too). Off: the part meshes are shown as they are.
@export var merge_parts := true

@export_group("Pieces")
## ShamblerMale_Muscular_Pieces.glb (or _mid or _low). When set, dismember() throws off the part that came away as a
## physics piece, made from that part as it looked (Intact or Rotted, or a Destroyed head).
@export var pieces_scene: PackedScene
## Where the pieces are added. Empty: this shambler's parent.
@export var pieces_parent: NodePath
## The pieces' shader: zombie_decay.gdshader's twin that can fade them away.
@export var piece_shader: Shader = preload("zombie_decay_piece.gdshader")
## Real seconds for a piece to rot from fully fresh to nothing, then fade away. 0: pieces don't rot by themselves.
@export var piece_rot_seconds := 180.0
## Seconds a rotted piece takes to fade away.
@export var piece_fade_seconds := 3.0
## Pieces fade away and free themselves once rotted. Off: they only send rotted_away, for the game to deal with.
@export var piece_auto_fade := true

var parts := {}          # slot -> state shown now
var is_crawler := false
var is_decapitated := false
var freshness: Freshness  # how long he's been dead; call freshness.age(hours) to let him rot further
var skin_tone := 1       # who he was: the same values as a living body's look (see living_body.gd)
var variant := 1
var hair_color := 2
var look_seed := 0.0
var decay_seed := 0.0
var gore := 0.5
var grime := 0.5
var neck_blood := 0.0    # set from the head's state: 1 decapitated, less for a torn neck

var _meshes := {}        # "Slot_State" -> MeshInstance3D
var _merged: MeshInstance3D   # the parts shown, as one mesh (merge_parts)
static var _merged_cache := {}   # "model id|Head_Intact|Torso_Rotted|..." -> ArrayMesh, shared by every shambler with that mix
var _skeleton: Skeleton3D
static var _material: ShaderMaterial
const PIECE_BONE := {"Head": "Head", "ArmL": "ForearmRollL", "ArmR": "ForearmRollR", "LegL": "CalfL", "LegR": "CalfR"}
const PIECE_MASS := {"Head": 5.0, "Arm": 1.2, "Leg": 3.5}   # kg
static var _piece_material: ShaderMaterial
static var _piece_kinds := {}    # pieces scene path -> {"ArmL_Intact": [PackedScene, joints, capsules], ...}
static var _piece_shapes := {}   # Mesh -> its collision shape (heads)


func _ready() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var key := String(m.name)
		var bits := key.split("_")
		if bits.size() == 2 and bits[0] in SLOTS and (bits[1] in STATES or bits[1] in PLAY_STATES.get(bits[0], [])):
			_meshes[key] = m
	var sks := find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_skeleton = sks[0]
	var expected := SLOTS.size() * STATES.size()
	for slot in PLAY_STATES:
		expected += PLAY_STATES[slot].size()
	if _meshes.size() != expected:
		push_warning("Shambler: expected %d part meshes, found %d" % [expected, _meshes.size()])
	if _material == null and skin_shader != null:
		_material = ShaderMaterial.new()
		_material.shader = skin_shader
		_material.set_shader_parameter("anatomy_map", AnatomyMap.texture())   # what the shader paints inside the torso's wounds
	# The skin, and its per-shambler values, go only on the parts being shown (show_parts), never on hidden ones:
	# the renderer reserves a block of 16 per-object shader values for every mesh that has any set, hidden or not,
	# so 6 or 7 parts instead of 19 lets about three times as many shamblers on screen.
	if roll_on_ready:
		roll()


## Roll a new look. Pass slots to force, e.g. roll({"LegL": "Destroyed"}), and a freshness (0..1) to force how
## long he's been dead, e.g. roll({}, 1.0) for one who just turned.
func roll(forced := {}, fresh := -1.0) -> void:
	var rng := RandomNumberGenerator.new()
	if roll_seed >= 0:
		rng.seed = roll_seed
	else:
		rng.randomize()
	var f := fresh if fresh >= 0.0 else Freshness.roll(rng, stage_weights)
	var rotted := chance_rotted * lerpf(rotted_scale_fresh, rotted_scale_old, 1.0 - f)
	var lost_legs := 0
	for slot in SLOTS:
		if forced.has(slot) and forced[slot] == "Destroyed" and slot.begins_with("Leg"):
			lost_legs += 1
	var picked := {}
	for slot in SLOTS:
		var state: String
		if forced.has(slot):
			state = forced[slot]
		else:
			var r := rng.randf()
			if r < chance_destroyed:
				state = "Destroyed"
			elif r < chance_destroyed + rotted:
				state = "Rotted"
			else:
				state = "Intact"
			if state == "Destroyed" and slot.begins_with("Leg"):
				if lost_legs >= max_lost_legs:
					state = "Rotted"
				else:
					lost_legs += 1
		picked[slot] = state
	var l := LivingBody.roll_look(rng, groups, variant_weights)
	set_skin(f, l.tone, l.variant, l.hair, l.seed, rng.randf_range(0.0, 100.0), rng.randf_range(gore_range.x, gore_range.y),
		rng.randf_range(grime_range.x, grime_range.y))
	show_parts(picked)


## Set how he looks: freshness 0..1 (1 = just turned), who he was (skin tone, look and hair color, and the seed that
## places their freckles, vitiligo and hair, all as on a living body), a seed for the blotches and stains of the rot,
## how bloody he is (0..1) and how dirty (0..1).
func set_skin(fresh: float, tone := 1, look := 1, hair := 2, look_seed_value := 0.0, decay_seed_value := 0.0,
		blood := 0.5, dirt := 0.5) -> void:
	if freshness != null and freshness.changed.is_connected(_apply_skin):
		freshness.changed.disconnect(_apply_skin)
	freshness = Freshness.new(fresh)
	freshness.changed.connect(_apply_skin)
	skin_tone = tone
	variant = look
	hair_color = hair
	look_seed = look_seed_value
	decay_seed = decay_seed_value
	gore = blood
	grime = dirt
	_apply_skin()


## Become the same zombie as `other` (another shambler, e.g. the same one at another detail level): the same parts,
## the same Freshness (shared, so it keeps rotting as one), the same person and the same blood and grime.
func copy_look(other: Node3D) -> void:
	if freshness != null and freshness.changed.is_connected(_apply_skin):
		freshness.changed.disconnect(_apply_skin)
	freshness = other.freshness
	if freshness != null:
		freshness.changed.connect(_apply_skin)
	skin_tone = other.skin_tone
	variant = other.variant
	hair_color = other.hair_color
	look_seed = other.look_seed
	decay_seed = other.decay_seed
	gore = other.gore
	grime = other.grime
	show_parts(other.parts)
	_apply_skin()


## Turn a living person into this shambler: same skin tone, freckles, vitiligo, age and hair, just turned.
func turn_from(person: LivingBody, fresh := 1.0) -> void:
	set_skin(fresh, person.skin_tone, person.variant, person.hair_color, person.look_seed, randf_range(0.0, 100.0), gore, grime)


## Show an exact set of parts, e.g. show_parts({"Head": "Rotted", "Torso": "Destroyed", ...}).
## Slots left out stay Intact.
func show_parts(picked: Dictionary) -> void:
	parts = {}
	for slot in SLOTS:
		parts[slot] = picked.get(slot, "Intact")
	is_crawler = parts["LegL"] == "Destroyed" or parts["LegR"] == "Destroyed"
	is_decapitated = parts["Head"] == "Decapitated"
	var shown_keys: Array[String] = []
	for key in _meshes:
		var bits := String(key).split("_")
		var shown: bool = parts[bits[0]] == bits[1]
		if shown:
			shown_keys.append(key)
		_meshes[key].visible = shown and not merge_parts
		_meshes[key].material_override = _material if shown and not merge_parts else null
	if merge_parts:
		_show_merged(shown_keys)
	# a head that's off, or a torn neck, bleeds down over the shoulders, chest and back
	neck_blood = {"Decapitated": 1.0, "Destroyed": 0.5, "Rotted": 0.3}.get(parts["Head"], 0.0)
	_apply_skin()
	rolled.emit(parts, is_crawler)


## Take a part off in play: the head becomes the decapitated neck stump, an arm or leg becomes Destroyed.
## Losing a leg turns the shambler into a crawler. With pieces_scene set, the part that came away flies off as a
## physics piece (also sent with piece_spawned), pushed by `impulse`; the piece is returned, or null.
func dismember(slot: String, impulse := Vector3.ZERO) -> ShamblerPiece:
	if not slot in SLOTS or slot == "Torso":
		push_warning("Shambler: can't dismember %s" % slot)
		return null
	var before: String = parts.get(slot, "Intact")
	var next := parts.duplicate()
	next[slot] = "Decapitated" if slot == "Head" else "Destroyed"
	show_parts(next)
	var piece: ShamblerPiece = null
	if before != next[slot]:
		piece = spawn_piece(slot, before, impulse)
	dismembered.emit(slot, is_crawler)
	return piece


## Make the loose piece for a part that came off: `slot`, and the state it was in before (Intact or Rotted, or for the
## head also Destroyed). It starts exactly where that part was on the body, with the hand or foot in the pose it had and
## with this shambler's look, as a ShamblerPiece (a RigidBody3D with a convex collision shape). Returns null without
## pieces_scene, or for a state with no piece.
func spawn_piece(slot: String, from_state: String, impulse := Vector3.ZERO) -> ShamblerPiece:
	if pieces_scene == null or _skeleton == null or not PIECE_BONE.has(slot):
		return null
	var kind: Array = _pieces().get("%s_%s" % [slot, from_state], [])
	var bone := _skeleton.find_bone(PIECE_BONE[slot])
	if kind.is_empty() or bone < 0:
		return null
	var piece_node: Node3D = (kind[0] as PackedScene).instantiate()
	piece_node.transform = Transform3D.IDENTITY
	var body := ShamblerPiece.new()
	body.name = "%s_piece" % slot
	body.slot = slot
	body.from_state = from_state
	body.mass = PIECE_MASS["Head" if slot == "Head" else slot.left(3)]
	body.rot_seconds = piece_rot_seconds
	body.fade_seconds = piece_fade_seconds
	body.auto_fade = piece_auto_fade
	body.add_child(piece_node)
	var mi: MeshInstance3D = piece_node.find_children("*", "MeshInstance3D", true, false)[0]
	if _piece_material == null and piece_shader != null:
		_piece_material = ShaderMaterial.new()
		_piece_material.shader = piece_shader
		_piece_material.set_shader_parameter("anatomy_map", AnatomyMap.texture())
	mi.material_override = _piece_material
	# an arm or leg collides as two rounded capsules (along the forearm or shin, and the hand or foot), so it can't
	# stand on its flat cut; a head as its convex hull
	var capsules: Array = kind[2]
	if capsules.is_empty():
		var cs := CollisionShape3D.new()
		if not _piece_shapes.has(mi.mesh):
			_piece_shapes[mi.mesh] = mi.mesh.create_convex_shape(true, true)
		cs.shape = _piece_shapes[mi.mesh]
		body.add_child(cs)
	for c in capsules:
		var a := Vector3(c["a"][0], c["a"][1], c["a"][2])
		var b := Vector3(c["b"][0], c["b"][1], c["b"][2])
		var shape := CapsuleShape3D.new()
		shape.radius = c["r"]
		shape.height = a.distance_to(b) + 2.0 * shape.radius
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var up := (b - a).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		cs.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
		body.add_child(cs)
	var host: Node = get_node_or_null(pieces_parent) if not pieces_parent.is_empty() else get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(body)
	# the piece is modelled in its bone's frame, so the bone's pose puts it exactly where the part was
	var t := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	body.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	# and the hand or foot takes the pose it had on the body (the bones have the same names)
	var psk: Skeleton3D = piece_node.get_node("Skeleton3D")
	for i in psk.get_bone_count():
		var src := _skeleton.find_bone(psk.get_bone_name(i))
		if src >= 0 and psk.get_bone_parent(i) >= 0:
			psk.set_bone_pose_rotation(i, _skeleton.get_bone_pose_rotation(src))
	_skin_params(mi)
	mi.set_instance_shader_parameter("dissolve", 0.0)
	body.setup(piece_node, kind[1], freshness.value if freshness != null else 1.0)
	if impulse != Vector3.ZERO:
		body.apply_central_impulse(impulse)
	piece_spawned.emit(slot, body)
	return body


# The pieces file, split into one small scene per piece (its skeleton and mesh), with its joint ranges.
func _pieces() -> Dictionary:
	var key := pieces_scene.resource_path
	if not _piece_kinds.has(key):
		var found := {}
		var inst := pieces_scene.instantiate()
		var kinds := inst.find_children("*", "Node3D", true, false).filter(func(n): return n.has_meta("extras") and n.has_node("Skeleton3D"))
		for n in kinds:
			n.get_parent().remove_child(n)
			for d in n.find_children("*", "", true, false):
				d.owner = n
			var ps := PackedScene.new()
			ps.pack(n)
			var ex: Dictionary = n.get_meta("extras")
			found[String(n.name)] = [ps, ex.get("joints", []), ex.get("shapes", [])]
			n.free()
		inst.free()
		_piece_kinds[key] = found
	return _piece_kinds[key]


## Decay stage name: "Fresh", "Rigor", "Bloated", "Putrid" or "Dried".
func stage() -> String:
	return freshness.stage() if freshness != null else "Fresh"


## Rigor mortis right now, 0 loose to 1 fully stiff. Highest in the Rigor stage; use it for stiff, jerky movement.
func rigor() -> float:
	return freshness.rigor() if freshness != null else 0.0


func _apply_skin() -> void:
	for m in shown_meshes():
		_skin_params(m)


## The mesh instances that carry the skin now: the merged mesh, or with merge_parts off the part meshes shown.
func shown_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if merge_parts:
		if _merged != null:
			out.append(_merged)
		return out
	for m in _meshes.values():
		if m.visible and m.material_override != null:   # only the parts shown (see _ready)
			out.append(m)
	return out


# Show the given part meshes as one merged mesh, built (or found in the cache) for exactly that mix.
func _show_merged(keys: Array[String]) -> void:
	if keys.is_empty() or _skeleton == null:
		return
	keys.sort()
	var first: MeshInstance3D = _meshes[keys[0]]
	var id := "%d|%s" % [first.mesh.get_instance_id(), "|".join(keys)]
	var mesh: ArrayMesh = _merged_cache.get(id)
	if mesh == null:
		var parts_list: Array[Mesh] = []
		for k in keys:
			parts_list.append((_meshes[k] as MeshInstance3D).mesh)
		mesh = merge_meshes(parts_list)
		_merged_cache[id] = mesh
		if _merged_cache.size() > 160:
			_prune_merged_cache()
	if _merged == null:
		_merged = MeshInstance3D.new()
		_merged.name = "Merged"
		_skeleton.add_child(_merged)
		_merged.skeleton = NodePath("..")
		_merged.skin = first.skin
		_merged.extra_cull_margin = first.extra_cull_margin
		_merged.lod_bias = first.lod_bias
	_merged.mesh = mesh
	_merged.material_override = _material
	_merged.visible = true


## One mesh of one surface from several skinned meshes on the same skeleton (same skin, same vertex format).
static func merge_meshes(meshes: Array[Mesh]) -> ArrayMesh:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var fmt := 0
	var base := 0
	var idx := PackedInt32Array()
	for m in meshes:
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			fmt |= m.surface_get_format(s)
			var n: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for k in Mesh.ARRAY_MAX:
				if k == Mesh.ARRAY_INDEX or a[k] == null:
					continue
				if out[k] == null:
					out[k] = a[k].duplicate()
				else:
					out[k].append_array(a[k])
			var src: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(n))
			var at := idx.size()
			idx.resize(at + src.size())
			for i in src.size():
				idx[at + i] = src[i] + base
			base += n
	out[Mesh.ARRAY_INDEX] = idx
	# keep the custom channels' formats (the rest position the shader paints from) and the bone-weight count
	var keep := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,
			Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
		keep |= Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, fmt & keep)
	return am


# Drop merged meshes no shambler uses any more (only the cache holds them).
static func _prune_merged_cache() -> void:
	for id in _merged_cache.keys():
		if (_merged_cache[id] as ArrayMesh).get_reference_count() <= 1:
			_merged_cache.erase(id)


func _skin_params(m: GeometryInstance3D) -> void:
	var f := freshness.value if freshness != null else 1.0
	m.set_instance_shader_parameter("freshness", f)
	m.set_instance_shader_parameter("skin_tone", skin_tone)
	m.set_instance_shader_parameter("variant", variant)
	m.set_instance_shader_parameter("hair_color", hair_color)
	m.set_instance_shader_parameter("look_seed", look_seed)
	m.set_instance_shader_parameter("decay_seed", decay_seed)
	m.set_instance_shader_parameter("gore", gore)
	m.set_instance_shader_parameter("grime", grime)
	m.set_instance_shader_parameter("neck_blood", neck_blood)
