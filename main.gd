extends Node3D
## Builds the whole test level in code.
##  - Training yard (z -40..40): a small house with a normal door (south) and a heavy locked
##    door (east), training dummies, a few shamblers, the tutorial ammo crate.
##  - Cul-de-sac (north of the yard, through the gap in the wall): a short street ending in a
##    turning circle, seven houses with doors and windows, a lot of zombies, and ammo hidden
##    inside some of the houses.
## North is -Z.

const WALL_H := 2.6
const WALL_T := 0.4
const DOOR_W := 1.6       # matches Door.width
const DOOR_H := 2.3       # wall above this over a doorway
const WINDOW_W := 1.4
const SILL_H := 0.9       # window opening runs from here...
const HEAD_H := 2.0       # ...up to here. You can see and shoot through it, not climb through.

# The whole playable area, for the ground, the outer wall and the fog-of-war map.
const WORLD_X0 := -40.0
const WORLD_X1 := 40.0
const WORLD_Z0 := -112.0  # north edge
const WORLD_Z1 := 40.0    # south edge

var player: Player
var rig: CamRig
var hud: Hud
var fog: Node3D
var cutaway: Cutaway
var horde: Horde
var _zone_label: Label
var _zone_t := 0.0

# Crowd test (F5 / F6 / F7): extra shamblers to find out how many the game can take, and where the time goes.
const CROWD_STEP := 50
var _crowd: Array[Enemy] = []
var _raiders: Array[Raider] = []   # added with T
var _perf: Label
var _perf_t := 0.0
var _perf_frames := 0


func _enter_tree() -> void:
	InputSetup.apply()


func _ready() -> void:
	Cover.clear()
	Cover.bounds = Rect2(WORLD_X0, WORLD_Z0, WORLD_X1 - WORLD_X0, WORLD_Z1 - WORLD_Z0)
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
	fog.map_min = Vector2(WORLD_X0 - 4.0, WORLD_Z0 - 4.0)
	fog.map_size = Vector2(WORLD_X1 - WORLD_X0 + 8.0, WORLD_Z1 - WORLD_Z0 + 8.0)
	add_child(fog)

	# Whatever stands between the camera and you is cut open.
	cutaway = Cutaway.new()
	cutaway.player = player
	cutaway.camera = rig.cam
	add_child(cutaway)

	# The horde: how many zombies are where, and how noise moves them about.
	horde = Horde.new()
	horde.player = player
	add_child(horde)

	hud = Hud.new()
	hud.player = player
	add_child(hud)
	_make_perf_label()

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
			KEY_C: hud.toggle_sheet()
			KEY_PAGEUP: hud.sheet_select(-1)
			KEY_PAGEDOWN: hud.sheet_select(1)
			KEY_MINUS: hud.sheet_adjust(-1)
			KEY_EQUAL: hud.sheet_adjust(1)
			KEY_1: _stat("strength", -1)
			KEY_2: _stat("strength", 1)
			KEY_3: _stat("endurance", -1)
			KEY_4: _stat("endurance", 1)
			KEY_5: _stat("weight", -1)
			KEY_6: _stat("weight", 1)
			KEY_7: _stat("dexterity", -1)
			KEY_8: _stat("dexterity", 1)
			KEY_F5: _add_crowd(CROWD_STEP)
			KEY_F6: _clear_crowd()
			KEY_L:   # (not F8: that's the Godot editor's Stop Running Project)
				ZombieBody.force_low = not ZombieBody.force_low
				player.show_status("All zombies on the low model: %s" % ("ON" if ZombieBody.force_low else "OFF"), 1.5)
			KEY_T:   # a raider at the crosshair; Shift+T removes the ones added this way
				if event.shift_pressed:
					for r in _raiders:
						if is_instance_valid(r):
							r.queue_free()
					_raiders.clear()
					player.show_status("Test raiders removed", 1.5)
				else:
					var at := player.global_position + player.reticle_offset
					if player.reticle_offset.length() < 3.0:
						at = player.global_position + player.facing * 10.0
					_raiders.append(_raider(Vector3(at.x, 0.05, at.z)))
					player.show_status("Raider added (Shift+T removes them)", 1.5)
			KEY_Z:   # the horde readout: zombies out of play / in play / warmth, area by area
				if _zone_label == null:
					_zone_label = Label.new()
					_zone_label.add_theme_font_size_override("font_size", 15)
					_zone_label.add_theme_color_override("font_outline_color", Color.BLACK)
					_zone_label.add_theme_constant_override("outline_size", 6)
					_zone_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
					_zone_label.position = Vector2(20, 220)
					_zone_label.visible = false
					hud.add_child(_zone_label)
				_zone_label.visible = not _zone_label.visible
				_zone_t = 0.0
			KEY_V:   # the cutaway on / off, to compare
				cutaway.enabled = not cutaway.enabled
				player.show_status("Cutaway: %s" % ("ON" if cutaway.enabled else "OFF"), 1.5)
			KEY_G:   # cover test: something that shoots at you
				if event.shift_pressed:
					for g in get_tree().get_nodes_in_group("gunners"):
						g.queue_free()
					player.show_status("Test gunners removed", 1.5)
				else:
					_add_gunner()
			KEY_F7:
				player.invulnerable = not player.invulnerable
				player.show_status("Can't be hurt: %s" % ("ON" if player.invulnerable else "OFF"), 1.5)
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ crowd test
## Add n shamblers in front of you, 6 to 20 m out, where there's open floor. They come straight for you.
func _add_crowd(n: int) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1 | 2
	var made := 0
	var tries := 0
	while made < n and tries < n * 20:
		tries += 1
		var a := atan2(-player.facing.x, -player.facing.z) + randf_range(-0.9, 0.9)
		var r := randf_range(6.0, 20.0)
		var pos := player.global_position + Vector3(-sin(a), 0.0, -cos(a)) * r
		if pos.x < WORLD_X0 + 1.0 or pos.x > WORLD_X1 - 1.0 or pos.z < WORLD_Z0 + 1.0 or pos.z > WORLD_Z1 - 1.0:
			continue
		q.position = pos + Vector3.UP * 0.9
		if not space.intersect_point(q, 1).is_empty():
			continue   # inside a wall or a house
		var e := Enemy.new()
		e.kind = "shambler"
		e.position = Vector3(pos.x, 0.05, pos.z)
		add_child(e)
		e.player = player
		e.aggro_range = 40.0
		_crowd.append(e)
		made += 1
	_perf.visible = true
	player.show_status("Crowd: %d extra shamblers" % _crowd.size(), 1.5)


## Cover test (G): a stand-in for a raider. It stands where the crosshair is and shoots at you whenever it can see
## you, so the cover rules can be tried before raiders exist.
func _add_gunner() -> void:
	var at := player.global_position + player.reticle_offset
	if player.reticle_offset.length() < 3.0:
		at = player.global_position + player.facing * 10.0
	var g := TestGunner.new()
	g.position = Vector3(at.x, 0.0, at.z)
	g.player = player
	add_child(g)
	player.show_status("Test gunner added (Shift+G removes them)", 1.5)


func _clear_crowd() -> void:
	for e in _crowd:
		if is_instance_valid(e):
			player.release_grab(e)
			e.queue_free()
	_crowd.clear()
	_perf.visible = false
	player.show_status("Crowd cleared", 1.0)


func _make_perf_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_perf = Label.new()
	# top right, under the INPUT CHECK box, clear of the help text
	_perf.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_perf.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_perf.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_perf.offset_top = 300.0
	_perf.offset_right = -20.0
	_perf.add_theme_font_size_override("font_size", 20)
	_perf.add_theme_color_override("font_outline_color", Color.BLACK)
	_perf.add_theme_constant_override("outline_size", 6)
	_perf.visible = false
	layer.add_child(_perf)


## Twice a second: frame rate, how many zombies, and where the time goes. Posing is per drawn frame; zombie AI and
## movement is per physics tick (60 a second, each with 16.7 ms to spare).
func _process(delta: float) -> void:
	if _zone_label != null and _zone_label.visible:
		_zone_t -= delta
		if _zone_t <= 0.0:
			_zone_t = 1.0
			_zone_label.text = horde.readout()
	if _perf == null or not _perf.visible:
		Enemy.anim_usec = 0
		Enemy.zombie_usec = 0
		return
	_perf_t += delta
	_perf_frames += 1
	if _perf_t < 0.5:
		return
	var ticks := maxf(_perf_t * Engine.physics_ticks_per_second, 1.0)
	var anim_ms := Enemy.anim_usec / float(_perf_frames) / 1000.0
	var ai_ms := Enemy.zombie_usec / ticks / 1000.0
	Enemy.anim_usec = 0
	Enemy.zombie_usec = 0
	_perf_t = 0.0
	_perf_frames = 0
	var alive := 0
	var seen := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en != null and en.body != null and not en.dead:
			alive += 1
			if en._alpha > 0.0:
				seen += 1
	_perf.text = "CROWD TEST   F5 +%d   F6 clear   F7 can't be hurt: %s   L all low model: %s\n" % [CROWD_STEP,
			"ON" if player.invulnerable else "OFF", "ON" if ZombieBody.force_low else "OFF"] \
		+ "%d FPS   frame %.1f ms   physics %.1f ms\n" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0] \
		+ "zombies %d (%d in view)\n" % [alive, seen] \
		+ "zombie posing %.2f ms per frame   zombie AI+movement %.2f ms per tick\n" % [anim_ms, ai_ms] \
		+ "draw calls %d   triangles %dk" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)]


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
	gb.size = Vector3(WORLD_X1 - WORLD_X0 + 10.0, 1, WORLD_Z1 - WORLD_Z0 + 10.0)
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
	ground.position = Vector3((WORLD_X0 + WORLD_X1) * 0.5, -0.5, (WORLD_Z0 + WORLD_Z1) * 0.5)
	add_child(ground)


func _build_level() -> void:
	var wall_col := Color(0.55, 0.52, 0.48)
	# Outer wall around the whole map
	var mid_z := (WORLD_Z0 + WORLD_Z1) * 0.5
	var len_z := WORLD_Z1 - WORLD_Z0 + 1.0
	_box(Vector3(0, WALL_H / 2, WORLD_Z0), Vector3(81, WALL_H, 1), wall_col)
	_box(Vector3(0, WALL_H / 2, WORLD_Z1), Vector3(81, WALL_H, 1), wall_col)
	_box(Vector3(WORLD_X0, WALL_H / 2, mid_z), Vector3(1, WALL_H, len_z), wall_col)
	_box(Vector3(WORLD_X1, WALL_H / 2, mid_z), Vector3(1, WALL_H, len_z), wall_col)
	# Wall between the yard and the cul-de-sac, with a gap for the road (x -5..5)
	_box(Vector3(-22.5, WALL_H / 2, -40), Vector3(35, WALL_H, 1), wall_col)
	_box(Vector3(22.5, WALL_H / 2, -40), Vector3(35, WALL_H, 1), wall_col)

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

	# Ammo: the tutorial crate by the spawn, and one in the yard house
	for p in [Vector3(3, 0, 4), Vector3(0, 0, -20)]:
		_ammo(p)

	_sign(Vector3(3, 1.6, 4), "Ammo: weapon away, walk up, interact")
	_sign(Vector3(0, 3.2, -9.6), "Click the door to open it")
	_sign(Vector3(7.6, 3.2, -16), "Locked: dash into it")
	_sign(Vector3(-15, 3.0, 2), "Dummies")
	_sign(Vector3(20, 3.0, 0), "Shamblers")
	_sign(Vector3(0, 3.4, -38), "Cul-de-sac ahead: ammo is in some of the houses")

	_build_raider_camp()
	_build_culdesac()


# ------------------------------------------------------------------ cul-de-sac
func _build_culdesac() -> void:
	# Road in from the yard, ending in a turning circle.
	var asphalt := Color(0.2, 0.2, 0.22)
	var bulb := Vector3(0, 0, -78)
	_flat_box(Vector3(0, 0.02, -51.5), Vector3(8, 0.04, 31), asphalt)
	var circle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 14.0
	cm.bottom_radius = 14.0
	cm.height = 0.04
	circle.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = asphalt
	cmat.roughness = 0.95
	circle.material_override = cmat
	circle.position = bulb + Vector3(0, 0.02, 0)
	add_child(circle)

	# Houses: center (x, z), width (x), depth (z), which wall the front door is on.
	_house(Vector2(-14, -53), 10, 12, "E", Color(0.66, 0.6, 0.5))          # street, west side
	_house(Vector2(14, -53), 10, 12, "W", Color(0.58, 0.62, 0.66))         # street, east side
	_house(Vector2(-27, -78), 10, 12, "E", Color(0.68, 0.58, 0.52))        # circle, west
	_house(Vector2(27, -78), 10, 12, "W", Color(0.6, 0.66, 0.58), 0.0, -1.5)  # circle, east (back room)
	_house(Vector2(-19, -98), 10, 10, "S", Color(0.64, 0.62, 0.55))        # circle, north-west
	_house(Vector2(0, -102), 14, 10, "S", Color(0.7, 0.64, 0.56), 1.2)     # circle, north (side room)
	_house(Vector2(19, -98), 10, 10, "S", Color(0.6, 0.58, 0.62))          # circle, north-east

	# Abandoned cars on the circle: cover you can see and shoot over.
	_box(Vector3(-5, 0.7, -80), Vector3(1.9, 1.4, 4.2), Color(0.5, 0.18, 0.16))
	_box(Vector3(9, 0.7, -70), Vector3(4.2, 1.4, 1.9), Color(0.2, 0.3, 0.5))

	# Ammo, inside four of the seven houses.
	for p in [Vector3(-16, 0, -56), Vector3(30, 0, -82), Vector3(5, 0, -104.5), Vector3(21, 0, -100.5)]:
		_ammo(p)

	# Zombies: on the street, all over the circle, on the lawns, and waiting indoors.
	var spots: Array[Vector3] = [
		Vector3(-2, 0.05, -47), Vector3(2.5, 0.05, -55), Vector3(-1, 0.05, -62),
		Vector3(0, 0.05, -78), Vector3(-6, 0.05, -72), Vector3(7, 0.05, -75), Vector3(-9, 0.05, -83),
		Vector3(6, 0.05, -84), Vector3(0, 0.05, -88), Vector3(11, 0.05, -80), Vector3(-11, 0.05, -76),
		Vector3(-18, 0.05, -66), Vector3(18, 0.05, -67), Vector3(-12, 0.05, -91), Vector3(12, 0.05, -91),
		Vector3(14, 0.05, -55), Vector3(-28, 0.05, -76), Vector3(27, 0.05, -75),
		Vector3(-19, 0.05, -99), Vector3(-3, 0.05, -103), Vector3(17, 0.05, -96),
	]
	for p in spots:
		_enemy("shambler", p)


## A house: four walls with a front door (flanked by windows) on door_side ("N", "S", "E" or
## "W") and windows on the other walls. No roof, so you can see in from above once it's in view.
## split_x / split_z add an inside wall (with an open doorway) that many meters off center,
## running north-south / east-west, to make a second room.
func _house(c: Vector2, w: float, d: float, door_side: String, col: Color,
		split_x := 0.0, split_z := 0.0) -> void:
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var z0 := c.y - d * 0.5   # north wall
	var z1 := c.y + d * 0.5   # south wall
	_flat_box(Vector3(c.x, 0.02, c.y), Vector3(w, 0.04, d), Color(0.4, 0.33, 0.26))   # floorboards
	_wall(Vector2(x0, z0), Vector2(x1, z0), _openings(w, door_side == "N"), col)
	_wall(Vector2(x0, z1), Vector2(x1, z1), _openings(w, door_side == "S"), col)
	_wall(Vector2(x0, z0), Vector2(x0, z1), _openings(d, door_side == "W"), col)
	_wall(Vector2(x1, z0), Vector2(x1, z1), _openings(d, door_side == "E"), col)
	var inner := col.darkened(0.12)
	if split_x != 0.0:
		_wall(Vector2(c.x + split_x, z0), Vector2(c.x + split_x, z1),
			[{"at": d * 0.5 - DOOR_W * 0.5, "w": DOOR_W, "kind": "gap"}], inner)
	if split_z != 0.0:
		_wall(Vector2(x0, c.y + split_z), Vector2(x1, c.y + split_z),
			[{"at": w * 0.5 - DOOR_W * 0.5, "w": DOOR_W, "kind": "gap"}], inner)


## Openings for one outside wall of the given length: a centered door with a window either
## side, or just windows.
func _openings(length: float, has_door: bool) -> Array:
	var o := []
	if has_door:
		o.append({"at": length * 0.5 - DOOR_W * 0.5, "w": DOOR_W, "kind": "door"})
		o.append({"at": length * 0.22 - WINDOW_W * 0.5, "w": WINDOW_W, "kind": "window"})
		o.append({"at": length * 0.78 - WINDOW_W * 0.5, "w": WINDOW_W, "kind": "window"})
	elif length >= 12.0:
		o.append({"at": length * 0.3 - WINDOW_W * 0.5, "w": WINDOW_W, "kind": "window"})
		o.append({"at": length * 0.7 - WINDOW_W * 0.5, "w": WINDOW_W, "kind": "window"})
	else:
		o.append({"at": length * 0.5 - WINDOW_W * 0.5, "w": WINDOW_W, "kind": "window"})
	return o


## A straight wall from a to b (XZ; must run along X or along Z) with openings cut into it.
## Each opening is {"at": meters from the west/north end to its near edge, "w": width,
## "kind": "door" (hinged Door), "window" (sill + glass) or "gap" (open doorway)}.
func _wall(a: Vector2, b: Vector2, openings: Array, col: Color) -> void:
	if a.x > b.x or a.y > b.y:
		var t := a
		a = b
		b = t
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var length := (b - a).length()
	openings.sort_custom(func(p, q): return p["at"] < q["at"])
	var cursor := -WALL_T * 0.5   # run half a thickness past each end so corners close up
	for o in openings:
		var o0: float = o["at"]
		var o1: float = o0 + float(o["w"])
		_wall_piece(a, along_x, cursor, o0, 0.0, WALL_H, col)
		match o["kind"]:
			"window":
				_wall_piece(a, along_x, o0, o1, 0.0, SILL_H, col)
				_wall_piece(a, along_x, o0, o1, HEAD_H, WALL_H, col)
				_glass(a, along_x, o0, o1)
			"door":
				_wall_piece(a, along_x, o0, o1, DOOR_H, WALL_H, col)
				var door := Door.new()
				if along_x:
					door.position = Vector3(a.x + o0, 0, a.y)       # panel runs toward +X
				else:
					door.position = Vector3(a.x, 0, a.y + o1)       # turned: panel runs toward -Z
					door.rotation.y = PI / 2
				add_child(door)
			_:
				_wall_piece(a, along_x, o0, o1, DOOR_H, WALL_H, col)
		cursor = o1
	_wall_piece(a, along_x, cursor, length + WALL_T * 0.5, 0.0, WALL_H, col)


## One solid block of a wall: from d0 to d1 meters along it, from height y0 up to y1.
func _wall_piece(a: Vector2, along_x: bool, d0: float, d1: float, y0: float, y1: float, col: Color) -> void:
	if d1 - d0 < 0.01:
		return
	var mid := (d0 + d1) * 0.5
	var y := (y0 + y1) * 0.5
	if along_x:
		_box(Vector3(a.x + mid, y, a.y), Vector3(d1 - d0, y1 - y0, WALL_T), col)
	else:
		_box(Vector3(a.x, y, a.y + mid), Vector3(WALL_T, y1 - y0, d1 - d0), col)


## Window glass: looks only. It doesn't stop sight, bullets or anything else (yet).
func _glass(a: Vector2, along_x: bool, d0: float, d1: float) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var mid := (d0 + d1) * 0.5
	if along_x:
		bm.size = Vector3(d1 - d0, HEAD_H - SILL_H, 0.05)
		m.position = Vector3(a.x + mid, (SILL_H + HEAD_H) * 0.5, a.y)
	else:
		bm.size = Vector3(0.05, HEAD_H - SILL_H, d1 - d0)
		m.position = Vector3(a.x, (SILL_H + HEAD_H) * 0.5, a.y + mid)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.8, 0.95, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


## A flat colored slab with no collision (road, floorboards).
func _flat_box(pos: Vector3, size: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _ammo(pos: Vector3) -> void:
	var a := AmmoPickup.new()
	a.position = pos
	add_child(a)


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
	m.material_override = Cutaway.solid(col)   # opens up when it stands between the camera and you
	b.add_child(m)
	add_child(b)
	Cover.add_box(b, pos, size)   # anything solid standing on the ground is cover (cover.gd)
	return b


## Raiders' camp, in the south-west corner of the yard: three raiders on watch among things to hide behind.
func _build_raider_camp() -> void:
	var crate := Color(0.45, 0.36, 0.25)
	var wall_col := Color(0.5, 0.48, 0.44)
	_box(Vector3(-26, 0.55, 20), Vector3(4.0, 1.1, 0.5), wall_col)     # a low wall facing the yard
	_box(Vector3(-19, 0.55, 23), Vector3(0.5, 1.1, 3.5), wall_col)     # and one on the east side
	_box(Vector3(-30, 0.6, 24), Vector3(1.2, 1.2, 1.2), crate)
	_box(Vector3(-23, 0.6, 27), Vector3(1.2, 1.2, 1.2), crate)
	_box(Vector3(-27, 1.3, 30), Vector3(3.0, 2.6, 0.4), wall_col)      # a standing wall to lean round
	_box(Vector3(-33, 1.0, 29), Vector3(1.0, 2.0, 1.0), wall_col)
	# Cover on the way in, for you.
	_box(Vector3(-17, 0.6, 14), Vector3(1.2, 1.2, 1.2), crate)
	_box(Vector3(-24, 0.55, 12), Vector3(3.0, 1.1, 0.5), wall_col)
	_box(Vector3(-11, 1.0, 20), Vector3(1.0, 2.0, 1.0), wall_col)
	for p in [Vector3(-26, 0.05, 23), Vector3(-22, 0.05, 25), Vector3(-30, 0.05, 27)]:
		_raider(p)
	_sign(Vector3(-25, 3.2, 21), "Raiders: they use cover and shoot back")


func _raider(pos: Vector3) -> Raider:
	var r := Raider.new()
	r.position = pos
	r.facing = Vector3(0.6, 0.0, -0.8).normalized()   # watching the yard
	add_child(r)
	r.player = player
	return r


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
