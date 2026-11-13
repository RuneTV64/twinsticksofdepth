class_name InputSetup
extends RefCounted
## Builds the whole input map in code, so the project needs no Project Settings edits.


static func apply() -> void:
	_action("move_left", 0.2)
	_key("move_left", KEY_A); _key("move_left", KEY_LEFT); _axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", 0.2)
	_key("move_right", KEY_D); _key("move_right", KEY_RIGHT); _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_action("move_up", 0.2)
	_key("move_up", KEY_W); _key("move_up", KEY_UP); _axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_action("move_down", 0.2)
	_key("move_down", KEY_S); _key("move_down", KEY_DOWN); _axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

	_action("aim_left", 0.2); _axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_action("aim_right", 0.2); _axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_action("aim_up", 0.2); _axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_action("aim_down", 0.2); _axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)

	# Ready is HOLD. Q is a fallback for touchpads that can't hold right-click and click.
	_action("ready_weapon", 0.5)
	_mouse("ready_weapon", MOUSE_BUTTON_RIGHT); _key("ready_weapon", KEY_Q)
	_axis("ready_weapon", JOY_AXIS_TRIGGER_LEFT, 1.0)

	# Attack while Ready, Interact while the weapon is away. Same button.
	_action("attack", 0.4)
	# Pad: RT is the main button; A stays as an alternate so Interact is also on a face button.
	_mouse("attack", MOUSE_BUTTON_LEFT); _axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button("attack", JOY_BUTTON_A)

	# Tap = dash, hold = run.
	_action("sprint", 0.5)
	_key("sprint", KEY_SHIFT); _button("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_button("sprint", JOY_BUTTON_LEFT_STICK)

	_action("reload", 0.5)
	_key("reload", KEY_R); _button("reload", JOY_BUTTON_X)


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


static func _button(n: StringName, b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	InputMap.action_add_event(n, e)


static func _axis(n: StringName, a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = -1
	InputMap.action_add_event(n, e)
