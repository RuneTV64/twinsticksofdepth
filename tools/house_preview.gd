extends SceneTree
## Test harness for the house kit (assets/buildings/house): builds a house, or the parts laid out in a row, on
## plain soil, and takes one picture as the game's camera sees it (turned 45 degrees).
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   MODE=house WEATHER=1 WEAR=0 OUT=/tmp/house.png xvfb-run -a -s "-screen 0 1400x1000x24" godot \
##       --rendering-driver opengl3 --resolution 1100x800 -s res://house_preview.gd
## MODE: house (a 3 by 2 cell house; STOREYS, default 2), open (the same with the upper storey and roof left
##       off, to see the rooms), cellar (a basement on its own, open to the sky), parts (every part on its
##       own). CELLAR=1 puts a basement under the house.
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
	RenderingServer.global_shader_parameter_set("cutaway_aim", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("cutaway_room2", Vector4(0, 0, 0, 0))
	Cutaway.reset()
	Cover.clear()
	Solid.reset()
	HouseKit.reset()
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
		k.stairs(Vector2i(0, 0), 0, Vector2i(0, 1))
		k.origin.x += 5.0
		k.origin.y = -2.3            # the roof alone, set down on the ground
		k.roof(Rect2i(0, 0, 2, 1), 1)
		dist = 21.0
		look_at = Vector3(0, 0, 2.0)
	else:
		var storeys := _env("STOREYS", 2)
		var cellar := _env("CELLAR", 0) == 1
		if mode == "open":
			# The ground floor with nothing over it, to see the rooms, the floor and the stairs.
			var k := HouseKit.house(world, Vector3(-4.5, 0, -3), 3, 2, 1, wear, paint, Vector4(-1, 0, 0, 0), cellar)
			for b in k.parts:
				if is_instance_valid(b) and b.title == "roof":
					b.host.queue_free()
			if not cellar:
				k.stairs(Vector2i(0, 0), 0, Vector2i(0, 1))
			dist = 15.0
		elif mode == "cellar":
			# A basement on its own, with its stairs, open to the sky.
			var k := HouseKit.new(world, Vector3(-4.5, 0, -3), wear, paint)
			k.basement(Rect2i(0, 0, 3, 2))
			k.stairs(Vector2i(0, 0), -1, Vector2i(0, 1))
			dist = 15.0
			look_at = Vector3(0, -1.5, 0)
		else:
			HouseKit.house(world, Vector3(-4.5, 0, -3), 3, 2, storeys, wear, paint, Vector4(-1, 0, 0, 0), cellar)
			dist = 21.0
			look_at = Vector3(0, 2.0, 0)
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
	# The cutaway as the game runs it (cutaway.gd), round a stand-in for the player:
	#   WHO="x,y,z"      where the player's feet are (a plain figure is stood there)
	#   AIM="x,y,z"      weapon Ready, the crosshair on this spot of the player's floor
	#   AIMHIGH="x,y,z"  weapon Ready, the crosshair on a thing above the storey, at this spot on it
	if OS.get_environment("WHO") != "":
		var gs := GDScript.new()
		gs.source_code = "extends Node3D\nvar dead := false\nvar armed := false\nvar free_look := false\nvar reticle_visible := true\nvar reticle_offset := Vector3.ZERO\nvar aim_high = null\nvar aim_high_at := Vector3.ZERO\nvar perch := 0.0\n"
		gs.reload()
		var who := Node3D.new()
		who.set_script(gs)
		var f := OS.get_environment("WHO").split_floats(",")
		who.position = Vector3(f[0], f[1], f[2])
		world.add_child(who)
		var fig := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 1.8
		fig.mesh = cm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.85, 0.55, 0.3)
		fig.material_override = fm
		fig.position.y = 0.9
		who.add_child(fig)
		var spot := Vector3.INF
		if OS.get_environment("AIM") != "":
			var v := OS.get_environment("AIM").split_floats(",")
			spot = Vector3(v[0], v[1], v[2])
			who.set("armed", true)
			who.set("reticle_offset", spot - who.position)
		if OS.get_environment("AIMHIGH") != "":
			var v := OS.get_environment("AIMHIGH").split_floats(",")
			spot = Vector3(v[0], v[1], v[2])
			who.set("armed", true)
			who.set("reticle_offset", Vector3(spot.x, who.position.y, spot.z) - who.position)
			who.set("aim_high", who)
			who.set("aim_high_at", spot)
		var cut := Cutaway.new()
		cut.player = who
		cut.camera = cam
		cut.room_ease = 0.001      # no easing: the picture is taken a few frames in
		cut.aim_ease = 0.001
		world.add_child(cut)
		if spot != Vector3.INF:
			# The crosshair, drawn where it would be.
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.26
			tm.outer_radius = 0.34
			ring.mesh = tm
			var rm := StandardMaterial3D.new()
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.albedo_color = Color(1.0, 0.2, 0.15)
			rm.no_depth_test = true
			ring.material_override = rm
			ring.position = spot + Vector3(0, 0.05, 0)
			world.add_child(ring)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
