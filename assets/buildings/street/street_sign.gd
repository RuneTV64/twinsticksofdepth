class_name StreetSign
extends Node3D
## What a street sign says, for whoever walks up to it (street_kit.gd puts one on every sign's post). A sign tells
## you where you are: the prompt reads it out, and interacting keeps it on the screen a moment longer.

var text := "STOP"


func _ready() -> void:
	add_to_group("interactables")


func can_interact(_p: Player) -> bool:
	return true


func interact_point() -> Vector3:
	return global_position


func prompt_text(_p: Player) -> String:
	return "The sign reads: %s" % text


func interact(p: Player) -> void:
	p.show_status("The sign reads: %s" % text, 3.0)
