# MaleBody_Muscular living look picker for Godot 4.
# Rolls a skin tone, a look (freckles, clean shaven, hairy, old, vitiligo) and a hair color, and sets them on
# body_living.gdshader, so every living body comes out different.
#
# Use: make a scene from MaleBody_Muscular.glb (New Inherited Scene), attach this script to its root, save it.
# Each instance rolls itself when it enters the tree. Call roll() again for a new look, or set_look() for an exact one.
# The skin tones, looks and hair weights here are shared with the zombies (shambler.gd uses roll_look()), so a
# zombie is rolled as the person it used to be.
class_name LivingBody
extends Node3D

signal rolled(tone: int, variant: int, hair: int)

const VARIANTS := ["Freckles", "Clean shaven", "Hairy", "Old", "Vitiligo"]
const HAIR := ["Blond", "Ginger", "Brown", "Dark", "Grey"]
## Skin tone groups. Each tone's number is fixed in the shader; add groups here as their tones are made.
const GROUPS := {
	"european": {"tones": {0: "Porcelain", 1: "Cream", 2: "Fawn"},
		# hair color weights for each look: [blond, ginger, brown, dark, grey]
		# how often each look rolls in this group: [freckles, clean shaven, hairy, old, vitiligo]
		"looks": [1.0, 2.0, 1.5, 1.0, 1.0],
		"hair": {0: [3, 5, 2, 0, 0], 1: [2, 1, 4, 3, 0], 2: [1, 1, 4, 5, 0], 3: [0, 0, 0, 1, 7], 4: [2, 1, 4, 3, 0]}},
	"african": {"tones": {3: "Umber", 4: "Mahogany", 5: "Ebony"},
		"looks": [1.0, 2.0, 1.5, 1.0, 1.0],
		"hair": {0: [0, 1, 3, 6, 0], 1: [0, 0, 2, 8, 0], 2: [0, 0, 2, 8, 0], 3: [0, 0, 0, 1, 7], 4: [0, 0, 2, 8, 0]}},
	"latin": {"tones": {6: "Golden", 7: "Copper", 8: "Bronze"},
		"looks": [1.0, 2.0, 1.5, 1.0, 1.0],
		"hair": {0: [1, 1, 3, 5, 0], 1: [1, 0, 3, 6, 0], 2: [0, 0, 3, 7, 0], 3: [0, 0, 0, 1, 7], 4: [1, 0, 3, 6, 0]}},
	"asian": {"tones": {9: "Wheat", 10: "Honey", 11: "Almond"},
		"looks": [1.0, 2.0, 1.0, 1.0, 1.0],
		"hair": {0: [0, 0, 2, 8, 0], 1: [0, 0, 1, 9, 0], 2: [0, 0, 1, 9, 0], 3: [0, 0, 0, 1, 7], 4: [0, 0, 1, 9, 0]}},
	"mideast_southasia": {"tones": {12: "Sand", 13: "Caramel", 14: "Chestnut"},
		"looks": [1.0, 2.0, 1.5, 1.0, 1.0],
		"hair": {0: [0, 0, 3, 7, 0], 1: [0, 0, 2, 8, 0], 2: [0, 0, 1, 9, 0], 3: [0, 0, 0, 1, 7], 4: [0, 0, 2, 8, 0]}},
}

@export var roll_on_ready := true
## -1 rolls a new look every time. Any other number always gives the same look.
@export var roll_seed := -1
## Which skin tone groups a roll can pick from.
@export var groups: Array[String] = ["european", "african", "latin", "asian", "mideast_southasia"]
## Extra weighting on each look, on top of the group's own: freckles, clean shaven, hairy, old, vitiligo.
## 0 turns a look off everywhere; 2 makes it twice as common.
@export var variant_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]
@export var skin_shader: Shader = preload("body_living.gdshader")

var skin_tone := 1
var variant := 1
var hair_color := 2
var look_seed := 0.0

var _meshes: Array[MeshInstance3D] = []
static var _material: ShaderMaterial


func _ready() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m)
	if _meshes.is_empty():
		push_warning("LivingBody: no mesh found")
	if _material == null and skin_shader != null:
		_material = ShaderMaterial.new()
		_material.shader = skin_shader
	if _material != null:
		for m in _meshes:
			m.material_override = _material
	if roll_on_ready:
		roll()


## Roll a new look. Pass a value to force it, e.g. roll(-1, 3) for an old man of any tone.
func roll(tone := -1, look := -1, hair := -1) -> void:
	var rng := RandomNumberGenerator.new()
	if roll_seed >= 0:
		rng.seed = roll_seed
	else:
		rng.randomize()
	var l := roll_look(rng, groups, variant_weights, tone, look, hair)
	set_look(l.tone, l.variant, l.hair, l.seed)


## Roll who a person is: a skin tone from one of the groups, a look and a hair color, and a seed for the details.
## Returns {tone, variant, hair, seed}. Shared with the zombies, so they're rolled from the same people.
## Pass tone, look or hair (>= 0) to force them.
static func roll_look(rng: RandomNumberGenerator, from_groups: Array, weights: Array = [],
		tone := -1, look := -1, hair := -1) -> Dictionary:
	var group: String = from_groups[rng.randi_range(0, from_groups.size() - 1)] if not from_groups.is_empty() else "european"
	var g: Dictionary = GROUPS.get(group, GROUPS["european"])
	if tone >= 0:   # a forced tone picks its own group, for the hair and look weights
		for k in GROUPS:
			if GROUPS[k].tones.has(tone):
				g = GROUPS[k]
	else:
		var tones: Array = g.tones.keys()
		tone = tones[rng.randi_range(0, tones.size() - 1)]
	if look < 0:
		var looks: Array = g.get("looks", [1.0, 1.0, 1.0, 1.0, 1.0]).duplicate()
		for i in looks.size():
			looks[i] = float(looks[i]) * (float(weights[i]) if i < weights.size() else 1.0)
		look = _pick(rng, looks)
	if hair < 0:
		hair = _pick(rng, g.hair.get(look, [1, 1, 1, 1, 0]))
	return {"tone": tone, "variant": look, "hair": hair, "seed": rng.randf_range(0.0, 100.0)}


## Set an exact look: skin tone (European: 0 Porcelain, 1 Cream, 2 Fawn; African: 3 Umber, 4 Mahogany, 5 Ebony;
## Latin American: 6 Golden, 7 Copper, 8 Bronze; Asian: 9 Wheat, 10 Honey, 11 Almond;
## Middle Eastern & South Asian: 12 Sand, 13 Caramel, 14 Chestnut), variant (0 freckles, 1 clean shaven,
## 2 hairy, 3 old, 4 vitiligo), hair color (0 blond, 1 ginger, 2 brown, 3 dark, 4 grey) and a seed for the details.
func set_look(tone: int, look: int, hair: int, seed_value := 0.0) -> void:
	skin_tone = tone
	variant = look
	hair_color = hair
	look_seed = seed_value
	for m in _meshes:
		m.set_instance_shader_parameter("skin_tone", skin_tone)
		m.set_instance_shader_parameter("variant", variant)
		m.set_instance_shader_parameter("hair_color", hair_color)
		m.set_instance_shader_parameter("look_seed", look_seed)
	rolled.emit(skin_tone, variant, hair_color)


## A readable name for the current look, e.g. "Fawn, hairy, dark hair".
func describe() -> String:
	var tone_name := "?"
	for g in GROUPS.values():
		if g.tones.has(skin_tone):
			tone_name = g.tones[skin_tone]
	return "%s, %s, %s hair" % [tone_name, VARIANTS[variant].to_lower(), HAIR[hair_color].to_lower()]


static func _pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return 0
	var r := rng.randf() * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1
