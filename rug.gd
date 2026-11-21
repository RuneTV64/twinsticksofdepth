class_name Rug
extends Node3D
## A rug on a floor (owner, 21 Nov 2026: the living room's furniture; everything has to do something). Footsteps
## on it are muffled: walking on it you are heard `QUIET` as far (Player.noise_radius). Rolled up it is an item
## ("rolled_rug": heavy, two hands, a poor club), and laid down again wherever you stand: in front of your door,
## along the way you come and go. Nothing can be rolled up with furniture standing on it.
##
## Not a solid thing: you walk on it, it stops nothing. It is drawn with the furniture shader (its RUG part, in
## the fabric's colours), flat on the floor, and opens with the cutaway as furniture does.

const QUIET := 0.5

static var all: Array[Rug] = []

var w := 2.4                   # along its own x (its length)
var d := 1.6                   # along its own z
var fabric := 0
var stain := 1
var wear := 0
var floor_y := 0.0


## Lay a rug: `at` is its middle on the floor, `size` its length and width, `turns` quarter turns of its length
## from along x.
static func lay(level: Node, at: Vector3, size: Vector2, turns := 0, cloth := 0, worn := 0) -> Rug:
	var r := Rug.new()
	r.w = size.x
	r.d = size.y
	r.fabric = cloth
	r.wear = worn
	r.floor_y = at.y
	r.position = at
	r.rotation.y = turns * PI * 0.5
	level.add_child(r)
	return r


## The rug under this spot, or null.
static func under(p: Vector3) -> Rug:
	for r in all:
		if not is_instance_valid(r) or absf(p.y - r.floor_y) > 0.5:
			continue
		var l := r.to_local(Vector3(p.x, r.global_position.y, p.z))
		if absf(l.x) <= r.w * 0.5 and absf(l.z) <= r.d * 0.5:
			return r
	return null


func _ready() -> void:
	add_to_group("interactables")
	all.append(self)
	var look := MeshInstance3D.new()
	look.mesh = FurnitureKit.mesh_of("rug", w)
	look.scale = Vector3(1.0, 1.0, d / FurnitureKit.KINDS_RUG_D)
	look.material_override = FurnitureKit.mat(stain, fabric, wear)
	look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(look)


func _exit_tree() -> void:
	all.erase(self)


# ---------------------------------------------------------------------------------------- interactable
## It rolls up from its end.
func interact_point() -> Vector3:
	return global_position + global_transform.basis.x * (w * 0.5 - 0.2)


func can_interact(p: Player) -> bool:
	return absf(p.global_position.y - floor_y) < 1.2 and not _weighed_down()


func prompt_text(_p: Player) -> String:
	return "Roll up the rug"


func interact(p: Player) -> void:
	var item := Items.make("rolled_rug")
	item["rug"] = [w, d, fabric, wear]
	var rest := p.inv.add(item)
	if not rest.is_empty():
		p.show_status("It takes both arms: free a hand first.", 1.8)
		return
	p._body.reach()
	p.recompute_stats()
	p.show_status("You roll the rug up and get it under your arm.", 1.8)
	queue_free()


## Is any furniture standing on it?
func _weighed_down() -> bool:
	for b in Breakable.near(Vector2(global_position.x, global_position.z), maxf(w, d)):
		if not is_instance_valid(b) or not b.alive() or not b.host.has_meta("furniture") or absf(b.floor_y - floor_y) > 0.5:
			continue
		var l := to_local(Vector3(b.host.global_position.x, global_position.y, b.host.global_position.z))
		if absf(l.x) < w * 0.5 + 0.1 and absf(l.z) < d * 0.5 + 0.1:
			return true
	return false
