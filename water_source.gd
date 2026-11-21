class_name WaterSource
extends Node3D
## Somewhere to fill a bottle (water.gd): a rain barrel, standing water. Interact fills the water bottle you
## carry with that water, as clean or as dirty as it is. A child of the thing that holds the water, so when
## that is broken the water goes with it.

var kind := "rain"


func _ready() -> void:
	add_to_group("interactables")


func can_interact(p: Player) -> bool:
	return p.inv.has("water")


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return "Fill your bottle from the %s" % Water.SOURCES[kind]["name"]


func interact(p: Player) -> void:
	var item: Dictionary = p.inv.slots[p.inv.find("water")]
	Water.fill(item, float(Water.SOURCES[kind]["dirt"]), float(Water.SOURCES[kind]["bugs"]))
	p.show_status("Filled. It looks %s." % Water.look(item), 2.0)
