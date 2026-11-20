class_name InputSetup
extends RefCounted
## Builds the whole input map in code, so the project needs no Project Settings edits.
## Mouse and keyboard only (owner, 20 Nov 2026): there are no controller bindings.


static func apply() -> void:
	_action("move_left", 0.2)
	_key("move_left", KEY_A); _key("move_left", KEY_LEFT)
	_action("move_right", 0.2)
	_key("move_right", KEY_D); _key("move_right", KEY_RIGHT)
	_action("move_up", 0.2)
	_key("move_up", KEY_W); _key("move_up", KEY_UP)
	_action("move_down", 0.2)
	_key("move_down", KEY_S); _key("move_down", KEY_DOWN)

	# Ready is HOLD. Q is a fallback for touchpads that can't hold right-click and click.
	_action("ready_weapon", 0.5)
	_mouse("ready_weapon", MOUSE_BUTTON_RIGHT); _key("ready_weapon", KEY_Q)

	# Attack while Ready, Interact while the weapon is away. Same button.
	_action("attack", 0.4)
	_mouse("attack", MOUSE_BUTTON_LEFT)

	# Tap = dash, hold = run.
	_action("sprint", 0.5)
	_key("sprint", KEY_SHIFT)

	# HOLD to open the quick weapon wheel, point with the mouse, release to equip.
	_action("weapon_wheel", 0.5)
	_key("weapon_wheel", KEY_TAB)

	# Cover: tap = slide into the nearest cover / leave it; hold = go to the cover the crosshair marks.
	_action("cover", 0.5)
	_key("cover", KEY_SPACE)

	_action("reload", 0.5)
	_key("reload", KEY_R)

	# Crouch and prone: each key gets you down, and up again.
	_action("crouch", 0.5)
	_key("crouch", KEY_CTRL)
	_action("prone", 0.5)
	_key("prone", KEY_X)

	# HOLD: the camera lets go of you and follows the crosshair further out.
	_action("free_look", 0.5)
	_key("free_look", KEY_F)
	_mouse("free_look", MOUSE_BUTTON_MIDDLE)

	# Look up from what your hands are doing (treating a wound; searching, later).
	_action("look_up", 0.5)
	_key("look_up", KEY_ALT)


static func _action(n: StringName, dz: float) -> void:
	if InputMap.has_action(n):
		InputMap.erase_action(n)
	InputMap.add_action(n, dz)


static func _key(n: StringName, k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	InputMap.action_add_event(n, e)


static func _mouse(n: StringName, b: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(n, e)
