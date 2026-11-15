class_name ZombieBody
extends Node3D
## A zombie's body: the ShamblerMale_Muscular model (rolled by shambler.gd, colored by the decay shader) and all of
## its animation. It works like player_body.gd: there are no baked clips. Every physics tick animate() reads the
## Enemy's state and poses the 72 bones from it, so one script covers every mix of missing parts and every stage of
## decay:
##   walk      a shamble straight at you. One leg is the bad one: it steps short and stiff and its foot scuffs, and the
##             more he has rotted the more it drags, the more the hips hike and the body lurches and stumbles
##   arms      reach for you as he closes in (one arm or both, less the more he's rotted); the others hang and swing
##             limply. A forearm stump reaches the same way, just shorter
##   rigor     stiff joints and a jerky, stop-start motion: the pose only updates in snaps
##   crawl     face down, dragging himself along with the arms (or the stumps); legs trail, stumps and all. Any zombie
##             can be knocked down to crawl; one missing a leg always crawls
##   grab      both hands, or the one he has, close on you; then he pulls in and bites
##   lunge     a zombie without hands crouches and throws himself forward, mouth first
##   flinch    a jolt away from each hit
##   death     he collapses on his face
##
## Model space: +Z is forward, +X is the body's left, feet at the origin. This node sits inside the Enemy's visual
## (which faces -Z), turned half a turn, the same as the player's body.

const MODEL_PATH := "res://assets/characters/ShamblerMale_Muscular/ShamblerMale_Muscular_mid.glb"
## Swapped in when the zombie is far from the camera (the upper part of the screen): 5,000 triangles against 15,000.
const LOW_PATH := "res://assets/characters/ShamblerMale_Muscular/ShamblerMale_Muscular_low.glb"
const PIECES_PATH := "res://assets/characters/ShamblerMale_Muscular/ShamblerMale_Muscular_Pieces_mid.glb"
const SHAMBLER_SCRIPT := preload("res://assets/characters/ShamblerMale_Muscular/shambler.gd")
## The pieces' version of the decay shader: the same shader plus `dissolve`, which also gives a dithered fade when a
## zombie leaves the player's view.
const SHADER := preload("res://assets/characters/ShamblerMale_Muscular/zombie_decay_piece.gdshader")

## How quickly the bones chase the pose they're asked for.
@export var pose_sharpness := 14.0
## Meters from the camera past which the low model is used, and under which the mid model comes back. The gap keeps
## a zombie walking along the line from flipping back and forth. The camera sits 18 m from the player, so on screen
## zombies are about 15 m (bottom edge) to 29 m (top edge) away.
@export var low_beyond := 21.0
@export var mid_within := 19.5
## Where cut-off pieces are put, from the shambler node (Shambler -> ZombieBody -> visual -> Enemy -> the level).
@export var pieces_parent := NodePath("../../../..")
## How often the body is posed, by distance from the player (m): 60 times a second up close (every frame at 60 FPS, but
## not 144 times a second on a fast screen), then 30 and 20. Out of the player's view, 10. Each zombie is offset, so a
## crowd's posing spreads over the frames.
@export var full_rate_within := 6.0
@export var half_rate_within := 14.0
## Posing budget: only the nearest this many zombies within full_rate_within pose at 60 a second; the rest of a
## crowd around the player poses at 30 (no one can tell the back rows of a mob apart at that). Zombies reaching for,
## holding, biting or lunging at the player always get the full rate. The ranking is redone 4 times a second.
@export var full_rate_count := 30

## A part came off and flew away as a piece (passed on from shambler.gd).
signal piece_spawned(slot: String, piece: Node)

const HINGE_L := {
	"Index": Vector3(0.5894, -0.1737, -0.7889),
	"Middle": Vector3(0.5753, -0.119, -0.8092),
	"Ring": Vector3(0.5619, -0.0732, -0.824),
	"Pinky": Vector3(0.544, -0.0179, -0.8389),
	"Thumb": Vector3(0.8179, 0.0983, 0.567),
}
const CURL := {"Index": [1.25, 1.45, 0.9], "Middle": [1.25, 1.45, 0.9], "Ring": [1.25, 1.45, 0.9],
	"Pinky": [1.25, 1.45, 0.9], "Thumb": [0.4, 0.45, 0.6]}
const CRAWL_FORWARD := 1.2      # m: prone, the chest sits over the Enemy's position
const CRAWL_HEIGHT := 0.12      # m: the chest's front clear of the floor
const KNEE_PAD := 0.06          # m: from the knee bone to the front of the knee

## The shambler (shambler.gd on the model's root): parts, Freshness, dismember().
var shambler: Node3D
var _skel: Skeleton3D

var _n := 0
var _parent := PackedInt32Array()
var _rest_o: Array[Vector3] = []
var _tq: Array[Quaternion] = []
var _cq: Array[Quaternion] = []
var _hold_q: Array[Quaternion] = []
var _dead_q: Array[Quaternion] = []
var _hips := -1
var _chest := -1
var _neck := -1
var _head := -1
var _arm: Array = [[], []]
var _leg: Array = [[], []]
var _fingers: Array = [[], []]
var _ankle_y := 0.08
var _hips_off := Vector3.ZERO
var _cur_off := Vector3.ZERO

# Who he is, how he moves: fixed per zombie.
var _rng := RandomNumberGenerator.new()
var _bad := 0                   # the bad leg (0 left, 1 right)
var _lead := 0                  # the arm he reaches with first
var _both_arms := true          # reaches with both arms, or only one
var _hunch := 0.0
var _tilt := 0.0                # head cocked to one side
var _noise_o := 0.0

var _t := 0.0
var _phase := 0.0
var _crawl_phase := 0.0
var _move_w := 0.0
var _prone_w := 0.0
var _reach_w := [0.0, 0.0]
var _grip_w := 0.0
var _bite_w := 0.0
var _lunge_w := 0.0
var _crouch_w := 0.0
var _flinch := 0.0
var _flinch_side := 1.0
var _dead_w := 0.0
var _stumble := 0.0
var _stumble_cd := 3.0
var _hold_t := 0.0
var _was_hurt := 0.0
var _rank := 0                 # this zombie's place in the crowd by distance from the player (see full_rate_count)
static var _ranked_at := -1000
var _pose_acc := randf() * 0.05   # time since last posed; starts offset so a crowd doesn't pose on the same frame
var _first := true
var _dissolve := -1.0           # the dissolve last sent to the parts; -1 = send next time
var _low := false
static var _swap_frame := -1
static var _swaps := 0
const SWAPS_PER_FRAME := 2      # spread a crowd's model swaps over a few frames


func _ready() -> void:
	rotation.y = PI
	if not _make_shambler(MODEL_PATH, null):   # shambler.gd's _ready rolls his parts, Freshness and look
		return
	_aim_light_at_sun.call_deferred()

	_n = _skel.get_bone_count()
	_parent.resize(_n)
	for i in _n:
		_parent[i] = _skel.get_bone_parent(i)
		_rest_o.append(_skel.get_bone_rest(i).origin)
		_tq.append(Quaternion.IDENTITY)
		_cq.append(Quaternion.IDENTITY)
		_hold_q.append(Quaternion.IDENTITY)
		_dead_q.append(Quaternion.IDENTITY)
	_hips = _bone("Hips")
	_chest = _bone("Chest")
	_neck = _bone("Neck")
	_head = _bone("Head")
	for k in 2:
		var s := "L" if k == 0 else "R"
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
	_ankle_y = _global(_leg[0][2]).origin.y
	reroll_style()


## Pick how this one moves: which leg is bad, which arm leads, how hunched. Called again when he's rolled anew.
func reroll_style() -> void:
	_rng.randomize()
	_bad = _rng.randi() % 2
	_lead = _rng.randi() % 2
	_both_arms = _rng.randf() < 0.55
	_hunch = _rng.randf_range(-0.05, 0.12)
	_tilt = _rng.randf_range(-0.22, 0.22)
	_noise_o = _rng.randf_range(0.0, 100.0)
	# Lying dead, face down: each arm flung up by the head, out to the side or down along the body (all flat on the
	# floor, so nothing bends down through it), head turned, legs apart.
	for i in _n:
		_dead_q[i] = Quaternion.IDENTITY
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var out: float = [0.25, 1.2, 2.5][_rng.randi() % 3] + _rng.randf_range(-0.15, 0.15)
		_dead_q[_arm[k][1]] = _rz(sgn * out) * _rx(0.12)
		_dead_q[_arm[k][3]] = _rx(-0.1)
		_dead_q[_leg[k][0]] = _rz(sgn * _rng.randf_range(0.05, 0.25))
		_dead_q[_leg[k][2]] = _rx(0.9)
	_dead_q[_neck] = _ry(0.6 if _rng.randf() < 0.5 else -0.6)
	_dead_q[_head] = _ry(0.5 if _dead_q[_neck].y > 0.0 else -0.5)


## A new zombie (after a respawn): a fresh shambler, rolled anew. Built fresh rather than re-rolled, so the parts
## shown before don't keep holding shader values.
func new_zombie() -> void:
	_make_shambler(LOW_PATH if _low else MODEL_PATH, shambler, false)
	reroll_style()
	_first = true   # starts standing (or lying, for a crawler), not getting up from where the last one died


## Build the shambler from a model file, replacing `from` if given. With `copy`, it becomes the same zombie as `from`
## (a detail swap); otherwise it rolls a new one.
func _make_shambler(path: String, from: Node3D, copy := true) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("ZombieBody: can't load %s" % path)
		return false
	var sh := Node3D.new()
	sh.name = "Shambler"
	sh.set_script(SHAMBLER_SCRIPT)
	sh.set("skin_shader", SHADER)
	sh.set("pieces_scene", load(PIECES_PATH))
	sh.set("pieces_parent", pieces_parent)
	sh.set("roll_on_ready", from == null or not copy)
	sh.add_child(packed.instantiate())
	if from != null:
		remove_child(from)
		from.queue_free()
	add_child(sh)
	if from != null and copy:
		sh.call("copy_look", from)
	var skels := sh.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_error("ZombieBody: %s has no skeleton" % path)
		return false
	shambler = sh
	_skel = skels[0]
	_dissolve = -1.0
	sh.connect("rolled", func(_p: Dictionary, _c: bool) -> void: refresh())   # parts changed (or rolled anew)
	sh.connect("piece_spawned", _on_piece)
	for m in sh.find_children("*", "MeshInstance3D", true, false):
		var gi := m as GeometryInstance3D
		gi.extra_cull_margin = 1.5
		# The shader reads per-vertex data the automatic simplified meshes don't keep; the low model is the far one.
		gi.lod_bias = 64.0
	refresh()
	return true


## Seconds between posings for this zombie now (see full_rate_within and full_rate_count).
func _pose_interval(e: Enemy) -> float:
	if e._alpha <= 0.0 and not e.dead:
		return 0.1
	if e.player == null:
		return 0.0
	var full := 1.0 / 60.0 - 0.0005   # (a hair under, so a 60 FPS frame never skips one)
	if e.state != "walk" and e.state != "down" and not e.dead:
		return full                     # it's got its hands on you, or its teeth in: always smooth
	var now := Time.get_ticks_msec()
	if now - _ranked_at > 250:
		_ranked_at = now
		_rank_crowd(e.player, get_tree())
	var d := Vector2(e.global_position.x - e.player.global_position.x, e.global_position.z - e.player.global_position.z).length()
	if d < full_rate_within and _rank < full_rate_count:
		return full
	return 1.0 / 30.0 if d < half_rate_within else 1.0 / 20.0


## Rank every live zombie by distance from the player (0 = nearest), for the posing budget.
static func _rank_crowd(player: Node3D, tree: SceneTree) -> void:
	var pp := player.global_position
	var list: Array = []
	for n in tree.get_nodes_in_group("enemies"):
		var z := n as Enemy
		if z != null and z.body != null and not z.dead:
			var d := Vector2(z.global_position.x - pp.x, z.global_position.z - pp.z).length_squared()
			list.append([d, z.body])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in list.size():
		(list[i][1] as ZombieBody)._rank = i


## Mid model near the camera, low model far from it. Swaps are spread out so a whole crowd never swaps at once.
func _update_detail(e: Enemy) -> void:
	if e.dead or e._alpha <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(e.global_position + Vector3.UP * 0.9)
	var want_low := d > (mid_within if _low else low_beyond)
	if want_low == _low:
		return
	var frame := Engine.get_process_frames()
	if frame != _swap_frame:
		_swap_frame = frame
		_swaps = 0
	if _swaps >= SWAPS_PER_FRAME:
		return
	_swaps += 1
	if _make_shambler(LOW_PATH if want_low else MODEL_PATH, shambler):
		_low = want_low
		set_fade(e._alpha)


func _bone(bone_name: String) -> int:
	var i := _skel.find_bone(bone_name)
	if i < 0:
		push_error("ZombieBody: bone %s is missing" % bone_name)
		return 0
	return i


# ====================================================================== what he has left
# His decay and what he has left, worked out once and kept: at spawn, when a part comes off (shambler.gd's `rolled`),
# and if his Freshness ever changes (its `changed`; nothing ages a live zombie yet). Never per pose or per tick.
var fresh := 1.0        # Freshness, 1 just turned .. 0 long dead
var rot_amt := 0.0      # 1 - fresh
var rigor_amt := 0.0    # rigor mortis, 0 loose .. 1 fully stiff
var bloat_amt := 0.0    # swollen with gas (the Bloated stage)
var drag := 0.2         # how badly the bad leg drags
var frail := 0.0        # dried out, falling apart
var stiff := 0.0        # rigor or dried stiffness: jerky, short-stepped
var walk_mult := 1.0    # his walking speed against a fresh zombie's
var crawl_mult := 1.0   # his crawling speed against a fresh zombie's (before counting hands)
var shed_chance := 0.0  # chance, each fall_apart_every, that a part just comes off
var _parts := {}
var _hand: Array[bool] = [true, true]
var _hands := 2
var _legs := 2
var _has_head := true
var _fresh_src: Freshness


## Work out his decay and parts again. Called on its own when they change; call it after setting a look by hand
## (shambler.set_skin) outside roll().
func refresh() -> void:
	if shambler == null:
		return
	_parts = shambler.get("parts")
	_hand = [_parts.get("ArmL", "Intact") != "Destroyed", _parts.get("ArmR", "Intact") != "Destroyed"]
	_hands = int(_hand[0]) + int(_hand[1])
	_legs = int(_parts.get("LegL", "Intact") != "Destroyed") + int(_parts.get("LegR", "Intact") != "Destroyed")
	_has_head = _parts.get("Head", "Intact") != "Decapitated"
	var f: Freshness = shambler.get("freshness")
	if f != _fresh_src:
		if _fresh_src != null and _fresh_src.changed.is_connected(refresh):
			_fresh_src.changed.disconnect(refresh)
		_fresh_src = f
		if f != null:
			f.changed.connect(refresh)
	fresh = f.value if f != null else 1.0
	rigor_amt = f.rigor() if f != null else 0.0
	rot_amt = 1.0 - fresh
	bloat_amt = smoothstep(0.7, 0.6, fresh) * smoothstep(0.3, 0.45, fresh)
	drag = 0.2 + 0.8 * smoothstep(0.35, 0.85, rot_amt)
	frail = smoothstep(0.75, 1.0, rot_amt)
	stiff = clampf(rigor_amt + 0.6 * frail, 0.0, 1.0)
	walk_mult = lerpf(1.0, 0.65, smoothstep(0.35, 0.9, rot_amt)) * (1.0 - 0.15 * rigor_amt)
	crawl_mult = lerpf(1.0, 0.6, rot_amt)
	shed_chance = 0.6 * frail


func part(slot: String) -> String:
	return _parts.get(slot, "Intact")


func has_hand(k: int) -> bool:
	return _hand[k]


func hands() -> int:
	return _hands


func legs() -> int:
	return _legs


func has_head() -> bool:
	return _has_head


func freshness() -> float:
	return fresh


func rigor() -> float:
	return rigor_amt


## How far rot slows and breaks his movement: 0 fresh, 1 as far gone as it gets.
func rot() -> float:
	return rot_amt


## Swollen with gas, in the Bloated stage: heavier on his feet, leaning back over the belly.
func bloat() -> float:
	return bloat_amt


## Take a part off (see shambler.gd); the piece flies off pushed by impulse.
func dismember(slot: String, impulse := Vector3.ZERO) -> void:
	if shambler != null:
		shambler.call("dismember", slot, impulse)


## Out of the player's view the body dithers away (1 = fully seen).
func set_fade(alpha: float) -> void:
	if shambler == null:
		return
	var d := clampf(1.0 - alpha, 0.0, 1.0)
	if d == _dissolve:
		return   # unchanged (nearly always): sending it to every part each tick was a real cost in a crowd
	_dissolve = d
	for m in shambler.get("_meshes").values():
		if (m as MeshInstance3D).visible:
			(m as GeometryInstance3D).set_instance_shader_parameter("dissolve", d)


func _on_piece(slot: String, piece: Node) -> void:
	var mi := piece.find_children("*", "MeshInstance3D", true, false)
	if not mi.is_empty():
		_light_material((mi[0] as MeshInstance3D).material_override as ShaderMaterial)
	piece_spawned.emit(slot, piece)


# ====================================================================== the pose
func animate(e: Enemy, delta: float) -> void:
	if _skel == null:
		return
	_update_detail(e)
	_pose_acc += delta
	if _pose_acc < _pose_interval(e) and not _first:
		return
	delta = minf(_pose_acc, 0.25)
	_pose_acc = 0.0
	_t += delta
	for i in _n:
		_tq[i] = Quaternion.IDENTITY
	if _first:
		_first = false
		_prone_w = 1.0 if e.crawling else 0.0   # spawned lying down: no fall
		_dead_w = 0.0

	var rt := rot_amt
	var blo := bloat_amt

	var fwd := e.facing
	var left := Vector3.UP.cross(fwd)
	var vel := Vector3(e.velocity.x, 0.0, e.velocity.z)
	if e.dead:
		vel = Vector3.ZERO
	var speed := vel.length()
	var prone := e.crawling and not e.dead

	_move_w = _ease(_move_w, smoothstep(0.05, 0.6, speed), 8.0, delta)
	_prone_w = _ease(_prone_w, 1.0 if prone else 0.0, 7.0 if prone else 3.0, delta)
	_dead_w = _ease(_dead_w, 1.0 if e.dead else 0.0, 6.0, delta)
	if not e.dead and _dead_w < 0.02:
		_dead_w = 0.0
	var reaching := e.state == "reach" or e.state == "hold" or e.state == "bite"
	_grip_w = _ease(_grip_w, 1.0 if e.state == "hold" or e.state == "bite" else 0.0, 10.0, delta)
	var bite_u := 0.0
	if e.state == "bite":
		bite_u = sin(PI * clampf(e.state_t / maxf(e.bite_time, 0.01), 0.0, 1.0))
	_bite_w = _ease(_bite_w, bite_u, 22.0, delta)
	_crouch_w = _ease(_crouch_w, 1.0 if e.state == "lunge_wind" else 0.0, 9.0, delta)
	_lunge_w = _ease(_lunge_w, 1.0 if e.state == "lunge" else 0.0, 24.0 if e.state == "lunge" else 6.0, delta)
	if e.hurt_t > _was_hurt + 0.001:
		_flinch_side = 1.0 if e.hit_dir.dot(left) > 0.0 else -1.0
	_was_hurt = e.hurt_t
	_flinch = _ease(_flinch, 1.0 if e.hurt_t > 0.0 else 0.0, 30.0 if e.hurt_t > 0.0 else 7.0, delta)

	# Stumbles: the further gone, the more often he lurches and nearly goes over.
	_stumble_cd -= delta * _move_w
	if _stumble_cd <= 0.0:
		_stumble_cd = lerpf(9.0, 2.5, drag) * _rng.randf_range(0.6, 1.4)
		if _rng.randf() < 0.25 + 0.6 * drag:
			_stumble = 1.0
	_stumble = move_toward(_stumble, 0.0, delta * 2.2)
	var stum := sin(PI * _stumble) * (1.0 if _stumble > 0.0 else 0.0)

	# Where he reaches: the target in model space.
	var to_model := _skel.global_transform.affine_inverse()
	var tgt: Vector3 = to_model * e.target
	var gap := Vector2(e.target.x - e.global_position.x, e.target.z - e.global_position.z).length()
	var near := clampf((4.0 - gap) / 2.0, 0.0, 1.0) if e.chasing else 0.0

	if _prone_w > 0.5:
		_pose_crawl(e, delta, speed, rt, stiff, drag, tgt, reaching)
	else:
		_pose_walk(e, delta, speed, rt, stiff, drag, blo, frail, stum, tgt, near, reaching)

	# ---- flinch: thrown back and twisted away from the hit
	_tq[_chest] = _tq[_chest] * _rx(-0.55 * _flinch) * _ry(0.35 * _flinch * _flinch_side)
	_tq[_neck] = _tq[_neck] * _rx(-0.45 * _flinch) * _rz(0.35 * _flinch * _flinch_side)
	_tq[_head] = _tq[_head] * _rx(-0.3 * _flinch)
	for k in 2:
		_tq[_arm[k][1]] = _rx(0.5 * _flinch) * _tq[_arm[k][1]]

	# ---- down
	if _dead_w > 0.001:
		for i in _n:
			_tq[i] = _tq[i].slerp(_dead_q[i], _dead_w)
		_hips_off *= 1.0 - _dead_w

	# Lying down (crawling or dead): on his face, moved back so the chest is over his position. Going down he
	# drops to his knees, then falls forward from the knees onto his hands; getting up runs the same way back.
	var fall := smoothstep(0.0, 1.0, maxf(_prone_w, _dead_w))
	var u := clampf(fall / 0.45, 0.0, 1.0)              # 0..1: dropping to the knees
	var v := clampf((fall - 0.45) / 0.55, 0.0, 1.0)     # 0..1: from kneeling to flat on the floor
	var kneel := u * (1.0 - v)
	if kneel > 0.001:
		for k in 2:
			var ks := 1.0 if k == 0 else -1.0
			_tq[_leg[k][0]] = _tq[_leg[k][0]].slerp(_rx(-0.1) * _rz(ks * 0.08), kneel)
			_tq[_leg[k][1]] = _tq[_leg[k][1]].slerp(_rx(1.75), kneel)
			_tq[_leg[k][2]] = _tq[_leg[k][2]].slerp(_rx(0.9), kneel)
			var reach_down := smoothstep(0.3, 1.0, v + 0.5 * u)     # hands go out to break the fall
			_tq[_arm[k][1]] = _tq[_arm[k][1]].slerp(_rx(-1.1) * _rz(ks * 0.25), reach_down * (1.0 - _dead_w))
		_tq[_chest] = _tq[_chest].slerp(_rx(0.35), kneel)
	# ---- rigor: the pose only moves on in jerks
	_hold_t -= delta
	var kk := 1.0 - exp(-pose_sharpness * delta)
	if stiff > 0.25 and not e.dead:
		if _hold_t <= 0.0:
			_hold_t = lerpf(0.05, 0.22, stiff) * _rng.randf_range(0.6, 1.4)
			for i in _n:
				_hold_q[i] = _tq[i]
		kk = 1.0 - exp(-lerpf(pose_sharpness, 40.0, stiff) * delta)
	else:
		for i in _n:
			_hold_q[i] = _tq[i]

	for i in _n:
		_cq[i] = _cq[i].slerp(_hold_q[i], kk)
		_skel.set_bone_pose_rotation(i, _cq[i])
	_cur_off = _cur_off.lerp(_hips_off, kk)
	_skel.set_bone_pose_position(_hips, _rest_o[_hips] + _cur_off)

	var pitch := PI * 0.5 * smoothstep(0.0, 1.0, v)
	rotation = Vector3(pitch, PI, 0.0)
	# Placed from the pose on screen, so the knees and feet meet the floor exactly.
	# Sink until the lower of knee and foot is on the floor; then pitch forward about the knees, and settle into
	# the lying layout.
	var knee := Vector3.ZERO
	var foot_y := INF
	for k in 2:
		knee += _global(_leg[k][1], _cq).origin * 0.5
		foot_y = minf(foot_y, _global(_leg[k][2], _cq).origin.y)
	var sink := maxf(0.0, minf(knee.y - KNEE_PAD, foot_y - _ankle_y))
	var pos := Vector3(0.0, -sink, 0.0)
	if v > 0.0:
		var flip := Basis(Vector3.UP, PI)
		knee.x = 0.0
		pos += flip * knee - flip * Basis(Vector3.RIGHT, pitch) * knee
	position = pos.lerp(Vector3(0.0, CRAWL_HEIGHT, CRAWL_FORWARD), smoothstep(0.55, 1.0, v))


# ---------------------------------------------------------------------- upright: the shamble
func _pose_walk(e: Enemy, delta: float, speed: float, rt: float, stiff: float, drag: float, blo: float,
		frail: float, stum: float, tgt: Vector3, near: float, reaching: bool) -> void:
	var stride := lerpf(1.15, 0.75, drag) * (1.0 - 0.15 * blo)
	_phase = fposmod(_phase + TAU * speed / stride * delta, TAU)
	var m := _move_w
	var nz := _noise(0.6)
	var th: Array[float] = [0.0, 0.0]
	var crouch := 0.1 + 0.32 * _crouch_w + 0.12 * stum + 0.06 * blo
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var bad := 1.0 if k == _bad else 0.0
		var ph := _phase + k * PI
		# The bad leg swings late and short: it's hauled through, not stepped.
		var sph := ph - 0.6 * bad * drag * maxf(0.0, sin(ph))
		var amp := 0.34 * (1.0 - 0.45 * stiff) * (1.0 - 0.5 * bad * drag) * m
		th[k] = amp * sin(sph)
		var lift := 0.55 * (1.0 - 0.7 * stiff) * (1.0 - 0.85 * bad * drag) * m
		var kn := 0.1 * (1.0 - 0.5 * stiff) + lift * pow(maxf(0.0, cos(sph + 0.2)), 2.0) + 0.5 * _crouch_w + 0.25 * stum * bad
		var wide := sgn * (0.05 + 0.05 * blo)
		_tq[_leg[k][0]] = _rx(-th[k] - crouch) * _rz(wide)
		_tq[_leg[k][1]] = _rx(kn + crouch)
		# Toes scuff along the floor on the bad side.
		_tq[_leg[k][2]] = _rx(-0.5 * kn + 0.55 * bad * drag * m * maxf(0.0, -sin(sph)) + th[k] * 0.3 - 0.4 * _crouch_w) * _rz(-wide)

	# ---- spine: hunched toward the target, lurching over the bad leg, head lolling
	var sn := sin(_phase)
	var cs := cos(_phase)
	var badsgn := 1.0 if _bad == 0 else -1.0
	var hike := 0.07 * drag * m * maxf(0.0, -sin(_phase + _bad * PI))    # hip hitched to swing the bad leg through
	var sway := (0.05 + 0.08 * drag) * cs * m
	var pelvis := 0.1 + 0.05 * _grip_w
	var bend := 0.3 + _hunch + 0.14 * rt - 0.2 * blo + 0.22 * stum + 0.1 * near * (1.0 - stiff) \
		- 0.25 * _crouch_w + 0.55 * _lunge_w - 0.1 * _grip_w + 0.08 * _bite_w
	_tq[_hips] = _ry(-0.08 * sn * m) * _rz(-sway - badsgn * hike) * _rx(pelvis)
	_tq[_chest] = _rx(bend) * _rz(sway * 1.4 + badsgn * 0.08 * drag + 0.05 * nz) * _ry(0.12 * sn * m + 0.08 * nz)
	var loll := 0.06 + 0.3 * rt * (1.0 - stiff)
	# The head juts forward on the neck and tips back to look where he's going.
	_tq[_neck] = _rx(0.35 + 0.15 * rt - 0.15 * near - 0.3 * _crouch_w + 0.2 * _lunge_w + 0.4 * _bite_w) \
		* _rz(_tilt + loll * _noise(0.35)) * _ry(0.15 * loll * _noise(0.27))
	_tq[_head] = _rx(-0.5 - 0.15 * near - 0.15 * _bite_w + 0.25 * frail * (1.0 - near)) * _rz(0.5 * _tilt + 0.3 * _bite_w)
	# Shoulders rolled forward and slumped.
	for k in 2:
		var ks := 1.0 if k == 0 else -1.0
		_tq[_arm[k][0]] = _ry(-ks * (0.18 + 0.1 * rt)) * _rz(-ks * 0.08)

	_hips_off = Vector3(0.0, 0.0, 0.0)
	_hips_off.y = _ankle_y - minf(_global(_leg[0][2]).origin.y, _global(_leg[1][2]).origin.y)
	_hips_off.z = 0.1 * _lunge_w + 0.08 * _bite_w

	# ---- arms
	var cg := _global(_chest)
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var hand := has_hand(k)
		# Hanging: straight down under gravity whatever the spine does, swinging dead and lagging behind the body.
		var swing := 0.5 * th[k] * (1.0 - 0.6 * stiff) + 0.08 * _noise(0.9 + k)
		var dangle := -(pelvis + bend) * (1.0 - 0.5 * stiff)
		var pose: Array[Quaternion] = [
			_rx(dangle + swing + 0.1 * stum) * _rz(-sgn * (0.12 + 0.1 * stiff)),
			Quaternion.IDENTITY,
			_rx(-0.12 - 0.5 * stiff - 0.3 * frail),
			Quaternion.IDENTITY,
			Quaternion.IDENTITY,
		]
		# Reaching: the lead arm when he's near, both if he's a two-arm reacher, both when he grabs.
		var want := 0.0
		if not e.dead and not e.crawling:
			var keen := lerpf(1.0, 0.45, drag) * near
			if k == _lead or _both_arms:
				want = keen
			if reaching:
				want = 1.0
			if e.state == "lunge" or e.state == "lunge_wind":
				want = 0.0
		_reach_w[k] = _ease(_reach_w[k], want, 5.0 if want > _reach_w[k] else 3.0, delta)
		if _reach_w[k] > 0.001:
			var aim := cg * Vector3(sgn * 0.22, 0.25, 0.75)                # out in front, at shoulder height
			if reaching:
				var to := Vector3(tgt.x, clampf(tgt.y, cg.origin.y + 0.05, cg.origin.y + 0.45), tgt.z)
				var sh := cg * Vector3(sgn * 0.2, 0.3, 0.0)
				var d := to - sh
				aim = sh + d.normalized() * minf(d.length(), 0.62) + Vector3(sgn * 0.12, 0.0, 0.0)
			aim += Vector3(0.03 * _noise(1.7 + k), 0.04 * _noise(2.3 + k), 0.0) * (1.0 - _grip_w)
			if not hand:
				aim = aim.lerp(cg * Vector3(sgn * 0.2, 0.3, 0.0), 0.15)
			var rpose := _solve_arm(k, aim, cg.basis * Vector3(sgn * 0.8, -0.6, -0.4), _rx(0.25))
			pose = _blend_arm(pose, rpose, _reach_w[k])
		if _lunge_w > 0.001:
			# Lunging: the arms fly back.
			var lp: Array[Quaternion] = [_rx(0.7) * _rz(-sgn * 0.25), Quaternion.IDENTITY, _rx(-0.4),
				Quaternion.IDENTITY, Quaternion.IDENTITY]
			pose = _blend_arm(pose, lp, _lunge_w)
		for j in 5:
			_tq[_arm[k][j + 1]] = pose[j]
		_pose_fingers(k, stiff)


# ---------------------------------------------------------------------- face down: the crawl
func _pose_crawl(e: Enemy, delta: float, speed: float, rt: float, stiff: float, drag: float, tgt: Vector3,
		reaching: bool) -> void:
	# One pull of each arm moves him about 0.7 m; the worse he is, the more each pull struggles.
	var pull_len := lerpf(0.75, 0.5, drag)
	_crawl_phase = fposmod(_crawl_phase + TAU * maxf(speed, 0.15 * float(e.chasing)) / pull_len * delta, TAU)
	var cp := _crawl_phase
	var heave := sin(cp)                     # which side is pulling
	var strain := 0.5 + 0.5 * drag
	# Spine: chest pushed up off the floor, head lifted to look ahead, the body worming side to side.
	_tq[_hips] = _rz(0.08 * heave * strain) * _ry(0.06 * heave)
	_tq[_chest] = _rx(-0.22 - 0.15 * _bite_w) * _rz(-0.12 * heave * strain) * _ry(-0.1 * heave) * _rx(0.05 * _noise(0.8))
	_tq[_neck] = _rx(-0.55 - 0.2 * _bite_w + 0.2 * rt * (1.0 - stiff)) * _rz(_tilt + 0.15 * _noise(0.4))
	_tq[_head] = _rx(-0.45 + 0.3 * _bite_w)
	_hips_off = Vector3.ZERO
	# Legs: trailing, feet turned soles up. A whole leg pushes now and then, frog-like.
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var push := maxf(0.0, sin(cp + k * PI)) * (1.0 - stiff) * 0.6
		_tq[_leg[k][0]] = _rz(sgn * (0.12 + 0.35 * push)) * _rx(-0.15 * push)
		_tq[_leg[k][1]] = _rx(0.15 + 0.9 * push)
		_tq[_leg[k][2]] = _rx(0.9)
	# Arms: reach ahead along the floor, dig in, haul back to the shoulder, lift and go again.
	var cg := _global(_chest)
	for k in 2:
		var sgn := 1.0 if k == 0 else -1.0
		var ph := fposmod(cp + k * PI, TAU) / TAU          # 0..1 through one pull
		var y_reach := 0.0
		var lift := 0.0
		if ph < 0.6:
			y_reach = lerpf(0.6, 0.05, smoothstep(0.0, 0.6, ph))     # planted, hauling the body up to the hand
		else:
			var u := (ph - 0.6) / 0.4
			y_reach = lerpf(0.05, 0.6, smoothstep(0.0, 1.0, u))      # lifted and thrown forward again
			lift = sin(PI * u)
		# On the floor = toward the model's front (+Z), the floor is about 0.12 m out from the spine.
		var aim := Vector3(sgn * 0.3, cg.origin.y + 0.4 + 0.75 * y_reach, 0.06 - 0.18 * lift)
		if reaching and (k == _lead or _grip_w > 0.5):
			aim = Vector3(clampf(tgt.x, -0.35, 0.35), clampf(tgt.y, cg.origin.y + 0.5, cg.origin.y + 0.9), 0.02)
		var pose := _solve_arm(k, aim, Vector3(sgn * 0.9, 0.0, -0.6), _rx(-0.6))
		for j in 5:
			_tq[_arm[k][j + 1]] = pose[j]
		_pose_fingers(k, stiff)


func _pose_fingers(k: int, stiff: float) -> void:
	# Clawed and twitching; clenched in rigor; closed tight on a grip.
	var curl := 0.55 + 0.12 * _noise(3.1 + k) + 0.35 * stiff
	curl = lerpf(curl, 1.05, _grip_w)
	curl = lerpf(curl, 0.25, _reach_w[k] * (1.0 - _grip_w) * 0.6)
	for fg in _fingers[k]:
		_tq[fg[0]] = Quaternion(fg[1], fg[2] * curl)


# ====================================================================== helpers
## The decay shader lights in view space. The camera never turns, so point its light the same way as the level
## sun as seen from the camera: zombies are lit from the same side as the player and everything else.
func _aim_light_at_sun() -> void:
	if shambler == null:
		return
	for m in shambler.get("_meshes").values():
		_light_material((m as MeshInstance3D).material_override as ShaderMaterial)
		break


func _light_material(mat: ShaderMaterial) -> void:
	if mat == null or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	var suns := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	if cam == null or suns.is_empty():
		return
	var d := (suns[0] as Node3D).global_transform.basis.z.normalized()
	mat.set_shader_parameter("key_dir", (cam.global_transform.basis.inverse() * d).normalized())


## Smooth noise in -1..1 for wobble and loll, different for each zombie.
func _noise(rate: float) -> float:
	var x := _t * rate + _noise_o * rate
	return 0.6 * sin(x * 1.3 + 1.7) + 0.4 * sin(x * 2.9 + 0.3 * _noise_o)


func _ease(cur: float, to: float, sharpness: float, delta: float) -> float:
	return lerpf(cur, to, 1.0 - exp(-sharpness * delta))


func _rx(angle: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, angle)


func _ry(angle: float) -> Quaternion:
	return Quaternion(Vector3.UP, angle)


func _rz(angle: float) -> Quaternion:
	return Quaternion(Vector3.BACK, angle)


# The pose maths below is the same as player_body.gd's (same skeleton).

## Where a bone is in model space under the pose being built (_tq, before smoothing), or under another pose.
func _global(i: int, q: Array[Quaternion] = _tq) -> Transform3D:
	var off := _hips_off if is_same(q, _tq) else _cur_off
	var t := Transform3D(Basis(q[i]), _rest_o[i])
	if i == _hips:
		t.origin += off
	var p := _parent[i]
	while p >= 0:
		var pt := Transform3D(Basis(q[p]), _rest_o[p])
		if p == _hips:
			pt.origin += off
		t = pt * t
		p = _parent[p]
	return t


func _blend_arm(from: Array[Quaternion], to: Array[Quaternion], w: float) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for j in 5:
		out.append(from[j].slerp(to[j], w))
	return out


func _swing_twist(q: Quaternion, axis: Vector3) -> Array[Quaternion]:
	var proj := axis * Vector3(q.x, q.y, q.z).dot(axis)
	var twist := Quaternion(proj.x, proj.y, proj.z, q.w)
	if twist.length_squared() < 0.000001:
		twist = Quaternion.IDENTITY
	else:
		twist = twist.normalized()
	return [q * twist.inverse(), twist]


## Two-bone IK: the wrist of arm k on `target` (model space), the elbow pushed toward `pole`.
func _solve_arm(k: int, target: Vector3, pole: Vector3, hand: Quaternion) -> Array[Quaternion]:
	var ids: Array = _arm[k]
	var cl := _global(ids[0])
	var sh: Vector3 = cl * _rest_o[ids[1]]
	var e0: Vector3 = _rest_o[ids[2]]
	var w0: Vector3 = _rest_o[ids[4]]
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
	var ru := Basis(x1, y1, z1) * rest_frame.transposed()
	var rf := Basis(z1, (ru * w0n).signed_angle_to(fdir, z1)) * ru

	var upper := _swing_twist((cl.basis.inverse() * ru).get_rotation_quaternion(), x0)
	var wristq := _swing_twist(hand, w0n)
	return [upper[0], upper[1], (ru.inverse() * rf).get_rotation_quaternion(),
		wristq[1], wristq[1].inverse() * hand]
