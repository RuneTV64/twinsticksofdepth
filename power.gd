class_name Power
extends RefCounted
## Mains power: a stand-in until there is a grid to lose (owner, 21 Nov 2026: the living room's appliances). It
## is on when the game starts and stays on; Shift+N cuts it, and brings it back, by hand until the clock and
## the world decide when the grid goes down. The phone lines go with it.
##
## What runs on it: every building's sockets (an appliance plugged in indoors: appliance.gd), and the street
## lamps (street_kit.gd). Outdoors there is no socket. Batteries don't care (a portable radio, a torch).
##
## Nothing here runs between changes: what wants to know watches (`watch`) and is told once.

static var on := true
static var _watchers: Array[Callable] = []


static func reset() -> void:
	on = true
	_watchers.clear()


## Tell `c` (a func(bool)) whenever the power goes off or comes back. It is dropped once its object is gone.
static func watch(c: Callable) -> void:
	_watchers.append(c)


static func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	var keep: Array[Callable] = []
	for c in _watchers:
		if c.is_valid():
			keep.append(c)
			c.call(v)
	_watchers = keep


## Is there a socket here: inside a building (Cutaway knows every building's footprint).
static func indoors(p: Vector3) -> bool:
	return not Cutaway.building_at(p).is_empty()


## Does something plugged in here get power?
static func at(p: Vector3) -> bool:
	return on and indoors(p)
