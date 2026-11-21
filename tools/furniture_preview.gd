extends SceneTree
## Test harness for the furniture kit (assets/buildings/furniture): puts furniture down and takes one picture as
## the game's camera sees it (turned 45 degrees).
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   MODE=pieces WEAR=0 OUT=/tmp/furniture.png xvfb-run -a -s "-screen 0 1100x800x24" godot \
##       --rendering-driver opengl3 --resolution 800x600 -s res://furniture_preview.gd
## MODE: pieces (every piece on a floor, fronts to the camera), backs (the same turned round), house (a kit
##       house furnished, opened as the game opens it round someone indoors; FLOOR=1 for upstairs).
## WEAR 0..2, STAIN 0..2 (pine, oak, walnut), FABRIC 0..2 (brick red, olive, blue), WEATHER 0..5 (the damp
## only shows on worn furniture), DIST the camera's distance, LOOK "x,y,z".
## Test-only patch for the software renderer: it skips the linear->sRGB step, so the shaders output their
## palette colours directly (FurnitureKit.raw_colors). Shadows are not drawn by it.

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
	env.environment.ambient_light_energy = 0.45
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
	FurnitureKit.reset()
	Cutaway.reset()
	HouseKit.raw_colors = true
	FurnitureKit.raw_colors = true
	var g := Ground.new()
	world.add_child(g)
	g.setup(Rect2(-30, -30, 60, 60), "soil")
	var gsh := Shader.new()
	gsh.code = FileAccess.get_file_as_string("res://assets/ground/ground.gdshader").replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	g.material.shader = gsh
	g.rect("lawn", Rect2(-20, -20, 40, 40))
	g.apply()
	var mode := OS.get_environment("MODE")
	var wear := _env("WEAR", 0)
	var stain := _env("STAIN", 1)
	var fabric := _env("FABRIC", 0)
	var look_at := Vector3(0, 0.5, 0)
	var dist := 13.0
	var cam := Camera3D.new()
	cam.fov = 50.0
	if mode == "house":
		var storeys := 2 if _env("FLOOR", 0) == 1 else 1
		var o := Vector3(-4.5, 0, -3)
		HouseKit.house(world, o, 3, 2, storeys, wear, 0)
		FurnitureKit.furnish(world, o, storeys, wear, stain, fabric)
		# Someone indoors, so the house opens as it does in the game (cutaway.gd).
		var gs := GDScript.new()
		gs.source_code = "extends Node3D\nvar dead := false\nvar armed := false\nvar free_look := false\nvar reticle_visible := false\nvar reticle_offset := Vector3.ZERO\nvar aim_high = null\nvar aim_high_at := Vector3.ZERO\nvar perch := 0.0\n"
		gs.reload()
		var who := Node3D.new()
		who.set_script(gs)
		who.position = o + Vector3(3.6, HouseKit.STOREY * (storeys - 1), 4.4)
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
		var cut := Cutaway.new()
		cut.player = who
		cut.camera = cam
		cut.room_ease = 0.001
		world.add_child(cut)
		look_at = Vector3(0, HouseKit.STOREY * (storeys - 1) + 0.6, 0.3)
		dist = 14.5
	else:
		# Every piece, on a floor of the house's boards.
		var k := HouseKit.new(world, Vector3(-7.5, 0, -4.5), 0, 0)
		k.floor(Rect2i(0, 0, 5, 3), 0)
		var f := FurnitureKit.new(world, wear, stain, fabric)
		var face := "S" if mode != "backs" else "N"
		var side := "E" if mode != "backs" else "W"
		f.put("wardrobe", Vector3(-6.2, 0, -3.6), face)
		f.put("bookshelf", Vector3(-4.6, 0, -3.6), face)
		f.put("fridge", Vector3(-3.2, 0, -3.6), face)
		f.put("stove", Vector3(-1.7, 0, -3.6), face)
		f.counter(Vector2(-0.6, -3.6), Vector2(1.4, -3.6), 0.0, face)
		f.put("dresser", Vector3(3.0, 0, -3.6), face)
		f.put("bed", Vector3(5.6, 0, -2.6), face)
		f.put("couch", Vector3(-5.2, 0, -0.6), face)
		f.put("armchair", Vector3(-3.0, 0, -0.6), face)
		f.put("table", Vector3(-0.4, 0, -0.4), face)
		f.put("chair", Vector3(-0.4, 0, 0.55), "N" if mode != "backs" else "S")
		f.put("chair", Vector3(1.0, 0, -0.4), "W" if mode != "backs" else "E")
		f.put("chair", Vector3(2.4, 0, 0.2), face)
		f.put("couch", Vector3(4.6, 0, 1.6), side)
		f.put("wardrobe", Vector3(-6.4, 0, 2.6), side)
		f.put("dresser", Vector3(-4.0, 0, 3.4), side)
		look_at = Vector3(-0.5, 0.5, -0.6)
		dist = 17.0
	if OS.get_environment("LOOK") != "":
		var l := OS.get_environment("LOOK").split_floats(",")
		look_at = Vector3(l[0], l[1], l[2])
	if OS.get_environment("DIST") != "":
		dist = float(OS.get_environment("DIST"))
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
