class_name TinAlarm
extends Node3D
## Empty tins strung on a strip of cloth or a cord across a doorway or a gap (owner, 22 Nov 2026: the kitchen's
## odds and ends; nothing is junk, an empty tin included). Whoever walks through it sets the tins rattling,
## heard `RATTLE` m off: it stops nobody, it only tells you, and tells everything else near by. It is not a solid
## thing. Called from the same footfalls as broken glass and marbles (Player._step_in_it, Enemy's tracks).
## Taken down by hand (interact): the tins and the tie come back.

const TINS := 3                # tins it takes
const SPAN := 1.4              # m across
const RATTLE := 11.0           # m: how far the rattle carries
const REACH := 0.45            # m either side of the line that sets it off

static var all: Array[TinAlarm] = []

var tie := "cloth_strip"       # what the tins hang on, given back when it is taken down
var floor_y := 0.0
var _quiet := 0.0


## String one across `at`, at right angles to `facing` (the way you were looking: you string it across it).
static func hang(level: Node, at: Vector3, facing: Vector3, with_tie: String) -> TinAlarm:
	var t := TinAlarm.new()
	t.tie = with_tie
	t.floor_y = at.y
	t.position = at
	t.rotation.y = atan2(facing.x, facing.z)      # its +z the way you faced; the line runs along its x
	level.add_child(t)
	return t


## A foot has come down at `pos`: through the line?
static func step_on(pos: Vector3, who: Node) -> void:
	for t in all:
		if not is_instance_valid(t) or absf(pos.y - t.floor_y) > 0.6:
			continue
		var l := t.to_local(Vector3(pos.x, t.global_position.y, pos.z))
		if absf(l.x) <= SPAN * 0.5 + 0.1 and absf(l.z) <= REACH:
			t._rattle(who)


func _ready() -> void:
	add_to_group("interactables")
	all.append(self)
	var cord := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(SPAN, 0.01, 0.01)
	cord.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.55, 0.5, 0.42) if tie == "cloth_strip" else Color(0.15, 0.15, 0.17)
	cord.material_override = cm
	cord.position.y = 0.3
	add_child(cord)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.7, 0.72, 0.72)
	tm.metallic = 0.6
	for i in TINS:
		var tin := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.035
		c.bottom_radius = 0.035
		c.height = 0.1
		c.radial_segments = 8
		tin.mesh = c
		tin.material_override = tm
		tin.position = Vector3((i - (TINS - 1) * 0.5) * 0.4, 0.22, 0.0)
		add_child(tin)


func _exit_tree() -> void:
	all.erase(self)


func _process(delta: float) -> void:
	_quiet -= delta
	set_process(_quiet > 0.0)


func _rattle(who: Node) -> void:
	if _quiet > 0.0:
		return
	_quiet = 1.0
	set_process(true)
	Earshot.make(global_position + Vector3(0.0, 0.3, 0.0), RATTLE, get_tree(), who, who is Player)
	if who is Player:
		(who as Player).show_status("The tins rattle as you go through.", 1.2)
	else:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p != null and not p.dead and p.global_position.distance_to(global_position) <= RATTLE:
			p.show_status("Tins rattling, somewhere near.", 1.6)


# ---------------------------------------------------------------------------------------- interactable
func interact_point() -> Vector3:
	return global_position


func can_interact(p: Player) -> bool:
	return absf(p.global_position.y - floor_y) < 1.2


func prompt_text(_p: Player) -> String:
	return "Take down the tin-can alarm"


func interact(p: Player) -> void:
	var back: Array[Dictionary] = [Items.make("empty_tin", TINS), Items.make(tie)]
	for it in back:
		var rest := p.inv.add(it)
		if not rest.is_empty():
			p._drop(rest)
	p._body.reach()
	p.recompute_stats()
	p.show_status("You take the tins down.", 1.4)
	queue_free()
