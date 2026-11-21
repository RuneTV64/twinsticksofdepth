class_name Cutaway
extends Node
## Keeps the cutaway up to date: whatever stands between the camera and the player is cut open (see
## cutaway.gdshaderinc). The camera never turns, so tall things to the south would otherwise hide the player and
## the ground behind them. One of these lives in the level; it sets a few project-wide shader values once a frame.
##
## Anything drawn with a shader that includes the cutaway takes part. The test level's walls, crates and doors
## do, through Cutaway.solid(); the modular building pieces to come should include it in their own shaders.

@export var radius := 2.6        # m: how far round the player the opening reaches
@export var soft := 0.9          # m: the dithered edge of it
@export var keep_below := 0.95   # m above the player's feet: walls are kept up to here, so you see where they stand
@export var enabled := true
## The cursor cutaway: with the weapon Ready (or looking about with free look), the same kind of opening is cut
## toward what the crosshair is on, so a wall, an upper floor or a roof never hides the spot you are aiming at.
## It opens to the crosshair's spot on your floor; or, when the crosshair is on something above your storey
## (Player.aim_high: an upstairs window, even one on the far side of the house), to that thing, through the
## roof. It eases open and shut; the crosshair itself never moves for it.
@export var aim_radius := 2.2    # m round the line to the crosshair
@export var aim_soft := 0.8
@export var aim_from := 2.0      # m from the player before it opens (nearer, the player's own opening does)
@export var aim_ease := 0.14     # s to open or shut
## Indoors (owner, 21 Nov 2026: walls cut away while the player is inside the building): the whole building
## opens. Every wall of it comes down to `keep_below` wherever it hides the building's floor (the walls on the
## camera's side and the walls between rooms; the far walls stand), and everything over the storey you are on
## goes: upper floors, the roof. Window glass stays, at half strength (glass.gdshader).
@export var room_ease := 0.3     # s for a building to open as you go in, and to close as you leave
@export var room_ceiling := 2.58 # m over the floor you are on: everything in the building above this goes
@export var room_climb := 5.0    # m/s: how fast the cut follows you from one storey to the next
var _aim_r := 0.0
var _aim_focus := Vector3.ZERO
var _aim_keep := 0.0
var _room_floor := 0.0

var player: Node3D
var camera: Camera3D

# What the shader was last told, kept so scripts can ask the same question (`hides()`).
static var _focus := Vector3.ZERO
static var _view := Vector3.DOWN
static var _shape := Vector4.ZERO

# The building the player is in, as the shader was last told (cutaway_room, cutaway_room2, cutaway_room3).
static var _room := Vector4.ZERO
static var _room2 := Vector4.ZERO
static var _room3 := Vector4.ZERO

## Buildings, by footprint. Whatever builds one says where it stands (HouseKit.house, main.gd's _house):
## {"rect": Rect2 on the map, "low": its lowest floor, "high": its top, "ground": the ground it stands on,
## "storey": the height of one storey, "eaves": how far its roof overhangs}.
static var buildings: Array = []


static func add_building(rect: Rect2, low: float, high: float, ground := 0.0, storey := 2.7, eaves := 0.6) -> void:
	buildings.append({"rect": rect, "low": low, "high": high, "ground": ground, "storey": storey, "eaves": eaves})


static func reset() -> void:
	buildings.clear()
	_room2 = Vector4.ZERO


## The building this spot is inside, or an empty Dictionary.
static func building_at(p: Vector3) -> Dictionary:
	for b in buildings:
		if (b["rect"] as Rect2).has_point(Vector2(p.x, p.z)) and p.y > b["low"] - 0.5 and p.y < b["high"]:
			return b
	return {}


static var _shader: Shader
static var _materials := {}


## The level's plain solid colour, with the cutaway in it. One material per colour, shared.
static func solid(color: Color, metal := 0.0) -> ShaderMaterial:
	var key := "%s/%.2f" % [color.to_html(), metal]
	if not _materials.has(key):
		if _shader == null:
			_shader = load("res://level_solid.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("metal", metal)
		_materials[key] = m
	return _materials[key]


## Is this point of the world cut away right now (not drawn, so not something the crosshair can be on)?
## The same test as the shader's, without the dithered edge.
static func hides(wp: Vector3) -> bool:
	if _shape.w < 0.5 or _view.y > -0.05:
		return false
	if _room2.w > 0.5 and _in_room(wp):
		return true
	if wp.y < _shape.z:
		return false
	var flat := Vector2(_view.x, _view.z).normalized()
	if Vector2(wp.x - _focus.x, wp.z - _focus.z).dot(flat) > -0.25:
		return false
	var t := (_focus.y - wp.y) / _view.y
	if t <= 0.0:
		return false
	var at := wp + _view * t
	return Vector2(at.x - _focus.x, at.z - _focus.z).length() < _shape.x - _shape.y * 0.5


static func _in_room(wp: Vector3) -> bool:
	var lo := Vector2(_room.x, _room.y)
	var hi := Vector2(_room.z, _room.w)
	var p := Vector2(wp.x, wp.z)
	if wp.y >= _room2.z:
		if p.x > lo.x and p.y > lo.y and p.x < hi.x and p.y < hi.y:
			return true
		var e := _room3.x
		if wp.y > _room3.y and p.x > lo.x - e and p.y > lo.y - e and p.x < hi.x + e and p.y < hi.y + e:
			return true
	if wp.y < _room2.y:
		return false
	var at := wp + _view * ((_room2.x - wp.y) / _view.y)
	return at.x > lo.x and at.z > lo.y and at.x < hi.x and at.z < hi.y


func _process(_delta: float) -> void:
	if player == null or camera == null or not enabled or player.get("dead"):
		_shape = Vector4(radius, soft, 0.0, 0.0)
		RenderingServer.global_shader_parameter_set("cutaway_shape", _shape)
		RenderingServer.global_shader_parameter_set("cutaway_aim", Vector4.ZERO)
		_aim_r = 0.0
		_room2.w = 0.0
		RenderingServer.global_shader_parameter_set("cutaway_room2", _room2)
		return
	var feet := player.global_position
	# Standing on bodies raises the player (perch): the opening follows.
	var lift: float = player.get("perch") if player.get("perch") != null else 0.0
	_focus = feet + Vector3(0.0, 1.0 + lift, 0.0)
	_view = -camera.global_transform.basis.z
	_shape = Vector4(radius, soft, feet.y + keep_below + lift, 1.0)
	RenderingServer.global_shader_parameter_set("cutaway_focus", _focus)
	RenderingServer.global_shader_parameter_set("cutaway_view", _view)
	RenderingServer.global_shader_parameter_set("cutaway_shape", _shape)
	_aim(feet, lift, _delta)
	_indoors(feet, _delta)


func _aim(feet: Vector3, lift: float, delta: float) -> void:
	var want := 0.0
	var ready: bool = player.get("armed") == true
	if (ready or player.get("free_look") == true) and player.get("reticle_visible") != false:
		var off: Vector3 = player.get("reticle_offset")
		var high = player.get("aim_high")
		if ready and high != null and is_instance_valid(high):
			# On something above your storey: open what hides it (the roof over a far wall's window).
			_aim_focus = player.get("aim_high_at")
			_aim_keep = -100000.0
			want = aim_radius
		elif Vector2(off.x, off.z).length() >= aim_from:
			_aim_focus = feet + off + Vector3(0.0, 1.0 + lift, 0.0)
			_aim_keep = feet.y + keep_below + lift
			want = aim_radius
	_aim_r = move_toward(_aim_r, want, aim_radius * delta / maxf(aim_ease, 0.01))
	RenderingServer.global_shader_parameter_set("cutaway_aim", Vector4(_aim_focus.x, _aim_focus.y, _aim_focus.z, _aim_r))
	RenderingServer.global_shader_parameter_set("cutaway_aim2", Vector4(aim_soft, _aim_keep, 0.0, 0.0))


func _indoors(feet: Vector3, delta: float) -> void:
	var b := building_at(feet)
	var step := delta / maxf(room_ease, 0.01)
	if b.is_empty():
		if _room2.w <= 0.0:
			return
		_room2.w = maxf(_room2.w - step, 0.0)      # the building you left closes as it was
	else:
		var r: Rect2 = b["rect"]
		var now := Vector4(r.position.x, r.position.y, r.end.x, r.end.y)
		# The storey you are on: the cut follows you up and down the stairs, a storey at a time.
		var storey: float = b["storey"]
		var want: float = b["low"] + roundf((feet.y - b["low"]) / storey) * storey
		if now != _room or _room2.w <= 0.0:
			_room = now
			_room_floor = want
		_room_floor = move_toward(_room_floor, want, room_climb * delta)
		var lid := _room_floor + room_ceiling
		_room2 = Vector4(_room_floor, _room_floor + keep_below, lid, minf(_room2.w + step, 1.0))
		_room3 = Vector4(b["eaves"], maxf(lid, float(b["ground"]) + 0.3), 0.0, 0.0)
		RenderingServer.global_shader_parameter_set("cutaway_room", _room)
		RenderingServer.global_shader_parameter_set("cutaway_room3", _room3)
	RenderingServer.global_shader_parameter_set("cutaway_room2", _room2)
