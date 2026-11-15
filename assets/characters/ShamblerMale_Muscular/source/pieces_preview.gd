extends Node3D
## Pieces test. env MODE=sheet: every piece, front and cut face. MODE=live: a posed shambler loses an arm, a leg and
## its head; renders before, just after (the pieces should sit where the parts were) and after they fall. OUT = prefix.
const PARAMS := {"skin_tone": 1, "variant": 1, "hair_color": 2, "look_seed": 5.0, "freshness": 0.95, "decay_seed": 3.0, "gore": 0.3, "grime": 0.2, "neck_blood": 1.0}
var out := ""
func patched() -> Shader:
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string("res://zombie_decay.gdshader").replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	return sh
func mat_with(p: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = patched()
	for k in p: m.set_shader_parameter(k, p[k])
	m.set_shader_parameter("anatomy_map", AnatomyMap.texture())
	return m
func cam(pos: Vector3, look: Vector3, size: float) -> void:
	var c := Camera3D.new(); c.projection = Camera3D.PROJECTION_ORTHOGONAL; c.size = size; add_child(c); c.position = pos; c.look_at(look); c.near = 0.01; c.make_current()
func shot(n: String) -> void:
	for k in 3: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, n])
func _ready() -> void:
	out = OS.get_environment("OUT")
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(30/255.0, 25/255.0, 36/255.0); add_child(env)
	if OS.get_environment("MODE") == "sheet": await sheet()
	else: await live()
	get_tree().quit()
func sheet() -> void:
	var inst: Node3D = load(OS.get_environment("GLB")).instantiate()
	var meshes := {}
	for m in inst.find_children("*", "MeshInstance3D", true, false): meshes[String(m.name)] = m.mesh
	var order := ["ArmL_Intact", "ArmL_Rotted", "ArmR_Intact", "ArmR_Rotted", "LegL_Intact", "LegL_Rotted", "LegR_Intact", "LegR_Rotted", "Head_Intact", "Head_Rotted", "Head_Destroyed"]
	var m := mat_with(PARAMS)
	var holders := []
	for i in order.size():
		var mi := MeshInstance3D.new(); mi.mesh = meshes[order[i]]; mi.material_override = m
		var h := Node3D.new(); add_child(h); h.add_child(mi)
		var c := mi.mesh.get_aabb().get_center(); mi.position = -c
		h.position = Vector3((i - 5) * 0.3, 0, 0)
		holders.append([h, order[i]])
	var only := OS.get_environment("ONLY")
	if only != "":
		for hv in holders: hv[0].visible = String(hv[1]) in only.split(",")
		var k := 0
		for hv in holders:
			if hv[0].visible: hv[0].position.x = (k - 1) * 0.3; k += 1
	cam(Vector3(0, 0, 5), Vector3.ZERO, 0.62 if only == "" else 0.3)
	await shot("front")
	# turn each piece so its cut faces up and toward the camera: limbs were cut across the top, the head across the bottom
	for hv in holders:
		var head: bool = String(hv[1]).begins_with("Head")
		hv[0].rotation = Vector3(-PI * 0.75 if head else PI * 0.25, 0.3, 0)   # cut face up toward the light, and toward the camera
	await shot("cut")
func live() -> void:
	var floor := StaticBody3D.new(); var fs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(10, 0.2, 10); fs.shape = bx; floor.add_child(fs); floor.position.y = -0.1; add_child(floor)
	var fm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); fm.mesh = pm; var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.2, 0.18, 0.16); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.material_override = fmat; add_child(fm)
	var sh: Node3D = load("res://shambler.glb").instantiate()
	var script: Script = load("res://shambler.gd")
	sh.set_script(script)
	sh.set("roll_on_ready", false)
	sh.set("skin_shader", patched())
	sh.set("pieces_scene", load(OS.get_environment("GLB")))
	add_child(sh)
	sh.call("roll", {"Head": "Destroyed", "Torso": "Intact", "ArmL": "Rotted", "ArmR": "Intact", "LegL": "Intact", "LegR": "Intact"}, 0.95)
	var mat: ShaderMaterial = sh.find_children("*", "MeshInstance3D", true, false)[0].material_override
	for k in PARAMS: mat.set_shader_parameter(k, PARAMS[k])
	# a pose, so the pieces have to follow the bones, not just the rest pose
	var sk: Skeleton3D = sh.find_children("*", "Skeleton3D", true, false)[0]
	var rot := func(b: String, axis: Vector3, a: float): var i := sk.find_bone(b); sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(axis.normalized(), a))
	rot.call("UpperArmL", Vector3(0, 0, 1), 0.9); rot.call("ForearmL", Vector3(1, 0, 0), -0.9)
	rot.call("ThighR", Vector3(1, 0, 0), -0.5); rot.call("CalfR", Vector3(1, 0, 0), 0.7)
	rot.call("Neck", Vector3(0, 0, 1), 0.25)
	cam(Vector3(1.6, 1.3, 4.2), Vector3(0.1, 0.85, 0), 2.2)
	await shot("0before")
	var got := []
	for s in [["ArmL", Vector3(1.2, 1.0, 0.6)], ["LegR", Vector3(-0.6, 0.4, 1.2)], ["Head", Vector3(0.4, 2.0, 0.8)]]:
		var p: RigidBody3D = sh.call("dismember", s[0], s[1] * 0.0)
		got.append([s[0], p])
	for g in got: if g[1]: g[1].freeze = true   # hold them still for the "just after" frame
	print("pieces: ", got.map(func(g): return "%s=%s" % [g[0], g[1].name if g[1] else "none"]))
	for g in got:
		var p: RigidBody3D = g[1]
		var mi: MeshInstance3D = p.get_child(0)
		var ab := p.global_transform * mi.mesh.get_aabb()
		print(g[0], " at ", p.global_position.snapped(Vector3.ONE * 0.001), " world box ", ab.position.snapped(Vector3.ONE * 0.01), " size ", ab.size.snapped(Vector3.ONE * 0.01), " scale ", p.global_transform.basis.get_scale().snapped(Vector3.ONE * 0.01), " mesh surfaces ", mi.mesh.get_surface_count(), " verts ", mi.mesh.surface_get_array_len(0))
	var hb := sk.find_bone("Head"); print("Head bone ", hb, " pose origin ", sk.get_bone_global_pose(hb).origin.snapped(Vector3.ONE * 0.001), " rest ", sk.get_bone_global_rest(hb).origin.snapped(Vector3.ONE * 0.001), " skeleton xf ", sk.global_transform.origin)
	await shot("1after")
	for g in got: if g[1]: g[1].freeze = false
	for g in got:
		if g[1]: g[1].apply_central_impulse({"ArmL": Vector3(1.0, 0.8, 0.5), "LegR": Vector3(-0.8, 0.5, 1.4), "Head": Vector3(0.6, 1.5, 1.0)}[g[0]] * g[1].mass)
	for k in 150: await get_tree().physics_frame
	for g in got: if g[1]: print(g[0], " came to rest at ", g[1].global_position.snapped(Vector3.ONE * 0.01), " sleeping=", g[1].sleeping)
	await shot("2fallen")
