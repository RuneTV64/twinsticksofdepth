class_name Campfire
extends Node3D
## A fire you can use: a camp fire, or the fire in a stove (furniture_kit.gd puts one on every stove).
##
##  - A fire burns wood. Put something that burns on it (Items.FUEL: splintered wood, a plank) and light it
##    with a match. It burns its wood down and goes out; feed it to keep it in.
##  - Lit, it boils water (water.gd): with a cooking pot and water in your bottle, interact and stay within
##    reach for Water.BOIL_TIME. Walk off and it comes off the fire unboiled.
##  - `kept` is a fire somebody else keeps in (the test level's camp fires): it is always alight and needs
##    nothing from you. A stand-in until there are people who tend fires.
##
## What it offers goes by what you carry and how the fire stands, one thing at a time: boil, feed, light.
## It only runs (`_process`) while it burns wood or has a pot on it.

signal changed(lit: bool)

const REACH := 2.5
## Lit, with wood on it.
var lit := true
## Seconds of wood left on it.
var fuel := 0.0
## Somebody else keeps it in: always alight, never burns down.
var kept := true

var _player: Player
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	set_process(lit and not kept)


## What you carry that burns, or "".
static func _wood(p: Player) -> String:
	for id: String in Items.FUEL:
		if p.inv.has(id):
			return id
	return ""


func _can_boil(p: Player) -> bool:
	if not lit or _t > 0.0 or not p.inv.has("water"):
		return false
	var item: Dictionary = p.inv.slots[p.inv.find("water")]
	return int(item["uses"]) > 0 and not (item.get("done", []) as Array).has("boiled")


func can_interact(p: Player) -> bool:
	if _can_boil(p):
		return true
	if kept:
		return false
	return _wood(p) != "" or (not lit and (fuel > 0.0 or p.inv.has("matches")))


func interact_point() -> Vector3:
	return global_position


func prompt_text(p: Player) -> String:
	if _can_boil(p):
		return "Boil your water on the fire" if p.inv.tool_for("pot") != "" else "Boil your water (you need a pot or a pan to boil it in)"
	if not lit:
		if fuel <= 0.0 and _wood(p) == "":
			return "A cold hearth: it wants wood"
		if not p.inv.has("matches"):
			return "Lay wood on the hearth" if _wood(p) != "" and fuel <= 0.0 else "Laid and ready: it wants a match"
		return "Light the fire"
	return "Feed the fire"


func interact(p: Player) -> void:
	if _can_boil(p):
		if p.inv.tool_for("pot") == "":
			p.show_status("You have nothing to boil it in. A cooking pot would do.", 2.5)
			return
		_player = p
		_t = Water.BOIL_TIME
		set_process(true)
		p.show_status("Your water is on the fire. Stay by it.", 2.5)
		return
	if kept:
		return
	var wood := _wood(p)
	if not lit and fuel <= 0.0:
		if wood == "":
			p.show_status("There is nothing on it to burn.", 2.0)
			return
		_feed(p, wood)
		if not p.inv.has("matches"):
			p.show_status("You lay the wood. It wants a match.", 2.0)
			return
	if not lit:
		if not p.inv.use("matches"):
			p.show_status("You have nothing to light it with.", 2.0)
			return
		lit = true
		set_process(true)
		changed.emit(true)
		p.recompute_stats()
		p.show_status("It catches.", 2.0)
		return
	if wood != "":
		_feed(p, wood)
		p.show_status("You feed the fire.", 1.5)


func _feed(p: Player, wood: String) -> void:
	p.inv.use(wood)
	fuel += float(Items.FUEL[wood])
	p.recompute_stats()


## How long it will burn as it stands, in words (never a number).
func feel() -> String:
	if not lit:
		return "cold"
	if kept:
		return "burning steadily"
	return "burning low" if fuel < 60.0 else ("burning" if fuel < 300.0 else "burning well")


func _process(delta: float) -> void:
	# Burning its wood down.
	if lit and not kept:
		fuel -= delta
		if fuel <= 0.0:
			fuel = 0.0
			lit = false
			changed.emit(false)
			if _t > 0.0 and is_instance_valid(_player):
				_player.show_status("The fire went out under your water.", 2.5)
			_t = 0.0
	# A pot on it.
	if _t > 0.0:
		if not is_instance_valid(_player) or _player.dead or not _player.inv.has("water"):
			_t = 0.0
		elif _player.global_position.distance_to(global_position) > REACH:
			_t = 0.0
			_player.show_status("You took the water off the fire before it boiled.", 2.0)
		else:
			_t -= delta
			if _t <= 0.0:
				Water.boil(_player.inv.slots[_player.inv.find("water")])
				_player.show_status("It has boiled. Whatever lived in it is dead.", 2.5)
	if _t <= 0.0 and not (lit and not kept):
		set_process(false)
