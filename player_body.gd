class_name PlayerBody
extends Node3D
## The player's body: the MaleBody_Muscular model, its skin shader, and all of its animation.
##
## There are no baked clips. Every physics tick animate() reads the Player's state (speed,
## stance, weapon, punch / shove / reload / dash timers, health) and poses the 72 bones from it,
## so the body always matches what the controller is doing:
##   legs      step in the direction you actually move (forward, strafe, backpedal), at a pace
##             set by your speed; walk blends into run and dash
##   spine     leans into movement, breathes, slumps when tired, flinches when hit
##   head      turns toward the look crosshair while the weapon is away
##   arms      swing while the weapon is away; in Ready the hands are placed (two-bone IK) on a
##             boxing guard or on the gun, and punches, shoves, recoil, reload and bash move them
##   cover     squats behind low cover, comes half up to peek and all the way up to aim over it, leans out round
##             an end, holds the gun up over (or out round) the cover to fire blind, tucks up to vault
##   roll      tucks up and goes once over, head first, the way it is travelling
##   death     falls onto its back until the respawn
##
## Raiders use it too (raider_body.gd): animate() takes anyone who carries the same state fields as the Player.
##
## Model space: +Z is forward, +X is the body's left, feet at the origin. This node sits inside
## the Player's visual (which faces -Z), turned half a turn.

const MODEL_PATH := "res://body/MaleBody_Muscular_mid.glb"
const SHADER_PATH := "res://body/male_body_muscular_skin.gdshader"

## How quickly the bones chase the pose they're asked for. Lower = floatier, higher = snappier.
@export var pose_sharpness := 26.0
## Screen pixels per art pixel for the skin shader's dither pattern.
@export var pixel_size := 1.0

# Finger hinge axes for the left hand (from the body's source rig). Right hand mirrors them.
const HINGE_L := {
	"Index": Vector3(0.5894, -0.1737, -0.7889),
	"Middle": Vector3(0.5753, -0.119, -0.8092),
	"Ring": Vector3(0.5619, -0.0732, -0.824),
	"Pinky": Vector3(0.544, -0.0179, -0.8389),
	"Thumb": Vector3(0.8179, 0.0983, 0.567),
}
const CURL := {"Index": [1.25, 1.45, 0.9], "Middle": [1.25, 1.45, 0.9], "Ring": [1.25, 1.45, 0.9],
	"Pinky": [1.25, 1.45, 0.9], "Thumb": [0.4, 0.45, 0.6]}
const REACH_TIME := 0.35
const MISSING_BIT := {"ArmL": 1, "ArmR": 2, "LegL": 4, "LegR": 8}

var material: ShaderMaterial

var _skel: Skeleton3D
var _mesh: MeshInstance3D
## The outline's kind (outline.gd): the player and allies are ALLY; raider_body.gd sets RAIDER.
var outline_kind := Outline.ALLY
var _outline_on := true
var _flash := Vector2(-1.0, -1.0)
var _weapon: Node3D
var _clothes: MeshInstance3D        # what is worn, drawn over the body (clothes.gd); made the first time it is dressed
var _clothes_tint := -1.0

var _n := 0
var _parent := PackedInt32Array()
var _rest_o: Array[Vector3] = []
var _tq: Array[Quaternion] = []     # the pose being asked for this tick
var _cq: Array[Quaternion] = []     # the pose on screen (chases _tq)
var _dead_q: Array[Quaternion] = []
var _hips := -1
var _chest := -1
var _neck := -1
var _head := -1
var _arm: Array = [[], []]          # per side: clavicle, upper arm, upper roll, forearm, forearm roll, hand
var _leg: Array = [[], []]          # per side: thigh, calf, foot
var _fingers: Array = [[], []]      # per side: [bone, hinge axis, curl factor]
var _ankle_y := 0.08
var _hips_off := Vector3.ZERO
var _cur_off := Vector3.ZERO

var _t := 0.0
var _breath := 0.0
var _phase := 0.0
var _dir := 0.0                     # which way the legs are stepping, relative to facing (0 = forward, + = left)
var _move_w := 0.0
var _run_w := 0.0
var _dash_w := 0.0
var _fist_w := 0.0
var _gun_w := 0.0
var _dead_w := 0.0
var _prone_w := 0.0                 # 1 = flat on the ground, face down (a stand-in: the whole body tipped over)
var _cover_w := 0.0                 # how far down behind cover (0 standing .. 1 squatting)
var _lean := 0.0                    # leaning out round an end: + = to the body's left
var _blind_w := 0.0                 # holding the gun up over, or out round, cover to fire blind
var _slide_w := 0.0                 # sliding into cover
var _vault_w := 0.0
var _roll_w := 0.0                  # tucked up in a roll
var _look := 0.0
var _flinch := 0.0
var _recoil := 0.0
var _reach_t := 0.0
var _punch_side := 1                # 0 = left jab, 1 = right cross; flips with every punch
var _prev_swing := 0.0
var _prev_flash := 0.0
var _was_dead := false
var _gone := 0                      # which limbs are shown cut off (bits: arm L, arm R, leg L, leg R)


func _ready() -> void:
	rotation.y = PI
	var packed := _model_scene()
	if packed == null:
		push_error("PlayerBody: can't load its model")
		return
	var model := packed.instantiate()
	add_child(model)
	var skels := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if skels.is_empty() or meshes.is_empty():
		push_error("PlayerBody: its model has no skeleton or mesh")
		return
	_skel = skels[0]
	_mesh = meshes[0]

	material = _make_material()
	_aim_light_at_sun.call_deferred()
	_mesh.material_override = material
	Outline.apply([_mesh], outline_kind)
	# The shader reads per-vertex detail data, so never let the far-away simplified versions in.
	_mesh.lod_bias = 64.0
	_mesh.extra_cull_margin = 1.5

	_n = _skel.get_bone_count()
	_parent.resize(_n)
	for i in _n:
		_parent[i] = _skel.get_bone_parent(i)
		_rest_o.append(_skel.get_bone_rest(i).origin)
		_tq.append(Quaternion.IDENTITY)
		_cq.append(Quaternion.IDENTITY)
		_dead_q.append(Quaternion.IDENTITY)
	_hips = _bone("Hips")
	_chest = _bone("Chest")
	_neck = _bone("Neck")
	_head = _bone("Head")
	for k in 2:
		var s := "L" if k == 0 else "R"
		var sgn := 1.0 if k == 0 else -1.0
		for nm in ["Clavicle", "UpperArm", "UpperArmRoll", "Forearm", "ForearmRoll", "Hand"]:
			_arm[k].append(_bone(nm + s))
		for nm in ["Thigh", "Calf", "Foot"]:
			_leg[k].append(_bone(nm + s))
		for fname in HINGE_L:
			var h: Vector3 = HINGE_L[fname]
			if k == 1:
				h = Vector3(h.x, -h.y, -h.z)
			for j in 3:
				_fingers[k].append([_bone("%s%s%d" % [fname, s, j + 1]), h.normalized(), CURL[fname][j]])
		# Lying dead: arms flung out, legs a little apart.
		_dead_q[_arm[k][1]] = _rz(sgn * 0.85) * _rx(-0.2)
		_dead_q[_arm[k][3]] = _rx(-0.35)
		_dead_q[_leg[k][0]] = _rz(sgn * 0.14)
	_dead_q[_neck] = _ry(0.3)
	_ankle_y = _global(_leg[0][2]).origin.y


## Which model, and which skin. Other bodies built on this one (raiders) override these.
func _model_scene() -> PackedScene:
	return load(MODEL_PATH) as PackedScene


func _make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("pixel_size", pixel_size)
	return mat


func _bone(bone_name: String) -> int:
	var i := _skel.find_bone(bone_name)
	if i < 0:
		push_error("PlayerBody: bone %s is missing" % bone_name)
		return 0
	return i


## The Player hands over its weapon mesh; the body carries it (in hand, or slung on the back).
func attach_weapon(node: Node3D) -> void:
	_weapon = node
	add_child(node)


## The thing held to hit with goes in this hand (1 right, 0 left; -1 none): a node on the hand's bone, so it
## moves with the hand. The Player shows it or not and sizes it (a bar `length` long, along GRIP_AXIS).
const GRIP_AXIS := Vector3(-1.0, 0.0, 0.0)    # the way a held bar runs through the right fist, in the hand bone's space
                                              # (found by render: tools/preview/held_weapons.png; the left hand mirrors it)
const GRIP_AT := Vector3(0.0, 0.07, 0.0)      # where the fist closes on it, from the hand bone
var _grips: Array = [null, null]


func hold_in(node: Node3D, hand: int) -> void:
	if hand < 0 or _skel == null:
		return
	if _grips[hand] == null:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "HandR" if hand == 1 else "HandL"
		_skel.add_child(ba)
		_grips[hand] = ba
	if node.get_parent() != _grips[hand]:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		_grips[hand].add_child(node)
	# The bar's long side is its Y: turned onto GRIP_AXIS, held a hand's width from its near end.
	var length := (node as MeshInstance3D).mesh.get_aabb().size.y if node is MeshInstance3D else 0.3
	var axis := GRIP_AXIS if hand == 1 else GRIP_AXIS * Vector3(-1.0, 1.0, 1.0)
	node.transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), GRIP_AT + axis * (length * 0.5 - 0.07))


## Reach out with the right hand (interacting with something).
func reach() -> void:
	_reach_t = REACH_TIME


# ====================================================================== the pose
## p is the Player, or anything else with the same state fields (a Raider).
func animate(p, delta: float) -> void:
	if _skel == null:
		return
	_t += delta
	if _was_dead and not p.dead:
		_dead_w = 0.0            # respawned: stand up at once
	_was_dead = p.dead
	for i in _n:
		_tq[i] = Quaternion.IDENTITY

	# ---- what the controller is doing
	var fwd: Vector3 = p.facing
	var left := Vector3.UP.cross(fwd)
	var vel := Vector3(p.velocity.x, 0.0, p.velocity.z)
	if p.dead:
		vel = Vector3.ZERO
	var speed := vel.length()
	var tired: float = p.fatigue()
	var melee: bool = p.is_melee()
	var pace := clampf(speed / maxf(p.walk_speed, 0.1), 0.0, 1.0)
	var run_t := clampf((speed - p.walk_speed) / maxf(p.run_speed - p.walk_speed, 0.1), 0.0, 1.0)

	_move_w = _ease(_move_w, smoothstep(0.15, 1.0, speed), 12.0, delta)
	_run_w = _ease(_run_w, run_t, 10.0, delta)
	_dash_w = _ease(_dash_w, 1.0 if p._dash_t > 0.0 else 0.0, 45.0 if p._dash_t > 0.0 else 14.0, delta)
	_fist_w = _ease(_fist_w, 1.0 if p.armed and melee else 0.0, 16.0, delta)
	var blind: bool = not melee and (p.cover_blind or p._blind_t > 0.0)
	_gun_w = _ease(_gun_w, 1.0 if (p.armed or blind) and not melee else 0.0, 16.0, delta)
	_cover_w = _ease(_cover_w, p.cover_crouch, 13.0, delta)
	_prone_w = _ease(_prone_w, p.prone_w, 7.0, delta)
	_lean = _ease(_lean, p.cover_lean_dir.dot(left), 12.0, delta)
	_blind_w = _ease(_blind_w, 1.0 if blind else 0.0, 16.0, delta)
	_slide_w = _ease(_slide_w, 1.0 if p.cover_entering else 0.0, 18.0, delta)
	_vault_w = _ease(_vault_w, 1.0 if p._vault_t > 0.0 else 0.0, 20.0, delta)
	_dead_w = _ease(_dead_w, 1.0 if p.dead else 0.0, 7.0, delta)
	var hit := 1.0 if p._hurt_t > 0.0 or p._stagger > 0.0 else 0.0
	_flinch = _ease(_flinch, hit, 30.0 if hit > _flinch else 9.0, delta)
	if p._flash_t > _prev_flash:
		_recoil = 1.0            # a shot just went off
	_prev_flash = p._flash_t
	_recoil = _ease(_recoil, 0.0, 16.0, delta)
	_reach_t = maxf(_reach_t - delta, 0.0)
	var ready_w := clampf(_fist_w + _gun_w, 0.0, 1.0)
	if speed > 0.2:
		_dir = lerp_angle(_dir, atan2(vel.dot(left), vel.dot(fwd)), 1.0 - exp(-14.0 * delta))

	# Weapon away: the head follows the look crosshair.
	var look_to := 0.0
	if not p.armed and not p.dead and p.reticle_visible and p.reticle_offset.length() > 0.4:
		look_to = clampf(atan2(p.reticle_offset.dot(left), p.reticle_offset.dot(fwd)), -1.25, 1.25)
	_look = _ease(_look, look_to, 9.0, delta)

	# Punch: pull back during the windup, snap out as it lands, come back during the recovery.
	var hh: int = p.held_hand
	if p._swing_t > _prev_swing + 0.001:
		_punch_side = 1 - _punch_side
	if hh >= 0:
		_punch_side = hh           # a weapon is swung with the hand that holds it
	_prev_swing = p._swing_t
	var pull := 0.0
	var ext := 0.0
	if p._swing_t > 0.0 and p._swing_total > 0.0:
		var el: float = p._swing_total - p._swing_t
		if el < p._swing_windup:
			pull = el / maxf(p._swing_windup, 0.001)
		else:
			ext = 1.0 - smoothstep(0.3, 1.0, (el - p._swing_windup) / maxf(p._swing_total - p._swing_windup, 0.01))
	var shove: float = smoothstep(0.0, 0.12, p._block_t) if melee else 0.0
	var punch_twist := (0.5 * ext - 0.15 * pull) if _punch_side == 1 else (-0.22 * ext + 0.08 * pull)

	# ---- legs: step along the direction of travel
	var stride := lerpf(lerpf(1.1, 2.3, pace), 3.3, _run_w)       # meters per two steps
	_phase = fposmod(_phase + TAU * speed / stride * delta, TAU)
	var m := _move_w
	var hip_yaw := 0.4 * sin(2.0 * _dir) * m                        # hips turn partway into a diagonal
	var a := _dir - hip_yaw
	var amp := lerpf(lerpf(0.26, 0.46, pace), 0.82, _run_w) * lerpf(1.0, 0.6, absf(sin(a))) * m
	var knee_base := lerpf(0.08, 0.3, _run_w) * m
	var knee_lift := lerpf(lerpf(0.55, 0.9, pace), 1.5, _run_w) * m
	var swing_axis := Vector3(-cos(a), 0.0, sin(a))
	var roll_w: float = 1.0 if p._roll_t > 0.0 else 0.0
	_roll_w = _ease(_roll_w, roll_w, 30.0 if roll_w > 0.0 else 12.0, delta)
	# Coming up out of a roll: from a crouch back to standing over the recovery.
	var rising: float = clampf(p._roll_rec_t / 0.45, 0.0, 1.0)
	var crouch := 0.2 * ready_w + 0.12 * _dash_w + 0.07 * tired + 1.15 * maxf(_cover_w, maxf(_roll_w, 0.85 * rising))
	var split := (0.2 * _fist_w + 0.12 * _gun_w) * (1.0 - 0.7 * m)  # Ready: left foot forward
	crouch *= 1.0 - _prone_w      # flat on the ground the legs lie straight
	split *= 1.0 - _prone_w
	var th: Array[float] = [0.0, 0.0]
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var ph := _phase + k * PI
		th[k] = amp * sin(ph)
		var kn := knee_base + knee_lift * pow(maxf(0.0, cos(ph + 0.15)), 2.0)
		var w := 0.7 - 0.3 * cos(ph)
		var wide := sgn * (0.07 * ready_w + 0.1 * absf(sin(a)) * m)   # feet apart in Ready, more so when side-stepping
		_tq[_leg[k][0]] = Quaternion(swing_axis, th[k]) * _rz(wide) * _rx(-crouch - sgn * split)
		_tq[_leg[k][1]] = _rx(kn + 2.0 * crouch)
		_tq[_leg[k][2]] = _rx((th[k] * cos(a) - kn) * w - crouch + sgn * split) * _rz(-wide)

	# ---- flat on the ground: crawling, one knee is drawn up at a time and the toes trail; on the back (to shoot
	# behind) the knees are up and the feet planted
	if _prone_w > 0.001:
		var bk: float = p.prone_back
		for k in 2:
			var sgn := 1.0 if k == 0 else -1.0
			var kick := maxf(0.0, sin(_phase + k * PI)) * m
			var q0 := _rz(sgn * (0.14 + 0.4 * kick)) * _rx(-0.3 * kick)
			var q1 := _rx(0.12 + 0.9 * kick)
			_tq[_leg[k][0]] = _tq[_leg[k][0]].slerp(q0.slerp(_rz(sgn * 0.12) * _rx(-0.75), bk), _prone_w)
			_tq[_leg[k][1]] = _tq[_leg[k][1]].slerp(q1.slerp(_rx(1.25), bk), _prone_w)
			_tq[_leg[k][2]] = _tq[_leg[k][2]].slerp(_rx(0.55 * (1.0 - bk) - 0.3 * bk), _prone_w)

	# ---- a finishing stomp: the right knee comes up, then the boot goes down hard
	if p._stomp_t > 0.0 and melee:
		var su: float = 1.0 - p._stomp_t / maxf(p._stomp_total, 0.01)
		var lift: float = smoothstep(0.0, 0.3, su) * (1.0 - smoothstep(0.38, 0.5, su))
		_tq[_leg[1][0]] = _tq[_leg[1][0]] * _rx(-1.15 * lift)
		_tq[_leg[1][1]] = _tq[_leg[1][1]] * _rx(1.5 * lift)

	# ---- spine
	_breath += delta * TAU / 3.8 * (1.0 + 1.6 * tired)
	var b := 0.5 - 0.5 * cos(_breath)
	var ba := 1.0 + 2.5 * tired
	var sw := sin(TAU * _t / 7.6)
	var sn := sin(_phase)
	var cs := cos(_phase)
	var lean := (0.035 + 0.16 * _run_w) * m + 0.4 * _dash_w
	var lean_axis := Vector3(cos(_dir), 0.0, -sin(_dir))
	var stance_yaw := -0.5 * _fist_w - 0.38 * _gun_w              # Ready: left shoulder forward
	var bend := 0.1 * ready_w + 0.14 * tired - 0.022 * b * ba - 0.22 * _flinch - 0.05 * _recoil + 0.14 * shove \
		+ 0.42 * _cover_w - 0.3 * _slide_w + 0.35 * _vault_w + 0.75 * _roll_w + 0.35 * rising   # hunched behind cover, leaning back in a slide, curled in a roll
	_tq[_hips] = _ry(hip_yaw + 0.4 * stance_yaw - 0.09 * sn * m) * _rz(-0.035 * cs * m)
	if _prone_w > 0.001:
		# Flat on the front. Rolling onto the back (to shoot behind) turns the body over along its length; the
		# head stays where it was.
		var over: float = p.prone_back * PI
		_tq[_hips] = _rz(over) * _rx(1.57 * _prone_w) * Quaternion.IDENTITY.slerp(_tq[_hips], 1.0 - _prone_w)
	_tq[_chest] = _ry(-hip_yaw + 0.6 * stance_yaw + punch_twist + 0.12 * _look) \
		* Quaternion(lean_axis, lean) * _rx(bend) * _rz(-0.34 * _lean) \
		* _ry(0.19 * sn * m * (1.0 + 0.6 * _run_w)) * _rz(0.035 * cs * m + 0.014 * sw)
	_tq[_neck] = _ry(-0.45 * stance_yaw - 0.5 * punch_twist + 0.35 * _look - 0.09 * sn * m) \
		* _rx(-0.03 * m + 0.018 * b * ba - 0.6 * lean * cos(_dir) + 0.1 * tired - 0.15 * _flinch) * _rz(-0.014 * sw + 0.14 * _lean)
	_tq[_head] = _ry(-0.55 * stance_yaw - 0.3 * punch_twist + 0.45 * _look) * _rx(-0.06 * ready_w - 0.3 * _cover_w) * _rz(0.1 * _lean)   # head stays level when hunched or leaning
	if _prone_w > 0.001:
		# On the front: chest propped a little, head up to see ahead, the shoulders rocking with the crawl.
		# On the back: curled up a little, chin to the chest, to see down past the feet.
		var bk2: float = p.prone_back
		_tq[_chest] = _tq[_chest].slerp(_rx(lerpf(-0.28, 0.3, bk2)) * _ry(0.16 * sn * m * (1.0 - bk2)), _prone_w)
		_tq[_neck] = _tq[_neck].slerp(_rx(lerpf(-0.5, 0.4, bk2)), _prone_w)
		_tq[_head] = _tq[_head].slerp(_rx(lerpf(-0.5, 0.35, bk2)), _prone_w)

	# Keep the lower foot on the ground whatever the legs are doing (this is also the walk's bob).
	_hips_off = Vector3(-0.012 * cs * m, 0.0, 0.0)
	_hips_off.y = _ankle_y - minf(_global(_leg[0][2]).origin.y, _global(_leg[1][2]).origin.y)

	# ---- the gun: in the hands when Ready, slung on the back otherwise
	var cg := _global(_chest)
	var reload_u := 0.0
	var reload_w := 0.0
	if p._reload_t > 0.0 and not melee:
		reload_u = 1.0 - clampf(p._reload_t / maxf(p.reload_time, 0.01), 0.0, 1.0)
		reload_w = smoothstep(0.0, 0.12, reload_u) * (1.0 - smoothstep(0.85, 1.0, reload_u))
	var bash: float = smoothstep(0.25, 0.5, p._bash_cd) if not melee else 0.0
	var gun_o := Vector3(cg.origin.x * 0.5 - 0.17, cg.origin.y + 0.11 - 0.05 * reload_w,
		cg.origin.z * 0.5 + 0.42 - 0.08 * _recoil + 0.28 * bash)
	# Blind fire: the gun goes up over the cover (when squatting behind it) or out round its end.
	gun_o += Vector3(0.3 * _lean, 0.46 * _cover_w, 0.06) * _blind_w
	var gun_b := Basis(_rx(-0.12 * _recoil + 0.4 * reload_w) * _rz(0.45 * reload_w))
	if _prone_w > 0.001 and not melee:
		# Lying down the gun is out in front on the ground, or (on the back) held over the belly pointing past
		# the feet. It turns to where you aim; the body stays where it lies.
		var bk3: float = p.prone_back
		var rel: float = (p.prone_dir as Vector3).signed_angle_to(p.facing, Vector3.UP)
		var piv := Vector3(0.0, lerpf(0.16, 0.3, bk3), 0.45)
		var aim_q := _ry(rel)
		gun_o = gun_o.lerp(piv + Basis(aim_q) * Vector3(-0.03, lerpf(0.02, 0.14, bk3), 0.6), _prone_w)
		gun_b = Basis(gun_b.get_rotation_quaternion().slerp(aim_q, _prone_w))
	var grip := gun_o + gun_b * Vector3(0.0, -0.05, -0.27)       # right hand
	var fore := gun_o + gun_b * Vector3(0.05, -0.06, 0.0)        # left hand
	if reload_w > 0.0:
		# The left hand goes to the belt for a fresh magazine and brings it back.
		var fetch := smoothstep(0.12, 0.3, reload_u) * (1.0 - smoothstep(0.5, 0.7, reload_u))
		fore = fore.lerp(cg * Vector3(0.17, -0.2, 0.1), fetch)
	if _weapon != null:
		_weapon.visible = not melee
		var slung := cg * Transform3D(Basis(_rz(0.5) * _rx(PI * 0.5)), Vector3(0.0, 0.17, -0.17))
		var held := Transform3D(gun_b, gun_o)
		var want := slung.interpolate_with(held, _gun_w)
		_weapon.transform = _weapon.transform.interpolate_with(want, 1.0 - exp(-pose_sharpness * delta))

	# ---- arms
	var reach_w := sin(PI * (1.0 - _reach_t / REACH_TIME)) if _reach_t > 0.0 else 0.0
	# A weapon in hand, Ready: held up by the shoulder, drawn up and back in the wind-up, brought down and across
	# in front as it lands. Held in both hands, the other hand closes on it just below.
	var swing_tgt := Vector3.ZERO
	var swing_pole := Vector3.ZERO
	if hh >= 0:
		var hs := 1.0 if hh == 0 else -1.0
		swing_tgt = cg * Vector3(hs * 0.24, 0.44, 0.16)
		swing_tgt = swing_tgt.lerp(cg * Vector3(hs * 0.3, 0.62, -0.06), pull)
		swing_tgt = swing_tgt.lerp(Vector3(-hs * 0.12, cg.origin.y - 0.05, 0.72), ext)
		swing_pole = cg.basis * Vector3(hs * 0.8, -0.7, -0.3)
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var ph := _phase + k * PI
		# Weapon away: hang and swing against the legs; elbows fold up at a run.
		var swing := (0.72 + 0.35 * _run_w) * th[k] * cos(a)
		var hang := -sgn * (0.2 - 0.03 * m - 0.02 * b)
		var pose: Array[Quaternion] = [
			_rx(swing - 0.1 * _run_w * m) * _rz(hang) * _rx(sgn * 0.02 * sw),
			Quaternion.IDENTITY,
			_rx(-(0.04 + 0.34 * maxf(0.0, -sin(ph))) * m - 1.15 * _run_w * m + (0.05 - 0.03 * b) * (1.0 - m)),
			Quaternion.IDENTITY,
			Quaternion.IDENTITY,
		]
		if _fist_w > 0.001:
			# Boxing guard, with the punching hand pulled back or thrown, or both hands shoving.
			var target := cg * Vector3(0.10 if k == 0 else -0.11, 0.36, 0.27 if k == 0 else 0.19)
			var pole := cg.basis * Vector3(sgn * 0.75, -1.0, -0.15)
			if hh >= 0 and k == hh:
				target = swing_tgt
				pole = swing_pole
			elif hh >= 0 and p.held_two:
				target = swing_tgt + (cg.basis * Vector3(-sgn * 0.05, -0.1, -0.02))
				pole = swing_pole * Vector3(-1.0, 1.0, 1.0)
			elif k == _punch_side:
				target = target.lerp(cg * Vector3(sgn * 0.2, 0.26, 0.05), pull)
				target = target.lerp(Vector3(sgn * 0.03, cg.origin.y + 0.3, 0.8), ext)
				pole = pole.lerp(cg.basis * Vector3(sgn, -0.35, 0.0), ext)
			target = target.lerp(cg * Vector3(sgn * 0.12, 0.31, 0.7), shove)
			pose = _blend_arm(pose, _solve_arm(k, target, pole, Quaternion.IDENTITY), _fist_w)
		if _gun_w > 0.001:
			var gpose: Array[Quaternion]
			if k == 0 and _gone & 2 != 0:
				# The right arm is gone: the left hand holds the gun by its grip.
				gpose = _solve_arm(k, grip, Vector3(0.6, -0.5, -0.7), Quaternion.IDENTITY)
			elif k == 0:
				gpose = _solve_arm(k, fore, Vector3(0.5, -1.0, 0.1), Quaternion.IDENTITY)
			else:
				gpose = _solve_arm(k, grip, Vector3(-0.6, -0.5, -0.7), Quaternion.IDENTITY)
			pose = _blend_arm(pose, gpose, _gun_w)
		if _prone_w > 0.001 and _gun_w < 0.999:
			# Crawling: the hands are planted out in front, elbows wide, and pull back one at a time.
			var ctgt := Vector3(sgn * 0.3, 0.04, 0.8 + 0.2 * sin(ph) * m)
			pose = _blend_arm(pose, _solve_arm(k, ctgt, Vector3(sgn, 0.25, -0.4), Quaternion.IDENTITY), _prone_w * (1.0 - _gun_w))
		if k == 1 and reach_w > 0.001:
			var rpose := _solve_arm(k, Vector3(-0.12, cg.origin.y - 0.1, 0.56), Vector3(-0.6, -1.0, 0.0), Quaternion.IDENTITY)
			pose = _blend_arm(pose, rpose, reach_w)
		for j in 5:
			_tq[_arm[k][j + 1]] = pose[j]
		# Fingers: loose when relaxed, fists in the guard and at a run, wrapped round the gun, open to shove.
		var curl := lerpf(0.22 + 0.45 * _run_w * m, 1.0, _fist_w * (1.0 - 0.9 * shove))
		curl = lerpf(curl, 0.85, _gun_w)
		if hh >= 0 and (k == hh or p.held_two and _fist_w > 0.5):
			curl = maxf(curl, 0.95)           # closed on what it holds
		for f in _fingers[k]:
			_tq[f[0]] = Quaternion(f[1], f[2] * curl)

	# ---- down
	if _dead_w > 0.001:
		for i in _n:
			_tq[i] = _tq[i].slerp(_dead_q[i], _dead_w)
		_hips_off *= 1.0 - _dead_w
	rotation = Vector3(-PI * 0.5 * _dead_w, PI, 0.0)
	position = Vector3(0.0, 0.11 * _dead_w, 0.0)
	if p._roll_t > 0.0 and not p.dead:
		# A roll: tucked up (above), the whole body goes once over, head first, the way it is travelling, about a
		# point at its middle. That way is given in the world; here it is turned into the body's own space.
		var ru: float = 1.0 - p._roll_t / maxf(p._roll_total, 0.01)
		var rd: Vector3 = p._roll_dir
		var dir_m := Vector3(rd.dot(left), 0.0, rd.dot(fwd)).normalized()
		var over := Basis(Vector3.UP.cross(dir_m).normalized(), TAU * smoothstep(0.0, 1.0, ru))
		var mid := Vector3(0.0, 0.45, 0.0)
		var half_turn := Basis(Vector3.UP, PI)
		transform = Transform3D(half_turn * over, half_turn * (mid - over * mid))

	# ---- limbs cut off (only looked at when the list changes: its length is enough, limbs don't come back)
	var gone := 0
	var sheet = p.get("sheet")
	if sheet != null and sheet.body != null:
		for part in sheet.body.missing:
			gone |= MISSING_BIT.get(part, 0)
	if gone != _gone:
		show_missing(gone)

	# ---- onto the skeleton
	var kk := 1.0 - exp(-pose_sharpness * delta)
	for i in _n:
		_cq[i] = _cq[i].slerp(_tq[i], kk)
		_skel.set_bone_pose_rotation(i, _cq[i])
	_cur_off = _cur_off.lerp(_hips_off, kk)
	_skel.set_bone_pose_position(_hips, _rest_o[_hips] + _cur_off)

	# ---- flashes
	var tint := Vector3(1.0, 0.35, 0.3)
	var amount := 0.0
	if p._hurt_t > 0.0:
		amount = 0.6
	elif p._dash_t > 0.0:
		tint = Vector3(0.6, 0.85, 1.0)
		amount = 0.4
	material.set_shader_parameter("tint_color", tint)
	material.set_shader_parameter("tint_amount", amount)
	if _clothes != null and amount != _clothes_tint:
		_clothes_tint = amount
		var cm := _clothes.material_override as ShaderMaterial
		cm.set_shader_parameter("tint_color", tint)
		cm.set_shader_parameter("tint_amount", amount)


## Dress the body in these layers (Clothes.layers_of(): outermost first). Nothing worn, nothing drawn.
func dress(layers: Array) -> void:
	if _mesh == null:
		return
	if _clothes == null:
		if layers.is_empty():
			return
		_clothes = Clothes.put_on(_mesh, pixel_size)
		if is_inside_tree():
			var suns := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
			if not suns.is_empty():
				(_clothes.material_override as ShaderMaterial).set_shader_parameter("key_dir", (suns[0] as Node3D).global_transform.basis.z.normalized())
	_clothes.visible = not layers.is_empty()
	Clothes.set_layers(_clothes.material_override as ShaderMaterial, layers)


## Show these limbs as cut off (bits as in MISSING_BIT): the forearm or the lower leg, and all below it, is
## drawn down to nothing at the elbow or knee, which leaves a closed stump. The model itself isn't touched.
func show_missing(gone: int) -> void:
	_gone = gone
	for k in 2:
		_skel.set_bone_pose_scale(_arm[k][3], Vector3.ONE * (0.001 if gone & (1 << k) != 0 else 1.0))
		_skel.set_bone_pose_scale(_leg[k][1], Vector3.ONE * (0.001 if gone & (4 << k) != 0 else 1.0))


## The outline (outline.gd): off once dead, back on when alive again (a raider who respawns).
func set_outline(on: bool) -> void:
	if on == _outline_on or _mesh == null:
		return
	_outline_on = on
	Outline.apply([_mesh], outline_kind if on else -1)


## The outline's flash: seen (just come into view) and warn (lining up a shot at you), 0 or 1 each.
func set_outline_flash(seen: float, warn: float) -> void:
	var f := Vector2(seen, warn)
	if f == _flash or _mesh == null:
		return
	_flash = f
	Outline.flash([_mesh], seen, warn)


# ====================================================================== helpers
## The skin shader does its own banded lighting. Point its light the same way as the level sun,
## so the body is lit from the same side as everything around it.
func _aim_light_at_sun() -> void:
	var suns := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		material.set_shader_parameter("key_dir", (suns[0] as Node3D).global_transform.basis.z.normalized())
		if _clothes != null:
			(_clothes.material_override as ShaderMaterial).set_shader_parameter("key_dir", (suns[0] as Node3D).global_transform.basis.z.normalized())


func _ease(cur: float, to: float, sharpness: float, delta: float) -> float:
	return lerpf(cur, to, 1.0 - exp(-sharpness * delta))


func _rx(angle: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, angle)


func _ry(angle: float) -> Quaternion:
	return Quaternion(Vector3.UP, angle)


func _rz(angle: float) -> Quaternion:
	return Quaternion(Vector3.BACK, angle)


## Where a bone is in model space under the pose being built (_tq), before smoothing.
func _global(i: int) -> Transform3D:
	var t := Transform3D(Basis(_tq[i]), _rest_o[i])
	if i == _hips:
		t.origin += _hips_off
	var p := _parent[i]
	while p >= 0:
		var pt := Transform3D(Basis(_tq[p]), _rest_o[p])
		if p == _hips:
			pt.origin += _hips_off
		t = pt * t
		p = _parent[p]
	return t


func _blend_arm(from: Array[Quaternion], to: Array[Quaternion], w: float) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for j in 5:
		out.append(from[j].slerp(to[j], w))
	return out


## Split a rotation into a turn about `axis` (twist) and the rest (swing): q = swing * twist.
func _swing_twist(q: Quaternion, axis: Vector3) -> Array[Quaternion]:
	var proj := axis * Vector3(q.x, q.y, q.z).dot(axis)
	var twist := Quaternion(proj.x, proj.y, proj.z, q.w)
	if twist.length_squared() < 0.000001:
		twist = Quaternion.IDENTITY
	else:
		twist = twist.normalized()
	return [q * twist.inverse(), twist]


## Two-bone IK. Puts the wrist of arm k (0 = left, 1 = right) on `target` (model space), with the
## elbow pushed toward `pole`. `hand` is the hand's own rotation relative to the forearm.
## Returns rotations for: upper arm, upper-arm roll, forearm, forearm roll, hand. The turn along
## each arm segment goes on its roll bone, which is what keeps the skin from pinching.
func _solve_arm(k: int, target: Vector3, pole: Vector3, hand: Quaternion) -> Array[Quaternion]:
	var ids: Array = _arm[k]
	var cl := _global(ids[0])
	var sh: Vector3 = cl * _rest_o[ids[1]]
	var e0: Vector3 = _rest_o[ids[2]]          # shoulder -> elbow at rest
	var w0: Vector3 = _rest_o[ids[4]]          # elbow -> wrist at rest
	var l1 := e0.length()
	var l2 := w0.length()
	var x0 := e0 / l1
	var w0n := w0 / l2
	var y0 := (w0n - x0 * w0n.dot(x0)).normalized()
	var rest_frame := Basis(x0, y0, x0.cross(y0))

	var d := target - sh
	var dist := clampf(d.length(), absf(l1 - l2) + 0.02, l1 + l2 - 0.004)
	var dn := d.normalized() if d.length() > 0.0001 else Vector3.BACK
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var pp := pole - dn * pole.dot(dn)
	if pp.length() < 0.001:
		pp = Vector3.DOWN - dn * Vector3.DOWN.dot(dn)
	pp = pp.normalized()
	var elbow := sh + dn * along + pp * h
	var wrist := sh + dn * dist

	var x1 := (elbow - sh).normalized()
	var fdir := (wrist - elbow).normalized()
	var y1 := fdir - x1 * fdir.dot(x1)
	y1 = y1.normalized() if y1.length() > 0.0001 else -pp
	var z1 := x1.cross(y1)
	var ru := Basis(x1, y1, z1) * rest_frame.transposed()          # upper arm, model space
	var rf := Basis(z1, (ru * w0n).signed_angle_to(fdir, z1)) * ru  # forearm, model space

	var upper := _swing_twist((cl.basis.inverse() * ru).get_rotation_quaternion(), x0)
	var wristq := _swing_twist(hand, w0n)
	return [upper[0], upper[1], (ru.inverse() * rf).get_rotation_quaternion(),
		wristq[1], wristq[1].inverse() * hand]
