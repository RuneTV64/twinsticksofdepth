class_name Wreck
extends Node3D
## What is left when something breaks: broken glass, splintered wood, rubble, a wrecked appliance's metal and
## plastic. It stays (owner, 20 Nov 2026), and it is there for a reason:
##   - its materials can be taken, broken as they are (interact: the scrap items in items.gd)
##   - broken glass crunches underfoot: whoever walks on it is heard, and each step grinds it further in
##   - it goes away in the end by rust and rot, the way flesh goes by maggots: wood, cloth and plaster rot,
##     metal rusts (both quicker in the wet), glass is trodden into the dirt, stone and plastic stay until
##     someone takes them. What has rotted or rusted away can no longer be salvaged.
## Nothing here runs per frame: wear.gd steps every wreck on a slow clock, and feet report in when they land.

const CRUNCH := 6.0            # how far glass underfoot is heard (m)
const TREAD := 0.04            # share of the glass one footfall grinds away
const MERGE := 0.8             # wreckage landing this close to more of the same pile joins it

static var all: Array[Wreck] = []
static var glass := 0          # how many have glass in them: feet only ask when this isn't 0

var title := "wreckage"
var spread := 0.6
## material -> {"area": m2 of it that broke, "gone": 0..1 rusted, rotted or trodden away, "taken": items taken}
var lot := {}

var _mm: MultiMeshInstance3D
var _shown := -1


static func reset() -> void:
	all.clear()
	glass = 0


## Leave wreckage at `pos`: `parts` is material -> share, `area` how many square metres of thing broke.
static func leave(level: Node, pos: Vector3, radius: float, parts: Dictionary, area: float, what: String) -> Wreck:
	var w: Wreck = null
	for o in all:
		if is_instance_valid(o) and o.global_position.distance_to(pos) <= MERGE:
			w = o
			break
	if w == null:
		w = Wreck.new()
		w.title = "what is left of the " + what if not what.begins_with("broken") else what
		w.spread = radius
		level.add_child(w)
		w.global_position = Vector3(pos.x, 0.0, pos.z)
	else:
		w.spread = maxf(w.spread, radius)
	for m: String in parts:
		var a := area * float(parts[m])
		if w.lot.has(m):
			var e: Dictionary = w.lot[m]
			e["gone"] = float(e["gone"]) * float(e["area"]) / (float(e["area"]) + a)
			e["area"] = float(e["area"]) + a
		else:
			w.lot[m] = {"area": a, "gone": 0.0, "taken": 0}
			if m == "glass":
				glass += 1
	w._redraw(true)
	return w


func _enter_tree() -> void:
	add_to_group("interactables")
	add_to_group("wreckage")
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)
	if lot.has("glass"):
		glass -= 1


## How many scrap items of this material can still be taken.
func left(m: String) -> int:
	if not lot.has(m):
		return 0
	var e: Dictionary = lot[m]
	var d := Materials.of(m)
	if str(d["scrap"]) == "":
		return 0
	var whole := maxf(float(e["area"]) * float(d["per_m2"]), 1.0)
	return maxi(roundi(whole * (1.0 - float(e["gone"]))) - int(e["taken"]), 0)


## Rust, rot and time: called by Wear on its slow clock. `wet` 0 dry .. 1 raining.
func weather(dt: float, wet: float) -> void:
	for m: String in lot.keys():
		var ag: Dictionary = Materials.AGENTS[Materials.of(m)["agent"]]
		if float(ag["rate"]) > 0.0:
			lot[m]["gone"] = minf(float(lot[m]["gone"]) + float(ag["rate"]) * (1.0 + float(ag["wet"]) * wet) * dt, 1.0)
	_settle()


## A foot lands at `pos`. Glass there crunches (heard `quiet` times as far when going carefully) and is ground
## a little further in. Returns true if it crunched.
static func step_on(pos: Vector3, who: Node, quiet := 1.0) -> bool:
	if glass <= 0:
		return false
	for w in all:
		if w.lot.has("glass") and Vector2(w.global_position.x - pos.x, w.global_position.z - pos.z).length() <= w.spread + 0.25:
			var e: Dictionary = w.lot["glass"]
			e["gone"] = minf(float(e["gone"]) + TREAD, 1.0)
			Earshot.make(pos, CRUNCH * quiet, w.get_tree(), who, who is Player)
			w._settle()
			return true
	return false


## Drop what has gone entirely; go when nothing is left.
func _settle() -> void:
	for m: String in lot.keys():
		var e: Dictionary = lot[m]
		var agent := str(Materials.of(m)["agent"])
		var scrap := str(Materials.of(m)["scrap"])
		if float(e["gone"]) >= 1.0 or (agent == "none" and scrap != "" and left(m) == 0):
			lot.erase(m)
			if m == "glass":
				glass -= 1
	if lot.is_empty():
		queue_free()
		return
	_redraw(false)


func _chunks() -> int:
	var n := 0
	for m: String in lot:
		n += clampi(ceili(float(lot[m]["area"]) * 3.0 * (1.0 - float(lot[m]["gone"]))), 1, 10)
	return n


## The look: a scatter of small bits, coloured by material and darkening as they rust and rot. A stand-in, not
## the 8-shade look. Only rebuilt when the number of bits changes.
func _redraw(force: bool) -> void:
	var n := _chunks()
	if n == _shown and not force:
		return
	_shown = n
	if _mm == null:
		_mm = MultiMeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		_mm.material_override = mat
		_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.06, 0.14)
	mm.mesh = bm
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(global_position.x, global_position.z))
	var i := 0
	for m: String in lot:
		var d := Materials.of(m)
		var gone := float(lot[m]["gone"])
		var col: Color = (d["tint"] as Color).lerp(Materials.AGENTS[d["agent"]]["tint"], gone * 0.8)
		for k in clampi(ceili(float(lot[m]["area"]) * 3.0 * (1.0 - gone)), 1, 10):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * spread
			var s := rng.randf_range(0.6, 1.5) * (1.0 - 0.4 * gone)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s)), Vector3(cos(a) * r, 0.04, sin(a) * r))
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, col.darkened(rng.randf() * 0.2))
			i += 1
	_mm.multimesh = mm


## What it reads as: "splintered wood, rusting scrap metal".
func describe() -> String:
	var out: Array[String] = []
	for m: String in lot:
		var d := Materials.of(m)
		var word := str(Materials.AGENTS[d["agent"]]["word"])
		var nm := Items.name_of(str(d["scrap"])).to_lower() if str(d["scrap"]) != "" else "crumbled " + str(d["name"])
		out.append(("%s %s" % [word, nm]) if word != "" and float(lot[m]["gone"]) > 0.3 else nm)
	return ", ".join(out)


# ---- interactable API ----
func can_interact(_p: Player) -> bool:
	for m: String in lot:
		if left(m) > 0:
			return true
	return false


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return "Pick through %s (%s)" % [title, describe()]


func interact(p: Player) -> void:
	var took := 0
	var full := false
	for m: String in lot.keys():
		var id := str(Materials.of(m)["scrap"])
		for i in left(m):
			if not p.inv.add(Items.make(id)).is_empty():
				full = true
				break
			lot[m]["taken"] = int(lot[m]["taken"]) + 1
			took += 1
	p.recompute_stats()
	if took == 0:
		p.show_status("No room for any of it.", 1.8)
	else:
		p.show_status("Took %d broken piece%s%s." % [took, "" if took == 1 else "s", "; no room for the rest" if full else ""], 2.0)
	_settle()
