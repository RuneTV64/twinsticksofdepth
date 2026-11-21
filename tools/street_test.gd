extends SceneTree
## Headless test of the street kit (assets/buildings/street) in the real level: its shapes, what the ground
## under it does to whoever walks on it, and breaking it up. Run from a scratch copy (copy this file to its
## root):
##   godot --headless --fixed-fps 60 -s res://street_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[street] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## Walk the player in a straight line for `secs`, and say how many new prints were left and how fast it went.
func _walk(from: Vector3, dir: Vector3, secs: float) -> Array:
	p.global_position = from
	p.velocity = Vector3.ZERO
	await _wait(0.2)
	var n0 := Ground.it.trail_first + Ground.it.trail.size()
	var at0 := p.global_position
	Input.action_press("move_up" if dir.z < 0.0 else "move_down")
	var t := 0.0
	while t < secs:
		# (The keys go by the screen, which is turned 45 degrees: push the body along instead.)
		p.global_position += dir * 2.0 / 60.0 * Ground.it.slow_at(p.global_position)
		p._update_ground()
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release("move_up")
	Input.action_release("move_down")
	var gone := p.global_position - at0
	gone.y = 0.0
	return [Ground.it.trail_first + Ground.it.trail.size() - n0, gone.length() / secs]


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	p.invulnerable = true
	p.set_physics_process(false)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.2)
	# ---- its shapes
	var s := StreetKit.new(main, Vector3(200, 0, 200))
	s.plan([" # # ", "#####", " #  #", " ####"])
	var names := {}
	for cell: Vector2i in s.cells:
		var l := s.links_of(cell)
		var n := int(l & 1 != 0) + int(l & 2 != 0) + int(l & 4 != 0) + int(l & 8 != 0)
		var straight := l == 5 or l == 10
		var what: String = ["island", "dead end", "straight" if straight else "bend", "T junction", "crossroads"][n]
		names[what] = int(names.get(what, 0)) + 1
	_say("a plan of %d cells works itself out as: %s" % [s.cells.size(), names])
	var streets := 0
	for b: Breakable in get_nodes_in_group("destructible"):
		if b.title == "street":
			streets += 1
	_say("in the level: %d street tiles, %d breakable things in all" % [streets, Breakable.count])
	# A straight tile of the level's street: x from -5 to 4, its middle at -0.5.
	var across := []
	for x: float in [-0.5, 2.0, 2.56, 3.2, 4.2, 5.0]:
		var b := Breakable.under(Vector2(x, -62.5))
		across.append("%.1f m: %s, ground %s" % [x + 0.5, b.title if b != null else "nothing", Ground.it.kind_at(Vector3(x, 0, -62.5))])
	_say("across the street from its middle: %s" % "; ".join(across))
	# The head of a dead end: its corners are not street.
	var corner := Breakable.under(Vector2(-13.5, -84.5))
	_say("the outer corner of the west dead end's tile: %s, ground %s" % ["street" if corner != null and corner.title == "street" else "not street", Ground.it.kind_at(Vector3(-13.5, 0, -84.5))])
	# ---- firm in all weather, and no prints
	for wx: Array in [["dry summer", 1, false, 0.0], ["rain", 1, true, 0.0], ["lying snow", 3, false, 0.6]]:
		Seasons.it.set_season(wx[1], true)
		Seasons.it.now.y = 1.0 if wx[2] else 0.0
		Seasons.it.now.z = wx[3]
		Ground.it.clear_tracks()
		var on: Array = await _walk(Vector3(-0.5, 0.05, -50.0), Vector3(0, 0, -1), 5.0)
		var soil := Vector3(-22.0, 0.05, -66.0)
		var off: Array = await _walk(soil, Vector3(0, 0, -1), 5.0)
		_say("%s: on the street, softness %.2f, %d prints in 10 m; on bare ground beside it (%s), softness %.2f, %d prints" % [
			wx[0], Ground.it.softness(Vector3(-0.5, 0, -52.0)), on[0], Ground.it.kind_at(soil), Ground.it.softness(soil), off[0]])
	Seasons.it.set_season(1, true)
	Seasons.it.now.y = 0.0
	Seasons.it.now.z = 0.0
	# ---- breaking it up
	var road := Breakable.under(Vector2(0.5, -51.5))
	var out := []
	var holder := Node3D.new()
	main.add_child(holder)
	for wear in 3:
		var k := StreetKit.new(holder, Vector3(300 + wear * 20, 0, 300), wear)
		k.add([Vector2i(0, 0)])
		k.open(Vector2i(0, 0), "N")
		k.open(Vector2i(0, 0), "S")
		k.build()
		out.append("%.0f" % ceilf(k.parts[0].hits_left(p.break_sledge, "pound")))
	_say("a square metre, laid sound, cracked, breaking up: %s sledgehammer blows; fists: %s; the level's street is laid cracked" % [", ".join(out), road.feel(p.break_fist, "blunt")])
	var n := 0
	while not road.holed(Vector3(0.5, 0, -51.5)) and n < 100:
		road.hit(p.break_sledge, "pound", Vector3(0.5, 0, -51.5), p)
		n += 1
	var rocks := 0
	for w in Wreck.all:
		if is_instance_valid(w) and w.global_position.distance_to(Vector3(0.5, 0, -51.5)) < 1.5:
			for m: String in w.lot:
				rocks += w.left(m)
	var tile: MeshInstance3D = road.host
	var hm: ShaderMaterial = tile.material_override
	_say("broken up in %d blows: the tile's hole map is %s (it has its own material now: %s); what is left: %d rock(s); the crosshair there finds %s; the ground in the hole is %s" % [
		n, hm.get_shader_parameter("holes"), hm != StreetKit.mat(s.links_of(Vector2i(0, 0)), 1), rocks, Breakable.under(Vector2(0.5, -51.5)), Ground.it.kind_at(Vector3(0.5, 0, -51.5))])
	quit()
