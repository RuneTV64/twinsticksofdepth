class_name Player
extends CharacterBody3D
## Two stances:
##  WEAPON AWAY (default): face where you walk. Right stick / mouse moves a crosshair and the
##    camera pans to keep it centered; your facing doesn't change. Let go and the camera
##    returns to you and the crosshair hides. Attack button = Interact. Hold Sprint to run.
##  READY (hold LT / right-click / Q): twin-stick. Right stick / mouse sets facing, the camera
##    leads toward the aim point. Attack button attacks. Slower, no running (dash still works).
## Doors work in either stance: walk into them to push them, run or dash into them to barge.

# ---------- Stats (there is no speed stat: speed comes from these three) ----------
@export var strength := 10.0
@export var endurance := 10.0
@export var weight := 8.0
@export var dexterity := 10.0           # aimed-shot damage and headshot chance

# Derived in recompute_stats()
var walk_speed := 4.6
var ready_speed := 3.0
var run_speed := 6.7
var dash_speed := 12.0
var dash_time := 0.18
var max_stamina := 100.0
var stamina_regen := 25.0
var run_drain := 14.0
var dash_cost := 20.0
var barge_min_speed := 5.3

# ---------- Feel tuning ----------
@export var base_walk_speed := 4.6      # walk speed at default stats, before burden/fitness
@export var run_mult := 1.45            # run = walk x this
@export var accel := 26.0               # lower = heavier start-up
@export var decel := 30.0               # lower = longer slide to a stop
@export var turn_speed := 14.0          # rad/s, weapon away
@export var ready_turn_speed := 28.0    # rad/s, Ready on a stick (mouse aim is instant)
@export var backpedal_mult := 0.75      # Ready: speed when moving directly away from aim
@export var draw_time := 0.12         # Ready pressed -> can attack
@export var sprint_tap_time := 0.22     # release Sprint before this = dash, hold past it = run
@export var reticle_range := 10.0       # how far the reticle can roam, in both stances
# Gear adds to the base range per stance. Set these when equipment changes (they can change
# at any time; the reticle is re-clamped every frame).
var look_range_bonus := 0.0             # weapon away: e.g. binoculars
var aim_range_bonus := 0.0              # Ready: e.g. a scoped gun
@export var aim_min_dist := 0.3         # Ready: reticle closer than this doesn't turn you
@export var aim_follow_sharpness := 11.0 # Ready: how tightly the reticle tracks stick tilt
# Stick tilt -> reticle distance curve. 1 = linear (twitchy: small tilts move it meters),
# 2 = squared (fine control near you, full range still at full tilt). Higher = gentler.
@export var stick_aim_curve := 2.0
@export var ready_cam_lead := 0.45     # Ready: how far the camera leans toward the reticle
@export var look_follow_sharpness := 9.0  # weapon away: how tightly the crosshair tracks stick tilt
@export var look_return_sharpness := 6.0  # weapon away: how fast an idle mouse crosshair floats home
@export var mouse_sens := 0.022         # world meters per mouse pixel
@export var mouse_idle_hide := 1.2      # weapon away: idle mouse crosshair starts floating home after this
@export var interact_range := 1.9
@export var max_health := 100.0

# ---------- Fatigue: low stamina slows all movement ----------
@export var fatigue_start := 0.5        # stamina fraction where you start slowing down
@export var fatigue_min_speed := 0.65   # speed multiplier at zero stamina
@export var fatigue_min_accel := 0.6    # accel multiplier at zero stamina (sluggish starts)

# ---------- Weapon (placeholder ranged weapon; tech level is still open) ----------
@export var mag_size := 8
@export var fire_interval := 0.2
@export var reload_time := 1.1
@export var shot_damage := 25.0
@export var shot_speed := 140.0         # m/s; fast enough to read as a gunshot, not a thrown bolt
@export var shot_kick := 2.6            # m/s shoved backward per shot
@export var shot_cam_kick := 0.3        # meters the camera jolts back per shot
@export var shot_noise_range := 30.0    # meters; enemies this close hear a shot and come looking
@export var bash_damage := 12.0

# ---------- Unarmed ----------
# Punches are a last resort: weak, unreliable (damage varies, some whiff), but cheap and quick,
# and they never stop you moving. Weapon away: attack punches (you can do it running).
# Ready: TAP attack to punch, HOLD attack to shove.
@export var punch_damage_min := 2.0
@export var punch_damage_max := 5.0
@export var punch_still_mult := 1.4     # planted feet hit a little harder than a punch on the move
@export var punch_still_speed := 0.6    # m/s; slower than this counts as holding still
@export var punch_miss_chance := 0.2    # chance a punch in range just doesn't connect
@export var punch_range := 1.5          # meters
@export var punch_arc_dot := 0.5        # target must be within this cone of your facing (dot)
@export var punch_knock := 1.5
@export var punch_windup := 0.1         # fresh: seconds from the punch starting to it landing
@export var punch_recover := 0.28       # fresh: seconds after it lands before the next one
@export var punch_cost := 3.0           # stamina per punch
@export var punch_tired_slow := 1.4     # at zero stamina, punches take this many times longer
@export var punch_tired_damage := 0.5   # at zero stamina, punch damage is multiplied by this
@export var melee_look_range := 2.5     # Ready unarmed: how far the (hidden) look point roams
# Shove (Ready, HOLD attack): throws back everything in reach in front of you. No damage; it
# buys space. Repeats while held.
@export var shove_hold_time := 0.2      # Ready: attack held this long is a shove, released sooner is a punch
@export var shove_interval := 0.7       # seconds between shoves while held
@export var shove_range := 1.7          # meters
@export var shove_arc_dot := 0.4        # shoves enemies within this cone of your facing (dot)
@export var shove_force := 9.0          # m/s the enemy is thrown back (about 2 m of travel)
@export var shove_cost := 12.0          # stamina when a shove connects
@export var shove_whiff_cost := 3.0     # stamina when it pushes at nothing
# Guard: Ready unarmed and facing an attacker stops its hit and costs stamina instead. Against
# a zombie that is a last-moment shove before the bite. (Proper blocking is for fighting people.)
@export var block_arc_dot := 0.5        # attacker must be within this cone of your facing (dot)
@export var block_stamina_per_damage := 2.5   # stamina spent per point of damage stopped
@export var block_regen_delay := 1.0    # seconds after a shove before stamina regenerates
@export var cam_stance_sharpness := 3.0 # how gently the camera settles after Ready / lower / weapon swap

## Weapons on the quick wheel, in slot order (slot 0 is at the left, going clockwise).
const WEAPONS: Array[String] = ["fists", "gun"]
const WEAPON_NAMES := {"fists": "Unarmed", "gun": "Gun"}
const WHEEL_MOUSE_RADIUS := 90.0        # pixels of mouse travel from center to the wheel's rim

# ---------- Aimed shots (reticle red on the enemy you hit) ----------
@export var aim_bonus_per_dex := 0.03          # +3% aimed damage per point of DEX
@export var aim_bonus_per_firepower := 0.008   # +0.8% aimed damage per point of weapon damage
@export var headshot_per_dex := 0.008          # +0.8% headshot chance per point of DEX
@export var headshot_per_firepower := 0.002    # +0.2% headshot chance per point of weapon damage
@export var headshot_max_chance := 0.6

var health := 100.0
var stamina := 100.0
var winded := false
var running := false
var armed := false
var using_pad := false
var dead := false
var mag := 8
var reserve := 16
var facing := Vector3(0, 0, -1)
var weapon := "fists"              # what's in hand: one of WEAPONS
var shoving := false               # Ready unarmed with attack held past shove_hold_time
var _atk_hold := 0.0               # how long attack has been held, 0 when it isn't
var _cam_carry := Vector3.ZERO     # camera offset left over from a stance change, eased to zero
var wheel_open := false            # quick weapon wheel is up (Tab / LB held)
var wheel_choice := -1             # slot highlighted on the wheel, -1 = none yet
var _wheel_vec := Vector2.ZERO     # mouse travel since the wheel opened
var _swing_t := 0.0                # > 0 while a punch is under way (windup + recovery left)
var _swing_total := 0.0            # full length of the current punch
var _swing_windup := 0.0           # windup part of the current punch
var _swing_power := 1.0            # damage multiplier from fatigue, fixed when the punch started
var _swing_landed := true          # the current punch has already been resolved
var _block_t := 0.0                # > 0 just after a shove (visual only)

var camera_rig: CamRig
var spawn_point := Vector3.ZERO
var reticle_offset := Vector3.ZERO
var reticle_visible := false
var reticle_on_enemy := false
var reticle_target: Enemy = null   # the enemy under the reticle (Ready only counts as "aimed")
var aimed_mult := 1.5              # derived: damage multiplier for a shot aimed at its target
var headshot_chance := 0.13        # derived: chance an aimed hit is a one-shot kill
var interact_target: Node = null
var status_text := ""
var shots_fired := 0
var last_shot := "-"
var status_t := 0.0

var _draw_t := 0.0
var _fire_cd := 0.0
var _reload_t := 0.0
var _regen_delay := 0.0
var _sprint_t := -1.0
var _dash_t := 0.0
var _dash_dir := Vector3.ZERO
var _stagger := 0.0
var _barge_cd := 0.0
var _bash_cd := 0.0
var _mouse_idle := 99.0
var _hurt_t := 0.0
var _heal_delay := 0.0
var _respawn_t := 0.0
var _locked_msg_cd := 0.0
var _flash_t := 0.0
var _lmb_edge := false   # a left-click arrived since the last physics tick
var _rmb_event := false  # right button state as last reported by a mouse event
var _lmb_event := false
var _has_mouse := DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE)

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _weapon: MeshInstance3D
var _weapon_mesh: BoxMesh
var _weapon_mat: StandardMaterial3D
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.25, 0.45, 0.85)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	body.mesh = cm
	body.material_override = _body_mat
	body.position.y = 0.9
	_visual.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.28, 0.14, 0.3)
	nose.mesh = nm
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.1, 0.12, 0.2)
	nose.material_override = nose_mat
	nose.position = Vector3(0, 1.5, -0.38)
	_visual.add_child(nose)

	_weapon = MeshInstance3D.new()
	_weapon_mesh = BoxMesh.new()
	_weapon.mesh = _weapon_mesh
	_weapon_mat = StandardMaterial3D.new()
	_weapon_mat.emission_enabled = true
	_weapon_mat.emission = Color(1.0, 0.8, 0.3)
	_weapon_mat.emission_energy_multiplier = 0.0
	_weapon.material_override = _weapon_mat
	_visual.add_child(_weapon)
	_apply_weapon_look()

	_reticle = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.42
	tm.rings = 24
	tm.ring_segments = 6
	_reticle.mesh = tm
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.no_depth_test = true
	_reticle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticle_mat.render_priority = 10
	_reticle.material_override = _reticle_mat
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.top_level = true
	add_child(_reticle)

	recompute_stats()
	_reset_vitals()


## Defaults (STR 10 / END 10 / WT 8) give walk 4.6, run 6.7, 100 stamina.
##  - burden = weight / strength. Carrying more than your frame handles slows you.
##  - endurance = stamina pool, regen, and a small bump to top speed.
##  - weight makes runs and dashes cost more, and dashes shorter.
func recompute_stats() -> void:
	strength = maxf(strength, 1.0)
	endurance = maxf(endurance, 1.0)
	weight = maxf(weight, 1.0)
	var burden := weight / strength
	var mobility := clampf(1.0 - 0.4 * (burden - 0.8), 0.55, 1.25)
	var fitness := 1.0 + 0.02 * (endurance - 10.0)
	walk_speed = base_walk_speed * mobility * fitness
	ready_speed = walk_speed * 0.65
	run_speed = walk_speed * (run_mult + 0.01 * (endurance - 10.0))
	max_stamina = 60.0 + endurance * 4.0
	stamina_regen = 10.0 + endurance * 1.5
	run_drain = 14.0 * (0.6 + 0.5 * burden)
	dash_cost = 20.0 * (0.7 + 0.4 * burden)
	dash_speed = run_speed * 1.8
	dash_time = 0.18 * clampf(1.15 - 0.2 * burden, 0.6, 1.1)
	barge_min_speed = walk_speed * 1.15
	# Aimed shots: dexterity and the weapon's firepower both raise the bonus and the headshot odds.
	# Defaults (DEX 10, 25 damage) give x1.5 damage and a 13% headshot chance.
	dexterity = maxf(dexterity, 1.0)
	aimed_mult = 1.0 + dexterity * aim_bonus_per_dex + shot_damage * aim_bonus_per_firepower
	headshot_chance = clampf(dexterity * headshot_per_dex + shot_damage * headshot_per_firepower,
		0.0, headshot_max_chance)
	stamina = minf(stamina, max_stamina)


## Strength + weight behind the hit, scaled by how fast you were going (dash hits hardest).
func barge_power(speed: float) -> float:
	return (strength + weight) * clampf(speed / run_speed, 0.0, 1.6)


## 0 = fresh, 1 = completely spent. Starts climbing once stamina drops below fatigue_start.
func fatigue() -> float:
	if max_stamina <= 0.0 or fatigue_start <= 0.0:
		return 0.0
	return 1.0 - clampf((stamina / max_stamina) / fatigue_start, 0.0, 1.0)


func camera_focus() -> Vector3:
	var f := global_position
	if dead:
		return f
	return f + _cam_offset() + _cam_carry


## Where the current stance wants the camera, relative to you.
func _cam_offset() -> Vector3:
	if armed:
		return reticle_offset * ready_cam_lead
	if reticle_visible:
		return reticle_offset
	return Vector3.ZERO


func show_status(text: String, dur := 1.6) -> void:
	status_text = text
	status_t = dur


func add_ammo(n: int) -> void:
	reserve += n
	show_status("+%d ammo" % n)


# ---------------------------------------------------------------- weapons + quick wheel
func is_melee() -> bool:
	return weapon == "fists"


## True while your guard is up: Ready unarmed with stamina left to spend.
## A drained guard stays down until you've caught your breath (winded clears).
func is_guarding() -> bool:
	return armed and is_melee() and not dead and not winded and stamina > 0.0


func equip(w: String) -> void:
	if w == weapon or not WEAPONS.has(w):
		return
	var cam_before := _cam_offset()
	weapon = w
	_reload_t = 0.0
	_swing_t = 0.0
	_draw_t = draw_time
	_fire_cd = maxf(_fire_cd, draw_time)
	_apply_weapon_look()
	_settle_camera(cam_before)
	show_status(WEAPON_NAMES[w], 0.9)


## Call after anything that makes the camera's resting spot jump (Ready, lower, weapon swap):
## the camera keeps its place and eases over to the new spot instead of lurching.
func _settle_camera(cam_before: Vector3) -> void:
	reticle_offset = reticle_offset.limit_length(current_reticle_range())
	_cam_carry += cam_before - _cam_offset()


func _apply_weapon_look() -> void:
	if is_melee():
		# A fist.
		_weapon_mesh.size = Vector3(0.18, 0.18, 0.18)
		_weapon_mat.albedo_color = Color(0.85, 0.68, 0.55)
	else:
		_weapon_mesh.size = Vector3(0.12, 0.12, 0.85)
		_weapon_mat.albedo_color = Color(0.35, 0.3, 0.25)


## Screen-space angle of a wheel slot (0 = right, PI = left; y is down). Shared with the HUD.
static func wheel_angle(slot: int) -> float:
	return PI + slot * TAU / WEAPONS.size()


## Hold Tab / LB: the wheel opens. Point with the mouse or right stick to highlight a weapon,
## release to equip it. Releasing without pointing keeps what you have.
func _update_wheel() -> void:
	var held := Input.is_action_pressed("weapon_wheel")
	if held and not wheel_open:
		wheel_open = true
		wheel_choice = -1
		_wheel_vec = Vector2.ZERO
	if not wheel_open:
		return
	var v := _wheel_vec / WHEEL_MOUSE_RADIUS
	if using_pad:
		v = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.2)
	if v.length() > 0.45:
		var dir := v.normalized()
		var best := -2.0
		for i in WEAPONS.size():
			var a := wheel_angle(i)
			var d := dir.dot(Vector2(cos(a), sin(a)))
			if d > best:
				best = d
				wheel_choice = i
	if not held:
		wheel_open = false
		if wheel_choice >= 0:
			equip(WEAPONS[wheel_choice])


# ======================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		# Every mouse event (motion too) carries which buttons are held. Some systems drop the
		# second click while one button is already held, so track the mask ourselves.
		var mask: int = event.button_mask
		var l := (mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if l and not _lmb_event:
			_lmb_edge = true
		_lmb_event = l
		_rmb_event = (mask & MOUSE_BUTTON_MASK_RIGHT) != 0
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _lmb_event:
				_lmb_edge = true
			_lmb_event = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_event = event.pressed
	if event is InputEventMouseMotion:
		using_pad = false
		if wheel_open:
			# The mouse points at the wheel instead of moving the crosshair.
			_wheel_vec = (_wheel_vec + event.relative).limit_length(WHEEL_MOUSE_RADIUS)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dead:
			var rel: Vector2 = event.relative
			reticle_offset += Vector3(rel.x, 0.0, rel.y) * mouse_sens
			reticle_offset = reticle_offset.limit_length(current_reticle_range())
			_mouse_idle = 0.0
	elif event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if dead:
		_respawn_t -= delta
		velocity = Vector3.ZERO
		wheel_open = false
		if _respawn_t <= 0.0:
			_respawn()
		_update_visuals(delta)
		return

	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(mv.x, 0.0, mv.y)
	if _stagger > 0.0:
		move_dir = Vector3.ZERO

	_update_wheel()
	_update_stance()
	_update_aim(delta)
	_update_sprint(delta, move_dir)

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if _dash_t > 0.0:
		horiz = _dash_dir * dash_speed
	elif _stagger > 0.0:
		horiz = horiz.move_toward(Vector3.ZERO, decel * 0.4 * delta)
	else:
		var spd := walk_speed
		if armed:
			var back := (move_dir.normalized().dot(facing) + 1.0) * 0.5   # 0 = straight back
			spd = ready_speed * lerpf(backpedal_mult, 1.0, back)
		elif running:
			spd = run_speed
		var tired := fatigue()
		spd *= lerpf(1.0, fatigue_min_speed, tired)
		var want := move_dir * spd
		var rate := decel
		if want.length() > 0.01:
			rate = accel * lerpf(1.0, fatigue_min_accel, tired)
		horiz = horiz.move_toward(want, rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 25.0 * delta

	var pre_vel := horiz
	move_and_slide()
	_handle_collisions(pre_vel)

	_update_facing(delta, move_dir)
	_update_line_of_fire()
	_update_combat()
	_update_interact()
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_draw_t -= delta
	_fire_cd -= delta
	_dash_t -= delta
	_stagger -= delta
	_barge_cd -= delta
	_bash_cd -= delta
	_swing_t -= delta
	_block_t -= delta
	_cam_carry = _cam_carry.lerp(Vector3.ZERO, 1.0 - exp(-cam_stance_sharpness * delta))
	_hurt_t -= delta
	_flash_t -= delta
	_locked_msg_cd -= delta
	_mouse_idle += delta
	status_t -= delta
	_heal_delay -= delta
	if not dead and _heal_delay <= 0.0 and health < max_health:
		health = minf(health + 4.0 * delta, max_health)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var n := mini(mag_size - mag, reserve)
			mag += n
			reserve -= n


# ---------------------------------------------------------------- stance + aim
func _update_stance() -> void:
	var want_ready := ready_held()
	# If you're actively aiming during a stance change (right stick tilted, or the mouse moved
	# recently enough that the crosshair is still showing), the reticle carries over instead of
	# resetting, so you can ready (or lower) mid-aim without losing your place.
	var aim_active := _mouse_idle < mouse_idle_hide
	if using_pad:
		aim_active = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.2).length() > 0.05
	var cam_before := _cam_offset()
	if want_ready and not armed:
		armed = true
		running = false
		_draw_t = draw_time
		# Otherwise the reticle starts on you and is moved out from there. Facing holds until
		# it has been pushed far enough to give a direction (see aim_min_dist).
		if not aim_active:
			reticle_offset = Vector3.ZERO
		_settle_camera(cam_before)
	elif not want_ready and armed:
		armed = false
		_reload_t = 0.0   # putting it away cancels a reload
		if not aim_active:
			_mouse_idle = 99.0   # not aiming: let the reticle float home (no snap)
		_settle_camera(cam_before)


func _update_aim(delta: float) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.2)
	if stick.length() > 0.3:
		using_pad = true
	if wheel_open:
		stick = Vector2.ZERO   # the stick is pointing at the wheel, not aiming

	if armed:
		if using_pad:
			# Same rule as weapon away: tilt = distance, so easing off the stick floats the
			# reticle back toward you. Tracks tighter than the look crosshair to stay snappy.
			var target := _stick_reticle_target(stick)
			reticle_offset = reticle_offset.lerp(target, 1.0 - exp(-aim_follow_sharpness * delta))
		reticle_offset = reticle_offset.limit_length(current_reticle_range())
		reticle_visible = true
	else:
		var returning := false
		if using_pad:
			# The crosshair tracks the stick: tilt = distance, so easing off the stick floats
			# it back toward you and letting go floats it all the way home. No snapping.
			var target := _stick_reticle_target(stick)
			reticle_offset = reticle_offset.lerp(target, 1.0 - exp(-look_follow_sharpness * delta))
			returning = stick.length() <= 0.05
		else:
			# Mouse: it stays where you put it, then floats home once the mouse has been idle.
			returning = _mouse_idle >= mouse_idle_hide
			if returning:
				reticle_offset = reticle_offset.lerp(Vector3.ZERO, 1.0 - exp(-look_return_sharpness * delta))
		reticle_offset = reticle_offset.limit_length(current_reticle_range())
		# Hidden only once it has actually arrived back on you.
		if returning and reticle_offset.length() < 0.2:
			reticle_offset = Vector3.ZERO
			reticle_visible = false
		else:
			reticle_visible = true



## Where the stick is asking the reticle to be: direction straight from the stick, distance
## from the tilt run through stick_aim_curve so the first part of the throw is fine-grained.
func _stick_reticle_target(stick: Vector2) -> Vector3:
	var tilt := minf(stick.length(), 1.0)
	if tilt <= 0.0:
		return Vector3.ZERO
	var dir := stick / stick.length()
	# Melee Ready has no reticle to place, only a direction to face: keep it linear so a light
	# tilt already turns you.
	var curve := 1.0 if armed and is_melee() else stick_aim_curve
	return Vector3(dir.x, 0.0, dir.y) * pow(tilt, curve) * current_reticle_range()


## Max reticle distance right now: the shared base plus whatever the current stance's gear adds.
## Ready with a melee weapon keeps the (hidden) look point close, so turning stays quick.
func current_reticle_range() -> float:
	if armed and is_melee():
		return melee_look_range
	return maxf(reticle_range + (aim_range_bonus if armed else look_range_bonus), 0.5)


func muzzle_position() -> Vector3:
	return global_position + Vector3(0.0, 1.1, 0.0) + facing * 0.3


## The reticle is red only when a shot fired right now would really hit an enemy. This traces
## the same path the projectile takes (from the muzzle, along your current facing, same hit
## radius and wall check), so a wall, a shut door, a body in the way, or a facing that hasn't
## turned onto the target yet all keep it white.
func _update_line_of_fire() -> void:
	reticle_on_enemy = false
	reticle_target = null
	if not armed or dead or is_melee():
		return
	var from := muzzle_position()
	var to := from + facing * Projectile.MAX_DIST
	var best_t := 2.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var t := Projectile.segment_hit(from, to, en.global_position, Projectile.HIT_RADIUS)
		if t >= 0.0 and t < best_t:
			best_t = t
			reticle_target = en
	if reticle_target == null:
		return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		if from.distance_to(hp) / Projectile.MAX_DIST < best_t:
			reticle_target = null   # something solid is in the way
			return
	reticle_on_enemy = true


func _update_facing(delta: float, move_dir: Vector3) -> void:
	var want := Vector3.ZERO
	var rate := turn_speed
	if armed:
		want = reticle_offset
		rate = ready_turn_speed
	elif _dash_t > 0.0:
		want = _dash_dir
	elif move_dir.length() > 0.1:
		want = move_dir
	# In Ready, a reticle sitting on (or very near) you gives no direction: keep facing as is.
	if want.length() < (aim_min_dist if armed else 0.01):
		return
	want = want.normalized()
	if armed and not using_pad:
		facing = want
	else:
		facing = _turn_toward(facing, want, rate * delta)


func _turn_toward(from: Vector3, to: Vector3, step: float) -> Vector3:
	var a := atan2(from.x, from.z)
	var b := atan2(to.x, to.z)
	a += clampf(wrapf(b - a, -PI, PI), -step, step)
	return Vector3(sin(a), 0.0, cos(a))


# ---------------------------------------------------------------- stamina, run, dash
func _update_sprint(delta: float, move_dir: Vector3) -> void:
	if Input.is_action_just_pressed("sprint"):
		_sprint_t = 0.0
	if _sprint_t >= 0.0:
		if Input.is_action_pressed("sprint"):
			_sprint_t += delta
		else:
			if _sprint_t <= sprint_tap_time:
				_try_dash(move_dir)
			_sprint_t = -1.0

	var want_run := _sprint_t > sprint_tap_time and not armed and move_dir.length() > 0.1 \
		and not winded and _stagger <= 0.0
	running = want_run and stamina > 0.0
	if running:
		stamina = maxf(stamina - run_drain * delta, 0.0)
		_regen_delay = 0.8
		if stamina <= 0.0:
			winded = true
			running = false
			show_status("Winded!", 1.2)
	else:
		_regen_delay -= delta
		if _regen_delay <= 0.0 and _dash_t <= 0.0:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
	if winded and stamina >= max_stamina * 0.35:
		winded = false


func _try_dash(move_dir: Vector3) -> void:
	if winded or _dash_t > 0.0 or _stagger > 0.0 or stamina < dash_cost * 0.5:
		if winded:
			show_status("Too winded to dash", 0.8)
		return
	_dash_dir = move_dir if move_dir.length() > 0.1 else facing
	_dash_dir = _dash_dir.normalized()
	_dash_t = dash_time
	stamina = maxf(stamina - dash_cost, 0.0)
	_regen_delay = 0.8
	if stamina <= 0.0:
		winded = true


# ---------------------------------------------------------------- doors / barging
func _handle_collisions(pre_vel: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col == null or not col.has_meta("door"):
			continue
		var door: Door = col.get_meta("door")
		var n := c.get_normal()
		var into := -Vector3(n.x, 0.0, n.z)
		if into.length() < 0.01:
			continue
		into = into.normalized()
		var spd := pre_vel.dot(into)
		if spd >= barge_min_speed and _barge_cd <= 0.0 and door.is_shut():
			_barge(door, spd, into)
			return
		if spd > 0.4:
			if not door.push(global_position, into, spd) and _locked_msg_cd <= 0.0:
				show_status("Won't budge. Run or dash into it to barge it open.", 2.0)
				_locked_msg_cd = 2.5


func _barge(door: Door, spd: float, into: Vector3) -> void:
	_barge_cd = 0.6
	_dash_t = 0.0
	var power := barge_power(spd)
	var need := door.resistance()
	if door.barge(power, global_position, into):
		var hurt := 3.0 + need * 0.2
		take_damage(hurt, Vector3.ZERO, 0.0)
		velocity = into * spd * 0.55     # keep some momentum through the doorway
		_stagger = 0.12
		show_status("BAM! Barged through  (power %d vs %d, -%d HP)" % [roundi(power), roundi(need), roundi(hurt)], 2.0)
	else:
		var hurt := 5.0 + need * 0.35
		take_damage(hurt, -into, 5.0)
		_stagger = 0.45
		show_status("Oof. It held  (power %d vs %d, -%d HP)" % [roundi(power), roundi(need), roundi(hurt)], 2.2)


# ---------------------------------------------------------------- combat + interact
## Ready = right mouse button (read three ways), LT, or Q.
func ready_held() -> bool:
	if Input.is_action_pressed("ready_weapon"):
		return true
	return _rmb_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or (_has_mouse and (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_RIGHT) != 0)


## Attack / Interact = left mouse button (read three ways), RT, or A.
func attack_held() -> bool:
	if Input.is_action_pressed("attack"):
		return true
	return _lmb_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or (_has_mouse and (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) != 0)


var _attack_was_held := false
var attack_tapped := false


func _update_combat() -> void:
	var held := attack_held()
	attack_tapped = Input.is_action_just_pressed("attack") or _lmb_edge or (held and not _attack_was_held)
	_attack_was_held = held
	_lmb_edge = false
	# Tap vs hold: a tap is attack let go before shove_hold_time.
	var tap_released := not held and _atk_hold > 0.0 and _atk_hold < shove_hold_time
	_atk_hold = _atk_hold + get_physics_process_delta_time() if held else 0.0
	shoving = false
	# A punch already under way lands when its windup runs out, whatever else is going on.
	if _swing_t > 0.0 and not _swing_landed and _swing_total - _swing_t >= _swing_windup:
		_land_punch()
	if wheel_open:
		return
	if Input.is_action_just_pressed("reload") and not is_melee():
		_start_reload()
	if armed:
		if _draw_t > 0.0 or _stagger > 0.0 or _reload_t > 0.0:
			return
		if is_melee():
			# Ready unarmed: tap = punch, hold = shove (repeats while held).
			if tap_released:
				if _fire_cd <= 0.0:
					_punch()
			elif held and _atk_hold >= shove_hold_time:
				shoving = true
				if _fire_cd <= 0.0:
					_shove()
		elif attack_held() and _fire_cd <= 0.0:
			if mag > 0:
				_fire()
			elif reserve > 0:
				_start_reload()
			elif attack_tapped:
				_bash()
	elif interact_target != null:
		if attack_tapped:
			interact_target.call("interact", self)
	elif is_melee() and held and _fire_cd <= 0.0 and _stagger <= 0.0:
		_punch()   # fists need no readying: punch with the weapon away, even on the run


func _start_reload() -> void:
	if _reload_t > 0.0 or mag >= mag_size:
		return
	if reserve <= 0:
		show_status("No ammo. Find some, or bash (attack with an empty weapon).", 1.8)
		return
	_reload_t = reload_time
	show_status("Reloading...", reload_time)


func _fire() -> void:
	mag -= 1
	_fire_cd = fire_interval
	_flash_t = 0.06
	var shot := Projectile.new()
	shot.dir = facing
	shot.speed = shot_speed
	shot.damage = shot_damage
	shot.exclude = [get_rid()]
	shot.shooter = self
	# Fired with the reticle on an enemy: the shot is "aimed" at that enemy.
	if reticle_target != null:
		shot.aimed_at = reticle_target
		shot.aimed_mult = aimed_mult
		shot.headshot_chance = headshot_chance
	shots_fired += 1
	print("[fire] #%d dir %s mag %d" % [shots_fired, facing, mag])
	shot.position = muzzle_position()
	get_parent().add_child(shot)
	# The shot is loud: every enemy within earshot comes to where it was fired.
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en != null and en.global_position.distance_to(global_position) <= shot_noise_range:
			en.hear_noise(global_position)
	velocity -= facing * shot_kick
	if camera_rig:
		camera_rig.kick(-facing * shot_cam_kick)
	if mag == 0 and reserve > 0:
		_start_reload()


## Throw a punch. It doesn't stop you moving. The less stamina you have, the slower and
## weaker it is.
func _punch() -> void:
	var tired := 1.0 - clampf(stamina / max_stamina, 0.0, 1.0)
	var slow := lerpf(1.0, punch_tired_slow, tired)
	_swing_power = lerpf(1.0, punch_tired_damage, tired)
	_swing_windup = punch_windup * slow
	_swing_total = (punch_windup + punch_recover) * slow
	_swing_t = _swing_total
	_swing_landed = false
	_fire_cd = _swing_total
	stamina = maxf(stamina - punch_cost, 0.0)
	_regen_delay = maxf(_regen_delay, _swing_total + 0.2)
	if stamina <= 0.0 and not winded:
		winded = true
		show_status("Exhausted!", 1.2)


## The punch arrives: it goes for the nearest enemy in reach in front of you, and may not
## connect. Damage is a roll, a bit higher if your feet were planted.
func _land_punch() -> void:
	_swing_landed = true
	var target: Enemy = null
	var best := punch_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < best and to.normalized().dot(facing) > punch_arc_dot:
			best = to.length()
			target = en
	if target == null or randf() < punch_miss_chance:
		return
	var dmg := randf_range(punch_damage_min, punch_damage_max) * _swing_power
	if Vector2(velocity.x, velocity.z).length() < punch_still_speed:
		dmg *= punch_still_mult
	target.take_hit(dmg, facing, punch_knock)


## Shove everything in reach in front of you straight back. No damage. Needs your guard:
## once you're spent you can't shove until you've caught your breath.
func _shove() -> void:
	_fire_cd = shove_interval
	if not is_guarding():
		show_status("Too spent to shove", 0.8)
		return
	_block_t = 0.25
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < shove_range and to.normalized().dot(facing) > shove_arc_dot:
			en.shove(to.normalized(), shove_force)
			hit = true
	_spend_guard(shove_cost if hit else shove_whiff_cost)


## Stamina spent holding something off. Running dry breaks your guard.
func _spend_guard(cost: float) -> void:
	stamina = maxf(stamina - cost, 0.0)
	_regen_delay = block_regen_delay
	if stamina <= 0.0:
		winded = true
		show_status("Too spent to hold them off!", 1.4)


func _bash() -> void:
	if _bash_cd > 0.0:
		return
	_bash_cd = 0.5
	_fire_cd = 0.5
	show_status("Out of ammo - bash!", 0.8)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < 1.8 and to.normalized().dot(facing) > 0.4:
			en.take_hit(bash_damage, facing, 7.0)


func _update_interact() -> void:
	interact_target = null
	var best := interact_range
	for n in get_tree().get_nodes_in_group("interactables"):
		if not n.call("can_interact", self):
			continue
		var p: Vector3 = n.call("interact_point")
		var d := p - global_position
		d.y = 0.0
		if d.length() < best:
			best = d.length()
			interact_target = n


func interact_prompt() -> String:
	if interact_target == null:
		return ""
	var txt: String = interact_target.call("prompt_text", self)
	if armed:
		return "%s  (lower your weapon)" % txt
	return "[%s]  %s" % ["RT" if using_pad else "Left-click", txt]


# ---------------------------------------------------------------- health
## An enemy's melee attack; dir points from the attacker to you. With your guard up and the
## attacker in front of you, you shove it off before the bite lands: no damage, the attacker
## is thrown clear, and it costs you stamina (more than a shove you chose to throw). The one
## that empties your stamina is your last; after that bites land in full until you recover.
## (Placeholder: a spent guard should let enemies overtake you once that exists.)
func take_attack(amount: float, dir: Vector3, knock: float, attacker: Enemy = null) -> void:
	if dead:
		return
	if is_guarding() and facing.dot(-dir) >= block_arc_dot:
		_block_t = 0.25
		velocity += dir * knock * 0.3
		if attacker != null:
			attacker.shove(-dir, shove_force)
		show_status("Shoved it off", 0.5)
		_spend_guard(amount * block_stamina_per_damage)
		return
	take_damage(amount, dir, knock)
	if not dead:
		show_status("Hit! -%d HP" % roundi(amount), 0.8)


func take_damage(amount: float, dir: Vector3, knock: float) -> void:
	if dead:
		return
	health -= amount
	_hurt_t = 0.15
	_heal_delay = 5.0
	if knock > 0.0:
		velocity += dir * knock
		_stagger = maxf(_stagger, 0.15)
	if health <= 0.0:
		health = 0.0
		dead = true
		armed = false
		_respawn_t = 2.5
		show_status("You went down. Respawning...", 2.5)


func _respawn() -> void:
	dead = false
	global_position = spawn_point
	velocity = Vector3.ZERO
	_cam_carry = Vector3.ZERO
	_reset_vitals()
	if camera_rig:
		camera_rig.snap()


func _reset_vitals() -> void:
	health = max_health
	stamina = max_stamina
	winded = false
	mag = mag_size
	reserve = 16
	_reload_t = 0.0


# ---------------------------------------------------------------- visuals
func _update_visuals(_delta: float) -> void:
	_visual.visible = not dead
	_visual.rotation.y = atan2(-facing.x, -facing.z)
	_weapon.visible = true
	if is_melee():
		# A fist: up in front of you when Ready, out of sight otherwise unless it's punching.
		_weapon.visible = armed or _swing_t > 0.0
		_weapon.rotation = Vector3.ZERO
		var reach := 0.5
		var side := 0.22
		if _swing_t > 0.0:
			# Pull back a touch, snap out as it lands, come back during recovery.
			var elapsed := _swing_total - _swing_t
			if elapsed < _swing_windup:
				reach = lerpf(0.5, 0.38, elapsed / _swing_windup)
			else:
				reach = lerpf(1.05, 0.5, clampf((elapsed - _swing_windup) / (_swing_total - _swing_windup), 0.0, 1.0))
		elif _block_t > 0.0:
			# Shove: straight out from the chest.
			reach = 0.95
			side = 0.0
		_weapon.position = Vector3(side, 1.2, -reach)
	elif armed:
		_weapon.position = Vector3(0.28, 1.1, -0.55)
		_weapon.rotation = Vector3.ZERO
	else:
		_weapon.position = Vector3(0.0, 1.25, 0.45)
		_weapon.rotation = Vector3(deg_to_rad(65.0), 0.0, deg_to_rad(20.0))
	_weapon_mat.emission_energy_multiplier = 4.0 if _flash_t > 0.0 or _block_t > 0.0 else 0.0

	var base := Color(0.25, 0.45, 0.85)
	if _hurt_t > 0.0:
		base = Color(1.0, 0.35, 0.3)
	elif _dash_t > 0.0:
		base = Color(0.6, 0.85, 1.0)
	_body_mat.albedo_color = base

	# Ready with a melee weapon: no reticle. You still turn toward where you're pointing.
	_reticle.visible = reticle_visible and not dead and not (armed and is_melee())
	_reticle.global_position = global_position + reticle_offset + Vector3(0.0, 0.08, 0.0)
	if not armed:
		# Weapon away: just a look cursor, so keep it a quiet gray (no enemy highlight).
		_reticle_mat.albedo_color = Color(0.62, 0.64, 0.66, 0.55)
	elif reticle_on_enemy:
		_reticle_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.95)
	else:
		_reticle_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
