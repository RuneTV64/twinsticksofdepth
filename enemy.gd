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
@export var shambler_hp := 50.0        # at the middle of decay. Scaled by rot (see Toughness)
@export_group("Toughness")
# The fresher the body, the more it takes: more damage to put down, a harder skull, steadier on its feet. A
# long-rotted one is fragile on all three. Each pair is fresh .. fully rotted.
@export var hp_by_rot := Vector2(1.7, 0.85)        # times shambler_hp
@export var skull_by_rot := Vector2(0.55, 1.4)     # how much of a blow gets through to the skull
@export var topple_by_rot := Vector2(0.3, 1.8)     # times knockdown_chance
@export_group("")
@export var move_speed := 1.5
@export var aggro_range := 12.0
@export var attack_range := 1.45       # dummies don't attack; kept for tuning other kinds
@export var attack_damage := 10.0
@export var attack_cooldown := 1.3
@export var shambler_respawn := 90.0   # seconds a killed shambler stays gone, so a bullet buys real time
@export var investigate_time := 10.0   # how long a heard noise keeps pulling it in
@export var fade_time := 0.25          # seconds to fade into the player's view
@export var linger_time := 1.2         # s it stays in view after you look away: you remember where it was
@export var fade_out_time := 0.9       # ... then s to fade out (it has moved on by then, which is why it goes)

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

@export_group("Wandering")
# A zombie has no plan, but it has a kind of memory. A sound turns it, and it goes on walking that way for
# minutes, long past where the sound was, until it forgets. One with nothing in its head that sees another on
# the move falls in behind it, and so does the next: that is how a horde forms and travels on its own.
@export var sound_memory := Vector2(120.0, 240.0)   # s it keeps going the way a sound came from
@export var chase_memory := 30.0       # s it keeps going the way its prey went, once it has lost it
@export var wander_speed := 0.75       # its speed when it is only wandering, as a share of its chasing speed
@export var follow_sight := 10.0       # m: how far off it notices another zombie on the move
@export var follow_keep := 0.85        # a follower keeps this much of its leader's purpose (so chains die away)
@export var stuck_forget := 4.0        # walking into something it can't pass, it forgets this many times faster

@export_group("Climbing")
# Zombies get over things by accident, not by plan. One that keeps walking into something it can get its arms over
# drags itself across and tumbles down the far side. Where they are packed densely against something taller, some
# go under the feet of the rest; the fallen (and the dead) make a heap, the rest walk up it, and once it is high
# enough the ones on top can reach the top of the wall and go over. A couple of dozen can clear one storey.
# With hundreds, the heap fills and the ones at the bottom are crushed flat: they stop being zombies and become
# the corpse pile (corpse_pile.gd), which keeps growing and stays. It only happens where zombies are dense.
@export var climb_reach := 1.5         # m: it can drag itself over a top this far above its feet
@export var crawl_reach := 0.6         # ... and this far when it has no legs to stand on
@export var climb_delay := Vector2(0.6, 1.6)   # s pushing at it before it starts over (longer when stiff)
@export var climb_time := 2.2          # s to get over, fresh (longer when stiff, and for a taller climb)
@export var climb_max_depth := 2.6     # m: nothing deeper than this is climbed
@export var heap_step := 0.85          # m: how big a step up it can take onto a heap (two bodies)
@export var heap_boost := 0.3          # m more it can reach when it is on a heap, pushed up from behind
@export var heap_density := 10         # this many zombies within 3 m, and one pushing at the front can go under
@export var heap_chance := 0.2         # ... with this chance every half second, once it has pushed for heap_after
@export var heap_after := 2.0          # s it has to have been pushing first
@export var heap_max := 6              # live bodies deep in one spot (0.24 m each); one more and the bottom one is crushed
@export var tear_join := 0.2           # chance of losing a limb going under the crowd
@export var tear_out := 0.3            # chance, for each limb, of losing it dragging itself out of a heap
@export var tear_over := 0.25          # chance, for each limb, of losing it going over a wall off a heap or pile
@export var max_loose_pieces := 50     # torn-off pieces lying about at once; past this they aren't left behind
@export var mill_after := 3.0          # s stuck before it starts shuffling sideways along what stopped it
@export var mill_speed := 0.5          # m/s
@export var crush_under := 3           # with this many lying on top of it, a body in a heap can be crushed
@export var crush_chance := 0.12       # ... with this chance every half second
@export var crush_hurt := 8.0          # damage to a person right where a zombie goes under or is crushed
@export var skull := 1.0               # how much stomping its head takes (rot softens it)
@export var heap_rest := 3.0           # s with no crowd before the one on top drags itself out
@export var fall_break := 1.8          # m: a drop this far can shake a rotten limb off

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

# The heap: fallen and dead zombies by 0.8 m cell, bottom first. Everyone else walks on top of them.
const HEAP_CELL := 0.8
const HEAP_LAYER := 0.24    # packed: a body lying on bodies adds about this much
static var _heap := {}
static var _heap_n := 0     # bodies in heaps anywhere; 0 = no heap work is done at all
static var _loose := 0      # torn-off pieces lying about now
static var for_pile := false   # set by the corpse pile while it takes a piece for itself

var hp := 100.0
var dead := false
var perch := 0.0            # how far above the ground it is: standing on a heap, lying in one, going over a wall
var _in_heap := false
var _heap_key := Vector2i.ZERO
var _press_t := 0.0         # how long it has been walking into something
var _press_box: Cover.Box = null
var _press_n := Vector3.ZERO
var _climb_wait := 1.0
var _crowd_n := 0           # how many others are pressing round it
var _heap_t := 0.0
var _quiet_t := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_top := 0.0
var _climb_h0 := 0.0
var _climb_len := 2.0
var _shown_y := 0.0
var head_dmg := 0.0         # blows its head has taken from finishers
var _drive := 0.0           # s of purpose left: how long it will go on walking the way it is going
var _heading := Vector3.ZERO   # the way it is going, when it is wandering
var _lead: Enemy = null     # the zombie it has fallen in behind
var _follow_t := randf()      # until it next looks about for one to follow
# Zombies on the move by 8 m cell, looked up by idle ones wondering whom to follow. Rebuilt once a second.
static var _movers := {}
static var _movers_frame := -1000
var _mill := 1.0 if randf() < 0.5 else -1.0
var _mill_t := 0.0
var home := Vector3.ZERO
var player: Player
## Who a zombie is after right now: the player or a raider, whichever living person it has noticed nearest.
## (Anything with the player's grab / bite / attack methods will do.)
var prey = null
var _held = null         # whoever it has hold of
var _prey_t := 0.0

# Read by zombie_body.gd to pose the body.
var facing := Vector3(0, 0, -1)
var state := "walk"      # walk, reach, hold, bite, lunge_wind, lunge, down, getup
var state_t := 0.0       # seconds in the current state
var target := Vector3.ZERO   # world point it reaches or bites toward
var chasing := false
var _was_chasing := false
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
var _out_t := 0.0                # s since it left the player's view
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
	max_hp = shambler_hp * lerpf(hp_by_rot.x, hp_by_rot.y, body.rot())
	hp = max_hp
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
	if (state == "hold" or state == "bite") and _held != null and is_instance_valid(_held):
		_held.loosen_grip(0.5)
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
	if knock >= 3.0 and randf() < knockdown_chance * lerpf(topple_by_rot.x, topple_by_rot.y, body.rot()):
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
func hear_noise(pos: Vector3, _by_player := true) -> void:
	if dead or kind != "shambler":
		return
	_noise_pos = pos
	_noise_t = investigate_time
	# It turns that way, and will go on that way long after it has passed the spot.
	var to := pos - global_position
	to.y = 0.0
	if to.length() > 0.2:
		_heading = to.normalized()
	_drive = maxf(_drive, randf_range(sound_memory.x, sound_memory.y))
	_lead = null


## You only see an enemy while it's in the player's view; out of it, it fades away (it is
## still there, still moving, still dangerous).
## (Engine properties here are only set when they change: the owner's profiler showed this function as most of the
## script time in a 226-zombie crowd, with every zombie re-setting them every tick.)
func _update_fade(delta: float) -> void:
	var seen := player == null or player.can_see(global_position)
	if seen:
		_out_t = 0.0
		_alpha = move_toward(_alpha, 1.0, delta / maxf(fade_time, 0.01))
	else:
		# Out of your view it lingers a moment, as you remember where it was, and then fades.
		_out_t += delta
		if _out_t > linger_time or _alpha < 0.99:
			_alpha = move_toward(_alpha, 0.0, delta / maxf(fade_out_time, 0.01))
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
	if state == "climb" or state == "heap":
		return   # half over a wall, or under a pile of others: there's no shoving it
	_knock += Vector3(dir.x, 0.0, dir.z) * force
	_cd = maxf(_cd, 0.6)
	if state != "down" and state != "getup":
		_let_go()
		_set_state("walk")
	if randf() < knockdown_chance * 0.5 * lerpf(topple_by_rot.x, topple_by_rot.y, body.rot()):
		_knock_down()


func _die() -> void:
	dead = true
	hp = 0.0
	collision_layer = 0
	_let_go()
	# Dying against a wall, or on a heap, it becomes part of the heap until the corpse is gone.
	if body != null and not _in_heap and state != "climb" and (_press_t > 0.5 or perch > 0.1):
		_join_heap()
	_label.visible = false
	if body != null:
		_set_state("walk")
		crawling = false
		_corpse_t = corpse_time
		# With a horde keeping count, the dead stay dead; without one (a bare test scene) they come back.
		_dead_t = corpse_time + 2.0 if Horde.it != null else shambler_respawn
	else:
		visible = false
		_dead_t = 2.0


func _respawn() -> void:
	_leave_heap()
	perch = 0.0
	_press_t = 0.0
	head_dmg = 0.0
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
	if state == "heap" and s != "heap" and not dead:
		_leave_heap()
	state = s
	state_t = 0.0


func _knock_down() -> void:
	if dead or state == "down" or state == "climb" or state == "heap":
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
	if _held != null and is_instance_valid(_held):
		_held.release_grab(self)
	_held = null
	if player != null:
		player.release_grab(self)


func _on_piece(slot: String, piece: Node) -> void:
	# A crush tears off far more than is worth keeping: past a point the pieces just aren't left lying.
	# (Pieces the corpse pile keeps as part of itself don't count: for_pile.)
	if not for_pile:
		if _loose >= max_loose_pieces:
			piece.queue_free()
			return
		_loose += 1
		piece.tree_exited.connect(func() -> void: _loose = maxi(_loose - 1, 0))
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
			if _in_heap:
				if _corpse_t <= 0.0:
					_leave_heap()
				else:
					_settle(delta)
		if _dead_t <= 0.0:
			if Horde.it != null and kind == "shambler":
				_gone()
			else:
				_respawn()
		return

	var want := Vector3.ZERO
	_noise_t -= delta
	chasing = false
	var moving := true
	if kind == "shambler":
		if state == "climb":
			_climb_step()
			moving = false
		elif state == "heap":
			_heap_step(delta)
			moving = false
		else:
			want = _think(delta)
	elif kind == "dummy" and _since_hit > 3.0:
		hp = max_hp
	# Where it means to go, before the crowd pushes it about: what it is "walking into" is judged against this.
	var going := want.normalized() if want.length() > 0.05 else Vector3.ZERO
	var stepped := false
	if (_heap_n > 0 or CorpsePile.it != null) and moving and kind == "shambler":
		# A heap ahead that is too big a step up stops it (and it presses there, like at a wall).
		if going != Vector3.ZERO and heap_height(global_position + going * 0.5) > perch + heap_step:
			want = Vector3.ZERO
			stepped = true
		if perch > 0.05:
			want *= 0.6   # slow going over bodies
	# Stuck against something for a while, it mills about along it, this way then that: no plan to it, but it is
	# how one ends up on the heap its neighbours made.
	if _press_t > mill_after and moving and going != Vector3.ZERO:
		_mill_t -= delta
		if _mill_t <= 0.0:
			_mill_t = randf_range(1.5, 3.5)
			_mill = -_mill if randf() < 0.6 else _mill
		var along := Vector3(-going.z, 0.0, going.x) if _press_box == null else Vector3(-_press_n.z, 0.0, _press_n.x)
		want += along * _mill * mill_speed

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
	var pressed := stepped
	if moving:
		velocity.x *= _mult
		velocity.z *= _mult
		move_and_slide()
		velocity.x /= _mult
		velocity.z /= _mult

		# Shamblers push doors open just like the player does. Anything else solid it is walking into, it presses on.
		_press_box = null
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col == null:
				continue
			var n := get_slide_collision(i).get_normal()
			if col.has_meta("door"):
				var door: Door = col.get_meta("door")
				door.push(global_position, -Vector3(n.x, 0.0, n.z).normalized(), move_speed)
			elif kind == "shambler" and col is StaticBody3D and absf(n.y) < 0.5 and going.dot(-n) > 0.5:
				pressed = true
				_press_box = Cover.box_of(col)
				_press_n = Vector3(n.x, 0.0, n.z).normalized()
	if kind == "shambler" and moving:
		_press(delta, pressed)
		# Standing on a heap, its feet are on the bodies.
		var heaps := _heap_n > 0 or CorpsePile.it != null
		perch = move_toward(perch, heap_height(global_position) if heaps else 0.0, (2.0 if heaps else 4.0) * delta)
	if absf(perch - _shown_y) > 0.004:
		_shown_y = perch
		_visual.position.y = perch

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
	var near := 0
	var packed := perch > 0.1 or _press_t > 1.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell: Array = _grid.get(Vector2i(cx + dx, cz + dz), [])
			for o: Enemy in cell:
				if o == self:
					continue
				if o.state == "heap":
					continue   # the fallen are underfoot, not in the way
				var r := personal_space + (0.25 if crawling or o.crawling else 0.0)
				if packed:
					r *= 0.5   # on the heap, or jammed against what stopped them, they are on top of each other
				var d := Vector3(p.x - o.global_position.x, 0.0, p.z - o.global_position.z)
				var l2 := d.length_squared()
				if l2 < 1.44:
					near += 1
				if l2 >= r * r:
					continue
				if l2 < 0.0001:
					d = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))   # right on top: any way out
					l2 = d.length_squared()
				var l := sqrt(l2)
				push += d / l * (1.0 - l / r)
				var g := (min_gap + (0.2 if crawling or o.crawling else 0.0)) * (0.45 if packed else 1.0)
				if l < g:
					hard += d / l * (g - l) * 0.5 / maxf(delta, 0.001)   # (looked up every other tick: catches up over two)
	_crowd_n = near
	return [push, hard]


# ---------------------------------------------------------------- over things, and over each other
## How high the bodies stand at this spot: the crushed pile, and the live heap on top of it. Zombies and people
## both stand on it.
static func heap_height(p: Vector3) -> float:
	var arr: Array = _heap.get(Vector2i(floori(p.x / HEAP_CELL), floori(p.z / HEAP_CELL)), [])
	return CorpsePile.height_at(p) + arr.size() * HEAP_LAYER


## Where to aim at it: its middle, or its head when it is on the ground (for finishers).
func aim_point() -> Vector3:
	if body != null and not dead and (crawling or state == "down" or state == "heap"):
		return global_position + facing * 0.7
	return global_position


## Is it on the ground, where its head can be stomped?
func is_down() -> bool:
	return body != null and not dead and (crawling or state == "down" or state == "heap") and state != "climb"


## How much of a blow gets through to its skull: little on a fresh body, a lot on a rotted one.
func skull_softness() -> float:
	return lerpf(skull_by_rot.x, skull_by_rot.y, body.rot()) if body != null else 1.0


## A blow to the head while it is down (a stomp, a rifle butt). `power` 1 is enough for a sound skull; rot softens
## it. Returns true if that finished it.
func take_stomp(power: float, dir: Vector3) -> bool:
	if dead:
		return false
	head_dmg += power * skull_softness()
	_flash = 0.1
	hurt_t = 0.18
	_since_hit = 0.0
	if head_dmg >= skull:
		take_hit(hp + 1.0, dir, 0.0)
		return true
	return false


## How many zombies are on their feet within about 3 m: what "densely packed" is measured by. The fallen don't
## count, so a small crowd stops going under once enough of it has.
func _density() -> int:
	var n := 0
	var cx := floori(global_position.x / CELL)
	var cz := floori(global_position.z / CELL)
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			for o: Enemy in _grid.get(Vector2i(cx + dx, cz + dz), []):
				if o.state != "heap":
					n += 1
	return n


## Crushed flat under the rest: no longer a zombie, part of the corpse pile, gone for good.
func _crushed() -> void:
	var key := _heap_key
	_leave_heap()
	_let_go()
	if CorpsePile.crush(key, get_parent(), self):
		_gone()


## Out of the game for good. It is taken out of the crowd grid first, so nothing this tick trips over it.
func _gone() -> void:
	var cell: Array = _grid.get(Vector2i(floori(global_position.x / CELL), floori(global_position.z / CELL)), [])
	cell.erase(self)
	dead = true
	queue_free()


## Lie down in the heap where it stands (fallen, or dead). A full heap crushes the one at its bottom to make
## room. False if nothing more fits there (the pile is as high as it gets).
func _join_heap() -> bool:
	var key := Vector2i(floori(global_position.x / HEAP_CELL), floori(global_position.z / HEAP_CELL))
	var arr: Array = _heap.get(key, [])
	if arr.size() >= heap_max:
		var under: Enemy = arr[0]
		if not CorpsePile.crush(key, get_parent(), under):
			return false
		under._leave_heap()
		under._let_go()
		under._gone()
		arr = _heap.get(key, [])
	arr.append(self)
	_heap[key] = arr
	_heap_key = key
	_heap_n += 1
	_in_heap = true
	# It lands any old way: at any angle, on its front, its side or its back, jammed in among the others.
	facing = facing.rotated(Vector3.UP, randf_range(-PI, PI))
	_visual.rotation.x = randf_range(-0.5, 0.5)
	_visual.rotation.z = randf_range(-1.5, 1.5) if randf() < 0.6 else randf_range(-0.3, 0.3)
	_visual.position.x = randf_range(-0.3, 0.3)
	_visual.position.z = randf_range(-0.3, 0.3)
	return true


func _leave_heap() -> void:
	if not _in_heap:
		return
	_in_heap = false
	_visual.rotation.x = 0.0
	_visual.rotation.z = 0.0
	_visual.position.x = 0.0
	_visual.position.z = 0.0
	_heap_n = maxi(_heap_n - 1, 0)
	var arr: Array = _heap.get(_heap_key, [])
	arr.erase(self)
	if arr.is_empty():
		_heap.erase(_heap_key)


func _exit_tree() -> void:
	_leave_heap()


## A body in the heap lies at its place in the stack, and sinks when one under it goes.
func _settle(delta: float) -> void:
	var arr: Array = _heap.get(_heap_key, [])
	perch = move_toward(perch, CorpsePile.height_at(global_position) + maxi(arr.find(self), 0) * HEAP_LAYER, 2.5 * delta)
	if absf(perch - _shown_y) > 0.004:
		_shown_y = perch
		_visual.position.y = perch


## Walking into something. After a while it goes over, if it can get its arms over the top from where its feet
## are. If it can't, and the crowd behind keeps pressing, sooner or later it goes under them.
func _press(delta: float, pressed: bool) -> void:
	if not pressed or (state != "walk" and state != "down"):
		_press_t = maxf(_press_t - delta * 2.0, 0.0)
		return
	if _press_t <= 0.0:
		_climb_wait = randf_range(climb_delay.x, climb_delay.y) * (1.0 + body.stiff)
	_press_t += delta
	var reach := climb_reach if body.legs() == 2 and not crawling else crawl_reach
	if perch > 0.3:
		reach += heap_boost   # shoved up from below by the ones still coming
	if _press_box != null and _press_t >= _climb_wait and _press_box.top - perch <= reach:
		if _start_climb():
			return
		_press_t = 0.0   # no way over here: keep pushing, look again in a while
	_heap_t -= delta
	if _press_t > heap_after and _heap_t <= 0.0:
		_heap_t = 0.5
		if _crowd_n >= 2 and _density() >= heap_density and randf() < heap_chance:
			if randf() < tear_join:
				_tear(1.0, 1)   # pulled down by an arm or a leg, and it comes off
			if not _join_heap():
				return
			# Down it goes, under the feet of the rest. Anyone it was reaching for is in the crush too.
			_let_go()
			crawling = true
			_quiet_t = 0.0
			_set_state("heap")
			if prey != null and is_instance_valid(prey) and not prey.dead \
					and global_position.distance_to(prey.global_position) < 1.6:
				var push: Vector3 = prey.global_position - global_position
				push.y = 0.0
				prey.take_crush(crush_hurt, push.normalized())


## Start over the thing it is pushing at: across it and down the far side, if there is room to land there.
func _start_climb() -> bool:
	var dir := -_press_n
	var r := _press_box.rect
	var depth := r.size.x if absf(dir.x) > absf(dir.z) else r.size.y
	if depth > climb_max_depth:
		return false
	var land := Vector2(global_position.x, global_position.z) + Vector2(dir.x, dir.z) * (depth + 1.0)
	if not Cover.has_room(land, _press_box):
		return false
	if Cover.bounds.size != Vector2.ZERO and not Cover.bounds.grow(-1.0).has_point(land):
		return false
	_let_go()
	_climb_from = global_position
	_climb_to = Vector3(land.x, global_position.y, land.y)
	_climb_top = _press_box.top
	_climb_h0 = perch
	_climb_len = climb_time * (1.0 + 0.8 * body.stiff) * (0.7 + 0.3 * maxf(_climb_top - perch, 0.3))
	crawling = true
	facing = dir
	_press_t = 0.0
	_set_state("climb")
	return true


## Going over: up onto the top on its belly, across, and off the far edge in a heap.
func _climb_step() -> void:
	var u := clampf(state_t / maxf(_climb_len, 0.1), 0.0, 1.0)
	var p := _climb_from.lerp(_climb_to, smoothstep(0.2, 0.9, u))
	global_position = p
	velocity = Vector3.ZERO
	if u < 0.6:
		perch = lerpf(_climb_h0, _climb_top, smoothstep(0.0, 0.4, u))
	else:
		perch = lerpf(_climb_top, 0.0, smoothstep(0.6, 1.0, u))
	if u >= 1.0:
		perch = 0.0
		_set_state("down")
		_down_t = randf_range(0.8, 2.5)
		# Hauled up over a heap of clutching bodies, it doesn't come away whole.
		if _climb_h0 > 0.3:
			_tear(tear_over, 2)
		# A long drop can shake a rotten one apart.
		if _climb_top >= fall_break and randf() < 0.3 + 0.5 * body.rot():
			_shed_part()


## Each limb it still has comes off with `chance`, up to `most` of them: torn away in the press.
func _tear(chance: float, most: int) -> void:
	var slots: Array[String] = ["ArmL", "ArmR", "LegL", "LegR"]
	slots.shuffle()
	var n := 0
	for slot in slots:
		if n >= most:
			return
		if body.part(slot) != "Destroyed" and randf() < chance:
			_lose(slot, Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0)))
			n += 1


## Lying in the heap. The one on top drags itself out once the crowd has gone.
func _heap_step(delta: float) -> void:
	_settle(delta)
	# Still trying to get where it was going: it claws and kicks where it lies (the body poses from this).
	velocity = facing * (0.3 + 0.2 * sin(state_t * 2.3 + _sway))
	_heap_t -= delta
	if _heap_t > 0.0:
		return
	_heap_t = 0.5
	var arr: Array = _heap.get(_heap_key, [])
	if arr.is_empty() or arr[arr.size() - 1] != self:
		_quiet_t = 0.0
		# Others on top of it. With enough of them, sooner or later the weight crushes it.
		if arr.size() - 1 - arr.find(self) >= crush_under and randf() < crush_chance:
			_crushed()
		return
	var crowd := false
	var cx := floori(global_position.x / CELL)
	var cz := floori(global_position.z / CELL)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for o: Enemy in _grid.get(Vector2i(cx + dx, cz + dz), []):
				if o != self and is_instance_valid(o) and o.state != "heap" and not o.dead:
					crowd = true
	_quiet_t = 0.0 if crowd else _quiet_t + 0.5
	if _quiet_t >= heap_rest:
		_set_state("down")
		_down_t = randf_range(0.4, 1.2)
		_tear(tear_out, 2)   # it drags itself out, leaving some of itself behind


## A shambler's mind: where it wants to go this tick, and what it does when it gets there.
const HIDDEN_NOTICE := 0.35   # someone hunkered behind cover is noticed at this much of the usual range


## With nothing in its head, it looks about once a second for another zombie that is going somewhere, and falls
## in behind the nearest one it can see. It only follows one with more purpose than its own, so chains never loop
## and die away down their length.
func _look_about(delta: float) -> void:
	_follow_t -= delta
	if _follow_t > 0.0:
		return
	_follow_t = 1.0
	var frame := Engine.get_physics_frames()
	if frame - _movers_frame >= 60:
		_movers_frame = frame
		_movers.clear()
		for n in get_tree().get_nodes_in_group("enemies"):
			var z := n as Enemy
			if z.kind != "shambler" or z.dead or z._drive < 10.0 or z.state != "walk":
				continue
			var k := Vector2i(floori(z.global_position.x / 8.0), floori(z.global_position.z / 8.0))
			if _movers.has(k):
				_movers[k].append(z)
			else:
				_movers[k] = [z]
	var cx := floori(global_position.x / 8.0)
	var cz := floori(global_position.z / 8.0)
	var best: Enemy = null
	var best_d := follow_sight
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for o: Enemy in _movers.get(Vector2i(cx + dx, cz + dz), []):
				if o == self or not is_instance_valid(o) or o.dead:
					continue
				var to := o.global_position - global_position
				to.y = 0.0
				var dd := to.length()
				if dd < best_d and dd > 0.3 and facing.dot(to / dd) > -0.3:
					best_d = dd
					best = o
	if best == null:
		return
	# It has to be able to see it.
	var eye := Vector3.UP * 1.4
	var q := PhysicsRayQueryParameters3D.create(global_position + eye, best.global_position + eye, 1, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	_lead = best
	_drive = best._drive * follow_keep
	_heading = (best.global_position - global_position).normalized()
	_heading.y = 0.0


## Pick who to go for: the nearest living person it has noticed, you or a raider. With no one noticed it keeps
## the player in mind (it still comes to noises), as before raiders existed.
func _pick_prey() -> void:
	var best = null
	var best_d := INF
	if player != null and not player.dead:
		var dp := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		var notice := aggro_range * (HIDDEN_NOTICE if player.in_cover and player.hidden_from(global_position) else 1.0)
		if dp < notice:
			best = player
			best_d = dp
	for r in get_tree().get_nodes_in_group("raiders"):
		if r.dead:
			continue
		var dr := Vector2(r.global_position.x - global_position.x, r.global_position.z - global_position.z).length()
		var notice_r := aggro_range * (HIDDEN_NOTICE if r.hidden_from(global_position) else 1.0)
		if dr < notice_r and dr < best_d:
			best = r
			best_d = dr
	if best == null and player != null and not player.dead:
		best = player
	prey = best


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

	# Who it is after is looked up twice a second, and only while it is free to change its mind.
	_prey_t -= delta
	if _prey_t <= 0.0 and (state == "walk" or state == "down"):
		_prey_t = 0.5
		_pick_prey()
	if prey != null and not is_instance_valid(prey):
		prey = null
	if prey == null or prey.dead:
		_prey_t = 0.0
		if state != "down" and state != "getup":
			_let_go()
			_set_state("walk")
		return Vector3.ZERO

	var to: Vector3 = prey.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var d := to / dist if dist > 0.01 else facing
	# Hunkered behind cover, out of its sight, it only notices you from much closer. One that was already after
	# you goes to where it last saw you.
	var notice := aggro_range
	if prey.in_cover and prey.hidden_from(global_position):
		notice *= HIDDEN_NOTICE
	chasing = dist < notice
	if _was_chasing and not chasing:
		hear_noise(prey.global_position)
	_was_chasing = chasing
	# Upright it goes for your chest; on the floor, for your legs.
	target = prey.global_position + Vector3.UP * (0.25 if crawling else 1.25)

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
				if dist < grab_range + 0.3 and prey.take_grab(self, body.hands()):
					_held = prey
					_set_state("hold")
					_bite_cd = bite_first * (1.3 if body.hands() == 1 else 1.0) * (1.0 + 0.5 * stiff)
				else:
					_cd = grab_cooldown
					_set_state("walk")
			return d * speed * 0.2
		"hold", "bite":
			if not prey.is_held_by(self) or dist > 2.0:
				_let_go()
				_cd = grab_cooldown
				_set_state("walk")
				return Vector3.ZERO
			facing = d
			if state == "bite":
				if not _bit and state_t >= bite_time * 0.5:
					_bit = true
					prey.take_bite(bite_damage, d, self)
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
				prey.take_attack(bite_damage, d, 4.0, self)   # your guard shoves it off
			if state_t >= lunge_time:
				_cd = lunge_cooldown
				_set_state("walk")
			return facing * throw

	# Walking (or crawling) toward you; or, with no one in sight, wherever its memory is taking it.
	var goal := to
	var going := chasing
	if chasing:
		# While it has prey it is the most purposeful thing about: others fall in behind it. When it loses the
		# prey it carries on the way it was going for a while.
		_heading = d
		_drive = maxf(_drive, chase_memory)
		_lead = null
	else:
		if _drive <= 0.0:
			_look_about(delta)
		if _drive > 0.0:
			_drive -= delta * (stuck_forget if _press_t > 3.0 else 1.0)
			speed *= wander_speed
			going = true
			if _lead != null and (not is_instance_valid(_lead) or _lead.dead
					or _lead.global_position.distance_to(global_position) > follow_sight * 1.5):
				_lead = null   # lost the one it was behind: it carries on the same way
			if _lead != null:
				# Behind another zombie: toward it, and once close, the way it is going.
				goal = _lead.global_position - global_position
				goal.y = 0.0
				if goal.length() < 1.8:
					goal = _lead._heading if _lead._heading != Vector3.ZERO else _lead.facing
				_heading = goal.normalized()
				_drive = maxf(_drive, _lead._drive * follow_keep)
			elif _noise_t > 0.0:
				# Toward the sound itself first.
				goal = _noise_pos - global_position
				goal.y = 0.0
				_noise_t -= delta
				if goal.length() < 1.5:
					_noise_t = 0.0   # got there, nothing to find: it keeps going the same way
				else:
					_heading = goal.normalized()
			if _lead == null and _noise_t <= 0.0:
				goal = _heading * 4.0
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
