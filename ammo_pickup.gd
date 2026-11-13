class_name AmmoPickup
extends Node3D
## First interaction in the game: put your weapon away, walk up, press Interact.

@export var amount := 12
@export var respawn_time := 12.0

var _active := true
var _t := 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _alpha := 0.0          # 1 = in the player's view; fades out when it isn't
var _player: Player


func _ready() -> void:
	add_to_group("interactables")
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.6, 0.35, 0.4)
	_mesh.mesh = b
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.7, 0.2)
	_mat.emission_enabled = true
	_mat.emission = Color(0.5, 0.4, 0.05)
	_mesh.material_override = _mat
	_mesh.position.y = 0.4
	add_child(_mesh)


## Like enemies, items only show while the player can see them. You remember the place, not
## whether the thing is still there.
func _update_fade(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	var seen := _player == null or _player.can_see(global_position, 0.3)
	_alpha = move_toward(_alpha, 1.0 if seen else 0.0, delta / 0.25)
	_mesh.visible = _alpha > 0.02
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if _alpha > 0.99 \
		else BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color.a = _alpha
	_mat.emission_energy_multiplier = _alpha


func _process(delta: float) -> void:
	_update_fade(delta)
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
