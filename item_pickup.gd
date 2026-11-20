class_name ItemPickup
extends Node3D
## A box of things lying in the level (a first-aid box, for now). Walk up, weapon away, interact: what is in it
## goes into your slots. What won't fit stays in the box.

@export var title := "First-aid box"
var small := false           # one small thing lying on the ground (a rock, a bottle), not a box
var tint := Color(0.85, 0.87, 0.82)
var contents: Array[Dictionary] = []

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _alpha := 0.0
var _player: Player


func _ready() -> void:
	add_to_group("interactables")
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.55, 0.3, 0.35) if not small else Vector3(0.2, 0.14, 0.2)
	_mesh.mesh = b
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint
	_mat.emission_enabled = not small
	_mat.emission = Color(0.1, 0.4, 0.15)
	_mesh.material_override = _mat
	_mesh.position.y = 0.3 if not small else 0.08
	add_child(_mesh)


func _process(delta: float) -> void:
	# Like everything else lying about, it only shows while you can see it.
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	var seen := _player == null or _player.can_see(global_position, 0.3)
	_alpha = move_toward(_alpha, 1.0 if seen else 0.0, delta / 0.25)
	_mesh.visible = _alpha > 0.02 and not contents.is_empty()


func can_interact(_p: Player) -> bool:
	return not contents.is_empty()


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return ("Pick up the %s" if small else "Take what is in the %s") % title.to_lower()


func interact(p: Player) -> void:
	var left: Array[Dictionary] = []
	var took := 0
	for item in contents:
		var rest: Dictionary = p.inv.add(item)
		if rest.is_empty():
			took += 1
		else:
			left.append(rest)
	contents = left
	p.recompute_stats()
	if left.is_empty() and small:
		p.show_status("%s taken. Tab: Throw." % title, 1.5)
		queue_free()
	elif small:
		p.show_status("No room for it: your pockets, belt and hands are full.", 1.8)
	elif left.is_empty():
		p.show_status("Took everything from the %s." % title.to_lower(), 2.5)
		queue_free()
	else:
		p.show_status("Took %d things; no room for the rest." % took, 2.0)
