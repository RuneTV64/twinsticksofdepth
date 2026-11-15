# ShamblerMale_Muscular spawner for Godot 4.
# Rolls one part per slot (Head, Torso, ArmL, ArmR, LegL, LegR) so every shambler looks different, and rolls how
# long he's been dead (his Freshness): fresh ones are pale and drained, older ones go green, then black, then leathery.
# A destroyed leg makes a crawler: read is_crawler (or listen to `rolled`) to pick crawler movement and animations.
# Head_Decapitated is never rolled at spawn. Call dismember("Head") when a hit takes the head off.
#
# Use: make a scene from ShamblerMale_Muscular.glb (New Inherited Scene), attach this script to its root, save it.
# Each instance of that scene rolls itself when it enters the tree.
# Needs freshness.gd, living_body.gd and anatomy_map.gd somewhere in the project (they register the Freshness,
# LivingBody and AnatomyMap classes).
extends Node3D

signal rolled(parts: Dictionary, crawler: bool)
signal dismembered(slot: String, crawler: bool)

const SLOTS := ["Head", "Torso", "ArmL", "ArmR", "LegL", "LegR"]
const STATES := ["Intact", "Rotted", "Destroyed"]   # what a spawn can roll
const PLAY_STATES := {"Head": ["Decapitated"]}       # only switched to in play

@export var roll_on_ready := true
## -1 rolls a new shambler every time. Any other number always gives the same shambler.
@export var roll_seed := -1
@export_range(0.0, 1.0) var chance_rotted := 0.4
@export_range(0.0, 1.0) var chance_destroyed := 0.15
## Most legs one shambler can lose (0, 1 or 2). Two lost legs still crawls, on the arms alone.
@export_range(0, 2) var max_lost_legs := 1

@export_group("Freshness")
## How often each stage of decay is rolled at spawn. Set a stage to 0 to never roll it.
@export var stage_weights := {"Fresh": 2, "Rigor": 2, "Bloated": 3, "Putrid": 3, "Dried": 1}
## Fresh bodies haven't had time to rot: at Freshness 1 the Rotted chance is scaled by this, rising to
## rotted_scale_old for the oldest. Fresh "Rotted" parts read as fresh bites and tears, wet and red.
@export var rotted_scale_fresh := 0.6
@export var rotted_scale_old := 1.25
## Who he was: which skin tone groups to roll from, and an extra weight on each look (freckles, clean shaven,
## hairy, old, vitiligo), the same as on a living body. Tones, looks and hair come from living_body.gd.
@export var groups: Array[String] = ["european", "african", "latin", "asian", "mideast_southasia"]
@export var variant_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]
## Range of grime (mud, dust, stains and smears): 0 clean, 1 caked.
@export var grime_range := Vector2(0.1, 0.9)
## Range of blood spattered on the hands, arms and chest.
@export var gore_range := Vector2(0.15, 0.85)
@export var skin_shader: Shader = preload("zombie_decay.gdshader")

var parts := {}          # slot -> state shown now
var is_crawler := false
var is_decapitated := false
var freshness: Freshness  # how long he's been dead; call freshness.age(hours) to let him rot further
var skin_tone := 1       # who he was: the same values as a living body's look (see living_body.gd)
var variant := 1
var hair_color := 2
var look_seed := 0.0
var decay_seed := 0.0
var gore := 0.5
var grime := 0.5
var neck_blood := 0.0    # set from the head's state: 1 decapitated, less for a torn neck

var _meshes := {}        # "Slot_State" -> MeshInstance3D
static var _material: ShaderMaterial


func _ready() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var key := String(m.name)
		var bits := key.split("_")
		if bits.size() == 2 and bits[0] in SLOTS and (bits[1] in STATES or bits[1] in PLAY_STATES.get(bits[0], [])):
			_meshes[key] = m
	var expected := SLOTS.size() * STATES.size()
	for slot in PLAY_STATES:
		expected += PLAY_STATES[slot].size()
	if _meshes.size() != expected:
		push_warning("Shambler: expected %d part meshes, found %d" % [expected, _meshes.size()])
	if _material == null and skin_shader != null:
		_material = ShaderMaterial.new()
		_material.shader = skin_shader
		_material.set_shader_parameter("anatomy_map", AnatomyMap.texture())   # what the shader paints inside the torso's wounds
	if _material != null:
		for m in _meshes.values():
			m.material_override = _material
	if roll_on_ready:
		roll()


## Roll a new look. Pass slots to force, e.g. roll({"LegL": "Destroyed"}), and a freshness (0..1) to force how
## long he's been dead, e.g. roll({}, 1.0) for one who just turned.
func roll(forced := {}, fresh := -1.0) -> void:
	var rng := RandomNumberGenerator.new()
	if roll_seed >= 0:
		rng.seed = roll_seed
	else:
		rng.randomize()
	var f := fresh if fresh >= 0.0 else Freshness.roll(rng, stage_weights)
	var rotted := chance_rotted * lerpf(rotted_scale_fresh, rotted_scale_old, 1.0 - f)
	var lost_legs := 0
	for slot in SLOTS:
		if forced.has(slot) and forced[slot] == "Destroyed" and slot.begins_with("Leg"):
			lost_legs += 1
	var picked := {}
	for slot in SLOTS:
		var state: String
		if forced.has(slot):
			state = forced[slot]
		else:
			var r := rng.randf()
			if r < chance_destroyed:
				state = "Destroyed"
			elif r < chance_destroyed + rotted:
				state = "Rotted"
			else:
				state = "Intact"
			if state == "Destroyed" and slot.begins_with("Leg"):
				if lost_legs >= max_lost_legs:
					state = "Rotted"
				else:
					lost_legs += 1
		picked[slot] = state
	var l := LivingBody.roll_look(rng, groups, variant_weights)
	set_skin(f, l.tone, l.variant, l.hair, l.seed, rng.randf_range(0.0, 100.0), rng.randf_range(gore_range.x, gore_range.y),
		rng.randf_range(grime_range.x, grime_range.y))
	show_parts(picked)


## Set how he looks: freshness 0..1 (1 = just turned), who he was (skin tone, look and hair color, and the seed that
## places their freckles, vitiligo and hair, all as on a living body), a seed for the blotches and stains of the rot,
## how bloody he is (0..1) and how dirty (0..1).
func set_skin(fresh: float, tone := 1, look := 1, hair := 2, look_seed_value := 0.0, decay_seed_value := 0.0,
		blood := 0.5, dirt := 0.5) -> void:
	if freshness != null and freshness.changed.is_connected(_apply_skin):
		freshness.changed.disconnect(_apply_skin)
	freshness = Freshness.new(fresh)
	freshness.changed.connect(_apply_skin)
	skin_tone = tone
	variant = look
	hair_color = hair
	look_seed = look_seed_value
	decay_seed = decay_seed_value
	gore = blood
	grime = dirt
	_apply_skin()


## Turn a living person into this shambler: same skin tone, freckles, vitiligo, age and hair, just turned.
func turn_from(person: LivingBody, fresh := 1.0) -> void:
	set_skin(fresh, person.skin_tone, person.variant, person.hair_color, person.look_seed, randf_range(0.0, 100.0), gore, grime)


## Show an exact set of parts, e.g. show_parts({"Head": "Rotted", "Torso": "Destroyed", ...}).
## Slots left out stay Intact.
func show_parts(picked: Dictionary) -> void:
	parts = {}
	for slot in SLOTS:
		parts[slot] = picked.get(slot, "Intact")
	is_crawler = parts["LegL"] == "Destroyed" or parts["LegR"] == "Destroyed"
	is_decapitated = parts["Head"] == "Decapitated"
	for key in _meshes:
		var bits := String(key).split("_")
		_meshes[key].visible = parts[bits[0]] == bits[1]
	# a head that's off, or a torn neck, bleeds down over the shoulders, chest and back
	neck_blood = {"Decapitated": 1.0, "Destroyed": 0.5, "Rotted": 0.3}.get(parts["Head"], 0.0)
	for m in _meshes.values():
		m.set_instance_shader_parameter("neck_blood", neck_blood)
	rolled.emit(parts, is_crawler)


## Take a part off in play: the head becomes the decapitated neck stump, an arm or leg becomes Destroyed.
## Losing a leg turns the shambler into a crawler.
func dismember(slot: String) -> void:
	if not slot in SLOTS or slot == "Torso":
		push_warning("Shambler: can't dismember %s" % slot)
		return
	var next := parts.duplicate()
	next[slot] = "Decapitated" if slot == "Head" else "Destroyed"
	show_parts(next)
	dismembered.emit(slot, is_crawler)


## Decay stage name: "Fresh", "Rigor", "Bloated", "Putrid" or "Dried".
func stage() -> String:
	return freshness.stage() if freshness != null else "Fresh"


## Rigor mortis right now, 0 loose to 1 fully stiff. Highest in the Rigor stage; use it for stiff, jerky movement.
func rigor() -> float:
	return freshness.rigor() if freshness != null else 0.0


func _apply_skin() -> void:
	var f := freshness.value if freshness != null else 1.0
	for m in _meshes.values():
		m.set_instance_shader_parameter("freshness", f)
		m.set_instance_shader_parameter("skin_tone", skin_tone)
		m.set_instance_shader_parameter("variant", variant)
		m.set_instance_shader_parameter("hair_color", hair_color)
		m.set_instance_shader_parameter("look_seed", look_seed)
		m.set_instance_shader_parameter("decay_seed", decay_seed)
		m.set_instance_shader_parameter("gore", gore)
		m.set_instance_shader_parameter("grime", grime)
		m.set_instance_shader_parameter("neck_blood", neck_blood)
