class_name Player
extends CharacterBody3D
## Two stances:
##  WEAPON AWAY (default): face where you walk. Right stick / mouse moves a crosshair and the
##    camera pans to keep it centered; your facing doesn't change. Let go and the camera
##    returns to you and the crosshair hides. Attack button = Interact. Hold Sprint to run.
##  COVER (B / Space): tap to slide into the nearest cover or to leave it; hold to go to the cover the crosshair
##    marks. Hunkered you are hidden and nearly blind. Push toward low cover (or along, at an end) to peek. Ready
##    pops you out to aim; attack without Ready fires blind. See the Cover section below and cover.gd.
##  READY (hold LT / right-click / Q): twin-stick. Right stick / mouse sets facing, the camera
##    leads toward the aim point. Attack button attacks. Slower, no running (dash still works).
## Doors work in either stance: walk into them to push them, run or dash into them to barge.

# ---------- Stats ----------
# The character sheet (character_sheet.gd) holds the attributes, needs, composure and conditions. There is no
# speed stat: speed comes from strength, endurance and the load carried. recompute_stats() turns the sheet into
# the numbers below; call it after changing an attribute.
var sheet := CharacterSheet.new()
var strength: float:
	get: return sheet.attr("strength")
	set(v): sheet.set_attr("strength", v)
var endurance: float:
	get: return sheet.attr("endurance")
	set(v): sheet.set_attr("endurance", v)
var dexterity: float:                    # aimed-shot damage and headshot chance
	get: return sheet.attr("dexterity")
	set(v): sheet.set_attr("dexterity", v)
@export var weight := 8.0                # the load you carry

# Derived in recompute_stats()
var walk_speed := 2.1
var ready_speed := 1.45
var run_speed := 5.0
var dash_speed := 8.0
var dash_time := 0.3
var max_stamina := 100.0
var stamina_regen := 25.0
var run_drain := 14.0
var dash_cost := 20.0
var barge_min_speed := 5.3

# ---------- Feel tuning ----------
@export var base_walk_speed := 2.1      # walk speed at default stats, before burden/fitness
@export var run_mult := 2.1             # run = walk x this
@export var ready_mult := 0.8           # Ready = walk x this
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
@export_group("Lock-on")
# Sticky aim: a crosshair brought near an enemy you can see is drawn onto it and follows it.
# The pull fades out with distance, so pushing the stick (or moving the mouse) takes it off again.
@export var lock_on := true
@export var lock_on_radius := 1.6       # m: the pull starts when the crosshair comes this close to an enemy
@export var lock_on_core := 0.5         # m: inside this the crosshair sits dead centre on the enemy
@export var lock_on_strength := 1.0     # 0..1: how far toward the enemy it is drawn (1 = centres)
@export var lock_on_sharpness := 8.0    # how quickly the pull takes hold and lets go (lower = softer)
@export var lock_on_hold := 0.75        # < 1: the enemy already locked wins ties with its neighbours
@export var lock_on_mouse := true       # mouse: the crosshair settles onto a nearby enemy once the mouse rests
@export var lock_on_mouse_radius := 1.0 # m: the mouse's pull radius (a mouse is precise; keep it small)
@export var lock_on_mouse_settle := 0.1 # s the mouse must be still before the pull acts
@export_group("Cover")
# In cover you are in one of three states (cover_mode). To see is to be seen:
#   hunker  hidden behind it. Shots that cross the cover are stopped. You see only a short way.
#   peek    head up over low cover, or round an end. You see as normal; enemies see you; a shot that crosses
#           the cover has a small chance to hit, and when it does it is a head hit.
#   pop     Ready held: up over low cover, or leaning out round an end, to aim. Hit as normal.
@export var cover_reach := 2.5          # m: tap Cover within this of cover to slide in
@export var cover_run_reach := 4.0      # m: the same from a run or a dash
@export var cover_slide_speed := 7.0    # m/s sliding in
@export var cover_move_speed := 1.9     # m/s along cover, hunkered
@export var cover_leave_hold := 0.18    # s pushing firmly away from cover before you leave it
@export var cover_peek_hold := 0.4      # s pushing toward low cover (or along, at an end) before you peek
@export var cover_edge_dist := 0.7      # m: this close to an open end, Ready leans round it
@export var cover_peek_out := 0.15      # m your centre goes past the end when peeking round it
@export var cover_pop_out := 0.5        # m past the end when leaning out to aim
@export var cover_lean_speed := 6.0     # m/s leaning out and back
@export var cover_hunker_sight := 4.0   # m: how far you see all round while hunkered
@export var cover_hidden_aggro := 0.35  # zombies you are hidden from notice you at this much of their range
@export var cover_peek_hit_chance := 0.15   # chance a shot crossing your cover hits while you peek
@export var head_hit_fraction := 0.75   # a head hit on you takes this much of full health
@export var blind_fire_spread_deg := 14.0   # blind fire goes this far either side of the crosshair
@export var blind_fire_slow := 1.6      # blind fire's interval is the gun's times this
@export var cover_hold_time := 0.25     # s holding Cover before you go to the marked cover
@export var cover_aim_radius := 1.5     # m: the crosshair marks cover within this of it
@export var vault_time := 0.42          # s to vault low cover
@export var vault_max_depth := 2.2      # m: cover deeper than this can't be vaulted
@export var vault_cost := 6.0           # stamina
@export_group("")
@export var interact_range := 1.9
@export var base_max_health := 100.0    # at Constitution 10
var max_health := 100.0
@export var base_heal_rate := 4.0       # health per second once you've been left alone a while, at Constitution 10
var heal_rate := 4.0
var melee_mult := 1.0                   # punch damage, from Strength
var _sheet_t := 0.0

# ---------- Fatigue: low stamina slows all movement ----------
@export var fatigue_start := 0.5        # stamina fraction where you start slowing down
@export var fatigue_min_speed := 0.65   # speed multiplier at zero stamina
@export var fatigue_min_accel := 0.6    # accel multiplier at zero stamina (sluggish starts)

# ---------- Weapon (placeholder ranged weapon; tech level is still open) ----------
@export var mag_size := 8
@export var fire_interval := 0.2
@export var base_reload_time := 1.1     # at Dexterity 10
var reload_time := 1.1
@export var shot_damage := 25.0
@export var shot_speed := 140.0         # m/s; fast enough to read as a gunshot, not a thrown bolt
@export var shot_kick := 2.6            # m/s shoved backward per shot
@export var shot_cam_kick := 0.3        # meters the camera jolts back per shot
@export var shot_noise_range := 30.0    # meters; enemies this close hear a shot and come looking
@export var bash_damage := 12.0

# ---------- Unarmed ----------
# Punches are a last resort: weak, unreliable (damage varies, some whiff), but cheap and quick,
# and they never stop you moving. They need Ready, like any attack (weapon away, the attack
# button is Interact only).
@export var punch_damage_min := 2.0
@export var punch_damage_max := 5.0
@export var punch_still_mult := 1.4     # planted feet hit a little harder than a punch on the move
@export var punch_still_speed := 0.6    # m/s; slower than this counts as holding still
@export var punch_miss_chance := 0.2    # chance a punch in range just doesn't connect
@export var punch_range := 1.75         # meters
@export var punch_arc_dot := 0.5        # target must be within this cone of your facing (dot)
@export var punch_knock := 1.5
@export var punch_windup := 0.1         # fresh: seconds from the punch starting to it landing
@export var punch_recover := 0.28       # fresh: seconds after it lands before the next one
@export var punch_cost := 3.0           # stamina per punch
@export var punch_tired_slow := 1.4     # at zero stamina, punches take this many times longer
@export var punch_tired_damage := 0.5   # at zero stamina, punch damage is multiplied by this
@export var melee_look_range := 2.5     # Ready unarmed: how far the (hidden) look point roams
# Shove: automatic. Hold Ready unarmed, and when a zombie comes within reach in front of you,
# you throw it back, along with any zombies right beside it. No damage; it buys space.
@export var shove_interval := 0.75       # seconds before you can shove again
@export var shove_range := 0.1          # meters; a zombie this close in front of you gets shoved
@export var shove_arc_dot := 0.4        # "in front" = within this cone of your facing (dot)
@export var shove_adjacent := 1.4       # meters; zombies this close to a shoved one go with it
@export var base_shove_force := 9.0     # m/s the enemy is thrown back (about 1.5m of travel), at Strength 10
var shove_force := 9.0
@export var shove_cost := 12.0          # stamina per shove
# Guard: Ready unarmed and facing an attacker stops its hit and costs stamina instead. Against
# a zombie that is a last-moment shove before the bite. (Proper blocking is for fighting people.)
@export var block_arc_dot := 0.5        # attacker must be within this cone of your facing (dot)
@export var block_stamina_per_damage := 2.5   # stamina spent per point of damage stopped
@export var block_regen_delay := 1.0    # seconds after a shove before stamina regenerates
# Held: a zombie with hands can grab you. Held, you're slowed (two hands nearly root you) and it bites until
# you get loose: shove it off (guard up, facing it) or struggle (wiggle the move stick / keys; hitting it helps).
@export var held_speed_one := 0.35      # your speed with one hand on you
@export var held_speed_two := 0.08      # with two hands (or two zombies) on you
@export var struggle_per_wiggle := 0.12 # struggle gained per full swing of the move input
@export var struggle_needed := 1.0      # struggle to break a one-handed grip; two hands need 1.8x
@export var struggle_fade := 0.3        # struggle lost per second
@export var break_free_cost := 16.0     # stamina to shove a holder off
# ---------- Vision ----------
# You see a cone in front of you plus a small circle all around; walls cut both short. Enemies
# outside it fade out and the fog of war covers what you can't see (see fog.gd).
@export var sight_fov_deg := 110.0      # full width of the cone
@export var sight_range := 26.0         # meters, how far the cone reaches
@export var base_sight_near := 3.0      # meters, all-round awareness (behind you too), at Wisdom 10
var sight_near := 3.0
@export var sight_eye_height := 1.5     # rays go out at this height, so low cover doesn't block sight
const SIGHT_RAYS := 240                 # one every 1.5 degrees, all the way round

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
var reserve := 8
var facing := Vector3(0, 0, -1)
var weapon := "fists"              # what's in hand: one of WEAPONS
## Distance to the first wall along each of SIGHT_RAYS directions (capped at sight_range).
## Ray i points at angle -PI + i * TAU / SIGHT_RAYS in the XZ plane (0 = +X, PI/2 = +Z).
## Refreshed every physics tick. The cone itself is applied on top: see sight_reach_angle().
var sight_rays := PackedFloat32Array()
var _sight_query: PhysicsRayQueryParameters3D
var _shove_cd := 0.0               # > 0 until you can shove again
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
var lock_target: Enemy = null      # the enemy the crosshair is being drawn onto (lock-on), or null
var _lock_shift := Vector3.ZERO    # stick: how far lock-on is moving the crosshair off where the stick asks
var _aim_raw := Vector3.ZERO       # where the stick or mouse points, before lock-on shifts it (cover marking uses it)
var _aim_raw_on := false

# ---- cover (see the Cover exports)
var in_cover := false
var cover_entering := false        # on the way to a cover spot
var cover_face: Cover.Face = null  # the face you are using, or heading for
var cover_t := 0.0                 # where along it you are settled (m from its a end)
var cover_mode := "hunker"         # hunker, peek or pop
var cover_side := 0                # peek / pop: -1 round the a end, 1 round the b end, 0 over the top
var cover_crouch := 0.0            # 0 standing .. 1 right down: what the body should be doing
var cover_lean_dir := Vector3.ZERO # which way the body leans out (world), 0..1 long
var cover_blind := false           # firing blind right now (the body holds the gun up over or round)
var cover_mark_face: Cover.Face = null   # the cover the crosshair is marking, for hold-Cover
var cover_mark_t := 0.0
var view_range := 26.0             # how far you see now: sight_range and sight_near, or less behind cover
var view_near := 3.0
var _eye_h := 1.5                  # height the sight rays go out at now
var _cover_u := 0.0                # where along the face you actually are (cover_t plus any lean out)
var _cover_btn_t := -1.0           # how long Cover has been held, -1 = not held
var _cover_went := false           # this press already sent you to the marked cover
var _cover_recenter := false       # recentre the crosshair on arriving
var _cover_timeout := 0.0
var _cover_speed := 7.0
var _peek_t := 0.0
var _leave_t := 0.0
var _mark_tick := 0
var _blind_t := 0.0                # > 0 just after a blind shot
var _vault_t := 0.0                # > 0 while vaulting
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _vault_h := 0.0
var _cover_mark: MeshInstance3D
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
var held_by: Array[Enemy] = []   # zombies that have hold of you
var invulnerable := false          # test switch (F7): nothing hurts you
var _struggle := 0.0
var _last_mv := Vector2.ZERO
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
var _body: PlayerBody          # the model, its skin shader and all its animation (player_body.gd)
var _weapon: MeshInstance3D
var _weapon_mesh: BoxMesh
var _weapon_mat: StandardMaterial3D
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
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
	_body = PlayerBody.new()
	_visual.add_child(_body)

	_weapon = MeshInstance3D.new()
	_weapon_mesh = BoxMesh.new()
	_weapon.mesh = _weapon_mesh
	_weapon_mat = StandardMaterial3D.new()
	_weapon_mat.emission_enabled = true
	_weapon_mat.emission = Color(1.0, 0.8, 0.3)
	_weapon_mat.emission_energy_multiplier = 0.0
	_weapon.material_override = _weapon_mat
	_body.attach_weapon(_weapon)   # the body carries it: in hand when Ready, on the back otherwise
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

	# Marks the cover spot the crosshair is pointing out (hold Cover to go there).
	_cover_mark = MeshInstance3D.new()
	var cm := TorusMesh.new()
	cm.inner_radius = 0.34
	cm.outer_radius = 0.4
	cm.rings = 20
	cm.ring_segments = 4
	_cover_mark.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.no_depth_test = true
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.albedo_color = Color(0.45, 0.9, 1.0, 0.85)
	cmat.render_priority = 9
	_cover_mark.material_override = cmat
	_cover_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cover_mark.top_level = true
	_cover_mark.visible = false
	add_child(_cover_mark)
	view_range = sight_range
	view_near = sight_near
	_eye_h = sight_eye_height

	recompute_stats()
	_reset_vitals()


## Defaults (STR 10 / END 10 / WT 8) give walk 3.2, Ready 2.6, run 6.7, 100 stamina.
##  - burden = weight / strength. Carrying more than your frame handles slows you.
##  - endurance = stamina pool, regen, and a small bump to top speed.
##  - weight makes runs and dashes cost more, and dashes shorter.
##  - strength also scales punches and shoves; dexterity, reloading; constitution, health and healing;
##    wisdom, how far you are aware of things all round you. Each is +/- a few percent per point from 10.
func recompute_stats() -> void:
	weight = maxf(weight, 1.0)
	melee_mult = maxf(1.0 + 0.04 * sheet.bonus("strength"), 0.5)
	shove_force = base_shove_force * maxf(1.0 + 0.03 * sheet.bonus("strength"), 0.6)
	reload_time = base_reload_time * clampf(1.0 - 0.02 * sheet.bonus("dexterity"), 0.7, 1.3)
	max_health = base_max_health * maxf(1.0 + 0.03 * sheet.bonus("constitution"), 0.5)
	heal_rate = base_heal_rate * maxf(1.0 + 0.05 * sheet.bonus("constitution"), 0.3)
	sight_near = base_sight_near * maxf(1.0 + 0.04 * sheet.bonus("wisdom"), 0.5)
	health = minf(health, max_health)
	var burden := weight / strength
	var mobility := clampf(1.0 - 0.4 * (burden - 0.8), 0.55, 1.25)
	var fitness := 1.0 + 0.02 * (endurance - 10.0)
	walk_speed = base_walk_speed * mobility * fitness
	ready_speed = walk_speed * ready_mult
	run_speed = walk_speed * (run_mult + 0.01 * (endurance - 10.0))
	max_stamina = 60.0 + endurance * 4.0
	stamina_regen = 10.0 + endurance * 1.5
	run_drain = 14.0 * (0.6 + 0.5 * burden)
	dash_cost = 20.0 * (0.7 + 0.4 * burden)
	dash_speed = run_speed * 1.8
	dash_time = 0.18 * clampf(1.15 - 0.2 * burden, 0.6, 1.1)
	barge_min_speed = run_speed * 0.79   # a walk never barges; a fresh run does, a tired one doesn't
	# Aimed shots: dexterity and the weapon's firepower both raise the bonus and the headshot odds.
	# Defaults (DEX 10, 25 damage) give x1.5 damage and a 13% headshot chance.
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
	# Unarmed uses the body's own fists, so the weapon mesh is only ever the gun.
	_weapon_mesh.size = Vector3(0.09, 0.12, 0.85)
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
	_update_held(delta, mv)

	_update_wheel()
	_update_stance()
	_update_aim(delta)
	_update_cover(delta, move_dir)
	_update_sprint(delta, move_dir)

	if _vault_t > 0.0:
		_vault_step(delta)
		_update_facing(delta, move_dir)
		_update_sight(delta)
		_update_visuals(delta)
		return

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if (in_cover or cover_entering) and _dash_t <= 0.0 and _stagger <= 0.0:
		horiz = _cover_velocity(delta, move_dir)
	elif _dash_t > 0.0:
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
		spd *= held_speed() * sheet.speed_mult
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
	_update_sight(delta)
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
	_shove_cd -= delta
	_swing_t -= delta
	_block_t -= delta
	_blind_t -= delta
	_cam_carry = _cam_carry.lerp(Vector3.ZERO, 1.0 - exp(-cam_stance_sharpness * delta))
	_hurt_t -= delta
	_flash_t -= delta
	_locked_msg_cd -= delta
	_mouse_idle += delta
	status_t -= delta
	_heal_delay -= delta
	if not dead and _heal_delay <= 0.0 and health < max_health:
		health = minf(health + heal_rate * sheet.heal_mult * delta, max_health)
	# The sheet's slow clock: needs, composure and conditions move a few times a second, not every tick.
	_sheet_t += delta
	if _sheet_t >= 0.25:
		if not dead:
			sheet.tick(_sheet_t, _threat(), not held_by.is_empty(), in_cover and cover_mode == "hunker",
				health / max_health, winded, weight / strength)
		_sheet_t = 0.0
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
			_aim_raw = target
			_aim_raw_on = stick.length() > 0.05
			target += _stick_lock_shift(target, stick.length() > 0.05, delta)
			reticle_offset = reticle_offset.lerp(target, 1.0 - exp(-aim_follow_sharpness * delta))
		else:
			_mouse_lock(delta)
		reticle_offset = reticle_offset.limit_length(current_reticle_range())
		reticle_visible = true
	else:
		var returning := false
		if using_pad:
			# The crosshair tracks the stick: tilt = distance, so easing off the stick floats
			# it back toward you and letting go floats it all the way home. No snapping.
			var target := _stick_reticle_target(stick)
			returning = stick.length() <= 0.05
			_aim_raw = target
			_aim_raw_on = not returning
			target += _stick_lock_shift(target, not returning, delta)
			reticle_offset = reticle_offset.lerp(target, 1.0 - exp(-look_follow_sharpness * delta))
		else:
			# Mouse: it stays where you put it, then floats home once the mouse has been idle.
			returning = _mouse_idle >= mouse_idle_hide
			if returning:
				reticle_offset = reticle_offset.lerp(Vector3.ZERO, 1.0 - exp(-look_return_sharpness * delta))
				lock_target = null
			else:
				_mouse_lock(delta)
		reticle_offset = reticle_offset.limit_length(current_reticle_range())
		# Hidden only once it has actually arrived back on you.
		if returning and reticle_offset.length() < 0.2:
			reticle_offset = Vector3.ZERO
			reticle_visible = false
		else:
			reticle_visible = true
	if not using_pad:
		_aim_raw = reticle_offset
		_aim_raw_on = reticle_visible and (armed or _mouse_idle < mouse_idle_hide)


# ---------------------------------------------------------------- lock-on (sticky aim)
## How far lock-on wants to move a crosshair at `point` (relative to you): toward the nearest
## living enemy you can see within `radius` of it. Full pull inside the core, fading to nothing at
## the radius, so the crosshair never gets stuck: move it away and the pull lets go smoothly.
## Sets lock_target.
func _lock_pull(point: Vector3, radius: float) -> Vector3:
	var prev := lock_target
	lock_target = null
	if not lock_on or dead or wheel_open or radius <= 0.0:
		return Vector3.ZERO
	# A short reach (melee Ready) gets a smaller pull, or it would cover everything around you.
	var r := minf(radius, current_reticle_range() * 0.4)
	var core := minf(lock_on_core, r * 0.5)
	var best := r
	var best_d := r
	var best_off := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var off := en.global_position - global_position
		off.y = 0.0
		var d := off.distance_to(point)
		var score := d * lock_on_hold if en == prev else d
		if score >= best or d >= r or en._alpha < 0.5 or not can_see(en.global_position):
			continue
		best = score
		best_d = d
		best_off = off
		lock_target = en
	if lock_target == null:
		return Vector3.ZERO
	var pull := (1.0 - smoothstep(core, r, best_d)) * clampf(lock_on_strength, 0.0, 1.0)
	return (best_off - point) * pull


## Stick: the crosshair goes where the tilt says, so lock-on shifts that spot, easing in and out.
## Only while the stick is tilted: a stick at rest never aims for you.
func _stick_lock_shift(target: Vector3, tilted: bool, delta: float) -> Vector3:
	var want := Vector3.ZERO
	if tilted:
		want = _lock_pull(target, lock_on_radius)
	else:
		lock_target = null
	_lock_shift = _lock_shift.lerp(want, 1.0 - exp(-lock_on_sharpness * delta))
	return _lock_shift


## Mouse: it has full control while it moves. Once it rests near an enemy, the crosshair settles
## onto that enemy and follows it.
func _mouse_lock(delta: float) -> void:
	_lock_shift = Vector3.ZERO
	if not lock_on_mouse or _mouse_idle < lock_on_mouse_settle:
		lock_target = null
		return
	reticle_offset += _lock_pull(reticle_offset, lock_on_mouse_radius) * (1.0 - exp(-lock_on_sharpness * delta))


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


## How much danger is right on you, for composure: 1 for a zombie at arm's length, less further off, nothing
## past 6 m; a crowd adds up. Dummies don't count.
func _threat() -> float:
	var total := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or en.kind == "dummy":
			continue
		var d := Vector2(en.global_position.x - global_position.x, en.global_position.z - global_position.z).length()
		if d < 6.0:
			total += 1.0 - d / 6.0
	return total


# ---------------------------------------------------------------- cover
func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Are you out of sight of something at `from`: hunkered, with your cover between you and it? With `any_mode`,
## it only asks whether the cover is between you (for shots at someone peeking).
func hidden_from(from: Vector3, any_mode := false) -> bool:
	if not in_cover or cover_face == null or (cover_mode != "hunker" and not any_mode):
		return false
	return Cover.shields(cover_face, Cover.spot(cover_face, cover_t), _xz(from))


func leave_cover() -> void:
	in_cover = false
	cover_entering = false
	cover_face = null
	cover_mode = "hunker"
	cover_side = 0
	cover_blind = false
	_peek_t = 0.0
	_leave_t = 0.0


## Head for a spot on a cover face. `recenter` puts the crosshair back on you when you get there.
func _go_to_cover(f: Cover.Face, t: float, recenter: bool) -> void:
	Cover.prep(f)
	var d := _xz(global_position).distance_to(Cover.spot(f, t))
	in_cover = false
	cover_entering = true
	cover_face = f
	cover_t = t
	_cover_u = t
	cover_mode = "hunker"
	cover_side = 0
	_cover_recenter = recenter
	# A slide from close by, a low run from further off.
	_cover_speed = cover_slide_speed if d <= cover_run_reach else maxf(run_speed * 1.1, 4.0)
	_cover_timeout = d / _cover_speed * 1.6 + 0.6
	running = false


## The Cover button, the crosshair's cover mark, and what state you are in behind cover.
func _update_cover(delta: float, move_dir: Vector3) -> void:
	var can := not dead and not wheel_open and held_by.is_empty() and _stagger <= 0.0 and _vault_t <= 0.0
	# ---- the button: tap = slide into the nearest cover / leave (or vault); hold = go to the marked cover
	if Input.is_action_just_pressed("cover") and can:
		_cover_btn_t = 0.0
		_cover_went = false
	if _cover_btn_t >= 0.0:
		if Input.is_action_pressed("cover") and can:
			_cover_btn_t += delta
			if not _cover_went and _cover_btn_t >= cover_hold_time and cover_mark_face != null:
				_cover_went = true
				_go_to_cover(cover_mark_face, cover_mark_t, true)
		else:
			if not _cover_went and can:
				_cover_tap(move_dir)
			_cover_btn_t = -1.0

	# ---- the mark: which cover the crosshair is pointing out (looked up a few times a second)
	_mark_tick += 1
	if _mark_tick % 6 == 0:
		cover_mark_face = null
		if can and _aim_raw_on and _aim_raw.length() > 1.0:
			var me := _xz(global_position)
			var m := Cover.find_aim(me + _xz(_aim_raw), me, cover_aim_radius)
			if not m.is_empty():
				var sp := Cover.spot(m["face"], m["t"])
				var here := me if not (in_cover or cover_entering) else Cover.spot(cover_face, cover_t)
				if sp.distance_to(here) > 0.8:
					cover_mark_face = m["face"]
					cover_mark_t = m["t"]

	# ---- what the body should be doing
	var crouch := 0.0
	var lean := Vector3.ZERO
	if cover_entering:
		crouch = 0.8
	elif in_cover and cover_face != null:
		_cover_state(delta, move_dir)
	if in_cover and cover_face != null:
		var d3 := Vector3(cover_face.dir.x, 0.0, cover_face.dir.y)
		if cover_face.low:
			if cover_mode == "hunker":
				crouch = 1.0
			elif cover_mode == "peek":
				crouch = 0.7 if cover_side == 0 else 1.0
			else:
				crouch = 0.0 if cover_side == 0 else 0.75
		if cover_side != 0 and (cover_mode != "hunker" or cover_blind):
			lean = d3 * cover_side * (1.0 if cover_mode == "pop" else 0.7)
	elif _vault_t > 0.0:
		crouch = 0.7
	cover_crouch = crouch
	cover_lean_dir = lean


func _cover_tap(move_dir: Vector3) -> void:
	if cover_entering:
		leave_cover()
		return
	if in_cover:
		var n3 := Vector3(cover_face.n.x, 0.0, cover_face.n.y)
		if cover_face.low and move_dir.dot(-n3) > 0.6:
			_try_vault()
		else:
			leave_cover()
		return
	var reach := cover_run_reach if running or _dash_t > 0.0 else cover_reach
	var want := move_dir if move_dir.length() > 0.2 else facing
	var c := Cover.find_near(_xz(global_position), reach, _xz(want))
	if c.is_empty():
		show_status("No cover in reach", 0.7)
		return
	_dash_t = 0.0
	_go_to_cover(c["face"], c["t"], false)


## The open end within `within` meters of where you are, as -1 / 1, or 0. With both in reach, `prefer` (how far
## the aim points along the face) picks; `prefer` near zero picks the nearer one.
func _near_open_end(prefer: float, within: float) -> int:
	var f := cover_face
	var a_ok: bool = f.open[0] and cover_t - f.t_min < within
	var b_ok: bool = f.open[1] and f.t_max - cover_t < within
	if a_ok and b_ok:
		if absf(prefer) > 0.2:
			return 1 if prefer > 0.0 else -1
		return 1 if f.t_max - cover_t < cover_t - f.t_min else -1
	if a_ok:
		return -1
	if b_ok:
		return 1
	return 0


## Hunker, peek or pop, and round which end. Also leaving by pushing away.
func _cover_state(delta: float, move_dir: Vector3) -> void:
	var f := cover_face
	var n3 := Vector3(f.n.x, 0.0, f.n.y)
	var d3 := Vector3(f.dir.x, 0.0, f.dir.y)
	var along := move_dir.dot(d3)
	var into := move_dir.dot(-n3)

	# Pushing firmly away from it leaves.
	_leave_t = _leave_t + delta if into < -0.7 else 0.0
	if _leave_t >= cover_leave_hold:
		leave_cover()
		return

	var mode := "hunker"
	var side := 0
	if armed:
		# Ready pops you out: round an end when you are near one, else up over low cover.
		var aim := reticle_offset if reticle_offset.length() >= aim_min_dist else -n3
		var aim_along := aim.normalized().dot(d3)
		side = _near_open_end(aim_along, cover_edge_dist)
		if f.low and side != 0:
			# Low cover can also be stood up over: when the aim points away from that end, or, on a piece
			# so short that both ends are in reach, when it points straight across.
			var both := _near_open_end(1.0, cover_edge_dist) == 1 and _near_open_end(-1.0, cover_edge_dist) == -1
			if aim_along * side < -0.35 or (both and absf(aim_along) <= 0.2):
				side = 0
		if side != 0 or f.low:
			mode = "pop"
		_peek_t = 0.0
	else:
		# Peeking: hold the stick toward low cover to look over it; hold it along the cover, at an open end
		# where nothing carries on, to look round it.
		var want_side := 0
		if absf(along) > 0.6 and absf(into) < 0.6:
			var e := 1 if along > 0.0 else 0
			var at_end := (f.t_max - cover_t < 0.06) if e == 1 else (cover_t - f.t_min < 0.06)
			if at_end and f.open[e] and f.next[e] == null:
				want_side = 1 if e == 1 else -1
		var want_over := f.low and into > 0.6
		if want_side != 0 or want_over:
			_peek_t += delta
			if _peek_t >= cover_peek_hold:
				mode = "peek"
				side = want_side
		else:
			_peek_t = 0.0
		if cover_blind and mode == "hunker" and not f.low:
			side = cover_side   # the gun arm stays out round the end it is firing round
	cover_mode = mode
	cover_side = side


## Moving in cover: sliding in, sliding along it, leaning out and back. Returns this tick's ground velocity.
func _cover_velocity(delta: float, move_dir: Vector3) -> Vector3:
	var f := cover_face
	var me := _xz(global_position)
	if cover_entering:
		var to := Cover.spot(f, cover_t) - me
		_cover_timeout -= delta
		if to.length() < 0.12:
			cover_entering = false
			in_cover = true
			_cover_u = cover_t
			_peek_t = 0.0
			_leave_t = 0.0
			if _cover_recenter:
				reticle_offset = Vector3.ZERO
				_lock_shift = Vector3.ZERO
				_mouse_idle = 99.0
			return Vector3.ZERO
		if _cover_timeout <= 0.0:
			leave_cover()   # something was in the way
			return Vector3.ZERO
		var ve := to.normalized() * minf(_cover_speed, to.length() / maxf(delta, 0.001))
		return Vector3(ve.x, 0.0, ve.y)

	var d3 := Vector3(f.dir.x, 0.0, f.dir.y)
	var along := move_dir.dot(d3)
	var leaning := cover_side != 0 and cover_mode != "hunker"
	# Slide along it (not while leaning out round an end). Faces that carry on in a line are walked straight onto.
	if absf(along) > 0.25 and not leaning:
		var spd := ready_speed if cover_mode == "pop" else cover_move_speed
		var nt := cover_t + along * spd * delta
		var nf := f
		if nt > f.length and f.next[1] != null:
			nf = f.next[1]
			nt -= f.length
		elif nt < 0.0 and f.next[0] != null:
			nf = f.next[0]
			nt += nf.length
		Cover.prep(nf)
		nt = clampf(nt, nf.t_min, nf.t_max)
		if Cover.has_room(Cover.spot(nf, nt), nf.box):
			if nf != f:
				cover_face = nf
				f = nf
				_cover_u = nt
			cover_t = nt

	# Where along the face the body should be: settled, or out past an end.
	var want_u := cover_t
	if leaning:
		var out := cover_pop_out if cover_mode == "pop" else cover_peek_out
		want_u = f.length + out if cover_side > 0 else -out
	_cover_u = move_toward(_cover_u, want_u, cover_lean_speed * delta)
	var gap := f.a + f.dir * _cover_u + f.n * Cover.STANDOFF - me
	if gap.length() > 1.6:
		leave_cover()   # dragged or knocked well away from it
		return Vector3.ZERO
	var v := (gap / maxf(delta, 0.001)).limit_length(8.0)
	return Vector3(v.x, 0.0, v.y)


## Over low cover and down the other side.
func _try_vault() -> void:
	var f := cover_face
	if f.depth > vault_max_depth:
		show_status("Too deep to vault", 0.8)
		return
	var land := Cover.spot(f, cover_t) - f.n * (f.depth + Cover.STANDOFF * 2.0)
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1
	q.position = Vector3(land.x, global_position.y + 0.9, land.y)
	if not Cover.has_room(land, f.box) or not get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
		show_status("No room on the other side", 0.8)
		return
	_vault_from = global_position
	_vault_to = Vector3(land.x, global_position.y, land.y)
	_vault_h = maxf(f.top - 0.45, 0.2)
	_vault_t = vault_time
	stamina = maxf(stamina - vault_cost, 0.0)
	_regen_delay = maxf(_regen_delay, 0.6)
	leave_cover()


func _vault_step(delta: float) -> void:
	_vault_t -= delta
	var u := clampf(1.0 - _vault_t / maxf(vault_time, 0.01), 0.0, 1.0)
	var p := _vault_from.lerp(_vault_to, smoothstep(0.0, 1.0, u))
	p.y += sin(PI * u) * _vault_h
	global_position = p
	velocity = Vector3.ZERO
	if _vault_t <= 0.0:
		global_position = _vault_to
		velocity = (_vault_to - _vault_from).normalized() * walk_speed


# ---------------------------------------------------------------- vision
const SIGHT_TAPER := 0.1   # radians over which the cone's edge falls from full range to sight_near


## Angle you're facing in the XZ plane, same convention as the sight rays.
func facing_angle() -> float:
	return atan2(facing.z, facing.x)


## How far you'd see in direction a with no walls: full range inside the cone, the short
## all-round distance outside it, tapering across the cone's edge. (fog.gd's shader has the
## same formula.)
func sight_limit(a: float) -> float:
	var off := absf(wrapf(a - facing_angle(), -PI, PI))
	var half := deg_to_rad(sight_fov_deg) * 0.5
	return lerpf(view_range, view_near, smoothstep(half, half + SIGHT_TAPER, off))


## How far you can actually see in direction a right now: the cone, cut short by walls.
func sight_reach_angle(a: float) -> float:
	if sight_rays.size() != SIGHT_RAYS:
		return 0.0
	var f := (wrapf(a, -PI, PI) + PI) / TAU * SIGHT_RAYS
	var i0 := int(floor(f)) % SIGHT_RAYS
	var wall := lerpf(sight_rays[i0], sight_rays[(i0 + 1) % SIGHT_RAYS], f - floor(f))
	return minf(wall, sight_limit(a))


## Sweep the rays: how far it is to the first wall or door in every direction.
func _update_sight(delta := 0.0) -> void:
	# Hunkered behind cover you see only a short way, all round, and your eyes are below the top of low cover.
	# Peeking or popped out, your view is back (and you can be seen).
	var hunkered := in_cover and cover_mode == "hunker"
	var low_eyes := in_cover and cover_face != null and cover_face.low and (hunkered or cover_side != 0)
	var k := 1.0 - exp(-10.0 * delta) if delta > 0.0 else 1.0
	view_range = lerpf(view_range, cover_hunker_sight if hunkered else sight_range, k)
	view_near = lerpf(view_near, cover_hunker_sight if hunkered else sight_near, k)
	_eye_h = lerpf(_eye_h, 0.6 if low_eyes else sight_eye_height, k)
	if sight_rays.size() != SIGHT_RAYS:
		sight_rays.resize(SIGHT_RAYS)
	if _sight_query == null:
		_sight_query = PhysicsRayQueryParameters3D.new()
		_sight_query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	var eye := global_position + Vector3(0.0, _eye_h, 0.0)
	_sight_query.from = eye
	for i in SIGHT_RAYS:
		var a := -PI + i * TAU / SIGHT_RAYS
		var reach := sight_range
		_sight_query.to = eye + Vector3(cos(a), 0.0, sin(a)) * reach
		var hit := space.intersect_ray(_sight_query)
		if not hit.is_empty():
			reach = eye.distance_to(hit["position"])
		sight_rays[i] = reach


## How far you can see toward a world position's direction right now.
func sight_reach_toward(pos: Vector3) -> float:
	return sight_reach_angle(atan2(pos.z - global_position.z, pos.x - global_position.x))


## Is this spot in view: inside the cone (or right next to you) with nothing solid between?
## radius lets something with a body count as seen when its near edge is in view.
func can_see(pos: Vector3, radius := 0.4) -> bool:
	if dead:
		return false
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return d <= sight_reach_toward(pos) + radius


## The reticle is red only when a shot fired right now would really hit an enemy. This traces
## the same path the projectile takes (from the muzzle, along your current facing, same hit
## radius and wall check), so a wall, a shut door, a body in the way, or a facing that hasn't
## turned onto the target yet all keep it white.
func _update_line_of_fire() -> void:
	reticle_on_enemy = false
	reticle_target = null
	if not armed or dead or is_melee() or (in_cover and cover_mode != "pop"):
		return
	var from := muzzle_position()
	var to := from + facing * Projectile.MAX_DIST
	var best_t := 2.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or (en.kind == "raider" and en._alpha < 0.5):
			continue   # (a raider hidden behind cover doesn't turn the reticle red)
		var t := Projectile.segment_hit(from, to, en.global_position, Projectile.HIT_RADIUS)
		if t >= 0.0 and t < best_t:
			best_t = t
			reticle_target = en
	if reticle_target == null:
		return
	var hit := Projectile.wall_hit(get_world_3d().direct_space_state, from, to, [get_rid()])
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		if from.distance_to(hp) / Projectile.MAX_DIST < best_t:
			reticle_target = null   # something solid is in the way
			return
	reticle_on_enemy = true


func _update_facing(delta: float, move_dir: Vector3) -> void:
	var want := Vector3.ZERO
	var rate := turn_speed
	if _vault_t > 0.0:
		want = _vault_to - _vault_from
	elif in_cover and cover_face != null:
		# Hunkered: back to the cover. Peeking or firing blind: turned to it. Popped out: where you aim.
		var n3 := Vector3(cover_face.n.x, 0.0, cover_face.n.y)
		if cover_mode == "pop":
			if reticle_offset.length() >= aim_min_dist:
				facing = reticle_offset.normalized() if not using_pad \
					else _turn_toward(facing, reticle_offset.normalized(), ready_turn_speed * delta)
				return
			want = -n3
		elif cover_mode == "peek" or cover_blind:
			want = -n3
		else:
			want = n3
		facing = _turn_toward(facing, want, turn_speed * delta)
		return
	elif armed:
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
		and not winded and _stagger <= 0.0 and held_by.is_empty() and not in_cover and not cover_entering
	running = want_run and stamina > 0.0
	if running:
		stamina = maxf(stamina - run_drain * sheet.stamina_cost_mult * delta, 0.0)
		_regen_delay = 0.8
		if stamina <= 0.0:
			winded = true
			running = false
			show_status("Winded!", 1.2)
	else:
		_regen_delay -= delta
		if _regen_delay <= 0.0 and _dash_t <= 0.0:
			stamina = minf(stamina + stamina_regen * sheet.stamina_regen_mult * delta, max_stamina)
	if winded and stamina >= max_stamina * 0.35:
		winded = false


func _try_dash(move_dir: Vector3) -> void:
	if not held_by.is_empty():
		show_status("Held! Shove it off or struggle", 0.8)
		return
	if winded or _dash_t > 0.0 or _stagger > 0.0 or stamina < dash_cost * 0.5:
		if winded:
			show_status("Too winded to dash", 0.8)
		return
	leave_cover()   # a dash breaks out of cover
	_dash_dir = move_dir if move_dir.length() > 0.1 else facing
	_dash_dir = _dash_dir.normalized()
	_dash_t = dash_time
	stamina = maxf(stamina - dash_cost * sheet.stamina_cost_mult, 0.0)
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
		take_damage(hurt, Vector3.ZERO, 0.0, false)
		velocity = into * spd * 0.55     # keep some momentum through the doorway
		_stagger = 0.12
		show_status("BAM! Barged through  (power %d vs %d, -%d HP)" % [roundi(power), roundi(need), roundi(hurt)], 2.0)
	else:
		var hurt := 5.0 + need * 0.35
		take_damage(hurt, -into, 5.0, false)
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
	# A punch already under way lands when its windup runs out, whatever else is going on.
	if _swing_t > 0.0 and not _swing_landed and _swing_total - _swing_t >= _swing_windup:
		_land_punch()
	if wheel_open:
		return
	if Input.is_action_just_pressed("reload") and not is_melee():
		_start_reload()
	cover_blind = false
	if in_cover and cover_mode != "pop" and not is_melee():
		# In cover and not popped out: the attack button fires blind, over the cover or round its end.
		# (Something to interact with right beside you still comes first.)
		if attack_tapped and interact_target != null and not armed:
			interact_target.call("interact", self)
			_body.reach()
		elif held and _stagger <= 0.0 and _reload_t <= 0.0:
			cover_blind = true
			if _fire_cd <= 0.0:
				if mag > 0:
					_blind_fire()
				elif reserve > 0:
					_start_reload()
	elif armed:
		if _draw_t > 0.0 or _stagger > 0.0 or _reload_t > 0.0:
			return
		if is_melee():
			# Ready unarmed: zombies that get within reach are shoved back on their own;
			# attack punches.
			_auto_shove()
			if held and _fire_cd <= 0.0:
				_punch()
		elif attack_held() and _fire_cd <= 0.0:
			if mag > 0:
				_fire()
			elif reserve > 0:
				_start_reload()
			elif attack_tapped:
				_bash()
	elif attack_tapped and interact_target != null:
		# Weapon away: the attack button only ever interacts. Punching needs Ready.
		interact_target.call("interact", self)
		_body.reach()


func _start_reload() -> void:
	if _reload_t > 0.0 or mag >= mag_size:
		return
	if reserve <= 0:
		show_status("No ammo. Find some, or bash (attack with an empty weapon).", 1.8)
		return
	_reload_t = reload_time
	show_status("Reloading...", reload_time)


func _fire() -> void:
	_fire_cd = fire_interval
	_shoot(facing, muzzle_position(), true)
	velocity -= facing * shot_kick
	if camera_rig:
		camera_rig.kick(-facing * shot_cam_kick)
	if mag == 0 and reserve > 0:
		_start_reload()


## Blind fire: from cover without popping out. The gun goes up over low cover, or round the nearest open end of
## high cover, and fires toward the crosshair with a wide spread: no aimed bonus, no headshots. Hunkered, you
## don't see what it hits.
func _blind_fire() -> void:
	var f := cover_face
	var n3 := Vector3(f.n.x, 0.0, f.n.y)
	var d3 := Vector3(f.dir.x, 0.0, f.dir.y)
	var dir := -n3
	if reticle_visible and reticle_offset.length() > 0.5:
		dir = reticle_offset.normalized()
	var from := global_position + Vector3(0.0, 1.25, 0.0) - n3 * 0.3
	if not f.low:
		# High cover: the gun has to go round an end. Take the open end within reach that the crosshair favours.
		var side := _near_open_end(dir.dot(d3), cover_edge_dist * 1.5)
		if side == 0:
			show_status("No angle from here: move to an end", 0.9)
			_fire_cd = 0.3
			return
		var u := f.length + 0.35 if side > 0 else -0.35
		var at := f.a + f.dir * u + f.n * (Cover.STANDOFF * 0.6)
		from = Vector3(at.x, global_position.y + 1.25, at.y)
		if dir.dot(-n3) < 0.15:
			dir = (-n3 + d3 * side * 0.4).normalized()   # it can only point past the wall
		cover_side = side
	var spread := blind_fire_spread_deg * sheet.spread_mult * clampf(1.0 - 0.02 * sheet.bonus("dexterity"), 0.6, 1.4)
	dir = dir.rotated(Vector3.UP, deg_to_rad(randf_range(-spread, spread)))
	_fire_cd = fire_interval * blind_fire_slow
	_blind_t = 0.3
	_shoot(dir, from, false)
	if camera_rig:
		camera_rig.kick(-dir * shot_cam_kick * 0.5)
	if mag == 0 and reserve > 0:
		_start_reload()


## One round leaves the gun: the projectile, the flash, the noise. `aimed` lets it carry the aimed-shot bonus.
func _shoot(dir: Vector3, from: Vector3, aimed: bool) -> void:
	mag -= 1
	_flash_t = 0.06
	var shot := Projectile.new()
	shot.dir = dir
	shot.speed = shot_speed
	shot.damage = shot_damage
	shot.exclude = [get_rid()]
	shot.shooter = self
	# Fired with the reticle on an enemy: the shot is "aimed" at that enemy.
	if aimed and reticle_target != null:
		shot.aimed_at = reticle_target
		# Conditions (shaken, tired, hurt) eat into the bonus, not the base damage.
		shot.aimed_mult = 1.0 + (aimed_mult - 1.0) * sheet.aim_mult
		shot.headshot_chance = headshot_chance * sheet.aim_mult
	shots_fired += 1
	print("[fire] #%d dir %s mag %d%s" % [shots_fired, dir, mag, "" if aimed else " (blind)"])
	shot.position = from
	get_parent().add_child(shot)
	# The shot is loud: every enemy within earshot comes to where it was fired.
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en != null and en.global_position.distance_to(global_position) <= shot_noise_range:
			en.hear_noise(global_position)


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
	var dmg := randf_range(punch_damage_min, punch_damage_max) * _swing_power * melee_mult
	if Vector2(velocity.x, velocity.z).length() < punch_still_speed:
		dmg *= punch_still_mult
	target.take_hit(dmg, facing, punch_knock)


## Shove everything in reach in front of you straight back. No damage. Needs your guard:
## once you're spent you can't shove until you've caught your breath.
func _auto_shove() -> void:
	if _shove_cd > 0.0 or not is_guarding():
		return
	var alive: Array[Enemy] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en != null and not en.dead and en.kind != "dummy":
			alive.append(en)
	# Whoever has come within reach in front of you sets it off...
	var shoved: Array[Enemy] = []
	for en in alive:
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < shove_range and to.normalized().dot(facing) > shove_arc_dot:
			shoved.append(en)
	if shoved.is_empty():
		return
	# ...and anything standing right beside them goes too.
	var in_reach := shoved.size()
	for en in alive:
		if shoved.has(en):
			continue
		for i in in_reach:
			if en.global_position.distance_to(shoved[i].global_position) < shove_adjacent:
				shoved.append(en)
				break
	for en in shoved:
		var away := en.global_position - global_position
		away.y = 0.0
		en.shove(away.normalized(), shove_force)
	_shove_cd = shove_interval
	_block_t = 0.25
	show_status("Shoved back", 0.5)
	_spend_guard(shove_cost)


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
	if not dead and not invulnerable:
		show_status("Hit! -%d HP" % roundi(amount), 0.8)


## A zombie with hands reaches for you. With your guard up and it in front of you, you shove it off before its
## hands close (like any other attack). Otherwise it has hold of you: returns true.
func take_grab(e: Enemy, hands: int) -> bool:
	if dead or hands <= 0:
		return false
	var dir := global_position - e.global_position
	dir.y = 0.0
	dir = dir.normalized()
	if is_guarding() and facing.dot(-dir) >= block_arc_dot:
		_block_t = 0.25
		e.shove(-dir, shove_force)
		show_status("Shoved it off", 0.5)
		_spend_guard(shove_cost)
		return false
	if not held_by.has(e):
		held_by.append(e)
	leave_cover()   # hands on you drag you out of cover
	sheet.startle()
	show_status("Grabbed! Shove it off or struggle free", 1.6)
	return true


func release_grab(e: Enemy) -> void:
	held_by.erase(e)
	if held_by.is_empty():
		_struggle = 0.0


func is_held_by(e: Enemy) -> bool:
	return held_by.has(e)


## A bite from a zombie that has hold of you. Your guard can't stop it: you have to get loose first.
func take_bite(amount: float, dir: Vector3, _e: Enemy) -> void:
	take_damage(amount, dir, 1.0)
	if not dead and not invulnerable:
		show_status("Bitten! -%d HP" % roundi(amount), 0.9)


## Something that helps you get loose (hitting the one holding you).
func loosen_grip(amount: float) -> void:
	if not held_by.is_empty():
		_struggle += amount


## How much the hands on you slow you: one hand, or two hands (or two zombies).
func held_speed() -> float:
	var hands := 0
	for e in held_by:
		hands += e.body.hands() if e.body != null else 1
	if hands <= 0:
		return 1.0
	return held_speed_one if hands == 1 else held_speed_two


## While held: shove off whoever holds you from the front (guard up), or struggle until the grip breaks.
func _update_held(delta: float, mv: Vector2) -> void:
	for e: Enemy in held_by.duplicate():
		if not is_instance_valid(e) or e.dead:
			held_by.erase(e)
	if held_by.is_empty():
		_struggle = 0.0
		_last_mv = mv
		return
	_struggle += (mv - _last_mv).length() * 0.5 * struggle_per_wiggle
	_last_mv = mv
	_struggle = maxf(_struggle - struggle_fade * delta, 0.0)
	if is_guarding() and _shove_cd <= 0.0:
		for e: Enemy in held_by.duplicate():
			var to := e.global_position - global_position
			to.y = 0.0
			if to.normalized().dot(facing) > shove_arc_dot:
				held_by.erase(e)
				e.shove(to.normalized(), shove_force)
				_shove_cd = shove_interval
				_block_t = 0.25
				show_status("Shoved it off", 0.6)
				_spend_guard(break_free_cost)
				break
	var hands := 0
	for e in held_by:
		hands += e.body.hands() if e.body != null else 1
	if not held_by.is_empty() and _struggle >= struggle_needed * (1.8 if hands >= 2 else 1.0):
		for e: Enemy in held_by.duplicate():
			var away := e.global_position - global_position
			away.y = 0.0
			e.shove(away.normalized(), shove_force * 0.4)
		held_by.clear()
		_struggle = 0.0
		show_status("Broke free!", 0.8)


## `fright` off = damage that doesn't scare you (hurting your shoulder on a door you chose to barge).
func take_damage(amount: float, dir: Vector3, knock: float, fright := true) -> void:
	if dead or invulnerable:
		return
	health -= amount
	if fright:
		sheet.hurt(amount / max_health)
	_hurt_t = 0.15
	_heal_delay = 5.0
	if knock > 0.0:
		velocity += dir * knock
		_stagger = maxf(_stagger, 0.15)
	if health <= 0.0:
		health = 0.0
		dead = true
		leave_cover()
		armed = false
		held_by.clear()
		_respawn_t = 2.5
		show_status("You went down. Respawning...", 2.5)


## A gunshot at you, fired from `from`. Your cover decides what it does, when the shot has to cross it to
## reach you (from the side or behind, cover does nothing):
##   hunkered  the cover stops it
##   peeking   only your head shows: a small chance it hits, and then it is a head hit (most of your health)
##   popped out, or not in cover: an ordinary hit
## Returns "cover", "head" or "hit". (Raiders and other players in cover are meant to get the same rule.)
func take_shot(amount: float, dir: Vector3, knock: float, from: Vector3) -> String:
	if dead:
		return "hit"
	if in_cover and cover_mode != "pop" and hidden_from(from, true):
		if cover_mode == "hunker" or randf() >= cover_peek_hit_chance:
			return "cover"
		var dmg := max_health * head_hit_fraction
		take_damage(dmg, dir, knock)
		if not dead and not invulnerable:
			show_status("Head hit! -%d HP" % roundi(dmg), 1.2)
		return "head"
	take_damage(amount, dir, knock)
	if not dead and not invulnerable:
		show_status("Shot! -%d HP" % roundi(amount), 0.8)
	return "hit"


func _respawn() -> void:
	leave_cover()
	dead = false
	global_position = spawn_point
	velocity = Vector3.ZERO
	_cam_carry = Vector3.ZERO
	sheet.reset()
	_reset_vitals()
	if camera_rig:
		camera_rig.snap()


func _reset_vitals() -> void:
	health = max_health
	stamina = max_stamina
	winded = false
	mag = mag_size
	reserve = 8   # one spare magazine: the rest you have to find
	_reload_t = 0.0


# ---------------------------------------------------------------- visuals
func _update_visuals(delta: float) -> void:
	_visual.rotation.y = atan2(-facing.x, -facing.z)
	# The body poses itself from our state: stance, speed, punches, shoves, reload, hits, death.
	_body.animate(self, delta)
	_weapon_mat.emission_energy_multiplier = 4.0 if _flash_t > 0.0 else 0.0

	# Ready with a melee weapon: no reticle. You still turn toward where you're pointing.
	_cover_mark.visible = cover_mark_face != null and not dead
	if _cover_mark.visible:
		var ms := Cover.spot(cover_mark_face, cover_mark_t)
		_cover_mark.global_position = Vector3(ms.x, global_position.y + 0.06, ms.y)
	_reticle.visible = reticle_visible and not dead and not (armed and is_melee())
	_reticle.global_position = global_position + reticle_offset + Vector3(0.0, 0.08, 0.0)
	if not armed:
		# Weapon away: just a look cursor, so keep it a quiet gray (no enemy highlight).
		_reticle_mat.albedo_color = Color(0.62, 0.64, 0.66, 0.55)
	elif reticle_on_enemy:
		_reticle_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.95)
	else:
		_reticle_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
