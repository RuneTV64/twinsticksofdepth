extends SceneTree
## Test harness for the player's cover poses (player_body.gd): renders one row of players frozen in each pose,
## each beside a piece of cover. Every cell is a real Player with its controller switched off; the fields the
## cover code sets are set by hand, then the body poses itself exactly as in the game.
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   ROW=0 OUT=/tmp/cover_0.png xvfb-run -a -s "-screen 0 2400x1600x24" godot --rendering-driver opengl3 \
##       --resolution 2240x560 -s res://cover_pose_preview.gd
## ROW 0 = low cover, ROW 1 = high cover and the vault. Stack the rows with any image tool.
## Test-only patch for the software renderer: it skips the linear->sRGB step, so the skin shader outputs its
## palette colors directly.

const DT := 1.0 / 60.0
const GAP := 2.1

var _frames := 0
var _shader: Shader


# label, cover height (0 = none), facing (1 = back to the cover, -1 = turned to it), then Player fields.
func _cells(row: int) -> Array:
	if row == 0:
		return [
			["Standing (for scale)", 1.2, 1, {}],
			["Sliding in", 1.2, 1, {"cover_entering": true, "cover_crouch": 0.8, "velocity": Vector3(0, 0, -6)}],
			["Hunkered", 1.2, 1, {"cover_crouch": 1.0}],
			["Peeking over", 1.2, -1, {"cover_crouch": 0.7}],
			["Ready: up over it", 1.2, -1, {"armed": true, "weapon": "gun"}],
			["Blind fire over it", 1.2, -1, {"cover_crouch": 1.0, "cover_blind": true, "weapon": "gun"}],
			["Ready: leaning out low", 1.2, -1, {"armed": true, "weapon": "gun", "cover_crouch": 0.75, "cover_lean_dir": Vector3(1, 0, 0)}],
		]
	return [
		["Back to the wall", 2.6, 1, {}],
		["Peeking round the end", 2.6, -1, {"cover_lean_dir": Vector3(0.7, 0, 0)}],
		["Ready: leaning out", 2.6, -1, {"armed": true, "weapon": "gun", "cover_lean_dir": Vector3(1, 0, 0)}],
		["Blind fire round the end", 2.6, -1, {"cover_blind": true, "weapon": "gun", "cover_lean_dir": Vector3(0.7, 0, 0)}],
		["Low peek round the end", 1.2, -1, {"cover_crouch": 1.0, "cover_lean_dir": Vector3(0.7, 0, 0)}],
		["Vault (halfway)", 1.2, -1, {"cover_crouch": 0.7, "_vault_t": 0.2, "lift": 0.75, "over": true}],
		["Roll: a quarter over", 0.0, 1, {"_roll_t": 0.39, "_roll_total": 0.55, "_roll_dir": Vector3(1, 0, 0), "nowall": true}],
		["Roll: three quarters", 0.0, 1, {"_roll_t": 0.16, "_roll_total": 0.55, "_roll_dir": Vector3(1, 0, 0), "nowall": true}],
	]


func _init() -> void:
	var code := FileAccess.get_file_as_string("res://body/male_body_muscular_skin.gdshader")
	_shader = Shader.new()
	_shader.code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	_build.call_deferred(int(OS.get_environment("ROW")))


func _build(row: int) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	var cells := _cells(row)
	for i in cells.size():
		var c: Array = cells[i]
		var x := (i - (cells.size() - 1) * 0.5) * GAP
		var f: Dictionary = c[3]
		var h: float = c[1]
		# The cover: its face is at z = 0, the player stands on the +Z side. Leaning poses get its end beside them.
		var lean: Vector3 = f.get("cover_lean_dir", Vector3.ZERO)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.3, h, 0.4)
		box.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.42, 0.32) if h < 2.0 else Color(0.5, 0.5, 0.48)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material_override = mat
		box.position = Vector3(x - (0.9 if lean != Vector3.ZERO else 0.0), h * 0.5, -0.2)
		if h > 0.0:
			world.add_child(box)
		var p := Player.new()
		p.position = Vector3(x, f.get("lift", 0.0), -0.2 if f.get("over", false) else Cover.STANDOFF)
		world.add_child(p)
		p.set_physics_process(false)
		p.set_process_input(false)
		p._body.material.shader = _shader
		p.facing = Vector3(0, 0, c[2])
		for k in f:
			if k != "lift" and k != "over" and k != "nowall":
				p.set(k, f[k])
		for n in 90:
			p._update_visuals(DT)
		p._reticle.visible = false
		var l := Label3D.new()
		l.text = c[0]
		l.font_size = 30
		l.outline_size = 8
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3(x, 3.1, 0.0)
		world.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.3
	world.add_child(cam)
	cam.position = Vector3(0.0, 6.5, 12.0)     # straight on and a little above, so the row stays level
	cam.look_at(Vector3(0.0, 1.25, 0.0))
	cam.make_current()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
