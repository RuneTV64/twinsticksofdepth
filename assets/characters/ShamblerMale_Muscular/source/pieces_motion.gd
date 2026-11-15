extends Node3D
## Limp-limb test. env FRESH (shambler freshness), MODE=motion (frames over time, wrist and ankle angles) or rot
## (fast rot and fade), OUT prefix.
var out := ""
var pieces := []
var mats := {}
func patched(path: String) -> Shader:
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	return sh
func shot(n: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, n])
var follow_cam: Camera3D
func _process(_d: float) -> void:
	if follow_cam and not pieces.is_empty() and is_instance_valid(pieces[0]):
		var c: Vector3 = pieces[0].global_transform * (pieces[0].mesh.mesh.get_aabb().get_center())
		follow_cam.size = 0.6; follow_cam.position = c + Vector3(0.0, 0.25, 3.0); follow_cam.look_at(c)
	for p in pieces:   # this test renderer ignores per-instance values, so each piece gets its own material
		if is_instance_valid(p) and mats.has(p):
			mats[p].set_shader_parameter("freshness", p.freshness.value)
			mats[p].set_shader_parameter("dissolve", clampf(p._fading, 0.0, 1.0))
func joint_angles(p) -> String:
	var parts := []
	for l in p._links:
		if l["finger"] and not String(p.skeleton.get_bone_name(l["b"])).ends_with("1"): continue
		var pg: Transform3D = p.skeleton.get_bone_global_pose(l["p"])
		var rp: Basis = (p.skeleton.global_transform.basis * pg.basis).orthonormalized()
		var joint: Vector3 = p.skeleton.global_transform * (pg * (p._rest[l["b"]] - p._rest[l["p"]]))
		parts.append("%s %d" % [p.skeleton.get_bone_name(l["b"]), roundi(rad_to_deg((rp * l["d0"]).angle_to(l["pos"] - joint)))])
	return ", ".join(parts.slice(0, 4))
func _ready() -> void:
	out = OS.get_environment("OUT")
	var mode := OS.get_environment("MODE")
	var fresh := float(OS.get_environment("FRESH"))
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(30/255.0, 25/255.0, 36/255.0); add_child(env)
	var floor := StaticBody3D.new(); var fs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(10, 0.2, 10); fs.shape = bx; floor.add_child(fs); floor.position.y = -0.1; add_child(floor)
	var fm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); fm.mesh = pm; var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.2, 0.18, 0.16); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.material_override = fmat; add_child(fm)
	var sh: Node3D = load("res://shambler.glb").instantiate()
	sh.set_script(load("res://shambler.gd"))
	sh.set("roll_on_ready", false)
	sh.set("skin_shader", patched("res://zombie_decay.gdshader"))
	sh.set("piece_shader", patched("res://zombie_decay_piece.gdshader"))
	sh.set("pieces_scene", load("res://pieces.glb"))
	if mode == "rot": sh.set("piece_rot_seconds", 4.0); sh.set("piece_fade_seconds", 1.2)
	add_child(sh)
	sh.call("roll", {"Head": "Intact", "Torso": "Intact", "ArmL": "Intact", "ArmR": "Intact", "LegL": "Intact", "LegR": "Intact"}, fresh)
	var params := {"skin_tone": 1, "variant": 1, "hair_color": 2, "look_seed": 5.0, "freshness": fresh, "decay_seed": 3.0, "gore": 0.3, "grime": 0.2, "neck_blood": 0.0}
	var bm: ShaderMaterial = sh.find_children("*", "MeshInstance3D", true, false)[0].material_override
	for k in params: bm.set_shader_parameter(k, params[k])
	var sk: Skeleton3D = sh.find_children("*", "Skeleton3D", true, false)[0]
	var rot := func(b: String, axis: Vector3, a: float): var i := sk.find_bone(b); sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(axis.normalized(), a))
	rot.call("UpperArmL", Vector3(0, 0, 1), 1.25)          # arm out to the side, about level
	rot.call("ThighR", Vector3(1, 0, 0), -1.1); rot.call("CalfR", Vector3(1, 0, 0), 0.4)   # leg lifted forward
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.7; add_child(cam); cam.position = Vector3(0.4, 0.9, 5); cam.look_at(Vector3(0.4, 0.75, 0)); cam.make_current()
	await get_tree().process_frame
	var throw := {"ArmL": Vector3(0.6, 1.2, 0.5), "LegR": Vector3(0.3, 1.6, 1.0)}
	for s in OS.get_environment("SLOTS").split(","):
		var p = sh.call("dismember", s, Vector3.ZERO)
		p.apply_central_impulse(throw[s] * p.mass); p.apply_torque_impulse(Vector3(0.0, 0.0, 0.08 if s == "ArmL" else -0.15))
		pieces.append(p)
		var m: ShaderMaterial = p.mesh.material_override.duplicate(); p.mesh.material_override = m
		for k in params: m.set_shader_parameter(k, params[k])
		mats[p] = m
	for m in sh.find_children("*", "MeshInstance3D", true, false): m.visible = false   # only the pieces
	if OS.get_environment("FOLLOW") == "1": follow_cam = cam
	var times := [0.0, 0.15, 0.3, 0.45, 0.7, 3.0] if mode != "rot" else [0.6, 1.5, 2.5, 3.5, 4.4, 4.75, 5.2]
	var t := 0.0
	for k in times.size():
		while t < times[k]:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		await shot("%d" % k)
		var alive := pieces.filter(func(p): return is_instance_valid(p))
		print("t=%.2f  " % t, "  |  ".join(alive.map(func(p): return "%s fresh %.2f %s: %s" % [p.slot, p.freshness.value, p.freshness.stage(), joint_angles(p)])), "  (pieces left: %d)" % alive.size())
	get_tree().quit()
