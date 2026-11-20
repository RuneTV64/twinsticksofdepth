class_name Projectile
extends Node3D
## Raycast-stepped shot: each physics tick it casts from where it was to where it's going,
## so it can't tunnel through thin things at high speed.

var dir := Vector3(0, 0, -1)
var speed := 140.0
var damage := 25.0
var knock := 3.0
const MAX_DIST := 40.0
const HIT_RADIUS := 0.55    # how close (XZ) the shot must pass to an enemy's center to hit

var max_dist := MAX_DIST
var exclude: Array[RID] = []
var shooter: Player
var aimed_at: Enemy = null      # enemy under the reticle when fired; bonuses apply only to it
var aimed_mult := 1.0
var headshot_chance := 0.0
var targets_player := false     # fired at the player (a raider, the test gunner): it can hit the player, not zombies
var origin := Vector3.ZERO      # where it was fired from: cover is judged from here
var _travel := 0.0


func _ready() -> void:
	add_to_group("projectiles")
	origin = global_position
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.07, 0.07, 2.2)   # long thin tracer: at gun speeds a short bolt is invisible
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.no_depth_test = true
	mat.render_priority = 5
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	rotation.y = atan2(-dir.x, -dir.z)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + dir * speed * delta
	# 1) Enemies: checked directly by distance, so hits don't depend on the physics engine.
	var best_t := 2.0
	var best_e: Enemy = null
	var best_p: Player = null
	if targets_player:
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl != null and not pl.dead:
			var t := segment_hit(from, to, pl.global_position, HIT_RADIUS)
			if t >= 0.0:
				best_t = t
				best_p = pl
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Enemy
			if en == null or en.dead:
				continue
			var t := segment_hit(from, to, en.global_position, HIT_RADIUS)
			if t >= 0.0 and t < best_t:
				best_t = t
				best_e = en
	# 2) Walls / doors: physics ray. Shots pass over low cover (see wall_hit).
	var hit := wall_hit(get_world_3d().direct_space_state, from, to, exclude)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		var wall_t := from.distance_to(hp) / maxf(from.distance_to(to), 0.0001)
		if wall_t < best_t:
			_report("hit wall (%s)" % (hit["collider"] as Node).name)
			_impact(hp)
			queue_free()
			return
	if best_p != null:
		# Whether the player's cover stops it is the player's call (hunkered, peeking or out).
		var what := best_p.take_shot(damage, dir, knock, origin)
		_report("shot at the player: %s" % what)
		_impact(from.lerp(to, best_t))
		queue_free()
		return
	if best_e != null and best_e.has_method("cover_result"):
		# A raider behind cover gets the same rule as the player: hunkered, the cover stops it; peeking, only
		# the head shows, so a hit there kills.
		var cov: String = best_e.call("cover_result", origin)
		if cov == "cover":
			_report("stopped by %s's cover" % best_e.kind)
			_impact(from.lerp(to, best_t))
			queue_free()
			return
		if cov == "head":
			best_e.take_headshot(dir, knock * 2.0)
			_report("HEAD HIT on a peeking %s" % best_e.kind)
			if is_instance_valid(shooter):
				shooter.show_status("HEADSHOT!", 1.0)
			_impact(from.lerp(to, best_t))
			queue_free()
			return
	if best_e != null:
		if best_e == aimed_at and randf() < headshot_chance:
			best_e.take_headshot(dir, knock * 2.0)   # one-hit kill; may take the head off
			_report("HEADSHOT on %s" % best_e.kind)
			if is_instance_valid(shooter):
				shooter.show_status("HEADSHOT!", 1.0)
		elif best_e == aimed_at:
			best_e.take_hit(damage * aimed_mult, dir, knock)
			_report("AIMED HIT %s x%.2f, hp now %d" % [best_e.kind, aimed_mult, ceili(best_e.hp)])
		else:
			best_e.take_hit(damage, dir, knock)
			_report("HIT %s, hp now %d" % [best_e.kind, ceili(best_e.hp)])
		_impact(from.lerp(to, best_t))
		queue_free()
		return
	global_position = to
	_travel += speed * delta
	if _travel > max_dist:
		_report("missed (flew %dm)" % roundi(_travel))
		queue_free()


## The first wall, door or high cover between two points, or an empty Dictionary. Low cover (crates, window sills,
## cars) doesn't stop a shot: it goes over. Someone hunkered behind low cover is protected by the cover rule
## instead (Player.take_shot), not by the box. Static so aim checks use the same test as the shot.
static func wall_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, skip: Array[RID]) -> Dictionary:
	var ex: Array[RID] = skip.duplicate()
	for i in 8:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, ex))
		if hit.is_empty() or not (hit["collider"] as Object).has_meta("cover_low"):
			return hit
		ex.append(hit["rid"])
	return {}


## Fraction 0..1 along from->to where it passes within `radius` of a standing enemy (XZ), or -1.
## Static so the player's aim check uses exactly the same test as the shot itself.
static func segment_hit(from: Vector3, to: Vector3, c: Vector3, radius: float) -> float:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(c.x, c.z)
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.000001 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	if (a + ab * t).distance_to(p) <= radius:
		return t
	return -1.0


func _report(text: String) -> void:
	print("[shot] ", text)
	if is_instance_valid(shooter):
		shooter.last_shot = text


func _impact(p: Vector3) -> void:
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	fx.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	fx.material_override = mat
	get_parent().add_child(fx)
	fx.global_position = p
	get_tree().create_timer(0.07).timeout.connect(fx.queue_free)
