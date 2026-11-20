class_name CamRig
extends Node3D
## Locked-angle camera. It never rotates; it only pans to the player's camera focus
## (the player, the free-look crosshair, or a lead toward the aim point).

@export var pitch_deg := 56.0
@export var distance := 18.0
## The mouse wheel moves the camera in and out between these (m from what it looks at).
## Project Zomboid's zoom steps run from 25% to 250% of its normal view; this is the same span round our 18 m.
@export var zoom_min := 4.5
@export var zoom_max := 45.0
@export var zoom_step := 1.12         # each notch of the wheel: this much nearer or further
@export var zoom_sharpness := 9.0
@export var fov := 50.0
@export var follow_sharpness := 7.0   # higher = snappier pan
@export var kick_recover := 16.0      # higher = recoil jolt settles faster

var target: Player
var cam: Camera3D
var _focus := Vector3.ZERO
var _kick := Vector3.ZERO
var _want := 18.0                     # the distance the wheel has asked for


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = fov
	add_child(cam)
	_want = distance
	cam.far = 400.0
	_place()
	cam.rotation = Vector3(-deg_to_rad(pitch_deg), 0.0, 0.0)
	cam.current = true


func _place() -> void:
	var p := deg_to_rad(pitch_deg)
	cam.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)


## Wheel notches: negative = in, positive = out. The angle never changes, only how far back the camera is.
func zoom(notches: int) -> void:
	_want = clampf(_want * pow(zoom_step, notches), zoom_min, zoom_max)


func snap() -> void:
	if target:
		_focus = target.camera_focus()
		global_position = _focus


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_focus = _focus.lerp(target.camera_focus(), 1.0 - exp(-follow_sharpness * delta))
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-kick_recover * delta))
	global_position = _focus + _kick
	if absf(distance - _want) > 0.01:
		distance = lerpf(distance, _want, 1.0 - exp(-zoom_sharpness * delta))
		_place()


## A short positional jolt (recoil). It pans only, never rotates, and settles on its own.
func kick(offset: Vector3) -> void:
	_kick = (_kick + offset).limit_length(0.8)
