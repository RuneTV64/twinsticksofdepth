class_name Hud
extends CanvasLayer

var player: Player

var _state: Label
var _help: Label
var _stats: Label
var _ammo: Label
var _prompt: Label
var _status: Label
var _conds: RichTextLabel      # conditions affecting you now, right edge of the screen
var _sheet: RichTextLabel      # the character page (C / Back)
var _sheet_panel: PanelContainer
var _sheet_row := 0            # which row test editing changes
var _sheet_t := 0.0
var _hp: ProgressBar
var _st: ProgressBar
var _st_fill: StyleBoxFlat
var _debug: Label
var treat: TreatmentScreen     # seeing to wounds (H)
var _wheel: Control
var _wheel_labels: Array[Label] = []

const HELP_KEYS := """CONTROLS
Move  WASD
Look (weapon away)  Mouse moves the crosshair, camera follows
Ready (HOLD)  Right mouse button
Attack (while Ready)  Left-click
Interact (weapon away)  Left-click
Sprint  Shift: tap = dash, hold = run
Weapon wheel (HOLD)  Tab, point with the mouse, release
Reload  R
Cover  Space: tap = slide into nearest cover / leave it; hold = go to the cover the crosshair marks
Roll  Space twice quickly, out of cover: rolls the way you are moving"""

const HELP_TAIL := """
Doors: click them (weapon away) to open or shut them.
A strong character (Strength 13) can bash a shut one in by dashing at it (it hurts). Doors stop zombies and raiders.
Aim: the crosshair is a small grey x. Ready, on an enemy it goes red, and the part of them it is on (head, body,
  an arm, a leg) is where the shot is likeliest to land: likelier close up and with Dexterity. Head = a kill;
  arms and legs can come off; a leg hit can put one down.
Lock-on: a crosshair resting near an enemy settles onto it; move the mouse to take it off.
Unarmed + Ready: attack = punch (weak; a bit harder standing still).
Hold Ready and face a zombie: when it gets within reach you shove it back,
and any zombies right beside it. Each shove costs stamina;
out of stamina = no shoves, bites land until you recover.
Grabbed: Ready and face it to shove it off, or wiggle the move keys to break free.
In cover: hunkered = hidden, safe from shots across it, but you see only a short way.
  Hold a move key toward low cover (or along it at an end) = peek: you see, they see you, small chance of a head hit.
  Ready = pop up or lean out to aim. Attack without Ready = blind fire. Hold the move key away from it = leave.
  Space while moving toward low cover = vault it.
Stat test keys: 1/2 STR   3/4 END   5/6 WT   7/8 DEX
Crowd test: F5 +50 zombies   F6 clear   F7 can't be hurt   L all on low model
Finisher: weapon raised (Ready), crosshair on a downed zombie close by, then left-click. On its head it finishes
  it: fists Ready = stomp (blows by Strength), gun Ready = one shot, gun empty = rifle butt. Anywhere else on it
  only hurts it.
Corpse piles can be walked on: slow, bad footing, and what is still alive in them grabs. Space at a wall = climb it.
Character page: C. It shows attributes, needs, composure, your body, what you carry, and conditions.
Wounds: H sits you down to treat them by hand with what you carry (a first-aid box is by the spawn).
  Your view closes in; hold ALT to look up. Moving puts it down. Keys 1-7 or a click pick a tool.
  J gives you a test wound (a deep cut, a gunshot, a bite in turn).
Bites infect. Only taking the arm or leg off before it reaches the body can cure it (hatchet, in the treatment
  screen), and that takes luck. Steroids slow it. Run its course and you turn; your old self walks with your things.
Horde: noise warms an area and draws zombies in from round about. Z shows the readout. Killed ones don't come back.
Cutaway: walls between the camera and you open up. V switches it off and on, to compare.
Cover test: G test gunner at the crosshair   Shift+G remove them
Raiders: a camp in the south-west of the yard.  T adds one at the crosshair   Shift+T removes those
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

	_conds = RichTextLabel.new()
	_conds.bbcode_enabled = true
	_conds.fit_content = true
	_conds.scroll_active = false
	_conds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conds.add_theme_font_size_override("normal_font_size", 18)
	_conds.add_theme_color_override("font_outline_color", Color.BLACK)
	_conds.add_theme_constant_override("outline_size", 6)
	_conds.anchor_left = 1.0
	_conds.anchor_right = 1.0
	_conds.anchor_top = 0.35
	_conds.anchor_bottom = 0.35
	_conds.offset_left = -420
	_conds.offset_right = -20
	root.add_child(_conds)

	# The character page: everything on the sheet, in one panel over the middle of the screen.
	_sheet_panel = PanelContainer.new()
	_sheet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sheet_panel.offset_left = -560
	_sheet_panel.offset_right = 560
	_sheet_panel.offset_top = -400
	_sheet_panel.offset_bottom = 400
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.07, 0.9)
	bg.set_content_margin_all(22)
	_sheet_panel.add_theme_stylebox_override("panel", bg)
	_sheet_panel.visible = false
	root.add_child(_sheet_panel)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.scroll_active = false
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_theme_font_size_override("normal_font_size", 17)
	_sheet.add_theme_font_size_override("bold_font_size", 17)
	_sheet_panel.add_child(_sheet)

	treat = TreatmentScreen.new()
	treat.player = player
	root.add_child(treat)

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


# ---------------------------------------------------------------- character page
## Rows test editing can change: the seven attributes, the load carried, the three needs.
func _sheet_rows() -> Array:
	var rows: Array = []
	rows.append_array(CharacterSheet.ATTRS)
	rows.append("weight")
	rows.append_array(CharacterSheet.NEEDS)
	rows.append("medical")
	return rows


func toggle_sheet() -> void:
	_sheet_panel.visible = not _sheet_panel.visible
	_sheet_t = 0.0


func sheet_select(d: int) -> void:
	if _sheet_panel.visible:
		_sheet_row = posmod(_sheet_row + d, _sheet_rows().size())
		_sheet_t = 0.0


## Test editing (this becomes levelling up and eating): change the picked row.
func sheet_adjust(d: int) -> void:
	if not _sheet_panel.visible:
		return
	var row: String = _sheet_rows()[_sheet_row]
	var s := player.sheet
	if row == "weight":
		player.weight = maxf(player.weight + d, 1.0)
	elif row == "medical":
		s.body.medical = clampi(s.body.medical + d, 0, 10)
	elif CharacterSheet.NEEDS.has(row):
		s.set_need(row, float(s.needs[row]) + d * 10.0)
	else:
		s.set_attr(row, s.attr(row) + d)
	player.recompute_stats()
	_sheet_t = 0.0


func _meter(v: float, width := 20) -> String:
	var n := clampi(roundi(v / 100.0 * width), 0, width)
	return "[color=#9fd3a0]%s[/color][color=#444]%s[/color]" % ["#".repeat(n), "-".repeat(width - n)]


func _mark(row: String) -> String:
	return "[color=#ffc04d]>[/color] " if _sheet_rows()[_sheet_row] == row else "   "


func _cell(text: String) -> String:
	return "[cell]%s   [/cell]" % text


func _sheet_text() -> String:
	var s := player.sheet
	var t := "[b]CHARACTER[/b]      [color=#999]C closes.   PgUp PgDn picks a row.   - = changes it (test editing).[/color]\n\n"
	t += "[b]ATTRIBUTES[/b]   [color=#999]1 to 20; 10 is an ordinary adult[/color]\n[table=4]"
	for a in CharacterSheet.ATTRS:
		var does: String = CharacterSheet.GOVERNS[a]
		var later := "[color=#777]Later: %s[/color]" % CharacterSheet.LATER[a]
		t += _cell(_mark(a) + "[b]%s[/b]" % CharacterSheet.SHORT[a]) + _cell("%d" % roundi(s.attr(a))) \
			+ _cell(a.capitalize()) + _cell(does + ".  " + later if does != "" else "[color=#c9a]Not wired yet.[/color]  " + later)
	t += _cell(_mark("weight") + "[b]WT[/b]") + _cell("%d" % roundi(player.weight)) + _cell("Load carried") \
		+ _cell("Against Strength: over it you slow down and effort costs more")
	t += "[/table]\n"
	t += "[b]WHAT THEY ADD UP TO[/b]\n"
	t += "   Health %d (heals %.1f/s)     Stamina %d (back at %.0f/s)     Walk %.1f  Ready %.1f  Run %.1f  Dash %.1f m/s\n" % [
		roundi(player.max_health), player.heal_rate, roundi(player.max_stamina), player.stamina_regen,
		player.walk_speed, player.ready_speed, player.run_speed, player.dash_speed]
	t += "   Shot at 8 m: head %d%%, body %d%%   Reload %.2f s   Punch x%.2f   Shove %.1f m/s   Aware all round %.1f m   Barge %d / %d\n\n" % [
		roundi(player.part_chance("Head", 8.0) * 100.0), roundi(player.part_chance("Torso", 8.0) * 100.0), player.reload_time, player.melee_mult,
		player.shove_force, player.sight_near, roundi(player.barge_power(player.run_speed)),
		roundi(player.barge_power(player.dash_speed))]
	t += "[b]NEEDS[/b]   [color=#999]%s[/color]\n[table=3]" % (
		"not running down yet: waits for the clock and for things to eat and drink" if s.needs_rate <= 0.0 else "running down with time")
	for n in CharacterSheet.NEEDS:
		t += _cell(_mark(n) + CharacterSheet.NEED_NAMES[n]) + _cell(_meter(s.needs[n])) + _cell("%d" % roundi(s.needs[n]))
	t += "[/table]\n"
	t += "[b]COMPOSURE[/b]   %s  %d   [color=#999]danger wears it down; quiet brings it back, cover faster[/color]\n\n" % [
		_meter(s.composure), roundi(s.composure)]
	# The body: what you can tell about it, which depends on what you know.
	var b := s.body
	t += "[b]BODY[/b]   %s   [color=#999]%s[/color]\n" % [player.death_feel(),
		b.blood_feel() if b.blood_feel() != "" else "colour good"]
	t += "   %sMedical %d of 10   [color=#999]%s[/color]\n" % [_mark("medical"), b.medical,
		["you can tell what hurts and what bleeds", "you can tell what hurts and what bleeds",
		"you can tell what kind of wound it is and how bad", "you can see a wound closing",
		"you can judge what won't stop on its own, and how long you have"][mini(b.medical, 4)]]
	var any := false
	for part in BodyHealth.PARTS:
		for line in b.describe(part):
			any = true
			t += "   [color=#e8836b]%s[/color]   %s\n" % [BodyHealth.NAMES[part], line]
	if not any:
		t += "   [color=#999]Nothing wrong that you can tell.[/color]\n"
	if b.bite_guess() != "":
		t += "   [color=#e8836b]%s[/color]\n" % b.bite_guess()
	if not b.missing.is_empty():
		var gone := ""
		for m in b.missing:
			gone += ("" if gone == "" else ", ") + str(BodyHealth.NAMES[m]).to_lower()
		t += "   [color=#e8836b]Gone for good:[/color] %s\n" % gone
	var guess := b.time_left_guess()
	if guess != "":
		t += "   [color=#d6a04a]%s[/color]\n" % guess
	t += "\n[b]CARRYING[/b]   [color=#999]no bag: slots, each up to a weight.  %.1f kg in all.  H treats wounds.[/color]\n   " % player.inv.weight()
	for sl in Inventory.SLOTS:
		var it = player.inv.slots.get(sl[0])
		t += "%s: %s      " % [sl[1], Items.label(it) if it != null else "[color=#777]empty[/color]"]
		if sl[0] == "pocket4" or sl[0] == "belt2":
			t += "\n   "
	t += "\n\n[b]CONDITIONS[/b]\n"
	if s.conditions.is_empty():
		t += "   [color=#999]None[/color]\n"
	for c in s.conditions:
		t += "   [color=%s]%s[/color]   %s\n" % ["#e8836b" if c["bad"] else "#8fd18f", c["name"], c["text"]]
	t += "\n[b]TRAITS[/b]\n"
	for tr in s.traits:
		t += "   [color=#d8c27a]%s[/color]   %s\n" % [tr["name"], tr["text"]]
	return t


func _process(delta: float) -> void:
	if player == null:
		return
	# The sheet moves a few times a second, so its page and the condition list are redrawn at that pace.
	_sheet_t -= delta
	if _sheet_t <= 0.0:
		_sheet_t = 0.25
		var lines := ""
		for c in player.sheet.conditions:
			lines += "[right][color=%s]%s[/color][/right]\n" % ["#e8836b" if c["bad"] else "#8fd18f", c["name"]]
		_conds.text = lines
		if _sheet_panel.visible:
			_sheet.text = _sheet_text()
	var stance := "READY" if player.armed else "WEAPON AWAY"
	if player.armed and player.is_melee():
		if not player.is_guarding():
			stance += "  - SPENT"
		else:
			stance += "  - guarding"
	if player.running:
		stance += "  - running"
	if player.cover_entering:
		stance += "  - to cover"
	elif player.in_cover:
		stance += {"hunker": "  - IN COVER (hidden)", "peek": "  - PEEKING (seen)", "pop": "  - OUT OF COVER (exposed)"}[player.cover_mode]
	if player.fatigue() > 0.3:
		stance += "  - fatigued"
	_state.text = stance
	_state.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3) if player.armed else Color.WHITE)
	_help.text = HELP_KEYS + "\n" + HELP_TAIL

	# Health is shown roughly, in five steps: you can tell you are close to death, not how close.
	_hp.max_value = 5.0
	var worst := minf(player.health / player.max_health,
		(player.sheet.body.blood - player.sheet.body.dead_at) / (100.0 - player.sheet.body.dead_at))
	_hp.value = clampf(ceilf(worst * 5.0), 0.0 if player.dead else 1.0, 5.0)
	_st.max_value = player.max_stamina
	_st.value = player.stamina
	# Green when fresh, sliding to yellow as fatigue sets in; orange while winded.
	_st_fill.bg_color = Color(0.9, 0.5, 0.15) if player.winded \
		else Color(0.3, 0.8, 0.35).lerp(Color(0.9, 0.8, 0.2), player.fatigue())

	_stats.text = "STR %d  END %d  WT %d  DEX %d   ->  walk %.1f  ready %.1f  run %.1f  dash %.1f   barge power: run %d / dash %d   at 8 m: head %d%%  body %d%%" % [
		roundi(player.strength), roundi(player.endurance), roundi(player.weight), roundi(player.dexterity),
		player.walk_speed, player.ready_speed, player.run_speed, player.dash_speed,
		roundi(player.barge_power(player.run_speed)), roundi(player.barge_power(player.dash_speed)),
		roundi(player.part_chance("Head", 8.0) * 100.0), roundi(player.part_chance("Torso", 8.0) * 100.0)]

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

	if treat.visible != player.treating:
		if player.treating:
			treat.open()
		else:
			treat.close()
	_prompt.text = player.interact_prompt() if not player.treating else ""
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
