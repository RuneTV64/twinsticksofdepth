class_name Spill
extends Node3D
## Blood on the ground (owner, 21 Nov 2026). A zombie that is hit leaves its blood where it stood; so does a
## raider. It matters to whoever walks through it with an open cut on a bare foot (Player._step_in_it):
##   fresh zombie blood   may infect you as a bite does, and fouls the wound
##   old blood            fouls it badly: almost sure to go bad unless washed at once
## A stain is fresh for FRESH seconds, then old; rain washes stains away, and in the end they dry into the
## dirt. One node in the level. Nothing runs per frame: Wear's slow clock ages them, and feet ask `at()`.

const FRESH := 180.0           # s a stain stays fresh (a stand-in until the game has a clock)
const LAST := 1800.0           # s until it has dried away to nothing
const MERGE := 0.7             # blood landing this close to a stain renews it
const MAX := 160

static var it: Spill
## Each: {"pos": Vector2, "age": s, "zombie": whose blood, "r": radius}
var stains: Array[Dictionary] = []
var _mm: MultiMeshInstance3D


func _enter_tree() -> void:
	it = self


func _exit_tree() -> void:
	if it == self:
		it = null


static func leave(pos: Vector3, zombie: bool, radius := 0.45) -> void:
	if it == null:
		return
	var p := Vector2(pos.x, pos.z)
	for s in it.stains:
		if (s["pos"] as Vector2).distance_to(p) <= MERGE:
			var was_old := float(s["age"]) > FRESH
			s["age"] = 0.0
			s["zombie"] = s["zombie"] or zombie
			s["r"] = minf(float(s["r"]) + 0.05, 0.9)
			if was_old:
				it._redraw()
			return
	if it.stains.size() >= MAX:
		it.stains.pop_front()
	it.stains.append({"pos": p, "age": 0.0, "zombie": zombie, "r": radius})
	it._redraw()


## The stain under this spot, or an empty Dictionary.
static func at(pos: Vector3) -> Dictionary:
	if it == null:
		return {}
	var p := Vector2(pos.x, pos.z)
	for s in it.stains:
		if (s["pos"] as Vector2).distance_to(p) <= float(s["r"]):
			return s
	return {}


static func fresh(stain: Dictionary) -> bool:
	return float(stain["age"]) <= FRESH


## Time passes (Wear's clock). `wet` 0 dry .. 1 raining: rain washes blood away in about a minute.
func age(seconds: float, wet: float) -> void:
	if stains.is_empty():
		return
	var i := 0
	while i < stains.size():
		var s := stains[i]
		s["age"] = float(s["age"]) + seconds * (1.0 + 30.0 * maxf(wet - 0.7, 0.0) / 0.3)
		if float(s["age"]) >= LAST:
			stains.remove_at(i)
		else:
			i += 1
	_redraw()


## The look: flat dark patches, red while fresh and brown-black when old. A stand-in, not the 8-shade look.
func _redraw() -> void:
	if _mm == null:
		_mm = MultiMeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.6
		_mm.material_override = mat
		_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var pm := CylinderMesh.new()
	pm.top_radius = 1.0
	pm.bottom_radius = 1.0
	pm.height = 0.01
	pm.radial_segments = 8
	mm.mesh = pm
	mm.instance_count = stains.size()
	for i in stains.size():
		var s := stains[i]
		var r := float(s["r"])
		var p: Vector2 = s["pos"]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(r, 1.0, r)), Vector3(p.x, 0.035, p.y)))
		mm.set_instance_color(i, Color(0.42, 0.04, 0.04) if fresh(s) else Color(0.13, 0.06, 0.04))
	_mm.multimesh = mm
