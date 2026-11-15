class_name Hud
extends CanvasLayer

var player: Player

var _state: Label
var _help: Label
var _stats: Label
var _ammo: Label
var _prompt: Label
var _status: Label
var _hp: ProgressBar
var _st: ProgressBar
var _st_fill: StyleBoxFlat
var _debug: Label
var _wheel: Control
var _wheel_labels: Array[Label] = []

const HELP_KM := """MOUSE + KEYBOARD
Move  WASD
Look (weapon away)  Mouse moves the crosshair, camera follows
Ready (HOLD)  Right mouse button
Attack (while Ready)  Left-click
Interact (weapon away)  Left-click
Sprint  Shift: tap = dash, hold = run
Weapon wheel (HOLD)  Tab, point with the mouse, release
Reload  R"""

const HELP_PAD := """CONTROLLER
Move  Left stick
Look (weapon away)  Right stick moves the crosshair, camera follows
Ready (HOLD)  LT
Attack (while Ready)  RT
Interact (weapon away)  RT  or  A
Sprint  L3: tap = dash, hold = run
Weapon wheel (HOLD)  LB, point with the right stick, release
Reload  X"""

const HELP_TAIL := """
Doors: walk into them to push them open or shut.
Run or dash into a shut one to barge it (it hurts).
Aim: a red reticle on an enemy = aimed shot (more damage, headshot chance)
Unarmed + Ready: attack = punch (weak; a bit harder standing still).
Hold Ready and face a zombie: when it gets within reach you shove it back,
and any zombies right beside it. Each shove costs stamina;
out of stamina = no shoves, bites land until you recover.
Grabbed: Ready and face it to shove it off, or wiggle the move keys to break free.
Stat test keys: 1/2 STR   3/4 END   5/6 WT   7/8 DEX
Crowd test: F5 +50 zombies   F6 clear   F7 can't be hurt
F1 hide help    Esc free mouse"""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_state = _label(root, 26)
	_state.position = Vector2(20, 14)

	_help = _label(root, 16)
	_help.position = Vector2(20, 56)

	_status = _label(root, 26)
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.offset_left = -500
	_status.offset_right = 500
	_status.offset_top = 90

	_prompt = _label(root, 24)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	_prompt.offset_top = -150
	_prompt.offset_bottom = -110

	_hp = _bar(root, 0, Color(0.85, 0.25, 0.25))
	var st_style := StyleBoxFlat.new()
	st_style.bg_color = Color(0.3, 0.8, 0.35)
	_st_fill = st_style
	_st = _bar(root, 1, Color(0.3, 0.8, 0.35))
	_st.add_theme_stylebox_override("fill", _st_fill)

	_stats = _label(root, 15)
	_stats.anchor_top = 1.0
	_stats.anchor_bottom = 1.0
	_stats.offset_left = 20
	_stats.offset_top = -128
	_stats.offset_bottom = -82

	_debug = _label(root, 18)
	_debug.anchor_left = 1.0
	_debug.anchor_right = 1.0
	_debug.offset_left = -560
	_debug.offset_right = -20
	_debug.offset_top = 14
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))

	_ammo = _label(root, 40)
	_ammo.anchor_left = 1.0
	_ammo.anchor_right = 1.0
	_ammo.anchor_top = 1.0
	_ammo.anchor_bottom = 1.0
	_ammo.offset_left = -360
	_ammo.offset_right = -24
	_ammo.offset_top = -80
	_ammo.offset_bottom = -20
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Quick weapon wheel: a ring of slots in the middle of the screen, shown while it's held open.
	_wheel = Control.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.visible = false
	_wheel.draw.connect(_draw_wheel)
	root.add_child(_wheel)
	for w in Player.WEAPONS:
		var l := _label(_wheel, 20)
		l.text = Player.WEAPON_NAMES[w]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(160, 30)
		_wheel_labels.append(l)


const WHEEL_RADIUS := 150.0

func _draw_wheel() -> void:
	var c := _wheel.size * 0.5
	_wheel.draw_circle(c, WHEEL_RADIUS + 22.0, Color(0, 0, 0, 0.45))
	var n := Player.WEAPONS.size()
	var half := PI / n - 0.05
	for i in n:
		var a := Player.wheel_angle(i)
		var col := Color(1, 1, 1, 0.22)
		if i == player.wheel_choice:
			col = Color(1.0, 0.75, 0.3, 0.95)       # highlighted: equips on release
		elif Player.WEAPONS[i] == player.weapon:
			col = Color(1, 1, 1, 0.6)               # what you're holding now
		_wheel.draw_arc(c, WHEEL_RADIUS, a - half, a + half, 48, col, 24.0, true)


func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, row: int, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = 20
	b.offset_right = 360
	b.offset_top = -66 + row * 28
	b.offset_bottom = b.offset_top + 20
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func toggle_help() -> void:
	_help.visible = not _help.visible


func toggle_debug() -> void:
	_debug.visible = not _debug.visible


func _process(_delta: float) -> void:
	if player == null:
		return
	var stance := "READY" if player.armed else "WEAPON AWAY"
	if player.armed and player.is_melee():
		if not player.is_guarding():
			stance += "  - SPENT"
		else:
			stance += "  - guarding"
	if player.running:
		stance += "  - running"
	if player.fatigue() > 0.3:
		stance += "  - fatigued"
	_state.text = "%s    |    %s" % [stance, "Controller" if player.using_pad else "Mouse + Keyboard"]
	_state.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3) if player.armed else Color.WHITE)
	_help.text = (HELP_PAD if player.using_pad else HELP_KM) + "\n" + HELP_TAIL

	_hp.max_value = player.max_health
	_hp.value = player.health
	_st.max_value = player.max_stamina
	_st.value = player.stamina
	# Green when fresh, sliding to yellow as fatigue sets in; orange while winded.
	_st_fill.bg_color = Color(0.9, 0.5, 0.15) if player.winded \
		else Color(0.3, 0.8, 0.35).lerp(Color(0.9, 0.8, 0.2), player.fatigue())

	_stats.text = "STR %d  END %d  WT %d  DEX %d   ->  walk %.1f  ready %.1f  run %.1f  dash %.1f   barge power: run %d / dash %d   aimed x%.2f  headshot %d%%" % [
		roundi(player.strength), roundi(player.endurance), roundi(player.weight), roundi(player.dexterity),
		player.walk_speed, player.ready_speed, player.run_speed, player.dash_speed,
		roundi(player.barge_power(player.run_speed)), roundi(player.barge_power(player.dash_speed)),
		player.aimed_mult, roundi(player.headshot_chance * 100.0)]

	_ammo.text = "FISTS" if player.is_melee() else "%d / %d" % [player.mag, player.reserve]
	_ammo.modulate = Color(1, 1, 1, 1.0 if player.armed else 0.45)

	_wheel.visible = player.wheel_open
	if _wheel.visible:
		var c := _wheel.size * 0.5
		for i in _wheel_labels.size():
			var a := Player.wheel_angle(i)
			var l := _wheel_labels[i]
			l.position = c + Vector2(cos(a), sin(a)) * (WHEEL_RADIUS - 80.0) - l.size * 0.5
			l.modulate = Color(1.0, 0.8, 0.4) if i == player.wheel_choice else Color.WHITE
		_wheel.queue_redraw()

	_prompt.text = player.interact_prompt()
	_prompt.modulate = Color(1, 1, 1, 0.5 if player.armed else 1.0)

	var mask := Input.get_mouse_button_mask()
	var blocked := []
	if player._draw_t > 0.0: blocked.append("drawing")
	if player._reload_t > 0.0: blocked.append("reloading")
	if player._stagger > 0.0: blocked.append("staggered")
	if player._fire_cd > 0.0: blocked.append("cooldown")
	_debug.text = "INPUT CHECK (F3)\nmouse held: L %s  R %s   mouse %s\nready %s   attack %s\narmed %s   blocked: %s\nshots fired %d   last: %s\nGodot %s" % [
		_yn(mask & MOUSE_BUTTON_MASK_LEFT), _yn(mask & MOUSE_BUTTON_MASK_RIGHT),
		"captured" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "FREE",
		_yn(player.ready_held()), _yn(player.attack_held()),
		_yn(player.armed), ", ".join(blocked) if not blocked.is_empty() else "no",
		player.shots_fired, player.last_shot, Engine.get_version_info()["string"]]

	_status.visible = player.status_t > 0.0
	_status.text = player.status_text


func _yn(v) -> String:
	return "YES" if v else "no"
