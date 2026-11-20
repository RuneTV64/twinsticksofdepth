class_name GrassPush
extends Node
## Who is pushing through the standing grass, besides the player: zombies and raiders. One node in the level.
## A few times a second it draws everyone near the player into a small map (a texel to half a metre, 32 m
## across, centred on the player) and hands it to the grass shader as a project-wide texture; the blades lean
## away from wherever the map is marked and are pressed down there. A map and not a list, so a whole horde
## wading through a meadow costs the shader nothing more than one zombie does.
## (The player's own parting is exact and separate: `grass_push`, set in Player._update_visuals.)

const SIZE := 64            # texels a side
const CELL := 0.5           # metres a texel

static var it: GrassPush
## Extra spots to mark, for previews and tests: [Vector3].
static var extra: Array = []

@export var every := 0.1    # s between redraws
@export var player: Node3D

var _img: Image
var _tex: ImageTexture
var _t := 0.0
var _had := false           # was anything marked last time? (when nothing is, and nothing was, there is nothing to send)


func _ready() -> void:
	it = self
	_img = Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("grass_push_map", _tex.get_rid())
	_send_rect(Vector2.ZERO)


func _exit_tree() -> void:
	if it == self:
		it = null


func _send_rect(origin: Vector2) -> void:
	RenderingServer.global_shader_parameter_set("grass_push_rect", Vector4(origin.x, origin.y, SIZE * CELL, SIZE * CELL))


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = every
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	var centre := player.global_position if player != null else Vector3.ZERO
	# The map moves with the player in whole texels, so the marks don't swim.
	var origin := Vector2(floorf(centre.x / CELL) * CELL, floorf(centre.z / CELL) * CELL) - Vector2.ONE * (SIZE * CELL * 0.5)
	var any := false
	_img.fill(Color(0, 0, 0))
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e.dead:
			continue
		any = _mark(e.global_position, origin, 1.0 if e.crawling else 0.8) or any
	for p: Vector3 in extra:
		any = _mark(p, origin, 0.8) or any
	if any or _had:
		_tex.update(_img)
		_send_rect(origin)
	_had = any


# A soft round mark: full where they stand, fading over `radius` metres.
func _mark(pos: Vector3, origin: Vector2, radius: float) -> bool:
	var fx := (pos.x - origin.x) / CELL
	var fy := (pos.z - origin.y) / CELL
	var r := radius / CELL
	if fx < -r or fy < -r or fx > SIZE + r or fy > SIZE + r:
		return false
	for y in range(maxi(floori(fy - r), 0), mini(ceili(fy + r) + 1, SIZE)):
		for x in range(maxi(floori(fx - r), 0), mini(ceili(fx + r) + 1, SIZE)):
			var d := Vector2(x + 0.5 - fx, y + 0.5 - fy).length() / r
			if d < 1.0:
				var v := 1.0 - d * d
				if v > _img.get_pixel(x, y).r:
					_img.set_pixel(x, y, Color(v, 0, 0))
	return true
