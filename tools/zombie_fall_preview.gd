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
## Sheets: walk, approach, limbs, abilities, stages_crawl, falls, impaled (hung on a picket fence).
## CLIP=<frames> (with SHEET=impaled) writes that many pictures, 1/15 s apart, to OUT with the frame number put
## before ".png", for a moving picture (tools/impaled_gif.py puts them together).
## (A copy of ShamblerMale_Muscular/source/zombie_anim_preview.gd with the falls sheet added; that asset is
## approved, so its own harness was left as it is.)
## Test-only patches for the software renderer: it skips the linear->sRGB step and ignores instance uniforms, so the
## shader outputs palette colors directly and each zombie gets its own material.

const DT := 1.0 / 60.0
const STAGES := {"Fresh": 0.95, "Rigor": 0.78, "Bloated": 0.56, "Putrid": 0.3, "Dried": 0.08}
const INTACT := {"Head": "Intact", "Torso": "Intact", "ArmL": "Intact", "ArmR": "Intact", "LegL": "Intact", "LegR": "Intact"}

var _shader: Shader
var _frames := 0
var _root: Node3D
var _empty := false
var _clip := 0                  # CLIP: how many pictures of a moving picture to write
var _live: Array = []           # [enemy, driver, its time] for a moving picture


func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	var code := FileAccess.get_file_as_string("res://assets/characters/ShamblerMale_Muscular/zombie_decay_piece.gdshader")
	code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	_shader = Shader.new()
	_shader.code = code
	_clip = int(OS.get_environment("CLIP")) if OS.get_environment("CLIP") != "" else 0
	_build.call_deferred(OS.get_environment("SHEET"), int(OS.get_environment("ROW")))


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		if _empty:
			quit()
			return false
		var img := root.get_viewport().get_texture().get_image()
		if _clip <= 0:
			img.save_png(OS.get_environment("OUT"))
			quit()
	elif _frames > 8 and _clip > 0:
		# A moving picture: this frame shows the step taken last frame; save it, then step again.
		var n := _frames - 9
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").replace(".png", "_%03d.png" % n))
		if n + 1 >= _clip:
			quit()
			return false
		for l: Array in _live:
			var e: Enemy = l[0]
			for i in 4:
				(l[1] as Callable).call(e, l[2])
				e._visual.rotation.y = atan2(-e.facing.x, -e.facing.z)
				e.body.animate(e, DT)
				l[2] += DT
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
		"falls":
			rows.append(["Knocked onto its back, sits up", INTACT, 0.9, [0.12, 0.3, 0.7, 1.5, 2.1, 2.9], _fall_back_up])
			rows.append(["On its back, rolls over to crawl", INTACT, 0.9, [0.7, 1.2, 1.45, 1.7, 2.0, 2.8], _fall_back_roll])
			rows.append(["Knocked onto its front, gets up", INTACT, 0.9, [0.08, 0.16, 0.35, 2.1, 2.35, 2.7], _knockdown])
			rows.append(["Killed from the front: on its back", INTACT, 0.9, [0.05, 0.2, 0.45, 0.7, 1.0, 1.6], _die_back])
		"impaled":
			var it := [0.7, 1.3, 1.9, 2.6, 2.95, 3.4]
			rows.append(["Impaled on its front: thrashing, then a heave to pull free", INTACT, 0.95, it, _impaled.bind(false, -1.0, 2.1)])
			rows.append(["The same, long rotted: slower and weaker", INTACT, 0.3, it, _impaled.bind(false, -1.0, 2.1)])
			rows.append(["In rigor: the same in jerks", INTACT, 0.78, it, _impaled.bind(false, -1.0, 2.1)])
			rows.append(["Knocked backward onto the points", INTACT, 0.95, it, _impaled.bind(true, -1.0, 2.1)])
			rows.append(["Killed on the fence: it hangs limp", INTACT, 0.95, [0.7, 1.0, 1.25, 1.6, 2.2, 3.4], _impaled.bind(false, 1.1, 9.0)])
			rows.append(["Killed on its back", INTACT, 0.95, [0.7, 1.0, 1.25, 1.6, 2.2, 3.4], _impaled.bind(true, 1.1, 9.0)])
			var p := INTACT.duplicate()
			p["ArmL"] = "Destroyed"
			p["LegR"] = "Destroyed"
			rows.append(["With an arm and a leg gone", p, 0.56, it, _impaled.bind(false, -1.0, 2.1)])
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
	if _clip > 0:
		rows = [(all[only] as Array).duplicate()]
		rows[0][3] = [0.6]              # a moving picture: one zombie, stepped on from here
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
		lab.visible = _clip <= 0
		_root.add_child(lab)
		for c in times.size():
			var e := Enemy.new()
			e.kind = "shambler"
			e.position = Vector3(c * cw, y, 0.0)
			_root.add_child(e)
			e.set_physics_process(false)
			e.set_process(false)   # posed here by hand, frozen at the time shown
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
			if sheet == "impaled":
				_fence(Vector3(c * cw, y, 0.0))
			var t := 0.0
			var tt: float = times[c]
			if _clip > 0:
				tt = 0.6
				_live.append([e, row[4], tt])
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
			tl.visible = _clip <= 0
			_root.add_child(tl)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var n := rows.size()
	var cols: int = (rows[0][3] as Array).size()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = cols * cw + (1.1 if _clip > 0 else 0.2)
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


func _fall_back_up(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.velocity = Vector3.ZERO
	e.target = e.global_position + e.facing * 3.0 + Vector3.UP * 0.25
	if t < DT:
		_state(e, "walk", t)
	elif t < 1.4:
		e.crawling = true
		e.on_back = true
		_state(e, "down", t)
	else:
		e.crawling = false
		_state(e, "getup", t - 1.4)


func _fall_back_roll(e: Enemy, t: float) -> void:
	if not e.has_meta("rolled"):
		e.facing = FACE.normalized()
	e.chasing = true
	e.velocity = Vector3.ZERO
	e.target = e.global_position + e.facing * 3.0 + Vector3.UP * 0.25
	if t < DT:
		_state(e, "walk", t)
		return
	e.crawling = true
	_state(e, "down", t)
	if t < 1.9 and not e.has_meta("rolled"):
		e.on_back = true
		e.roll_u = clampf((t - 1.1) / 0.8, 0.0, 1.0)
	elif not e.has_meta("rolled"):
		e.set_meta("rolled", true)
		e.on_back = false
		e.roll_u = 0.0
		e.facing = -e.facing
		e.body.rolled_over()
	else:
		e.velocity = e.facing * 0.35


func _die_back(e: Enemy, t: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.target = e.global_position + e.facing * 3.0 + Vector3.UP * 1.25
	e.velocity = e.facing * 1.2
	if t >= 0.1:
		e.on_back = true
		e.dead = true
		e.velocity = Vector3.ZERO


## Hung on a fence: on its front (or, `back`, knocked backward onto it); `die_at` kills it there (< 0: never);
## from `heave_at` a try to pull itself off builds for 0.9 s and lets go, again every 3.2 s.
func _impaled(e: Enemy, t: float, back: bool, die_at: float, heave_at: float) -> void:
	e.facing = FACE.normalized()
	e.chasing = true
	e.velocity = Vector3.ZERO
	e.target = e.global_position + e.facing * 2.5 + Vector3.UP * 1.0
	if back and t < DT:
		_state(e, "walk", t)        # on its feet when the blow lands, so it goes over backward
		return
	e.crawling = true
	e.on_back = back
	e.hung = true
	e.perch = 0.88
	e._visual.position.y = e.perch
	_state(e, "impaled", t)
	var ht := fposmod(t - heave_at, 3.2) if t >= heave_at else -1.0
	e.heave = clampf(ht / 0.9, 0.0, 1.0) if ht >= 0.0 and ht < 0.9 else 0.0
	if die_at >= 0.0 and t >= die_at:
		e.dead = true
		e.crawling = false
		e.heave = 0.0


## A bit of picket fence, seen end on, for the impaled sheet.
func _fence(at: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.85, 0.8)
	var across := Vector3(-FACE.z, 0.0, FACE.x).normalized()
	for i in range(-1, 2):
		var pk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 1.0, 0.11)
		pk.mesh = bm
		pk.material_override = m
		pk.position = at + across * (i * 0.19) + Vector3(0.0, 0.5, 0.0)
		pk.rotation.y = atan2(-FACE.z, FACE.x)       # its thin side along the way the zombie faces
		_root.add_child(pk)
	for h: float in [0.3, 0.75]:
		var rl := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.05, 0.09, 0.56)
		rl.mesh = rb
		rl.material_override = m
		rl.position = at + Vector3(0.0, h, 0.0) - FACE.normalized() * 0.04
		rl.rotation.y = atan2(-FACE.z, FACE.x)
		_root.add_child(rl)


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
