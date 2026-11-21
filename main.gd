extends Node3D
## Builds the whole test level in code.
##  - Training yard (z -40..40): a small house with a normal door (south) and a heavy locked
##    door (east), training dummies, a few shamblers, the tutorial ammo crate.
##  - Cul-de-sac (north of the yard, through the gap in the wall): a short street ending in a
##    crossroads of dead ends, seven houses with doors and windows, a lot of zombies, and ammo hidden
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
var _test_wound := 0
var _plain_ground: ShaderMaterial
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
	Solid.reset()
	HouseKit.reset()
	FenceKit.reset()
	StreetKit.reset()
	FurnitureKit.reset()
	Cutaway.reset()
	add_child(Wear.new())
	add_child(Spill.new())
	TallGrass.clear()
	Daylight.reset()
	add_child(Daylight.new())
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
			KEY_F2:   # how much of the UI shows: everything, only what you need, nothing
				player.show_status(hud.next_ui_level(), 1.6)
			KEY_F3:
				hud.toggle_debug()
			KEY_C: hud.toggle_sheet()
			KEY_H: player.toggle_treat()
			KEY_J:   # a test wound, to try the treatment screen on
				var tw: Array = [["deep cut", "ArmL", 30.0], ["gunshot", "Torso", 26.0], ["bite", "ArmR", 20.0]][_test_wound % 3]
				_test_wound += 1
				player._wound(tw[0], tw[2], tw[1])
				player.show_status("Test wound: %s." % tw[0])
			KEY_PAGEUP: hud.sheet_select(-1)
			KEY_PAGEDOWN: hud.sheet_select(1)
			KEY_ENTER, KEY_KP_ENTER:
				if event.shift_pressed:
					hud.sheet_apart()
				else:
					hud.sheet_use()
			KEY_DELETE, KEY_BACKSPACE: hud.sheet_drop()
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
			KEY_M:   # the season, by hand until there is a clock
				player.show_status("%s." % Seasons.it.next_season(), 1.5)
			KEY_K:   # rain on and off
				Seasons.it.set_rain(not Seasons.it.raining)
				player.show_status("It is raining." if Seasons.it.raining else "The rain stops.", 1.5)
			KEY_B:   # the new ground / the old plain one
				var gm := Ground.it.mesh
				gm.material_override = _plain_ground if gm.material_override == Ground.it.material else Ground.it.material
			KEY_N:   # the time of day, by hand until there is a clock: day, dusk, night, dawn
				player.show_status("%s." % Daylight.next_time(), 1.5)
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
			KEY_P:   # board up the window by the crosshair (hammer, nails, planks), or prise its boards off (crowbar)
				if event.shift_pressed:
					# The old stand-in, for testing: boarded at once, for nothing.
					var win := Solid.window_near(player.global_position + player.reticle_offset, 2.5)
					if win.is_empty():
						player.show_status("No window by the crosshair.", 1.5)
					else:
						player.show_status("Boarded up (for nothing: a test key)." if Solid.board(win) else "It is boarded already.", 1.5)
				else:
					player.work_window()
			KEY_Y:   # lay the broken glass you carry, as an alarm or a trap
				player.lay_glass()
			KEY_I:   # what you carry, as slots and a bag's grid (loot_screen.gd); Shift+I: filter or treat your water
				if event.shift_pressed:
					player.purify_water()
				else:
					player.toggle_things()
			KEY_U:   # shoes on and off, if you have any. Shift+U: the old test switch, shod or not
				if event.shift_pressed:
					player.barefoot = not player.barefoot
					player.show_status("Barefoot." if player.barefoot else "Shod (a test key: no shoes needed).", 1.5)
				elif player.inv.worn.has("feet"):
					player.use_item("worn:feet")
				else:
					var shoe := ""
					for sl in player.inv.slot_list():
						var it = player.inv.slots.get(sl[0])
						if it != null and str(Items.DEFS[it["id"]].get("wear", "")) == "feet":
							shoe = sl[0]
							break
					if shoe != "":
						player.use_item(shoe)
					else:
						player.show_status("You have nothing to put on your feet.", 1.5)
			KEY_O:   # break what the crosshair is on; Shift+O: ten minutes of rust and rot
				if event.shift_pressed:
					for w in get_tree().get_nodes_in_group("weathering"):
						(w as Wear).pass_time(600.0)
					player.show_status("Ten minutes of rust and rot.", 1.5)
				elif player.hover_breakable != null:
					player.hover_breakable.hit(100000.0, "pound", player.global_position + player.reticle_offset, player)
				else:
					player.show_status("Ready, with the crosshair on something.", 1.5)
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

	# The ground: soil, with a dirt road up the yard to the street, a ploughed field, and a patch each of clay and
	# mud (assets/ground: ground.gd paints it, ground.gdshader draws it, seasons.gd turns the year).
	add_child(Seasons.new())
	var ground := Ground.new()
	add_child(ground)
	ground.setup(Rect2(WORLD_X0, WORLD_Z0, WORLD_X1 - WORLD_X0, WORLD_Z1 - WORLD_Z0), "soil")
	ground.road([Vector2(-1, 40), Vector2(1.5, 26), Vector2(-1, 12), Vector2(0.5, -4), Vector2(0, -20), Vector2(0, -36)])
	ground.rect("farm", Rect2(18, 16, 18, 17), 14.0)
	ground.blob("clay", Vector2(10, 31), 4.0)
	ground.blob("mud", Vector2(-10, 24), 3.5)
	# Grass: a lawn round the spawn, a meadow along the west side of the yard, rough ground toward the raider camp
	# and under the tall grass.
	ground.blob("lawn", Vector2(-4, 6), 5.0)
	ground.rect("meadow", Rect2(-38, -30, 14, 34))
	ground.blob("rough", Vector2(-18, 14), 6.0)
	ground.rect("rough", Rect2(5, 7, 11, 9))
	ground.apply()
	var push := GrassPush.new()          # zombies and raiders part the standing grass too
	push.player = player
	add_child(push)
	_grow_grass.call_deferred(ground)      # once the level's walls and crates are in, so nothing grows inside them
	# The old plain ground, kept to fall back on (B) if the new shader misbehaves on some machine.
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
	_plain_ground = ShaderMaterial.new()
	_plain_ground.shader = sh


func _build_level() -> void:
	var wall_col := Color(0.55, 0.52, 0.48)
	# Outer wall around the whole map. It is the edge of the test map, not a thing in the world: the one
	# thing that can't be broken (`fixed`).
	var mid_z := (WORLD_Z0 + WORLD_Z1) * 0.5
	var len_z := WORLD_Z1 - WORLD_Z0 + 1.0
	Breakable.of(_box(Vector3(0, WALL_H / 2, WORLD_Z0), Vector3(81, WALL_H, 1), wall_col, "concrete")).fixed = true
	Breakable.of(_box(Vector3(0, WALL_H / 2, WORLD_Z1), Vector3(81, WALL_H, 1), wall_col, "concrete")).fixed = true
	Breakable.of(_box(Vector3(WORLD_X0, WALL_H / 2, mid_z), Vector3(1, WALL_H, len_z), wall_col, "concrete")).fixed = true
	Breakable.of(_box(Vector3(WORLD_X1, WALL_H / 2, mid_z), Vector3(1, WALL_H, len_z), wall_col, "concrete")).fixed = true
	# Wall between the yard and the cul-de-sac, with a gap for the road (x -5..5)
	_box(Vector3(-22.5, WALL_H / 2, -40), Vector3(35, WALL_H, 1), wall_col)
	_box(Vector3(22.5, WALL_H / 2, -40), Vector3(35, WALL_H, 1), wall_col)

	# House: x -7..7, z -22..-10
	var hc := Color(0.62, 0.56, 0.47)
	Cutaway.add_building(Rect2(-7, -22, 14, 12), 0.0, WALL_H + 0.2, 0.0, 2.7, 0.3)   # it opens round whoever is inside
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
	_box(Vector3(-5, 0.6, 1), Vector3(1.2, 1.2, 1.2), crate, "wood", "crate")
	_box(Vector3(6, 0.6, -3), Vector3(1.2, 1.2, 1.2), crate, "wood", "crate")
	_box(Vector3(12, 1.0, -6), Vector3(1, 2, 1), wall_col)
	_box(Vector3(16, 1.0, 3), Vector3(1, 2, 1), wall_col)
	_box(Vector3(-3, 0.5, -16), Vector3(2.4, 1.0, 1.0), crate, "wood", "crate")
	_box(Vector3(4, 0.6, -19), Vector3(1.2, 1.2, 1.2), crate, "wood", "crate")

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

	# A first-aid box by the spawn, and one in the yard house: what the treatment screen (H) needs.
	for p in [Vector3(-3, 0, 4), Vector3(1.5, 0, -20)]:
		_first_aid(p)
	_sign(Vector3(-3, 1.6, 4), "First aid: take it, then H treats wounds")
	# A tool box (the hatchet and the steroids, for a bite), and things to throw lying about.
	var tools := ItemPickup.new()
	tools.title = "Tool box"
	tools.tint = Color(0.7, 0.3, 0.2)
	tools.position = Vector3(-5, 0, 4)
	tools.contents = [Items.make("steroids"), Items.make("hatchet"), Items.make("torch"), Items.make("battery", 2), Items.make("fire_torch"), Items.make("sledgehammer")]
	add_child(tools)
	# What the things already in the game were waiting for (items.gd): boards for a window, boots and a helmet.
	var joiner := ItemPickup.new()
	joiner.title = "Carpenter's box"
	joiner.tint = Color(0.62, 0.48, 0.3)
	joiner.position = Vector3(-5, 0, 6)
	joiner.contents = [Items.make("hammer"), Items.make("nails"), Items.make("plank", 4), Items.make("crowbar")]
	add_child(joiner)
	var kit_box := ItemPickup.new()
	kit_box.title = "Boots, a helmet and a pack"
	kit_box.tint = Color(0.4, 0.42, 0.36)
	kit_box.position = Vector3(-7, 0, 6)
	kit_box.contents = [Items.make("boots"), Items.make("helmet"), Items.make("backpack")]
	add_child(kit_box)
	_place_grass.call_deferred()     # once the whole level is built, so it lands clear of everything
	for p in [Vector3(-1.5, 0, 3), Vector3(1.5, 0, 3), Vector3(-9, 0, 9), Vector3(-14, 0, 13)]:
		_throwable("rock", p)
	for p in [Vector3(0, 0, 2.5), Vector3(-2.5, 0, 2.5), Vector3(-11, 0, 11)]:
		_throwable("bottle", p)
	_sign(Vector3(0, 3.2, -9.6), "Click the door to open it")
	_sign(Vector3(7.6, 3.2, -16), "Locked: bash it (Strength 13, dash)")
	_sign(Vector3(-15, 3.0, 2), "Dummies")
	_sign(Vector3(20, 3.0, 0), "Shamblers")
	_sign(Vector3(0, 3.4, -38), "Cul-de-sac ahead: ammo is in some of the houses")

	# Things to break, one of each sort (everything else in the level breaks too): furniture, an appliance,
	# (and once a street sign: the street kit has its own now). Each is there for a reason: cover, and what it is made of.
	_box(Vector3(-4.5, 0.4, -12.5), Vector3(1.6, 0.8, 0.9), Color(0.5, 0.36, 0.22), "wood", "table")
	_box(Vector3(-6.2, 0.9, -21.2), Vector3(0.8, 1.8, 0.8), Color(0.86, 0.87, 0.85), "metal", "fridge", {"metal": 0.6, "plastic": 0.4})
	# (The street sign that stood here is now one of the street kit's own: see _build_culdesac.)
	# Water (water.gd): a rain barrel and a trough of standing water to fill a bottle from, a fire to boil
	# it on, and tablets and a filter. The barrel and the trough break like anything else, and the water
	# goes with them.
	_water(Vector3(-8, 0.5, 5), Vector3(0.7, 1.0, 0.7), Color(0.2, 0.35, 0.5), "plastic", "rain barrel", "rain")
	_water(Vector3(-10.5, 0.3, 5), Vector3(1.6, 0.6, 0.7), Color(0.45, 0.47, 0.5), "metal", "water trough", "pond")
	_lamp(Vector3(-9, 0, 8), 5.0, true)
	var kit := ItemPickup.new()
	kit.title = "Water kit"
	kit.tint = Color(0.3, 0.55, 0.8)
	kit.position = Vector3(-7, 0, 4)
	kit.contents = [Items.make("purify_tabs"), Items.make("water_filter")]
	add_child(kit)
	_sign(Vector3(-9, 2.2, 6), "Water: fill a bottle here. Boil it on the fire (with a pot), or Shift+I treats it. I: your things; right-click the bottle to drink")
	_sign(Vector3(0, 2.6, 5), "Break things: Ready, crosshair on it, left-click. P boards a window: hammer, nails, planks")

	# Houses from the kit (assets/buildings/house): a sound two-storey one, and a small derelict one beside
	# it, to compare. Every part of them is a Solid like the rest of the level.
	HouseKit.house(self, Vector3(18, 0, -34), 3, 2, 2, 0, 0, Vector4(-1.0, 0.0, 0.0, 0.0), true)
	HouseKit.house(self, Vector3(30, 0, -34), 2, 2, 1, 2, 1)
	# Furniture (assets/buildings/furniture): the sound house furnished room by room; the derelict one has
	# what is left of its own. Low pieces are cover, tall ones stop sight, and the stove boils water.
	FurnitureKit.furnish(self, Vector3(18, 0, -34), 2, 0)
	# In its kitchen: what a stove wants and what you eat (the stove is cold: lay wood on it and light it).
	var larder := ItemPickup.new()
	larder.title = "Kitchen things"
	larder.tint = Color(0.8, 0.74, 0.5)
	larder.position = Vector3(25.2, 0, -29.3)
	larder.contents = [Items.make("cooking_pot"), Items.make("matches"), Items.make("canned_food", 3), Items.make("can_opener")]
	add_child(larder)
	var left := FurnitureKit.new(self, 2, 1, 1)
	left.put("couch", Vector3(31.5, 0, -28.6), "N")
	left.put("table", Vector3(34.4, 0, -32.4), "S")
	left.put("dresser", Vector3(31.5, 0, -33.6), "S")
	# Fences (assets/buildings/fence): one of each kind, each doing its own job.
	# A picket front yard for the derelict house, as worn as the house: low cover, and a zombie has to climb it.
	var picket_yard := FenceKit.new(self, "picket", 2)
	picket_yard.run(Vector2(30, -27.85), Vector2(30, -23.5), [], Vector2(-1, 0))
	picket_yard.run(Vector2(30, -23.5), Vector2(36, -23.5), [3.0])
	picket_yard.run(Vector2(36, -27.85), Vector2(36, -23.5))
	# A boarded back yard behind both houses, against the yard's wall: nothing sees in, and the only way in
	# without breaking something is the gate between the houses.
	var board_yard := FenceKit.new(self, "board")
	board_yard.run(Vector2(18, -39.5), Vector2(18, -34.15), [], Vector2(-1, 0))
	board_yard.run(Vector2(36, -39.5), Vector2(36, -34.15))
	board_yard.run(Vector2(27.15, -34), Vector2(29.85, -34), [1.35])
	# A rail fence round the ploughed field: it hides nobody and stops no shot, it only slows what crosses it.
	FenceKit.yard(self, Rect2(18, 16, 18, 17), "rail", "W")
	_sign(Vector3(22.5, 3.4, -27), "Kit house: two storeys and a basement. The stairs are inside, to the left")
	_sign(Vector3(33, 3.4, -27), "The same kit, derelict: far easier to break into")

	_build_raider_camp()
	_build_culdesac()


# ------------------------------------------------------------------ cul-de-sac
func _build_culdesac() -> void:
	# The street in from the yard (assets/buildings/street): four tiles north from the gap in the yard's wall
	# to a crossroads, with a short dead end off it to the west, the east and the north. It is firm in all
	# weather and takes no prints (except in snow); it is pavement, to be broken up for rock.
	var street := StreetKit.new(self, Vector3(-14, 0, -94), 1)
	street.plan([" # ",
				 "###",
				 " # ",
				 " # ",
				 " # ",
				 " # "])
	street.open(Vector2i(1, 5), "S")          # it carries on through the gap, to the yard's dirt road
	street.build()
	street.furnish()                          # lamps on the straights, signs at the crossroads and the dead ends

	# Houses: center (x, z), width (x), depth (z), which wall the front door is on.
	_house(Vector2(-14, -53), 10, 12, "E", Color(0.66, 0.6, 0.5))          # street, west side
	_house(Vector2(14, -53), 10, 12, "W", Color(0.58, 0.62, 0.66))         # street, east side
	_house(Vector2(-27, -78), 10, 12, "E", Color(0.68, 0.58, 0.52))        # circle, west
	_house(Vector2(27, -78), 10, 12, "W", Color(0.6, 0.66, 0.58), 0.0, -1.5)  # circle, east (back room)
	_house(Vector2(-19, -98), 10, 10, "S", Color(0.64, 0.62, 0.55))        # circle, north-west
	_house(Vector2(0, -102), 14, 10, "S", Color(0.7, 0.64, 0.56), 1.2)     # circle, north (side room)
	_house(Vector2(19, -98), 10, 10, "S", Color(0.6, 0.58, 0.62))          # circle, north-east

	# Abandoned cars on the circle: cover you can see and shoot over.
	_box(Vector3(-5, 0.7, -80), Vector3(1.9, 1.4, 4.2), Color(0.5, 0.18, 0.16), "metal", "car", {"metal": 0.7, "glass": 0.1, "plastic": 0.2})
	_box(Vector3(9, 0.7, -70), Vector3(4.2, 1.4, 1.9), Color(0.2, 0.3, 0.5), "metal", "car", {"metal": 0.7, "glass": 0.1, "plastic": 0.2})

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
	Cutaway.add_building(Rect2(x0, z0, w, d), 0.0, WALL_H + 0.2, 0.0, 2.7, 0.3)   # it opens round whoever is inside
	_flat_box(Vector3(c.x, 0.02, c.y), Vector3(w, 0.04, d), Color(0.4, 0.33, 0.26))   # floorboards
	_wall(Vector2(x0, z0), Vector2(x1, z0), _openings(w, door_side == "N"), col)
	_wall(Vector2(x0, z1), Vector2(x1, z1), _openings(w, door_side == "S"), col)
	_wall(Vector2(x0, z0), Vector2(x0, z1), _openings(d, door_side == "W"), col)
	_wall(Vector2(x1, z0), Vector2(x1, z1), _openings(d, door_side == "E"), col)
	var inner := col.darkened(0.12)
	if split_x != 0.0:
		_wall(Vector2(c.x + split_x, z0), Vector2(c.x + split_x, z1),
			[{"at": d * 0.5 - DOOR_W * 0.5, "w": DOOR_W, "kind": "gap"}], inner, "plaster")
	if split_z != 0.0:
		_wall(Vector2(x0, c.y + split_z), Vector2(x1, c.y + split_z),
			[{"at": w * 0.5 - DOOR_W * 0.5, "w": DOOR_W, "kind": "gap"}], inner, "plaster")


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
func _wall(a: Vector2, b: Vector2, openings: Array, col: Color, stuff := "brick") -> void:
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
		_wall_piece(a, along_x, cursor, o0, 0.0, WALL_H, col, stuff)
		match o["kind"]:
			"window":
				_wall_piece(a, along_x, o0, o1, 0.0, SILL_H, col, stuff)
				_wall_piece(a, along_x, o0, o1, HEAD_H, WALL_H, col, stuff)
				_glass(a, along_x, o0, o1)
			"door":
				_wall_piece(a, along_x, o0, o1, DOOR_H, WALL_H, col, stuff)
				var door := Door.new()
				if along_x:
					door.position = Vector3(a.x + o0, 0, a.y)       # panel runs toward +X
				else:
					door.position = Vector3(a.x, 0, a.y + o1)       # turned: panel runs toward -Z
					door.rotation.y = PI / 2
				add_child(door)
			_:
				_wall_piece(a, along_x, o0, o1, DOOR_H, WALL_H, col, stuff)
		cursor = o1
	_wall_piece(a, along_x, cursor, length + WALL_T * 0.5, 0.0, WALL_H, col, stuff)


## One solid block of a wall: from d0 to d1 meters along it, from height y0 up to y1.
func _wall_piece(a: Vector2, along_x: bool, d0: float, d1: float, y0: float, y1: float, col: Color, stuff := "brick") -> void:
	if d1 - d0 < 0.01:
		return
	var mid := (d0 + d1) * 0.5
	var y := (y0 + y1) * 0.5
	if along_x:
		_box(Vector3(a.x + mid, y, a.y), Vector3(d1 - d0, y1 - y0, WALL_T), col, stuff)
	else:
		_box(Vector3(a.x, y, a.y + mid), Vector3(WALL_T, y1 - y0, d1 - d0), col, stuff)


## Window glass. It stops bodies, not sight; a shot or a blow breaks it (solid.gd).
func _glass(a: Vector2, along_x: bool, d0: float, d1: float) -> void:
	var mid := (d0 + d1) * 0.5
	var y := (SILL_H + HEAD_H) * 0.5
	if along_x:
		Solid.pane(self, Vector3(a.x + mid, y, a.y), Vector3(d1 - d0, HEAD_H - SILL_H, 0.05))
	else:
		Solid.pane(self, Vector3(a.x, y, a.y + mid), Vector3(0.05, HEAD_H - SILL_H, d1 - d0))


## A flat slab with no collision (pavement, floorboards). Broken up a square metre at a time with the right
## tool (solid.gd).
func _flat_box(pos: Vector3, size: Vector3, col: Color, stuff := "wood", what := "floor") -> void:
	Solid.slab(self, pos, size, col, stuff, what)


## Something that holds water, to fill a bottle from. `source` is a key of Water.SOURCES.
func _water(pos: Vector3, size: Vector3, col: Color, stuff: String, what: String, source: String) -> void:
	var ws := WaterSource.new()
	ws.kind = source
	_box(pos, size, col, stuff, what).add_child(ws)


func _first_aid(pos: Vector3) -> void:
	var b := ItemPickup.new()
	b.position = pos
	b.contents = [Items.make("bandage", 3), Items.make("clean_rag", 2), Items.make("needle_thread"),
		Items.make("tweezers"), Items.make("vodka"), Items.make("water"), Items.make("painkillers"), Items.make("antibiotics")]
	add_child(b)


func _grow_grass(ground: Ground) -> void:
	ground.grow_grass()


func _place_grass() -> void:
	# Tall grass to go to ground in (a stand-in look): the first of these patches that is clear of everything.
	for r: Rect2 in [Rect2(6, 8, 9, 7), Rect2(-16, 16, 9, 7), Rect2(8, 18, 9, 7)]:
		var clear_of := true
		for c: Vector2 in [r.position, r.end, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.get_center()]:
			clear_of = clear_of and Cover.has_room(c, null)
		for b in Cover.boxes:
			clear_of = clear_of and not b.rect.intersects(r)
		if clear_of:
			var g := TallGrass.new()
			g.area = r
			add_child(g)
			_sign(Vector3(r.get_center().x, 1.9, r.get_center().y), "Tall grass: crouch (Ctrl) or lie down (X) in it")
			break


## One thing to throw, lying on the ground.
func _throwable(id: String, pos: Vector3) -> void:
	var b := ItemPickup.new()
	b.title = Items.name_of(id)
	b.small = true
	b.tint = Thrown.LOOK[id][1]
	b.position = pos
	b.contents = [Items.make(id)]
	add_child(b)


func _ammo(pos: Vector3) -> void:
	var a := AmmoPickup.new()
	a.position = pos
	add_child(a)


## Anything solid. `stuff` is what it is made of (materials.gd) and `what` is what it is called: everything
## that goes into the level can be broken (solid.gd, breakable.gd).
func _box(pos: Vector3, size: Vector3, col: Color, stuff := "brick", what := "wall", parts := {}) -> StaticBody3D:
	return Solid.box(self, pos, size, col, stuff, what, parts)


## Raiders' camp, in the south-west corner of the yard: three raiders on watch among things to hide behind.
## A fire or a lamp: it lights the ground round it at night (who stands in it can be seen), with a real light
## for the look of it.
func _lamp(pos: Vector3, radius: float, fire := false) -> void:
	Daylight.add_lamp(pos, radius)
	if fire:
		var cf := Campfire.new()      # a fire you can boil water on
		cf.position = pos
		add_child(cf)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, 1.2, 0.0)
	l.omni_range = radius
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = 1.6
	add_child(l)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.3, 0.5)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.5, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.2)
	mat.emission_energy_multiplier = 2.0
	m.material_override = mat
	m.position = pos + Vector3(0.0, 0.15, 0.0)
	add_child(m)


func _build_raider_camp() -> void:
	_lamp(Vector3(-26, 0, 25), 9.0, true)      # the camp's fire: at night they stand in its light and you don't
	_lamp(Vector3(2, 0, 9), 6.0)         # a lamp by the spawn
	var crate := Color(0.45, 0.36, 0.25)
	var wall_col := Color(0.5, 0.48, 0.44)
	_box(Vector3(-26, 0.55, 20), Vector3(4.0, 1.1, 0.5), wall_col)     # a low wall facing the yard
	_box(Vector3(-19, 0.55, 23), Vector3(0.5, 1.1, 3.5), wall_col)     # and one on the east side
	_box(Vector3(-30, 0.6, 24), Vector3(1.2, 1.2, 1.2), crate, "wood", "crate")
	_box(Vector3(-23, 0.6, 27), Vector3(1.2, 1.2, 1.2), crate, "wood", "crate")
	_box(Vector3(-27, 1.3, 30), Vector3(3.0, 2.6, 0.4), wall_col)      # a standing wall to lean round
	_box(Vector3(-33, 1.0, 29), Vector3(1.0, 2.0, 1.0), wall_col)
	# Cover on the way in, for you.
	_box(Vector3(-17, 0.6, 14), Vector3(1.2, 1.2, 1.2), crate, "wood", "crate")
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
