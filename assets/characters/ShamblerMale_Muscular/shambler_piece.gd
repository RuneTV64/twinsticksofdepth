class_name ShamblerPiece
extends RigidBody3D
## A part that came off a shambler: a forearm and hand, a lower leg and foot, or a head. shambler.gd's dismember()
## makes these. The piece tumbles as one rigid body, while its joints (the wrist and fingers, or the ankle and toes)
## move the way a dead limb's do. It also rots with its own Freshness and then fades away.
##
## How a severed limb moves depends on how long the body has been dead:
##   Fresh    Limp. Nothing holds the joints, so the hand or foot flops at the wrist or ankle under gravity and as the
##            piece swings and lands, and the fingers fall into a loose curl. Freshly cut muscle twitches for a few
##            seconds, the twitches dying away.
##   Rigor    The muscles stiffen. The joints lock where they happen to be and hold that pose through the fall.
##   Bloated, Putrid
##            Loose again once rigor passes, and floppier than fresh: the tissue round the joints is breaking down.
##   Dried    Stiff and leathery: the joints barely move.
## Each joint stays inside a real range: the wrist and ankle swing within a cone, and the fingers, thumb and toes bend
## on their hinges, a little backward and a long way forward; toes are stiffer than fingers. The hand, foot, fingers
## and toes rest on the floor (or whatever the piece lies on) instead of sinking into it. A piece that has come to
## rest stops working it out until something moves it.

## Sent when the piece has rotted to nothing, just before it fades away (or, with auto_fade off, instead of fading).
signal rotted_away(piece: ShamblerPiece)

## Real seconds to rot from fully fresh to nothing. 0: it doesn't rot by itself; change freshness yourself.
@export var rot_seconds := 180.0
## Seconds to fade away once it has rotted.
@export var fade_seconds := 3.0
## Fade away and free itself once rotted. Off: it only sends rotted_away and stays, for the game to deal with.
@export var auto_fade := true
## Seconds the freshly cut muscle twitches. Only when the piece came off a Fresh body.
@export var twitch_seconds := 6.0

var slot := ""
var from_state := ""
var freshness: Freshness
var skeleton: Skeleton3D
var mesh: MeshInstance3D

var _links: Array[Dictionary] = []
var _rest := {}          # bone index -> rest position (piece space)
var _twitch := 0.0
var _fading := -1.0
var _quiet := 0
var _warm := 2   # physics steps the joints ride along rigidly first, so a throw's velocity has reached the body
var _rng := RandomNumberGenerator.new()


## Set up by shambler.gd. `piece` is the imported piece node (its Skeleton3D and mesh); `joints` comes from the piece
## file (its extras), `fresh` is the shambler's Freshness value when the part came off.
func setup(piece: Node3D, joints: Array, fresh: float) -> void:
	skeleton = piece.get_node("Skeleton3D")
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			mesh = c
	freshness = Freshness.new(fresh)
	_twitch = twitch_seconds if freshness.stage() == "Fresh" else 0.0
	_rng.randomize()
	for i in skeleton.get_bone_count():
		_rest[i] = skeleton.get_bone_global_rest(i).origin
	for j in joints:
		var b := skeleton.find_bone(j["bone"])
		var pb := skeleton.get_bone_parent(b)
		if b < 0 or pb < 0:
			continue
		var tip := Vector3(j["tip"][0], j["tip"][1], j["tip"][2])
		var d0: Vector3 = tip - _rest[b]
		var link := {"b": b, "p": pb, "d0": d0.normalized(), "len": d0.length(), "kind": j["kind"],
			"cone": float(j.get("cone", 0.0)), "lo": float(j.get("lo", 0.0)), "hi": float(j.get("hi", 0.0)), "flex": float(j.get("flex", 1.0)),
			"finger": not String(j["bone"]).begins_with("Hand") and not String(j["bone"]).begins_with("Foot"),
			"tone": 0.12 if String(j["bone"]).begins_with("Toe") else 0.0}   # toes are short and stiff: they barely flop
		if j["kind"] == "hinge":
			link["axis"] = Vector3(j["hinge"][0], j["hinge"][1], j["hinge"][2]).normalized()
		_links.append(link)
	_start_points()


## Start fading away now (the lore can call this), whatever its freshness.
func fade_away() -> void:
	if _fading < 0.0:
		_fading = 0.0
		rotted_away.emit(self)


func _start_points() -> void:
	for l in _links:
		var t := _tip_world(l)
		l["pos"] = t
		l["prev"] = t
		l["hold"] = skeleton.get_bone_pose_rotation(l["b"]) * l["d0"]   # the pose rigor will lock


func _tip_world(l: Dictionary) -> Vector3:
	var g := skeleton.get_bone_global_pose(l["b"])
	return skeleton.global_transform * (g * (l["d0"] * l["len"]))


func _process(delta: float) -> void:
	if freshness == null:
		return
	if rot_seconds > 0.0 and freshness.value > 0.0:
		freshness.value -= delta / rot_seconds
		if mesh:
			mesh.set_instance_shader_parameter("freshness", freshness.value)
		if freshness.value <= 0.0:
			if auto_fade:
				fade_away()
			else:
				rotted_away.emit(self)
	if _fading >= 0.0:
		_fading += delta / maxf(fade_seconds, 0.01)
		if mesh:
			mesh.set_instance_shader_parameter("dissolve", minf(_fading, 1.0))
		if _fading >= 1.0 and auto_fade:
			queue_free()


func _physics_process(delta: float) -> void:
	if _links.is_empty() or freshness == null:
		return
	if sleeping and _quiet > 30 and _twitch <= 0.0:
		return   # at rest and settled: nothing to work out until something moves it
	var f := freshness.value
	var dried := 1.0 - smoothstep(0.05, 0.2, f)
	var stiff := maxf(freshness.rigor(), 0.9 * dried)
	var loose := smoothstep(0.68, 0.44, f) * (1.0 - dried)        # rotting tissue: floppier after rigor
	var k := 0.012 + 0.55 * stiff - 0.008 * loose                 # pull toward the held pose (a little tendon tone when limp)
	var damp := 0.05 + 0.2 * stiff + 0.03 * loose
	var follow := clampf((0.45 - stiff) * 6.0 * delta, 0.0, 1.0)  # until rigor sets in, the held pose follows where it lies
	var gravity: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var sk_xf := skeleton.global_transform
	if _warm > 0:   # the hand or foot starts out moving with the rest of the piece, not left behind by a throw
		_warm -= 1
		for l in _links:
			l["pos"] = _tip_world(l)
			l["prev"] = l["pos"] - (linear_velocity + angular_velocity.cross(l["pos"] - global_position)) * delta
		return
	var space := get_world_3d().direct_space_state
	var moved := 0.0
	if _twitch > 0.0:
		_twitch -= delta
	for l in _links:
		var pg := skeleton.get_bone_global_pose(l["p"])
		var joint: Vector3 = sk_xf * (pg * (_rest[l["b"]] - _rest[l["p"]]))
		var rp: Basis = (sk_xf.basis * pg.basis).orthonormalized()
		var w0: Vector3 = rp * l["d0"]
		var cur: Vector3 = (l["pos"] - joint).normalized()
		l["hold"] = (l["hold"] as Vector3).slerp((rp.inverse() * cur).normalized(), follow).normalized()
		# move the segment's end: keep its momentum, let gravity pull it, and the held pose pull it back by k
		var p: Vector3 = l["pos"]
		var v: Vector3 = (p - l["prev"]) * (1.0 - damp)
		l["prev"] = p
		p += v + gravity * delta * delta
		var want: Vector3 = joint + rp * (l["d0"] as Vector3).slerp(l["hold"], stiff) * l["len"]
		p += (want - p) * minf(k + l["tone"] * (1.0 - stiff), 1.0)
		if _twitch > 0.0 and _rng.randf() < 0.05 * (_twitch / twitch_seconds):   # a twitch: the cut muscle firing
			p += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * (0.012 if l["finger"] else 0.025) * (_twitch / twitch_seconds)
		# keep it on the joint, inside the joint's range
		var dir := (p - joint).normalized()
		var q := Quaternion.IDENTITY
		if l["kind"] == "hinge":
			var axis_w: Vector3 = (rp * l["axis"]).normalized()
			dir = (dir - axis_w * dir.dot(axis_w)).normalized()
			var w0p := (w0 - axis_w * w0.dot(axis_w)).normalized()
			var ang: float = w0p.signed_angle_to(dir, axis_w) * l["flex"]
			ang = clampf(ang, l["lo"], l["hi"])
			q = Quaternion(l["axis"], ang * l["flex"])
			dir = rp * (q * l["d0"])
		else:
			var a := w0.angle_to(dir)
			if a > l["cone"]:
				dir = w0.slerp(dir, l["cone"] / a).normalized()
			var local := (rp.inverse() * dir).normalized()
			q = Quaternion(l["d0"], local) if (l["d0"] as Vector3).dot(local) > -0.999 else Quaternion.IDENTITY
		p = joint + dir * l["len"]
		# don't sink into the floor or whatever it lies on: stop the segment where it meets something solid
		var thick := 0.007 if l["finger"] else 0.016
		var ray := PhysicsRayQueryParameters3D.create(joint, joint + dir * (l["len"] + thick), collision_mask, [get_rid()])
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var reach := maxf(joint.distance_to(hit["position"]) - thick, 0.0)
			if reach < l["len"] * 0.98:
				var lift: Vector3 = (hit["normal"] as Vector3).normalized()
				dir = (dir * reach + lift * sqrt(maxf(l["len"] * l["len"] - reach * reach, 0.0))).normalized()   # fold the segment up off the surface
				if l["kind"] == "hinge":
					var axis_h: Vector3 = (rp * l["axis"]).normalized()
					dir = (dir - axis_h * dir.dot(axis_h)).normalized()
					var w0h := (w0 - axis_h * w0.dot(axis_h)).normalized()
					var ah: float = clampf(w0h.signed_angle_to(dir, axis_h) * l["flex"], l["lo"], l["hi"])
					q = Quaternion(l["axis"], ah * l["flex"])
					dir = rp * (q * l["d0"])
				else:
					var lc := (rp.inverse() * dir).normalized()
					q = Quaternion(l["d0"], lc) if (l["d0"] as Vector3).dot(lc) > -0.999 else Quaternion.IDENTITY
				p = joint + dir * l["len"]
				l["prev"] = p   # contact takes the speed out of it
		moved = maxf(moved, p.distance_to(l["pos"]))
		l["pos"] = p
		skeleton.set_bone_pose_rotation(l["b"], q)
	_quiet = _quiet + 1 if moved < 0.0003 else 0
