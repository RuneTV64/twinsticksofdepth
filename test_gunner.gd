class_name TestGunner
extends Node3D
## Cover test stand-in for a raider (G in the test level). It never moves. Whenever it can see the player it
## shoots; when the player ducks out of sight it puts a few more shots into where it last saw them, then waits.
## It sees what a raider would: not through walls, over low cover, and not someone hunkered behind cover.

@export var fire_interval := 0.9
@export var damage := 12.0
@export var spread_deg := 2.5
@export var sight := 32.0
@export var suppress_time := 2.5     # s it keeps firing at where it last saw you

var player: Player
var _cd := 1.0
var _last_seen := Vector3.ZERO
var _since_seen := 99.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("gunners")
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 1.8, 0.6)
	_mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.45, 0.15)
	_mesh.material_override = mat
	_mesh.position.y = 0.9
	add_child(_mesh)
	var l := Label3D.new()
	l.text = "Test gunner"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 36
	l.outline_size = 8
	l.pixel_size = 0.01
	l.position.y = 2.3
	_mesh.add_child(l)


func sees_player() -> bool:
	if player == null or player.dead:
		return false
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > sight or player.hidden_from(global_position):
		return false
	var eye := Vector3.UP * 1.5
	var hit := Projectile.wall_hit(get_world_3d().direct_space_state, global_position + eye,
		player.global_position + eye, [player.get_rid()])
	return hit.is_empty()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_mesh.visible = player.can_see(global_position)
	_cd -= delta
	_since_seen += delta
	if sees_player():
		_last_seen = player.global_position
		_since_seen = 0.0
	if _cd > 0.0 or _since_seen > suppress_time or player.dead:
		return
	_cd = fire_interval
	var to := _last_seen - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return
	var a := deg_to_rad(randf_range(-spread_deg, spread_deg))
	var shot := Projectile.new()
	shot.dir = to.normalized().rotated(Vector3.UP, a)
	shot.damage = damage
	shot.knock = 1.0
	shot.targets_player = true
	shot.position = global_position + Vector3(0.0, 1.15, 0.0) + shot.dir * 0.5
	get_parent().add_child(shot)
