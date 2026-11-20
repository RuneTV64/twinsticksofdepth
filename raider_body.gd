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
