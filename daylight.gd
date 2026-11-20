class_name Daylight
extends Node
## Light and dark. How light it is anywhere is the daylight (the time of day) or a lamp near by, whichever is
## brighter; a gunshot lights whoever fired it for a moment. In the dark you are seen from less far, and you see
## less far yourself; a lit place shows from as far as ever, so a camp with a fire stands out at night and you
## don't.
##
## There is no clock yet, so the time of day is stepped by hand (N in the test level): day, dusk, night, dawn.
## The game's clock is to drive `want` instead. The darkening on screen is drawn by the fog of war's screen quad
## (fog.gd), so it covers everything alike whatever shader a thing uses.

const LAMP_MAX := 8
const TIMES := [["Day", 1.0], ["Dusk", 0.45], ["Night", 0.0], ["Dawn", 0.45]]

static var it: Daylight
## 1 = full day, 0 = the dead of night. Eased toward `want`.
static var level := 1.0
static var want := 1.0
static var time_i := 0
## [{"pos": Vector3, "radius": float}]: fires, lamps. At most LAMP_MAX are drawn (the first ones).
static var lamps: Array[Dictionary] = []

## A torch somebody is carrying: a beam of light from `beam_pos` along `beam_dir` (flat), `beam_range` long and
## `beam_cos` wide (the cosine of half its angle), with a small pool of light round whoever holds it.
static var beam_on := false
static var beam_pos := Vector3.ZERO
static var beam_dir := Vector3.FORWARD
static var beam_range := 16.0
static var beam_cos := 0.92
const BEAM_GLOW := 2.2            # m of light round the holder

@export var change_time := 4.0        # s for the light to change when the time of day is stepped
@export var night_light := 0.08       # how light open ground is in the dead of night (starlight)


static func reset() -> void:
	level = 1.0
	want = 1.0
	time_i = 0
	lamps.clear()
	beam_on = false


func _ready() -> void:
	it = self


func _exit_tree() -> void:
	if it == self:
		it = null


func _process(delta: float) -> void:
	if level != want:
		level = move_toward(level, want, delta / maxf(change_time, 0.1))


## Step to the next time of day (a stand-in for the clock). Returns its name.
static func next_time() -> String:
	time_i = (time_i + 1) % TIMES.size()
	want = float(TIMES[time_i][1])
	return TIMES[time_i][0]


static func time_name() -> String:
	return TIMES[time_i][0]


static func add_lamp(pos: Vector3, radius: float) -> void:
	lamps.append({"pos": pos, "radius": radius})


## How much lamp light falls here, 0 to 1: full near the lamp, fading to nothing at its radius.
static func lamp_light(pos: Vector3) -> float:
	var best := 0.0
	for l in lamps:
		var p: Vector3 = l["pos"]
		var d := Vector2(pos.x - p.x, pos.z - p.z).length()
		var r: float = l["radius"]
		if d < r:
			best = maxf(best, 1.0 - smoothstep(r * 0.35, r, d))
	if beam_on:
		var rel := Vector2(pos.x - beam_pos.x, pos.z - beam_pos.z)
		var bd := rel.length()
		best = maxf(best, 1.0 - smoothstep(BEAM_GLOW * 0.5, BEAM_GLOW, bd))
		if bd > 0.01 and bd < beam_range:
			var along := rel.dot(Vector2(beam_dir.x, beam_dir.z)) / bd
			best = maxf(best, smoothstep(beam_cos, beam_cos + 0.04, along) * (1.0 - smoothstep(beam_range * 0.6, beam_range, bd)))
	return best


## How light it is here, 0 (pitch dark) to 1 (daylight).
static func at(pos: Vector3) -> float:
	var open := lerpf(it.night_light if it != null else 0.08, 1.0, level)
	return maxf(open, lamp_light(pos))


## How far you can see by the daylight alone, as a share of a clear day (the dark closes in at night).
static func sight_share() -> float:
	return lerpf(0.35, 1.0, level)
