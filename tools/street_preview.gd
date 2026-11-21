extends SceneTree
## Test harness for the street kit (assets/buildings/street): lays streets on plain ground and takes one picture
## as the game's camera sees it (turned 45 degrees).
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   MODE=scene WEATHER=1 WEAR=0 OUT=/tmp/street.png xvfb-run -a -s "-screen 0 1100x800x24" godot \
##       --rendering-driver opengl3 --resolution 800x600 -s res://street_preview.gd
## MODE: shape (one tile, close: SHAPE end, straight, bend, tee or cross), scene (a T junction and the
##       streets off it, with grass verges), plan (a small town's worth: every shape in one layout),
##       town (the plan with kit houses and fences along it), props (a lamp and each sign, close).
## FURNISH=1 stands lamps and signs along the streets. NIGHT=1 turns the daylight down (the lamps' own light
## shows; the game's darkness is a screen effect this harness doesn't have).
## WEATHER 0..5 (the list below), WEAR 0..2, HOLES=1 breaks a few square metres up, DIST the camera's distance,
## LOOK "x,y,z".
## Test-only patch for the software renderer: it skips the linear->sRGB step, so the shaders output their
## palette colours directly (StreetKit.raw_colors). Shadows are not drawn by it.

const WEATHER := [
	["Spring", Vector4(0.0, 0.35, 0.0, 0.0)],
	["Summer, dry", Vector4(1.0, 0.0, 0.0, 0.0)],
	["Summer rain", Vector4(1.0, 1.0, 0.0, 0.0)],
	["Autumn", Vector4(2.0, 0.3, 0.0, 0.0)],
	["Winter, hard frost", Vector4(3.0, 0.1, 0.0, 1.0)],
	["Winter, snow", Vector4(3.0, 0.1, 0.6, 0.8)],
]
const SHAPES := {"end": ["S"], "straight": ["N", "S"], "bend": ["S", "E"], "tee": ["N", "S", "E"], "cross": ["N", "E", "S", "W"]}

var _frames := 0


func _env(name: String, fallback: int) -> int:
	return int(OS.get_environment(name)) if OS.get_environment(name) != "" else fallback


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.environment.ambient_light_energy = 0.35
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)      # the level's sun
	sun.shadow_enabled = true
	world.add_child(sun)
	if _env("NIGHT", 0) == 1:
		sun.light_energy = 0.12
		env.environment.ambient_light_energy = 0.1
	Daylight.reset()
	var w: Array = WEATHER[_env("WEATHER", 1)]
	RenderingServer.global_shader_parameter_set("ground_season", w[1])
	RenderingServer.global_shader_parameter_set("cutaway_shape", Vector4(0, 0, 0, 0))     # nobody to cut it open for
	RenderingServer.global_shader_parameter_set("cutaway_aim", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("cutaway_room2", Vector4(0, 0, 0, 0))
	Cover.clear()
	Solid.reset()
	HouseKit.reset()
	FenceKit.reset()
	StreetKit.reset()
	Cutaway.reset()
	HouseKit.raw_colors = true
	FenceKit.raw_colors = true
	StreetKit.raw_colors = true
	var g := Ground.new()
	world.add_child(g)
	g.setup(Rect2(-60, -60, 120, 120), "soil")
	var gsh := Shader.new()
	gsh.code = FileAccess.get_file_as_string("res://assets/ground/ground.gdshader").replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	g.material.shader = gsh
	g.rect("lawn", Rect2(-40, -40, 80, 80))
	g.apply()
	var mode := OS.get_environment("MODE")
	var wear := _env("WEAR", 0)
	var look_at := Vector3(0, 0, 0)
	var dist := 22.0
	var s: StreetKit
	if mode == "props":
		# A lamp and one of each sign, on a short straight.
		s = StreetKit.new(world, Vector3(-4.0, 0, -9.0), wear)
		s.plan(["#", "#"])
		s.open(Vector2i(0, 0), "N")
		s.open(Vector2i(0, 1), "S")
		s.build()
		s.lamp(Vector2(4.6, -5.0))
		s.signpost(Vector2(4.6, -1.5), "stop", "S")
		s.name_sign(Vector2(4.6, 1.5))
		s.signpost(Vector2(4.6, 4.5), "warning", "E")
		s.signpost(Vector2(-3.6, 3.0), "stop", "N")
		look_at = Vector3(3.0, 1.2, 0.0)
		dist = 13.0
	elif mode == "shape":
		var shape := OS.get_environment("SHAPE") if OS.get_environment("SHAPE") != "" else "straight"
		s = StreetKit.new(world, Vector3(-4.0, 0, -4.0), wear)
		s.add([Vector2i(0, 0)])
		for side: String in SHAPES[shape]:
			s.open(Vector2i(0, 0), side)
		s.build()
		look_at = Vector3(0.5, 0, 0.5)
		dist = 17.0
	elif mode == "plan" or mode == "town":
		s = StreetKit.new(world, Vector3(-22.0, 0, -18.0), wear)
		s.plan([" # # ",
				"#####",
				" #  #",
				" ####"])
		s.build()
		look_at = Vector3(0.5, 0, 0)
		dist = 62.0
		if mode == "town":
			# Inside the loop of streets (x -4..14, z 0..9): two houses with a picket fence between them;
			# and one more between the two dead ends to the north.
			HouseKit.house(world, Vector3(-3.5, 0, 1.5), 3, 2, 2, wear, 0)
			HouseKit.house(world, Vector3(7.5, 0, 1.5), 2, 2, 1, wear, 1)
			var f := FenceKit.new(world, "picket", wear)
			f.run(Vector2(5.5, 1.5), Vector2(7.5, 1.5))
			f.run(Vector2(5.5, 7.5), Vector2(7.5, 7.5))
			HouseKit.house(world, Vector3(-2.5, 0, -16.5), 2, 2, 1, wear, 2)
	else:
		s = StreetKit.new(world, Vector3(-13.0, 0, -9.0), wear)
		s.plan(["###",
				" # "])
		s.open(Vector2i(0, 0), "W")
		s.open(Vector2i(2, 0), "E")
		s.open(Vector2i(1, 1), "S")
		s.build()
		look_at = Vector3(0.5, 0, -1.5)
		dist = 27.0
	if _env("FURNISH", 0) == 1:
		s.furnish()
	if _env("HOLES", 0) == 1:
		# A few square metres broken up, as a sledgehammer leaves them.
		for b in s.parts:
			var c := b.rect.get_center()
			for off: Vector2 in [Vector2(0.5, 0.5), Vector2(1.5, 0.5), Vector2(1.5, 1.5), Vector2(-2.5, -3.5), Vector2(3.5, 2.5)]:
				b.hit(100000.0, "pound", Vector3(c.x + off.x, 0.0, c.y + off.y))
			if mode != "shape":
				break
	if OS.get_environment("LOOK") != "":
		var l := OS.get_environment("LOOK").split_floats(",")
		look_at = Vector3(l[0], l[1], l[2])
	if OS.get_environment("DIST") != "":
		dist = float(OS.get_environment("DIST"))
	var cam := Camera3D.new()
	cam.fov = 50.0
	var rig := Node3D.new()
	world.add_child(rig)
	rig.rotation.y = deg_to_rad(45.0)
	rig.position = look_at
	var pitch := deg_to_rad(56.0)
	rig.add_child(cam)
	cam.position = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	cam.rotation = Vector3(-pitch, 0.0, 0.0)
	cam.current = true


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
