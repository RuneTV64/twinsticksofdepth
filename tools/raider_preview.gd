extends SceneTree
## Test harness for raiders (raider.gd, raider_body.gd): one row of raiders, each a real Raider with its mind
## switched off, its state set by hand and posed by the body exactly as in the game. Shows the rolled looks too.
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   OUT=/tmp/raiders.png xvfb-run -a -s "-screen 0 2400x1600x24" godot --rendering-driver opengl3 \
##       --resolution 2240x560 -s res://raider_preview.gd
## Test-only patches for the software renderer: it skips the linear->sRGB step and ignores per-object shader
## values, so the skin shader outputs its palette colors directly and each raider gets a material of its own.

const DT := 1.0 / 60.0
const GAP := 2.3

var _frames := 0

# label, tone, look, hair, then Raider fields
const CELLS := [
	["On watch", 1, 1, 2, {}],
	["Walking", 4, 2, 3, {"velocity": Vector3(0, 0, 2.1), "armed": true}],
	["Aiming", 7, 0, 3, {"armed": true}],
	["Reloading", 10, 1, 3, {"armed": true, "_reload_t": 0.9}],
	["Hunkered", 13, 3, 4, {"armed": true, "cover_crouch": 1.0, "wall": 1.2, "back": true}],
	["Up over cover", 0, 0, 1, {"armed": true, "wall": 1.2}],
	["Down", 5, 1, 3, {"dead": true}],
]


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.24)
	world.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.3
	world.add_child(cam)
	cam.position = Vector3(0.0, 6.5, 12.0)
	cam.look_at(Vector3(0.0, 1.25, 0.0))
	cam.make_current()
	var code := FileAccess.get_file_as_string("res://assets/characters/MaleBody_Muscular_Skins/body_living.gdshader")
	code = code.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	var shader := Shader.new()
	shader.code = code
	for i in CELLS.size():
		var c: Array = CELLS[i]
		var f: Dictionary = c[4]
		var x := (i - (CELLS.size() - 1) * 0.5) * GAP
		if f.has("wall"):
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.3, f["wall"], 0.4)
			box.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.5, 0.42, 0.32)
			bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			box.material_override = bmat
			box.position = Vector3(x, f["wall"] * 0.5, -0.2)
			world.add_child(box)
		var r := Raider.new()
		r.position = Vector3(x, 0.0, Cover.STANDOFF)
		r.drops_ammo = Vector2i.ZERO
		world.add_child(r)
		r.set_physics_process(false)
		r.set_process(false)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("skin_tone", c[1])
		mat.set_shader_parameter("variant", c[2])
		mat.set_shader_parameter("hair_color", c[3])
		mat.set_shader_parameter("look_seed", 7.0 * i)
		mat.set_shader_parameter("key_dir", (cam.global_transform.basis.inverse() * Vector3(0.33, 0.82, 0.47)).normalized())
		r.rbody._mesh.material_override = mat
		r.facing = Vector3(0, 0, 1) if (not f.has("wall") or f.get("back", false)) else Vector3(0, 0, -1)
		for k in f:
			if k != "wall" and k != "back":
				r.set(k, f[k])
		for n in 90:
			r.rbody.animate(r, DT)
		r._visual.rotation.y = atan2(-r.facing.x, -r.facing.z)
		var l := Label3D.new()
		l.text = c[0]
		l.font_size = 30
		l.outline_size = 8
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3(x, 3.1, 0.0)
		world.add_child(l)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
