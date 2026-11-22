class_name Appliance
extends Node3D
## An appliance (owner, 21 Nov 2026: the living room's third session). Each is a solid thing (Solid.box, so it
## breaks like anything: rule 1) with this node on it, and each does something to the player (rule 2):
##
##   television  plugged in: a lit screen and a voice. Its glow lights whoever is in front of it (seen through a
##               window at night as if by day), and it talks on and on, heard `noise` m off: a lure you can leave
##               running in an empty house. What it says is the emergency broadcast.
##   floor lamp, table lamp
##               plugged in: light to see by in a dark room, and light that shows you to anyone looking in.
##               Shift+click picks one up (a lamp is an item: a club that breaks at once into glass and cord);
##               used from your things it is stood where you are, and works wherever there is a socket.
##   radio       batteries, not the mains: set down playing, it carries on by itself until they are flat or
##               something smashes it. The decoy that works anywhere.
##   candle      lit with a match: a little light without power, for half an hour of burning; blown out and
##               lit again, picked up and carried. Burned down, it is gone.
##   toy robot   batteries: set down, it marches off the way you were facing, clanking, turning at walls: a
##               decoy that leads the zombies after it, until its batteries go or one catches it.
##   kettle      mains: pour your bottle in, it boils it in 30 s (the bugs die, the mud stays), clicks off, and you
##               pour it back. No wood, no fire. Picked up and carried, it works at any socket.
##   microwave   mains: set it running and it hums for 20 s, then dings, loud: a timed lure, set and walk away.
##               With something metal in it (Shift+click: a tin, scrap metal) it sparks and goes with a bang
##               heard much further, and is wrecked.
##   dishwasher  mains: racks to search, and a 90 s wash cycle heard 9 m off the whole time: a lure that lasts.
##   kitchen timer
##               wound by hand: set down, it ticks for 30 s and then rings, heard `RING` m off. A timed lure
##               with no batteries and no power; picked up and wound again as often as you like.
##   telephone   the line is live while the power is: now and then it rings, and every zombie near hears it.
##               Answer it, or pull its cord out of the wall to shut it up for good (and keep the cord).
##
## Zombies that come to what is making the noise find it and beat on it until it stops (Enemy.hear_noise with
## the thing, `still_sounding`, `take_blow_from`). A worn-out one (wear 2) is dead: no light, no sound.
## How each looks is the furniture kit's (furniture_kit.gd: its meshes and its shader), so the cutaway, wear
## and the 8-shade look are the same as the furniture's.

## w, h, d: its size facing south. stuff / parts: what it is made of; thin: its strength as a share of a solid
## block of that. power: "mains", "battery", "burn" or "line". light: how far its light reaches (m), and the
## height of the glow; energy: how bright it looks (left out: a lamp's). noise: how far it is heard, every `every` s. item: what it is picked up as ("" can't be).
const KINDS := {
	"television": {"what": "television", "w": 0.56, "h": 0.48, "d": 0.56, "stuff": "plastic",
		"parts": {"glass": 0.3, "plastic": 0.5, "metal": 0.2}, "thin": 1.0, "power": "mains", "light": 3.0,
		"glow_y": 0.25, "tint": Color(0.62, 0.74, 1.0), "noise": 12.0, "every": 5.0, "item": ""},
	"floor_lamp": {"what": "floor lamp", "w": 0.4, "h": 1.62, "d": 0.4, "stuff": "glass",
		"parts": {"metal": 0.6, "cloth": 0.25, "glass": 0.15}, "thin": 0.5, "power": "mains", "light": 4.5,
		"glow_y": 1.45, "tint": Color(1.0, 0.82, 0.56), "noise": 0.0, "every": 0.0, "item": "floor_lamp"},
	"table_lamp": {"what": "table lamp", "w": 0.3, "h": 0.55, "d": 0.3, "stuff": "glass",
		"parts": {"glass": 0.5, "cloth": 0.3, "metal": 0.2}, "thin": 0.5, "power": "mains", "light": 3.5,
		"glow_y": 0.43, "tint": Color(1.0, 0.82, 0.56), "noise": 0.0, "every": 0.0, "item": "table_lamp"},
	"radio": {"what": "radio", "w": 0.36, "h": 0.22, "d": 0.12, "stuff": "plastic",
		"parts": {"plastic": 0.8, "metal": 0.2}, "thin": 1.2, "power": "battery", "light": 0.0,
		"glow_y": 0.1, "tint": Color.WHITE, "noise": 20.0, "every": 3.0, "item": "radio"},
	"candle": {"what": "candle", "w": 0.09, "h": 0.16, "d": 0.09, "stuff": "plastic",
		"parts": {}, "thin": 1.0, "power": "burn", "light": 1.8, "energy": 0.4,
		"glow_y": 0.15, "tint": Color(1.0, 0.72, 0.42), "noise": 0.0, "every": 0.0, "item": "candle"},
	"toy_robot": {"what": "toy robot", "w": 0.14, "h": 0.22, "d": 0.12, "stuff": "plastic",
		"parts": {"plastic": 0.6, "metal": 0.4}, "thin": 1.0, "power": "battery", "light": 0.0,
		"glow_y": 0.12, "tint": Color.WHITE, "noise": 10.0, "every": 1.6, "item": "toy_robot"},
	# The kitchen's (22 Nov 2026: the second theme's appliances). `cycle`: s it runs once started, then stops.
	"kettle": {"what": "kettle", "w": 0.2, "h": 0.25, "d": 0.16, "stuff": "plastic",
		"parts": {"plastic": 0.7, "metal": 0.3}, "thin": 1.0, "power": "mains", "light": 0.0,
		"glow_y": 0.12, "tint": Color.WHITE, "noise": 4.0, "every": 3.0, "item": "kettle", "cycle": 30.0},
	"microwave": {"what": "microwave", "w": 0.5, "h": 0.3, "d": 0.38, "stuff": "plastic",
		"parts": {"metal": 0.5, "glass": 0.15, "plastic": 0.35}, "thin": 0.8, "power": "mains", "light": 0.0,
		"glow_y": 0.15, "tint": Color.WHITE, "noise": 3.0, "every": 4.0, "item": "", "cycle": 20.0},
	"dishwasher": {"what": "dishwasher", "w": 0.6, "h": 0.85, "d": 0.6, "stuff": "plastic",
		"parts": {"metal": 0.5, "plastic": 0.5}, "thin": 0.5, "power": "mains", "light": 0.0,
		"glow_y": 0.4, "tint": Color.WHITE, "noise": 9.0, "every": 4.0, "item": "", "cycle": 90.0},
	"kitchen_timer": {"what": "kitchen timer", "w": 0.09, "h": 0.08, "d": 0.09, "stuff": "plastic",
		"parts": {"plastic": 0.7, "metal": 0.3}, "thin": 1.0, "power": "wind", "light": 0.0,
		"glow_y": 0.04, "tint": Color.WHITE, "noise": 2.0, "every": 2.0, "item": "kitchen_timer", "cycle": 30.0},
	"telephone": {"what": "telephone", "w": 0.22, "h": 0.1, "d": 0.2, "stuff": "plastic",
		"parts": {}, "thin": 0.5, "power": "line", "light": 0.0,
		"glow_y": 0.05, "tint": Color.WHITE, "noise": 15.0, "every": 3.0, "item": ""},
}

## The emergency broadcast, round and round (the television, and the radio between the static).
const BROADCAST := [
	"\"...remain indoors. Do not attempt to travel. Do not approach the sick...\"",
	"\"...relief centres have been established at the following locations...\"",
	"\"...if a member of your household has been bitten, isolate them at once...\"",
	"\"...this is not a test. Repeat, this is not a test...\"",
	"\"...power and water services will be maintained for as long as...\"",
]
const ANSWERS := [
	"Breathing on the line. Then it goes dead.",
	"A recorded voice: \"...all circuits are busy. Please try again later.\"",
	"A woman, crying, asking for someone called Dale. Then nothing.",
	"Static, and something under it like a crowd. Then it goes dead.",
	"\"Is anyone there? Please, we're at the school, we...\" The line goes dead.",
]

const RING_CHECK := 20.0       # s between looks at whether the phone rings
const RING_CHANCE := 0.04      # ... the chance it does then, while you are near (about once in eight minutes)
const RING_NEAR := 25.0        # m: it only rings with you this near (a stand-in for calls that matter to you)
const RINGS := 6               # rings before the caller gives up, `every` s apart
const DING := 16.0              # m: a microwave's ding
const RING := 15.0              # m: a kitchen timer's bell
const ZAP := 26.0               # m: the bang when something metal in it sparks
const ROBOT_SPEED := 0.25      # m/s: a toy robot's march (a wandering zombie is about 0.4)

var kind := "television"
var wear := 0
var stain := 1
var fabric := 0
var switched := false          # the switch is on (it works if it has power too: `working`)
var item := {}                 # what it is as an item (a radio carries its batteries' seconds in "uses")
var cut := false               # a phone with its cord pulled out, a television with its plug cut off
var floor_y := 0.0
var br: Breakable

var _look: MeshInstance3D
var _light: OmniLight3D
var _lamp_at := Vector3.INF    # where its lamp is in Daylight's list, while it is lit
var _t := 0.0
var _spent := 0.0              # battery seconds not yet taken off `item.uses`
var _rings := 0
var _ring_t := 0.0
var _said := 0
var _look_t := 0.0             # a toy robot: s until it looks ahead for a wall again
var _grid_t := 0.0             # ... until its place in Breakable's grid is brought up to date
var _run_t := 0.0              # what runs a cycle (kettle, microwave, dishwasher): s left of it
var water := {}                # the kettle: the water in it, as a bottle's ({"uses", "dirt", "bugs"}), {} empty
var boiled := false            # ... and whether it has come to the boil
var metal := false             # the microwave: something metal has been put in it


## Put one down: `at` is where its middle stands (y the surface it stands on: a floor, a table top), `facing`
## the way its front looks, `floor_at` the floor of the room it is in. Returns it.
static func put(level: Node, what_kind: String, at: Vector3, facing := "S", worn := 0, on := false,
		floor_at := NAN, carried := {}, wood := 1, cloth := 0) -> Appliance:
	var k: Dictionary = KINDS[what_kind]
	var turns: int = FurnitureKit.TURN.get(facing, 0)
	var h: float = k["h"]
	var size := Vector3(k["w"], h, k["d"]) if turns % 2 == 0 else Vector3(k["d"], h, k["w"])
	var fy := at.y if is_nan(floor_at) else floor_at
	var body := Solid.box(level, at + Vector3(0.0, h * 0.5, 0.0), size, Color(0.4, 0.4, 0.42), k["stuff"], k["what"],
		k["parts"], 0.0, Callable(), fy)
	body.set_meta("appliance", what_kind)
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var a := Appliance.new()
	a.kind = what_kind
	a.wear = worn
	a.stain = wood
	a.fabric = cloth
	a.switched = on
	a.floor_y = fy
	a.item = carried if not carried.is_empty() else (Items.make(k["item"]) if k["item"] != "" else {})
	if carried.is_empty() and Items.DEFS.get(k["item"], {}).has("uses"):
		var full := int(Items.DEFS[k["item"]]["uses"])
		a.item["uses"] = randi_range(full / 3, full)        # found part used
	if worn >= 2 and not a.item.is_empty():
		a.item["dead"] = true                   # it never works again, wherever it is put
	a.br = Breakable.of(body)
	a.br.splitter = Callable()                  # it breaks whole
	a.br.thin_to(float(k["thin"]))
	a.br.hp = a.br.max_hp * float(FurnitureKit.WEAR_HP[worn])
	a.br.stage = worn
	a.position = Vector3(0.0, -h * 0.5, 0.0)
	a.rotation.y = turns * PI * 0.5
	body.add_child(a)
	# Somewhere things are kept (stash.gd): a dishwasher's racks. Searched through the appliance (its click).
	var stash := Stash.for_piece(what_kind, str(k["what"]), wood, worn)
	if stash != null:
		body.add_child(stash)
		stash.remove_from_group("interactables")
		a.br.broke.connect(func(_by: Node) -> void:
			if is_instance_valid(stash):
				stash.spill())
	return a


func _ready() -> void:
	add_to_group("interactables")
	var k: Dictionary = KINDS[kind]
	_look = MeshInstance3D.new()
	_look.mesh = FurnitureKit.mesh_of(kind)
	add_child(_look)
	if float(k["light"]) > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = k["tint"]
		_light.omni_range = float(k["light"]) + 1.0
		_light.light_energy = float(k.get("energy", 1.2))
		_light.shadow_enabled = false
		_light.position = Vector3(0.0, float(k["glow_y"]), 0.0)
		add_child(_light)
	br.on_stage = func(_stage: int) -> void: _show()
	br.broke.connect(func(_by: Node) -> void: _dark())
	if KINDS[kind]["power"] != "battery":
		Power.watch(_on_power)            # a method, not a lambda: it stops being valid when this is freed
	_ring_t = randf_range(0.0, RING_CHECK)
	_show()


func _exit_tree() -> void:
	_dark()


func _on_power(_now: bool) -> void:
	_show()


## Does it do what it does now?
func working() -> bool:
	if br == null or not br.alive() or wear >= 2 or cut:
		return false
	match str(KINDS[kind]["power"]):
		"mains":
			return switched and Power.at(global_position)
		"battery", "burn":
			return switched and int(item.get("uses", 0)) > 0
		"wind":
			return switched
		"line":
			return Power.on
	return false


## Is it still making the noise that brought them (zombies stop beating on it when it stops).
func still_sounding() -> bool:
	if kind == "telephone":
		return working() and _rings > 0
	return working() and float(KINDS[kind]["noise"]) > 0.0


## A zombie that came to the noise beats on it.
func take_blow_from(by: Node, force: float) -> void:
	if br != null and br.alive():
		br.hit(force, "blunt", global_position + Vector3(0.0, float(KINDS[kind]["glow_y"]), 0.0), by)


## How it is drawn and lit, after anything changes.
func _show() -> void:
	if not is_inside_tree():
		return
	var lit := working() and kind != "telephone"
	_look.material_override = FurnitureKit.mat(stain, fabric, br.stage if br != null else wear, lit)
	var k: Dictionary = KINDS[kind]
	var shines := lit and float(k["light"]) > 0.0
	if _light != null:
		_light.visible = shines
	var spot := global_position + Vector3(0.0, float(k["glow_y"]), 0.0)
	if shines and _lamp_at == Vector3.INF:
		_lamp_at = Vector3(spot.x, floor_y, spot.z)
		Daylight.add_lamp(_lamp_at, float(k["light"]))
	elif not shines:
		_dark()
	set_process(working() and (float(k["noise"]) > 0.0 or k["power"] == "battery" or k["power"] == "burn") or kind == "telephone")


## Out of Daylight's list of lamps.
func _dark() -> void:
	if _lamp_at != Vector3.INF:
		Daylight.remove_lamp(_lamp_at)
		_lamp_at = Vector3.INF
	if _light != null and is_instance_valid(_light):
		_light.visible = false


func _process(delta: float) -> void:
	var k: Dictionary = KINDS[kind]
	if kind == "telephone":
		_phone(delta)
		return
	if not working():
		_show()
		return
	if k["power"] == "battery" or k["power"] == "burn":
		_spent += delta
		if _spent >= 1.0:
			_spent -= 1.0
			item["uses"] = int(item["uses"]) - 1
			if int(item["uses"]) <= 0:
				if kind == "candle":
					_gone()                   # burned down to nothing
					return
				_show()
				return
	if kind == "toy_robot":
		_walk(delta)
	if k.has("cycle"):
		_run_t -= delta
		if _run_t <= 0.0:
			_cycle_done()
			return
	if float(k["noise"]) <= 0.0:
		return
	_t -= delta
	if _t <= 0.0:
		_t = float(k["every"]) * randf_range(0.85, 1.15)
		_said = (_said + 1) % BROADCAST.size()
		Earshot.make(global_position + Vector3(0.0, 0.3, 0.0), float(k["noise"]), get_tree(), null, false, self)


## A cycle has run its course: the kettle has boiled, the microwave dings (or bangs), the wash is done.
func _cycle_done() -> void:
	switched = false
	match kind:
		"kettle":
			if not water.is_empty():
				Water.boil(water)
				boiled = true
			Earshot.make(global_position, 3.0, get_tree(), null, false)     # it clicks off
		"microwave":
			if metal:
				Earshot.make(global_position, ZAP, get_tree(), null, false)
				metal = false
				_show()
				br.give_way(null)                    # sparks, a bang, smoke: it is finished
				return
			Earshot.make(global_position, DING, get_tree(), null, false, self)
		"kitchen_timer":
			Earshot.make(global_position, RING, get_tree(), null, false, self)
	_show()


## Start a cycle.
func _start() -> void:
	switched = true
	_run_t = float(KINDS[kind]["cycle"])
	_t = 0.0
	_show()


## The toy robot marches on the way it faces; at a wall (or anything solid) it turns, and goes on.
func _walk(delta: float) -> void:
	var body := br.host
	if body == null:
		return
	var fwd := global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.2
		var from := body.global_position + Vector3(0.0, 0.0, 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 0.3, 1 | Solid.GLASS_LAYER, [body.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			rotation.y += deg_to_rad(randf_range(100.0, 160.0)) * (1.0 if randf() < 0.5 else -1.0)
			return
	body.global_position += fwd * ROBOT_SPEED * delta
	_grid_t -= delta
	if _grid_t <= 0.0:
		_grid_t = 0.3
		var half := br.rect.size * 0.5
		br.rect = Rect2(Vector2(body.global_position.x, body.global_position.z) - half, br.rect.size)
		br.reindex()


## Gone altogether (a candle burned down).
func _gone() -> void:
	_dark()
	if br != null and br.host != null:
		Cover.remove_box(br.host)
		br.host.queue_free()


## The phone: now and then, with you near, it rings, and goes on ringing until it is answered or the caller
## gives up. Each ring is a noise.
func _phone(delta: float) -> void:
	if not working():
		_rings = 0
		return
	if _rings > 0:
		_t -= delta
		if _t <= 0.0:
			_t = float(KINDS[kind]["every"])
			_rings -= 1
			Earshot.make(global_position, float(KINDS[kind]["noise"]), get_tree(), null, false, self)
		return
	_ring_t -= delta
	if _ring_t > 0.0:
		return
	_ring_t = RING_CHECK
	var p := _player()
	if p != null and p.global_position.distance_to(global_position) < RING_NEAR and randf() < RING_CHANCE:
		ring()


## Ring now (the chance above, or a test).
func ring() -> void:
	if not working():
		return
	_rings = RINGS
	_t = 0.0
	set_process(true)


func ringing() -> bool:
	return _rings > 0


func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] as Player if not ps.is_empty() else null


# ---------------------------------------------------------------------------------------- interactable
func interact_point() -> Vector3:
	return global_position + global_transform.basis.z * 0.3


func can_interact(p: Player) -> bool:
	return br != null and br.alive() and absf(p.global_position.y - floor_y) < 1.2


func prompt_text(_p: Player) -> String:
	var k: Dictionary = KINDS[kind]
	var what: String = k["what"]
	var lift := "   (Shift+click: pick it up)" if k["item"] != "" else ""
	if wear >= 2:
		return "The %s is dead%s" % [what, lift if k["item"] != "" else ""]
	match kind:
		"telephone":
			if cut:
				return "The phone, its cord pulled out"
			if _rings > 0:
				return "Answer the phone   (Shift+click: pull the cord out)"
			return "Pick up the phone   (Shift+click: pull the cord out)"
		"television":
			if cut:
				return "The television, its plug cut off"
			if working():
				return "Switch the television off   %s   (Shift+click: cut its cord off)" % BROADCAST[_said]
			return "Switch the television on (it will be heard)   (Shift+click: cut its cord off)"
		"radio":
			if int(item.get("uses", 0)) <= 0:
				return "The radio's batteries are flat%s" % lift
			return ("Switch the radio off" if switched else "Switch the radio on (it will be heard)") + lift
		"toy_robot":
			if int(item.get("uses", 0)) <= 0:
				return "The toy robot's batteries are flat%s" % lift
			return ("Switch the toy robot off" if switched else "Switch the toy robot on (it walks off, clanking)") + lift
		"candle":
			return ("Blow the candle out" if switched else "Light the candle (a match)") + "   (Shift+click: pick it up)"
		"kitchen_timer":
			return ("The timer is ticking: %d s" % ceili(_run_t) if switched else "Wind the timer (it rings in 30 s)") + lift
		"kettle":
			if switched:
				return "The kettle is coming to the boil" + (" (no power: it has stopped)" if not Power.at(global_position) else "")
			if not water.is_empty():
				return "Pour the %s water back into your bottle%s" % ["boiled" if boiled else "unboiled", lift]
			return "Pour your water in and boil it (30 s)" + lift
		"microwave":
			if switched:
				return "The microwave is humming: it will ding in %d s" % ceili(_run_t)
			return "Set the microwave running (it dings in 20 s, loud)   (Shift+click: put a tin or scrap metal in it first)"
		"dishwasher":
			if switched:
				return "The dishwasher is churning (%d s left)" % ceili(_run_t)
			return "Look in the dishwasher   (Shift+click: run it: 90 s, heard 9 m off)"
	return ("Switch the %s off" % what if switched else "Switch the %s on" % what) + lift


func interact(p: Player) -> void:
	var k: Dictionary = KINDS[kind]
	p._body.reach()
	var shift := Input.is_key_pressed(KEY_SHIFT)
	if shift and k["item"] != "":
		pick_up(p)
		return
	if shift and (kind == "telephone" or kind == "television") and not cut:
		cut = true
		_rings = 0
		var cord := Items.make("electric_cord")
		var rest := p.inv.add(cord)
		if not rest.is_empty():
			p._drop(rest)
		p.recompute_stats()
		_show()
		p.show_status(("You yank the cord out of the wall. It won't ring again." if kind == "telephone"
			else "You cut the cord off the back of the set.") + ("" if rest.is_empty() else " It is at your feet."), 2.0)
		return
	if wear >= 2 or cut:
		p.show_status("It is dead.", 1.4)
		return
	if kind == "kitchen_timer":
		if switched:
			p.show_status("It is ticking: %d s to go." % ceili(_run_t), 1.2)
		else:
			_start()
			p.show_status("You wind it. Thirty seconds.", 1.4)
		return
	if KINDS[kind].has("cycle"):
		_use_cycle(p, shift)
		return
	match kind:
		"telephone":
			if not working():
				p.show_status("The line is dead.", 1.6)
			elif _rings > 0:
				_rings = 0
				p.show_status(ANSWERS[randi() % ANSWERS.size()], 3.2)
			else:
				p.show_status("A dial tone. There is nobody left to call.", 2.2)
			return
		"radio", "toy_robot":
			if int(item.get("uses", 0)) <= 0:
				p.show_status("Nothing: the batteries are flat.", 1.6)
				return
		"candle":
			if not switched and not p.inv.use("matches"):
				p.show_status("You need a match to light it.", 1.6)
				return
	switched = not switched
	_t = 0.0
	_show()
	if switched and not working():
		p.show_status("Nothing. No power." if k["power"] == "mains" else "Nothing.", 1.6)
	elif switched and kind == "television":
		p.show_status("The set warms up: the emergency broadcast, loud in the empty house.", 2.2)
	elif switched and kind == "radio":
		p.show_status("Static, then a voice. It will play until the batteries go.", 2.0)
	elif kind == "candle":
		p.show_status("You light the candle." if switched else "You blow the candle out.", 1.4)
	elif switched and kind == "toy_robot":
		p.show_status("It whirrs and clanks off.", 1.4)
	else:
		p.show_status("Off." if not switched else "On.", 1.0)


## The kettle, the microwave, the dishwasher.
func _use_cycle(p: Player, shift: bool) -> void:
	if switched:
		p.show_status("Leave it to finish.", 1.2)
		return
	if not Power.at(global_position):
		p.show_status("Nothing. No power.", 1.4)
		return
	match kind:
		"kettle":
			var wk := p.inv.find("water")
			if not water.is_empty():
				if wk == "":
					p.show_status("You have no bottle to pour it into.", 1.6)
					return
				var b: Dictionary = p.inv.slots[wk]
				for f in ["uses", "dirt", "bugs", "done"]:
					if water.has(f):
						b[f] = water[f]
					else:
						b.erase(f)
				water = {}
				boiled = false
				p.show_status("You pour it back into your bottle. It looks %s." % Water.look(b), 1.8)
				return
			if wk == "" or int(p.inv.slots[wk].get("uses", 0)) <= 0:
				p.show_status("You have no water to boil.", 1.6)
				return
			var bottle: Dictionary = p.inv.slots[wk]
			water = {"uses": bottle["uses"], "dirt": Water.dirt(bottle), "bugs": Water.bugs(bottle)}
			if bottle.has("done"):
				water["done"] = bottle["done"]
			bottle["uses"] = 0
			_start()
			p.show_status("You pour your water into the kettle and switch it on.", 1.8)
		"microwave":
			if shift:
				var mk := ""
				for id: String in ["empty_tin", "scrap_metal", "canned_food"]:
					if mk == "" and p.inv.has(id):
						mk = id
				if mk == "":
					p.show_status("You have nothing metal to put in it.", 1.6)
					return
				p.inv.use(mk)
				p.recompute_stats()
				metal = true
				_start()
				p.show_status("You shut the %s in it and set it running. Get clear." % Items.name_of(mk).to_lower(), 2.2)
				return
			_start()
			p.show_status("It hums. In 20 s it will ding, loud.", 1.8)
		"dishwasher":
			if shift:
				_start()
				p.show_status("It fills and starts to churn: a minute and a half of noise.", 2.0)
				return
			var st := _stash()
			if st != null:
				st.interact(p)


func _stash() -> Stash:
	if br == null or br.host == null:
		return null
	for c in br.host.get_children():
		if c is Stash:
			return c
	return null


## Pick it up: it goes into your things as the item it is (a lamp, a radio with its batteries).
func pick_up(p: Player) -> bool:
	var it := item.duplicate(true)
	it.erase("on")
	var rest := p.inv.add(it)
	if not rest.is_empty():
		p.show_status("No room for it: free a hand.", 1.6)
		return false
	p.recompute_stats()
	p.show_status("You pick up the %s." % KINDS[kind]["what"], 1.4)
	_dark()
	if br != null and br.host != null:
		Cover.remove_box(br.host)
		br.host.queue_free()
	return true


## The thing it stood on has gone: down it comes to the floor, and glass may not survive it.
func fall_to(y: float) -> void:
	if br == null or not br.alive() or br.host == null:
		return
	var body := br.host
	var h: float = KINDS[kind]["h"]
	var drop := body.global_position.y - h * 0.5 - y
	if drop < 0.05:
		return
	_dark()
	body.global_position.y = y + h * 0.5
	br.foot = y
	br.top = y + h
	if drop > 0.3 and (kind == "television" or kind == "table_lamp") and randf() < 0.5:
		br.give_way(null)                       # the screen or the base shatters on the floor
		return
	_show()


## Stand one you are carrying (an item) at a spot on a floor; the radio comes down playing.
static func set_down(level: Node, it: Dictionary, at: Vector3, facing: Vector3) -> Appliance:
	var what_kind := str(it["id"])
	# Its front toward you, as you would put it down.
	var turns := posmod(roundi(atan2(-facing.x, -facing.z) / (PI * 0.5)), 4)
	var face: String = ["S", "E", "N", "W"][turns]
	if what_kind == "toy_robot":
		turns = posmod(roundi(atan2(facing.x, facing.z) / (PI * 0.5)), 4)     # off the way you face
		face = ["S", "E", "N", "W"][turns]
	var dead := bool(it.get("dead", false))
	var playing := what_kind in ["radio", "toy_robot", "candle"] and int(it.get("uses", 0)) > 0 and not dead
	var a := Appliance.put(level, what_kind, at, face, 2 if dead else 0, playing, at.y, it)
	if what_kind == "kitchen_timer":
		a._start()                             # set down wound
	return a
