class_name Player
extends CharacterBody3D
## Two stances:
##  Mouse and keyboard only.
##  WEAPON AWAY (default): face where you walk. The mouse moves a crosshair and the
##    camera pans to keep it centered; your facing doesn't change. Let go and the camera
##    returns to you and the crosshair hides. Attack button = Interact. Hold Sprint to run.
##  COVER (B / Space): tap to slide into the nearest cover or to leave it; hold to go to the cover the crosshair
##    marks. Hunkered you are hidden and nearly blind. Push toward low cover (or along, at an end) to peek. Ready
##    pops you out to aim; attack without Ready fires blind. See the Cover section below and cover.gd.
##  READY (hold right-click / Q): the mouse sets facing, the camera
##    leads toward the aim point. Attack button attacks. Slower, no running (dash still works).
## Doors: click one (weapon away) to open or close it. A strong character can bash a shut one in by dashing at it.

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
@export var backpedal_mult := 0.75      # Ready: speed when moving directly away from aim
@export var draw_time := 0.12         # Ready pressed -> can attack
@export var sprint_tap_time := 0.22     # release Sprint before this = dash, hold past it = run
@export var reticle_range := 16.0       # how far the reticle can roam, in both stances
## Free look (hold F or the middle mouse button): the camera lets go of you and goes with the crosshair, which
## can roam this far. You still only see what your eyes can (the fog of war doesn't lift).
@export var free_look_range := 30.0
var free_look := false
@export var cam_lead_max := Vector2(11.0, 6.0)   # m (across the screen, up and down it) the camera may lead by at the default zoom
@export var cursor_size := 0.7           # the cursor's size on screen (1 = as it was at the default zoom)
@export var look_cam_lead := 0.5        # weapon away: how much of the way to the crosshair the camera goes
@export var reticle_edge := 0.06        # the crosshair stays this share of the screen in from its edges
# Gear adds to the base range per stance. Set these when equipment changes (they can change
# at any time; the reticle is re-clamped every frame).
var look_range_bonus := 0.0             # weapon away: e.g. binoculars
var aim_range_bonus := 0.0              # Ready: e.g. a scoped gun
@export var aim_min_dist := 0.3         # Ready: reticle closer than this doesn't turn you
@export var ready_cam_lead := 0.45     # Ready: how far the camera leans toward the reticle
@export var look_return_sharpness := 6.0  # weapon away: how fast an idle mouse crosshair floats home
@export var mouse_sens := 0.022         # world meters per mouse pixel
@export var mouse_idle_hide := 1.2      # weapon away: idle mouse crosshair starts floating home after this
@export_group("Lock-on")
# Sticky aim: a crosshair resting near an enemy you can see settles onto it and follows it.
# The pull fades out with distance, and moving the mouse takes it off again.
@export var lock_on := true
@export var lock_on_core := 0.5         # m: inside this the crosshair sits dead centre on the enemy
@export var lock_on_strength := 1.0     # 0..1: how far toward the enemy it is drawn (1 = centres)
@export var lock_on_sharpness := 8.0    # how quickly the pull takes hold and lets go (lower = softer)
@export var lock_on_hold := 0.75        # < 1: the enemy already locked wins ties with its neighbours
@export var lock_on_mouse := true       # the crosshair settles onto a nearby enemy once the mouse rests
@export var lock_on_mouse_radius := 1.0 # m: the pull starts when the crosshair rests this close to an enemy
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
# (Zombies notice someone hidden behind cover at Enemy.HIDDEN_NOTICE of their usual range.)
@export var cover_peek_hit_chance := 0.15   # chance a shot crossing your cover hits while you peek
@export var head_hit_fraction := 0.75   # a head hit on you takes this much of full health
@export var blind_fire_spread_deg := 14.0   # blind fire goes this far either side of the crosshair
@export var blind_fire_slow := 1.6      # blind fire's interval is the gun's times this
@export var cover_hold_time := 0.25     # s holding Cover before you go to the marked cover
@export var cover_aim_radius := 1.5     # m: the crosshair marks cover within this of it
@export var vault_time := 0.42          # s to vault low cover
@export var vault_max_depth := 2.2      # m: cover deeper than this can't be vaulted
@export var vault_cost := 6.0           # stamina
@export_group("Roll")
# Double-tap Cover when not in cover: a roll the way you are moving (or the way you face, standing still),
# whichever way you were facing. You turn into it, go over in a burst, and come up facing the way you rolled;
# then there is a moment getting back to your feet before you can move, turn to your aim or attack. An ordinary
# person's roll, not a superhero's: it takes a lot out of you. Nothing can get hold of you while you are going
# over; while you are getting up, anything can.
@export var roll_window := 0.28         # s between the two taps
@export var roll_time := 0.55           # s going over
@export var roll_distance := 3.2        # m it covers
@export var roll_recover := 0.45        # s getting back to your feet afterwards
@export var roll_cost := 32.0           # stamina: a third of an ordinary person's
@export var roll_turn_speed := 9.0      # rad/s turning from the way you rolled to your aim, mouse included
@export_group("Corpse pile")
# Heaps of fallen zombies and the crushed pile under them can be walked on (Enemy.heap_height). It is slow, the
# footing is bad, and the ones still alive in it grab at you. From high enough on it you can get over a wall.
@export var pile_speed := 0.4           # speed on bodies is your speed times this; no running or dashing
@export var pile_step := 0.85           # m: the biggest step up you can take onto it
@export var pile_drain := 6.0           # stamina per second moving on it
@export var pile_slip := 0.08           # chance per second of losing your footing, walking (more when hurried or shaken)
@export var pile_reach := 1.6           # m: from the pile, a wall top this far above your feet can be climbed (Cover)
@export_group("Finisher")
# A zombie on the ground can be finished: put the crosshair on its head from close by and press attack. What you
# do depends on what is in your hands. Weapon away: a stomp unarmed, the butt of the gun if you carry one. Ready
# with the gun: a shot to the head, one round, loud, certain. Blows go by Strength: 14 does it in one, an
# ordinary 10 takes two, a weak 6 three. Rot softens the skull.
@export var finisher_reach := 1.7       # m from you to its head
@export var finisher_aim := 0.55        # m: how close to the head the crosshair has to be
@export var finisher_windup := 0.35     # s from starting the blow to it landing
@export var finisher_recover := 0.4     # s after
@export var finisher_cost := 6.0        # stamina per blow
@export var finisher_full_strength := 14.0   # Strength that does it in one blow
@export var butt_bonus := 1.4           # a rifle butt hits this much harder than a boot
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
@export var barge_noise_range := 14.0   # ... a door barged
@export var bash_strength := 13.0       # Strength needed to bash a door in (stands in for the ability to come)
@export var stomp_noise_range := 5.0    # ... a skull stomped or clubbed
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
# you get loose: shove it off (guard up, facing it) or struggle (wiggle the move keys; hitting it helps).
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
@export var sight_range := 40.0         # meters, how far the cone reaches (26 until the camera could pull back this far)
@export var base_sight_near := 3.0      # meters, all-round awareness (behind you too), at Wisdom 10
var sight_near := 3.0
@export var sight_eye_height := 1.5     # rays go out at this height, so low cover doesn't block sight
const SIGHT_RAYS := 240                 # one every 1.5 degrees, all the way round

@export var cam_stance_sharpness := 3.0 # how gently the camera settles after Ready / lower / weapon swap

## Weapons on the quick wheel, in slot order (slot 0 is at the left, going clockwise).
const WEAPONS: Array[String] = ["fists", "gun", "throw"]
const THROWABLES: Array[String] = ["bottle", "rock"]     # what "throw" throws, the first you have
const WEAPON_NAMES := {"fists": "Unarmed", "gun": "Gun", "throw": "Throw"}
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
var wheel_open := false            # quick weapon wheel is up (Tab held)
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
## The enemy the crosshair is on, and which part of it ("Head", "Torso", "ArmL"...). Ready only.
var hover_target: Enemy = null
var hover_part := ""
@export var hover_radius := 0.34       # m (on the ground, as the camera sees it) from a part to count as on it
@export_group("Accuracy")
## The chance a shot lands on the part the crosshair is on, at arm's length, before skill, range and the gun.
const PART_CHANCE := {"Head": 0.22, "Torso": 0.7, "ArmL": 0.3, "ArmR": 0.3, "LegL": 0.38, "LegR": 0.38}
@export var gun_accuracy := 1.0        # the gun in your hands (1 = an ordinary one). Guns as items will set it
@export var scope_mult := 1.0          # a scope stretches the range you are accurate over (1 = none)
@export var accurate_range := 10.0     # m over which an ordinary gun, unscoped, loses its close-range edge
@export_group("")
var reticle_target: Enemy = null   # the enemy under the reticle (Ready only counts as "aimed")
var lock_target: Enemy = null      # the enemy the crosshair is being drawn onto (lock-on), or null
var _aim_raw := Vector3.ZERO       # where the mouse points (cover marking uses it)
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
var view_range := 40.0             # how far you see now: sight_range and sight_near, or less behind cover
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
var perch := 0.0                   # how far above the ground you stand (on a heap or the corpse pile)
var _wall_box: Cover.Box = null    # the solid thing you are walking into, if any (for climbing it from the pile)
var _wall_n := Vector3.ZERO
var finish_target: Enemy = null    # a downed zombie whose head the crosshair is on
var takedown_target: Raider = null   # a raider you are behind, unnoticed, close enough to take down quietly
var finish_part := ""              # which part of it the crosshair is on: only "Head" finishes it
var _finish_part := ""
var finish_pile = null             # ... or where a trapped one in the corpse pile is (Vector3), or null
var _roll_t := 0.0                 # > 0 while rolling (the body reads these three)
var _roll_total := 0.55
var _roll_dir := Vector3.ZERO
var _roll_rec_t := 0.0             # > 0 while getting back up after a roll
var _roll_turning := false         # up from a roll and still turning round to the aim
var _tap_t := 99.0                 # s since the last Cover tap made out of cover
var _stomp_t := 0.0                # > 0 while a finishing blow is under way (the body reads these)
var _stomp_total := 1.0
var _finish_kind := "stomp"        # stomp, butt
var _finish_landed := true
var _finish_on: Enemy = null
var _finish_at = null
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
## How you are standing: 0 on your feet, 1 crouched, 2 flat on the ground. Lower is slower, quieter and harder
## to see, and your own eyes are lower too.
var posture := 0
## A torch (items.gd "torch") switched on: a beam where you face. You see by it; it shows you to everyone.
var torch_on := false
var _torch_light: SpotLight3D
@export var torch_range := 16.0          # m the beam reaches
@export var torch_angle_deg := 24.0      # half its width
@export var torch_seen := 1.5            # carrying a light in the dark, you are seen from this much further than by day
var _lit_t := 0.0                # your own muzzle flash is still showing you up
var prone_w := 0.0               # for the body: 1 = lying flat
## Prone, you lie along prone_dir (head that way) and crawl on your front. With a gun raised you stay put:
## aiming ahead of you, you stay on your stomach; aiming behind you, you roll onto your back, head where it was,
## and shoot down past your feet. Aim ahead again (or lower the gun) and you roll back over. Nobody crawls on
## their back. prone_back: 0 = on your front, 1 = on your back.
var prone_back := 0.0
var prone_dir := Vector3.FORWARD
var _on_back := false
@export var roll_over_time := 0.5        # s to roll from front to back, or back again
@export var back_beyond_deg := 110.0     # aiming further round than this from where your head points: onto your back
@export var front_within_deg := 80.0     # ... and nearer than this: back onto your stomach
@export var prone_aim_reach := 6.0       # m further the crosshair roams while aiming a gun from the ground
@export_group("Throwing")
@export var throw_base := 8.0            # m you can throw at Strength 0 ...
@export var throw_per_str := 0.6         # ... plus this for each point (14 m at Strength 10)
@export var throw_cooldown := 0.7
@export_group("Stealth")
@export var takedown_reach := 1.6        # m: how close behind someone you have to be
@export var takedown_noise := 3.0        # m it is heard
@export var crouch_speed := 0.55         # of walking speed
@export var prone_speed := 0.25
@export var crouch_seen := 0.65          # crouched, you are seen from this much of the usual distance
@export var prone_seen := 0.4
@export var dark_seen := 0.3              # in pitch dark you are seen from this much of the usual distance
@export var shot_lights_you := 0.6        # s a gunshot shows you up, however dark it is
@export var grass_crouch_seen := 0.7      # crouched in tall grass: this much again
@export var grass_prone_seen := 0.35      # flat in tall grass: you have to be nearly trodden on (about 2.5 m for a raider)
@export var crouch_hide_reach := 1.3     # m: crouched this close behind low cover, it hides you from the far side
@export var prone_hide_reach := 2.6
@export var noise_run := 10.0            # m your footsteps carry: running
@export var noise_walk := 4.5
@export var noise_crouch := 1.5
@export var noise_prone := 0.8
@export_group("")
## What you carry: weighted slots (inventory.gd).
var inv := Inventory.new()
## Seeing to your wounds (the treatment screen is open). You don't move, and you see only a short way.
var treating := false
var treat_look := false          # looking up from it (ALT held): your view is back, your hands stop
@export var treat_sight := 3.0   # m: how far you see while your eyes are on the wound
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
var _reticle_x: MeshInstance3D
## Something that can be broken is under the crosshair (a node in the group "destructible"). Nothing in the game
## is in that group yet; things that can be broken should join it.
var hover_breakable: Node3D = null
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

	# The cursor: a ring on the ground. Ready, on an enemy (or something that can be broken) it gives way to a
	# red x (_reticle_x).
	_reticle = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.42
	tm.rings = 24
	tm.ring_segments = 6
	_reticle.mesh = tm
	var xm := BoxMesh.new()
	xm.size = Vector3(0.5, 0.01, 0.09)
	var x_mat := StandardMaterial3D.new()
	x_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	x_mat.no_depth_test = true
	x_mat.render_priority = 10
	x_mat.albedo_color = Color(1.0, 0.16, 0.12)
	_reticle_x = MeshInstance3D.new()
	_reticle_x.mesh = xm
	_reticle_x.material_override = x_mat
	_reticle_x.rotation.y = PI * 0.25
	_reticle_x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle_x.top_level = true
	var bar2 := MeshInstance3D.new()
	bar2.mesh = xm
	bar2.material_override = x_mat
	bar2.rotation.y = PI * 0.5
	bar2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle_x.add_child(bar2)
	add_child(_reticle_x)
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
	if free_look:
		return reticle_offset
	if not armed and not reticle_visible:
		return Vector3.ZERO
	# The camera goes part of the way to the crosshair, and never so far that you leave the screen.
	var o := reticle_offset * (ready_cam_lead if armed else look_cam_lead)
	var k := camera_rig.distance / 18.0 if camera_rig else 1.0
	var yaw := camera_rig.yaw() if camera_rig else 0.0
	o = o.rotated(Vector3.UP, -yaw)        # into the screen's own left-right and up-down
	o.x = clampf(o.x, -cam_lead_max.x * k, cam_lead_max.x * k)
	o.z = clampf(o.z, -cam_lead_max.y * k, cam_lead_max.y * k)
	return o.rotated(Vector3.UP, yaw)


## A direction on the screen (x right, y down) as a direction on the ground, whichever way the camera is turned.
func screen_to_ground(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, camera_rig.yaw() if camera_rig else 0.0)


## Keep the crosshair on the screen: at the edge it stops and pushes the view along (the camera follows it), so
## it can go as far as you can see, however far in the camera is. Scroll out to see, and reach, further at once.
func _keep_reticle_on_screen() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or reticle_offset.length() < 0.5:
		return
	var vp := get_viewport().get_visible_rect().size
	var box := Rect2(vp * reticle_edge, vp * (1.0 - 2.0 * reticle_edge))
	if box.has_point(cam.unproject_position(global_position + reticle_offset)):
		return
	var lo := 0.0
	var hi := 1.0
	for i in 7:
		var mid := (lo + hi) * 0.5
		if box.has_point(cam.unproject_position(global_position + reticle_offset * mid)):
			lo = mid
		else:
			hi = mid
	reticle_offset *= lo


func show_status(text: String, dur := 1.6) -> void:
	status_text = text
	status_t = dur


func add_ammo(n: int) -> void:
	reserve += n
	show_status("+%d ammo" % n)


# ---------------------------------------------------------------- weapons + quick wheel
func is_melee() -> bool:
	return weapon != "gun"      # fists, or something to throw: nothing that shoots


## True while your guard is up: Ready unarmed with stamina left to spend.
## A drained guard stays down until you've caught your breath (winded clears).
func is_guarding() -> bool:
	return armed and weapon == "fists" and not dead and not winded and stamina > 0.0 and not sheet.one_armed and posture != 2


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


## Hold Tab: the wheel opens. Point with the mouse to highlight a weapon,
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
		if event.pressed and camera_rig and not treating and not wheel_open \
				and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			camera_rig.zoom(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _lmb_event:
				_lmb_edge = true
			_lmb_event = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_event = event.pressed
	if event is InputEventMouseMotion:
		if wheel_open:
			# The mouse points at the wheel instead of moving the crosshair.
			_wheel_vec = (_wheel_vec + event.relative).limit_length(WHEEL_MOUSE_RADIUS)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dead and not treating:
			var rel: Vector2 = event.relative
			# The same hand movement covers the same share of the screen however far out the camera is.
			var far := camera_rig.distance / 18.0 if camera_rig else 1.0
			reticle_offset += screen_to_ground(rel) * mouse_sens * far
			reticle_offset = reticle_offset.limit_length(current_reticle_range())
			_keep_reticle_on_screen()
			_mouse_idle = 0.0


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if dead:
		treating = false
		_respawn_t -= delta
		velocity = Vector3.ZERO
		wheel_open = false
		if _respawn_t <= 0.0:
			_respawn()
		_update_visuals(delta)
		return

	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := screen_to_ground(mv)      # up on the keys is up on the screen
	if _stagger > 0.0:
		move_dir = Vector3.ZERO
	_update_held(delta, mv)

	if treating:
		treat_look = Input.is_action_pressed("look_up")
		if mv.length() > 0.3 or not held_by.is_empty() or _stagger > 0.0:
			stop_treat()
		else:
			# Sat down over it: nothing else happens until you put it down.
			cover_crouch = 0.85
			velocity = velocity.move_toward(Vector3.ZERO, decel * delta)
			move_and_slide()
			_update_sight(delta)
			_update_visuals(delta)
			return

	_update_wheel()
	_update_torch()
	_update_posture()
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
	if _roll_t > 0.0:
		# A burst: it picks up speed going over, and dies away as you come out of it. About roll_distance in all.
		var ru := 1.0 - _roll_t / maxf(_roll_total, 0.01)
		var burst := smoothstep(0.0, 0.25, ru) * (1.0 - 0.75 * smoothstep(0.7, 1.0, ru))
		horiz = _roll_dir * (roll_distance / maxf(_roll_total, 0.01)) * 1.3 * burst
		if _roll_t - delta <= 0.0:
			_roll_rec_t = roll_recover
	elif _roll_rec_t > 0.0:
		# Getting back to your feet: no going anywhere yet.
		horiz = horiz.move_toward(Vector3.ZERO, decel * delta)
	elif (in_cover or cover_entering) and _dash_t <= 0.0 and _stagger <= 0.0:
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
		spd *= held_speed() * sheet.speed_mult * [1.0, crouch_speed, prone_speed][posture]
		if posture == 2 and ((armed and not is_melee()) or prone_back > 0.0):
			spd = 0.0           # aiming from the ground, on your back, or rolling over: you aren't going anywhere
		if perch > 0.25:
			spd *= pile_speed   # wading over bodies
			if move_dir.length() > 0.1:
				stamina = maxf(stamina - pile_drain * delta, 0.0)
				_regen_delay = maxf(_regen_delay, 0.5)
		if _stomp_t > 0.0:
			spd *= 0.15         # planted for the blow
		# A step up onto the bodies that is too high stops you.
		if (Enemy._heap_n > 0 or CorpsePile.it != null) and move_dir.length() > 0.1 \
				and Enemy.heap_height(global_position + move_dir.normalized() * 0.5) > perch + pile_step:
			spd = 0.0
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
	# Standing on bodies raises you (the look of it, and your eyes; the physics body stays on the ground).
	var heaps := Enemy._heap_n > 0 or CorpsePile.it != null
	perch = move_toward(perch, Enemy.heap_height(global_position) if heaps else 0.0, 3.0 * delta)
	_visual.position.y = perch

	_update_facing(delta, move_dir)
	_update_sight(delta)
	_update_line_of_fire()
	_update_combat()
	_update_interact()
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_lit_t -= delta
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
	_stomp_t -= delta
	_roll_t -= delta
	_roll_rec_t -= delta
	_tap_t += delta
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
		# Footing on the bodies: now and then you lose it, sooner if you hurry or have lost your head.
		if not dead and perch > 0.25 and _stagger <= 0.0 and Vector2(velocity.x, velocity.z).length() > 0.3:
			var hurry := 1.0 + clampf(Vector2(velocity.x, velocity.z).length() / maxf(walk_speed * pile_speed, 0.1) - 1.0, 0.0, 2.0)
			var nerve := 2.5 if sheet.composure < 20.0 else (1.5 if sheet.composure < 50.0 else 1.0)
			if randf() < pile_slip * hurry * nerve * _sheet_t:
				_stagger = 0.6
				show_status("You lose your footing!", 0.9)
		if not dead and sheet.body.turned() and not invulnerable:
			_die("You turned.")
		if not dead and sheet.body.dead_from_blood() and not invulnerable:
			_die("You bled out.")
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
	# If you're actively aiming during a stance change (the mouse moved recently enough that the
	# crosshair is still showing), the reticle carries over instead of resetting, so you can ready
	# (or lower) mid-aim without losing your place.
	var aim_active := _mouse_idle < mouse_idle_hide
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
	free_look = Input.is_action_pressed("free_look") and not dead and not treating and not wheel_open
	if free_look:
		_mouse_idle = 0.0       # it stays out there while you hold it
	if armed:
		_mouse_lock(delta)
		reticle_offset = reticle_offset.limit_length(current_reticle_range())
		reticle_visible = true
	else:
		# It stays where you put it, then floats home once the mouse has been idle.
		var returning := _mouse_idle >= mouse_idle_hide
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
		var off := en.aim_point() - global_position   # its middle, or its head when it is on the ground
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


## The mouse has full control while it moves. Once it rests near an enemy, the crosshair settles
## onto that enemy and follows it.
func _mouse_lock(delta: float) -> void:
	# Once the crosshair is on someone it stays where you put it: you are choosing which part of them.
	if not lock_on_mouse or _mouse_idle < lock_on_mouse_settle or hover_target != null:
		lock_target = null
		return
	reticle_offset += _lock_pull(reticle_offset, lock_on_mouse_radius) * (1.0 - exp(-lock_on_sharpness * delta))


## Max reticle distance right now: the shared base plus whatever the current stance's gear adds.
## Ready with a melee weapon keeps the (hidden) look point close, so turning stays quick.
func current_reticle_range() -> float:
	# Pulled back, the crosshair reaches further in step (the same share of the screen), as far as you can see.
	var zf := maxf(camera_rig.distance / 18.0, 1.0) if camera_rig else 1.0
	if free_look:
		return minf(free_look_range * zf, sight_range + 10.0)
	if armed and weapon == "throw":
		return throw_range()
	if armed and is_melee():
		return melee_look_range
	var steady := prone_aim_reach if posture == 2 and armed else 0.0    # braced on the ground, you aim further
	return maxf(minf(reticle_range * zf, sight_range) + (aim_range_bonus if armed else look_range_bonus) + steady, 0.5)


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
	if perch > 0.25:
		total += 1.5   # standing on the dead
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
				if _tap_t < roll_window:
					# The second of two quick taps: a roll. (The first may have started a slide to cover; drop it.)
					_tap_t = 99.0
					leave_cover()
					_start_roll(move_dir)
				else:
					_tap_t = 0.0 if not in_cover else 99.0
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
	cover_crouch = crouch if posture != 1 else maxf(crouch, 0.75)
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
	# On the pile, pushing at a wall whose top is in reach: over it.
	if perch > 0.3 and _wall_box != null and move_dir.dot(-_wall_n) > 0.5:
		_climb_wall_from_pile()
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
		# Peeking: hold a move key toward low cover to look over it; hold it along the cover, at an open end
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
	if sheet.lame:
		show_status("Not on one leg", 0.8)
		return
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


## A roll along the ground, the way you are moving (or facing, if you aren't moving).
func _start_roll(move_dir: Vector3) -> void:
	if _roll_t > 0.0 or _roll_rec_t > 0.0 or _vault_t > 0.0 or dead or sheet.lame or posture == 2:
		return
	if not held_by.is_empty():
		show_status("Held! Shove it off or struggle", 0.8)
		return
	if perch > 0.25:
		show_status("No footing to roll on this", 0.8)
		return
	if winded or _stagger > 0.0 or stamina < roll_cost * 0.6:
		if winded or stamina < roll_cost * 0.6:
			show_status("Too tired to roll", 0.8)
		return
	_roll_dir = (move_dir if move_dir.length() > 0.1 else facing).normalized()
	status_t = 0.0   # (the first tap may have said there was no cover in reach)
	_roll_total = roll_time
	_roll_t = roll_time
	_dash_t = 0.0
	running = false
	stamina = maxf(stamina - roll_cost, 0.0)
	_regen_delay = 1.2
	if stamina <= 0.0:
		winded = true


## From up on the bodies, over the wall you are pushing at and down the far side.
func _climb_wall_from_pile() -> void:
	var b := _wall_box
	if b.top - perch > pile_reach:
		show_status("Too high to reach from here", 0.8)
		return
	var dir := -_wall_n
	var depth := b.rect.size.x if absf(dir.x) > absf(dir.z) else b.rect.size.y
	if depth > vault_max_depth:
		show_status("Too deep to get over", 0.8)
		return
	var land := _xz(global_position) + Vector2(dir.x, dir.z) * (depth + 1.0)
	if not Cover.has_room(land, b) or (Cover.bounds.size != Vector2.ZERO and not Cover.bounds.grow(-1.0).has_point(land)):
		show_status("No room on the other side", 0.8)
		return
	_vault_from = global_position
	_vault_to = Vector3(land.x, global_position.y, land.y)
	_vault_h = maxf(b.top - perch - 0.3, 0.3)
	_vault_t = vault_time * 1.8
	stamina = maxf(stamina - vault_cost * 2.0, 0.0)
	_regen_delay = maxf(_regen_delay, 0.8)


# ---------------------------------------------------------------- finishers
## Which downed zombie (or trapped one in the pile) the crosshair is on the head of, close enough to finish.
func _update_finisher() -> void:
	finish_target = null
	finish_pile = null
	finish_part = ""
	# Only with your weapon raised, and the crosshair on a downed one within reach. Any part of it will do, but
	# only the head finishes it.
	if dead or not armed or not reticle_visible or not held_by.is_empty() or in_cover or _vault_t > 0.0:
		return
	var aim := global_position + reticle_offset
	if hover_target != null and hover_target.is_down() \
			and _xz(hover_target.global_position - global_position).length() <= finisher_reach + 0.4:
		finish_target = hover_target
		finish_part = hover_part
	_update_takedown()
	if finish_target == null and CorpsePile.it != null:
		# Any limb or head sticking out of the pile: there is no telling which are still alive.
		var p = CorpsePile.it.piece_near(aim, finisher_aim + 0.1)
		if p != null and _xz(p - global_position).length() <= finisher_reach:
			finish_pile = p


## How many blows a sound skull takes at your Strength, with what is in your hands.
func finisher_blows() -> int:
	var soft := finish_target.skull_softness() if finish_target != null else 1.0
	var left := 1.0 - (finish_target.head_dmg if finish_target != null else 0.0)
	return maxi(ceili(left / (_blow_power() * soft) - 0.001), 1)


func _blow_power() -> float:
	return clampf(strength / finisher_full_strength, 0.2, 1.0) * (1.0 if is_melee() else butt_bonus)


func _start_finisher() -> void:
	_finish_part = finish_part
	_finish_on = finish_target
	_finish_at = finish_pile
	var at: Vector3 = finish_target.aim_point() if finish_target != null else finish_pile
	var to := at - global_position
	to.y = 0.0
	if to.length() > 0.05:
		facing = to.normalized()
	if armed and not is_melee() and mag > 0 and _reload_t <= 0.0:
		# Ready with the gun: a round through the head. Certain, and loud.
		mag -= 1
		_flash_t = 0.06
		_lit_t = shot_lights_you
		_fire_cd = fire_interval
		shots_fired += 1
		Earshot.make(global_position, shot_noise_range, get_tree())
		if _finish_on != null and _finish_part != "Head":
			_finish_on.take_part_hit(_finish_part, shot_damage, Vector3.DOWN, 0.0)   # point blank: it can't miss
		elif _finish_on != null:
			_finish_on.take_hit(_finish_on.hp + 1.0, Vector3.DOWN, 0.0)
			show_status("Finished it", 0.7)
		elif CorpsePile.it != null:
			_pile_result(CorpsePile.it.stomp_at(_finish_at, 1.0))
		if mag == 0 and reserve > 0:
			_start_reload()
		return
	_finish_kind = "stomp" if is_melee() else "butt"
	_stomp_total = finisher_windup + finisher_recover
	_stomp_t = _stomp_total
	_finish_landed = false
	_fire_cd = _stomp_total
	if _finish_kind == "butt":
		_bash_cd = 0.5
	stamina = maxf(stamina - finisher_cost, 0.0)
	_regen_delay = maxf(_regen_delay, _stomp_total + 0.2)


func _land_finisher() -> void:
	_finish_landed = true
	if _finish_on != null:
		if not is_instance_valid(_finish_on) or not _finish_on.is_down():
			return   # it got up, or it's gone
		Earshot.make(global_position, stomp_noise_range, get_tree(), _finish_on)
		if _finish_part != "Head":
			_finish_on.take_body_blow(_blow_power(), _finish_part, Vector3.DOWN)
			show_status("It's down" if _finish_on.dead else "Go for the head!", 0.7)
		elif _finish_on.take_stomp(_blow_power(), Vector3.DOWN):
			show_status("Skull crushed", 0.8)
		else:
			show_status("Again!", 0.6)
	elif _finish_at != null and CorpsePile.it != null:
		_pile_result(CorpsePile.it.stomp_at(_finish_at, _blow_power()))


## What a blow on something in the pile turned out to be.
func _pile_result(what: String) -> void:
	match what:
		"killed":
			show_status("It was alive. Not now.", 1.0)
		"alive":
			show_status("It's alive! Again!", 0.8)
		_:
			show_status("Only meat.", 0.6)


## Something alive in the corpse pile has hold of your leg (corpse_pile.gd). It stops you for a moment; it may bite.
func pile_grab(dir: Vector3, bite: float) -> void:
	if dead:
		return
	_stagger = maxf(_stagger, 0.7)
	sheet.startle()
	if bite > 0.0:
		take_damage(bite, dir, 0.0)
		_wound("bite", bite, _pick(["LegL", "LegR"]))
		if not dead and not invulnerable:
			show_status("Bitten by something in the pile!", 1.2)
	else:
		show_status("Something in the pile has your leg!", 1.0)


## Caught where the horde is trampling its own: you are in the crush with them.
func take_crush(amount: float, dir: Vector3) -> void:
	take_damage(amount, dir, 2.0)
	_wound("bruise", amount, _pick(["Torso", "Torso", "ArmL", "ArmR"]))
	if not dead and not invulnerable:
		show_status("Crushed in the press!", 0.9)


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
	var eyes_down := treating and not treat_look
	var low_eyes := (in_cover and cover_face != null and cover_face.low and (hunkered or cover_side != 0)) or posture == 1
	var k := 1.0 - exp(-10.0 * delta) if delta > 0.0 else 1.0
	view_range = lerpf(view_range, treat_sight if eyes_down else (cover_hunker_sight if hunkered else sight_range), k)
	view_near = lerpf(view_near, treat_sight if eyes_down else (cover_hunker_sight if hunkered else sight_near), k)
	_eye_h = lerpf(_eye_h, (0.3 if posture == 2 else (0.6 if low_eyes else sight_eye_height)) + perch, k)   # higher up, you see over more
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
	# By night the dark closes in; what stands in lamp light still shows from as far as ever.
	var dark := lerpf(Daylight.sight_share(), 1.0, Daylight.lamp_light(pos))
	return d <= sight_reach_toward(pos) * dark + radius


## The reticle is red only when a shot fired right now would really hit an enemy. This traces
## the same path the projectile takes (from the muzzle, along your current facing, same hit
## radius and wall check), so a wall, a shut door, a body in the way, or a facing that hasn't
## turned onto the target yet all keep it white.
## Which enemy, and which part of it, the crosshair is on. The crosshair is a point on the ground; a part that
## is up off the ground is taken where the camera sees it against the ground (the camera never turns).
func _update_hover() -> void:
	hover_target = null
	hover_part = ""
	hover_breakable = null
	if not armed or dead or not reticle_visible:
		return
	for n in get_tree().get_nodes_in_group("destructible"):
		var b := n as Node3D
		if b != null and _xz(b.global_position - global_position - reticle_offset).length() <= 0.7:
			hover_breakable = b
			break
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var aim := global_position + reticle_offset
	var reach := current_reticle_range() + 2.0
	var best := hover_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or en._alpha < 0.5 or _xz(en.global_position - global_position).length() > reach:
			continue
		var pts: Dictionary = en.part_points()
		for slot: String in pts:
			var q: Vector3 = pts[slot]
			var g := c + (q - c) * (c.y / maxf(c.y - q.y, 0.01))    # where the camera sees it on the ground
			var d := _xz(g - aim).length()
			if slot == "Torso":
				d *= 0.8        # the biggest part: a little easier to be on
			if d < best:
				best = d
				hover_target = en
				hover_part = slot


## The chance a shot at this range lands on the part aimed at: better up close, with Dexterity, with a better
## gun or a scope; worse shaken, hurt or tired.
func part_chance(part: String, dist: float) -> float:
	var skill := maxf(1.0 + 0.04 * sheet.bonus("dexterity"), 0.4) * sheet.aim_mult
	var near := clampf(1.8 - dist / maxf(accurate_range * gun_accuracy * scope_mult, 1.0) * 0.8, 0.35, 1.8)
	return clampf(float(PART_CHANCE.get(part, 0.3)) * skill * gun_accuracy * near, 0.02, 0.95)


func _update_line_of_fire() -> void:
	reticle_on_enemy = false
	reticle_target = null
	_update_hover()
	if not armed or dead or is_melee() or (in_cover and cover_mode != "pop"):
		return
	if hover_target != null:
		# The crosshair is on someone: that is who you are aiming at, if nothing solid is in the way.
		var m := muzzle_position()
		var tgt := hover_target.global_position + Vector3(0.0, 1.0, 0.0)
		var w := Projectile.wall_hit(get_world_3d().direct_space_state, m, tgt, [get_rid()])
		if w.is_empty() or m.distance_to(w["position"]) >= m.distance_to(tgt) - 0.5:
			reticle_target = hover_target
			reticle_on_enemy = true
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
	if _roll_t > 0.0 or _roll_rec_t > 0.0:
		# You turn into the roll and come up facing the way you went; only then do you turn to where you aim.
		facing = _turn_toward(facing, _roll_dir, 26.0 * delta)
		_roll_turning = true
		return
	var want := Vector3.ZERO
	var rate := turn_speed
	if _vault_t > 0.0:
		want = _vault_to - _vault_from
	elif in_cover and cover_face != null:
		# Hunkered: back to the cover. Peeking or firing blind: turned to it. Popped out: where you aim.
		var n3 := Vector3(cover_face.n.x, 0.0, cover_face.n.y)
		if cover_mode == "pop":
			if reticle_offset.length() >= aim_min_dist:
				facing = reticle_offset.normalized()
				return
			want = -n3
		elif cover_mode == "peek" or cover_blind:
			want = -n3
		else:
			want = n3
		facing = _turn_toward(facing, want, turn_speed * delta)
		return
	elif armed and hover_target != null and not is_melee():
		want = hover_target.global_position - global_position   # the gun points at who the crosshair is on
		want.y = 0.0
	elif armed:
		want = reticle_offset
	elif _dash_t > 0.0:
		want = _dash_dir
	elif move_dir.length() > 0.1:
		want = move_dir
	# In Ready, a reticle sitting on (or very near) you gives no direction: keep facing as is.
	if want.length() < (aim_min_dist if armed else 0.01):
		return
	want = want.normalized()
	if armed and _roll_turning:
		# Just up from a roll: you turn round to your aim, you don't snap to it.
		facing = _turn_toward(facing, want, roll_turn_speed * delta)
		if facing.dot(want) > 0.999:
			_roll_turning = false
	elif armed:
		facing = want   # the mouse aims you at once
	else:
		facing = _turn_toward(facing, want, rate * delta)
		if facing.dot(want) > 0.999:
			_roll_turning = false


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
		and not winded and _stagger <= 0.0 and held_by.is_empty() and not in_cover and not cover_entering \
		and perch <= 0.25 and not sheet.lame and posture != 2
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
	if posture == 2:
		show_status("Get up first", 0.8)
		return
	if sheet.lame:
		show_status("Not on one leg", 0.8)
		return
	if perch > 0.25:
		show_status("No footing to dash on this", 0.8)
		return
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
	_wall_box = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col != null and col is StaticBody3D and absf(c.get_normal().y) < 0.5 and Cover.box_of(col) != null:
			_wall_box = Cover.box_of(col)
			_wall_n = Vector3(c.get_normal().x, 0.0, c.get_normal().z).normalized()
		if col == null or not col.has_meta("door"):
			continue
		var door: Door = col.get_meta("door")
		var n := c.get_normal()
		var into := -Vector3(n.x, 0.0, n.z)
		if into.length() < 0.01:
			continue
		into = into.normalized()
		var spd := pre_vel.dot(into)
		# Only a bash opens a door by force: a dash into it, by someone strong enough. Running into one does
		# nothing. (Bashing is to become an ability strong characters unlock or learn; Strength stands in for it.)
		if _dash_t > 0.0 and can_bash() and spd >= barge_min_speed and _barge_cd <= 0.0 and door.is_shut():
			_barge(door, spd, into)
			return
		# (Walking into a door no longer pushes it: you open and close doors by clicking them. Owner, 20 Nov 2026.)


## Can this character bash a door in? A stand-in for the ability: Strength of bash_strength or more.
func can_bash() -> bool:
	return strength >= bash_strength


func _barge(door: Door, spd: float, into: Vector3) -> void:
	Earshot.make(global_position, barge_noise_range, get_tree())   # a shoulder into a door carries
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
## Ready = right mouse button (read three ways), or Q.
func ready_held() -> bool:
	if Input.is_action_pressed("ready_weapon"):
		return true
	return _rmb_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or (_has_mouse and (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_RIGHT) != 0)


## Attack / Interact = left mouse button (read three ways).
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
	# A finishing blow under way lands when its windup runs out; a new one starts on the attack button when the
	# crosshair is on a downed zombie's head. It comes before anything else the button does.
	if _roll_t > 0.0 or _roll_rec_t > 0.0:
		cover_blind = false
		return   # hands are busy
	_update_finisher()
	if _stomp_t > 0.0:
		if not _finish_landed and _stomp_total - _stomp_t >= finisher_windup:
			_land_finisher()
		cover_blind = false
		return
	if attack_tapped and (finish_target != null or finish_pile != null) and _fire_cd <= 0.0 and _stagger <= 0.0:
		cover_blind = false
		_start_finisher()
		return
	if Input.is_action_just_pressed("reload") and not is_melee():
		_start_reload()
	cover_blind = false
	# A quiet take-down: behind someone who doesn't know you are there.
	if attack_tapped and takedown_target != null and _fire_cd <= 0.0 and _stagger <= 0.0:
		_takedown()
		return
	if weapon == "throw":
		# Something to throw: Ready and click, or from behind cover without showing yourself.
		if attack_tapped and interact_target != null and not armed:
			interact_target.call("interact", self)
			_body.reach()
		elif attack_tapped and (armed or in_cover) and _fire_cd <= 0.0 and _stagger <= 0.0 and _draw_t <= 0.0:
			_throw()
		return
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
		if _draw_t > 0.0 or _stagger > 0.0 or _reload_t > 0.0 or (posture == 2 and not is_melee() and prone_back > 0.02 and prone_back < 0.98):
			return   # (prone: not while you are rolling over)
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
	_reload_t = reload_time * (2.0 if sheet.one_armed else 1.0)
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
	_lit_t = shot_lights_you
	var shot := Projectile.new()
	shot.dir = dir
	shot.speed = shot_speed
	shot.damage = shot_damage
	shot.exclude = [get_rid()]
	shot.shooter = self
	# Fired with the reticle on an enemy: the shot is "aimed" at that enemy.
	if aimed and reticle_target != null and hover_target == reticle_target:
		shot.aimed_at = reticle_target
		shot.aim_part = hover_part
		shot.part_chance = part_chance(hover_part, _xz(reticle_target.global_position - global_position).length())
	shots_fired += 1
	print("[fire] #%d dir %s mag %d%s" % [shots_fired, dir, mag, "" if aimed else " (blind)"])
	shot.position = from
	get_parent().add_child(shot)
	# The shot is loud: every enemy within earshot comes to where it was fired.
	Earshot.make(global_position, shot_noise_range, get_tree())


## Throw a punch. It doesn't stop you moving. The less stamina you have, the slower and
## weaker it is.
func _punch() -> void:
	if posture == 2:
		return   # not from flat on the ground
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


const PART_WORDS := {"Head": "head", "Torso": "body", "ArmL": "left arm", "ArmR": "right arm", "LegL": "left leg", "LegR": "right leg"}


func interact_prompt() -> String:
	if takedown_target != null:
		return "[Left-click]  Take him down quietly"
	if weapon == "throw" and (armed or in_cover) and finish_target == null:
		var id := throw_item()
		return "[Left-click]  Throw the %s at the crosshair" % Items.name_of(id).to_lower() if id != "" else "Nothing to throw"
	if finish_target == null and finish_pile != null:
		return "[%s]  %s it, in case it's alive" % ["Left-click",
			"Shoot" if armed and not is_melee() and mag > 0 else ("Stomp" if is_melee() else "Rifle-butt")]
	if finish_target != null:
		var btn := "Left-click"
		var where: String = PART_WORDS.get(finish_part, "body")
		if armed and not is_melee() and mag > 0:
			return "[%s]  Shoot it in the %s (1 round, loud)" % [btn, where]
		if finish_part != "Head":
			return "[%s]  %s its %s (it hurts it; the head finishes it)" % [btn, "Stomp" if is_melee() else "Rifle-butt", where]
		var n := finisher_blows()
		return "[%s]  %s its head (%s)" % [btn, "Stomp" if is_melee() else "Rifle-butt",
			"one blow" if n <= 1 else "about %d blows" % n]
	if armed and not is_melee() and reticle_target != null and hover_part != "":
		# Aiming: which part, and roughly how good the shot is. Never a number.
		var ch := part_chance(hover_part, _xz(reticle_target.global_position - global_position).length())
		return "%s: %s" % [str(PART_WORDS.get(hover_part, "body")).capitalize(),
			"a long shot" if ch < 0.15 else ("a hard shot" if ch < 0.35 else ("a fair shot" if ch < 0.6 else ("a good shot" if ch < 0.93 else "can't miss")))]
	if interact_target == null:
		return ""
	var txt: String = interact_target.call("prompt_text", self)
	if armed:
		return "%s  (lower your weapon)" % txt
	return "[Left-click]  %s" % txt


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
	# A zombie's lunge is its teeth; a raider's is the butt of a gun.
	if attacker != null and attacker.kind == "raider":
		_wound("bruise", amount, _pick(["Torso", "ArmL", "ArmR", "Head"]))
	else:
		_wound("bite", amount, _pick(["ArmL", "ArmR", "Torso", "LegL", "LegR"]))
	if not dead and not invulnerable:
		show_status("Hit!", 0.8)


## A zombie with hands reaches for you. With your guard up and it in front of you, you shove it off before its
## hands close (like any other attack). Otherwise it has hold of you: returns true.
func take_grab(e: Enemy, hands: int) -> bool:
	if dead or hands <= 0 or _roll_t > 0.0:
		return false   # (rolling: its hands close on nothing)
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
func take_bite(amount: float, dir: Vector3, e: Enemy) -> void:
	take_damage(amount, dir, 1.0)
	# A standing zombie gets its teeth into an arm, a shoulder, the neck; one on the ground, a leg.
	_wound("bite", amount, _pick(["LegL", "LegR"]) if e != null and e.crawling else _pick(["ArmL", "ArmR", "ArmL", "ArmR", "Torso", "Head"]))
	if not dead and not invulnerable:
		show_status("Bitten!", 0.9)


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
	stop_treat()
	health -= amount
	if fright:
		sheet.hurt(amount / max_health)
	_hurt_t = 0.15
	_heal_delay = 5.0
	if knock > 0.0:
		velocity += dir * knock
		_stagger = maxf(_stagger, 0.15)
	if health <= 0.0:
		_die("You went down.")


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
		_wound("gunshot", dmg, "Head")
		if not dead and not invulnerable:
			show_status("Shot in the head!", 1.2)
		return "head"
	take_damage(amount, dir, knock)
	_wound("gunshot", amount, _pick(["Torso", "Torso", "Torso", "ArmL", "ArmR", "LegL", "LegR"]))
	if not dead and not invulnerable:
		show_status("Shot!", 0.8)
	return "hit"


## A wound on the body (sheet.body) from damage just taken. Nothing if the damage didn't count.
## The end of this character. Infected, they get up again as a zombie carrying what you had; otherwise what you
## had lies where you fell. Then a new character starts with nothing of theirs.
func _die(text: String) -> void:
	health = 0.0
	dead = true
	treating = false
	leave_cover()
	armed = false
	held_by.clear()
	_respawn_t = 3.0
	var things: Array[Dictionary] = []
	for k in inv.slots:
		things.append(inv.slots[k])
	inv = Inventory.new()
	if sheet.body.infected:
		_rise(things)
		text += " What was you gets up again."
	elif not things.is_empty():
		var box := ItemPickup.new()
		box.title = "Your body"
		box.contents = things
		box.position = Vector3(global_position.x, 0.0, global_position.z)
		get_parent().add_child(box)
	show_status(text, 3.0)


## Your old character, turned: a fresh zombie where you fell, missing what you had lost, carrying your things.
func _rise(things: Array[Dictionary]) -> void:
	var e := Enemy.new()
	e.kind = "shambler"
	e.player = self
	e.position = Vector3(global_position.x, 0.0, global_position.z)
	e.carried = things
	e.was_player = true
	get_parent().add_child(e)
	if e.body != null and e.body.shambler != null:
		var parts := {}
		for m in sheet.body.missing:
			parts[m] = "Destroyed"
		e.body.shambler.call("show_parts", parts)
		e.body.shambler.freshness.value = 1.0
		e.body.refresh()
		e._new_zombie(false)
	e.rise_from_death()


## Crouch (Ctrl) and prone (X): each key gets you down and up again. Anything that needs your legs under you
## (cover, a dash, a roll, a vault, a run, being grabbed) stands you up.
func _update_posture() -> void:
	if Input.is_action_just_pressed("crouch"):
		posture = 0 if posture == 1 else 1
	if Input.is_action_just_pressed("prone"):
		posture = 0 if posture == 2 else 2
	if in_cover or cover_entering or _dash_t > 0.0 or _roll_t > 0.0 or _roll_rec_t > 0.0 or _vault_t > 0.0 \
			or not held_by.is_empty() or running or dead or perch > 0.25:
		posture = 0
	prone_w = 1.0 if posture == 2 else 0.0
	if posture != 2:
		prone_back = 0.0
		_on_back = false
		prone_dir = facing
		return
	if not armed or is_melee():
		_on_back = false
		if prone_back <= 0.0:
			prone_dir = facing      # crawling: you point the way you go
	else:
		var aim := reticle_offset if reticle_offset.length() > 0.5 else prone_dir
		var ang := rad_to_deg(prone_dir.angle_to(Vector3(aim.x, 0.0, aim.z).normalized()))
		_on_back = ang > (front_within_deg if _on_back else back_beyond_deg)
	prone_back = move_toward(prone_back, 1.0 if _on_back else 0.0, get_physics_process_delta_time() / maxf(roll_over_time, 0.05))


## How far off you can be seen, as a share of the watcher's usual range.
func seen_mult() -> float:
	var m: float = [1.0, crouch_seen, prone_seen][posture]
	if posture > 0 and TallGrass.at(global_position):
		m *= grass_crouch_seen if posture == 1 else grass_prone_seen      # down in tall grass
	m *= lerpf(dark_seen, 1.0, light_on_you())
	if torch_on:
		m *= lerpf(torch_seen, 1.0, Daylight.level)     # a light in the dark carries; by day it makes no odds
	return m


## How lit you are, 0 to 1: the daylight or a lamp where you stand, or your own gun going off.
func light_on_you() -> float:
	return 1.0 if _lit_t > 0.0 or torch_on else Daylight.at(global_position)


## The torch: E switches it on and off, if you carry one. Dying or losing it puts it out.
func _update_torch() -> void:
	if Input.is_action_just_pressed("torch") and not dead:
		if inv.has("torch"):
			torch_on = not torch_on
			show_status("Torch on: you see by it, and it shows you." if torch_on else "Torch off.", 1.4)
		else:
			show_status("You have no torch.", 1.0)
	if torch_on and (dead or not inv.has("torch")):
		torch_on = false
	Daylight.beam_on = torch_on
	if torch_on:
		Daylight.beam_pos = global_position
		Daylight.beam_dir = facing
		Daylight.beam_range = torch_range
		Daylight.beam_cos = cos(deg_to_rad(torch_angle_deg))
	if _torch_light == null:
		_torch_light = SpotLight3D.new()
		_torch_light.light_color = Color(1.0, 0.95, 0.82)
		_torch_light.light_energy = 3.0
		_torch_light.spot_range = torch_range
		_torch_light.spot_angle = torch_angle_deg
		_torch_light.position = Vector3(0.0, 1.2, 0.0)
		_torch_light.rotation.x = deg_to_rad(-8.0)       # tipped down a little, so it falls on the ground ahead
		_visual.add_child(_torch_light)
	if _torch_light.visible != torch_on:
		_torch_light.visible = torch_on


## How far your footsteps carry right now (0 = silent: standing still).
func noise_radius() -> float:
	var v := Vector2(velocity.x, velocity.z).length()
	if v < 0.3 or dead:
		return 0.0
	if posture == 2:
		return noise_prone
	if posture == 1:
		return noise_crouch
	return noise_run if (running or _dash_t > 0.0 or _roll_t > 0.0) else noise_walk


## Down low behind something: is it between you and whoever is looking from `from`? (Crouched, low cover close
## in front of you; flat on the ground, a little further off. Being "in cover" is the cover system's own rule.)
func low_hidden_from(from: Vector3) -> bool:
	if posture == 0:
		return false
	var me := Vector2(global_position.x, global_position.z)
	var them := Vector2(from.x, from.z)
	var reach := crouch_hide_reach if posture == 1 else prone_hide_reach
	for b in Cover.boxes:
		if not b.low or not Cover.crosses(them, me, b.rect):
			continue
		var near := Vector2(clampf(me.x, b.rect.position.x, b.rect.end.x), clampf(me.y, b.rect.position.y, b.rect.end.y))
		if me.distance_to(near) <= reach:
			return true
	return false


# ---------------------------------------------------------------- throwing
## How far you can throw: further the stronger you are.
func throw_range() -> float:
	return throw_base + throw_per_str * strength


## What you would throw now (the first of THROWABLES you carry), or "".
func throw_item() -> String:
	for id in THROWABLES:
		if inv.has(id):
			return id
	return ""


## Throw it at the crosshair. It arcs, so it clears anything lower than the top of its arc (low cover always; a
## one-storey wall from far enough back); otherwise it drops at the foot of what it hit. From behind cover it
## goes over or round without you showing yourself. It makes a noise where it lands.
func _throw() -> void:
	var id := throw_item()
	if id == "":
		show_status("Nothing to throw. Rocks and bottles lie about.", 1.2)
		_fire_cd = 0.3
		return
	var aim := reticle_offset.limit_length(throw_range())
	if aim.length() < 1.0:
		aim = facing * 1.0
	var from := global_position + Vector3(0.0, 1.6 if posture == 0 and not in_cover else 1.0, 0.0)
	var to := global_position + aim
	to.y = 0.05
	var dist := aim.length()
	var peak := 0.6 + dist * 0.22
	var hit := Projectile.wall_hit(get_world_3d().direct_space_state, from, Vector3(to.x, from.y, to.z), [get_rid()])
	if not hit.is_empty():
		var box := Cover.box_of(hit["collider"])
		var own := in_cover and cover_face != null and box == cover_face.box
		if not own and (box == null or box.top > from.y + peak - 0.3):
			# It hits it and drops at its foot.
			var hp: Vector3 = hit["position"]
			var back := (from - hp)
			back.y = 0.0
			to = Vector3(hp.x, 0.05, hp.z) + back.normalized() * 0.35
			peak *= 0.5
		elif own:
			peak = maxf(peak, box.top - from.y + 0.6)     # up and over what you are hiding behind
	inv.use(id)
	var th := Thrown.new()
	th.item = id
	th.from = from
	th.to = to
	th.peak = peak
	th.flight = 0.45 + from.distance_to(to) * 0.045
	th.thrower = self
	get_parent().add_child(th)
	_fire_cd = throw_cooldown
	stamina = maxf(stamina - 4.0, 0.0)
	if not in_cover:
		facing = aim.normalized()
	_body.reach()
	if throw_item() == "":
		show_status("That was the last thing you had to throw.", 1.2)


# ---------------------------------------------------------------- quiet take-downs
## Behind a raider who doesn't know you are there, close enough to touch, weapon raised: one click and he is
## down without a sound to speak of.
func _update_takedown() -> void:
	takedown_target = null
	if not armed or dead or hover_target == null or not (hover_target is Raider):
		return
	var r := hover_target as Raider
	var to_me := global_position - r.global_position
	to_me.y = 0.0
	if r.sees or r.mode == "fight" or to_me.length() > takedown_reach or to_me.normalized().dot(r.facing) > -0.2:
		return
	takedown_target = r


func _takedown() -> void:
	var r := takedown_target
	takedown_target = null
	var to := r.global_position - global_position
	to.y = 0.0
	facing = to.normalized()
	r.take_hit(r.hp + 1.0, facing, 0.0)
	Earshot.make(global_position, takedown_noise, get_tree(), r)
	_fire_cd = 0.9
	stamina = maxf(stamina - 12.0, 0.0)
	_body.reach()
	show_status("Taken down, quietly.", 1.2)


## Sit down and see to your wounds (H), or put it down again.
func toggle_treat() -> void:
	if treating:
		stop_treat()
	elif dead:
		pass
	elif not held_by.is_empty():
		show_status("Not while something has hold of you.")
	elif armed or _roll_t > 0.0 or _roll_rec_t > 0.0 or _vault_t > 0.0 or _dash_t > 0.0:
		show_status("Put your weapon away and stand still first.")
	else:
		treating = true
		treat_look = false
		running = false


func stop_treat() -> void:
	treating = false
	treat_look = false


func _wound(kind: String, amount: float, part: String) -> void:
	if dead or invulnerable:
		return
	sheet.body.hurt(kind, part, amount)


func _pick(parts: Array) -> String:
	return parts[randi() % parts.size()]


## How close to death you feel. Never a number: you can tell you are close, not how close.
func death_feel() -> String:
	var worst := minf(health / max_health, (sheet.body.blood - sheet.body.dead_at) / (100.0 - sheet.body.dead_at))
	if worst > 0.75:
		return "You feel all right."
	if worst > 0.5:
		return "You are hurt."
	if worst > 0.3:
		return "You are in a bad way."
	if worst > 0.15:
		return "You are badly hurt. You could die of this."
	return "You are dying."


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
	var lie := prone_dir if posture == 2 else facing     # flat on the ground the body lies where it lay; only the aim turns
	_visual.rotation.y = atan2(-lie.x, -lie.z)
	# The body poses itself from our state: stance, speed, punches, shoves, reload, hits, death.
	_body.animate(self, delta)
	_weapon_mat.emission_energy_multiplier = 4.0 if _flash_t > 0.0 else 0.0

	# Ready with a melee weapon: no reticle. You still turn toward where you're pointing.
	_cover_mark.visible = cover_mark_face != null and not dead
	if _cover_mark.visible:
		var ms := Cover.spot(cover_mark_face, cover_mark_t)
		_cover_mark.global_position = Vector3(ms.x, global_position.y + 0.06, ms.y)
	var on_it := armed and (hover_target != null or finish_pile != null or hover_breakable != null)
	_reticle.visible = reticle_visible and not dead and not on_it
	_reticle_x.visible = reticle_visible and not dead and on_it
	_reticle.global_position = global_position + reticle_offset + Vector3(0.0, 0.08, 0.0)
	_reticle_x.global_position = _reticle.global_position
	# The cursor stays the same size on the screen however far in or out the camera is.
	var cs := cursor_size * (camera_rig.distance / 18.0 if camera_rig else 1.0)
	_reticle.scale = Vector3.ONE * cs
	_reticle_x.scale = Vector3.ONE * cs
	# Ready: white. Weapon away: just a look cursor, a quiet grey.
	_reticle_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95) if armed else Color(0.62, 0.64, 0.66, 0.55)
