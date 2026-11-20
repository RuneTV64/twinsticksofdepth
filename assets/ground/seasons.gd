class_name Seasons
extends Node
## The time of year and the weather, as the ground and the grass see them. One node in the level. It keeps the
## project-wide shader value `ground_season` (project.godot, [shader_globals]) up to date:
##   x  time of year: 0 spring, 1 summer, 2 autumn, 3 winter (fractions are in between)
##   y  wetness: 0 bone dry .. 1 raining now
##   z  snow lying: 0 none .. 1 deep
##   w  frost: 0 none .. 1 hard frost
##
## There is no clock yet, so the season is stepped by hand (M in the test level) and rain is switched on and off
## (K). The game's clock and weather are to drive `year`, `raining`, `snow` and `frost` instead; everything
## eases toward what is asked, so a change of season rolls over the ground and doesn't snap.
## Nothing here runs per tick when nothing is changing (the owner's rule for slow things).

const NAMES := ["Spring", "Summer", "Autumn", "Winter"]
## What each season is like when it isn't raining: wetness, snow, frost.
const USUAL := [Vector3(0.35, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3(0.1, 0.45, 0.8)]

static var it: Seasons

## What is asked for.
var year := 1.0
var raining := false
var snow := 0.0
var frost := 0.0
## What it is now (eased toward the above).
var now := Vector4(1.0, 0.0, 0.0, 0.0)

@export var turn_time := 6.0        # s for a season to turn (a stand-in: the clock will take days)
@export var soak_time := 5.0        # s for rain to wet the ground through
@export var dry_time := 40.0        # s for it to dry again once the rain stops


func _ready() -> void:
	it = self
	set_season(1, true)


func _exit_tree() -> void:
	if it == self:
		it = null


func season_index() -> int:
	return posmod(roundi(year), 4)


func season_name() -> String:
	return NAMES[season_index()]


## Go to a season (0 spring .. 3 winter) with its usual weather. `at_once` skips the easing.
func set_season(i: int, at_once := false) -> void:
	i = posmod(i, 4)
	# Always forward through the year: winter to spring goes 3 -> 4, then wraps.
	year = float(i) if at_once or float(i) >= now.x else float(i) + 4.0
	snow = USUAL[i].y
	frost = USUAL[i].z
	if at_once:
		now = Vector4(year, _wet_wanted(), snow, frost)
		_send()
	set_process(true)


func next_season() -> String:
	set_season(season_index() + 1)
	return season_name()


func set_rain(on: bool) -> void:
	raining = on
	set_process(true)


func _wet_wanted() -> float:
	return 1.0 if raining else USUAL[season_index()].x


func _process(delta: float) -> void:
	var wet := _wet_wanted()
	var was := now
	now.x = move_toward(now.x, year, delta / maxf(turn_time, 0.1))
	now.y = move_toward(now.y, wet, delta / (soak_time if wet > now.y else dry_time))
	now.z = move_toward(now.z, snow, delta / maxf(turn_time, 0.1))
	now.w = move_toward(now.w, frost, delta / maxf(turn_time, 0.1))
	if now.x >= 4.0 and year >= 4.0:
		now.x -= 4.0
		year -= 4.0
	if now == was:
		set_process(false)      # settled: nothing to do until something is asked for
		return
	_send()


func _send() -> void:
	RenderingServer.global_shader_parameter_set("ground_season", now)
