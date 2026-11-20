class_name Earshot
extends RefCounted
## Every sound that matters goes through here: a gunshot, a door barged in, a skull stomped, later a hurried
## rummage through a drawer. Whatever is near enough hears it:
##   zombies   turn and walk toward it, and keep walking that way long after (enemy.gd, Wandering)
##   raiders   come and look, with their wits about them (raider.gd)
##   the horde the area it came from warms up, and zombies drift in from the areas round it (horde.gd)
## One call per sound. Nothing here runs between sounds.


## A sound at `pos` that carries `radius` meters. `from` made it (it doesn't hear itself); `by_player` is false
## for sounds the player didn't make (a raider's shots), so raiders don't take them for the player.
static func make(pos: Vector3, radius: float, tree: SceneTree, from: Node = null, by_player := true) -> void:
	for e in tree.get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en == from or en.dead:
			continue
		if en.global_position.distance_to(pos) <= radius:
			en.hear_noise(pos, by_player)
	if Horde.it != null:
		Horde.it.heard(pos, radius)
