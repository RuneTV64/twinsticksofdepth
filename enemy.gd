class_name Enemy
extends CharacterBody3D
## "dummy": stands still, heals after a few seconds, respawns fast. For feeling out aim.
## "shambler": a zombie with the ShamblerMale_Muscular body (zombie_body.gd). Slow, walks straight at you, and
## shoulders doors open the same way you do. Respawns where it started, as a new zombie.
##
## What a shambler can do depends on what it has left:
##   grab    with at least one hand: it reaches, and if your guard isn't up its hands close on you. Held, you're
##           slowed (two hands nearly root you) and it pulls in and bites until you shove it off or wiggle free
##   lunge   with no hands: it crouches and throws itself at you mouth first. Your guard shoves it off
##   crawl   with a leg gone it always crawls. Any of them can be knocked down by a hard hit or a shove and crawl
##           for a while before getting up. Crawlers grab at your ankles and bite
##   heads   a headshot kills; sometimes it takes the head off. The head is still alive on the floor and, rarely,
##           bites whoever steps by it (severed_head.gd)
## How rotted it is changes all of it: slower, more dragging and stumbling, stiff and jerky in rigor, and the
## furthest gone fall apart on their own.

@export var kind := "dummy"
@export var max_hp := 100.0            # dummies; shamblers use shambler_hp
@export var shambler_hp := 50.0        # rotten and fragile: two shots, or a long beating with fists
@export var move_speed := 1.5
@export var aggro_range := 12.0
@export var attack_range := 1.45       # dummies don't attack; kept for tuning other kinds
@export var attack_damage := 10.0
@export var attack_cooldown := 1.3
@export var shambler_respawn := 90.0   # seconds a killed shambler stays gone, so a bullet buys real time
@export var investigate_time := 10.0   # how long a heard noise keeps pulling it in
@export var fade_time := 0.25          # seconds to fade out of (or into) the player's view

@export_group("Zombie abilities")
@export var grab_range := 1.05         # m: how close it has to be to reach for you
@export var grab_windup := 0.5         # s: reaching before the hands close (longer when stiff)
@export var grab_cooldown := 1.8       # s after a grab is shoved off or broken
@export var bite_damage := 15.0
@export var bite_first := 1.0          # s held before the first bite (two hands; one hand takes 1.3x)
@export var bite_interval := 1.5       # s between bites while it holds on
@export var bite_time := 0.35          # s: the bite itself
@export var lunge_range := 1.7         # m: no hands, so it lunges from here
@export var lunge_windup := 0.55
@export var lunge_speed := 4.2         # m/s for the throw
@export var lunge_time := 0.28
@export var lunge_cooldown := 2.2
@export var crawl_speed := 0.45        # m/s, fresh; slower as it rots
@export var knockdown_chance := 0.2    # a hard knock (shot, bash, shove) drops it to crawl
@export var down_time := Vector2(4.0, 9.0)   # s a knocked-down zombie crawls before it gets up
@export var getup_time := 1.3
@export var limb_chance := 0.12        # chance a hit that doesn't kill takes an arm or leg off (rotted parts 2x)
@export var decap_chance := 0.35       # chance a headshot takes the head off (otherwise it just drops)
@export var corpse_time := 30.0        # s a dead zombie lies there before it fades (stand-in for the clean-up lore)
@export var fall_apart_every := 20.0   # s: how often the most rotted get a chance to shed a part on their own

@export_group("Crowd")
## Zombies closer than this (m, centre to centre) push apart; crawlers, lying longer, keep a bit more room.
@export var personal_space := 0.75
## How hard they push apart (m/s at full overlap). Higher packs a horde looser; lower lets it bunch.
@export var separation := 3.0
## Closer than this (m) two zombies are pushed straight back out to it within a tick: bodies don't overlap.
@export var min_gap := 0.55
## Farther than this from the player (m), a zombie that's only walking or crawling thinks and moves every other
## physics tick, covering two ticks each time. Up close, or reaching, holding, biting, lunging or knocked back: every tick.
@export var half_rate_beyond := 14.0

## Microseconds spent on zombies since the crowd readout last read them (main.gd, F5): posing the bodies (each drawn
## frame), and everything a zombie does each physics tick (thinking, moving, colliding).
static var anim_usec := 0
static var zombie_usec := 0

# The crowd grid: every live zombie by 1 m cell, rebuilt once per physics tick by whichever zombie asks first, so
# each one only checks the few zombies in the cells around it.
const CELL := 1.0
static var _grid := {}
static var _grid_frame := -1

var hp := 100.0
var dead := false
var home := Vector3.ZERO
var player: Player

# Read by zombie_body.gd to pose the body.
var facing := Vector3(0, 0, -1)
var state := "walk"      # walk, reach, hold, bite, lunge_wind, lunge, down, getup
var state_t := 0.0       # seconds in the current state
var target := Vector3.ZERO   # world point it reaches or bites toward
var chasing := false
var crawling := false
var hurt_t := 0.0
var hit_dir := Vector3.ZERO
var body: ZombieBody

var _knock := Vector3.ZERO
var _flash := 0.0
var _cd := 0.0
var _since_hit := 99.0
var _dead_t := 0.0
var _corpse_t := 0.0
var _sway := 0.0
var _alpha := 1.0                # 1 = in the player's view, fades to 0 when it isn't
var _noise_pos := Vector3.ZERO   # where the last noise it heard came from
var _noise_t := 0.0              # > 0 while it is still drawn to that spot
var _bite_cd := 0.0
var _bit := false
var _down_t := 0.0
var _apart_t := 0.0
var _pace := 1.0                 # this zombie's own speed, rolled with it
var _soft := Vector3.ZERO        # last push from the crowd around it
var _hard := Vector3.ZERO
var _crowd_slot := randi() % 2   # which ticks it looks up its neighbours (and, far away, thinks and moves)
var _mult := 1.0                 # 2 on a far zombie's tick: it covers two ticks' worth
var _mat: StandardMaterial3D
var _visual: Node3D
var _label: Label3D
var _label_hp := -1              # the number the HP label shows now
var _base_color := Color(0.6, 0.55, 0.4)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	# Zombies don't collide with each other (it's the costliest part of a crowd); they steer apart instead (see
	# _separation). They still collide with walls, doors and the player. Dummies still block everything.
	collision_mask = 1 | 2 | 4 if kind == "dummy" else 1 | 2
	home = global_position
	if kind == "shambler":
		max_hp = shambler_hp
	hp = max_hp
	_sway = randf() * TAU

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	if kind == "shambler":
		body = ZombieBody.new()
		_visual.add_child(body)
		body.piece_spawned.connect(_on_piece)   # cut-off pieces land in the level (see ZombieBody.pieces_parent)
		_new_zombie(false)
	else:
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

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position.y = 2.3
	_label.visible = false
	add_child(_label)


## A fresh roll: who he was, how long dead, what's missing, how he moves.
func _new_zombie(reroll := true) -> void:
	if reroll:   # the first roll happens in shambler.gd's own _ready
		body.new_zombie()
	_pace = randf_range(0.88, 1.12)
	crawling = body.legs() < 2
	_set_state("walk")
	_apart_t = fall_apart_every * randf_range(0.5, 1.5)


func take_hit(dmg: float, dir: Vector3, knock: float) -> void:
	if dead:
		return
	hp -= dmg
	_flash = 0.1
	hurt_t = 0.18
	hit_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_since_hit = 0.0
	var k := 0.25 if kind == "dummy" else 1.0
	_knock += Vector3(dir.x, 0.0, dir.z) * knock * k
	if hp <= 0.0:
		_die()
		return
	if kind != "shambler":
		return
	# Hitting one that has hold of you helps you get loose.
	if (state == "hold" or state == "bite") and player != null:
		player.loosen_grip(0.5)
	if state == "reach" or state == "lunge_wind":
		_set_state("walk")
		_cd = maxf(_cd, 0.6)
	# A hit that doesn't kill can still take an arm or leg off; rotted parts go more easily.
	var limbs: Array[String] = []
	var weights: Array[float] = []
	for slot in ["ArmL", "ArmR", "LegL", "LegR"]:
		var st := body.part(slot)
		if st != "Destroyed":
			limbs.append(slot)
			weights.append(2.0 if st == "Rotted" else 1.0)
	if not limbs.is_empty() and knock > 0.0:
		var total := 0.0
		for w in weights:
			total += w
		if randf() < limb_chance * total / limbs.size():
			var r := randf() * total
			for i in limbs.size():
				r -= weights[i]
				if r <= 0.0:
					_lose(limbs[i], dir * 2.5 + Vector3.UP * 1.5)
					break
	if knock >= 3.0 and randf() < knockdown_chance * (1.0 + body.rot()):
		_knock_down()


## A headshot: always a kill. Sometimes the head comes right off (otherwise it's the pierced-brain death, which
## gets its own look once there are faces).
func take_headshot(dir: Vector3, knock: float) -> void:
	if dead:
		return
	if kind == "shambler" and body.has_head() and randf() < decap_chance:
		hit_dir = dir
		body.dismember("Head", dir * 2.0 + Vector3.UP * 2.5)
	take_hit(hp + 1.0, dir, knock)


## A loud noise (a gunshot) went off at pos. Shamblers walk to where it came from; once you are
## inside aggro_range they chase you as usual. Each new shot refreshes the spot and the timer.
func hear_noise(pos: Vector3) -> void:
	if dead or kind != "shambler":
		return
	_noise_pos = pos
	_noise_t = investigate_time


## You only see an enemy while it's in the player's view; out of it, it fades away (it is
## still there, still moving, still dangerous).
## (Engine properties here are only set when they change: the owner's profiler showed this function as most of the
## script time in a 226-zombie crowd, with every zombie re-setting them every tick.)
func _update_fade(delta: float) -> void:
	var seen := player == null or player.can_see(global_position)
	_alpha = move_toward(_alpha, 1.0 if seen else 0.0, delta / maxf(fade_time, 0.01))
	if body != null:
		var shown := _alpha > 0.02 or _corpse_t > 0.0
		if _visual.visible != shown:
			_visual.visible = shown
		if not dead:
			body.set_fade(_alpha)
		return
	if _visual.visible != (_alpha > 0.02):
		_visual.visible = _alpha > 0.02
	var mode := BaseMaterial3D.TRANSPARENCY_DISABLED if _alpha > 0.99 else BaseMaterial3D.TRANSPARENCY_ALPHA
	if _mat.transparency != mode:
		_mat.transparency = mode


## Shoved back by the player: thrown along dir, no damage, and it needs a moment before it
## can attack again. Its grip, if it had one, is broken. A hard shove can put it on the floor.
func shove(dir: Vector3, force: float) -> void:
	if dead or kind == "dummy":
		return
	_knock += Vector3(dir.x, 0.0, dir.z) * force
	_cd = maxf(_cd, 0.6)
	if state != "down" and state != "getup":
		_let_go()
		_set_state("walk")
	if randf() < knockdown_chance * 0.5 * (1.0 + body.rot()):
		_knock_down()


func _die() -> void:
	dead = true
	hp = 0.0
	collision_layer = 0
	_let_go()
	_label.visible = false
	if body != null:
		_set_state("walk")
		crawling = false
		_corpse_t = corpse_time
		_dead_t = shambler_respawn
	else:
		visible = false
		_dead_t = 2.0


func _respawn() -> void:
	dead = false
	hp = max_hp
	visible = true
	collision_layer = 4
	global_position = home
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	_noise_t = 0.0
	_corpse_t = 0.0
	if body != null:
		body.visible = true
		_new_zombie(true)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _knock_down() -> void:
	if dead or state == "down":
		return
	_let_go()
	crawling = true
	_set_state("down")
	_down_t = randf_range(down_time.x, down_time.y) * (1.0 + body.rot())
	# Going over hard can shake a rotten one apart.
	if randf() < 0.5 * smoothstep(0.6, 1.0, body.rot()):
		_shed_part()


## Lose an arm or a leg: the piece flies off, and a lost leg means crawling from now on.
func _lose(slot: String, impulse: Vector3) -> void:
	body.dismember(slot, impulse)
	if slot.begins_with("Leg"):
		_let_go()
		crawling = true
		if state != "down":
			_set_state("walk")
	elif body.hands() == 0 and (state == "hold" or state == "bite" or state == "reach"):
		_let_go()
		_set_state("walk")


## Falling apart on its own: a rotted limb just comes away.
func _shed_part() -> void:
	var slots: Array[String] = []
	for slot in ["ArmL", "ArmR", "LegL", "LegR"]:
		if body.part(slot) != "Destroyed":
			slots.append(slot)
	if not slots.is_empty():
		_lose(slots[randi() % slots.size()], Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5)))


func _let_go() -> void:
	if player != null:
		player.release_grab(self)


func _on_piece(slot: String, piece: Node) -> void:
	if slot == "Head":
		var h := SeveredHead.new()
		h.player = player
		piece.add_child(h)


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_mult = 1.0
	if _half_rate():
		if (Engine.get_physics_frames() + _crowd_slot) % 2 == 1:
			return   # the other half of the crowd's turn
		_mult = 2.0
	_tick(delta * _mult)
	if body != null:
		zombie_usec += Time.get_ticks_usec() - t0


func _half_rate() -> bool:
	if body == null or dead or player == null or _knock.length_squared() > 0.25:
		return false
	if state != "walk" and state != "down":
		return false
	var d := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z)
	return d.length_squared() > half_rate_beyond * half_rate_beyond


## The body is posed once per drawn frame, not in the physics tick: it's only for looks, and a slow frame then costs
## one posing, not one per physics tick it has to catch up on. zombie_body.gd poses far zombies less often.
func _process(delta: float) -> void:
	if body == null or (dead and _corpse_t <= 0.0):
		return
	var t0 := Time.get_ticks_usec()
	body.animate(self, delta)
	anim_usec += Time.get_ticks_usec() - t0


func _tick(delta: float) -> void:
	_flash -= delta
	_cd -= delta
	hurt_t -= delta
	_since_hit += delta
	state_t += delta
	_update_fade(delta)
	if dead:
		_dead_t -= delta
		if body != null:
			_corpse_t -= delta
			# The corpse lies there, then dithers away.
			body.set_fade(clampf(_corpse_t / 2.0, 0.0, 1.0) * _alpha)
			body.visible = _corpse_t > 0.0
		if _dead_t <= 0.0:
			_respawn()
		return

	var want := Vector3.ZERO
	_noise_t -= delta
	chasing = false
	if kind == "shambler":
		want = _think(delta)
	elif kind == "dummy" and _since_hit > 3.0:
		hp = max_hp

	_knock = _knock.move_toward(Vector3.ZERO, 18.0 * delta)
	if kind == "shambler":
		# Pushed apart by the zombies around it, and held back by those in front: a crowd presses in, it doesn't
		# pour into one spot.
		# Neighbours are looked up every other tick, half the crowd each tick; the soft push carries over between.
		if (Engine.get_physics_frames() + _crowd_slot) % 2 == 0:
			var sep := _separation(delta)
			_soft = sep[0]
			_hard = sep[1]
		else:
			_hard = Vector3.ZERO
		var soft := _soft
		if want != Vector3.ZERO and soft != Vector3.ZERO:
			var wd := want.normalized()
			var blocked := clampf(-soft.dot(wd), 0.0, 1.0)
			want -= wd * want.length() * blocked
		want += soft * separation + _hard
	var horiz := want + _knock
	velocity.x = horiz.x
	velocity.z = horiz.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 25.0 * delta
	if kind == "dummy":
		velocity.x = _knock.x
		velocity.z = _knock.z
	velocity.x *= _mult
	velocity.z *= _mult
	move_and_slide()
	velocity.x /= _mult
	velocity.z /= _mult

	# Shamblers push doors open just like the player does.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col != null and col.has_meta("door"):
			var door: Door = col.get_meta("door")
			var n := get_slide_collision(i).get_normal()
			door.push(global_position, -Vector3(n.x, 0.0, n.z).normalized(), move_speed)

	if body != null:
		_visual.rotation.y = atan2(-facing.x, -facing.z)
	else:
		var col := Color(1, 1, 1) if _flash > 0.0 else _base_color
		col.a = _alpha
		_mat.albedo_color = col
	var show_hp := _since_hit < 2.5 and _alpha > 0.5
	if _label.visible != show_hp:
		_label.visible = show_hp
	if show_hp and _label_hp != ceili(hp):
		_label_hp = ceili(hp)
		_label.text = "%d" % _label_hp


## Away from the zombies crowding this one: [soft, hard]. Soft is 0 when no one is within personal space, growing
## to 1 (and more with several) the closer they are. Hard is the speed that moves it out of any overlap closer than
## min_gap this tick (half the overlap; the other zombie does the other half).
func _separation(delta: float) -> Array:
	var frame := Engine.get_physics_frames()
	if frame != _grid_frame:
		_grid_frame = frame
		_grid.clear()
		for n in get_tree().get_nodes_in_group("enemies"):
			var z := n as Enemy
			if z == null or z.dead or z.kind == "dummy":
				continue
			var k := Vector2i(floori(z.global_position.x / CELL), floori(z.global_position.z / CELL))
			if _grid.has(k):
				_grid[k].append(z)
			else:
				_grid[k] = [z]
	var p := global_position
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	var push := Vector3.ZERO
	var hard := Vector3.ZERO
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell: Array = _grid.get(Vector2i(cx + dx, cz + dz), [])
			for o: Enemy in cell:
				if o == self:
					continue
				var r := personal_space + (0.25 if crawling or o.crawling else 0.0)
				var d := Vector3(p.x - o.global_position.x, 0.0, p.z - o.global_position.z)
				var l2 := d.length_squared()
				if l2 >= r * r:
					continue
				if l2 < 0.0001:
					d = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))   # right on top: any way out
					l2 = d.length_squared()
				var l := sqrt(l2)
				push += d / l * (1.0 - l / r)
				var g := min_gap + (0.2 if crawling or o.crawling else 0.0)
				if l < g:
					hard += d / l * (g - l) * 0.5 / maxf(delta, 0.001)   # (looked up every other tick: catches up over two)
	return [push, hard]


## A shambler's mind: where it wants to go this tick, and what it does when it gets there.
func _think(delta: float) -> Vector3:
	# How decayed he is was worked out once, by the body (ZombieBody.refresh), not here every tick.
	var stiff := body.stiff
	var speed := move_speed * _pace * body.walk_mult
	if crawling:
		speed = crawl_speed * _pace * body.crawl_mult * (0.6 + 0.2 * body.hands())

	# Falling apart: the furthest gone shed parts on their own now and then.
	_apart_t -= delta
	if _apart_t <= 0.0:
		_apart_t = fall_apart_every * randf_range(0.5, 1.5)
		if randf() < body.shed_chance:
			_shed_part()

	if player == null or player.dead:
		if state != "down" and state != "getup":
			_let_go()
			_set_state("walk")
		return Vector3.ZERO

	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var d := to / dist if dist > 0.01 else facing
	chasing = dist < aggro_range
	# Upright it goes for your chest; on the floor, for your legs.
	target = player.global_position + Vector3.UP * (0.25 if crawling else 1.25)

	match state:
		"down":
			# Knocked down: crawls at you for a while, then gets back up if it has the legs for it.
			_down_t -= delta
			if _down_t <= 0.0 and body.legs() == 2:
				crawling = false
				_set_state("getup")
				return Vector3.ZERO
		"getup":
			if state_t >= getup_time * (1.0 + stiff):
				_set_state("walk")
			return Vector3.ZERO
		"reach":
			facing = d
			if state_t >= grab_windup * (1.0 + 0.8 * stiff):
				if dist < grab_range + 0.3 and player.take_grab(self, body.hands()):
					_set_state("hold")
					_bite_cd = bite_first * (1.3 if body.hands() == 1 else 1.0) * (1.0 + 0.5 * stiff)
				else:
					_cd = grab_cooldown
					_set_state("walk")
			return d * speed * 0.2
		"hold", "bite":
			if not player.is_held_by(self) or dist > 2.0:
				_let_go()
				_cd = grab_cooldown
				_set_state("walk")
				return Vector3.ZERO
			facing = d
			if state == "bite":
				if not _bit and state_t >= bite_time * 0.5:
					_bit = true
					player.take_bite(bite_damage, d, self)
				if state_t >= bite_time:
					_set_state("hold")
					_bite_cd = bite_interval * (1.0 + 0.5 * stiff)
			else:
				_bite_cd -= delta
				if _bite_cd <= 0.0 and body.has_head():
					_bit = false
					_set_state("bite")
			# Pull in close and hang on as you drag it along.
			var gap := 0.55 if crawling else 0.7
			return d * clampf((dist - gap) * 4.0, -1.0, 3.0)
		"lunge_wind":
			facing = d
			if state_t >= lunge_windup * (1.0 + 0.8 * stiff):
				_bit = false
				_set_state("lunge")
			return Vector3.ZERO
		"lunge":
			var throw := lunge_speed * (0.45 if crawling else 1.0) * lerpf(1.0, 0.7, body.rot_amt)
			if not _bit and dist < 0.95 and d.dot(facing) > 0.3:
				_bit = true
				player.take_attack(bite_damage, d, 4.0, self)   # your guard shoves it off
			if state_t >= lunge_time:
				_cd = lunge_cooldown
				_set_state("walk")
			return facing * throw

	# Walking (or crawling) toward you, or toward a noise it heard.
	var goal := to
	var going := chasing
	if not chasing and _noise_t > 0.0:
		goal = _noise_pos - global_position
		goal.y = 0.0
		going = true
		if goal.length() < 1.0:
			_noise_t = 0.0   # got there, nothing to find
	if not going or goal.length() < 0.01:
		return Vector3.ZERO
	var gd := goal.normalized()
	facing = facing.slerp(gd, 1.0 - exp(-6.0 * delta)).normalized()
	if chasing and _cd <= 0.0 and body.has_head() and _knock.length() < 0.5:   # has its footing again
		if body.hands() > 0 and dist < grab_range:
			_set_state("reach")
			return Vector3.ZERO
		if body.hands() == 0 and dist < lunge_range * (0.6 if crawling else 1.0):
			_set_state("lunge_wind")
			return Vector3.ZERO
	if chasing and dist < (0.7 if crawling else 0.85):
		return Vector3.ZERO
	_sway += delta * (1.5 if crawling else 3.0)
	var side := Vector3(-gd.z, 0.0, gd.x) * sin(_sway) * (0.15 if crawling else 0.35)
	return (gd + side).normalized() * speed
