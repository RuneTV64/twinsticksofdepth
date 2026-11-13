class_name Enemy
extends CharacterBody3D
## "dummy": stands still, heals after a few seconds, respawns fast. For feeling out aim.
## "shambler": slow undead that walks straight at you, swipes in melee, and shoulders
## doors open the same way you do. Respawns where it started.

@export var kind := "dummy"
@export var max_hp := 100.0
@export var move_speed := 2.3
@export var aggro_range := 12.0
@export var attack_range := 1.45
@export var attack_damage := 10.0
@export var attack_cooldown := 1.3

var hp := 100.0
var dead := false
var home := Vector3.ZERO
var player: Player

var _knock := Vector3.ZERO
var _flash := 0.0
var _cd := 0.0
var _since_hit := 99.0
var _dead_t := 0.0
var _sway := 0.0
var _mat: StandardMaterial3D
var _visual: Node3D
var _label: Label3D
var _base_color := Color(0.6, 0.55, 0.4)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	home = global_position
	hp = max_hp
	_sway = randf() * TAU
	if kind == "shambler":
		_base_color = Color(0.42, 0.5, 0.38)

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	var m := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.42
	cm.height = 1.8
	m.mesh = cm
	m.material_override = _mat
	m.position.y = 0.9
	_visual.add_child(m)
	if kind == "shambler":
		var arms := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.9, 0.14, 0.6)
		arms.mesh = am
		arms.material_override = _mat
		arms.position = Vector3(0, 1.25, -0.4)
		_visual.add_child(arms)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position.y = 2.3
	_label.visible = false
	add_child(_label)


func take_hit(dmg: float, dir: Vector3, knock: float) -> void:
	if dead:
		return
	hp -= dmg
	_flash = 0.1
	_since_hit = 0.0
	var k := 0.25 if kind == "dummy" else 1.0
	_knock += Vector3(dir.x, 0.0, dir.z) * knock * k
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	hp = 0.0
	visible = false
	collision_layer = 0
	_dead_t = 2.0 if kind == "dummy" else 7.0


func _respawn() -> void:
	dead = false
	hp = max_hp
	visible = true
	collision_layer = 4
	global_position = home
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_flash -= delta
	_cd -= delta
	_since_hit += delta
	if dead:
		_dead_t -= delta
		if _dead_t <= 0.0:
			_respawn()
		return

	var want := Vector3.ZERO
	if kind == "shambler" and player != null and not player.dead:
		var to := player.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < aggro_range and dist > 0.01:
			var d := to / dist
			_sway += delta * 3.0
			var side := Vector3(-d.z, 0.0, d.x) * sin(_sway) * 0.35
			want = (d + side).normalized() * move_speed
			_visual.rotation.y = atan2(-d.x, -d.z)
			if dist < attack_range:
				want = Vector3.ZERO
				if _cd <= 0.0:
					_cd = attack_cooldown
					player.take_damage(attack_damage, d, 6.0)
					player.show_status("Hit! -%d HP" % roundi(attack_damage), 0.8)
	elif kind == "dummy" and _since_hit > 3.0:
		hp = max_hp

	_knock = _knock.move_toward(Vector3.ZERO, 18.0 * delta)
	var horiz := want + _knock
	velocity.x = horiz.x
	velocity.z = horiz.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 25.0 * delta
	if kind == "dummy":
		velocity.x = _knock.x
		velocity.z = _knock.z
	move_and_slide()

	# Shamblers push doors open just like the player does.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col != null and col.has_meta("door"):
			var door: Door = col.get_meta("door")
			var n := get_slide_collision(i).get_normal()
			door.push(global_position, -Vector3(n.x, 0.0, n.z).normalized(), move_speed)

	_mat.albedo_color = Color(1, 1, 1) if _flash > 0.0 else _base_color
	_label.visible = _since_hit < 2.5
	_label.text = "%d" % ceili(hp)
