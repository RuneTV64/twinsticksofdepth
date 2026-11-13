class_name AmmoPickup
extends Node3D
## First interaction in the game: put your weapon away, walk up, press Interact.

@export var amount := 12
@export var respawn_time := 12.0

var _active := true
var _t := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("interactables")
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.6, 0.35, 0.4)
	_mesh.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.4, 0.05)
	_mesh.material_override = mat
	_mesh.position.y = 0.4
	add_child(_mesh)


func _process(delta: float) -> void:
	if not _active:
		_t -= delta
		if _t <= 0.0:
			_active = true
			visible = true
		return
	_mesh.rotation.y += delta * 1.5
	_mesh.position.y = 0.4 + sin(Time.get_ticks_msec() * 0.004) * 0.08


func can_interact(_p: Player) -> bool:
	return _active


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return "Pick up ammo (+%d)" % amount


func interact(p: Player) -> void:
	p.add_ammo(amount)
	_active = false
	visible = false
	_t = respawn_time
