class_name Freshness
extends Resource
## How far something has gone off: 1.0 = just turned (or just made), 0.0 = as far gone as it gets.
## Shared by anything that rots. Shamblers use it now; food can carry the same status later with its own
## stage names and its own speed. It's a Resource, so it saves with whatever carries it.
##
##   var f := Freshness.new(0.9)                       # a corpse, Fresh
##   var bread := Freshness.new(1.0, Freshness.FOOD, 72.0)   # food that goes off over 72 game hours
##   bread.age(hours)   ->  bread.stage() == "Stale" ...

## Emitted when the value crosses into another stage.
signal stage_changed(stage: String)

## Corpse stages, freshest first: [name, lowest value still in that stage].
## These match the stage borders in zombie_decay.gdshader.
const CORPSE := [["Fresh", 0.88], ["Rigor", 0.68], ["Bloated", 0.44], ["Putrid", 0.2], ["Dried", 0.0]]
## Food stages, ready for when food uses this.
const FOOD := [["Fresh", 0.75], ["Stale", 0.5], ["Spoiled", 0.25], ["Rotten", 0.0]]

@export_range(0.0, 1.0) var value := 1.0: set = set_value
## Game hours to go all the way from 1.0 to 0.0 when age() is called. 0 = it never changes on its own.
@export var hours_to_rot := 0.0
## Which stage names this thing uses (CORPSE, FOOD, or your own list in the same shape).
@export var stages: Array = CORPSE


func _init(start := 1.0, stage_list: Array = CORPSE, hours := 0.0) -> void:
	stages = stage_list
	hours_to_rot = hours
	value = start


func set_value(v: float) -> void:
	var before := stage() if not stages.is_empty() else ""
	value = clampf(v, 0.0, 1.0)
	emit_changed()
	var now := stage()
	if now != before and before != "":
		stage_changed.emit(now)


## The stage name for the current value, e.g. "Rigor".
func stage() -> String:
	return stages[stage_index()][0]


## 0 for the freshest stage, counting up as it rots.
func stage_index() -> int:
	for i in stages.size():
		if value >= stages[i][1]:
			return i
	return stages.size() - 1


## Let game time pass. Does nothing while hours_to_rot is 0.
func age(hours: float) -> void:
	if hours_to_rot > 0.0:
		value = value - hours / hours_to_rot


## Rigor mortis, for corpses: 0 = loose, 1 = fully stiff. It sets in soon after death, is at its worst through
## the Rigor stage, then passes off as the muscles break down. Use it for stiff, jerky movement.
func rigor() -> float:
	var d := 1.0 - value
	return smoothstep(0.02, 0.14, d) * (1.0 - smoothstep(0.26, 0.4, d))


## A random value, picking a stage by weight first, then a spot inside that stage.
## weights: {"Fresh": 1, "Bloated": 3, ...}; stages left out are never picked. Empty = any value.
static func roll(rng: RandomNumberGenerator, weights: Dictionary, stage_list: Array = CORPSE) -> float:
	var total := 0.0
	for s in stage_list:
		total += float(weights.get(s[0], 0.0))
	if total <= 0.0:
		return rng.randf()
	var r := rng.randf() * total
	for i in stage_list.size():
		var w := float(weights.get(stage_list[i][0], 0.0))
		if w <= 0.0:
			continue
		r -= w
		if r <= 0.0:
			var lo: float = stage_list[i][1]
			var hi: float = 1.0 if i == 0 else stage_list[i - 1][1]
			return rng.randf_range(lo, hi - 0.001)
	return rng.randf()
