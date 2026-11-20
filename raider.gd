class_name Raider
extends Enemy
## A living person with a gun who wants what you have. Raiders are Enemies (so your shots, punches, shoves and
## lock-on work on them), with the player's body and poses (raider_body.gd), a character sheet of their own, and
## the same cover the player uses, under the same rule: to see is to be seen.
##
## What a raider does:
##   idle     stands watch where it was put, looking about. It notices you in front of it within sight, or
##            anywhere close by, and comes to gunshots.
##   fight    finds cover that is between it and you, with an angle on you, and works it: hunkers (hidden,
##            reloading), peeks, then pops out to aim and fire a short burst. With no cover in reach it fights in
##            the open, sidestepping between bursts. Up close it clubs you with the gun.
##   lost you fires blind at where it last saw you, then moves to cover with an angle past yours (a flank). If
##            that fails it comes looking.
##   search   walks to where it last saw or heard you, looks about, then goes home.
##   zombies  it shoots any zombie it can see within reach, backing off as they close and clubbing them at arm's
##            length; a zombie right on it comes before the fight with you. Zombies go for raiders as they go for
##            you: they grab, hold and bite, and the raider knocks them off. Its gunfire draws more of them.
## Movement is in straight lines: there is no path finding in the game yet, so cover is only picked when the way
## to it is clear.
##
## Cover protects a raider exactly as it protects you: hunkered, shots across the cover are stopped; peeking,
## a small chance of a hit, which is a head hit, which kills; popped out, hit as normal. A hunkered raider can't
## see you, and you can't see it.

@export_group("Raider")
@export var raider_hp := 60.0           # at Constitution 10
@export var sight := 26.0               # m
@export var sight_fov_deg := 150.0      # on watch: how wide in front it notices you
@export var close_sense := 4.0          # m: on watch, it notices you this close whichever way it faces
@export var shot_damage := 12.0
@export var spread_deg := 5.0           # at Dexterity 10, calm: its shots go this far either side of you
@export var aim_time := 0.55            # s popped out before the first shot
@export var shot_gap := 0.45            # s between shots in a burst
@export var mag_size := 6
@export var reload_time := 1.6
@export var duck_time := Vector2(1.2, 2.8)   # s hunkered between bursts
@export var pop_limit := 2.6            # s it will stay out at most
@export var cover_search := 12.0        # m: how far it will go for cover
@export var prefer_range := 12.0        # m: the distance from you it likes to fight at
@export var lose_time := 4.0            # s without seeing you before it fires blind, then flanks
@export var search_time := 6.0          # s it looks about where it lost you
@export var melee_range := 1.5
@export var melee_damage := 8.0
@export var melee_gap := 1.1
@export var zombie_sense := 11.0        # m: it deals with zombies it can see this close
@export var zombie_urgent := 6.0        # m: this close, a zombie comes before the fight with you
@export var shot_noise_range := 30.0    # m: zombies this close hear its shots and come
@export var zombie_wild := 1.6          # its spread at zombies is this many times its spread at you
@export var zombie_shot_slow := 1.6     # and its shots this many times further apart
@export var fend_off_chance := 0.3      # chance it knocks a grabbing zombie away before the hands close
@export var respawn_after := 120.0      # s; 0 = never (test level stand-in)
@export var drops_ammo := Vector2i(2, 5)

var sheet := CharacterSheet.new()

# ---- what the body reads: the same names the Player has (player_body.gd poses from them)
var armed := false
var walk_speed := 2.1
var run_speed := 4.4
var reticle_visible := false
var reticle_offset := Vector3.ZERO
var cover_crouch := 0.0
var cover_lean_dir := Vector3.ZERO
var cover_blind := false
var cover_entering := false
var _dash_t := 0.0
var _hurt_t := 0.0
var _stagger := 0.0
var _flash_t := 0.0
var _swing_t := 0.0
var _swing_total := 0.0
var _swing_windup := 0.0
var _block_t := 0.0
var _reload_t := 0.0
var _bash_cd := 0.0
var _blind_t := 0.0
var _vault_t := 0.0
var _stomp_t := 0.0
var _stomp_total := 1.0
var _roll_t := 0.0
var _roll_total := 0.55
var _roll_dir := Vector3.ZERO
var _roll_rec_t := 0.0

# ---- its mind
var mode := "idle"                 # idle, fight, search, return
var last_seen := Vector3.ZERO      # where it last saw (or heard) you
var sees := false
var in_cover := false
var cover_face: Cover.Face = null  # the cover it is using or heading for
var cover_t := 0.0
var cover_mode := "hunker"         # hunker, peek, pop
var cover_side := 0                # which end it leans round: -1, 1, or 0 = over the top
var mag := 6
var rbody: RaiderBody
var _phase := "duck"               # in cover or in the open: duck, peek, pop, blind
var _phase_t := 0.0
var _aim_t := 0.0
var _burst := 0
var _shot_cd := 0.0
var _blind_left := 0
var _unseen_t := 99.0
var _see_t := 0.0
var _cover_cd := 0.0
var _cover_timeout := 0.0
var _u := 0.0
var _melee_cd := 0.0
var _search_t := 0.0
var _look_t := 0.0
var _look_dir := Vector3(0, 0, -1)
var _strafe := 1.0
var _sheet_t := 0.0
var _weapon_mat: StandardMaterial3D
var held_by: Array[Enemy] = []     # zombies that have hold of it
var _zed: Enemy = null             # the zombie it is dealing with
var _zed_t := 0.0
var _zed_threat := 0.0             # how much zombie is right on it (for composure, as the player's)


func fatigue() -> float:
	return 0.0


func is_melee() -> bool:
	return false


func _ready() -> void:
	kind = "raider"
	add_to_group("enemies")
	add_to_group("raiders")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	home = global_position
	_look_dir = facing

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	rbody = RaiderBody.new()
	_visual.add_child(rbody)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.09, 0.12, 0.85)
	gun.mesh = gm
	_weapon_mat = StandardMaterial3D.new()
	_weapon_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_weapon_mat.emission_enabled = true
	_weapon_mat.emission = Color(1.0, 0.8, 0.3)
	_weapon_mat.emission_energy_multiplier = 0.0
	gun.material_override = _weapon_mat
	rbody.attach_weapon(gun)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position.y = 2.3
	_label.visible = false
	add_child(_label)
	_new_person()


## A fresh raider: attributes a little either side of ordinary, and what they make of him.
func _new_person() -> void:
	for a in CharacterSheet.ATTRS:
		sheet.set_attr(a, float(randi_range(8, 12)))
	sheet.reset()
	max_hp = raider_hp * (1.0 + 0.03 * sheet.bonus("constitution"))
	hp = max_hp
	walk_speed = 2.1 * (1.0 + 0.02 * sheet.bonus("endurance"))
	run_speed = walk_speed * 2.1
	mag = mag_size
	mode = "idle"
	armed = false
	_drop_cover()
	_unseen_t = 99.0


func _process(delta: float) -> void:
	if rbody == null or not _visual.visible:
		return
	rbody.animate(self, delta)


func _physics_process(delta: float) -> void:
	_hurt_t -= delta
	_stagger -= delta
	_flash_t -= delta
	_bash_cd -= delta
	_blind_t -= delta
	_shot_cd -= delta
	_melee_cd -= delta
	_cover_cd -= delta
	_since_hit += delta
	_update_fade(delta)
	if dead:
		_dead_t -= delta
		_corpse_t -= delta
		velocity = Vector3.ZERO
		if respawn_after > 0.0 and _dead_t <= 0.0:
			_respawn()
		return
	if player == null:
		return
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			mag = mag_size

	# Looking for you is a ray cast, so it happens a few times a second, not every tick.
	_see_t -= delta
	_unseen_t += delta
	if _see_t <= 0.0:
		_see_t = 0.2
		sees = _can_see_player()
		if sees:
			last_seen = player.global_position
			_unseen_t = 0.0
			if mode != "fight":
				_alert()
	# The sheet's slow clock (composure: being hurt spoils his aim for a while).
	_sheet_t += delta
	if _sheet_t >= 0.25:
		sheet.tick(_sheet_t, _zed_threat, not held_by.is_empty(), in_cover and cover_mode == "hunker", hp / max_hp, false, 0.8)
		_sheet_t = 0.0

	# Zombies near enough to matter, looked for a few times a second.
	_zed_t -= delta
	if _zed_t <= 0.0:
		_zed_t = 0.3
		var was := _zed
		_zed = _nearest_zombie()
		if _zed != was:
			_aim_t = 0.0   # a new one to line up on
	for e: Enemy in held_by.duplicate():
		if not is_instance_valid(e) or e.dead:
			held_by.erase(e)

	var want := Vector3.ZERO
	cover_blind = false
	var zd := INF
	if _zed != null and is_instance_valid(_zed) and not _zed.dead:
		zd = _xz(_zed.global_position - global_position).length()
	else:
		_zed = null
	if _stagger > 0.0:
		pass
	elif not held_by.is_empty():
		_break_free(delta)
	elif _zed != null and (zd < zombie_urgent or mode != "fight" or not sees):
		want = _fight_zombie(delta, zd)
	else:
		match mode:
			"idle":
				_watch(delta)
			"fight":
				want = _fight(delta)
			"search":
				want = _search(delta)
			"return":
				want = _go_home(delta)
	_pose_for_cover()

	_knock = _knock.move_toward(Vector3.ZERO, 18.0 * delta)
	velocity.x = want.x + _knock.x
	velocity.z = want.z + _knock.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 25.0 * delta
	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col != null and col.has_meta("door"):
			var door: Door = col.get_meta("door")
			var n := get_slide_collision(i).get_normal()
			door.push(global_position, -Vector3(n.x, 0.0, n.z).normalized(), walk_speed)

	_visual.rotation.y = atan2(-facing.x, -facing.z)
	_weapon_mat.emission_energy_multiplier = 4.0 if _flash_t > 0.0 else 0.0
	var show_hp := _since_hit < 2.5 and _alpha > 0.5
	if _label.visible != show_hp:
		_label.visible = show_hp
	if show_hp and _label_hp != ceili(hp):
		_label_hp = ceili(hp)
		_label.text = "%d" % _label_hp


# ---------------------------------------------------------------- seeing and being seen
func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Hunkered with its cover between it and that point: it can't be seen from there, and can't see there.
func hidden_from(from: Vector3) -> bool:
	return in_cover and cover_face != null and cover_mode == "hunker" \
		and Cover.shields(cover_face, Cover.spot(cover_face, cover_t), _xz(from))


func _can_see_player() -> bool:
	if player.dead:
		return false
	var to := player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > sight or player.hidden_from(global_position) or hidden_from(player.global_position):
		return false
	if mode != "fight" and d > close_sense and facing.dot(to / maxf(d, 0.01)) < cos(deg_to_rad(sight_fov_deg) * 0.5):
		return false
	var eye := Vector3.UP * 1.5
	return Projectile.wall_hit(get_world_3d().direct_space_state, global_position + eye,
		player.global_position + eye, [get_rid(), player.get_rid()]).is_empty()


## You only see a raider the player could see: in view, and not hunkered behind cover from where you stand.
func _update_fade(delta: float) -> void:
	var seen := player == null or (player.can_see(global_position) and not hidden_from(player.global_position))
	_alpha = move_toward(_alpha, 1.0 if seen else 0.0, delta / maxf(fade_time, 0.01))
	var shown := _alpha > 0.5 and (not dead or _corpse_t > 0.0)
	if _visual.visible != shown:
		_visual.visible = shown


## A shot of yours has reached it. What does its cover do? "" = nothing (hit as normal), "cover" = stopped,
## "head" = it was peeking and you hit the only part showing.
func cover_result(from: Vector3) -> String:
	if not in_cover or cover_face == null or cover_mode == "pop":
		return ""
	if not Cover.shields(cover_face, Cover.spot(cover_face, cover_t), _xz(from)):
		return ""
	if cover_mode == "hunker" or randf() >= player.cover_peek_hit_chance:
		return "cover"
	return "head"


# ---------------------------------------------------------------- what happens to it
func take_hit(dmg: float, dir: Vector3, knock: float) -> void:
	_damage(dmg, dir, knock, true)


## by_player: it came from you (so it knows roughly where you are). Zombie bites don't tell it that.
func _damage(dmg: float, dir: Vector3, knock: float, by_player: bool) -> void:
	if dead:
		return
	hp -= dmg
	_hurt_t = 0.15
	hurt_t = 0.18
	_since_hit = 0.0
	_knock += Vector3(dir.x, 0.0, dir.z) * knock
	sheet.hurt(dmg / max_hp)
	if hp <= 0.0:
		_die()
		return
	if not by_player:
		return
	# It knows roughly where that came from.
	if not sees and player != null:
		last_seen = player.global_position
		_unseen_t = minf(_unseen_t, lose_time * 0.5)
	if mode != "fight":
		_alert()
	if knock >= 6.0:
		_stagger = 0.5
		_drop_cover()
	elif in_cover and cover_mode != "hunker" and randf() < 0.7:
		_duck()


func take_headshot(dir: Vector3, knock: float) -> void:
	take_hit(hp + 1.0, dir, knock)


func shove(dir: Vector3, force: float) -> void:
	if dead:
		return
	_knock += dir * force
	_stagger = 0.6
	_drop_cover()
	if mode != "fight":
		last_seen = player.global_position if player != null else global_position
		_alert()


## A gunshot. On watch it comes to look; in a fight where it has lost you, it tells it where you are.
func hear_noise(pos: Vector3) -> void:
	if dead:
		return
	if mode == "fight":
		if not sees:
			last_seen = pos
	else:
		last_seen = pos
		mode = "search"
		_search_t = search_time
		armed = true


func _die() -> void:
	dead = true
	hp = 0.0
	collision_layer = 0
	held_by.clear()
	_drop_cover()
	armed = false
	_label.visible = false
	_corpse_t = corpse_time
	_dead_t = respawn_after
	if drops_ammo.y > 0:
		var a := AmmoPickup.new()
		a.amount = randi_range(drops_ammo.x, drops_ammo.y)
		a.one_time = true
		a.position = global_position + Vector3(0.5, 0.0, 0.3)
		get_parent().add_child(a)


func _respawn() -> void:
	dead = false
	collision_layer = 4
	global_position = home
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	rbody.roll()
	_new_person()


func _alert() -> void:
	mode = "fight"
	armed = true
	_phase = "duck"
	_phase_t = 0.0
	_cover_cd = 0.0
	_blind_left = 2


# ---------------------------------------------------------------- zombies
## What a zombie does to a raider, through the same calls it makes on the player.
func take_grab(e: Enemy, hands: int) -> bool:
	if dead or hands <= 0:
		return false
	if randf() < fend_off_chance:
		var away := e.global_position - global_position
		away.y = 0.0
		e.shove(away.normalized(), 7.0)
		_bash_cd = 0.5
		return false
	if not held_by.has(e):
		held_by.append(e)
	_drop_cover()   # hands on it drag it out of cover
	sheet.startle()
	return true


func release_grab(e: Enemy) -> void:
	held_by.erase(e)


func is_held_by(e: Enemy) -> bool:
	return held_by.has(e)


func loosen_grip(_amount: float) -> void:
	pass


func take_bite(amount: float, dir: Vector3, _e: Enemy) -> void:
	_damage(amount, dir, 1.0, false)


func take_attack(amount: float, dir: Vector3, knock: float, _attacker: Enemy = null) -> void:
	_damage(amount, dir, knock, false)


## Caught where the horde is trampling its own.
func take_crush(amount: float, dir: Vector3) -> void:
	_damage(amount, dir, 2.0, false)


## Something alive in the corpse pile has hold of its leg.
func pile_grab(dir: Vector3, bite: float) -> void:
	_stagger = maxf(_stagger, 0.7)
	if bite > 0.0:
		_damage(bite, dir, 0.0, false)


## The nearest living zombie it can see within zombie_sense, or null.
func _nearest_zombie() -> Enemy:
	var best: Enemy = null
	var best_d := zombie_sense
	_zed_threat = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or en.kind != "shambler":
			continue
		var d := _xz(en.global_position - global_position).length()
		if d < 6.0:
			_zed_threat += 1.0 - d / 6.0
		if d < best_d:
			best_d = d
			best = en
	if best == null:
		return null
	var eye := Vector3.UP * 1.2
	if not Projectile.wall_hit(get_world_3d().direct_space_state, global_position + eye,
			best.global_position + eye, [get_rid()]).is_empty():
		return null
	return best


## Held: it can't go anywhere. Every so often it clubs one of them off.
func _break_free(delta: float) -> void:
	armed = true
	var e: Enemy = held_by[0]
	var to := e.global_position - global_position
	to.y = 0.0
	_turn(to, 12.0, delta)
	if _melee_cd <= 0.0:
		_melee_cd = melee_gap
		_bash_cd = 0.5
		held_by.erase(e)
		e.take_hit(melee_damage, to.normalized(), 7.0)
		e.shove(to.normalized(), 8.0)


## A zombie to deal with: shoot it as it comes, back away when it gets close, club it at arm's length.
func _fight_zombie(delta: float, dist: float) -> Vector3:
	armed = true
	if in_cover or cover_face != null:
		_drop_cover()   # cover means nothing to a zombie
	var to := _zed.global_position - global_position
	to.y = 0.0
	var d := to / maxf(dist, 0.01)
	_turn(d, 12.0, delta)
	if dist < melee_range:
		if _melee_cd <= 0.0:
			_melee_cd = melee_gap
			_bash_cd = 0.5
			_zed.take_hit(melee_damage, d, 7.0)
			_zed.shove(d, 6.0)
		return -d * walk_speed * 0.6
	if mag <= 0:
		if _reload_t <= 0.0:
			_reload_t = reload_time
	elif _reload_t <= 0.0 and _shot_cd <= 0.0 and facing.dot(d) > 0.95:
		# Hurried shots at something lurching toward it: slower and wilder than its shooting at you from cover.
		_aim_t += delta
		if _aim_t >= aim_time:
			_fire(_zed.global_position, zombie_wild, _zed)
			_shot_cd = shot_gap * zombie_shot_slow
	# Give ground as it closes, unless there is a wall at its back.
	if dist < 4.0:
		return -d * walk_speed * 0.6
	return Vector3.ZERO


# ---------------------------------------------------------------- on watch, searching, going home
func _turn(to: Vector3, rate: float, delta: float) -> void:
	to.y = 0.0
	if to.length() < 0.01:
		return
	var a := atan2(facing.x, facing.z)
	var b := atan2(to.x, to.z)
	a += clampf(wrapf(b - a, -PI, PI), -rate * delta, rate * delta)
	facing = Vector3(sin(a), 0.0, cos(a))


func _watch(delta: float) -> void:
	armed = false
	if _xz(home - global_position).length() > 2.0:
		mode = "return"   # a zombie fight took it off its post
		return
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(2.5, 6.0)
		_look_dir = Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU)
	_turn(_look_dir, 1.6, delta)


func _walk_to(point: Vector3, speed: float, delta: float) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.2:
		return Vector3.ZERO
	_turn(to, 8.0, delta)
	return to.normalized() * speed


func _search(delta: float) -> Vector3:
	armed = true
	var to := last_seen - global_position
	to.y = 0.0
	if to.length() > 1.5 and _search_t > 0.0:
		_search_t -= delta * 0.25   # it doesn't walk for ever at a wall
		return _walk_to(last_seen, walk_speed, delta)
	_search_t -= delta
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(0.8, 1.6)
		_look_dir = Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU)
	_turn(_look_dir, 3.0, delta)
	if _search_t <= 0.0:
		mode = "return"
	return Vector3.ZERO


func _go_home(delta: float) -> Vector3:
	armed = false
	var to := home - global_position
	to.y = 0.0
	if to.length() < 0.5:
		mode = "idle"
		return Vector3.ZERO
	return _walk_to(home, walk_speed, delta)


# ---------------------------------------------------------------- the fight
func _fight(delta: float) -> Vector3:
	armed = true
	var to := last_seen - global_position
	to.y = 0.0
	var dist := to.length()
	var d := to / dist if dist > 0.01 else facing

	# Right on top of you: club you with the gun. Your guard shoves it off like anything else.
	if sees and dist < melee_range:
		_drop_cover()
		_turn(d, 14.0, delta)
		if _melee_cd <= 0.0:
			_melee_cd = melee_gap
			_bash_cd = 0.5
			player.take_attack(melee_damage, d, 3.0, self)
		return Vector3.ZERO

	# Lost you for a long while: go and look.
	if _unseen_t > lose_time * 3.0:
		_drop_cover()
		mode = "search"
		_search_t = search_time
		return Vector3.ZERO

	if cover_face == null:
		if _cover_cd <= 0.0:
			_cover_cd = 1.2
			_take_cover(_pick_cover(false))
		if cover_face == null:
			return _open_fight(delta, d)

	if not in_cover:
		# On the way to cover: a run, low.
		cover_entering = true
		var sp := Cover.spot(cover_face, cover_t)
		var gap := sp - _xz(global_position)
		_cover_timeout -= delta
		if gap.length() < 0.15:
			in_cover = true
			cover_entering = false
			_u = cover_t
			_duck(randf_range(0.3, 0.9))
			return Vector3.ZERO
		if _cover_timeout <= 0.0:
			_drop_cover()
			return Vector3.ZERO
		_turn(Vector3(gap.x, 0.0, gap.y), 10.0, delta)
		var v := gap.normalized() * minf(run_speed, gap.length() / maxf(delta, 0.001))
		return Vector3(v.x, 0.0, v.y)
	return _cover_fight(delta, d)


func _duck(time := -1.0) -> void:
	_phase = "duck"
	_phase_t = time if time >= 0.0 else randf_range(duck_time.x, duck_time.y)
	cover_mode = "hunker"


## Working a piece of cover: hunker, peek, pop out and fire, back down.
func _cover_fight(delta: float, d: Vector3) -> Vector3:
	var f := cover_face
	var n3 := Vector3(f.n.x, 0.0, f.n.y)
	var here := Cover.spot(f, cover_t)
	_phase_t -= delta
	match _phase:
		"duck":
			cover_mode = "hunker"
			_turn(n3, 8.0, delta)
			if mag <= 0 and _reload_t <= 0.0:
				_reload_t = reload_time
			# You have got round it, and it knows: this cover is no good now.
			if sees and not Cover.shields(f, here, _xz(player.global_position)):
				_drop_cover()
				_cover_cd = 0.0
				return Vector3.ZERO
			if _phase_t <= 0.0 and _reload_t <= 0.0:
				if _unseen_t > lose_time:
					if _blind_left > 0:
						_phase = "blind"
						_phase_t = 1.4
						_shot_cd = 0.4
					else:
						# Fired blind and you still haven't shown: move for an angle past your cover.
						_blind_left = 2
						var c := _pick_cover(true)
						if c.is_empty():
							_duck()
						else:
							_drop_cover()
							_take_cover(c)
				else:
					_phase = "peek"
					_phase_t = 0.4
		"peek":
			cover_mode = "peek"
			_turn(-n3, 10.0, delta)
			if _phase_t <= 0.0:
				if sees or _unseen_t < lose_time:
					_phase = "pop"
					_phase_t = pop_limit
					_aim_t = 0.0
					_burst = randi_range(1, 3)
				else:
					_duck(randf_range(0.6, 1.4))
		"pop":
			cover_mode = "pop"
			_turn(d, 12.0, delta)
			_aim_t += delta
			if _aim_t >= aim_time and _shot_cd <= 0.0 and mag > 0 and _burst > 0 and facing.dot(d) > 0.95:
				_fire(last_seen, 1.0)
				_burst -= 1
			if _burst <= 0 and _shot_cd <= shot_gap * 0.4 or mag <= 0 or _phase_t <= 0.0:
				_duck()
		"blind":
			# Gun up over the cover (or round its end), firing at where it last saw you.
			cover_mode = "hunker"
			cover_blind = true
			_turn(-n3, 10.0, delta)
			if _shot_cd <= 0.0 and mag > 0 and _blind_left > 0:
				_blind_left -= 1
				_blind_t = 0.3
				_fire(last_seen, 2.8)
			if _phase_t <= 0.0 or mag <= 0:
				_duck()

	# Hold the spot, or lean out past the end.
	var want_u := cover_t
	if cover_side != 0 and (cover_mode != "hunker" or cover_blind):
		var out := 0.5 if cover_mode == "pop" or cover_blind else 0.15
		want_u = f.length + out if cover_side > 0 else -out
	_u = move_toward(_u, want_u, 6.0 * delta)
	var gap := f.a + f.dir * _u + f.n * Cover.STANDOFF - _xz(global_position)
	if gap.length() > 1.6:
		_drop_cover()
		return Vector3.ZERO
	var v := (gap / maxf(delta, 0.001)).limit_length(8.0)
	return Vector3(v.x, 0.0, v.y)


## No cover in reach: stand and fight, sidestepping between bursts.
func _open_fight(delta: float, d: Vector3) -> Vector3:
	_turn(d, 12.0, delta)
	_phase_t -= delta
	if _unseen_t > lose_time:
		# Can't see you and nothing to hide behind: close in on where you were.
		return _walk_to(last_seen, walk_speed, delta) if _xz(last_seen - global_position).length() > 3.0 else Vector3.ZERO
	if _phase == "pop":
		_aim_t += delta
		if _aim_t >= aim_time and _shot_cd <= 0.0 and mag > 0 and _burst > 0 and facing.dot(d) > 0.95:
			_fire(last_seen, 1.0)
			_burst -= 1
		if _burst <= 0 and _shot_cd <= shot_gap * 0.4 or mag <= 0 or _phase_t <= 0.0:
			_phase = "duck"
			_phase_t = randf_range(0.8, 1.6)
			_strafe = -_strafe
		return Vector3.ZERO
	if mag <= 0 and _reload_t <= 0.0:
		_reload_t = reload_time
	if _phase_t <= 0.0 and _reload_t <= 0.0:
		_phase = "pop"
		_phase_t = pop_limit
		_aim_t = 0.0
		_burst = randi_range(1, 3)
	return Vector3(-d.z, 0.0, d.x) * _strafe * walk_speed * 0.8


func _fire(at: Vector3, wild: float, zombie: Enemy = null) -> void:
	var to := at - global_position
	to.y = 0.0
	if to.length() < 0.3:
		return
	mag -= 1
	_shot_cd = shot_gap
	_flash_t = 0.06
	# Steadier with Dexterity; wilder when hurt or shaken (the sheet's aim), and much wilder blind.
	var spread := spread_deg * wild * clampf(1.0 - 0.03 * sheet.bonus("dexterity"), 0.6, 1.4) / maxf(sheet.aim_mult, 0.4)
	var shot := Projectile.new()
	shot.dir = to.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-spread, spread)))
	shot.damage = shot_damage
	shot.knock = 1.0
	shot.targets_player = true
	shot.exclude = [get_rid()]
	if zombie != null:
		# At a zombie: a small chance of a headshot, as you have.
		shot.aimed_at = zombie
		shot.headshot_chance = 0.06
	# Its gunfire carries: zombies within earshot come to it.
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en != null and en.kind == "shambler" and en.global_position.distance_to(global_position) <= shot_noise_range:
			en.hear_noise(global_position)
	shot.position = global_position + Vector3(0.0, 1.15, 0.0) + shot.dir * 0.5
	get_parent().add_child(shot)


# ---------------------------------------------------------------- cover
func _drop_cover() -> void:
	in_cover = false
	cover_entering = false
	cover_face = null
	cover_mode = "hunker"
	cover_side = 0


func _take_cover(c: Dictionary) -> void:
	if c.is_empty():
		return
	cover_face = c["face"]
	cover_t = c["t"]
	cover_side = c["side"]
	in_cover = false
	_u = cover_t
	_cover_timeout = _xz(global_position).distance_to(Cover.spot(cover_face, cover_t)) / run_speed * 1.6 + 0.8


## What the body does behind it: the same crouch and lean as the player.
func _pose_for_cover() -> void:
	var crouch := 0.0
	var lean := Vector3.ZERO
	if cover_entering:
		crouch = 0.5
	elif in_cover and cover_face != null:
		if cover_face.low:
			if cover_mode == "hunker":
				crouch = 1.0
			elif cover_mode == "peek":
				crouch = 0.7 if cover_side == 0 else 1.0
			else:
				crouch = 0.0 if cover_side == 0 else 0.75
		if cover_side != 0 and (cover_mode != "hunker" or cover_blind):
			lean = Vector3(cover_face.dir.x, 0.0, cover_face.dir.y) * cover_side * (1.0 if cover_mode == "pop" else 0.7)
	cover_crouch = crouch
	cover_lean_dir = lean


## The best cover for this fight: between it and you, with an angle on you once it pops out, reached by a clear
## straight line, not too near you, not taken. `flank`: also somewhere your own cover doesn't shield you from.
## Returns {"face", "t", "side"} or an empty Dictionary.
func _pick_cover(flank: bool) -> Dictionary:
	var me := _xz(global_position)
	var tgt := _xz(last_seen)
	var space := get_world_3d().direct_space_state
	var best := {}
	var best_score := INF
	for f in Cover.faces:
		var along := (me - f.a).dot(f.dir)
		var off := (me - f.a).dot(f.n)
		if absf(off) > cover_search or along < -cover_search or along > f.length + cover_search:
			continue
		if (tgt - f.a).dot(f.n) > 0.0:
			continue   # you are on its side of this face: no cover from you
		Cover.prep(f)
		# Low cover: anywhere along it, and it comes up over the top. High cover: only an open end to lean round.
		var spots: Array = []
		if f.low:
			spots.append([clampf(along, f.t_min, f.t_max), 0])
		else:
			if f.open[0]:
				spots.append([f.t_min, -1])
			if f.open[1]:
				spots.append([f.t_max, 1])
		for s in spots:
			var t: float = s[0]
			var side: int = s[1]
			var sp := Cover.spot(f, t)
			if f == cover_face and absf(t - cover_t) < 1.0:
				continue
			var walk := me.distance_to(sp)
			var range_to := sp.distance_to(tgt)
			if walk > cover_search or range_to < 4.5 or range_to > sight - 2.0:
				continue
			if not Cover.has_room(sp, f.box) or not Cover.shields(f, sp, tgt):
				continue
			var out := sp
			if side != 0:
				out = f.a + f.dir * (f.length + 0.5 if side > 0 else -0.5) + f.n * Cover.STANDOFF
			if flank and player.in_cover and player.cover_face != null \
					and Cover.shields(player.cover_face, Cover.spot(player.cover_face, player.cover_t), out):
				continue
			if _taken(f, t):
				continue
			var score := walk + absf(range_to - prefer_range) * 0.4
			if score >= best_score:
				continue
			# A clear straight way there (nothing at shin height), and a clear line to you from where it pops out.
			var a3 := global_position + Vector3.UP * 0.4
			var b3 := Vector3(sp.x, global_position.y + 0.4, sp.y)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a3, b3, 1, [get_rid()])).is_empty():
				continue
			var eye := Vector3(out.x, global_position.y + 1.5, out.y)
			var you := Vector3(tgt.x, global_position.y + 1.5, tgt.y)
			if not Projectile.wall_hit(space, eye, you, [get_rid(), player.get_rid()]).is_empty():
				continue
			best_score = score
			best = {"face": f, "t": t, "side": side}
	return best


func _taken(f: Cover.Face, t: float) -> bool:
	for r in get_tree().get_nodes_in_group("raiders"):
		var o := r as Raider
		if o != null and o != self and not o.dead and o.cover_face == f and absf(o.cover_t - t) < 1.2:
			return true
	return false
