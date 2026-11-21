extends SceneTree
## Test harness for the house kit (assets/buildings/house): builds a house, or the parts laid out in a row, on
## plain soil, and takes one picture as the game's camera sees it (turned 45 degrees).
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   MODE=house WEATHER=1 WEAR=0 OUT=/tmp/house.png xvfb-run -a -s "-screen 0 1400x1000x24" godot \
##       --rendering-driver opengl3 --resolution 1100x800 -s res://house_preview.gd
## MODE: house (a 3 by 2 cell house; STOREYS, default 2), open (the same with the upper storey and roof left
##       off, to see the rooms), parts (every part on its own).
## WEATHER 0..5 (the list below), WEAR 0..2, PAINT 0..2, DIST the camera's distance.
## Test-only patch for the software renderer: it skips the linear->sRGB step, so the shaders output their
## palette colours directly (HouseKit.raw_colors). Shadows are not drawn by it.

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
	Cover.clear()
	Solid.reset()
	HouseKit.raw_colors = true
	var g := Ground.new()
	world.add_child(g)
	g.setup(Rect2(-24, -24, 48, 48), "soil")
	var gsh := Shader.new()
	gsh.code = FileAccess.get_file_as_string("res://assets/ground/ground.gdshader").replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	g.material.shader = gsh
	g.blob("lawn", Vector2(0, 6), 9.0)
	g.apply()
	var mode := OS.get_environment("MODE")
	var wear := _env("WEAR", 0)
	var paint := _env("PAINT", 0)
	var look_at := Vector3.ZERO
	var dist := 22.0
	if mode == "parts":
		var k := HouseKit.new(world, Vector3(-10.5, 0, -1.5), wear, paint)
		k.wall(Vector2i(0, 0), Vector2i(1, 0), 0, ".", Vector2(0, 1))
		k.origin.x += 4.0
		k.wall(Vector2i(0, 0), Vector2i(1, 0), 0, "W", Vector2(0, 1))
		k.origin.x += 4.0
		k.wall(Vector2i(0, 0), Vector2i(1, 0), 0, "D", Vector2(0, 1))
		k.origin.x += 4.0
		k.wall(Vector2i(0, 0), Vector2i(1, 0), 0, "O")
		k.origin.x += 4.0
		k.wall(Vector2i(0, 0), Vector2i(1, 0), 0, ".")
		k.origin = Vector3(-10.5, 0, 2.5)
		k.floor(Rect2i(0, 0, 1, 1), 0)
		k.origin.x += 4.0
		k.stairs(Vector2i(0, 0), 0, Vector2i(1, 0))
		k.origin.x += 5.0
		k.origin.y = -2.3            # the roof alone, set down on the ground
		k.roof(Rect2i(0, 0, 2, 1), 1)
		dist = 21.0
		look_at = Vector3(0, 0, 2.0)
	else:
		var storeys := _env("STOREYS", 2)
		if mode == "open":
			# The ground floor with nothing over it, to see the rooms, the floor and the stairs.
			var k := HouseKit.house(world, Vector3(-4.5, 0, -3), 3, 2, 1, wear, paint)
			for b in k.parts:
				if is_instance_valid(b) and b.title == "roof":
					b.host.queue_free()
			k.stairs(Vector2i(0, 0), 0, Vector2i(1, 0))
			dist = 15.0
		else:
			HouseKit.house(world, Vector3(-4.5, 0, -3), 3, 2, storeys, wear, paint)
			dist = 21.0
			look_at = Vector3(0, 2.0, 0)
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
