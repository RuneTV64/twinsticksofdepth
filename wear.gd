class_name Wear
extends Node
## Rust and rot (owner, 20 Nov 2026): the slow clock that clears wreckage away, as maggots, flies and worms
## are to clear the dead. One node in the level. Every STEP seconds it tells each wreck how much time has
## passed and how wet it is; nothing runs in between. The game's clock and weather are to drive it; until
## then it uses real seconds and the season's wetness (Seasons).

const STEP := 5.0
## Stand-in for the clock: how much faster than real time rust and rot run. The context menu's Admin submenu jumps ten minutes.
var speed := 1.0
var _t := 0.0


func _ready() -> void:
	add_to_group("weathering")


func _process(delta: float) -> void:
	_t += delta
	if _t >= STEP:
		pass_time(_t * speed)
		_t = 0.0


func pass_time(seconds: float) -> void:
	var wet := Seasons.it.now.y if Seasons.it != null else 0.0
	if Spill.it != null:
		Spill.it.age(seconds, wet)
	for w in Wreck.all.duplicate():
		if is_instance_valid(w):
			w.weather(seconds, wet)
