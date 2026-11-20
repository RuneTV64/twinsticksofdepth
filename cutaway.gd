class_name Cutaway
extends Node
## Keeps the cutaway up to date: whatever stands between the camera and the player is cut open (see
## cutaway.gdshaderinc). The camera never turns, so tall things to the south would otherwise hide the player and
## the ground behind them. One of these lives in the level; it sets a few project-wide shader values once a frame.
##
## Anything drawn with a shader that includes the cutaway takes part. The test level's walls, crates and doors
## do, through Cutaway.solid(); the modular building pieces to come should include it in their own shaders.

@export var radius := 2.6        # m: how far round the player the opening reaches
@export var soft := 0.9          # m: the dithered edge of it
@export var keep_below := 0.95   # m above the player's feet: walls are kept up to here, so you see where they stand
@export var enabled := true

var player: Node3D
var camera: Camera3D

static var _shader: Shader
static var _materials := {}


## The level's plain solid colour, with the cutaway in it. One material per colour, shared.
static func solid(color: Color, metal := 0.0) -> ShaderMaterial:
	var key := "%s/%.2f" % [color.to_html(), metal]
	if not _materials.has(key):
		if _shader == null:
			_shader = load("res://level_solid.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("metal", metal)
		_materials[key] = m
	return _materials[key]


func _process(_delta: float) -> void:
	if player == null or camera == null or not enabled or player.get("dead"):
		RenderingServer.global_shader_parameter_set("cutaway_shape", Vector4(radius, soft, 0.0, 0.0))
		return
	var feet := player.global_position
	# Standing on bodies raises the player (perch): the opening follows.
	var lift: float = player.get("perch") if player.get("perch") != null else 0.0
	RenderingServer.global_shader_parameter_set("cutaway_focus", feet + Vector3(0.0, 1.0 + lift, 0.0))
	RenderingServer.global_shader_parameter_set("cutaway_view", -camera.global_transform.basis.z)
	RenderingServer.global_shader_parameter_set("cutaway_shape", Vector4(radius, soft, feet.y + keep_below + lift, 1.0))
