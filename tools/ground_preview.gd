extends SceneTree
## Test harness for the ground shaders (assets/ground): renders a sheet of tiles straight down, one row for each
## kind and one column for each season or weather, every tile pinned to its own season with season_override.
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   SHEET=dirt OUT=/tmp/dirt.png xvfb-run -a -s "-screen 0 2000x1700x24" godot --rendering-driver opengl3 \
##       --resolution 1680x1440 -s res://ground_preview.gd
## SHEET: dirt (kinds by season), grass (grass kinds by season), scene (a small made-up place, seen as in the
## game; SEASON=0..3 and WET=0..1 pick the weather).
## Test-only patch for the software renderer: it skips the linear->sRGB step, so the shaders output their palette
## colours directly (ALBEDO=pow(c,vec3(2.2)) -> ALBEDO=c).

const TILE := 4.0
const GAP := 0.35
# name, ground_season (time of year, wetness, snow, frost)
const WEATHER := [
	["Spring", Vector4(0.0, 0.35, 0.0, 0.0)],
	["Summer, dry", Vector4(1.0, 0.0, 0.0, 0.0)],
	["Summer rain", Vector4(1.0, 1.0, 0.0, 0.0)],
	["Autumn", Vector4(2.0, 0.3, 0.0, 0.0)],
	["Winter, hard frost", Vector4(3.0, 0.1, 0.0, 1.0)],
	["Winter, snow", Vector4(3.0, 0.1, 0.6, 0.8)],
]
const DIRT := ["Soil", "Farm", "Road", "Clay", "Mud"]
const GRASS := ["Lawn", "Meadow", "Rough"]

var _frames := 0


func _patched(path: String) -> Shader:
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(path).replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	return sh


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
	env.environment.ambient_light_color = Color(0, 0, 0)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-PI * 0.5, 0, 0)      # straight down: every tile gets full light, so colours are exact
	world.add_child(sun)
	var sheet := OS.get_environment("SHEET")
	if sheet == "" or sheet == "dirt":
		_sheet(world, "res://assets/ground/dirt.gdshader", DIRT, 0)
	elif sheet == "grass":
		_sheet(world, "res://assets/ground/grass.gdshader", GRASS, 8)
	elif sheet == "scene":
		_scene(world, sun)


## A small made-up place, seen as the game sees it (the game camera's angle, turned 45 degrees), to judge the
## kinds side by side, their borders, and how shadows fall on them.
func _scene(world: Node3D, sun: DirectionalLight3D) -> void:
	var w: Array = WEATHER[int(OS.get_environment("WEATHER"))] if OS.get_environment("WEATHER") != "" else WEATHER[1]
	RenderingServer.global_shader_parameter_set("ground_season", w[1])
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)      # the level's sun
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	(world.get_child(0) as WorldEnvironment).environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	(world.get_child(0) as WorldEnvironment).environment.ambient_light_energy = 0.35
	var g := Ground.new()
	world.add_child(g)
	g.setup(Rect2(-20, -20, 40, 40), "soil")
	g.material.shader = _patched("res://assets/ground/ground.gdshader")
	g.road([Vector2(-20, 6), Vector2(-8, 3), Vector2(2, 4), Vector2(9, -2), Vector2(20, -5)])
	g.rect("farm", Rect2(-12, -15, 13, 11), 12.0)
	g.blob("clay", Vector2(9, 9), 4.5)
	g.blob("mud", Vector2(-9, 10), 3.2)
	if OS.get_environment("GRASS") != "":
		g.rect("meadow", Rect2(4, -16, 14, 9))
		g.blob("lawn", Vector2(0, 12), 4.0)
		g.blob("rough", Vector2(15, 4), 3.5)
	g.apply()
	if OS.get_environment("TRACKS") != "":
		# Someone walked across the mud and on over the soil and the road; someone else crawled through the mud.
		world.add_child(Seasons.new())
		Seasons.it.now = w[1]
		var side := 1
		for i in 46:
			side = -side
			g.stamp(Vector3(-15.0 + i * 0.7, 0, 14.0 - i * 0.42), Vector3(0.7, 0, -0.42), side)
		for i in 60:
			g.stamp(Vector3(-12.0 + i * 0.12, 0, 7.5 + i * 0.1), Vector3(0.12, 0, 0.1), 1, true)
		g._tracks_tex.update(g._tracks)
	if OS.get_environment("GRASS") != "":
		for c in g.get_children():
			pass
		print("tufts: ", g.grow_grass())
		world.add_child(GrassBlades.in_rect("tall", Rect2(-18, -6, 7, 6)))
		world.add_child(GrassBlades.in_rect("short", Rect2(-3, 9, 6, 6), 10.0))
		for c in g.get_children() + world.get_children():
			if c is GrassBlades:
				var gm := (c as GrassBlades).material_override as ShaderMaterial
				if gm.shader.resource_path != "":
					gm.shader = _patched("res://assets/ground/grass_blades.gdshader")
		RenderingServer.global_shader_parameter_set("grass_push", Vector4(-14.5, 0, -3, 1.1))
	# Something to cast shadows: a crate and a wall.
	for b in [[Vector3(3, 0.6, 0.5), Vector3(1.2, 1.2, 1.2)], [Vector3(-4, 1.3, -2.5), Vector3(4.0, 2.6, 0.4)]]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.48, 0.44)
		m.material_override = mat
		m.position = b[0]
		world.add_child(m)
	_label(world, w[0], Vector3(-13, 0.1, 16))
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	var rig := Node3D.new()
	world.add_child(rig)
	rig.rotation.y = deg_to_rad(45.0)
	if OS.get_environment("AT") != "":       # what the camera looks at: "x,z"
		var at := OS.get_environment("AT").split_floats(",")
		rig.position = Vector3(at[0], 0.0, at[1])
	var pitch := deg_to_rad(56.0)
	var dist := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 30.0
	cam.reparent(rig)
	cam.position = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	cam.rotation = Vector3(-pitch, 0.0, 0.0)
	cam.make_current()


func _sheet(top: Node3D, shader_path: String, names: Array, first_kind: int) -> void:
	var world := Node3D.new()
	world.rotation.y = deg_to_rad(45.0)       # the page's across and down are the ground frame's
	top.add_child(world)
	var sh := _patched(shader_path)
	var cols := WEATHER.size()
	var rows := names.size()
	for r in rows:
		for c in cols:
			var m := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(TILE, TILE)
			m.mesh = pm
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("kind", first_kind + r)
			mat.set_shader_parameter("season_override", WEATHER[c][1])
			var x := (c - (cols - 1) * 0.5) * (TILE + GAP)
			var z := (r - (rows - 1) * 0.5) * (TILE + GAP)
			# Rows and the road run a little off the grid, as they would in a level.
			var d3 := world.transform.basis * Vector3(1.0, 0.0, 0.18)
			var c3 := world.transform * Vector3(x, 0.0, z)
			mat.set_shader_parameter("direction", Vector2(d3.x, d3.z).normalized())
			mat.set_shader_parameter("road_point", Vector2(c3.x, c3.z))
			mat.set_shader_parameter("road_width", 3.6)
			m.material_override = mat
			m.position = Vector3(x, 0, z)
			world.add_child(m)
			if r == 0:
				_label(world, WEATHER[c][0], Vector3(x, 0.1, z - TILE * 0.5 - 0.3))
		_label(world, names[r], Vector3(-(cols * 0.5) * (TILE + GAP) - 0.9, 0.1, (r - (rows - 1) * 0.5) * (TILE + GAP)))
	_camera_down(world, Vector2(cols * (TILE + GAP) + 2.6, rows * (TILE + GAP) + 1.0), Vector2(-0.9, -0.3))


func _label(world: Node3D, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.outline_size = 10
	l.pixel_size = 0.006
	l.rotation.x = -PI * 0.5
	l.no_depth_test = true
	l.position = pos
	world.add_child(l)


func _camera_down(world: Node3D, extent: Vector2, centre: Vector2) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var vp := root.get_visible_rect().size
	cam.size = maxf(extent.y, extent.x * vp.y / vp.x)
	root.add_child(cam)
	# The sheet is laid out along the ground's own frame (turned 45 degrees to face the game camera), and looked
	# at the same way round, so its texels come out square on the page.
	var at := world.transform * Vector3(centre.x, 0.0, centre.y)
	cam.position = Vector3(at.x, 30.0, at.z)
	cam.rotation = Vector3(-PI * 0.5, deg_to_rad(45.0), 0)
	cam.make_current()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
