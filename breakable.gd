class_name Breakable
extends Node3D
## The part of a thing that can be broken. Everything in the world has one (owner, 20 Nov 2026: "everything in
## the game should be destructible"): walls, doors, windows, furniture, appliances, signs, floors, pavement.
## It is a child of the thing (`host`), knows what the thing is made of (materials.gd), takes blows, and when
## the thing gives way it leaves wreckage (wreck.gd), makes a noise, takes the thing out of the cover system
## and frees it.
##
## Nothing here runs between blows: no _process. Things are found through a grid of 2 m cells (`near()`), so
## zombies, shots and the crosshair don't search the whole level.
##
##   hit(force, kind, at, by)   a blow. kind: blunt, chop, pound, pierce (see Materials). Returns what it did.
##   hits_left(force, kind)     how many such blows it would still take: the measure of "least resistance"
##   weakest(pos, dir, ...)     what a zombie pressed up against something goes for
##   barrier_between(a, b)      the window pane or the boards that stop someone climbing through an opening
##
## A long wall doesn't go all at once: the first blow cuts out the section it landed on (`section` m wide),
## and that section is what breaks (solid.gd does the cutting). A surface (a floor, pavement) is worked a
## square metre at a time and never goes as a whole.

signal broke(by: Node)
signal struck(stage: int)

const CELL := 2.0
const REACH_UP := 1.9            # something whose underside is this far above your feet can't be got at
static var _grid := {}                    # Vector2i -> Array of Breakable
static var barriers: Array[Breakable] = []
static var count := 0

var host: Node3D                 # the thing itself: freed when it breaks (null for a surface)
var title := "wall"              # what the prompt calls it
var stuff := "wood"              # what it is mostly made of: decides how it breaks
var parts := {}                  # material -> share of it, for what is left (default: all `stuff`)
var rect := Rect2()              # its footprint on the ground (x, z)
var foot := 0.0                  # how high its underside is
var top := 0.0
var max_hp := 100.0
var hp := 100.0
var stage := 0                   # 0 sound, 1 damaged, 2 failing
var fixed := false               # the edge of the test map: not part of the world, never breaks
var barrier := false             # fills an opening someone could otherwise climb through (a pane, boards)
var lets_shots := false          # a shot goes through it (and breaks it): glass
var gaps := 0.0                  # the share of it that is air (a rail fence 0.8): it stops bodies, not sight,
                                 # and that share of the shots that cross it go through untouched (Solid.open_up)
var spikes := 0.0                # it has points along its top (a picket fence): the chance a body going over it,
                                 # or thrown onto it, is impaled there (enemy.gd, Impaling; less for the careful)
var thin := 1.0                  # its strength as a share of a solid thing of its size (a fence is not a wall)
var surface := false             # a floor or pavement: worked a square metre at a time
var radius := 0.0                # a round surface: only this far from its middle is really there
var section := 1.2               # how wide a hole a blow knocks in something long
var salvage_mult := 1.0
var color := Color(0.5, 0.5, 0.5)
var floor_y := 0.0               # the height of the floor it stands on (for the cover system)
var look := Callable()           # (stage) -> Material, for things drawn with their own shader (see Solid.box)
var splitter := Callable()       # set by Solid for something long: (breakable, at) -> the Breakable for that section
var on_stage := Callable()       # (stage): the thing shows its damage
var on_cell := Callable()        # (cell: Vector2i): a surface shows a hole

var _cells: Array[Vector2i] = []
var _work := {}                  # surface: Vector2i (1 m cell) -> hp left
var _holes := {}


## Make one for `thing`. `size` is the thing's full size; `pos` its centre.
static func attach(thing: Node3D, pos: Vector3, size: Vector3, material: String, what: String) -> Breakable:
	var b := Breakable.new()
	b.host = thing
	b.stuff = material
	b.title = what
	b.rect = Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z)
	b.foot = pos.y - size.y * 0.5
	b.top = pos.y + size.y * 0.5
	# Strength by its biggest face: a wall panel, a door leaf, a table top.
	var area := maxf(maxf(size.x, size.z) * size.y, size.x * size.z)
	b.max_hp = maxf(float(Materials.of(material)["hp"]) * area, 1.0)
	b.hp = b.max_hp
	thing.add_child(b)
	b.global_position = pos
	thing.set_meta("breakable", b)
	return b


## The Breakable of something a ray or a body ran into, or null.
static func of(body: Object) -> Breakable:
	if body == null or not body.has_meta("breakable"):
		return null
	var b = body.get_meta("breakable")
	return b if is_instance_valid(b) else null


## The nearest thing with spikes that someone with their feet at `feet` is beside or standing on, within
## `radius` of `p` on the map, or null.
static func spiked(p: Vector2, radius: float, feet: float) -> Breakable:
	var best: Breakable = null
	var best_d := radius
	for b in near(p, radius):
		if b.spikes <= 0.0 or b.surface or not b.alive() or b.top < feet - 0.25 or b.foot > feet + 0.5:
			continue
		var d := p.distance_to(Vector2(clampf(p.x, b.rect.position.x, b.rect.end.x), clampf(p.y, b.rect.position.y, b.rect.end.y)))
		if d <= best_d:
			best_d = d
			best = b
	return best


## Make it this much weaker than a solid thing its size (fence boards against a framed wall).
func thin_to(share: float) -> void:
	max_hp = max_hp / thin * share
	hp = hp / thin * share
	thin = share


static func reset() -> void:
	_grid.clear()
	barriers.clear()
	count = 0


func _enter_tree() -> void:
	add_to_group("destructible")
	_index()


func _exit_tree() -> void:
	_unindex()


func _index() -> void:
	_unindex()
	var a := Vector2i((rect.position / CELL).floor())
	var z := Vector2i((rect.end / CELL).floor())
	for x in range(a.x, z.x + 1):
		for y in range(a.y, z.y + 1):
			var c := Vector2i(x, y)
			_cells.append(c)
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append(self)
	count += 1
	if barrier:
		barriers.append(self)


func _unindex() -> void:
	if _cells.is_empty():
		return
	for c in _cells:
		var arr: Array = _grid.get(c, [])
		arr.erase(self)
		if arr.is_empty():
			_grid.erase(c)
	_cells.clear()
	count -= 1
	barriers.erase(self)


## Call after changing `rect` or `barrier` on one already in the tree.
func reindex() -> void:
	if is_inside_tree():
		_index()


## Everything breakable whose footprint comes within `radius` of this spot.
static func near(p: Vector2, radius: float) -> Array[Breakable]:
	var out: Array[Breakable] = []
	var a := Vector2i(((p - Vector2(radius, radius)) / CELL).floor())
	var z := Vector2i(((p + Vector2(radius, radius)) / CELL).floor())
	for x in range(a.x, z.x + 1):
		for y in range(a.y, z.y + 1):
			for b: Breakable in _grid.get(Vector2i(x, y), []):
				if not out.has(b) and b.gap_to(p) <= radius:
					out.append(b)
	return out


## How far this spot is from its footprint (0 inside it).
func gap_to(p: Vector2) -> float:
	var q := p.clamp(rect.position, rect.end)
	return p.distance_to(q)


func alive() -> bool:
	return hp > 0.0 and not is_queued_for_deletion()


## What a blow of this force and kind would do to it.
func dealt(force: float, kind: String) -> float:
	return Materials.dealt(stuff, force, kind)


## How many such blows it would still take. The fewer, the less resistance it offers.
func hits_left(force: float, kind: String) -> float:
	if fixed:
		return INF
	var d := dealt(force, kind)
	var left := hp
	if surface:
		left = float(Materials.of(stuff)["hp"])
	elif splitter.is_valid():
		left = hp * minf(section / maxf(maxf(rect.size.x, rect.size.y), 0.01), 1.0)   # only a section of it has to go
	return left / d if d > 0.0 else INF


## In words, never a number: how this is going to go with what you have in your hands.
func feel(force: float, kind: String) -> String:
	var n := hits_left(force, kind)
	if n <= 2.0:
		return "it will go easily"
	if n <= 10.0:
		return "a few good blows"
	if n <= 40.0:
		return "this will take a while"
	if n <= 200.0:
		return "a long job with this"
	return "you are getting nowhere without the right tool"


## How it looks to be holding up.
func state_word() -> String:
	return ["sound", "damaged", "about to give"][stage]


## A blow. `at` is where it landed (it matters for something long, and for a surface). Returns the damage done.
func hit(force: float, kind: String, at: Vector3, by: Node = null) -> float:
	if fixed or not alive() or not is_inside_tree():
		return 0.0
	if surface:
		return _hit_surface(force, kind, at, by)
	if splitter.is_valid():
		# Something long: cut out the section the blow landed on, and that takes it.
		var part: Breakable = splitter.call(self, at)
		if part != null and part != self:
			return part.hit(force, kind, at, by)
	var d := dealt(force, kind)
	if d <= 0.0:
		return 0.0
	hp -= d
	var m := Materials.of(stuff)
	if hp <= 0.0:
		give_way(by, at)
		return d
	Earshot.make(at, float(m["noise"]), get_tree(), by, by is Player)
	var s := 0 if hp > max_hp * 0.66 else (1 if hp > max_hp * 0.33 else 2)
	if s != stage:
		stage = s
		if on_stage.is_valid():
			on_stage.call(stage)
		struck.emit(stage)
	return d


## It breaks: wreckage where it stood, a noise, out of the cover system, gone.
func give_way(by: Node = null, at := Vector3.INF) -> void:
	if fixed or is_queued_for_deletion():
		return
	hp = 0.0
	var where := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var m := Materials.of(stuff)
	var tree := get_tree()
	var level := host.get_parent() if host != null else get_parent()
	Earshot.make(where if at == Vector3.INF else at, float(m["noise"]) * Materials.BREAK_NOISE, tree, by, by is Player)
	var area := maxf(maxf(rect.size.x, rect.size.y) * (top - foot), rect.size.x * rect.size.y)
	Wreck.leave(level, where, minf(maxf(rect.size.x, rect.size.y) * 0.5, 1.0), _parts(), area * salvage_mult, title)
	broke.emit(by)
	_unindex()
	if host != null:
		Cover.remove_box(host)
		host.queue_free()


func _parts() -> Dictionary:
	return parts if not parts.is_empty() else {stuff: 1.0}


# ---- surfaces: floors and pavement, a square metre at a time ----

func _cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x), floori(at.z))


## Is this spot on it (a round surface is smaller than its footprint)?
func on_it(p: Vector2) -> bool:
	return rect.has_point(p) and (radius <= 0.0 or p.distance_to(rect.get_center()) <= radius)


## Is this square metre of it already broken up?
func holed(at: Vector3) -> bool:
	return _holes.has(_cell_of(at))


func _hit_surface(force: float, kind: String, at: Vector3, by: Node) -> float:
	var c := _cell_of(at)
	if _holes.has(c) or not on_it(Vector2(at.x, at.z)):
		return 0.0
	var d := dealt(force, kind)
	if d <= 0.0:
		return 0.0
	var m := Materials.of(stuff)
	var left: float = float(_work.get(c, float(m["hp"]))) - d
	if left > 0.0:
		_work[c] = left
		Earshot.make(at, float(m["noise"]), get_tree(), by, by is Player)
		return d
	_work.erase(c)
	_holes[c] = true
	var mid := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	Earshot.make(mid, float(m["noise"]) * Materials.BREAK_NOISE, get_tree(), by, by is Player)
	Wreck.leave(host.get_parent(), mid, 0.45, _parts(), salvage_mult, "broken " + str(m["name"]))
	if on_cell.is_valid():
		on_cell.call(c)
	return d


# ---- what zombies and climbers ask ----

## Can someone whose feet are at height `feet` get at it? Not if it is overhead (the wall over a door, the
## storey above) or under the floor they stand on (the basement).
func in_reach(feet: float) -> bool:
	if surface:
		return top >= feet - 0.3 and foot <= feet + 0.3
	return foot <= feet + REACH_UP and top >= feet + 0.2


## What something pressed up against the world at `pos`, facing `dir`, would tear at: of everything breakable
## within `reach` in front of it, the one that will go soonest under blows of this force. Null when there is
## nothing, or nothing it could ever get through.
static func weakest(pos: Vector2, dir: Vector2, reach: float, force: float, kind := "blunt", feet := 0.0) -> Breakable:
	var best: Breakable = null
	var best_n := INF
	for b in near(pos, reach):
		if b.surface or b.fixed or not b.alive() or not b.in_reach(feet):
			continue
		var to := pos.clamp(b.rect.position, b.rect.end) - pos
		if to.length() > 0.05 and to.normalized().dot(dir) < 0.3:
			continue     # beside or behind it
		var n := b.hits_left(force, kind)
		if n < best_n:
			best_n = n
			best = b
	return best


## The pane or boards across the straight line from a to b, if any: what stops a climb through a window.
static func barrier_between(a: Vector2, b: Vector2, feet := 0.0) -> Breakable:
	for x in barriers:
		if x.alive() and x.in_reach(feet) and Cover.crosses(a, b, x.rect.grow(0.05)):
			return x
	return null


## The breakable thing at this spot on the ground for the crosshair: something standing first, then a surface.
static func under(p: Vector2, slack := 0.3, feet := 0.0) -> Breakable:
	var best: Breakable = null
	var best_d := INF
	for b in near(p, slack):
		if b.fixed or not b.alive() or not b.in_reach(feet):
			continue
		var d := b.gap_to(p) + (10.0 if b.surface else 0.0) - (0.5 if b.barrier else 0.0)
		if b.surface and (b.holed(Vector3(p.x, 0.0, p.y)) or not b.on_it(p)):
			continue
		if d < best_d:
			best_d = d
			best = b
	return best
