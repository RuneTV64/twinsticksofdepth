class_name Thrown
extends Node3D
## Something thrown (a rock, a bottle, a book, a record): it arcs from the hand to where it was aimed and makes a noise where it
## lands. Zombies go to the noise; raiders go to look. A rock can be picked up again; a bottle breaks.

## What it is, how it looks and how loud it lands are the item's own `throw` record (items.gd): a rock and a book
## lie where they land to be picked up again; a bottle breaks.

var item := "rock"
var from := Vector3.ZERO
var to := Vector3.ZERO
var peak := 2.0              # how high the arc goes above the straight line
var flight := 0.8
var thrower: Node = null
var _t := 0.0
## Thrown at something above head height (Player.aim_high: an upstairs window, a wall, a roof): `to` is the
## spot on it. Glass it breaks and goes through, to land on the floor inside; anything else it strikes and
## drops from, to the ground at its foot.
var at_thing: Breakable = null
var _high := false               # it was thrown at something (asked once: the thing may be gone by the time it lands)
var _second := false             # on its way down after reaching what it was thrown at
var _pane: Breakable = null      # a window in the way: it goes through it
var _pane_u := 0.0


func _ready() -> void:
	var look: Array = _rec().get("look", [[0.12, 0.1, 0.12], "stone"])
	var sz: Array = look[0]
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(sz[0], sz[1], sz[2])
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Clothes.ink(str(look[1]))
	m.material_override = mat
	add_child(m)
	global_position = from
	_high = at_thing != null
	# Glass between the hand and where it is going breaks as the thing passes.
	var p0 := Vector2(from.x, from.z)
	var p1 := Vector2(to.x, to.z)
	_pane = Breakable.barrier_between(p0, p1)
	if _pane != null and _pane.lets_shots:
		_pane_u = clampf((_pane.rect.get_center() - p0).dot(p1 - p0) / maxf((p1 - p0).length_squared(), 0.0001), 0.0, 1.0)
	else:
		_pane = null


func _process(delta: float) -> void:
	_t += delta
	var u := clampf(_t / maxf(flight, 0.05), 0.0, 1.0)
	global_position = from.lerp(to, u) + Vector3.UP * (4.0 * peak * u * (1.0 - u))
	rotation += Vector3(7.0, 3.0, 5.0) * delta
	if _pane != null and u >= _pane_u:
		if is_instance_valid(_pane) and global_position.y >= _pane.foot and global_position.y <= _pane.top:
			_pane.hit(15.0, "blunt", global_position, thrower)
		_pane = null
	if u >= 1.0:
		if _high and not _second:
			_strike()
		else:
			_land()


## It has reached what it was thrown at. Through glass and on to the floor beyond; off anything else and down.
func _strike() -> void:
	_second = true
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var through := false
	if is_instance_valid(at_thing) and at_thing.alive():
		through = at_thing.lets_shots
		at_thing.hit(15.0, "blunt", to, thrower)
		through = through and not (is_instance_valid(at_thing) and at_thing.alive())
	var over := to + along * (1.1 if through else -0.45)
	var down := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * 12.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(down)
	from = to
	to = hit["position"] if not hit.is_empty() else Vector3(over.x, 0.05, over.z)
	peak = 0.1
	flight = clampf(sqrt(maxf(from.y - to.y, 0.2) / 4.9), 0.2, 1.2)      # the time a drop of that height takes
	_t = 0.0


func _rec() -> Dictionary:
	return Items.DEFS[item].get("throw", {})


func _land() -> void:
	var rec := _rec()
	Earshot.make(to, float(rec.get("noise", 9.0)), get_tree(), thrower, true)
	if int(rec.get("shards", 0)) > 0:
		# It smashes, and its pieces lie where it landed: broken glass, as good as a trap laid by hand.
		var n := int(rec["shards"])
		Wreck.leave(get_parent(), Vector3(to.x, to.y if _second else 0.0, to.z), 0.5, {"glass": 1.0},
			n / float(Materials.of("glass")["per_m2"]), "broken glass")
	if bool(rec.get("keep", false)):
		var p := ItemPickup.new()
		p.title = Items.name_of(item)
		p.small = true
		p.tint = Clothes.ink(str((rec.get("look", [[], "stone"]) as Array)[1]))
		p.contents = [Items.make(item)]
		p.position = Vector3(to.x, to.y if _second else 0.0, to.z)      # (upstairs, if it went in at a window)
		get_parent().add_child(p)
	queue_free()
