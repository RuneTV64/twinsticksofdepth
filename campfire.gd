class_name Campfire
extends Node3D
## A fire you can use (water.gd): interact with water in your bottle and it goes on the fire. Stay within
## reach for Water.BOIL_TIME and it has boiled; walk off and it comes off the fire unboiled. It only runs
## while something is on it. (A pot, fuel, lighting and putting out fires come with items.)

const REACH := 2.5
var _player: Player
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	set_process(false)


func can_interact(p: Player) -> bool:
	if _t > 0.0 or not p.inv.has("water"):
		return false
	var item: Dictionary = p.inv.slots[p.inv.find("water")]
	return int(item["uses"]) > 0 and not (item.get("done", []) as Array).has("boiled")


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return "Boil your water on the fire"


func interact(p: Player) -> void:
	_player = p
	_t = Water.BOIL_TIME
	set_process(true)
	p.show_status("Your water is on the fire. Stay by it.", 2.5)


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.dead or not _player.inv.has("water"):
		_t = 0.0
		set_process(false)
		return
	if _player.global_position.distance_to(global_position) > REACH:
		_t = 0.0
		set_process(false)
		_player.show_status("You took the water off the fire before it boiled.", 2.0)
		return
	_t -= delta
	if _t <= 0.0:
		set_process(false)
		Water.boil(_player.inv.slots[_player.inv.find("water")])
		_player.show_status("It has boiled. Whatever lived in it is dead.", 2.5)
