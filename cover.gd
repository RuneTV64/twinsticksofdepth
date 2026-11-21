class_name Cover
extends RefCounted
## The level's cover, worked out from its boxes. Nothing is placed by hand: every solid box that stands on the
## ground (main.gd's _box) is registered here, and each of its long sides becomes a cover face.
##   low cover   top no higher than LOW_TOP (crates, window sills, cars): you crouch behind it, and can stand up
##               over it, peek over it, lean round its ends, or vault it
##   high cover  anything taller (walls, pillars): you stand flat against it and lean round its ends
## A face runs from a to b along dir (always toward +X or +Z), with n pointing out of the box at whoever is
## using it. A place on a face is t meters from a. Everything here is flat (XZ), as Vector2(x, z).
##
## The Player uses this now; raiders and other players are meant to use the same faces and the same rules.
##
## Floors: every box stands on a floor (`base`, the height of that floor: 0 the ground, 2.7 upstairs, -2.7 a
## basement) and is cover only for someone standing on that floor (`on(feet)`). `top` is how high the thing
## stands above its own floor. Everything that looks cover up says how high its feet are.

const MIN_TOP := 0.75      # shorter than this hides nobody
const LOW_TOP := 1.5       # tops up to here are low cover
const MIN_LEN := 0.6       # a side shorter than this is not a face (the ends of walls)
const STANDOFF := 0.48     # how far out from a face its user's centre is
const END_MARGIN := 0.3    # how close to a free end a user's centre can get
const CLEAR := 0.33        # a spot this close to another box has no room to stand in
const SAME_FLOOR := 0.7    # feet within this of a box's base are on its floor
const HEAD := 0.9          # how high the head of someone hunkered is


class Box:
	var rect: Rect2        # footprint: position (x, z), size (x, z)
	var base := 0.0        # the height of the floor it stands on
	var top := 0.0         # how high it stands above that floor
	var low := false
	var body: Object
	var gone := false      # it was broken: whoever was using it has to let go

	## Is someone whose feet are at this height on the floor this stands on?
	func on(feet: float) -> bool:
		return absf(feet - base) < SAME_FLOOR


class Face:
	var a := Vector2.ZERO
	var dir := Vector2.RIGHT
	var n := Vector2.UP
	var length := 0.0
	var depth := 0.0       # how thick the box is behind this face
	var box: Box
	var low := false
	var top := 0.0
	var base := 0.0
	# Worked out the first time the face is used, and again after the level changes (see prep):
	var ready := -1
	var next: Array = [null, null]      # the face that carries on past each end, if any
	var open: Array = [false, false]    # can you lean out round each end
	var t_min := 0.0                    # how far along it a user can go
	var t_max := 0.0


static var boxes: Array[Box] = []
static var faces: Array[Face] = []
static var by_body := {}          # a box's body (instance id) -> its Box, for whoever walks into it
static var bounds := Rect2()      # the playable area (XZ); nothing climbs out of it. Empty = no limit
static var version := 0           # goes up whenever a box is added or removed: faces work their ends out again


static func clear() -> void:
	boxes.clear()
	faces.clear()
	by_body.clear()
	bounds = Rect2()


## The box this body is, or null (doors, and boxes off the ground, aren't registered).
static func box_of(body: Object) -> Box:
	return by_body.get(body.get_instance_id()) if body != null else null


## Register a solid box: centre and size as built, and the height of the floor it stands on. Boxes off their
## floor (the wall over a window) and ones too low to hide behind are ignored. Low ones are marked on their
## body so shots know to pass over them.
static func add_box(body: Object, pos: Vector3, size: Vector3, floor_y := 0.0) -> void:
	var top := pos.y + size.y * 0.5 - floor_y
	if pos.y - size.y * 0.5 - floor_y > 0.3 or top < MIN_TOP:
		return
	var b := Box.new()
	b.rect = Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z)
	b.base = floor_y
	b.top = top
	b.low = top <= LOW_TOP
	b.body = body
	boxes.append(b)
	version += 1
	if body != null:
		by_body[body.get_instance_id()] = b
	if b.low and body != null:
		body.set_meta("cover_low", true)
	var x0 := b.rect.position.x
	var z0 := b.rect.position.y
	var x1 := b.rect.end.x
	var z1 := b.rect.end.y
	_add_face(b, Vector2(x0, z0), Vector2.RIGHT, size.x, Vector2(0, -1), size.z)   # north side
	_add_face(b, Vector2(x0, z1), Vector2.RIGHT, size.x, Vector2(0, 1), size.z)    # south side
	_add_face(b, Vector2(x0, z0), Vector2.DOWN, size.z, Vector2(-1, 0), size.x)    # west side
	_add_face(b, Vector2(x1, z0), Vector2.DOWN, size.z, Vector2(1, 0), size.x)     # east side


## Something solid was broken or taken away: its box and faces go, and anyone using them is told by `gone`.
static func remove_box(body: Object) -> void:
	var b := box_of(body)
	if b == null:
		return
	b.gone = true
	by_body.erase(body.get_instance_id())
	boxes.erase(b)
	faces = faces.filter(func(f: Face) -> bool: return f.box != b)
	version += 1


static func _add_face(b: Box, a: Vector2, dir: Vector2, length: float, n: Vector2, depth: float) -> void:
	if length < MIN_LEN:
		return
	var f := Face.new()
	f.a = a
	f.dir = dir
	f.n = n
	f.length = length
	f.depth = depth
	f.box = b
	f.low = b.low
	f.top = b.top
	f.base = b.base
	faces.append(f)


## Where someone using this face stands, t meters along it.
static func spot(f: Face, t: float) -> Vector2:
	return f.a + f.dir * t + f.n * STANDOFF


## Work out a face's ends, once: what carries on past them, whether you can lean round them, how far you can go.
## Done on first use, so the whole level is registered by then.
static func prep(f: Face) -> void:
	if f.ready == version:
		return
	f.ready = version
	for end in 2:
		var nb := _neighbor(f, end)
		f.next[end] = nb
		if nb != null:
			# Beside a window: a high wall with a low one carrying on. You can lean out over the sill.
			f.open[end] = nb.low and not f.low
		else:
			# A free end, if there is room to step out round it.
			f.open[end] = has_room(spot(f, f.length + 0.5 if end == 1 else -0.5), null, f.base)
	f.t_min = 0.0 if f.next[0] != null else END_MARGIN
	f.t_max = f.length if f.next[1] != null else f.length - END_MARGIN
	if f.t_max < f.t_min:
		f.t_min = f.length * 0.5
		f.t_max = f.t_min


## The face that carries on from this one in a straight line (walls are built in pieces): end 0 is a, end 1 is b.
static func _neighbor(f: Face, end: int) -> Face:
	var corner := f.a + f.dir * f.length if end == 1 else f.a
	for o in faces:
		if o == f or absf(o.base - f.base) > 0.1 or o.n.dot(f.n) < 0.99 or absf((o.a - f.a).dot(f.n)) > 0.12:
			continue
		var other_end := o.a if end == 1 else o.a + o.dir * o.length
		if absf((other_end - corner).dot(f.dir)) < 0.15:
			return o
	return null


## Is there room to stand here? Not inside, or right against, any box but `skip`. `feet` is the floor asked
## about; left out, it is the floor `skip` stands on (or the ground).
static func has_room(p: Vector2, skip: Box, feet := NAN) -> bool:
	if is_nan(feet):
		feet = skip.base if skip != null else 0.0
	for b in boxes:
		if b != skip and b.on(feet) and b.rect.grow(CLEAR).has_point(p):
			return false
	return true


## Does the straight line from p to q pass through this footprint?
static func crosses(p: Vector2, q: Vector2, r: Rect2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := q - p
	for axis in 2:
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(d[axis]) < 0.000001:
			if p[axis] < lo or p[axis] > hi:
				return false
			continue
		var ta: float = (lo - p[axis]) / d[axis]
		var tb: float = (hi - p[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return false
	return true


## Is someone at `at`, using face f, behind their cover as seen from `from`? True when the line between them
## passes through the cover. From the side or from behind them it isn't, and the cover does nothing.
## `rise` is how high the looker (or the gun) is above the floor the cover stands on. From no higher than the
## cover's top it is simply in the way. From higher, the line comes down over it: it still hides someone
## hunkered if the line passes under its top where it crosses the cover's near face, and not otherwise. So the
## higher and the closer the looker, the less low cover is worth; a wall is worth as much as ever.
static func shields(f: Face, at: Vector2, from: Vector2, rise := 0.0) -> bool:
	if not ((from - f.a).dot(f.n) < 0.0 and crosses(from, at, f.box.rect)):
		return false
	if rise <= f.top:
		return true
	var head := minf(HEAD, f.top - 0.2)
	return head + (rise - head) / maxf(from.distance_to(at), 0.1) * STANDOFF < f.top


## The best cover to slide into from `pos`: within `reach`, on the side you're on, with room to stand. `want`
## (a direction, or zero) favours cover that way. Returns {"face", "t"} or an empty Dictionary.
static func find_near(pos: Vector2, reach: float, want: Vector2, feet := 0.0) -> Dictionary:
	var best := {}
	var best_score := INF
	for f in faces:
		if absf(f.base - feet) >= SAME_FLOOR:
			continue
		var side := (pos - f.a).dot(f.n)
		var along := (pos - f.a).dot(f.dir)
		if side < -0.05 or side > reach + STANDOFF or along < -reach or along > f.length + reach:
			continue
		prep(f)
		var t := clampf(along, f.t_min, f.t_max)
		var sp := spot(f, t)
		var d := pos.distance_to(sp)
		if d > reach or not has_room(sp, f.box):
			continue
		var score := d
		if d > 0.3 and want.length() > 0.1:
			score *= 1.0 - 0.5 * want.normalized().dot((sp - pos) / d)
		if score < best_score:
			best_score = score
			best = {"face": f, "t": t}
	return best


## The cover spot the crosshair at `aim` is pointing out, for someone at `from`: the face within `radius` of the
## crosshair, on the side the crosshair is on. With the crosshair on top of the cover, or just past a wall, the
## side nearer to `from` wins. Returns {"face", "t"} or an empty Dictionary.
static func find_aim(aim: Vector2, from: Vector2, radius: float, feet := 0.0) -> Dictionary:
	var best := {}
	var best_score := INF
	for f in faces:
		if absf(f.base - feet) >= SAME_FLOOR:
			continue
		var along := (aim - f.a).dot(f.dir)
		if along < -radius or along > f.length + radius:
			continue
		var side := (aim - f.a).dot(f.n)
		if absf(side) > radius:
			continue
		prep(f)
		var t := clampf(along, f.t_min, f.t_max)
		var on_face := f.a + f.dir * clampf(along, 0.0, f.length)
		var d := aim.distance_to(on_face)
		if d > radius:
			continue
		var sp := spot(f, t)
		if not has_room(sp, f.box):
			continue
		var score := d
		if side < 0.0:
			score = radius + from.distance_to(sp) * 0.01     # crosshair is on or behind the cover
		elif crosses(from, sp, f.box.rect):
			score += 0.6                                       # the far side: only when clearly aimed past it
		if score < best_score:
			best_score = score
			best = {"face": f, "t": t}
	return best
