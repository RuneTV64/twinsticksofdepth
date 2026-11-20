class_name Horde
extends Node
## Where the zombies are, across the whole map, and how they move about it. The map is cut into areas (zones)
## ZONE meters square. Each has zombies you can meet (live ones, in the level) and a reserve: zombies that are
## there but out of play, indoors or out of sight. The number in the world is fixed: nothing here makes zombies
## from nothing.
##
##   noise    every sound warms the area it was made in (Earshot.make). The warmth fades slowly.
##   drawn in a warm area draws zombies: first its own reserve comes out, then the reserves of the areas round it
##            empty toward it. They appear out of your sight, in the area they came from, and walk to the sound. So
##            the more noise you make somewhere, the more of them wander there, and the fewer are left round about.
##   drifting off  a zombie that has gone quiet, far from you and unseen, goes back into the reserve of wherever it
##            has got to. One that wanders off the edge of the map is gone into the next area out.
##   deaths   a zombie killed (or crushed) is gone for good. Nothing respawns.
##
## It runs on a slow clock (every `step` seconds), never per tick.

static var it: Horde

const ZONE := 20.0

@export var start_reserve := 3        # zombies out of play in each area at the start
@export var warm_per_shot := 1.0      # warmth one gunshot (30 m) adds; quieter sounds add less
@export var cool_time := 240.0        # s for one gunshot's warmth to fade
@export var draw_at := 0.8            # warmth at which an area starts drawing zombies
@export var step := 2.0               # s between looks
@export var per_step := 2             # zombies drawn into the warmest areas each look, at most
@export var max_live := 160           # zombies in play at once, at most
@export var keep_clear := 14.0        # m: nothing appears this close to you
@export var quiet_time := 60.0        # s gone quiet, unseen and far off, before one goes back out of play
@export var far := 30.0               # m from you that counts as far off

var player: Player
var zones := {}                       # Vector2i -> {"reserve": int, "warm": float, "at": Vector3}
var drawn := 0                        # zombies brought into play so far
var gone_back := 0                    # ... and put back out of play
var _t := 0.0
var _quiet := {}                      # zombie instance id -> s it has been quiet and far off


func _ready() -> void:
	it = self
	var b := Cover.bounds
	if b.size == Vector2.ZERO:
		return
	for x in range(floori(b.position.x / ZONE), ceili(b.end.x / ZONE)):
		for z in range(floori(b.position.y / ZONE), ceili(b.end.y / ZONE)):
			zones[Vector2i(x, z)] = {"reserve": start_reserve, "warm": 0.0, "at": Vector3.ZERO}


func _exit_tree() -> void:
	if it == self:
		it = null


func zone_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / ZONE), floori(p.z / ZONE))


## A sound was made (from Earshot.make).
func heard(pos: Vector3, radius: float) -> void:
	var k := zone_of(pos)
	if not zones.has(k):
		return
	zones[k]["warm"] = minf(float(zones[k]["warm"]) + warm_per_shot * radius / 30.0, 12.0)
	zones[k]["at"] = pos


## How many zombies are in play.
func live() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).kind == "shambler" and not (e as Enemy).dead:
			n += 1
	return n


## Everything left in the world: in play and out of it.
func total() -> int:
	var n := live()
	for k in zones:
		n += int(zones[k]["reserve"])
	return n


## Put this zombie back out of play, in the area it has got to (or, off the map, into the nearest one).
func absorb(e: Enemy) -> void:
	var k := zone_of(e.global_position)
	if not zones.has(k):
		var best := INF
		for z: Vector2i in zones:
			var d := Vector2((z.x + 0.5) * ZONE - e.global_position.x, (z.y + 0.5) * ZONE - e.global_position.z).length()
			if d < best:
				best = d
				k = z
	zones[k]["reserve"] = int(zones[k]["reserve"]) + 1
	gone_back += 1
	e._gone()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < step or player == null:
		return
	var dt := _t
	_t = 0.0
	# Warmth fades.
	for k in zones:
		zones[k]["warm"] = maxf(float(zones[k]["warm"]) - warm_per_shot / cool_time * dt, 0.0)
	_draw_in()
	_drift_off(dt)


## The warmest areas draw zombies: out of their own reserve first, then out of the fullest area beside them.
func _draw_in() -> void:
	var warm: Array = []
	for k in zones:
		if float(zones[k]["warm"]) >= draw_at:
			warm.append(k)
	if warm.is_empty() or live() >= max_live:
		return
	warm.sort_custom(func(a, b): return float(zones[a]["warm"]) > float(zones[b]["warm"]))
	var left := per_step
	for k: Vector2i in warm:
		if left <= 0:
			return
		# Its own reserve first, then the areas round it, fullest first. An area with nowhere out of your sight
		# to come out of is passed over for the next.
		var sources: Array = []
		if int(zones[k]["reserve"]) > 0:
			sources.append(k)
		var round_it: Array = []
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var n := Vector2i(k.x + dx, k.y + dz)
				if n != k and zones.has(n) and int(zones[n]["reserve"]) > 0:
					round_it.append(n)
		round_it.sort_custom(func(a, b): return int(zones[a]["reserve"]) > int(zones[b]["reserve"]))
		sources.append_array(round_it)
		for from: Vector2i in sources:
			var spot = _free_spot(from)
			if spot == null:
				continue
			zones[from]["reserve"] = int(zones[from]["reserve"]) - 1
			var e := Enemy.new()
			e.kind = "shambler"
			e.position = spot
			get_parent().add_child(e)
			e.player = player
			e.hear_noise(zones[k]["at"], true)
			drawn += 1
			left -= 1
			break


## Somewhere in this area a zombie can appear: open ground, out of your sight, not close to you.
func _free_spot(k: Vector2i):
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1 | 2
	for i in 10:
		var p := Vector3((k.x + randf()) * ZONE, 0.05, (k.y + randf()) * ZONE)
		if not Cover.bounds.grow(-1.5).has_point(Vector2(p.x, p.z)):
			continue
		if p.distance_to(player.global_position) < keep_clear or player.can_see(p):
			continue
		q.position = p + Vector3.UP * 0.9
		if space.intersect_point(q, 1).is_empty():
			return p
	return null


## Zombies that have gone quiet, far from you and out of your sight, go back out of play after a while. Ones that
## have wandered off the map go at once.
func _drift_off(dt: float) -> void:
	var seen := {}
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e.kind != "shambler" or e.dead or e.state != "walk":
			continue
		if not Cover.bounds.grow(-0.5).has_point(Vector2(e.global_position.x, e.global_position.z)):
			absorb(e)
			continue
		if e.chasing or e._drive > 0.0 or player.can_see(e.global_position) \
				or e.global_position.distance_to(player.global_position) < far:
			continue
		var id := e.get_instance_id()
		seen[id] = float(_quiet.get(id, 0.0)) + dt
		if seen[id] >= quiet_time:
			seen.erase(id)
			absorb(e)
	_quiet = seen


## One line per row of areas, for the debug readout: reserve / in play / warmth.
func readout() -> String:
	var in_play := {}
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e.kind == "shambler" and not e.dead:
			var k := zone_of(e.global_position)
			in_play[k] = int(in_play.get(k, 0)) + 1
	var xs := {}
	var zs := {}
	for k: Vector2i in zones:
		xs[k.x] = true
		zs[k.y] = true
	var xl: Array = xs.keys()
	var zl: Array = zs.keys()
	xl.sort()
	zl.sort()
	var t := "HORDE  out of play / in play / warmth   (north at the top; %d left in the world, %d drawn in, %d gone back)\n" % [
		total(), drawn, gone_back]
	for z in zl:
		for x in xl:
			var k := Vector2i(x, z)
			var here: bool = zone_of(player.global_position) == k
			t += "%s%2d/%2d/%3.1f%s " % ["[" if here else " ", int(zones[k]["reserve"]), int(in_play.get(k, 0)), float(zones[k]["warm"]), "]" if here else " "]
		t += "\n"
	return t
