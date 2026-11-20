class_name Solid
extends RefCounted
## Builds the solid things of the world, each with what it is made of and the means to break it (breakable.gd).
## Everything that goes into a level is made through here, so nothing can be put in the world that can't be
## broken (owner, 20 Nov 2026). main.gd's _box, _glass and _flat_box call these.
##
##   box    anything standing: a wall piece, a crate, furniture, an appliance, a sign post
##   pane   window glass: stops bodies, not sight; a shot goes through and breaks it
##   boards planks across a window opening
##   slab   a floor or pavement: no collision, worked a square metre at a time
##
## Long walls are cut where they are hit (`_split`), so a blow knocks a hole a person wide, not the whole wall.

const GLASS_LAYER := 16        # physics layer for things that stop bodies but not sight or shots (glass)
const SPLIT_OVER := 1.8        # anything longer than this is cut into sections where it is hit
const MIN_PIECE := 0.6         # a remainder shorter than this goes with the section

## Window openings, for boarding up: {"pos": centre, "size": the opening's size, "level", "pane", "boards"}
static var windows: Array[Dictionary] = []


static func reset() -> void:
	windows.clear()
	Breakable.reset()
	Wreck.reset()


## A solid box. `stuff` is its material; `what` is what the prompt calls it; `parts` (material -> share) is for
## things made of more than one material (an appliance), for what they leave behind.
static func box(level: Node, pos: Vector3, size: Vector3, col: Color, stuff := "brick", what := "wall",
		parts := {}, metal := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.position = pos
	var s := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	s.shape = bs
	b.add_child(s)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = Cutaway.solid(col, metal)   # opens up when it stands between the camera and you
	b.add_child(m)
	level.add_child(b)
	Cover.add_box(b, pos, size)   # anything solid standing on the ground is cover (cover.gd)
	var br := Breakable.attach(b, pos, size, stuff, what)
	br.parts = parts
	br.color = col
	br.on_stage = func(stage: int) -> void: m.material_override = Cutaway.solid(col.darkened(0.14 * stage), metal)
	if maxf(size.x, size.z) > SPLIT_OVER and maxf(size.x, size.z) >= 2.5 * minf(size.x, size.z):
		br.splitter = _split
	return b


## Cut the section round `at` out of something long, as pieces of its own. Returns the section's Breakable.
static func _split(b: Breakable, at: Vector3) -> Breakable:
	var axis := 0 if b.rect.size.x >= b.rect.size.y else 1
	var length: float = b.rect.size[axis]
	var u := clampf((at.x if axis == 0 else at.z) - b.rect.position[axis], 0.0, length) if at.is_finite() else length * 0.5
	var s0 := clampf(u - b.section * 0.5, 0.0, maxf(length - b.section, 0.0))
	var s1 := minf(s0 + b.section, length)
	if s0 < MIN_PIECE:
		s0 = 0.0
	if length - s1 < MIN_PIECE:
		s1 = length
	b.splitter = Callable()
	if s0 <= 0.0 and s1 >= length:
		return b
	var level := b.host.get_parent()
	var share := b.hp / b.max_hp
	var mid_y := (b.foot + b.top) * 0.5
	var out: Breakable = null
	for r: Array in [[0.0, s0], [s0, s1], [s1, length]]:
		if r[1] - r[0] < 0.01:
			continue
		var c: float = b.rect.position[axis] + (r[0] + r[1]) * 0.5
		var across := b.rect.get_center()[1 - axis]
		var pos := Vector3(c, mid_y, across) if axis == 0 else Vector3(across, mid_y, c)
		var size := Vector3(r[1] - r[0], b.top - b.foot, b.rect.size.y) if axis == 0 else Vector3(b.rect.size.x, b.top - b.foot, r[1] - r[0])
		var piece := Breakable.of(box(level, pos, size, b.color, b.stuff, b.title, b.parts))
		piece.hp = piece.max_hp * share
		piece.fixed = b.fixed
		if r[0] == s0:
			piece.splitter = Callable()
			out = piece
	b.hp = 0.0
	b._unindex()
	Cover.remove_box(b.host)
	b.host.queue_free()
	return out


## Window glass across an opening: centre and size of the pane.
static func pane(level: Node, pos: Vector3, size: Vector3) -> Breakable:
	var b := StaticBody3D.new()
	b.collision_layer = GLASS_LAYER
	b.collision_mask = 0
	b.position = pos
	var s := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	s.shape = bs
	b.add_child(s)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.8, 0.95, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(m)
	level.add_child(b)
	var br := Breakable.attach(b, pos, Vector3(maxf(size.x, 0.3), size.y, maxf(size.z, 0.3)), "glass", "window")
	br.barrier = true
	br.lets_shots = true
	br.reindex()
	br.on_stage = func(stage: int) -> void: mat.albedo_color = Color(0.8, 0.88, 0.95, 0.28 + 0.2 * stage)   # crazed
	var thick := Vector3(maxf(size.x, 0.12), size.y, maxf(size.z, 0.12))
	windows.append({"pos": pos, "size": thick, "level": level, "pane": br, "boards": null})
	return br


## The window opening nearest this spot, within `reach`, or an empty Dictionary.
static func window_near(p: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for w in windows:
		var d := Vector2(p.x - w["pos"].x, p.z - w["pos"].z).length()
		if d <= best_d:
			best_d = d
			best = w
	return best


## Board a window up. False if it already is. (What it costs in planks, nails and time comes with the items.)
static func board(w: Dictionary) -> bool:
	if w.is_empty() or (w["boards"] != null and is_instance_valid(w["boards"]) and w["boards"].alive()):
		return false
	var body := box(w["level"], w["pos"], w["size"], Color(0.5, 0.38, 0.24), "wood", "boards")
	var br := Breakable.of(body)
	br.barrier = true
	br.hp = br.max_hp * 0.6          # planks with gaps between, not a solid panel
	br.max_hp = br.hp
	br.salvage_mult = 0.6
	br.reindex()
	w["boards"] = br
	return true


## A floor or pavement: a flat slab with no collision. Broken up a square metre at a time; the holes show the
## ground under it.
static func slab(level: Node, pos: Vector3, size: Vector3, col: Color, stuff: String, what: String) -> Breakable:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(m)
	return surface(m, pos, size, stuff, what)


## Make something flat that is already in the level (`m`) a surface that can be broken up. For a round one,
## set `radius` on what this returns.
static func surface(m: Node3D, pos: Vector3, size: Vector3, stuff: String, what: String) -> Breakable:
	var br := Breakable.attach(m, pos, size, stuff, what)
	br.surface = true
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.2, 0.15, 0.11)
	dirt.roughness = 1.0
	br.on_cell = func(c: Vector2i) -> void:
		var r := Rect2(c.x, c.y, 1.0, 1.0).intersection(br.rect)
		var hole := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(r.size.x, 0.01, r.size.y)
		hole.mesh = hm
		hole.material_override = dirt
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_child(hole)
		hole.global_position = Vector3(r.get_center().x, pos.y + size.y * 0.5 + 0.004, r.get_center().y)
	return br
