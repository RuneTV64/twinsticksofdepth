class_name Door
extends Node3D
## Hinged door. This node sits on the hinge; the panel runs along local +X.
## The collision body is a child of the hinge, so it swings with the door you see.
##  - Walk into it (either stance) and it swings away from you. That opens AND closes it.
##  - Interact (weapon away) opens or closes it.
##  - Run or dash into a shut door to barge it. Power = (STR + WT) x speed. If the power beats
##    the door's toughness it slams open, but it still hurts. If not, you bounce off and hurt more.
##  - Locked doors won't push open. Barge them; every failed barge weakens them a bit.

@export var width := 1.6
@export var height := 2.3
@export var toughness := 14.0
@export var locked := false
@export var max_angle_deg := 105.0

var angle := 0.0
var body: AnimatableBody3D

var _max_angle := 0.0
var _base_yaw := 0.0
var _target := 0.0
var _has_target := false
var _target_speed := 4.0
var _push_vel := 0.0
var _weaken := 0.0
var _shake := 0.0
var _panel: MeshInstance3D


func _ready() -> void:
	add_to_group("interactables")
	_max_angle = deg_to_rad(max_angle_deg)
	_base_yaw = rotation.y

	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("door", self)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.05, height, 0.16)
	shape.shape = box
	shape.position = Vector3(width * 0.5, height * 0.5, 0.0)
	body.add_child(shape)

	_panel = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	_panel.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.14) if locked else Color(0.55, 0.38, 0.22)
	_panel.material_override = mat
	_panel.position = shape.position
	body.add_child(_panel)
	if locked:
		for y in [0.5, 1.8]:
			var band := MeshInstance3D.new()
			var b2 := BoxMesh.new()
			b2.size = Vector3(width - 0.1, 0.12, 0.2)
			band.mesh = b2
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.25, 0.25, 0.28)
			bmat.metallic = 0.6
			band.material_override = bmat
			band.position = Vector3(width * 0.5, y, 0.0)
			body.add_child(band)


func _physics_process(delta: float) -> void:
	if _has_target:
		angle = move_toward(angle, _target, _target_speed * delta)
		if is_equal_approx(angle, _target):
			_has_target = false
	else:
		angle += _push_vel * delta
		_push_vel = move_toward(_push_vel, 0.0, 14.0 * delta)
	angle = clampf(angle, -_max_angle, _max_angle)
	_shake = maxf(_shake - delta, 0.0)
	var wobble := sin(_shake * 90.0) * 0.04 * (_shake / 0.25)
	rotation.y = _base_yaw + angle + wobble


func is_shut() -> bool:
	return absf(angle) < 0.15


func resistance() -> float:
	return maxf(toughness - _weaken, 1.0)


## Which way the door swings when pushed from `from_pos` in direction `dir` (+1 / -1).
func _swing_sign(from_pos: Vector3, dir: Vector3) -> float:
	var r := from_pos - global_position
	var tq := r.z * dir.x - r.x * dir.z
	if absf(tq) < 0.001:
		return 1.0
	return signf(tq)


## Gentle push from walking into it. Returns false if it won't move (locked).
func push(from_pos: Vector3, dir: Vector3, speed: float) -> bool:
	if locked and is_shut():
		return false
	if _has_target and _target_speed > 8.0:
		return true   # mid-slam from a barge: let it finish
	_has_target = false
	var r := from_pos - global_position
	r.y = 0.0
	var lever := clampf(r.length(), 0.4, width)
	var w := clampf(speed / lever * 1.4, 2.0, 12.0)
	_push_vel = _swing_sign(from_pos, dir) * w
	return true


## Hard hit. Returns true if it burst open.
func barge(power: float, from_pos: Vector3, dir: Vector3) -> bool:
	if power >= resistance():
		locked = false
		_target = _swing_sign(from_pos, dir) * _max_angle
		_target_speed = 22.0
		_has_target = true
		return true
	_weaken += 3.0
	_shake = 0.25
	return false


# ---- interactable API ----
func can_interact(_p: Player) -> bool:
	return true


func interact_point() -> Vector3:
	return global_transform * Vector3(width * 0.5, 1.0, 0.0)


func prompt_text(_p: Player) -> String:
	if locked and is_shut():
		return "Locked (barge it: run or dash into it)"
	return "Open door" if is_shut() else "Close door"


func interact(p: Player) -> void:
	if locked and is_shut():
		p.show_status("Locked tight. Run or dash into it to barge it open.", 2.0)
		return
	_push_vel = 0.0
	_has_target = true
	_target_speed = 4.0
	if is_shut():
		var c := interact_point()
		var d := c - p.global_position
		d.y = 0.0
		_target = _swing_sign(p.global_position, d.normalized()) * _max_angle * 0.95
	else:
		_target = 0.0
