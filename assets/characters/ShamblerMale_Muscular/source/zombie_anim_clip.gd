extends SceneTree
## Test harness for zombie_body.gd's motion: renders a short clip, frame by frame, of a few zombies side by side,
## driven through the same fields the AI sets and posed by zombie_body.gd exactly as in the game. The stills sheets
## (zombie_anim_preview.gd) can't show how a zombie moves; this can. zombie_anim_gif.py turns the frames into a GIF.
##
## Run from the game project root (Godot 4.x, software OpenGL under xvfb):
##   CLIP=walk OUT=/tmp/clip xvfb-run -a -s "-screen 0 2400x1600x24" godot --rendering-driver opengl3 \
##       --resolution 1500x380 -s res://zombie_anim_clip.gd
## Clips: walk (fresh, putrid, rigor reaching, stop-and-go), crawl (crawlers by stage).
## Test-only patches for the software renderer, as in zombie_anim_preview.gd.

const DT := 1.0 / 60.0
const FPS := 20                  # frames saved per second of game time
const SECONDS := 4.0
const INTACT := {"Head": "Intact", "Torso": "Intact", "ArmL": "Intact", "ArmR": "Intact", "LegL": "Intact", "LegR": "Intact"}
const FACE := Vector3(-0.97, 0.0, 0.25)

var _shader: Shader
var _root: Node3D
var _cases: Array = []           # [label, Enemy, driver]
var _t := 0.0
var _frame := -3                 # a few frames to settle before saving
var _out := ""


func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	var code := FileAccess.get_file_as_string("res://assets/characters/ShamblerMale_Muscular/zombie_decay_piece.gdshader")
	code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	_shader = Shader.new()
	_shader.code = code
	_out = OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute(_out)
	_build.call_deferred(OS.get_environment("CLIP"))


func _process(_d: float) -> bool:
	if _cases.is_empty():
		return false
	if _frame >= 0:
		root.get_viewport().get_texture().get_image().save_png("%s/f%03d.png" % [_out, _frame])
	_frame += 1
	if _t >= SECONDS:
		quit()
		return false
	# advance the game time of one saved frame, in 60 Hz steps as the game does
	var steps := roundi(1.0 / (FPS * DT))
	for s in steps:
		for c in _cases:
			var e: Enemy = c[1]
			(c[2] as Callable).call(e, _t)
			e._visual.rotation.y = atan2(-e.facing.x, -e.facing.z)
			e.state_t += DT
			e.body.animate(e, DT)
		_t += DT
	return false


func _cases_for(clip: String) -> Array:
	var p1 := INTACT.duplicate()
	p1["LegR"] = "Destroyed"
	match clip:
		"walk":
			return [["Fresh, walking", INTACT, 0.95, _walk.bind(1.5, 6.0)],
				["Putrid, closing in", INTACT, 0.3, _walk.bind(1.5, 1.6)],
				["Rigor, reaching", INTACT, 0.78, _walk.bind(1.5, 1.4)],
				["Bloated, stop and go", INTACT, 0.56, _stop_go]]
		"crawl":
			return [["Fresh crawler", p1, 0.95, _crawl.bind(0.45)],
				["Rigor crawler", p1, 0.78, _crawl.bind(0.4)],
				["Putrid crawler", p1, 0.3, _crawl.bind(0.3)]]
	return []


func _build(clip: String) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(30 / 255.0, 25 / 255.0, 36 / 255.0)
	_root.add_child(env)
	var list := _cases_for(clip)
	var lying := clip == "crawl"
	var cw := 2.7 if lying else 1.9
	var floor_mat := StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_color = Color(0.32, 0.27, 0.3)
	var fl := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(cw * list.size() + 0.4, 0.02, 1.4)
	fl.mesh = bm
	fl.material_override = floor_mat
	fl.position = Vector3((list.size() - 1) * cw * 0.5, -0.011, 0.0)
	_root.add_child(fl)
	for i in list.size():
		var c: Array = list[i]
		var e := Enemy.new()
		e.kind = "shambler"
		e.position = Vector3(i * cw + (0.4 if lying else 0.0), 0.0, 0.0)
		_root.add_child(e)
		e.set_physics_process(false)
		e.set_process(false)
		e.body.shambler.call("show_parts", c[1])
		e.body.shambler.call("set_skin", c[2], 1, 1, 2, 3.0, 11.0, 0.5, 0.4)
		e.body.reroll_style()
		e.body._bad = 1
		e.body._lead = 1
		e.body._both_arms = true
		e.body._rng.seed = 7 + i
		e.crawling = e.body.legs() < 2
		_material(e)
		var lab := Label3D.new()
		lab.text = c[0]
		lab.font_size = 34
		lab.pixel_size = 0.004
		lab.modulate = Color(0.91, 0.85, 0.78)
		lab.position = Vector3(i * cw, 1.0 if lying else 2.05, 0.5)
		_root.add_child(lab)
		_cases.append([c[0], e, c[3]])
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = list.size() * cw + 0.2
	cam.position = Vector3((list.size() - 1) * cw * 0.5 + (0.5 if lying else 0.0), 0.75 if lying else 1.0, 8.0)
	_root.add_child(cam)
	cam.current = true


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


func _walk(e: Enemy, _t: float, speed: float, target_dist: float) -> void:
	e.facing = FACE.normalized()
	e.state = "walk"
	e.chasing = true
	e.velocity = e.facing * speed * e.body.walk_mult
	e.target = e.global_position + e.facing * target_dist + Vector3.UP * 1.25


func _stop_go(e: Enemy, t: float) -> void:
	_walk(e, t, 1.5, 6.0)
	if fmod(t, 2.0) > 1.2:
		e.velocity = Vector3.ZERO   # stops dead for 0.8 s every 2 s


func _crawl(e: Enemy, _t: float, speed: float) -> void:
	e.facing = FACE.normalized()
	e.state = "walk"
	e.chasing = true
	e.crawling = true
	e.velocity = e.facing * speed * e.body.crawl_mult
	e.target = e.global_position + e.facing * 4.0 + Vector3.UP * 0.25
