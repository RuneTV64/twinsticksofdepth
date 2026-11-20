class_name Thrown
extends Node3D
## Something thrown (a rock, a bottle): it arcs from the hand to where it was aimed and makes a noise where it
## lands. Zombies go to the noise; raiders go to look. A rock can be picked up again; a bottle breaks.

const LOOK := {"rock": [Vector3(0.16, 0.12, 0.14), Color(0.5, 0.5, 0.48)], "bottle": [Vector3(0.08, 0.08, 0.26), Color(0.25, 0.5, 0.3)]}
## How far the landing is heard (m).
const NOISE := {"rock": 9.0, "bottle": 14.0}

var item := "rock"
var from := Vector3.ZERO
var to := Vector3.ZERO
var peak := 2.0              # how high the arc goes above the straight line
var flight := 0.8
var thrower: Node = null
var _t := 0.0


func _ready() -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = LOOK[item][0]
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LOOK[item][1]
	m.material_override = mat
	add_child(m)
	global_position = from


func _process(delta: float) -> void:
	_t += delta
	var u := clampf(_t / maxf(flight, 0.05), 0.0, 1.0)
	global_position = from.lerp(to, u) + Vector3.UP * (4.0 * peak * u * (1.0 - u))
	rotation += Vector3(7.0, 3.0, 5.0) * delta
	if u >= 1.0:
		_land()


func _land() -> void:
	Earshot.make(to, float(NOISE[item]), get_tree(), thrower, true)
	if item == "rock":
		var p := ItemPickup.new()
		p.title = "Rock"
		p.small = true
		p.tint = LOOK["rock"][1]
		p.contents = [Items.make("rock")]
		p.position = Vector3(to.x, 0.0, to.z)
		get_parent().add_child(p)
	queue_free()
