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

# What the shader was last told, kept so scripts can ask the same question (`hides()`).
static var _focus := Vector3.ZERO
static var _view := Vector3.DOWN
static var _shape := Vector4.ZERO

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


## Is this point of the world cut away right now (not drawn, so not something the crosshair can be on)?
## The same test as the shader's, without the dithered edge.
static func hides(wp: Vector3) -> bool:
	if _shape.w < 0.5 or wp.y < _shape.z or _view.y > -0.05:
		return false
	var flat := Vector2(_view.x, _view.z).normalized()
	if Vector2(wp.x - _focus.x, wp.z - _focus.z).dot(flat) > -0.25:
		return false
	var t := (_focus.y - wp.y) / _view.y
	if t <= 0.0:
		return false
	var at := wp + _view * t
	return Vector2(at.x - _focus.x, at.z - _focus.z).length() < _shape.x - _shape.y * 0.5


func _process(_delta: float) -> void:
	if player == null or camera == null or not enabled or player.get("dead"):
		_shape = Vector4(radius, soft, 0.0, 0.0)
		RenderingServer.global_shader_parameter_set("cutaway_shape", _shape)
		return
	var feet := player.global_position
	# Standing on bodies raises the player (perch): the opening follows.
	var lift: float = player.get("perch") if player.get("perch") != null else 0.0
	_focus = feet + Vector3(0.0, 1.0 + lift, 0.0)
	_view = -camera.global_transform.basis.z
	_shape = Vector4(radius, soft, feet.y + keep_below + lift, 1.0)
	RenderingServer.global_shader_parameter_set("cutaway_focus", _focus)
	RenderingServer.global_shader_parameter_set("cutaway_view", _view)
	RenderingServer.global_shader_parameter_set("cutaway_shape", _shape)
