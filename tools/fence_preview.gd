extends SceneTree
## Test harness for the fence kit (assets/buildings/fence): puts fences up on plain soil and takes one picture
## as the game's camera sees it (turned 45 degrees).
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   MODE=kinds WEATHER=1 WEAR=0 OUT=/tmp/fence.png xvfb-run -a -s "-screen 0 1100x800x24" godot \
##       --rendering-driver opengl3 --resolution 800x600 -s res://fence_preview.gd
## MODE: kinds (a run of each kind with a gate, the good side to the camera), inside (the same from the other
##       side: the rails), yard (a board fence behind, a picket yard in front, a rail fence beside),
##       house (a kit house with a picket front yard and a boarded back yard), one (KIND alone, close).
## WEATHER 0..5 (the list below), WEAR 0..2, PAINT -1..3 (left out: each kind's own), KIND picket/board/rail,
## GATE the angle the gates stand open at (degrees), SIDE=-1 (MODE=one) turns the inside to the camera, DIST the camera's distance, LOOK "x,y,z".
## Test-only patch for the software renderer: it skips the linear->sRGB step, so the shaders output their
## palette colours directly (FenceKit.raw_colors). Shadows are not drawn by it.

const WEATHER := [
	["Spring", Vector4(0.0, 0.35, 0.0, 0.0)],
	["Summer, dry", Vector4(1.0, 0.0, 0.0, 0.0)],
	["Summer rain", Vector4(1.0, 1.0, 0.0, 0.0)],
	["Autumn", Vector4(2.0, 0.3, 0.0, 0.0)],
	["Winter, hard frost", Vector4(3.0, 0.1, 0.0, 1.0)],
	["Winter, snow", Vector4(3.0, 0.1, 0.6, 0.8)],
]

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
	var w: Array = WEATHER[_env("WEATHER", 1)]
	RenderingServer.global_shader_parameter_set("ground_season", w[1])
	RenderingServer.global_shader_parameter_set("cutaway_shape", Vector4(0, 0, 0, 0))     # nobody to cut it open for
	RenderingServer.global_shader_parameter_set("cutaway_aim", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("cutaway_room2", Vector4(0, 0, 0, 0))
	Cover.clear()
	Solid.reset()
	HouseKit.reset()
	FenceKit.reset()
	Cutaway.reset()
	HouseKit.raw_colors = true
	FenceKit.raw_colors = true
	var g := Ground.new()
	world.add_child(g)
	g.setup(Rect2(-24, -24, 48, 48), "soil")
	var gsh := Shader.new()
	gsh.code = FileAccess.get_file_as_string("res://assets/ground/ground.gdshader").replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	g.material.shader = gsh
	g.blob("lawn", Vector2(0, 2), 9.0)
	g.apply()
	var mode := OS.get_environment("MODE")
	var wear := _env("WEAR", 0)
	var paint := _env("PAINT", -2)
	var pin := Vector4(-1, 0, 0, 0)
	var look_at := Vector3(0, 0.6, 0)
	var dist := 15.0
	var all: Array[FenceKit] = []
	if mode == "inside" or mode == "kinds" or mode == "":
		var out := -1.0 if mode == "inside" else 1.0
		var z := 3.5
		for kind: String in ["picket", "rail", "board"]:
			var f := FenceKit.new(world, kind, wear, paint)
			f.run(Vector2(-4.5, z), Vector2(4.5, z), [6.0], Vector2(0, out))
			all.append(f)
			z -= 3.5
	elif mode == "one":
		var kind := OS.get_environment("KIND") if OS.get_environment("KIND") != "" else "picket"
		var f := FenceKit.new(world, kind, wear, paint)
		var side := float(_env("SIDE", 1))                     # SIDE=-1: the inside faces the camera
		f.run(Vector2(-3.0, 0), Vector2(3.0, 0), [4.0], Vector2(0, side))
		f.run(Vector2(-3.0, -3.0), Vector2(-3.0, 0), [], Vector2(side, 0))
		all.append(f)
		dist = 9.5
	elif mode == "house":
		HouseKit.house(world, Vector3(-4.5, 0, -5), 3, 2, 2, wear, 0)
		all.append(FenceKit.yard(world, Rect2(-6.0, 1.0, 12.0, 5.0), "picket", "S", wear, paint))
		var back := FenceKit.new(world, "board", wear)
		back.run(Vector2(-6.0, -9.5), Vector2(6.0, -9.5), [], Vector2(0, -1))
		back.run(Vector2(-6.0, -9.5), Vector2(-6.0, 1.0), [], Vector2(-1, 0))
		back.run(Vector2(6.0, -9.5), Vector2(6.0, 1.0), [7.0], Vector2(1, 0))
		all.append(back)
		dist = 26.0
		look_at = Vector3(0, 1.5, -1)
	else:
		# A yard: a board fence along the back and one side, a picket yard in front, a rail fence beside it.
		var back := FenceKit.new(world, "board", wear)
		back.run(Vector2(-7.0, -4.0), Vector2(2.0, -4.0), [], Vector2(0, 1))
		back.run(Vector2(-7.0, -4.0), Vector2(-7.0, 3.0), [3.5], Vector2(1, 0))
		all.append(back)
		all.append(FenceKit.yard(world, Rect2(-4.0, -1.0, 6.0, 4.5), "picket", "S", wear, paint))
		var rail := FenceKit.new(world, "rail", wear)
		rail.run(Vector2(3.5, -4.0), Vector2(3.5, 5.0), [5.0])
		rail.run(Vector2(3.5, -4.0), Vector2(8.0, -4.0))
		all.append(rail)
		dist = 20.0
		look_at = Vector3(0, 0.6, 0)
	var swing := deg_to_rad(float(_env("GATE", 0)))
	for f in all:
		for d in f.gates:
			d.set_physics_process(false)
			d.rotation.y = d._base_yaw + swing
	if OS.get_environment("LOOK") != "":
		var l := OS.get_environment("LOOK").split_floats(",")
		look_at = Vector3(l[0], l[1], l[2])
	if OS.get_environment("DIST") != "":
		dist = float(OS.get_environment("DIST"))
	var cam := Camera3D.new()
	cam.fov = 50.0
	var rig := Node3D.new()
	world.add_child(rig)
	rig.rotation.y = deg_to_rad(45.0 + _env("TURN", 0))
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
