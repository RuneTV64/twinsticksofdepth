class_name Enemy
extends CharacterBody3D
## "dummy": stands still, heals after a few seconds, respawns fast. For feeling out aim.
## "shambler": slow undead that walks straight at you, swipes in melee, and shoulders
## doors open the same way you do. Respawns where it started.

@export var kind := "dummy"
@export var max_hp := 100.0            # dummies; shamblers use shambler_hp
@export var shambler_hp := 50.0        # rotten and fragile: two shots, or a long beating with fists
@export var move_speed := 2.3
@export var aggro_range := 12.0
@export var attack_range := 1.45
@export var attack_damage := 10.0
@export var attack_cooldown := 1.3
@export var shambler_respawn := 90.0   # seconds a killed shambler stays gone, so a bullet buys real time
@export var investigate_time := 10.0   # how long a heard noise keeps pulling it in
@export var fade_time := 0.25          # seconds to fade out of (or into) the player's view

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
var _alpha := 1.0                # 1 = in the player's view, fades to 0 when it isn't
var _noise_pos := Vector3.ZERO   # where the last noise it heard came from
var _noise_t := 0.0              # > 0 while it is still drawn to that spot
var _mat: StandardMaterial3D
var _visual: Node3D
var _label: Label3D
var _base_color := Color(0.6, 0.55, 0.4)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	home = global_position
	if kind == "shambler":
		max_hp = shambler_hp
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


## A loud noise (a gunshot) went off at pos. Shamblers walk to where it came from; once you are
## inside aggro_range they chase you as usual. Each new shot refreshes the spot and the timer.
func hear_noise(pos: Vector3) -> void:
	if dead or kind != "shambler":
		return
	_noise_pos = pos
	_noise_t = investigate_time


## You only see an enemy while it's in the player's view; out of it, it fades away (it is
## still there, still moving, still dangerous).
func _update_fade(delta: float) -> void:
	var seen := player == null or player.can_see(global_position)
	_alpha = move_toward(_alpha, 1.0 if seen else 0.0, delta / maxf(fade_time, 0.01))
	_visual.visible = _alpha > 0.02
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if _alpha > 0.99 \
		else BaseMaterial3D.TRANSPARENCY_ALPHA


## Shoved back by the player: thrown along dir, no damage, and it needs a moment before it
## can attack again.
func shove(dir: Vector3, force: float) -> void:
	if dead or kind == "dummy":
		return
	_knock += Vector3(dir.x, 0.0, dir.z) * force
	_cd = maxf(_cd, 0.6)


func _die() -> void:
	dead = true
	hp = 0.0
	visible = false
	collision_layer = 0
	_dead_t = 2.0 if kind == "dummy" else shambler_respawn


func _respawn() -> void:
	dead = false
	hp = max_hp
	visible = true
	collision_layer = 4
	global_position = home
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	_noise_t = 0.0


func _physics_process(delta: float) -> void:
	_flash -= delta
	_cd -= delta
	_since_hit += delta
	_update_fade(delta)
	if dead:
		_dead_t -= delta
		if _dead_t <= 0.0:
			_respawn()
		return

	var want := Vector3.ZERO
	_noise_t -= delta
	if kind == "shambler" and player != null and not player.dead:
		var to := player.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		var chasing := dist < aggro_range
		if not chasing and _noise_t > 0.0:
			# Out of sight of you, but it heard a shot: head for where the noise came from.
			to = _noise_pos - global_position
			to.y = 0.0
			dist = to.length()
			if dist < 1.0:
				_noise_t = 0.0   # got there, nothing to find
		if (chasing or _noise_t > 0.0) and dist > 0.01:
			var d := to / dist
			_sway += delta * 3.0
			var side := Vector3(-d.z, 0.0, d.x) * sin(_sway) * 0.35
			want = (d + side).normalized() * move_speed
			_visual.rotation.y = atan2(-d.x, -d.z)
			if chasing and dist < attack_range:
				want = Vector3.ZERO
				if _cd <= 0.0:
					_cd = attack_cooldown
					player.take_attack(attack_damage, d, 6.0, self)   # the player may shove it off
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

	var col := Color(1, 1, 1) if _flash > 0.0 else _base_color
	col.a = _alpha
	_mat.albedo_color = col
	_label.visible = _since_hit < 2.5 and _alpha > 0.5
	_label.text = "%d" % ceili(hp)
