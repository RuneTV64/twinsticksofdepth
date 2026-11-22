class_name WindowCurtains
extends Node3D
## Curtains at a window (owner, 21 Nov 2026: the living room's furniture). Drawn, nobody sees in or out: they
## stop sight both ways (a body on Solid.SIGHT_LAYER, which only sight looks for: your view, raiders' eyes,
## zombies noticing you), but not shots, thrown things or anyone climbing through. Open, they hang at the sides.
## Click to draw or open them, weapon away; the context menu (hold the click) takes them down: the "Curtains" item (a cloak, cloth).
## The way to watch a street from a dark room, or to hide that someone is in it.

const INSET := 0.12            # m in from the glass, on the room's side
const OPEN_W := 0.24           # each panel's width, open

var drawn := true
var fabric := 0
var stain := 1
var wear := 0
var width := 1.2
var height := 1.4
var floor_y := 0.0

var _sight: StaticBody3D
var _panels: Array[MeshInstance3D] = []


## Hang curtains at a window (Solid.windows' record) on the side of it toward `inside`.
static func hang(level: Node, window: Dictionary, inside: Vector3, cloth := 0, closed := true, floor_at := 0.0) -> WindowCurtains:
	var size: Vector3 = window["size"]
	var pos: Vector3 = window["pos"]
	var along_x := size.x >= size.z
	var n := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	if (inside - pos).dot(n) < 0.0:
		n = -n
	var c := WindowCurtains.new()
	c.width = maxf(size.x, size.z)
	c.height = size.y + 0.15
	c.fabric = cloth
	c.drawn = closed
	c.floor_y = floor_at
	c.position = pos + n * INSET + Vector3(0.0, 0.05, 0.0)
	c.rotation.y = atan2(n.x, n.z)          # its +z faces into the room
	level.add_child(c)
	return c


func _ready() -> void:
	add_to_group("interactables")
	_sight = StaticBody3D.new()
	_sight.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 0.1, height, 0.04)
	shape.shape = box
	_sight.add_child(shape)
	add_child(_sight)
	for i in 2:
		var m := MeshInstance3D.new()
		m.material_override = FurnitureKit.mat(stain, fabric, wear)
		add_child(m)
		_panels.append(m)
	_show()


## Draw them (true) or open them.
func set_drawn(v: bool) -> void:
	drawn = v
	if is_inside_tree():
		_show()


func _show() -> void:
	_sight.collision_layer = Solid.SIGHT_LAYER if drawn else 0
	var pw := width * 0.5 + 0.06 if drawn else OPEN_W
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var m := _panels[i]
		m.mesh = FurnitureKit.mesh_of("curtain", pw)
		m.scale = Vector3(1.0, height, 1.0)
		m.position = Vector3(side * (width * 0.25 - 0.03 if drawn else width * 0.5 + OPEN_W * 0.5 - 0.04), 0.0, 0.0)


# ---------------------------------------------------------------------------------------- interactable
func interact_point() -> Vector3:
	return global_position + global_transform.basis.z * 0.3


func can_interact(p: Player) -> bool:
	return absf(p.global_position.y - floor_y) < 1.2


func prompt_text(_p: Player) -> String:
	return "Open the curtains" if drawn else "Draw the curtains"


## For the context menu (hold left-click, weapon away).
func context_actions(_p: Player) -> Array:
	return [["Take the curtains down", "down"]]


func context_do(p: Player, id: String) -> void:
	if id == "down":
		p._body.reach()
		var item := Items.make("curtains")
		var rest := p.inv.add(item)
		if not rest.is_empty():
			p._drop(rest)
		p.recompute_stats()
		p.show_status("You pull the curtains down, rail and all." + ("" if rest.is_empty() else " They are at your feet."), 2.0)
		queue_free()


func interact(p: Player) -> void:
	p._body.reach()
	set_drawn(not drawn)
	p.show_status("You draw the curtains. Nobody can see in, or out." if drawn else "You open the curtains.", 1.6)
