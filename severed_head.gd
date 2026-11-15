class_name SeveredHead
extends Node
## A zombie's head that came off is still alive. It can't go anywhere, but it can still bite, very rarely and only
## by accident: when someone steps right by it. Enemy adds this to the head piece (a ShamblerPiece) when the head
## comes off. It bites for as long as the piece is there (until it rots away).

## How close a foot has to come.
@export var reach := 0.55
## Chance per second, while you're that close, that it gets its teeth into you.
@export var bite_chance := 0.04
@export var bite_damage := 6.0
## Seconds before it can bite again.
@export var bite_cooldown := 2.5

var player: Player
var _piece: Node3D
var _cd := 0.0


func _ready() -> void:
	_piece = get_parent() as Node3D


func _physics_process(delta: float) -> void:
	_cd -= delta
	if player == null or _piece == null or player.dead or _cd > 0.0:
		return
	var to := player.global_position - _piece.global_position
	to.y = 0.0
	if to.length() > reach:
		return
	if randf() < bite_chance * delta:
		_cd = bite_cooldown
		player.take_damage(bite_damage, to.normalized(), 0.0)
		if not player.dead:
			player.show_status("A severed head bit you! -%d HP" % roundi(bite_damage), 1.4)
