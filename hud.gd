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
var _sheet: RichTextLabel      # the character page (C): who they are
var _sheet2: RichTextLabel     # ... and beside it, how they are and what they carry
var _sheet_panel: PanelContainer
var _sheet_row := 0            # which row test editing changes
var _sheet_t := 0.0
var _hp: ProgressBar
var _st: ProgressBar
var _st_fill: StyleBoxFlat
var _debug: Label
var _root: Control
var _hint: Label               # the one line left when the help is hidden
## How much of the UI shows (F2 steps it): 0 everything, 1 only what you need to play (bars, ammo, prompts,
## conditions), 2 nothing at all.
var ui_level := 0
var treat: TreatmentScreen     # seeing to wounds (H)
var loot: LootScreen           # going through a drawer, a cupboard, or what you carry (interact, I)
var _wheel: Control
var _wheel_labels: Array[Label] = []

const HELP_KEYS := """CONTROLS
Move  WASD
Look (weapon away)  Mouse moves the crosshair as far as you can see; the camera follows
Camera in and out  Mouse wheel
Throw  Pick up rocks and bottles, choose Throw on the Tab wheel, hold Ready, left-click: it lands at the crosshair
  and the noise draws zombies and raiders. From behind cover a click throws without showing yourself.
Take-down  Weapon raised, right behind a raider who hasn't noticed you, crosshair on him: left-click.
Seasons  M steps the season (spring, summer, autumn, winter); K turns the rain on and off. The ground follows.
  B swaps the new ground for the old plain one.
Light and dark  N steps the time of day (day, dusk, night, dawn). In the dark you are seen from less far and see
  less far; a fire or lamp lights whoever stands in it; a gunshot shows you up for a moment.
Torch  E steps through the hand torch (a beam where you face), the burning torch (light all round, burns away)
       and none. Both are in the tool box. You see by them, and they show you.
Crouch  Ctrl (again to stand)      Prone  X (again to get up)
  Prone with a gun raised: you stay put and the crosshair reaches further. Aim behind you and you roll onto your back.
Free look (HOLD)  F or middle mouse button: the camera leaves you and follows the crosshair further out
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
Aim: Ready, the cursor turns into a red x on an enemy, and the part of them it is on (head, body,
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
  Your view closes in; hold ALT to look up. Moving puts it down. Keys 1-9 and 0 or a click pick a tool. Vodka or water washes a wound.
  J gives you a test wound (a deep cut, a gunshot, a bite in turn).
Bites infect. Only taking the arm or leg off before it reaches the body can cure it (hatchet, in the treatment
  screen), and that takes luck. Steroids slow it. Run its course and you turn; your old self walks with your things.
Horde: noise warms an area and draws zombies in from round about. Z shows the readout. Killed ones don't come back.
Breaking things: everything breaks. Ready, crosshair on it, close by, left-click: fists, or the hatchet (wood) or
  sledgehammer (brick, pavement) if you carry one; a gun shoots it. Zombies beat on what is in their way, weakest
  first. What is left can be picked through, and rusts and rots away. Broken glass crunches underfoot.
  Water: fill a bottle at a barrel or trough. It may be dirty, and clear water can still be bad. Boil it on a
  fire (interact with a cooking pot, stay by it), or Shift+I filters it and then treats it with tablets. Right-click the bottle among your things to drink.
  Dirty water fouls a wound washed with it and can make you ill. A stove is a fire too: lay wood on it, light it
  with a match, feed it or it burns out.
  Searching: interact with a dresser, a wardrobe, a kitchen counter, a fridge or a bookshelf. The drawer is dark
  until you go through it: hold your hand over a column; Shift hurries and is heard. Drag things about,
  double-click takes or puts back, right-click uses what is in a slot. 1 2 3 pick the drawer. You only see a
  short way in front of you; ALT looks up. I opens just what you carry. A backpack on your back is a grid.
  Things you carry: C opens the character page; PgUp PgDn pick a thing, Enter uses it (eat a tin, put on boots,
  take a pill, fresh batteries in the torch, wash cloth into a rag), Delete puts it down. Food and water run down.
  Y lays the broken glass you carry: a trap for bare feet, an alarm under boots. It stays until picked up.
  Barefoot, glass goes into your feet (U puts boots on and off, if you have a pair). A cut foot takes in what you
  walk through: wash and dress it. A helmet takes most of a blow to the head.
  Floors: stairs, upstairs and basements can be walked. Cover works on the floor you are on. A shot is a straight
  line: from an upstairs window the ground near the wall is hidden unless you take cover at the sill and pop up
  (Ready) to lean out; from below, only what shows over a sill can be hit. A drop of over 2 m bruises your legs.
  The crosshair hits what it covers: put it over an upstairs window, a wall or a roof and a shot or a thrown rock
  goes there. Glass breaks; a rock through an upstairs window lands, and is heard, upstairs.
  P at a window by the crosshair: boards it up (a hammer, 4 nails, 2 planks; it takes a while and is heard), or
  with a crowbar prises the boards off again. Shift+P boards it for nothing (a test key).
  O breaks what the crosshair is on   Shift+O ten minutes of rust and rot
Cutaway: walls between the camera and you open up; indoors the whole building opens (windows stay, faint); Ready, it opens to the crosshair too. V switches it off and on.
Cover test: G test gunner at the crosshair   Shift+G remove them
Raiders: a camp in the south-west of the yard.  T adds one at the crosshair   Shift+T removes those
F1 hide help    F2 hide the UI (once: the clutter; twice: all of it)    Esc free mouse"""


func _ready() -> void:
	var root := Control.new()
	_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_state = _label(root, 26)
	_state.position = Vector2(20, 14)

	_help = _label(root, 16)
	_help.position = Vector2(20, 56)
	_help.visible = false          # it has grown long: it opens on F1 and stays out of the way otherwise
	_hint = _label(root, 16)
	_hint.position = Vector2(20, 56)
	_hint.text = "F1 help     F2 hide the UI"
	_hint.modulate = Color(1, 1, 1, 0.6)

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

	# The character page: everything on the sheet, in one panel over the screen. Two columns: who they are on
	# the left; how they are and what they carry on the right.
	_sheet_panel = PanelContainer.new()
	_sheet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sheet_panel.offset_left = -780
	_sheet_panel.offset_right = 780
	_sheet_panel.offset_top = -430
	_sheet_panel.offset_bottom = 430
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.07, 0.9)
	bg.set_content_margin_all(22)
	_sheet_panel.add_theme_stylebox_override("panel", bg)
	_sheet_panel.visible = false
	root.add_child(_sheet_panel)
	var cols := HBoxContainer.new()
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_theme_constant_override("separation", 28)
	_sheet_panel.add_child(cols)
	_sheet = RichTextLabel.new()
	_sheet2 = RichTextLabel.new()
	for col: RichTextLabel in [_sheet, _sheet2]:
		col.bbcode_enabled = true
		col.scroll_active = false
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_font_size_override("normal_font_size", 17)
		col.add_theme_font_size_override("bold_font_size", 17)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
	_sheet.size_flags_stretch_ratio = 1.7

	treat = TreatmentScreen.new()
	treat.player = player
	root.add_child(treat)
	loot = LootScreen.new()
	loot.player = player
	root.add_child(loot)
	_apply_ui.call_deferred()

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
	_apply_ui()


## F2: step how much of the UI shows.
func next_ui_level() -> String:
	ui_level = (ui_level + 1) % 3
	_apply_ui()
	return ["UI: everything", "UI: only what you need (F2 again hides it all)", "UI hidden (F2 brings it back)"][ui_level]


func _apply_ui() -> void:
	_root.visible = ui_level < 2
	# The test readouts and the long help are the clutter: they go first.
	_stats.visible = ui_level == 0
	_hint.visible = ui_level == 0 and not _help.visible
	if ui_level > 0:
		_help.visible = false
		_debug.visible = false


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
	# What you carry and wear: Enter uses the picked thing, Delete puts it down.
	for sl in Inventory.SLOTS:
		rows.append("slot:" + str(sl[0]))
	for wr in Inventory.WORN:
		rows.append("worn:" + str(wr[0]))
	return rows


## Use the carried thing that is picked (Enter on the character page).
func sheet_use() -> void:
	if not _sheet_panel.visible:
		return
	var row: String = _sheet_rows()[_sheet_row]
	if row.begins_with("slot:"):
		player.use_item(row.substr(5))
	elif row.begins_with("worn:"):
		player.use_item(row)
	_sheet_t = 0.0


## Put down the carried thing that is picked (Delete on the character page).
func sheet_drop() -> void:
	if not _sheet_panel.visible:
		return
	var row: String = _sheet_rows()[_sheet_row]
	if row.begins_with("slot:"):
		player.drop_item(row.substr(5))
	elif row.begins_with("worn:"):
		player.use_item(row)
	_sheet_t = 0.0


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
	if row.begins_with("slot:") or row.begins_with("worn:"):
		return
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
	var t := "[b]CHARACTER[/b]      [color=#999]C closes.   PgUp PgDn picks a row.   - = changes it (test editing).   H treats wounds.[/color]\n\n"
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
		"not running down" if s.needs_rate <= 0.0 else "food and water run down with time (a day is three hours); rest waits for sleep")
	for n in CharacterSheet.NEEDS:
		t += _cell(_mark(n) + CharacterSheet.NEED_NAMES[n]) + _cell(_meter(s.needs[n])) + _cell("%d" % roundi(s.needs[n]))
	t += "[/table]\n"
	t += "[b]COMPOSURE[/b]   %s  %d   [color=#999]danger wears it down; quiet brings it back, cover faster[/color]\n\n" % [
		_meter(s.composure), roundi(s.composure)]
	t += "[b]TRAITS[/b]\n"
	for tr in s.traits:
		t += "   [color=#d8c27a]%s[/color]   %s\n" % [tr["name"], tr["text"]]
	return t


## The right-hand column of the page: the body, what is carried and worn, and the conditions.
func _sheet_text2() -> String:
	var s := player.sheet
	var t := ""
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
	t += "\n[b]CARRYING[/b]   [color=#999]no bag: slots, each up to a weight.  %.1f kg in all.[/color]\n" % player.inv.weight()
	var picked: String = _sheet_rows()[_sheet_row]
	var about := ""
	for sl in Inventory.SLOTS:
		var it = player.inv.slots.get(sl[0])
		t += "%s%s: %s\n" % [_mark("slot:" + str(sl[0])), sl[1], Items.label(it) if it != null else "[color=#777]empty[/color]"]
		if it != null and picked == "slot:" + str(sl[0]):
			about = str(Items.DEFS[it["id"]]["for"])
	for wr in Inventory.WORN:
		var on = player.inv.worn.get(wr[0])
		t += "%s%s: %s\n" % [_mark("worn:" + str(wr[0])), wr[1], Items.label(on) if on != null else "[color=#777]nothing[/color]"]
		if on != null and picked == "worn:" + str(wr[0]):
			about = str(Items.DEFS[on["id"]]["for"])
	if about != "":
		t += "\n[color=#d8c27a]%s[/color]\n[color=#999]Enter uses it.  Delete puts it down.[/color]\n" % about
	t += "\n[b]CONDITIONS[/b]\n"
	if s.conditions.is_empty():
		t += "   [color=#999]None[/color]\n"
	for c in s.conditions:
		t += "   [color=%s]%s[/color]   %s\n" % ["#e8836b" if c["bad"] else "#8fd18f", c["name"], c["text"]]
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
			_sheet2.text = _sheet_text2()
	var stance := "READY" if player.armed else "WEAPON AWAY"
	if player.armed and player.weapon == "fists":
		if not player.is_guarding():
			stance += "  - SPENT"
		else:
			stance += "  - guarding"
	if player.posture > 0:
		stance += "  - CROUCHED" if player.posture == 1 else ("  - PRONE" if player.prone_back < 0.5 else "  - ON YOUR BACK")
		if TallGrass.at(player.global_position):
			stance += " in tall grass"
	if Daylight.level < 0.999:
		var lt := player.light_on_you()
		stance += "   [%s: %s]" % [Daylight.time_name(), "torch on, lit up" if player.torch_on else ("in the dark" if lt < 0.25 else ("in shadow" if lt < 0.6 else "lit up"))]
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

	if player.weapon == "throw":
		var have := 0
		for k in player.inv.slots:
			if Player.THROWABLES.has(player.inv.slots[k]["id"]):
				have += int(player.inv.slots[k].get("n", 1))
		_ammo.text = "THROW  x%d" % have
	else:
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
	if loot.visible != player.searching:
		if player.searching:
			loot.open()
		else:
			loot.close()
	_prompt.text = player.interact_prompt() if not player.treating and not player.searching else ""
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
