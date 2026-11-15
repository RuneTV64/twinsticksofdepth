extends Node3D
## Test harness: env CFG = json file {shader, glb, w, h, views:[yaw...], out, zombies:[{parts:{}, params:{}, pose:{}}]}
const SLOTS := ["Head", "Torso", "ArmL", "ArmR", "LegL", "LegR"]

func _ready() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CFG")))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(30/255.0, 25/255.0, 36/255.0)
	add_child(env)
	# Test-only patches for this software renderer: it skips the linear->sRGB step and ignores
	# instance uniforms, so output palette bytes directly and use one material per zombie.
	var code := FileAccess.get_file_as_string(cfg.shader)
	code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	var sh := Shader.new()
	sh.code = code
	var scene: PackedScene = load(cfg.glb)
	var zs: Array = cfg.zombies
	var gap: float = cfg.get("gap", 0.62)
	var roots := []
	for i in zs.size():
		var z: Dictionary = zs[i]
		var inst: Node3D = scene.instantiate()
		inst.position.x = (i - (zs.size() - 1) * 0.5) * gap
		add_child(inst)
		roots.append(inst)
		var parts: Dictionary = z.get("parts", {})
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var params: Dictionary = z.get("params", {})
		for k in params:
			mat.set_shader_parameter(k, params[k])
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var bits := String(m.name).split("_")
			if bits.size() == 2 and bits[0] in ["Head", "Torso", "ArmL", "ArmR", "LegL", "LegR"]:
				m.visible = parts.get(bits[0], "Intact") == bits[1]   # shambler part meshes
			m.material_override = mat
		# optional pose: {"BoneName": [axis x, y, z, angle]}, turned on top of the rest pose
		var pose: Dictionary = z.get("pose", {})
		if not pose.is_empty():
			var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
			for bn in pose:
				var b := sk.find_bone(bn)
				var a: Array = pose[bn]
				sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(Vector3(a[0], a[1], a[2]).normalized(), a[3]))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cfg.get("cam_size", 2.0)
	cam.position = Vector3(0, cfg.get("cam_y", 0.92), 5)
	cam.rotation.x = -cfg.get("pitch", 0.1)
	add_child(cam)
	if cfg.has("cam_pos"):   # optional: an exact camera spot and target, e.g. between a hand and the thigh
		var cp: Array = cfg.cam_pos
		var ct: Array = cfg.cam_look
		cam.position = Vector3(cp[0], cp[1], cp[2])
		cam.look_at(Vector3(ct[0], ct[1], ct[2]))
		cam.near = 0.01
	cam.make_current()
	var views: Array = cfg.get("views", [0.0])
	for vi in views.size():
		for r in roots:
			r.rotation.y = views[vi]
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [cfg.out, vi])
	get_tree().quit()
