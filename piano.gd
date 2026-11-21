class_name Piano
extends Node3D
## The piano's keys (owner, 21 Nov 2026: every piece of the living room has to do something). Played, it is the
## loudest thing in a house that isn't a gun: heard right across the neighbourhood (`HEARD`). So it is a lure:
## play it, and slip out of the back before what it brought in gets here. A child of the piano, so breaking the
## piano ends it. A worn-out one is out of tune and no quieter.

const HEARD := 28.0            # m, as far as anything hears it (a gunshot is 30)
const AGAIN := 2.5             # s before it can be played again

var worn := 0
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")


func _process(delta: float) -> void:
	_t = maxf(_t - delta, 0.0)
	set_process(_t > 0.0)


func can_interact(p: Player) -> bool:
	var host := get_parent() as Node3D
	var br := Breakable.of(host) if host != null else null
	return _t <= 0.0 and (br == null or absf(p.global_position.y - br.floor_y) < 1.2)


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return "Play the piano (it will be heard a long way off)"


func interact(p: Player) -> void:
	_t = AGAIN
	set_process(true)
	Earshot.make(global_position, HEARD, get_tree(), p, true)
	p._body.reach()
	p.show_status("You bang out a few chords, out of tune. It carries right across the street." if worn >= 2
		else "You bang out a few chords. It carries right across the street.", 2.2)
