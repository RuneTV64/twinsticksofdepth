extends SceneTree
## Test harness for the cutaway (cutaway.gd, cutaway.gdshaderinc): a stand-in player north of a one-storey wall,
## with a tall block further south, seen from the game's camera angle. Renders with the cutaway off or on.
##   ON=0 OUT=/tmp/cut_off.png xvfb-run -a -s "-screen 0 1700x1000x24" godot --rendering-driver opengl3 \
##       --resolution 1200x800 -s res://cutaway_preview.gd        (from a scratch copy's root; ON=1 for on)
## TOWER=1 puts the player behind the tall block instead of the wall.

var _frames := 0


func _box(world: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = Cutaway.solid(col)
	m.position = pos
	world.add_child(m)


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.11, 0.13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(60, 60)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.3, 0.33, 0.28)
	ground.material_override = gmat
	world.add_child(ground)
	var tower := OS.get_environment("TOWER") != ""
	# A small house: the player stands just inside its south wall. And a tall block to the south.
	var hc := Color(0.62, 0.56, 0.47)
	_box(world, Vector3(0, 1.3, 1.0), Vector3(10, 2.6, 0.4), hc)          # south wall
	_box(world, Vector3(0, 1.3, -6.0), Vector3(10, 2.6, 0.4), hc)         # north wall
	_box(world, Vector3(-5, 1.3, -2.5), Vector3(0.4, 2.6, 7.4), hc)
	_box(world, Vector3(5, 1.3, -2.5), Vector3(0.4, 2.6, 7.4), hc)
	_box(world, Vector3(2.5, 0.6, -3.0), Vector3(1.2, 1.2, 1.2), Color(0.45, 0.36, 0.25))
	# A tall block: off to the side, or (TOWER=1) right between the camera and the player.
	_box(world, Vector3(-11.0 if not tower else 0.0, 6.0, 9.5), Vector3(9, 12, 3), Color(0.42, 0.44, 0.5))
	var player := Node3D.new()
	player.position = Vector3(-1.0, 0.0, 0.1) if not tower else Vector3(0.0, 0.0, 5.0)
	world.add_child(player)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	body.mesh = cm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.85, 0.5, 0.2)
	body.material_override = bmat
	body.position.y = 0.9
	player.add_child(body)
	# The game's camera: 56 degrees down, 18 m out, never turned.
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	var p := deg_to_rad(56.0)
	cam.position = player.position + Vector3(0.0, sin(p) * 18.0, cos(p) * 18.0)
	cam.rotation = Vector3(-p, 0.0, 0.0)
	cam.make_current()
	var cut := Cutaway.new()
	cut.player = player
	cut.camera = cam
	cut.enabled = OS.get_environment("ON") == "1"
	world.add_child(cut)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
