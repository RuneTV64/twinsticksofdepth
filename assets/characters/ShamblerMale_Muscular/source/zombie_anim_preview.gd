extends SceneTree
## Test harness for zombie_body.gd: renders sheets of zombies frozen at moments of each animation.
## Rows are cases, columns are moments in time. Each cell is its own zombie (an Enemy with its AI switched off),
## driven through the same fields the AI sets, then posed by zombie_body.gd exactly as in the game.
##
## Run from the game project root (Godot 4.x, software OpenGL under xvfb):
##   SHEET=walk ROW=0 OUT=/tmp/walk_0.png xvfb-run -a -s "-screen 0 2400x1600x24" godot --rendering-driver opengl3 \
##       --resolution 1500x260 -s res://zombie_anim_preview.gd
## One row per run (the software renderer only has room for the per-object shader values of about 20 shamblers);
## a ROW past the last one exits without writing. zombie_anim_sheet.py stacks the rows into a sheet.
## Sheets: walk, approach, limbs, abilities, stages_crawl.
## Test-only patches for the software renderer: it skips the linear->sRGB step and ignores instance uniforms, so the
## shader outputs palette colors directly and each zombie gets its own material.

const DT := 1.0 / 60.0
const STAGES := {"Fresh": 0.95, "Rigor": 0.78, "Bloated": 0.56, "Putrid": 0.3, "Dried": 0.08}
const INTACT := {"Head": "Intact", "Torso": "Intact", "ArmL": "Intact", "ArmR": "Intact", "LegL": "Intact", "LegR": "Intact"}

var _shader: Shader
var _frames := 0
var _root: Node3D
var _empty := false


func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	var code := FileAccess.get_file_as_string("res://assets/characters/ShamblerMale_Muscular/zombie_decay_piece.gdshader")
	code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	_shader = Shader.new()
	_shader.code = code
	_build.call_deferred(OS.get_environment("SHEET"), int(OS.get_environment("ROW")))


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		if _empty:
			quit()
			return false
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(OS.get_environment("OUT"))
		quit()
	return false


# A row: [label, parts, freshness, times, driver]. driver(e, t) sets the Enemy's fields at time t.
func _rows(sheet: String) -> Array:
	var rows := []
	var times := [0.2, 0.45, 0.7, 0.95, 1.2, 1.45]
	match sheet:
		"walk":
			for s in STAGES:
				rows.append([s, INTACT, STAGES[s], times, _walk.bind(1.5, 6.0)])
		"approach":
			for s in STAGES:
				rows.append([s, INTACT, STAGES[s], times, _walk.bind(1.5, 1.4)])
		"limbs":
			var p := INTACT.duplicate()
			p["ArmL"] = "Destroyed"
			rows.append(["No left hand", p, 0.8, times, _walk.bind(1.5, 1.4)])
			p = INTACT.duplicate()
			p["ArmL"] = "Destroyed"
			p["ArmR"] = "Destroyed"
			rows.append(["No hands", p, 0.8, times, _walk.bind(1.5, 1.4)])
			p = INTACT.duplicate()
			p["LegL"] = "Destroyed"
			rows.append(["No left leg", p, 0.8, [0.3, 0.7, 1.1, 1.5, 1.9, 2.3], _crawl.bind(0.4)])
			p = INTACT.duplicate()
			p["LegL"] = "Destroyed"
			p["LegR"] = "Destroyed"
			rows.append(["No legs", p, 0.8, [0.3, 0.7, 1.1, 1.5, 1.9, 2.3], _crawl.bind(0.4)])
			p["ArmR"] = "Destroyed"
			rows.append(["No legs, one hand", p, 0.8, [0.3, 0.7, 1.1, 1.5, 1.9, 2.3], _crawl.bind(0.3)])
		"abilities":
			rows.append(["Grab, hold, bite", INTACT, 0.9, [0.15, 0.35, 0.55, 1.0, 1.35, 1.5], _grab])
			var p := INTACT.duplicate()
			p["ArmL"] = "Destroyed"
			p["ArmR"] = "Destroyed"
			rows.append(["Lunge (no hands)", p, 0.9, [0.1, 0.3, 0.5, 0.62, 0.7, 0.9], _lunge])
			p = INTACT.duplicate()
			p["LegR"] = "Destroyed"
			rows.append(["Crawler grab, bite", p, 0.9, [0.2, 0.6, 1.0, 1.6, 1.75, 1.9], _crawl_grab])
			rows.append(["Knocked down, gets up", INTACT, 0.9, [0.08, 0.16, 0.35, 2.1, 2.35, 2.7], _knockdown])
			rows.append(["Hit, then killed", INTACT, 0.9, [0.05, 0.12, 0.4, 0.7, 0.9, 1.6], _hit_die])
		"stages_crawl":
			var p := INTACT.duplicate()
			p["LegR"] = "Destroyed"
			for s in STAGES:
				rows.append([s, p, STAGES[s], [0.3, 0.7, 1.1, 1.5, 1.9, 2.3], _crawl.bind(0.4)])
	return rows


func _build(sheet: String, only: int) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(30 / 255.0, 25 / 255.0, 36 / 255.0)
	_root.add_child(env)
	var sun := DirectionalLight3D.new()
	_root.add_child(sun)
	var all := _rows(sheet)
	if only >= all.size():
		_empty = true
		return
	var rows := [all[only]]
	var cw := 1.7
	var rh := 2.25
	var floor_mat := StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_color = Color(0.32, 0.27, 0.3)
	for r in rows.size():
		var row: Array = rows[r]
		var times: Array = row[3]
		var y := -r * rh
		var fl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(cw * times.size() + 0.4, 0.02, 1.4)
		fl.mesh = bm
		fl.material_override = floor_mat
		fl.position = Vector3((times.size() - 1) * cw * 0.5, y - 0.011, 0.0)
		_root.add_child(fl)
		var lab := Label3D.new()
		lab.text = row[0] if row[0] == e_stage(row[2]) else "%s   (%s)" % [row[0], e_stage(row[2])]
		lab.font_size = 40
		lab.pixel_size = 0.004
		lab.outline_size = 0
		lab.modulate = Color(0.91, 0.85, 0.78)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lab.position = Vector3(-0.75, y + 2.05, 0.5)
		_root.add_child(lab)
		for c in times.size():
			var e := Enemy.new()
			e.kind = "shambler"
			e.position = Vector3(c * cw, y, 0.0)
			_root.add_child(e)
			e.set_physics_process(false)
			e.body.shambler.call("show_parts", row[1])
			e.body.shambler.call("set_skin", row[2], 1, 1, 2, 3.0, 11.0, 0.5, 0.4)
			e.body.reroll_style()
			e.body._bad = 1
			e.body._lead = 1
			e.body._both_arms = true
			e.body._hunch = 0.04
			e.body._tilt = 0.12
			e.body._noise_o = 5.0
			e.body._rng.seed = 7
			e.crawling = e.body.legs() < 2
			_material(e)
			var t := 0.0
			var tt: float = times[c]
			while t < tt - 0.0001:
				(row[4] as Callable).call(e, t)
				e._visual.rotation.y = atan2(-e.facing.x, -e.facing.z)   # as Enemy does each tick
				e.body.animate(e, DT)
				t += DT
			var tl := Label3D.new()
			tl.text = "%.2fs" % tt
			tl.font_size = 28
			tl.pixel_size = 0.004
			tl.modulate = Color(0.66, 0.58, 0.56)
			tl.position = Vector3(c * cw, y - 0.12, 0.6)
			_root.add_child(tl)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var n := rows.size()
	var cols: int = (rows[0][3] as Array).size()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = cols * cw + 0.2
	cam.position = Vector3((cols - 1) * cw * 0.5, 0.97, 8.0)
	_root.add_child(cam)
	cam.current = true


func e_stage(f: float) -> String:
	return Freshness.new(f).stage()


func _material(e: Enemy) -> void:
	var sh := e.body.shambler
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("anatomy_map", AnatomyMap.texture())
	m.set_shader_parameter("freshness", e.body.freshness())
	for k in ["skin_tone", "variant", "hair_color", "look_seed", "decay_seed", "gore", "grime", "neck_blood"]:
		m.set_shader_parameter(k, sh.get(k))
	m.set_shader_parameter("dissolve", 0.0)
	for mi in sh.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


# ---------------------------------------------------------------- drivers
const FACE := Vector3(-0.97, 0.0, 0.25)   # walking to the left, turned a touch toward the camera


func _walk(e: Enemy, _t: float, speed: float, target_dist: float) -> void:
	e.facing = FACE.normalized()
	e.state = "walk"
	e.chasing = true
	e.velocity = e.facing * speed * lerpf(1.0, 0.65, smoothstep(0.35, 0.9, e.body.rot()))
	e.target = e.global_position + e.facing * target_dist + Vector3.UP * 1.25


func _crawl(e: Enemy, _t: float, speed: float) -> void:
	e.facing = FACE.normalized()
	e.state = "walk"
	e.chasing = true
	e.crawling = true
	e.velocity = e.facing * speed
	e.target = e.global_position + e.facing * 4.0 + Vector3.UP * 0.25


func _state(e: Enemy, s: String, since: float) -> void:
	e.state = s
	e.state_t = since


func _grab(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.velocity = Vector3.ZERO
	e.target = e.global_position + e.facing * 0.75 + Vector3.UP * 1.25
	if t < 0.5:
		_state(e, "reach", t)
	elif t < 1.2:
		_state(e, "hold", t - 0.5)
	else:
		_state(e, "bite", t - 1.2)


func _lunge(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.target = e.global_position + e.facing * 1.2 + Vector3.UP * 1.25
	if t < 0.55:
		_state(e, "lunge_wind", t)
		e.velocity = Vector3.ZERO
	elif t < 0.83:
		_state(e, "lunge", t - 0.55)
		e.velocity = e.facing * 4.2
	else:
		_state(e, "walk", t - 0.83)
		e.velocity = Vector3.ZERO


func _crawl_grab(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.crawling = true
	e.target = e.global_position + e.facing * 0.6 + Vector3.UP * 0.25
	e.velocity = Vector3.ZERO
	if t < 0.5:
		_state(e, "walk", t)
		e.velocity = e.facing * 0.4
	elif t < 1.0:
		_state(e, "reach", t - 0.5)
	elif t < 1.6:
		_state(e, "hold", t - 1.0)
	else:
		_state(e, "bite", t - 1.6)


func _knockdown(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.velocity = Vector3.ZERO
	e.target = e.global_position + e.facing * 3.0 + Vector3.UP * 0.25
	if t < DT:
		_state(e, "walk", t)   # standing when it starts
	elif t < 1.8:
		e.crawling = true
		_state(e, "down", t)
		e.velocity = e.facing * 0.35 if t > 0.6 else Vector3.ZERO
	else:
		e.crawling = false
		_state(e, "getup", t - 1.8)


func _hit_die(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.target = e.global_position + e.facing * 3.0 + Vector3.UP * 1.25
	e.velocity = e.facing * 1.2
	if t < DT * 0.5:
		e.hurt_t = 0.18
		e.hit_dir = -e.facing
	else:
		e.hurt_t -= DT
	if t >= 0.35:
		e.dead = true
		e.velocity = Vector3.ZERO
