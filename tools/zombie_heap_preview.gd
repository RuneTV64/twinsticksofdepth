extends SceneTree
## Test harness for zombies getting over walls (enemy.gd, Climbing): a crowd is let loose at a tall wall with the
## player behind it, the game runs for SECONDS with drawing switched off, then one picture is taken of how things
## stand: who is in the heap, who is standing on it, who is going over.
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   N=40 SECONDS=30 OUT=/tmp/heap.png xvfb-run -a -s "-screen 0 2400x1600x24" godot --rendering-driver opengl3 \
##       --resolution 1800x900 -s res://zombie_heap_preview.gd
## Test-only patches for the software renderer: the decay shader outputs its palette colors directly and each
## zombie gets a material of its own; and every zombie is shown, though in the game the player (behind the wall)
## would not see them until they come over.

var _zs: Array[Enemy] = []
var _player: Player
var _shader: Shader
var _t := 0.0
var _shot := -1


func _init() -> void:
	var code := FileAccess.get_file_as_string("res://assets/characters/ShamblerMale_Muscular/zombie_decay_piece.gdshader")
	_shader = Shader.new()
	_shader.code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	_build.call_deferred()


func _box(world: Node3D, pos: Vector3, size: Vector3, col: Color, cover: bool) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.position = pos
	var s := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	s.shape = bs
	b.add_child(s)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	b.add_child(m)
	world.add_child(b)
	if cover:
		Cover.add_box(b, pos, size)


func _build() -> void:
	InputSetup.apply()
	Cover.clear()
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.24)
	world.add_child(env)
	_box(world, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.3, 0.32, 0.3), false)        # the ground
	_box(world, Vector3(0, 1.3, 0), Vector3(16, 2.6, 0.6), Color(0.55, 0.52, 0.48), true)      # the wall
	_player = Player.new()
	_player.position = Vector3(0, 0.05, -5)
	_player.invulnerable = true
	world.add_child(_player)
	for i in int(OS.get_environment("N")):
		var e := Enemy.new()
		e.kind = "shambler"
		e.position = Vector3(randf_range(-5.0, 5.0), 0.05, randf_range(3.0, 9.0))
		world.add_child(e)
		e.player = _player
		e.aggro_range = 40.0
		_zs.append(e)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	world.add_child(cam)
	cam.position = Vector3(9.0, 7.0, 13.0)
	cam.look_at(Vector3(0.0, 1.2, 0.5))
	cam.make_current()
	RenderingServer.render_loop_enabled = false


func _process(delta: float) -> bool:
	_t += delta
	if _shot < 0 and _t >= float(OS.get_environment("SECONDS")):
		# Freeze everything as it stands, show it all, and draw.
		_shot = 0
		var st := {}
		var over := 0
		for e in _zs:
			st[e.state] = st.get(e.state, 0) + 1
			if e.global_position.z < -0.5:
				over += 1
			e.set_physics_process(false)
			e.set_process(false)
			e._alpha = 1.0
			e._visual.visible = true
			e.body.visible = true
			e.body.set_fade(1.0)
			var sh = e.body.shambler
			var m := ShaderMaterial.new()
			m.shader = _shader
			m.set_shader_parameter("anatomy_map", AnatomyMap.texture())
			m.set_shader_parameter("freshness", e.body.freshness())
			for k in ["skin_tone", "variant", "hair_color", "look_seed", "decay_seed", "gore", "grime", "neck_blood"]:
				m.set_shader_parameter(k, sh.get(k))
			m.set_shader_parameter("dissolve", 0.0)
			for mi in sh.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = m
			for i in 12:
				e.body.animate(e, 1.0 / 60.0)
		print("after %ss: %s, heap bodies %d, over the wall %d" % [OS.get_environment("SECONDS"), st, Enemy._heap_n, over])
		_player.set_physics_process(false)
		_player._visual.visible = false
		_player._reticle.visible = false
		RenderingServer.render_loop_enabled = true
	elif _shot >= 0:
		_shot += 1
		if _shot == 6:
			root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
			quit()
	return false
