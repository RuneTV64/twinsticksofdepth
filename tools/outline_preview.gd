extends SceneTree
## Test harness for the outline (outline.gd, outline.gdshader): the game's own camera angle (camera_rig.gd: turned
## 45 degrees, 56 degrees down, 50 degree lens) at 1600 x 900, over a stand-in for the player, a crowd of zombies,
## a dead one and a raider further off. One frame per panel, each saved as OUT_<name>.png:
##   d18_off, d18_on   the default distance (18 m), without and with outlines
##   d45_off, d45_on   zoomed right out (45 m)
##   close             6 m: a zombie with its chest torn open (no rim inside the wound), arms over the body
##   flash             8 m: a zombie winding up a grab (warn), one just come into view (seen), a raider lining
##                     up a shot (warn), a dead one (none)
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   OUT=/tmp/outline xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 \
##       --resolution 1600x900 -s res://outline_preview.gd
## Test-only patches for the software renderer: it skips the linear->sRGB step and ignores per-object shader
## values, so the skin shaders output their palette colours directly, the outline's colours are used as given,
## and every character gets materials of its own with the per-object values set on them.

const DT := 1.0 / 60.0

var _decay: Shader
var _living: Shader
var _outline: Shader
var _cam: Camera3D
var _zs: Array[Enemy] = []
var _rs: Array[Raider] = []
var _ally: Raider
var _over := {}          # character -> its own outline material (test copy)
var _shots := []         # [name, distance, look-at offset, outlines on]
var _i := -1
var _wait := 0


func _init() -> void:
	var dc := FileAccess.get_file_as_string("res://assets/characters/ShamblerMale_Muscular/zombie_decay_piece.gdshader")
	_decay = Shader.new()
	_decay.code = dc.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	var lc := FileAccess.get_file_as_string("res://assets/characters/MaleBody_Muscular_Skins/body_living.gdshader")
	_living = Shader.new()
	_living.code = lc.replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;").replace("instance uniform", "uniform")
	var oc := FileAccess.get_file_as_string("res://outline.gdshader")
	var re := RegEx.new()
	re.compile(" : instance_index\\(\\d+\\)")
	oc = re.sub(oc, "", true).replace("instance uniform", "uniform").replace(" : source_color", "")
	_outline = Shader.new()
	_outline.code = oc
	_build.call_deferred()


func _ground(world: Node3D) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(120, 1, 120)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.3, 0.22)       # a soil brown, about what the ground shader shows in summer
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(0, -0.5, 0)
	world.add_child(m)
	# A few darker patches and a lighter one, so the figures stand on something busy, as on the real ground.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 40:
		var p := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(rng.randf_range(0.6, 3.0), 0.02, rng.randf_range(0.6, 3.0))
		p.mesh = pm
		var pmat := StandardMaterial3D.new()
		var k := rng.randf_range(0.7, 1.2)
		pmat.albedo_color = Color(0.36 * k, 0.3 * k, 0.2 * k)
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = pmat
		p.position = Vector3(rng.randf_range(-22, 22), 0.0, rng.randf_range(-22, 22))
		p.rotation.y = rng.randf() * TAU
		world.add_child(p)


func _outline_mat(kind: int, seen := 0.0, warn := 0.0) -> ShaderMaterial:
	var src := Outline.material(kind)
	var m := ShaderMaterial.new()
	m.shader = _outline
	for k in ["color", "flash_color", "warn_color", "width_px", "warn_extra_px", "wound_codes_from"]:
		var v = src.get_shader_parameter(k)
		if v != null:
			m.set_shader_parameter(k, v)
	m.set_shader_parameter("outline_flash", seen)
	m.set_shader_parameter("outline_warn", warn)
	m.set_shader_parameter("dissolve", 0.0)
	return m


func _zombie(world: Node3D, player: Player, pos: Vector3, face: Vector3, fresh: float, forced := {},
		state := "walk", seen := 0.0, warn := 0.0, dead := false) -> Enemy:
	var e := Enemy.new()
	e.kind = "shambler"
	e.position = pos
	world.add_child(e)
	e.player = player
	e.set_physics_process(false)
	e.set_process(false)
	var sh = e.body.shambler
	var f := {"LegL": "Intact", "LegR": "Intact"}
	f.merge(forced, true)
	sh.call("roll", f, fresh)
	e.crawling = sh.get("is_crawler")
	e.body.refresh()
	e.facing = face.normalized()
	e._visual.rotation.y = atan2(-e.facing.x, -e.facing.z)
	e.state = state
	e.velocity = e.facing * (0.0 if state != "walk" else 1.0)
	if dead:
		e.dead = true
		e.body.set_outline(false)
	var m := ShaderMaterial.new()
	m.shader = _decay
	m.set_shader_parameter("anatomy_map", AnatomyMap.texture())
	m.set_shader_parameter("freshness", e.body.freshness())
	for k in ["skin_tone", "variant", "hair_color", "look_seed", "decay_seed", "gore", "grime", "neck_blood"]:
		m.set_shader_parameter(k, sh.get(k))
	m.set_shader_parameter("dissolve", 0.0)
	m.set_shader_parameter("key_dir", (_cam.global_transform.basis.inverse() * Vector3(0.33, 0.82, 0.47)).normalized())
	for mi in sh.call("shown_meshes"):
		(mi as MeshInstance3D).material_override = m
	for n in 60:
		e.body.animate(e, DT)
	if not dead:
		_over[e] = _outline_mat(Outline.ZOMBIE, seen, warn)
	_zs.append(e)
	return e


func _person(world: Node3D, pos: Vector3, face: Vector3, kind: int, i: int, fields := {}, warn := 0.0) -> Raider:
	var r := Raider.new()
	r.position = pos
	r.drops_ammo = Vector2i.ZERO
	world.add_child(r)
	r.set_physics_process(false)
	r.set_process(false)
	var mat := ShaderMaterial.new()
	mat.shader = _living
	mat.set_shader_parameter("skin_tone", [1, 7, 10, 4][i % 4])
	mat.set_shader_parameter("variant", i % 4)
	mat.set_shader_parameter("hair_color", 3)
	mat.set_shader_parameter("look_seed", 5.0 * i)
	mat.set_shader_parameter("key_dir", (_cam.global_transform.basis.inverse() * Vector3(0.33, 0.82, 0.47)).normalized())
	r.rbody._mesh.material_override = mat
	r.facing = face.normalized()
	for k in fields:
		r.set(k, fields[k])
	for n in 90:
		r.rbody.animate(r, DT)
	r._visual.rotation.y = atan2(-r.facing.x, -r.facing.z)
	_over[r] = _outline_mat(kind, 0.0, warn)
	for n in ["_label", "_mark"]:
		var v = r.get(n)
		if v is Node3D:
			(v as Node3D).visible = false
	_rs.append(r)
	return r


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
	_cam = Camera3D.new()
	_cam.fov = 50.0
	world.add_child(_cam)
	_place(18.0, Vector3.ZERO)
	_cam.make_current()
	_ground(world)
	var player := Player.new()
	player.position = Vector3(0, 0.05, 40)          # out of the picture: the zombies need one to exist
	player.invulnerable = true
	world.add_child(player)

	# The player's stand-in, in the middle: a person with the ALLY outline, gun up toward the crowd.
	var north := Vector3(0.7, 0, -0.7)
	_ally = _person(world, Vector3(0, 0, 0), north, Outline.ALLY, 0, {"armed": true})
	# The crowd, up the screen (north-east of the player), a mix of fresh and rotted, walking at him.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 16:
		var p := Vector3(rng.randf_range(2.5, 9.0), 0.0, rng.randf_range(-9.0, -2.5))
		_zombie(world, player, p, -p, rng.randf_range(0.2, 1.0))
	# Two crawlers among them.
	_zombie(world, player, Vector3(3.5, 0, -1.5), Vector3(-1, 0, 0.4), 0.4, {"LegL": "Destroyed"})
	_zombie(world, player, Vector3(5.5, 0, -6.5), Vector3(-1, 0, 1), 0.3, {"LegR": "Destroyed"})
	# Two coming in from the side, and one dead on the ground near the player.
	_zombie(world, player, Vector3(-4.5, 0, -1.0), Vector3(1, 0, 0.2), 0.8)
	_zombie(world, player, Vector3(-3.0, 0, 3.5), Vector3(0.6, 0, -1), 0.5)
	_zombie(world, player, Vector3(2.0, 0, 2.0), Vector3(-1, 0, 0), 0.7, {}, "walk", 0.0, 0.0, true)
	# A raider further off, up and to the left on the screen, aiming this way.
	_person(world, Vector3(-8.4, 0, -1.4), Vector3(8.4, 0, 1.4), Outline.RAIDER, 1, {"armed": true})

	# The close-up group, away from the crowd: a zombie with its chest torn open, one reaching with both arms.
	var cx := Vector3(30, 0, 0)
	_zombie(world, player, cx + Vector3(-0.8, 0, 0), Vector3(0, 0, 1), 0.75, {"Torso": "Destroyed", "ArmL": "Rotted"})
	_zombie(world, player, cx + Vector3(0.9, 0, 0.3), Vector3(0, 0, 1), 0.95, {}, "reach")
	# The flash group: a zombie winding up a grab (warn), one just come into view (seen), a raider lining up
	# a shot (warn), a dead one (no outline).
	var fx := Vector3(-30, 0, 0)
	_zombie(world, player, fx + Vector3(-2.4, 0, 0), Vector3(0, 0, 1), 0.9, {}, "reach", 0.0, 1.0)
	_zombie(world, player, fx + Vector3(-0.8, 0, 0), Vector3(0, 0, 1), 0.6, {}, "walk", 1.0, 0.0)
	_person(world, fx + Vector3(0.8, 0, 0), Vector3(0, 0, 1), Outline.RAIDER, 2, {"armed": true}, 1.0)
	_zombie(world, player, fx + Vector3(2.4, 0, 0.4), Vector3(1, 0, 0), 0.5, {}, "walk", 0.0, 0.0, true)

	_shots = [
		["d18_off", 18.0, Vector3.ZERO, false], ["d18_on", 18.0, Vector3.ZERO, true],
		["d45_off", 45.0, Vector3.ZERO, false], ["d45_on", 45.0, Vector3.ZERO, true],
		["close", 4.0, cx + Vector3(0, 0.9, 0), true], ["flash", 8.0, fx + Vector3(0, 0.6, 0), true],
	]
	player._visual.visible = false
	player._reticle.visible = false
	for v in player.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).visible = false    # its cursor marks too
	player.set_physics_process(false)
	player.set_process(false)
	_next()


## The game camera's own angle (camera_rig.gd) at this distance, looking at `at`.
func _place(dist: float, at: Vector3) -> void:
	var yaw := deg_to_rad(45.0)
	var p := deg_to_rad(56.0)
	var local := Vector3(0.0, sin(p) * dist, cos(p) * dist)
	_cam.global_position = at + Basis(Vector3.UP, yaw) * local
	_cam.rotation = Vector3(-p, yaw, 0.0)


func _next() -> void:
	_i += 1
	if _i >= _shots.size():
		quit()
		return
	var s: Array = _shots[_i]
	_place(s[1], s[2])
	for c in _over:
		var meshes: Array = c.body.shambler.call("shown_meshes") if c is Enemy and not (c is Raider) else [c.rbody._mesh]
		for mi in meshes:
			(mi as GeometryInstance3D).material_overlay = _over[c] if s[3] else null
	_wait = 4


func _process(_d: float) -> bool:
	if _i < 0 or _i >= _shots.size():
		return false
	_wait -= 1
	if _wait == 0:
		var s: Array = _shots[_i]
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OS.get_environment("OUT"), s[0]])
		_next()
	return false
