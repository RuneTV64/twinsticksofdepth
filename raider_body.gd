class_name RaiderBody
extends PlayerBody
## A raider's body: the same model, skeleton and posing as the player (player_body.gd), wearing a rolled living
## look (skin tone, look, hair colour) from MaleBody_Muscular_Skins. A Raider drives it through the same state
## fields the Player has, so every pose the player has, a raider has: walking, aiming, reloading, cover, death.

const RAIDER_MODEL := "res://assets/characters/MaleBody_Muscular/MaleBody_Muscular_mid.glb"
const LIVING_SHADER := "res://assets/characters/MaleBody_Muscular_Skins/body_living.gdshader"

# Loaded once and shared: one scene, one material for every raider. Each body's look is per-object shader values.
static var _scene: PackedScene
static var _shared: ShaderMaterial

## Who he is: {tone, variant, hair, seed}, as LivingBody.roll_look() gives it.
var look := {}


func _model_scene() -> PackedScene:
	if _scene == null:
		_scene = load(RAIDER_MODEL) as PackedScene
	return _scene


func _make_material() -> ShaderMaterial:
	if _shared == null:
		_shared = ShaderMaterial.new()
		_shared.shader = load(LIVING_SHADER)
		_shared.set_shader_parameter("pixel_size", pixel_size)
	return _shared


func _ready() -> void:
	outline_kind = Outline.RAIDER
	super._ready()
	roll()


## A new person: a skin tone from any group, a look and a hair colour.
func roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	look = LivingBody.roll_look(rng, LivingBody.GROUPS.keys())
	if _mesh == null:
		return
	_mesh.set_instance_shader_parameter("skin_tone", look.tone)
	_mesh.set_instance_shader_parameter("variant", look.variant)
	_mesh.set_instance_shader_parameter("hair_color", look.hair)
	_mesh.set_instance_shader_parameter("look_seed", look.seed)
	dress(Clothes.layers_from(outfit(rng), body_kind))


## What a raider has on (owner, 21 Nov 2026: clothes, so they read as raiders and not as copies of you). Rolled,
## in drab and hard-wearing things, with a bandana, a cap or a sling now and then. Looks only: raiders have no
## inventory yet, so what they wear keeps nothing out.
static func outfit(rng: RandomNumberGenerator) -> Array:
	var pick := func(a: Array): return a[rng.randi() % a.size()]
	var out := [
		{"wear": "undershirt", "look": {"cut": pick.call(["tee", "tee", "tank", "longsleeve"]), "ink": pick.call(["dark", "olive", "canvas", "#5a4a3a", "crimson"]), "pat": "plain"}},
		{"wear": "legs", "look": {"cut": "jeans", "ink": pick.call(["blue", "dark", "olive", "#4a4438"]), "pat": pick.call(["denim", "plain"]), "ink2": "water", "detail": "jeans", "thick": 0.01}},
		{"wear": "feet", "look": {"cut": "boots", "ink": pick.call(["leather", "dark"]), "pat": "leather", "thick": 0.022, "detail": "laces"}},
		{"wear": "waist", "look": {"cut": "belt", "ink": "leather", "pat": "leather", "thick": 0.014}},
	]
	if rng.randf() < 0.6:
		out.append({"wear": "outer", "look": pick.call([
			{"cut": "longsleeve", "ink": "red", "ink2": "dark", "pat": "check", "open": 0.16, "thick": 0.014},
			{"cut": "longsleeve", "ink": "#3a5a4a", "ink2": "dark", "pat": "check", "open": 0.16, "thick": 0.014},
			{"cut": "jacket", "ink": "leather", "pat": "leather", "open": 0.1, "thick": 0.018},
			{"cut": "jacket", "ink": "olive", "pat": "plain", "open": 0.08, "thick": 0.018, "detail": "zip"}])})
	if rng.randf() < 0.4:
		out.append({"wear": "face", "look": {"cut": "bandana", "ink": pick.call(["red", "dark", "#3a4a6a"]), "ink2": "white", "pat": "print"}})
	if rng.randf() < 0.35:
		out.append({"wear": "head", "look": {"cut": pick.call(["beanie", "cap"]), "ink": pick.call(["dark", "olive", "red"]), "pat": "knit", "thick": 0.014}})
	if rng.randf() < 0.5:
		out.append({"wear": "strap", "look": {"cut": "strap", "shape": "strap", "ink": "leather", "pat": "leather", "thick": 0.016}})
	if rng.randf() < 0.3:
		out.append({"wear": "hands", "look": {"cut": "gloves", "ink": pick.call(["dark", "leather"]), "pat": "leather"}})
	return out


## The living skin shader lights in view space: point it at the level sun as the camera sees it (the camera
## never turns), as zombie_body.gd does.
func _aim_light_at_sun() -> void:
	if material == null or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	var suns := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	if cam == null or suns.is_empty():
		return
	var d := (suns[0] as Node3D).global_transform.basis.z.normalized()
	material.set_shader_parameter("key_dir", (cam.global_transform.basis.inverse() * d).normalized())
