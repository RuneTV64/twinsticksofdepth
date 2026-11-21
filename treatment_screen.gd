class_name TreatmentScreen
extends Control
## Seeing to your wounds, by hand. Half the screen is your body (what you can tell about it), the other half is
## one wound close up, which you work on with the mouse and what you carry:
##   bare hand / clean rag   hold on the wound to press on it (best right on the bleeder)
##   tweezers                grip what is in the wound, draw it out slowly and steadily, let go clear of the wound
##   vodka / water           hold and sweep along the wound to wash it (vodka stings; water doesn't)
##   needle and thread       hold and zigzag across the wound: every crossing is a stitch
##   bandage / clean rag     hold and wind round the wound, three turns, to dress it
##   painkillers, steroids   picked = one taken
##   hatchet                 on an arm or a leg: tie it off above (wind a rag or bandage round the line), then
##                           chop on the line, three blows, and the limb is off
## (The drawn-out forceps and the zigzag stitch are borrowed from surgery games the owner likes.)
## Your pointer is your hand: it shakes with pain, lost composure and lost blood. What you can see of the wound
## (the bleeder, what is in it, where stitches should go) depends on Medical.
##
## It costs you your view: the Player sees only a short way while this is open. Hold ALT to look up (hands stop).
## The rules themselves are in body_health.gd; this only does them.

const TOOLS: Array[String] = ["hand", "clean_rag", "tweezers", "vodka", "water", "needle_thread", "bandage", "painkillers", "steroids", "hatchet"]
const SHORT := {"needle_thread": "Needle, thread", "painkillers": "Painkillers"}
const BLOWS := 3
const WRAP_TURNS := 3.0
const WASH_PARTS := 8

const C_BACK := Color(0.05, 0.05, 0.06, 0.94)
const C_PANEL := Color(0.11, 0.11, 0.13, 0.95)
const C_LINE := Color(0.32, 0.32, 0.36)
const C_TEXT := Color(0.86, 0.84, 0.8)
const C_DIM := Color(0.56, 0.55, 0.53)
const C_WARN := Color(0.91, 0.51, 0.42)
const C_GOOD := Color(0.56, 0.82, 0.56)
const C_MARK := Color(1.0, 0.75, 0.3)
const C_SKIN := Color(0.66, 0.5, 0.4)
const C_SKIN_D := Color(0.55, 0.4, 0.32)
const C_BLOOD := Color(0.5, 0.05, 0.05)
const C_BLOOD_D := Color(0.28, 0.02, 0.03)
const C_FLESH := Color(0.62, 0.16, 0.14)
const C_CLOTH := Color(0.85, 0.83, 0.76)

var player: Player
var wound: Dictionary = {}       # the one being worked on ({} = none)
var tool := "hand"

var _ptr := Vector2(1080, 340)   # where you mean your hand to be
var _at := Vector2(1080, 340)    # where it is (shaken)
var _down := false
var _t := 0.0
var _jolt := Vector2.ZERO
var _jolt_t := 1.0
var _wrap := 0.0                 # turns wound so far
var _wrap_ang := 0.0
var _wrap_on := false
var _washed: Array[bool] = []
var _poured := false
var _msg := ""
var _msg_t := 0.0
var _side := 0.0                 # stitching: which side of the wound the needle is on (and how far out it got)
var _grip := -1                  # forceps: the bit held, or -1
var _speed := 0.0                # how fast the hand is moving (smoothed), px/s
var _last_at := Vector2.ZERO
var _amp := false                # taking the limb off
var _amp_tied := false
var _amp_blows := 0
var _rows: Array = []            # [Rect2, wound] for the list on the left
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = ThemeDB.fallback_font


# The screen's size (this Control's own size is not laid out under the HUD's layer).
func _sz() -> Vector2:
	return get_viewport_rect().size


func open() -> void:
	visible = true
	_down = false
	_pick_wound({})
	_ptr = _centre()


func close() -> void:
	visible = false
	_down = false


## How much your hand shakes, in pixels.
func shake() -> float:
	var s := player.sheet
	var b := s.body
	var a := 3.0 + 34.0 * b.pain + 26.0 * (1.0 - s.composure / 100.0) + 18.0 * clampf((85.0 - b.blood) / 50.0, 0.0, 1.0)
	if s.adrenaline_t > 0.0:
		a *= 1.3
	return a * clampf(1.0 - 0.03 * s.bonus("dexterity"), 0.6, 1.4)


func _say(text: String) -> void:
	_msg = text
	_msg_t = 2.5


# ---------------------------------------------------------------- the wound's shape on the screen
func _area() -> Rect2:
	return Rect2(_sz().x * 0.36, 110.0, _sz().x * 0.61, _sz().y * 0.5)


func _centre() -> Vector2:
	return _area().get_center()


func _len() -> float:
	if wound.is_empty():
		return 0.0
	if wound["kind"] == "gunshot":
		return lerpf(50.0, 100.0, float(wound["sev"]))
	if wound["kind"] == "stump":
		return 220.0
	return lerpf(170.0, 600.0, float(wound["sev"]))


func _rand(i: int) -> float:
	return fposmod(sin(float(int(wound["seed"]) + i * 37) * 12.9898) * 43758.5453, 1.0)


## The point t (0 to 1) along the wound.
func _pt(t: float) -> Vector2:
	var tilt := (_rand(1) - 0.5) * 0.5
	var along := Vector2(cos(tilt), sin(tilt))
	var across := Vector2(-along.y, along.x)
	return _centre() + along * (t - 0.5) * _len() + across * sin(t * 5.0 + _rand(2) * 6.0) * 9.0


## [t along the wound, distance from it] for a screen point.
func _near(p: Vector2) -> Array:
	var best_t := 0.0
	var best_d := INF
	for i in 41:
		var d := p.distance_to(_pt(i / 40.0))
		if d < best_d:
			best_d = d
			best_t = i / 40.0
	return [best_t, best_d]


func _bleeder() -> Vector2:
	return _pt(0.15 + 0.7 * _rand(3))


func _debris_pt(i: int) -> Vector2:
	return _pt(0.12 + 0.76 * _rand(10 + i)) + Vector2(0, (_rand(20 + i) - 0.5) * 14.0)


## Which of the things in the wound are still there (so the one you pick out is the one that goes).
func _bits() -> Array:
	if not wound.has("bits") or wound["bits"].size() != int(wound["debris"]):
		wound["bits"] = range(int(wound["debris"]))
	return wound["bits"]


func _pick_wound(w: Dictionary) -> void:
	if w.is_empty():
		# The one that most needs it: bleeding most, among those something can be done for.
		var worst := -1.0
		for o in player.sheet.body.wounds:
			if BodyHealth.treatable(o) and float(o["bleed"]) + float(o["sev"]) * 0.01 > worst:
				worst = float(o["bleed"]) + float(o["sev"]) * 0.01
				w = o
	wound = w
	_amp = false
	_amp_tied = false
	_amp_blows = 0
	_grip = -1
	_wrap = 0.0
	_wrap_on = false
	_poured = false
	_washed.clear()
	_washed.resize(WASH_PARTS)
	if not wound.is_empty() and wound["clean"]:
		_washed.fill(true)


func _has(t: String) -> bool:
	return t == "hand" or player.inv.has(t)


# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventMouseMotion:
		if not player.treat_look:
			_ptr = (_ptr + event.relative).clamp(Vector2(10, 10), _sz() - Vector2(10, 10))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_down = event.pressed and not player.treat_look
		if _down:
			_click()
		else:
			_wrap_on = false
			_side = 0.0
			_release()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if (k >= KEY_1 and k <= KEY_9) or k == KEY_0:
			_take(TOOLS[9 if k == KEY_0 else k - KEY_1])
			get_viewport().set_input_as_handled()


func _take(t: String) -> void:
	if not _has(t):
		_say("You have no %s." % Items.name_of(t).to_lower())
		return
	if t == "painkillers":
		player.inv.use(t)
		player.sheet.body.take_painkiller()
		_say("You swallow a painkiller. It will take the edge off for a few minutes.")
		return
	if t == "steroids":
		player.inv.use(t)
		player.sheet.body.take_steroid()
		_say("You take a steroid. If something is in you, it will slow it. It cures nothing.")
		return
	if t == "hatchet":
		if wound.is_empty() or not player.sheet.body.can_amputate(wound["part"]):
			_say("Only an arm or a leg can come off.")
			return
		_amp = true
		_amp_blows = 0
	elif t != "clean_rag" and t != "bandage":
		_amp = false
	tool = t
	_wrap = 0.0


## The line the limb is cut on (above the wound).
func _cut_x() -> float:
	return _area().position.x + _area().size.x * 0.2


func _release() -> void:
	if _grip < 0 or wound.is_empty():
		_grip = -1
		return
	var b := player.sheet.body
	if float(_near(_at)[1]) > 45.0:
		_bits().erase(_grip)
		var what := b.pull_debris(wound)
		if what == "glass":
			player.inv.add(Items.make("bloody_glass"))      # the blood stays on it (owner)
			player.recompute_stats()
		var it := "A shard of glass, red with your blood." if what == "glass" else "It is out."
		_say(it if int(wound["debris"]) == 0 else it + " There is more in there.")
	else:
		_say("You let go of it too soon.")
	_grip = -1


func _click() -> void:
	# The tray, and the list of wounds.
	for i in TOOLS.size():
		if _tray_cell(i).has_point(_at):
			_take(TOOLS[i])
			return
	for r in _rows:
		if (r[0] as Rect2).has_point(_at):
			_pick_wound(r[1])
			return
	if wound.is_empty() or not _area().has_point(_at):
		return
	if not _has(tool):
		tool = "hand"
	var b := player.sheet.body
	var near := _near(_at)
	var on: bool = near[1] <= 22.0
	if wound["dressed"] != "" and not _amp:
		if tool == "hand" and near[1] <= 70.0:
			b.undress(wound)
			_say("You take the dressing off. It is no use again.")
		elif tool != "hand":
			_say("It is dressed. Take the dressing off first (bare hand).")
		return
	match tool:
		"tweezers":
			if float(wound["bleed"]) > 0.1:
				_say("Too much blood to see into it. Stop the bleeding first.")
				return
			for i in _bits():
				if _at.distance_to(_debris_pt(i)) <= 15.0:
					_grip = i
					_speed = 0.0
					_say("You have it. Draw it out slowly, and let go clear of the wound.")
					return
			if on:
				b.fumble(wound)
				player.sheet.composure = maxf(player.sheet.composure - 3.0, 0.0)
				_say("You dig into raw flesh. Nothing there.")
		"needle_thread":
			if BodyHealth.stitches_needed(wound) == 0:
				_say("A bite is left open: don't stitch it." if wound["kind"] == "bite" else "It is too slight to need stitches.")
			elif float(wound["bleed"]) > 0.1:
				_say("Too much blood to see what you are doing. Stop the bleeding first.")
			_side = 0.0
		"hatchet":
			if not _amp:
				return
			if absf(_at.x - _cut_x()) <= 26.0:
				_amp_blows += 1
				player.sheet.composure = maxf(player.sheet.composure - 18.0, 0.0)
				Earshot.make(player.global_position, 10.0, player.get_tree(), player, true)   # you can't do this quietly
				if _amp_blows >= BLOWS:
					var part: String = wound["part"]
					var tied := _amp_tied
					b.amputate(part, tied)
					player.recompute_stats()
					_pick_wound({})
					tool = "hand"
					_say("It is off. Now stop the bleeding." if tied else "It is off, and it is pouring. Stop the bleeding!")
				else:
					_say("Again. On the line.")
			else:
				b.fumble(wound)
				player.sheet.composure = maxf(player.sheet.composure - 10.0, 0.0)
				_say("You missed the line. That was for nothing.")


func _process(delta: float) -> void:
	if not visible or player == null:
		return
	_t += delta
	_msg_t -= delta
	modulate.a = move_toward(modulate.a, 0.1 if player.treat_look else 1.0, delta * 6.0)
	# The hand: a tremor, and now and then a jump.
	var amp := shake()
	_jolt_t -= delta
	if _jolt_t <= 0.0:
		_jolt_t = randf_range(0.5, 2.2)
		_jolt = Vector2.from_angle(randf() * TAU) * amp * randf_range(0.6, 1.6)
	_jolt = _jolt.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
	_last_at = _at
	_at = _ptr + _jolt + amp * 0.5 * Vector2(sin(_t * 7.3 + 1.0) + 0.6 * sin(_t * 13.1 + 2.0),
		sin(_t * 8.9 + 3.0) + 0.6 * sin(_t * 15.7 + 4.0))
	# A wound that has closed and gone is no longer there to work on.
	if not wound.is_empty() and not player.sheet.body.wounds.has(wound):
		_pick_wound({})
	_speed = lerpf(_speed, _at.distance_to(_last_at) / maxf(delta, 0.001), clampf(delta / 0.15, 0.0, 1.0))
	if _grip >= 0 and _speed > 700.0:
		# A jerk with something gripped: it tears free.
		_grip = -1
		player.sheet.body.fumble(wound)
		player.sheet.composure = maxf(player.sheet.composure - 4.0, 0.0)
		_say("Too fast: it tore out of the tweezers. Slowly.")
	if _down and not wound.is_empty() and _area().has_point(_at) and (wound["dressed"] == "" or _amp):
		_hold(delta)
	queue_redraw()


## Things done by holding the button down.
func _hold(delta: float) -> void:
	var b := player.sheet.body
	var near := _near(_at)
	var c := _centre()
	if _amp:
		# Tying it off: wind round the limb on the line.
		c = Vector2(_cut_x(), c.y)
		if (tool == "bandage" or tool == "clean_rag") and _has(tool) and not _amp_tied and _at.distance_to(c) > 50.0:
			var ang2 := (_at - c).angle()
			if _wrap_on:
				_wrap += absf(angle_difference(_wrap_ang, ang2)) / TAU
			_wrap_ang = ang2
			_wrap_on = true
			if _wrap >= WRAP_TURNS:
				player.inv.use(tool)
				_amp_tied = true
				_wrap = 0.0
				_down = false
				_say("Tied off, tight. Now the hatchet.")
		return
	if tool == "needle_thread" and BodyHealth.stitches_needed(wound) > 0 and float(wound["bleed"]) <= 0.1:
		# Zigzag: every time the needle crosses the wound, a stitch goes in where it crossed.
		var t0: float = near[0]
		var tan := (_pt(minf(t0 + 0.02, 1.0)) - _pt(maxf(t0 - 0.02, 0.0))).normalized()
		var off := (_at - _pt(t0)).dot(Vector2(-tan.y, tan.x))
		if _side == 0.0:
			_side = off
		elif signf(off) == signf(_side):
			_side = off if absf(off) > absf(_side) else _side
		elif absf(_side) >= 14.0 and absf(off) >= 6.0 and float(near[1]) <= 40.0:
			player.inv.use("needle_thread")
			b.stitch(wound, t0)
			player.sheet.composure = maxf(player.sheet.composure - 2.0, 0.0)
			_side = off
			if not player.inv.has("needle_thread"):
				_say("That was the last of the thread.")
				tool = "hand"
		return
	var winding := (tool == "bandage" or tool == "clean_rag") and float(near[1]) > 46.0 and _at.distance_to(c) > 60.0
	if winding and _has(tool):
		# Winding it on: round and round the wound.
		var ang := (_at - c).angle()
		if _wrap_on:
			_wrap += absf(angle_difference(_wrap_ang, ang)) / TAU
		_wrap_ang = ang
		_wrap_on = true
		if _wrap >= WRAP_TURNS:
			player.inv.use(tool)
			b.dress(wound, "bandage" if tool == "bandage" else "rag")
			_say("Dressed." if not wound["fester"] else "Dressed, but it was not clean. It will fester.")
			_wrap = 0.0
			_down = false
			if not _has(tool):
				tool = "hand"
		return
	_wrap_on = false
	if (tool == "hand" or tool == "clean_rag") and float(near[1]) <= 40.0:
		var d := _at.distance_to(_bleeder())
		b.press(wound, delta, clampf(remap(d, 28.0, 130.0, 1.0, 0.25), 0.25, 1.0), tool == "clean_rag")
	elif (tool == "vodka" or tool == "water") and float(near[1]) <= 30.0 and not wound["clean"]:
		if not _poured:
			if not player.inv.use(tool):
				return
			_poured = true
		var i := clampi(int(float(near[0]) * WASH_PARTS), 0, WASH_PARTS - 1)
		if not _washed[i]:
			_washed[i] = true
			if tool == "vodka":
				player.sheet.composure = maxf(player.sheet.composure - 1.5, 0.0)   # it stings
			if not _washed.has(false):
				b.wash(wound)
				_poured = false
				_say("Washed." if int(wound["debris"]) == 0 else "Washed, but something is still in it.")


# ---------------------------------------------------------------- drawing
func _text(pos: Vector2, text: String, col := C_TEXT, px := 18) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _tray_cell(i: int) -> Rect2:
	var a := _area()
	var w := a.size.x / TOOLS.size()
	return Rect2(a.position.x + w * i, _sz().y - 150.0, w - 8.0, 96.0)


func _draw() -> void:
	if player == null:
		return
	var b := player.sheet.body
	draw_rect(Rect2(Vector2.ZERO, _sz()), C_BACK)
	_draw_body(b)
	var a := _area()
	draw_rect(a, C_PANEL)
	draw_rect(a, C_LINE, false, 2.0)
	if wound.is_empty():
		_text(a.position + Vector2(24, 44), "Nothing here that your hands can help.", C_DIM, 22)
	else:
		_draw_wound(b, a)
	_draw_tray()
	# The hand.
	var col := C_MARK if _down else Color.WHITE
	draw_circle(_at, 7.0, Color(0, 0, 0, 0.6))
	draw_arc(_at, 9.0, 0.0, TAU, 20, col, 2.0)
	draw_line(_at - Vector2(15, 0), _at + Vector2(15, 0), col, 1.5)
	draw_line(_at - Vector2(0, 15), _at + Vector2(0, 15), col, 1.5)
	_text(_at + Vector2(16, -12), Items.name_of(tool) if tool != "hand" else "Bare hand", col, 15)


func _draw_body(b: BodyHealth) -> void:
	var x := 40.0
	var w := _sz().x * 0.36 - 70.0
	draw_rect(Rect2(x - 14.0, 40.0, w + 28.0, _sz().y - 80.0), C_PANEL)
	_text(Vector2(x, 78), "YOUR BODY", C_TEXT, 24)
	_text(Vector2(x, 104), "H or a move key puts it down.   Hold ALT to look up.", C_DIM, 15)
	_text(Vector2(x, 140), player.death_feel(), C_WARN if b.blood < 70.0 else C_TEXT, 19)
	var guess := b.time_left_guess()
	if guess != "":
		_text(Vector2(x, 164), guess, C_MARK, 16)
	var bite := b.bite_guess()
	if bite != "":
		draw_multiline_string(_font, Vector2(x, 186), bite, HORIZONTAL_ALIGNMENT_LEFT, w, 15, 2, C_WARN)
	var y := 230.0
	_rows.clear()
	for part in BodyHealth.PARTS:
		var lines := b.describe(part)
		var i := 0
		for o in b.wounds:
			if o["part"] != part:
				continue
			var r := Rect2(x - 6.0, y, w + 12.0, 52.0)
			var can := BodyHealth.treatable(o)
			if is_same(o, wound):
				draw_rect(r, Color(0.3, 0.24, 0.12, 0.9))
				draw_rect(r, C_MARK, false, 2.0)
			elif can:
				draw_rect(r, C_LINE, false, 1.0)
			_text(r.position + Vector2(10, 21), BodyHealth.NAMES[part], C_WARN, 18)
			_text(r.position + Vector2(10, 43), lines[i] if i < lines.size() else "", C_TEXT if can else C_DIM, 16)
			if can:
				_rows.append([r, o])
			else:
				_text(r.position + Vector2(w - 150.0, 21), "only rest helps", C_DIM, 14)
			y += 58.0
			i += 1
	if b.wounds.is_empty():
		_text(Vector2(x, y + 20.0), "Nothing wrong that you can tell.", C_DIM)
	# Your hands.
	var s := shake()
	var how := "steady" if s < 8.0 else ("unsteady" if s < 20.0 else ("shaking" if s < 36.0 else "shaking badly"))
	y = _sz().y - 150.0
	_text(Vector2(x, y), "Hands: %s" % how, C_GOOD if s < 8.0 else (C_TEXT if s < 20.0 else C_WARN), 19)
	_text(Vector2(x, y + 24.0), "Pain, fear and lost blood make them wander.", C_DIM, 15)
	_text(Vector2(x, y + 44.0), "Calm down, or take something for the pain.", C_DIM, 15)
	if b.painkiller_t > 0.0:
		_text(Vector2(x, y + 68.0), "Painkillers are working.", C_GOOD, 15)
	_text(Vector2(x, y + 92.0), "Medical %d of 10" % b.medical, C_DIM, 15)


func _draw_wound(b: BodyHealth, a: Rect2) -> void:
	var med := b.medical
	var bleed: float = wound["bleed"]
	var kind: String = wound["kind"]
	var title: String = BodyHealth.NAMES[wound["part"]].to_upper() + ": "
	title += ("IT HURTS" + (" AND IT BLEEDS" if bleed > b.ooze else "")) if med < 2 else str(BodyHealth.KINDS[kind][0]).to_upper()
	_text(Vector2(a.position.x, 92), title, C_TEXT, 24)

	# Skin, and the wound in it.
	var skin := a.grow(-14.0)
	draw_rect(skin, C_SKIN)
	for i in 9:
		var yy := skin.position.y + skin.size.y * (i + 0.5) / 9.0
		draw_line(Vector2(skin.position.x, yy), Vector2(skin.end.x, yy + 6.0), C_SKIN_D, 1.0)
	var n := 28
	if kind == "stump":
		# The raw end of the limb: meat, and the bone in the middle (pink-ivory: fresh bone is never white).
		draw_circle(_centre(), 150.0, C_BLOOD_D)
		draw_circle(_centre(), 138.0, C_FLESH)
		draw_circle(_centre(), 40.0, Color(0.86, 0.74, 0.68))
		draw_circle(_centre(), 17.0, Color(0.45, 0.12, 0.12))
	elif kind == "gunshot":
		var r := _len() * 0.5
		draw_circle(_centre(), r + 9.0, C_BLOOD_D)
		draw_circle(_centre(), r, C_FLESH)
		draw_circle(_centre(), r * 0.5, C_BLOOD_D)
	elif kind == "bite":
		for i in n + 1:
			var t := float(i) / n
			var p := _pt(t)
			var bow := sin(t * PI) * 34.0
			for side: float in [-1.0, 1.0]:
				draw_circle(p + Vector2(0, side * (8.0 + bow)), 7.0 + 3.0 * _rand(40 + i), C_FLESH if i % 2 == 0 else C_BLOOD_D)
	else:
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / n
			var gape := sin(t * PI) * lerpf(9.0, 30.0, float(wound["sev"])) * (1.0 - 0.75 * BodyHealth.closed_frac(wound))
			var p := _pt(t)
			top.append(p + Vector2(0, -gape - 3.0 * _rand(50 + i)))
			bot.append(p + Vector2(0, gape + 3.0 * _rand(80 + i)))
		for i in n:
			draw_colored_polygon(PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]]), C_FLESH)
			draw_line(top[i], top[i + 1], C_BLOOD_D, 3.0)
			draw_line(bot[i], bot[i + 1], C_BLOOD_D, 3.0)
	# Taking the limb off: the line, the tourniquet on it, the blows so far.
	if _amp:
		var cx := _cut_x()
		if _amp_tied or _wrap > 0.0:
			var wdt := 46.0 * (1.0 if _amp_tied else _wrap / WRAP_TURNS)
			draw_rect(Rect2(cx - 70.0, skin.position.y, wdt, skin.size.y), Color(0.6, 0.58, 0.5))
		var yy := skin.position.y
		while yy < skin.end.y:
			draw_line(Vector2(cx, yy), Vector2(cx, minf(yy + 14.0, skin.end.y)), C_MARK, 3.0)
			yy += 24.0
		for i in _amp_blows:
			draw_rect(Rect2(cx - 5.0, skin.position.y, 10.0, skin.size.y * (i + 1) / BLOWS), C_BLOOD_D)
		_text(Vector2(cx + 14.0, skin.position.y + 24.0), "cut here", C_MARK, 16)
	# Washed parts look clean.
	for i in WASH_PARTS:
		if _washed[i] and not wound["clean"]:
			draw_circle(_pt((i + 0.5) / WASH_PARTS), 13.0, Color(0.85, 0.7, 0.66, 0.5))
	# What is in it. Blood hides it; without Medical it is only a darker speck.
	if bleed <= 0.1 or _grip >= 0:
		for i in _bits():
			if bleed > 0.1 and i != _grip:
				continue
			var p := _debris_pt(i) if i != _grip else _at
			draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), Color(0.2, 0.22, 0.24) if med < 2 else Color(0.75, 0.8, 0.85))
			if med >= 2:
				draw_arc(p, 13.0, 0.0, TAU, 16, C_MARK, 1.5)
	# Stitches, and (with enough Medical) where the rest should go.
	for s in wound["stitches"]:
		var p := _pt(float(s))
		draw_line(p + Vector2(-3, -17), p + Vector2(3, 17), Color(0.1, 0.1, 0.12), 3.0)
	var need := BodyHealth.stitches_needed(wound)
	if med >= 3 and tool == "needle_thread":
		for i in need:
			var ideal := (i + 0.5) / need
			var have := false
			for s in wound["stitches"]:
				have = have or absf(float(s) - ideal) <= 0.55 / need
			if not have:
				draw_arc(_pt(ideal), 12.0, 0.0, TAU, 12, C_MARK, 1.5)
	# Blood: it wells from the bleeder and runs.
	if bleed > 0.0:
		var bp := _bleeder()
		var r := 10.0 + 150.0 * minf(bleed, 0.3) * (1.0 + 0.12 * sin(_t * 6.0))
		draw_circle(bp, r, Color(C_BLOOD, 0.85))
		draw_rect(Rect2(bp.x - r * 0.3, bp.y, r * 0.6, minf(skin.end.y - bp.y, r * 4.0)), Color(C_BLOOD, 0.8))
		if bleed > 0.1:
			for i in 12:
				draw_circle(_pt(i / 11.0), 10.0 + 60.0 * bleed, Color(C_BLOOD, 0.7))
		if med >= 1 and bleed > b.ooze:
			draw_arc(bp, r + 8.0, 0.0, TAU, 24, C_MARK, 2.0)
			_text(bp + Vector2(r + 14.0, -r), "the bleeder: press here", C_MARK, 15)
	# The dressing, or one being wound on.
	var turns := WRAP_TURNS if wound["dressed"] != "" else _wrap
	if turns > 0.0:
		var cloth := C_CLOTH if (wound["dressed"] == "bandage" or (wound["dressed"] == "" and tool == "bandage")) else Color(0.6, 0.58, 0.5)
		var strips := int(turns / WRAP_TURNS * 7.0)
		var l := _len() + 80.0
		for i in strips:
			var x0 := _centre().x - l * 0.5 + l * i / 7.0
			draw_colored_polygon(PackedVector2Array([Vector2(x0, skin.position.y), Vector2(x0 + l / 7.0 + 6.0, skin.position.y),
				Vector2(x0 + l / 7.0 - 14.0, skin.end.y), Vector2(x0 - 20.0, skin.end.y)]), cloth)
			draw_line(Vector2(x0, skin.position.y), Vector2(x0 - 20.0, skin.end.y), cloth.darkened(0.25), 2.0)
		if wound["dressed"] != "" and bleed > b.ooze:
			draw_circle(_bleeder(), 26.0, Color(C_BLOOD, 0.75))   # coming through

	# What to do, in order.
	var y := a.end.y + 30.0
	var i := 1
	var steps: Array = b.steps(wound)
	if _amp:
		steps = [["Tie it off above the line", "tied" if _amp_tied else "not tied: it will pour", _amp_tied],
			["Chop on the line", "%d of %d blows" % [_amp_blows, BLOWS], false]]
		_text(Vector2(a.position.x + 520.0, 92), "TAKING IT OFF. There is no putting it back.", C_WARN, 20)
	for st in steps:
		_text(Vector2(a.position.x, y), "%d.  %s" % [i, st[0]], C_TEXT if not st[2] else C_DIM, 18)
		_text(Vector2(a.position.x + 360.0, y), st[1], C_GOOD if st[2] else C_WARN, 18)
		y += 26.0
		i += 1
	if _msg_t > 0.0:
		_text(Vector2(a.position.x, _sz().y - 190.0), _msg, C_MARK, 18)
	var hint: String = {"hand": "Hold on the wound to press on it. On a dressing: click to take it off.",
		"clean_rag": "Hold on the wound to press. Hold and wind round it, three turns, to tie it on.",
		"tweezers": "Grip what is in the wound, draw it out slowly, let go clear of the wound. A jerk tears it free.",
		"hatchet": "Tie it off first (wind a rag or bandage round the line). Then click on the line: three blows.", "vodka": "Hold and sweep along the wound to wash it. It stings.",
		"water": "Hold and sweep along the wound to wash it.",
		"needle_thread": "Hold and zigzag across the wound: every crossing is a stitch. Keep them even.",
		"bandage": "Hold and wind round the wound, three turns."}.get(tool, "")
	_text(Vector2(a.position.x, _sz().y - 164.0), hint, C_DIM, 15)


func _draw_tray() -> void:
	for i in TOOLS.size():
		var t := TOOLS[i]
		var r := _tray_cell(i)
		var have := _has(t)
		draw_rect(r, Color(0.3, 0.24, 0.12, 0.9) if t == tool else C_PANEL)
		draw_rect(r, C_MARK if t == tool else C_LINE, false, 2.0)
		_text(r.position + Vector2(10, 24), "%d" % (i + 1), C_DIM, 15)
		_text(r.position + Vector2(10, 52), "Bare hand" if t == "hand" else str(SHORT.get(t, Items.name_of(t))), C_TEXT if have else C_DIM, 14)
		var sub := ""
		if t != "hand":
			var key := player.inv.find(t)
			if key == "":
				sub = "none"
			else:
				var it: Dictionary = player.inv.slots[key]
				sub = ("%d left" % int(it["uses"])) if it.has("uses") else ("x%d" % int(it["n"]) if it.has("n") and Items.DEFS[t].has("stack") else "")
		_text(r.position + Vector2(10, 76), sub, C_DIM, 14)
