class_name TallGrass
extends Node3D
## A patch of tall grass: somewhere to go to ground. Down low in it you are much harder to see (Player.seen_mult):
## flat on the ground most of all, crouched somewhat, standing not at all. It hides nothing from you, and
## nothing else uses it yet (zombies and raiders don't hide in it).
## It is drawn as tall standing grass (assets/ground/grass_blades.gd), which parts round whoever is in it.

static var patches: Array[Rect2] = []

@export var area := Rect2(0, 0, 8, 6)     # on the ground: position (x, z), size (x, z)


static func clear() -> void:
	patches.clear()


## Is this spot in tall grass?
static func at(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for r in patches:
		if r.has_point(p):
			return true
	return false


func _ready() -> void:
	patches.append(area)
	# It stands as real grass (assets/ground: grass_blades.gd), on rough ground if the level has painted ground.
	add_child(GrassBlades.in_rect("tall", area))


func _exit_tree() -> void:
	patches.erase(area)
