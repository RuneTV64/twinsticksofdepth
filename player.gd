class_name Player
extends CharacterBody3D
## Two stances:
##  WEAPON AWAY (default): face where you walk. Right stick / mouse moves a crosshair and the
##    camera pans to keep it centered; your facing doesn't change. Let go and the camera
##    returns to you and the crosshair hides. Attack button = Interact. Hold Sprint to run.
##  READY (hold LT / right-click / Q): twin-stick. Right stick / mouse sets facing, the camera
##    leads toward the aim point. Attack button attacks. Slower, no running (dash still works).
## Doors work in either stance: walk into them to push them, run or dash into them to barge.

# ---------- Stats (there is no speed stat: speed comes from these three) ----------
@export var strength := 10.0
@export var endurance := 10.0
@export var weight := 8.0
@export var dexterity := 10.0           # aimed-shot damage and headshot chance

# Derived in recompute_stats()
var walk_speed := 4.6
var ready_speed := 3.0
var run_speed := 6.7
var dash_speed := 12.0
var dash_time := 0.18
var max_stamina := 100.0
var stamina_regen := 25.0
var run_drain := 14.0
var dash_cost := 20.0
var barge_min_speed := 5.3

# ---------- Feel tuning ----------
@export var base_walk_speed := 4.6      # walk speed at default stats, before burden/fitness
@export var run_mult := 1.45            # run = walk x this
@export var accel := 26.0               # lower = heavier start-up
@export var decel := 30.0               # lower = longer slide to a stop
@export var turn_speed := 14.0          # rad/s, weapon away
@export var ready_turn_speed := 28.0    # rad/s, Ready on a stick (mouse aim is instant)
@export var backpedal_mult := 0.75      # Ready: speed when moving directly away from aim
@export var draw_time := 0.12         # Ready pressed -> can attack
@export var sprint_tap_time := 0.22     # release Sprint before this = dash, hold past it = run
@export var look_range := 8.0           # weapon away: how far the crosshair can roam
@export var aim_range := 10.0           # Ready: max reticle distance
@export var aim_min_dist := 0.3         # Ready: reticle closer than this doesn't turn you
@export var aim_stick_speed := 20.0     # Ready: reticle speed on the stick (m/s)
@export var ready_cam_lead := 0.45     # Ready: how far the camera leans toward the reticle
@export var stick_look_speed := 14.0  # weapon away: crosshair speed on the stick (m/s)
@export var mouse_sens := 0.022         # world meters per mouse pixel
@export var mouse_idle_hide := 1.2      # weapon away: idle mouse crosshair hides after this
@export var interact_range := 1.9
@export var max_health := 100.0

# ---------- Fatigue: low stamina slows all movement ----------
@export var fatigue_start := 0.5        # stamina fraction where you start slowing down
@export var fatigue_min_speed := 0.65   # speed multiplier at zero stamina
@export var fatigue_min_accel := 0.6    # accel multiplier at zero stamina (sluggish starts)

# ---------- Weapon (placeholder ranged weapon; tech level is still open) ----------
@export var mag_size := 8
@export var fire_interval := 0.2
@export var reload_time := 1.1
@export var shot_damage := 25.0
@export var shot_speed := 140.0         # m/s; fast enough to read as a gunshot, not a thrown bolt
@export var shot_kick := 2.6            # m/s shoved backward per shot
@export var shot_cam_kick := 0.3        # meters the camera jolts back per shot
@export var bash_damage := 12.0

# ---------- Aimed shots (reticle red on the enemy you hit) ----------
@export var aim_bonus_per_dex := 0.03          # +3% aimed damage per point of DEX
@export var aim_bonus_per_firepower := 0.008   # +0.8% aimed damage per point of weapon damage
@export var headshot_per_dex := 0.008          # +0.8% headshot chance per point of DEX
@export var headshot_per_firepower := 0.002    # +0.2% headshot chance per point of weapon damage
@export var headshot_max_chance := 0.6

var health := 100.0
var stamina := 100.0
var winded := false
var running := false
var armed := false
var using_pad := false
var dead := false
var mag := 8
var reserve := 16
var facing := Vector3(0, 0, -1)

var camera_rig: CamRig
var spawn_point := Vector3.ZERO
var reticle_offset := Vector3.ZERO
var reticle_visible := false
var reticle_on_enemy := false
var reticle_target: Enemy = null   # the enemy under the reticle (Ready only counts as "aimed")
var aimed_mult := 1.5              # derived: damage multiplier for a shot aimed at its target
var headshot_chance := 0.13        # derived: chance an aimed hit is a one-shot kill
var interact_target: Node = null
var status_text := ""
var shots_fired := 0
var last_shot := "-"
var status_t := 0.0

var _draw_t := 0.0
var _fire_cd := 0.0
var _reload_t := 0.0
var _regen_delay := 0.0
var _sprint_t := -1.0
var _dash_t := 0.0
var _dash_dir := Vector3.ZERO
var _stagger := 0.0
var _barge_cd := 0.0
var _bash_cd := 0.0
var _mouse_idle := 99.0
var _hurt_t := 0.0
var _heal_delay := 0.0
var _respawn_t := 0.0
var _locked_msg_cd := 0.0
var _flash_t := 0.0
var _lmb_edge := false   # a left-click arrived since the last physics tick
var _rmb_event := false  # right button state as last reported by a mouse event
var _lmb_event := false
var _has_mouse := DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE)

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _weapon: MeshInstance3D
var _weapon_mat: StandardMaterial3D
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.25, 0.45, 0.85)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	body.mesh = cm
	body.material_override = _body_mat
	body.position.y = 0.9
	_visual.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.28, 0.14, 0.3)
	nose.mesh = nm
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.1, 0.12, 0.2)
	nose.material_override = nose_mat
	nose.position = Vector3(0, 1.5, -0.38)
	_visual.add_child(nose)

	_weapon = MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.12, 0.12, 0.85)
	_weapon.mesh = wm
	_weapon_mat = StandardMaterial3D.new()
	_weapon_mat.albedo_color = Color(0.35, 0.3, 0.25)
	_weapon_mat.emission_enabled = true
	_weapon_mat.emission = Color(1.0, 0.8, 0.3)
	_weapon_mat.emission_energy_multiplier = 0.0
	_weapon.material_override = _weapon_mat
	_visual.add_child(_weapon)

	_reticle = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.42
	tm.rings = 24
	tm.ring_segments = 6
	_reticle.mesh = tm
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.no_depth_test = true
	_reticle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticle_mat.render_priority = 10
	_reticle.material_override = _reticle_mat
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.top_level = true
	add_child(_reticle)

	recompute_stats()
	_reset_vitals()


## Defaults (STR 10 / END 10 / WT 8) give walk 4.6, run 6.7, 100 stamina.
##  - burden = weight / strength. Carrying more than your frame handles slows you.
##  - endurance = stamina pool, regen, and a small bump to top speed.
##  - weight makes runs and dashes cost more, and dashes shorter.
func recompute_stats() -> void:
	strength = maxf(strength, 1.0)
	endurance = maxf(endurance, 1.0)
	weight = maxf(weight, 1.0)
	var burden := weight / strength
	var mobility := clampf(1.0 - 0.4 * (burden - 0.8), 0.55, 1.25)
	var fitness := 1.0 + 0.02 * (endurance - 10.0)
	walk_speed = base_walk_speed * mobility * fitness
	ready_speed = walk_speed * 0.65
	run_speed = walk_speed * (run_mult + 0.01 * (endurance - 10.0))
	max_stamina = 60.0 + endurance * 4.0
	stamina_regen = 10.0 + endurance * 1.5
	run_drain = 14.0 * (0.6 + 0.5 * burden)
	dash_cost = 20.0 * (0.7 + 0.4 * burden)
	dash_speed = run_speed * 1.8
	dash_time = 0.18 * clampf(1.15 - 0.2 * burden, 0.6, 1.1)
	barge_min_speed = walk_speed * 1.15
	# Aimed shots: dexterity and the weapon's firepower both raise the bonus and the headshot odds.
	# Defaults (DEX 10, 25 damage) give x1.5 damage and a 13% headshot chance.
	dexterity = maxf(dexterity, 1.0)
	aimed_mult = 1.0 + dexterity * aim_bonus_per_dex + shot_damage * aim_bonus_per_firepower
	headshot_chance = clampf(dexterity * headshot_per_dex + shot_damage * headshot_per_firepower,
		0.0, headshot_max_chance)
	stamina = minf(stamina, max_stamina)


## Strength + weight behind the hit, scaled by how fast you were going (dash hits hardest).
func barge_power(speed: float) -> float:
	return (strength + weight) * clampf(speed / run_speed, 0.0, 1.6)


## 0 = fresh, 1 = completely spent. Starts climbing once stamina drops below fatigue_start.
func fatigue() -> float:
	if max_stamina <= 0.0 or fatigue_start <= 0.0:
		return 0.0
	return 1.0 - clampf((stamina / max_stamina) / fatigue_start, 0.0, 1.0)


func camera_focus() -> Vector3:
	var f := global_position
	if dead:
		return f
	if armed:
		f += reticle_offset * ready_cam_lead
	elif reticle_visible:
		f += reticle_offset
	return f


func show_status(text: String, dur := 1.6) -> void:
	status_text = text
	status_t = dur


func add_ammo(n: int) -> void:
	reserve += n
	show_status("+%d ammo" % n)


# ======================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		# Every mouse event (motion too) carries which buttons are held. Some systems drop the
		# second click while one button is already held, so track the mask ourselves.
		var mask: int = event.button_mask
		var l := (mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if l and not _lmb_event:
			_lmb_edge = true
		_lmb_event = l
		_rmb_event = (mask & MOUSE_BUTTON_MASK_RIGHT) != 0
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _lmb_event:
				_lmb_edge = true
			_lmb_event = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_event = event.pressed
	if event is InputEventMouseMotion:
		using_pad = false
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dead:
			var rel: Vector2 = event.relative
			reticle_offset += Vector3(rel.x, 0.0, rel.y) * mouse_sens
			reticle_offset = reticle_offset.limit_length(aim_range if armed else look_range)
			_mouse_idle = 0.0
	elif event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if dead:
		_respawn_t -= delta
		velocity = Vector3.ZERO
		if _respawn_t <= 0.0:
			_respawn()
		_update_visuals(delta)
		return

	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(mv.x, 0.0, mv.y)
	if _stagger > 0.0:
		move_dir = Vector3.ZERO

	_update_stance()
	_update_aim(delta)
	_update_sprint(delta, move_dir)

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if _dash_t > 0.0:
		horiz = _dash_dir * dash_speed
	elif _stagger > 0.0:
		horiz = horiz.move_toward(Vector3.ZERO, decel * 0.4 * delta)
	else:
		var spd := walk_speed
		if armed:
			var back := (move_dir.normalized().dot(facing) + 1.0) * 0.5   # 0 = straight back
			spd = ready_speed * lerpf(backpedal_mult, 1.0, back)
		elif running:
			spd = run_speed
		var tired := fatigue()
		spd *= lerpf(1.0, fatigue_min_speed, tired)
		var want := move_dir * spd
		var rate := decel
		if want.length() > 0.01:
			rate = accel * lerpf(1.0, fatigue_min_accel, tired)
		horiz = horiz.move_toward(want, rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 25.0 * delta

	var pre_vel := horiz
	move_and_slide()
	_handle_collisions(pre_vel)

	_update_facing(delta, move_dir)
	_update_combat()
	_update_interact()
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_draw_t -= delta
	_fire_cd -= delta
	_dash_t -= delta
	_stagger -= delta
	_barge_cd -= delta
	_bash_cd -= delta
	_hurt_t -= delta
	_flash_t -= delta
	_locked_msg_cd -= delta
	_mouse_idle += delta
	status_t -= delta
	_heal_delay -= delta
	if not dead and _heal_delay <= 0.0 and health < max_health:
		health = minf(health + 4.0 * delta, max_health)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var n := mini(mag_size - mag, reserve)
			mag += n
			reserve -= n


# ---------------------------------------------------------------- stance + aim
func _update_stance() -> void:
	var want_ready := ready_held()
	if want_ready and not armed:
		armed = true
		running = false
		_draw_t = draw_time
		# The reticle always starts on you and is moved out from there. Facing holds until
		# it has been pushed far enough to give a direction (see aim_min_dist).
		reticle_offset = Vector3.ZERO
	elif not want_ready and armed:
		armed = false
		_reload_t = 0.0   # putting it away cancels a reload
		reticle_offset = Vector3.ZERO
		_mouse_idle = 99.0


func _update_aim(delta: float) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.2)
	var stick3 := Vector3(stick.x, 0.0, stick.y)
	if stick.length() > 0.3:
		using_pad = true

	if armed:
		if using_pad:
			# The stick pushes the reticle out from you like a cursor (it never jumps to a
			# distance). It stays where you leave it until Ready is released.
			if stick.length() > 0.05:
				reticle_offset += stick3 * aim_stick_speed * delta
		reticle_offset = reticle_offset.limit_length(aim_range)
		reticle_visible = true
	else:
		if using_pad:
			reticle_visible = stick.length() > 0.05
			if reticle_visible:
				reticle_offset += stick3 * stick_look_speed * delta
		else:
			reticle_visible = _mouse_idle < mouse_idle_hide
		if not reticle_visible:
			reticle_offset = Vector3.ZERO
		reticle_offset = reticle_offset.limit_length(look_range)

	# Reticle turns red over an enemy.
	reticle_on_enemy = false
	reticle_target = null
	if reticle_visible:
		var rp := global_position + reticle_offset
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Enemy
			if en and not en.dead:
				var d := en.global_position - rp
				d.y = 0.0
				if d.length() < 0.95:
					reticle_on_enemy = true
					reticle_target = en
					break


func _update_facing(delta: float, move_dir: Vector3) -> void:
	var want := Vector3.ZERO
	var rate := turn_speed
	if armed:
		want = reticle_offset
		rate = ready_turn_speed
	elif _dash_t > 0.0:
		want = _dash_dir
	elif move_dir.length() > 0.1:
		want = move_dir
	# In Ready, a reticle sitting on (or very near) you gives no direction: keep facing as is.
	if want.length() < (aim_min_dist if armed else 0.01):
		return
	want = want.normalized()
	if armed and not using_pad:
		facing = want
	else:
		facing = _turn_toward(facing, want, rate * delta)


func _turn_toward(from: Vector3, to: Vector3, step: float) -> Vector3:
	var a := atan2(from.x, from.z)
	var b := atan2(to.x, to.z)
	a += clampf(wrapf(b - a, -PI, PI), -step, step)
	return Vector3(sin(a), 0.0, cos(a))


# ---------------------------------------------------------------- stamina, run, dash
func _update_sprint(delta: float, move_dir: Vector3) -> void:
	if Input.is_action_just_pressed("sprint"):
		_sprint_t = 0.0
	if _sprint_t >= 0.0:
		if Input.is_action_pressed("sprint"):
			_sprint_t += delta
		else:
			if _sprint_t <= sprint_tap_time:
				_try_dash(move_dir)
			_sprint_t = -1.0

	var want_run := _sprint_t > sprint_tap_time and not armed and move_dir.length() > 0.1 \
		and not winded and _stagger <= 0.0
	running = want_run and stamina > 0.0
	if running:
		stamina = maxf(stamina - run_drain * delta, 0.0)
		_regen_delay = 0.8
		if stamina <= 0.0:
			winded = true
			running = false
			show_status("Winded!", 1.2)
	else:
		_regen_delay -= delta
		if _regen_delay <= 0.0 and _dash_t <= 0.0:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
	if winded and stamina >= max_stamina * 0.35:
		winded = false


func _try_dash(move_dir: Vector3) -> void:
	if winded or _dash_t > 0.0 or _stagger > 0.0 or stamina < dash_cost * 0.5:
		if winded:
			show_status("Too winded to dash", 0.8)
		return
	_dash_dir = move_dir if move_dir.length() > 0.1 else facing
	_dash_dir = _dash_dir.normalized()
	_dash_t = dash_time
	stamina = maxf(stamina - dash_cost, 0.0)
	_regen_delay = 0.8
	if stamina <= 0.0:
		winded = true


# ---------------------------------------------------------------- doors / barging
func _handle_collisions(pre_vel: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col == null or not col.has_meta("door"):
			continue
		var door: Door = col.get_meta("door")
		var n := c.get_normal()
		var into := -Vector3(n.x, 0.0, n.z)
		if into.length() < 0.01:
			continue
		into = into.normalized()
		var spd := pre_vel.dot(into)
		if spd >= barge_min_speed and _barge_cd <= 0.0 and door.is_shut():
			_barge(door, spd, into)
			return
		if spd > 0.4:
			if not door.push(global_position, into, spd) and _locked_msg_cd <= 0.0:
				show_status("Won't budge. Run or dash into it to barge it open.", 2.0)
				_locked_msg_cd = 2.5


func _barge(door: Door, spd: float, into: Vector3) -> void:
	_barge_cd = 0.6
	_dash_t = 0.0
	var power := barge_power(spd)
	var need := door.resistance()
	if door.barge(power, global_position, into):
		var hurt := 3.0 + need * 0.2
		take_damage(hurt, Vector3.ZERO, 0.0)
		velocity = into * spd * 0.55     # keep some momentum through the doorway
		_stagger = 0.12
		show_status("BAM! Barged through  (power %d vs %d, -%d HP)" % [roundi(power), roundi(need), roundi(hurt)], 2.0)
	else:
		var hurt := 5.0 + need * 0.35
		take_damage(hurt, -into, 5.0)
		_stagger = 0.45
		show_status("Oof. It held  (power %d vs %d, -%d HP)" % [roundi(power), roundi(need), roundi(hurt)], 2.2)


# ---------------------------------------------------------------- combat + interact
## Ready = right mouse button (read three ways), LT, or Q.
func ready_held() -> bool:
	if Input.is_action_pressed("ready_weapon"):
		return true
	return _rmb_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or (_has_mouse and (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_RIGHT) != 0)


## Attack / Interact = left mouse button (read three ways), RT, or A.
func attack_held() -> bool:
	if Input.is_action_pressed("attack"):
		return true
	return _lmb_event or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or (_has_mouse and (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) != 0)


var _attack_was_held := false
var attack_tapped := false


func _update_combat() -> void:
	var held := attack_held()
	attack_tapped = Input.is_action_just_pressed("attack") or _lmb_edge or (held and not _attack_was_held)
	_attack_was_held = held
	_lmb_edge = false
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	if armed:
		if _draw_t > 0.0 or _stagger > 0.0 or _reload_t > 0.0:
			return
		if attack_held() and _fire_cd <= 0.0:
			if mag > 0:
				_fire()
			elif reserve > 0:
				_start_reload()
			elif attack_tapped:
				_bash()
	elif attack_tapped and interact_target != null:
		interact_target.call("interact", self)


func _start_reload() -> void:
	if _reload_t > 0.0 or mag >= mag_size:
		return
	if reserve <= 0:
		show_status("No ammo. Find some, or bash (attack with an empty weapon).", 1.8)
		return
	_reload_t = reload_time
	show_status("Reloading...", reload_time)


func _fire() -> void:
	mag -= 1
	_fire_cd = fire_interval
	_flash_t = 0.06
	var shot := Projectile.new()
	shot.dir = facing
	shot.speed = shot_speed
	shot.damage = shot_damage
	shot.exclude = [get_rid()]
	shot.shooter = self
	# Fired with the reticle on an enemy: the shot is "aimed" at that enemy.
	if reticle_target != null:
		shot.aimed_at = reticle_target
		shot.aimed_mult = aimed_mult
		shot.headshot_chance = headshot_chance
	shots_fired += 1
	print("[fire] #%d dir %s mag %d" % [shots_fired, facing, mag])
	shot.position = global_position + Vector3(0.0, 1.1, 0.0) + facing * 0.3
	get_parent().add_child(shot)
	velocity -= facing * shot_kick
	if camera_rig:
		camera_rig.kick(-facing * shot_cam_kick)
	if mag == 0 and reserve > 0:
		_start_reload()


func _bash() -> void:
	if _bash_cd > 0.0:
		return
	_bash_cd = 0.5
	_fire_cd = 0.5
	show_status("Out of ammo - bash!", 0.8)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < 1.8 and to.normalized().dot(facing) > 0.4:
			en.take_hit(bash_damage, facing, 7.0)


func _update_interact() -> void:
	interact_target = null
	var best := interact_range
	for n in get_tree().get_nodes_in_group("interactables"):
		if not n.call("can_interact", self):
			continue
		var p: Vector3 = n.call("interact_point")
		var d := p - global_position
		d.y = 0.0
		if d.length() < best:
			best = d.length()
			interact_target = n


func interact_prompt() -> String:
	if interact_target == null:
		return ""
	var txt: String = interact_target.call("prompt_text", self)
	if armed:
		return "%s  (lower your weapon)" % txt
	return "[%s]  %s" % ["RT" if using_pad else "Left-click", txt]


# ---------------------------------------------------------------- health
func take_damage(amount: float, dir: Vector3, knock: float) -> void:
	if dead:
		return
	health -= amount
	_hurt_t = 0.15
	_heal_delay = 5.0
	if knock > 0.0:
		velocity += dir * knock
		_stagger = maxf(_stagger, 0.15)
	if health <= 0.0:
		health = 0.0
		dead = true
		armed = false
		_respawn_t = 2.5
		show_status("You went down. Respawning...", 2.5)


func _respawn() -> void:
	dead = false
	global_position = spawn_point
	velocity = Vector3.ZERO
	_reset_vitals()
	if camera_rig:
		camera_rig.snap()


func _reset_vitals() -> void:
	health = max_health
	stamina = max_stamina
	winded = false
	mag = mag_size
	reserve = 16
	_reload_t = 0.0


# ---------------------------------------------------------------- visuals
func _update_visuals(_delta: float) -> void:
	_visual.visible = not dead
	_visual.rotation.y = atan2(-facing.x, -facing.z)
	if armed:
		_weapon.position = Vector3(0.28, 1.1, -0.55)
		_weapon.rotation = Vector3.ZERO
	else:
		_weapon.position = Vector3(0.0, 1.25, 0.45)
		_weapon.rotation = Vector3(deg_to_rad(65.0), 0.0, deg_to_rad(20.0))
	_weapon_mat.emission_energy_multiplier = 4.0 if _flash_t > 0.0 else 0.0

	var base := Color(0.25, 0.45, 0.85)
	if _hurt_t > 0.0:
		base = Color(1.0, 0.35, 0.3)
	elif _dash_t > 0.0:
		base = Color(0.6, 0.85, 1.0)
	_body_mat.albedo_color = base

	_reticle.visible = reticle_visible and not dead
	_reticle.global_position = global_position + reticle_offset + Vector3(0.0, 0.08, 0.0)
	if not armed:
		# Weapon away: just a look cursor, so keep it a quiet gray (no enemy highlight).
		_reticle_mat.albedo_color = Color(0.62, 0.64, 0.66, 0.55)
	elif reticle_on_enemy:
		_reticle_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.95)
	else:
		_reticle_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
