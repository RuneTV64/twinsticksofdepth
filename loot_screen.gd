class_name LootScreen
extends Control
## Going through things (owner, 20 Nov 2026; built to the owner's sketch, tools/sketches/loot_screen_sketch.png).
## The lower part of the screen: on the left what you carry (your slots, what you wear, and the grid of a bag
## on your back), on the right the thing you are searching, drawn as itself: an open drawer, a cupboard, a
## fridge (item_art.gd), with a grid over it. The world stays in view above, but you only see a short way in
## front of you while your head is in a drawer; ALT looks up and your hands stop.
##
##  - Searching: a part nobody has been through is dark. The column your hand is over is gone through, and
##    the drawer itself is the meter: it comes up out of the dark from the front. When a column is done,
##    what lies in it shows. Shift hurries (three times as fast) and is heard. A part once searched opens at
##    once from then on.
##  - Things lie on each other as they were left. One with a gold edge has something under it: move it.
##  - The hand: drag a thing to move it (a slot, a square of the bag, a square of the drawer, onto your feet
##    or head to wear it, up out of the panel to put it on the ground). Double-click sends it across (take,
##    or put back). Right-click uses what is in a slot, or tells you what a thing is for; Shift+right-click
##    takes what is in a slot apart (Player.take_apart).
##  - 1 2 3 pick the drawer. Moving, being grabbed or being hit shuts it. Esc or I shuts it.
## The mouse is captured in play, so the hand is this screen's own pointer.

const C_BACK := Color(0.05, 0.05, 0.06, 0.95)
const C_PANEL := Color(0.11, 0.11, 0.13, 0.95)
const C_LINE := Color(0.32, 0.32, 0.36)
const C_TEXT := Color(0.86, 0.84, 0.8)
const C_DIM := Color(0.56, 0.55, 0.53)
const C_WARN := Color(0.91, 0.51, 0.42)
const C_GOOD := Color(0.56, 0.82, 0.56)
const C_MARK := Color(1.0, 0.75, 0.3)
const BAG_CELL := 40.0
## What you wear, as a small grid laid out head to foot (Clothes.PLACES), four to a row.
const WORN_GRID := [
	["head", "eyes", "face", "neck"],
	["cloak", "outer", "shirt", "undershirt"],
	["wrist_l", "hands", "fingers", "wrist_r"],
	["strap", "waist", "legs", "underwear"],
	["back", "socks", "feet", ""],
]
const WORN_TAG := {"head": "Head", "eyes": "Eyes", "face": "Face", "neck": "Neck", "cloak": "Cloak", "outer": "Coat",
	"shirt": "Shirt", "undershirt": "Under", "wrist_l": "L wrist", "hands": "Hands", "fingers": "Rings", "wrist_r": "R wrist",
	"strap": "Strap", "waist": "Belt", "legs": "Legs", "underwear": "Under", "back": "Back", "socks": "Socks", "feet": "Feet"}
const WORN_BOX := 46.0

var player: Player

var _ptr := Vector2(1100, 600)
var _part := 0
var _held := {}              # what the hand has hold of: {"item", "from", "key", "thing", "part", "grab", "cell"}
var _msg := ""
var _msg_t := 0.0
var _noise := 0.0            # how loud you are being, 0 to 1 (the meter)
var _noise_t := 0.0
var _filling := -1           # the column being gone through this frame, or -1
var _t := 0.0
var _click_t := -1.0
var _click_at := Vector2.ZERO
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	_font = ThemeDB.fallback_font


func _sz() -> Vector2:
	return get_viewport_rect().size


func open() -> void:
	visible = true
	_held = {}
	_msg_t = 0.0
	_noise = 0.0
	_part = 0
	var st := _stash()
	if st != null:
		# Start on the first part that hasn't been gone through, with the hand over its first column.
		for i in st.parts.size():
			if not st.searched(i):
				_part = i
				break
		_ptr = _box_origin() + Vector2(_box_cell() * 0.5, _box_cell() * float(st.parts[_part]["grid"]["h"]) * 0.5)
	else:
		_ptr = _left().position + _left().size * 0.5


func close() -> void:
	_put_back()
	visible = false


func _say(text: String) -> void:
	_msg = text
	_msg_t = 3.0


func _stash() -> Stash:
	if player == null or player.search == null or not is_instance_valid(player.search):
		return null
	return player.search


# ----------------------------------------------------------------------------------------------- layout
func _panel() -> Rect2:
	var s := _sz()
	return Rect2(40.0, s.y * 0.4, maxf(s.x - 80.0, 200.0), maxf(s.y * 0.6 - 16.0, 200.0))


func _left() -> Rect2:
	var p := _panel()
	return Rect2(p.position, Vector2(p.size.x * 0.5 - 3.0, p.size.y))


func _right() -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(p.size.x * 0.5 + 3.0, 0.0), Vector2(p.size.x * 0.5 - 3.0, p.size.y))


## Your slots and what you wear, as boxes: [{"where", "key", "rect", "name", "limit", "info"}]. The slots are the
## ones your clothes give you now (Inventory.slot_list()), in a column; what you wear is a grid head to foot.
func _slot_boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var l := _left()
	var y0 := l.position.y + 80.0
	for r in WORN_GRID.size():
		for c in 4:
			var key: String = WORN_GRID[r][c]
			if key == "":
				continue
			var nm := ""
			for wr in Inventory.WORN:
				if wr[0] == key:
					nm = wr[1]
			out.append({"where": "worn", "key": key, "rect": Rect2(l.position.x + 24.0 + c * (WORN_BOX + 4.0), y0 + r * (WORN_BOX + 4.0), WORN_BOX, WORN_BOX),
				"name": nm, "limit": 0.0})
	var list := player.inv.slot_list()
	var h := clampf((l.size.y - 110.0) / maxf(list.size(), 1.0) - 4.0, 22.0, 34.0)
	for i in list.size():
		var sl: Array = list[i]
		out.append({"where": "slot", "key": str(sl[0]), "rect": Rect2(l.position.x + 230.0, y0 + i * (h + 4.0), 240.0, h),
			"name": str(sl[1]), "limit": float(sl[2]), "info": sl})
	return out


## The bag on your back's grid, or {} with none.
func _bag() -> Dictionary:
	var bag = player.inv.worn.get("back")
	return Items.hold_of(bag) if bag != null else {}


func _bag_origin() -> Vector2:
	return _left().position + Vector2(486.0, 104.0)


func _box_cell() -> float:
	var st := _stash()
	if st == null:
		return 48.0
	var g: Dictionary = st.parts[_part]["grid"]
	var r := _right()
	return floorf(clampf(minf((r.size.x - 90.0) / float(g["w"]), (r.size.y - 250.0) / float(g["h"])), 28.0, 76.0))


func _box_origin() -> Vector2:
	return _right().position + Vector2(48.0, 122.0)


func _tabs() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var st := _stash()
	if st == null:
		return out
	var r := _right()
	for i in st.parts.size():
		out.append(Rect2(r.position.x + 36.0 + 168.0 * i, r.position.y + 58.0, 160.0, 30.0))
	return out


## What is under this spot: {"where": "slot" | "worn" | "bag" | "box" | "tab" | "out" | "", ...}.
func _hit(pos: Vector2) -> Dictionary:
	if not _panel().has_point(pos):
		return {"where": "out" if pos.y < _panel().position.y else ""}
	for b in _slot_boxes():
		if (b["rect"] as Rect2).has_point(pos):
			return {"where": b["where"], "key": b["key"], "limit": b["limit"]}
	var bag := _bag()
	if not bag.is_empty():
		var c := ((pos - _bag_origin()) / BAG_CELL).floor()
		if c.x >= 0 and c.y >= 0 and c.x < int(bag["w"]) and c.y < int(bag["h"]):
			return {"where": "bag", "cell": Vector2i(c), "thing": ItemGrid.at(bag, Vector2i(c))}
	var st := _stash()
	if st != null:
		var tabs := _tabs()
		for i in tabs.size():
			if tabs[i].has_point(pos):
				return {"where": "tab", "i": i}
		var g: Dictionary = st.part(_part)["grid"]
		var c2 := ((pos - _box_origin()) / _box_cell()).floor()
		if c2.x >= 0 and c2.y >= 0 and c2.x < int(g["w"]) and c2.y < int(g["h"]):
			var t := ItemGrid.at(g, Vector2i(c2))
			return {"where": "box", "cell": Vector2i(c2), "thing": t if not t.is_empty() and st.shows(_part, t) else {}}
	return {"where": ""}


# ------------------------------------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventMouseMotion:
		if not player.search_look:
			_ptr = (_ptr + event.relative).clamp(Vector2(10, 10), _sz() - Vector2(10, 10))
	elif event is InputEventMouseButton and not player.search_look:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press()
			else:
				_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _held.is_empty():
			var h := _hit(_ptr)
			if event.shift_pressed and str(h.get("where", "")) == "slot" and player.inv.slots.has(h["key"]):
				player.take_apart(h["key"])       # Shift+right-click: take it apart
				_say(player.status_text)
			else:
				_use(h)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		var st := _stash()
		if k == KEY_ESCAPE:
			player.stop_search()
			get_viewport().set_input_as_handled()
		elif st != null and k >= KEY_1 and k <= KEY_9 and k - KEY_1 < st.parts.size():
			_put_back()
			_part = k - KEY_1
			get_viewport().set_input_as_handled()


func _press() -> void:
	var h := _hit(_ptr)
	var twice := _t - _click_t < 0.35 and _ptr.distance_to(_click_at) < 14.0
	_click_t = _t
	_click_at = _ptr
	if h["where"] == "tab":
		_part = int(h["i"])
		return
	if twice:
		_click_t = -1.0
		_across(h)
	else:
		_pick_up(h)


## Take hold of what is under the hand.
func _pick_up(h: Dictionary) -> void:
	var inv := player.inv
	match str(h["where"]):
		"slot":
			var it = inv.slots.get(h["key"])
			if it != null:
				inv.slots.erase(h["key"])
				_held = {"item": it, "from": "slot", "key": h["key"], "grab": Vector2(BAG_CELL, BAG_CELL) * 0.5}
		"worn":
			if inv.worn.has(h["key"]):
				var on := inv.doff(h["key"])            # what is in its pockets goes with it
				_held = {"item": on, "from": "worn", "key": h["key"], "grab": Vector2(BAG_CELL, BAG_CELL) * 0.5}
				player._worn_changed()
		"bag", "box":
			var t: Dictionary = h["thing"]
			if t.is_empty():
				return
			var box: bool = h["where"] == "box"
			var g: Dictionary = _stash().part(_part)["grid"] if box else _bag()
			var cell := _box_cell() if box else BAG_CELL
			var origin := _box_origin() if box else _bag_origin()
			ItemGrid.remove(g, t)
			_held = {"item": t["item"], "from": h["where"], "thing": t, "part": _part,
				"grab": _ptr - (origin + Vector2(int(t["x"]), int(t["y"])) * cell)}
	if not _held.is_empty():
		player.recompute_stats()


## Let go of it where the hand is.
func _release() -> void:
	if _held.is_empty():
		return
	var item: Dictionary = _held["item"]
	var id: String = item["id"]
	var inv := player.inv
	var h := _hit(_ptr)
	var done := false
	match str(h["where"]):
		"slot":
			var have = inv.slots.get(h["key"])
			if have == null:
				if Inventory.fits(h["info"], item):
					inv.slots[h["key"]] = item
					done = true
				elif Items.weight(item) > float(h["limit"]):
					_say("Too heavy for that: it takes up to %.1f kg." % float(h["limit"]))
				else:
					_say("That only takes something long.")
			else:
				done = _merge(have, item, float(h["limit"]))
		"worn":
			if str(Items.DEFS[id].get("wear", "")) == str(h["key"]) and not inv.worn.has(h["key"]):
				inv.don(item)
				player._worn_changed()
				done = true
			elif str(Items.DEFS[id].get("wear", "")) != str(h["key"]):
				var place := str(Items.DEFS[id].get("wear", ""))
				_say("That isn't worn there." if place == "" else "That goes: %s." % _place_name(place).to_lower())
		"bag", "box":
			var box: bool = h["where"] == "box"
			var st := _stash()
			var g: Dictionary = st.part(_part)["grid"] if box else _bag()
			var cell := _box_cell() if box else BAG_CELL
			var origin := _box_origin() if box else _bag_origin()
			var c := Vector2i(((_ptr - (_held["grab"] as Vector2) - origin) / cell + Vector2(0.5, 0.5)).floor())
			var on: Dictionary = h["thing"]
			if not on.is_empty() and on["item"]["id"] == id and item.has("n"):
				done = _merge(on["item"], item, 9999.0)
			elif box and not st.can_put(_part, id, c):
				_say("It won't lie there." if st.searched(_part) else "You can only put things where you have looked.")
			elif not box and Items.DEFS[id].has("hold"):
				_say("A bag doesn't go in a bag.")
			elif ItemGrid.put(g, item, c):
				done = true
			else:
				_say("It won't lie there.")
		"out":
			player._drop(item)
			_say("You put the %s on the ground." % Items.name_of(id).to_lower())
			done = true
	if done:
		_held = {}
	else:
		_put_back()
	player.recompute_stats()


## Add what the hand holds to a stack of the same thing. True if all of it went on.
func _merge(have: Dictionary, item: Dictionary, limit: float) -> bool:
	if have["id"] != item["id"] or not have.has("n") or not item.has("n"):
		return false
	var each := maxf(float(Items.DEFS[item["id"]]["w"]), 0.001)
	var room := mini(int(Items.DEFS[item["id"]].get("stack", 1)) - int(have["n"]), floori((limit - Items.weight(have)) / each + 0.001))
	var move := clampi(room, 0, int(item["n"]))
	have["n"] = int(have["n"]) + move
	item["n"] = int(item["n"]) - move
	return int(item["n"]) <= 0


## What the hand holds goes back where it came from.
func _put_back() -> void:
	if _held.is_empty() or player == null:
		return
	var item: Dictionary = _held["item"]
	match str(_held["from"]):
		"slot":
			player.inv.slots[_held["key"]] = item
		"worn":
			player.inv.don(item)
			player._worn_changed()
		"bag":
			var bag := _bag()
			if bag.is_empty():
				player._drop(item)
			else:
				bag["things"].append(_held["thing"])
		"box":
			var st := _stash()
			if st == null:
				player._drop(item)
			else:
				st.parts[int(_held["part"])]["grid"]["things"].append(_held["thing"])
	_held = {}
	player.recompute_stats()


## Double-click: send it across. Out of the drawer into what you carry; out of what you carry into the drawer.
func _across(h: Dictionary) -> void:
	var inv := player.inv
	var st := _stash()
	match str(h["where"]):
		"box":
			var t: Dictionary = h["thing"]
			if t.is_empty():
				return
			var g: Dictionary = st.part(_part)["grid"]
			ItemGrid.remove(g, t)
			var rest := inv.add(t["item"])
			if rest.is_empty():
				_say("Taken: %s." % Items.label(t["item"]))
			else:
				g["things"].append(t)
				_say("No room for it: your slots are full%s." % (" and so is your bag" if not _bag().is_empty() else ""))
		"slot":
			var it = inv.slots.get(h["key"])
			if it == null:
				return
			if st != null:
				if _into_box(it):
					inv.slots.erase(h["key"])
			elif not _bag().is_empty() and ItemGrid.add(_bag(), it):
				inv.slots.erase(h["key"])
		"bag":
			var bt: Dictionary = h["thing"]
			if bt.is_empty():
				return
			var bag := _bag()
			ItemGrid.remove(bag, bt)
			if st != null:
				if not _into_box(bt["item"]):
					bag["things"].append(bt)
			else:
				var ok := false
				for sl in inv.slot_list():
					if not inv.slots.has(sl[0]) and Inventory.fits(sl, bt["item"]):
						inv.slots[sl[0]] = bt["item"]
						ok = true
						break
				if not ok:
					bag["things"].append(bt)
					_say("No slot will take it.")
		"worn":
			player.use_item("worn:" + str(h["key"]))
			_say(player.status_text)
	player.recompute_stats()


## Lay it in the open part, in the first clear place you have already looked. False if there is none.
func _into_box(item: Dictionary) -> bool:
	var st := _stash()
	var g: Dictionary = st.part(_part)["grid"]
	for y in int(g["h"]):
		for x in int(g["w"]):
			if st.can_put(_part, item["id"], Vector2i(x, y)):
				g["things"].append({"item": item, "x": x, "y": y, "z": 0})
				return true
	_say("No room for it there." if st.searched(_part) else "You can only put things where you have looked.")
	return false


## Right-click: use what is in a slot; anywhere else, what the thing is for.
func _use(h: Dictionary) -> void:
	match str(h["where"]):
		"slot":
			if player.inv.slots.has(h["key"]):
				player.use_item(h["key"])
				_say(player.status_text)
		"worn":
			if player.inv.worn.has(h["key"]):
				player.use_item("worn:" + str(h["key"]))
				_say(player.status_text)
		"bag", "box":
			var t: Dictionary = h["thing"]
			if not t.is_empty():
				_say("%s Take it in a hand, on your belt or in a pocket to use it." % Items.about(t["item"]["id"]))


# ---------------------------------------------------------------------------------------------- searching
func _process(delta: float) -> void:
	if not visible or player == null:
		return
	_t += delta
	_msg_t -= delta
	modulate.a = move_toward(modulate.a, 0.12 if player.search_look else 1.0, delta * 6.0)
	_noise = maxf(_noise - delta * 1.2, 0.0)
	_filling = -1
	var st := _stash()
	if st != null:
		_part = clampi(_part, 0, st.parts.size() - 1)
		if not player.search_look and _held.is_empty():
			var h := _hit(_ptr)
			if h["where"] == "box" and float(st.part(_part)["found"][(h["cell"] as Vector2i).x]) < 1.0:
				# The hand is over a column nobody has been through: go through it.
				var col: int = (h["cell"] as Vector2i).x
				var hurry := Input.is_action_pressed("sprint")
				_filling = col
				if st.search(_part, col, delta * (player.hurry_mult if hurry else 1.0) / maxf(player.search_pace(), 0.1)):
					var turned_up: Array[String] = []
					for t: Dictionary in st.parts[_part]["grid"]["things"]:
						if ItemGrid.rect_of(t).end.x - 1 == col and st.shows(_part, t):
							turned_up.append(Items.name_of(t["item"]["id"]).to_lower())
					if not turned_up.is_empty():
						_say("In there: %s." % ", ".join(turned_up))
				if hurry:
					_noise = 1.0
					_noise_t -= delta
					if _noise_t <= 0.0:
						_noise_t = 0.45
						Earshot.make(player.global_position, player.hurry_noise, player.get_tree(), player, true)
	queue_redraw()


# ------------------------------------------------------------------------------------------------ drawing
func _text(pos: Vector2, text: String, col := C_TEXT, px := 16) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _fit(text: String, px: int, width: float) -> String:
	var out := text
	while out.length() > 3 and _font.get_string_size(out, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		out = out.substr(0, out.length() - 4) + "..."
	return out


# A thing's picture in a box of squares, with how many there are.
func _draw_item(item: Dictionary, r: Rect2, alpha := 1.0) -> void:
	draw_texture_rect(ItemArt.icon(item["id"]), r.grow(-2.0), false, Color(1, 1, 1, alpha))
	if item.has("n") and int(item["n"]) > 1:
		var s := "x%d" % int(item["n"])
		var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(r.end - Vector2(w + 6.0, 16.0), Vector2(w + 5.0, 15.0)), Color(0, 0, 0, 0.7 * alpha))
		_text(r.end - Vector2(w + 3.0, 4.0), s, Color(C_TEXT, alpha), 13)


func _draw() -> void:
	if player == null:
		return
	var p := _panel()
	draw_rect(p, C_BACK)
	draw_rect(_left(), C_PANEL)
	draw_rect(_right(), C_PANEL)
	draw_rect(_left(), C_LINE, false, 2.0)
	draw_rect(_right(), C_LINE, false, 2.0)
	var hover := _hit(_ptr)
	_draw_you(hover)
	_draw_box(hover)
	# What the hand is over, or what was last said.
	var line := ""
	var col := C_TEXT
	if _msg_t > 0.0:
		line = _msg
		col = C_MARK
	else:
		var it := _item_under(hover)
		var where := (_place_name(hover["key"]) + ": ") if hover["where"] == "worn" else ""
		if not it.is_empty():
			line = "%s%s  (%.2f kg)   %s" % [where, Items.label(it), Items.weight(it), Items.about(it["id"])]
		elif hover["where"] == "worn":
			line = where + "nothing. Drag something here to put it on."
	_text(p.position + Vector2(24.0, p.size.y - 40.0), _fit(line, 15, p.size.x - 48.0), col, 15)
	_text(p.position + Vector2(24.0, p.size.y - 14.0),
		"Drag: move    Double-click: take / put back    Right-click: use    Shift+right-click: take apart    Drag up out of here: put on the ground    Shift: hurry (loud)    ALT: look up    Esc, I or walk away: stop",
		C_DIM, 13)
	# What the hand holds.
	if not _held.is_empty():
		var sz := Vector2(Items.size_of(_held["item"]["id"]))
		var cell := _box_cell() if _held["from"] == "box" else BAG_CELL
		_draw_item(_held["item"], Rect2(_ptr - (_held["grab"] as Vector2), sz * cell), 0.9)
	# The hand.
	var hc := C_MARK if not _held.is_empty() else Color.WHITE
	draw_circle(_ptr, 6.0, Color(0, 0, 0, 0.6))
	draw_arc(_ptr, 8.0, 0.0, TAU, 20, hc, 2.0)
	draw_line(_ptr - Vector2(13, 0), _ptr + Vector2(13, 0), hc, 1.5)
	draw_line(_ptr - Vector2(0, 13), _ptr + Vector2(0, 13), hc, 1.5)


func _place_name(place: String) -> String:
	for wr in Inventory.WORN:
		if wr[0] == place:
			return wr[1]
	return place


func _item_under(h: Dictionary) -> Dictionary:
	match str(h["where"]):
		"slot":
			var it = player.inv.slots.get(h["key"])
			return it if it != null else {}
		"worn":
			var on = player.inv.worn.get(h["key"])
			return on if on != null else {}
		"bag", "box":
			var t: Dictionary = h["thing"]
			return t["item"] if not t.is_empty() else {}
	return {}


func _draw_you(hover: Dictionary) -> void:
	var l := _left()
	var inv := player.inv
	_text(l.position + Vector2(24, 36), "YOU", C_TEXT, 24)
	_text(l.position + Vector2(92, 34), "%.1f kg carried.  Each slot takes one thing, up to a weight." % inv.weight(), C_DIM, 14)
	_text(l.position + Vector2(24, 70), "Wearing", C_DIM, 15)
	_text(l.position + Vector2(230, 70), "Carrying", C_DIM, 15)
	for b in _slot_boxes():
		var r: Rect2 = b["rect"]
		var it = inv.slots.get(b["key"]) if b["where"] == "slot" else inv.worn.get(b["key"])
		var over: bool = hover["where"] == b["where"] and hover.get("key", "") == b["key"]
		# A worn place lights up while the hand holds something that goes there.
		var goes: bool = not _held.is_empty() and b["where"] == "worn" and str(Items.DEFS[_held["item"]["id"]].get("wear", "")) == str(b["key"])
		draw_rect(r, Color(0.16, 0.16, 0.19) if it != null else (Color(0.14, 0.13, 0.08) if goes else Color(0.08, 0.08, 0.1)))
		draw_rect(r, C_MARK if over or goes else C_LINE, false, 1.0)
		if b["where"] == "worn":
			if it == null:
				_text(r.position + Vector2(4, r.size.y * 0.5 + 4.0), _fit(str(WORN_TAG.get(b["key"], b["key"])), 11, r.size.x - 6.0), Color(C_DIM, 0.55), 11)
			else:
				var szw := Vector2(Items.size_of(it["id"]))
				var kw := (r.size.x - 8.0) / maxf(szw.x, szw.y)
				draw_texture_rect(ItemArt.icon(it["id"]), Rect2(r.position + (r.size - szw * kw) * 0.5, szw * kw), false)
			continue
		var side := r.size.y - 4.0
		if it == null:
			_text(r.position + Vector2(8, r.size.y * 0.5 + 5.0), "%s  (%.1f kg)" % [str(b["name"]), float(b["limit"])], Color(C_DIM, 0.6), 12)
		else:
			var sz := Vector2(Items.size_of(it["id"]))
			var k := side / maxf(sz.x, sz.y)
			draw_texture_rect(ItemArt.icon(it["id"]), Rect2(r.position + Vector2(2.0 + (side - sz.x * k) * 0.5, 2.0 + (side - sz.y * k) * 0.5), sz * k), false)
			var tag := _fit(str(b["name"]), 10, 78.0)
			_text(r.position + Vector2(side + 8.0, r.size.y * 0.5 + 5.0), _fit(Items.label(it), 13, r.size.x - side - 92.0), C_TEXT, 13)
			_text(Vector2(r.end.x - 4.0 - _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, r.position.y + r.size.y * 0.5 + 4.0), tag, Color(C_DIM, 0.7), 10)
	# The bag.
	var bag := _bag()
	var o := _bag_origin()
	if bag.is_empty():
		_text(o + Vector2(0, -8), "No bag", C_DIM, 15)
		_text(o + Vector2(0, 16), "A bag on your back holds a", Color(C_DIM, 0.7), 13)
		_text(o + Vector2(0, 34), "grid of things.", Color(C_DIM, 0.7), 13)
		return
	_text(o + Vector2(0, -24), "%s  (%.1f kg in it)" % [Items.name_of(inv.worn["back"]["id"]), ItemGrid.weight(bag)], C_DIM, 15)
	_draw_grid(bag, o, BAG_CELL, ItemArt.backdrop("bag", 0, int(bag["w"]), int(bag["h"])), null, 0, hover if hover["where"] == "bag" else {})


func _draw_box(hover: Dictionary) -> void:
	var r := _right()
	var st := _stash()
	if st == null:
		_text(r.position + Vector2(24, 36), "NOTHING OPEN", C_DIM, 24)
		_text(r.position + Vector2(24, 70), "These are the things you carry. Go up to a drawer, a cupboard,", C_DIM, 15)
		_text(r.position + Vector2(24, 92), "a wardrobe or a fridge and interact to search it.", C_DIM, 15)
		return
	_text(r.position + Vector2(24, 36), st.title.to_upper(), C_TEXT, 24)
	var tabs := _tabs()
	for i in tabs.size():
		var on := i == _part
		draw_rect(tabs[i], Color(0.2, 0.2, 0.24) if on else Color(0.08, 0.08, 0.1))
		draw_rect(tabs[i], C_MARK if on else C_LINE, false, 1.0)
		_text(tabs[i].position + Vector2(8, 20), "%d  %s" % [i + 1, st.parts[i]["name"]], C_TEXT if on else C_DIM, 14)
		draw_rect(Rect2(tabs[i].position + Vector2(0, tabs[i].size.y - 3.0), Vector2(tabs[i].size.x * st.progress(i), 3.0)), C_GOOD if st.searched(i) else C_MARK)
	var part: Dictionary = st.part(_part)
	var g: Dictionary = part["grid"]
	var cell := _box_cell()
	var o := _box_origin()
	_draw_grid(g, o, cell, ItemArt.backdrop(str(part["look"]), st.stain, int(g["w"]), int(g["h"])), st, _part, hover if hover["where"] == "box" else {})
	# Under it: how far through it you are, and how loud you are being.
	var y := o.y + cell * float(g["h"]) + 26.0 + ItemArt.EDGE * cell / float(ItemArt.PX)
	_text(Vector2(o.x, y), "Searched", C_DIM, 15)
	draw_rect(Rect2(o.x + 84.0, y - 12.0, 180.0, 12.0), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(o.x + 84.0, y - 12.0, 180.0 * st.progress(_part), 12.0), C_GOOD if st.searched(_part) else C_MARK)
	_text(Vector2(o.x + 290.0, y), "Noise", C_DIM, 15)
	draw_rect(Rect2(o.x + 344.0, y - 12.0, 120.0, 12.0), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(o.x + 344.0, y - 12.0, 120.0 * clampf(_noise, 0.04, 1.0), 12.0), C_WARN if _noise > 0.3 else C_GOOD)
	_text(Vector2(o.x + 474.0, y), "LOUD" if _noise > 0.3 else "quiet", C_WARN if _noise > 0.3 else C_DIM, 15)
	if not st.searched(_part):
		_text(Vector2(o.x, y + 26.0), "Hold your hand over the dark to go through it. Shift hurries, and is heard.", C_DIM, 14)


# A grid with its backdrop, what lies in it, and (for a stash) the dark over what hasn't been gone through.
func _draw_grid(g: Dictionary, o: Vector2, cell: float, back: Texture2D, st: Stash, part_i: int, hover: Dictionary) -> void:
	var gw := int(g["w"])
	var gh := int(g["h"])
	var k := cell / float(ItemArt.PX)
	draw_texture_rect(back, Rect2(o - Vector2.ONE * ItemArt.EDGE * k, Vector2(gw * ItemArt.PX + ItemArt.EDGE * 2, gh * ItemArt.PX + ItemArt.EDGE * 2) * k), false)
	for x in range(1, gw):
		draw_line(o + Vector2(x * cell, 0), o + Vector2(x * cell, gh * cell), Color(0, 0, 0, 0.16), 1.0)
	for y in range(1, gh):
		draw_line(o + Vector2(0, y * cell), o + Vector2(gw * cell, y * cell), Color(0, 0, 0, 0.16), 1.0)
	for t: Dictionary in g["things"]:
		if st != null and not st.shows(part_i, t):
			continue
		var rc := ItemGrid.rect_of(t)
		var r := Rect2(o + Vector2(rc.position) * cell, Vector2(rc.size) * cell)
		draw_rect(r.grow(-1.0), Color(0, 0, 0, 0.22))
		_draw_item(t["item"], r)
		var over: bool = not hover.is_empty() and is_same(hover.get("thing", {}), t)
		if int(t.get("z", 0)) > 0:
			# Something lies under it.
			for i in range(0, int(r.size.x), 8):
				draw_line(r.position + Vector2(i, 1), r.position + Vector2(minf(i + 4.0, r.size.x), 1), C_MARK, 2.0)
				draw_line(r.position + Vector2(i, r.size.y - 1.0), r.position + Vector2(minf(i + 4.0, r.size.x), r.size.y - 1.0), C_MARK, 2.0)
			for j in range(0, int(r.size.y), 8):
				draw_line(r.position + Vector2(1, j), r.position + Vector2(1, minf(j + 4.0, r.size.y)), C_MARK, 2.0)
				draw_line(r.position + Vector2(r.size.x - 1.0, j), r.position + Vector2(r.size.x - 1.0, minf(j + 4.0, r.size.y)), C_MARK, 2.0)
		elif over:
			draw_rect(r, Color.WHITE, false, 1.0)
	if st == null:
		return
	# What hasn't been gone through is dark; the column being searched comes up out of it from the front.
	var found: Array = st.parts[part_i]["found"]
	var none := true
	for x in gw:
		var f := clampf(float(found[x]), 0.0, 1.0)
		if f > 0.0:
			none = false
		if f >= 1.0:
			continue
		var dark := Rect2(o + Vector2(x * cell, 0), Vector2(cell, gh * cell * (1.0 - f)))
		draw_rect(dark, Color(0.03, 0.03, 0.04, 0.94))
		for i in range(0, int(dark.size.y), 10):
			draw_line(dark.position + Vector2(0, i), dark.position + Vector2(minf(cell, dark.size.y - i), i + minf(cell, dark.size.y - i)), Color(1, 1, 1, 0.05), 1.0)
		if x == _filling:
			draw_line(dark.position + Vector2(0, dark.size.y), dark.position + Vector2(cell, dark.size.y), C_MARK, 2.0)
			draw_rect(Rect2(o + Vector2(x * cell, 0), Vector2(cell, gh * cell)), C_MARK, false, 1.0)
	if none:
		_text(o + Vector2(gw * cell * 0.5 - 62.0, gh * cell * 0.5 + 6.0), "not searched yet", Color(C_DIM, 0.8), 16)
