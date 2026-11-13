class_name CamRig
extends Node3D
## Locked-angle camera. It never rotates; it only pans to the player's camera focus
## (the player, the free-look crosshair, or a lead toward the aim point).

@export var pitch_deg := 56.0
@export var distance := 18.0
@export var fov := 50.0
@export var follow_sharpness := 7.0   # higher = snappier pan

var target: Player
var cam: Camera3D
var _focus := Vector3.ZERO


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = fov
	add_child(cam)
	var p := deg_to_rad(pitch_deg)
	cam.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)
	cam.rotation = Vector3(-p, 0.0, 0.0)
	cam.current = true


func snap() -> void:
	if target:
		_focus = target.camera_focus()
		global_position = _focus


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_focus = _focus.lerp(target.camera_focus(), 1.0 - exp(-follow_sharpness * delta))
	global_position = _focus
