class_name Projectile
extends Node3D
## Raycast-stepped shot: each physics tick it casts from where it was to where it's going,
## so it can't tunnel through thin things at high speed.

var dir := Vector3(0, 0, -1)
var speed := 140.0
var damage := 25.0
var knock := 3.0
var max_dist := 40.0
var exclude: Array[RID] = []
var shooter: Player
var aimed_at: Enemy = null      # enemy under the reticle when fired; bonuses apply only to it
var aimed_mult := 1.0
var headshot_chance := 0.0
var _travel := 0.0


func _ready() -> void:
	add_to_group("projectiles")
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
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var t := _segment_hit(from, to, en.global_position, 0.55)
		if t >= 0.0 and t < best_t:
			best_t = t
			best_e = en
	# 2) Walls / doors: physics ray.
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		var wall_t := from.distance_to(hp) / maxf(from.distance_to(to), 0.0001)
		if wall_t < best_t:
			_report("hit wall (%s)" % (hit["collider"] as Node).name)
			_impact(hp)
			queue_free()
			return
	if best_e != null:
		if best_e == aimed_at and randf() < headshot_chance:
			best_e.take_hit(best_e.hp + 1.0, dir, knock * 2.0)   # one-hit kill
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


## Fraction 0..1 along from->to where it passes within `radius` of a standing enemy (XZ), or -1.
func _segment_hit(from: Vector3, to: Vector3, c: Vector3, radius: float) -> float:
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
