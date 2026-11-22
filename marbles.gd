class_name Marbles
extends Node3D
## Marbles scattered on a floor (owner, 22 Nov 2026: the living room's odds and ends; a toy that does something).
## Anyone walking over them sets them rattling (a noise, heard `RATTLE` m off), and they may roll a foot out from
## under them: a zombie on its feet goes down (Enemy._knock_down), a raider stumbles and is slowed, and so do
## you, worst when running. Crawlers and people going carefully (crouched or flat) don't slip. Picked up again
## by hand (interact), the whole bag. Like broken glass, a trap and an alarm for whoever walks into it, you too.
##
## Not a solid thing. Called from the same footfalls as broken glass (Player._step_in_it, Enemy's tracks).

const SPREAD := 0.75           # m round the middle that they lie in
const RATTLE := 5.0            # m: how far a foot on them is heard
const SLIP_WALK := 0.15        # the chance you slip walking on them
const SLIP_RUN := 0.55         # ... running, dashing, rolling
const SLIP_ZOMBIE := 0.35      # a zombie on its feet: it goes down (fresh or rotted alike: its feet are no wiser)
const SLIP_RAIDER := 0.3

static var all: Array[Marbles] = []

var floor_y := 0.0
var _quiet := 0.0              # s until they rattle again (one noise for a crowd tramping through)


static func lay(level: Node, at: Vector3) -> Marbles:
	var m := Marbles.new()
	m.floor_y = at.y
	m.position = at
	level.add_child(m)
	return m


## Something's foot has come down here: do any marbles lie under it? `who` is the player, a zombie or a raider.
## Returns true if it slipped.
static func step_on(pos: Vector3, who: Node) -> bool:
	for m in all:
		if not is_instance_valid(m) or absf(pos.y - m.floor_y) > 0.6:
			continue
		if Vector2(pos.x - m.global_position.x, pos.z - m.global_position.z).length() <= SPREAD:
			return m._underfoot(who)
	return false


func _ready() -> void:
	add_to_group("interactables")
	all.append(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	var inks := [Color(0.3, 0.45, 0.85), Color(0.85, 0.3, 0.25), Color(0.35, 0.7, 0.4), Color(0.9, 0.8, 0.35), Color(0.85, 0.85, 0.9)]
	for i in 16:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.018
		sm.height = 0.036
		sm.radial_segments = 6
		sm.rings = 3
		b.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = inks[i % inks.size()]
		mat.roughness = 0.2
		b.material_override = mat
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * SPREAD
		b.position = Vector3(cos(a) * r, 0.06, sin(a) * r)
		add_child(b)


func _exit_tree() -> void:
	all.erase(self)


func _process(delta: float) -> void:
	_quiet -= delta
	set_process(_quiet > 0.0)


func _underfoot(who: Node) -> bool:
	if _quiet <= 0.0:
		_quiet = 0.5
		set_process(true)
		Earshot.make(global_position, RATTLE, get_tree(), who, who is Player)
	if who is Player:
		var p := who as Player
		if p.posture > 0 or p.dead:
			return false
		var fast := Vector2(p.velocity.x, p.velocity.z).length() > p.walk_speed * 1.15
		if randf() < (SLIP_RUN if fast else SLIP_WALK):
			p._stagger = maxf(p._stagger, 0.9 if fast else 0.6)
			if fast:
				p.posture = 2                  # off your feet and flat on the floor
			p.show_status("Marbles! Your feet go out from under you." if fast else "Something rolls under your foot.", 1.4)
			return true
		return false
	if who is Raider:
		var r := who as Raider
		if randf() < SLIP_RAIDER:
			r.slip()
			return true
		return false
	if who is Enemy:
		var z := who as Enemy
		if z.dead or z.crawling:
			return false
		if randf() < SLIP_ZOMBIE:
			z._knock_down(z.facing * 0.5)
			return true
	return false


# ---------------------------------------------------------------------------------------- interactable
func interact_point() -> Vector3:
	return global_position


func can_interact(p: Player) -> bool:
	return absf(p.global_position.y - floor_y) < 1.2


func prompt_text(_p: Player) -> String:
	return "Gather up the marbles"


func interact(p: Player) -> void:
	var rest := p.inv.add(Items.make("marbles"))
	if not rest.is_empty():
		p.show_status("No room for them.", 1.4)
		return
	p._body.reach()
	p.recompute_stats()
	p.show_status("You sweep the marbles back into their bag.", 1.4)
	queue_free()
