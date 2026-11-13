extends Node3D
## Builds the whole test level in code: open yard, a small house with a normal door (south)
## and a heavy locked door (east), training dummies, shamblers, and ammo crates.

const WALL_H := 2.6
const WALL_T := 0.4

var player: Player
var rig: CamRig
var hud: Hud
var fog: Node3D


func _enter_tree() -> void:
	InputSetup.apply()


func _ready() -> void:
	_build_environment()
	_build_level()

	rig = CamRig.new()
	add_child(rig)

	player = Player.new()
	player.spawn_point = Vector3(0, 0.05, 6)
	player.position = player.spawn_point
	player.camera_rig = rig
	add_child(player)
	rig.target = player
	rig.snap()

	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Enemy).player = player

	# Fog of war: darkens whatever is outside the player's vision cone.
	fog = preload("res://fog.gd").new()
	fog.player = player
	fog.cam = rig.cam
	add_child(fog)

	hud = Hud.new()
	hud.player = player
	add_child(hud)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F1:
				hud.toggle_help()
			KEY_F3:
				hud.toggle_debug()
			KEY_1: _stat("strength", -1)
			KEY_2: _stat("strength", 1)
			KEY_3: _stat("endurance", -1)
			KEY_4: _stat("endurance", 1)
			KEY_5: _stat("weight", -1)
			KEY_6: _stat("weight", 1)
			KEY_7: _stat("dexterity", -1)
			KEY_8: _stat("dexterity", 1)
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _stat(stat: String, d: int) -> void:
	player.set(stat, maxf(float(player.get(stat)) + d, 1.0))
	player.recompute_stats()


# ------------------------------------------------------------------ level
func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Ground with a world-space checker so you can feel your speed.
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(90, 1, 90)
	gs.shape = gb
	ground.add_child(gs)
	var gm := MeshInstance3D.new()
	var gbm := BoxMesh.new()
	gbm.size = gb.size
	gm.mesh = gbm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = floor(wp.xz / 2.0);
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(vec3(0.30, 0.34, 0.28), vec3(0.26, 0.30, 0.24), k);
	ROUGHNESS = 0.95;
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	gm.material_override = smat
	ground.add_child(gm)
	ground.position = Vector3(0, -0.5, 0)
	add_child(ground)


func _build_level() -> void:
	var wall_col := Color(0.55, 0.52, 0.48)
	# Yard boundary
	_box(Vector3(0, WALL_H / 2, -40), Vector3(80, WALL_H, 1), wall_col)
	_box(Vector3(0, WALL_H / 2, 40), Vector3(80, WALL_H, 1), wall_col)
	_box(Vector3(-40, WALL_H / 2, 0), Vector3(1, WALL_H, 80), wall_col)
	_box(Vector3(40, WALL_H / 2, 0), Vector3(1, WALL_H, 80), wall_col)

	# House: x -7..7, z -22..-10
	var hc := Color(0.62, 0.56, 0.47)
	_box(Vector3(-3.9, WALL_H / 2, -10), Vector3(6.2, WALL_H, WALL_T), hc)   # south, left of door
	_box(Vector3(3.9, WALL_H / 2, -10), Vector3(6.2, WALL_H, WALL_T), hc)    # south, right of door
	_box(Vector3(0, WALL_H / 2, -22), Vector3(14.4, WALL_H, WALL_T), hc)     # north
	_box(Vector3(-7, WALL_H / 2, -16), Vector3(WALL_T, WALL_H, 12), hc)      # west
	_box(Vector3(7, WALL_H / 2, -19.4), Vector3(WALL_T, WALL_H, 5.2), hc)    # east, north of door
	_box(Vector3(7, WALL_H / 2, -12.6), Vector3(WALL_T, WALL_H, 5.2), hc)    # east, south of door

	var front := Door.new()
	front.position = Vector3(-0.8, 0, -10)
	add_child(front)

	var heavy := Door.new()
	heavy.locked = true
	heavy.toughness = 26.0
	heavy.position = Vector3(7, 0, -15.2)
	heavy.rotation.y = PI / 2   # panel runs from the hinge toward -Z
	add_child(heavy)

	# Cover / props
	var crate := Color(0.45, 0.36, 0.25)
	_box(Vector3(-5, 0.6, 1), Vector3(1.2, 1.2, 1.2), crate)
	_box(Vector3(6, 0.6, -3), Vector3(1.2, 1.2, 1.2), crate)
	_box(Vector3(12, 1.0, -6), Vector3(1, 2, 1), wall_col)
	_box(Vector3(16, 1.0, 3), Vector3(1, 2, 1), wall_col)
	_box(Vector3(-3, 0.5, -16), Vector3(2.4, 1.0, 1.0), crate)
	_box(Vector3(4, 0.6, -19), Vector3(1.2, 1.2, 1.2), crate)

	# Dummies (west) to feel out aim
	for p in [Vector3(-14, 0.05, 0), Vector3(-16, 0.05, 4), Vector3(-12, 0.05, 8), Vector3(-18, 0.05, -4)]:
		_enemy("dummy", p)
	# Shamblers: two inside the house, three out east
	for p in [Vector3(-3, 0.05, -19), Vector3(3, 0.05, -14)]:
		_enemy("shambler", p)
	for p in [Vector3(20, 0.05, -4), Vector3(22, 0.05, 2), Vector3(19, 0.05, 7)]:
		_enemy("shambler", p)

	# Ammo crates
	for p in [Vector3(3, 0, 4), Vector3(0, 0, -20), Vector3(14, 0, 0)]:
		var a := AmmoPickup.new()
		a.position = p
		add_child(a)

	_sign(Vector3(3, 1.6, 4), "Ammo: weapon away, walk up, interact")
	_sign(Vector3(0, 3.2, -9.6), "Walk into the door to push it")
	_sign(Vector3(7.6, 3.2, -16), "Locked: dash into it")
	_sign(Vector3(-15, 3.0, 2), "Dummies")
	_sign(Vector3(20, 3.0, 0), "Shamblers")


func _box(pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
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
	m.material_override = mat
	b.add_child(m)
	add_child(b)
	return b


func _enemy(kind: String, pos: Vector3) -> void:
	var e := Enemy.new()
	e.kind = kind
	e.position = pos
	add_child(e)


func _sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.outline_size = 8
	l.pixel_size = 0.01
	l.modulate = Color(1, 0.95, 0.75)
	add_child(l)
