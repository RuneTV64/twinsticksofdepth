class_name Ground
extends StaticBody3D
## A level's ground: one flat slab you can walk on, drawn by ground.gdshader from a map painted here.
## Building a level's ground is a few lines:
##
##   var g := Ground.new()
##   add_child(g)
##   g.setup(Rect2(-40, -112, 80, 152), "soil")              # the area (x, z, width, depth) and what it is made of
##   g.road([Vector2(0, 38), Vector2(2, 10), Vector2(0, -36)])   # a dirt road through these points
##   g.rect("farm", Rect2(16, 12, 20, 20), 20.0)                 # a ploughed field, its rows 20 degrees round
##   g.blob("mud", Vector2(-8, 20), 4.0)                         # a round patch
##   g.apply()                                                   # once, when the painting is done
##
## The kinds are in KINDS. The borders between them are made ragged by the shader, so paint plain shapes.
## The season and the weather come from Seasons (seasons.gd); nothing here changes with them.

const CELL := 0.25      # metres to a map texel
const TRACK_CELL := 0.125   # metres to a texel of the tracks map: a footprint is two of them long
## Dirt is 0 to 7, grass from 8 (dirt_types.gdshaderinc, grass_types.gdshaderinc).
const KINDS := {"soil": 0, "farm": 1, "road": 2, "clay": 3, "mud": 4, "lawn": 8, "meadow": 9, "rough": 10}

static var it: Ground

var area := Rect2()
var road_width := 4.0
@export var mud_slow := 0.5         # walking speed in the deepest, wettest mud, as a share of normal
var material: ShaderMaterial
var mesh: MeshInstance3D

var _img: Image
var _tex: ImageTexture
var _w := 0
var _h := 0
# Tracks: where feet have pressed into soft ground. One byte a texel (how deep), drawn by the shader.
var _tracks: Image
var _tracks_tex: ImageTexture
var _tw := 0
var _th := 0
var _tracks_dirty := false
var _tracks_t := 0.0
var _road_d := PackedFloat32Array()     # how far each texel is from the middle of the nearest road painted so far


func _enter_tree() -> void:
	it = self


func _exit_tree() -> void:
	if it == self:
		it = null


## Make the slab and its map, all of one kind.
func setup(rect: Rect2, base := "soil") -> void:
	area = rect
	collision_layer = 1
	_w = ceili(rect.size.x / CELL)
	_h = ceili(rect.size.y / CELL)
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	_road_d.resize(_w * _h)
	_road_d.fill(INF)
	fill(base)
	_tw = ceili(rect.size.x / TRACK_CELL)
	_th = ceili(rect.size.y / TRACK_CELL)
	_tracks = Image.create(_tw, _th, false, Image.FORMAT_R8)
	_tracks_tex = ImageTexture.create_from_image(_tracks)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x + 10.0, 1.0, rect.size.y + 10.0)
	shape.shape = box
	shape.position = Vector3(rect.get_center().x, -0.5, rect.get_center().y)
	add_child(shape)
	mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size + Vector2(10.0, 10.0)
	mesh.mesh = plane
	mesh.position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = load("res://assets/ground/ground.gdshader")
	mesh.material_override = material
	add_child(mesh)


func _px(kind: String, lat := 0.5, dir := Vector2.RIGHT) -> Color:
	return Color8(int(KINDS[kind]) * 16, clampi(roundi(lat * 255.0), 0, 255),
		roundi((dir.x * 0.5 + 0.5) * 255.0), roundi((dir.y * 0.5 + 0.5) * 255.0))


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - area.position.x) / CELL), floori((p.y - area.position.y) / CELL))


func fill(kind: String) -> void:
	_img.fill(_px(kind))


## A rectangle of one kind. `dir_deg` turns its rows (a field's furrows) round from running east-west.
func rect(kind: String, r: Rect2, dir_deg := 0.0) -> void:
	var a := _cell(r.position)
	var b := _cell(r.end)
	_img.fill_rect(Rect2i(a, b - a).intersection(Rect2i(0, 0, _w, _h)), _px(kind, 0.5, Vector2.from_angle(deg_to_rad(dir_deg))))


## A round patch of one kind.
func blob(kind: String, centre: Vector2, radius: float, dir_deg := 0.0) -> void:
	var px := _px(kind, 0.5, Vector2.from_angle(deg_to_rad(dir_deg)))
	var a := _cell(centre - Vector2(radius, radius))
	var b := _cell(centre + Vector2(radius, radius))
	for y in range(maxi(a.y, 0), mini(b.y + 1, _h)):
		for x in range(maxi(a.x, 0), mini(b.x + 1, _w)):
			var p := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
			if p.distance_to(centre) <= radius:
				_img.set_pixel(x, y, px)


## A strip of one kind along a line of points (a road, a footpath, a muddy track). Roads get their ruts from
## this: the map remembers which way the strip runs and how far across it each spot is. `width` 0 = road_width
## (every road on one Ground is drawn the same width: the ruts are spaced from it).
func path(kind: String, points: Array, width := 0.0) -> void:
	var half := (width if width > 0.0 else road_width) * 0.5
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 < 0.0001:
			continue
		var dir := ab.normalized()
		var lo := _cell(Vector2(minf(a.x, b.x) - half, minf(a.y, b.y) - half))
		var hi := _cell(Vector2(maxf(a.x, b.x) + half, maxf(a.y, b.y) + half))
		for y in range(maxi(lo.y, 0), mini(hi.y + 1, _h)):
			for x in range(maxi(lo.x, 0), mini(hi.x + 1, _w)):
				var p := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
				var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				var off := p - (a + ab * t)
				var d := off.length()
				if d > half or d >= _road_d[y * _w + x]:
					continue
				_road_d[y * _w + x] = d
				var lat := dir.cross(p - a)        # signed: which side of the middle line
				_img.set_pixel(x, y, _px(kind, clampf(lat / (half * 2.0) + 0.5, 0.0, 1.0), dir))


## A dirt road through these points.
func road(points: Array) -> void:
	path("road", points)


## Send the painted map to the shader. Call it when the painting is done (and again after painting more).
func apply() -> void:
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	material.set_shader_parameter("kind_map", _tex)
	material.set_shader_parameter("aim_map", _tex)
	material.set_shader_parameter("map_rect", Vector4(area.position.x, area.position.y, _w * CELL, _h * CELL))
	material.set_shader_parameter("road_width", road_width)
	material.set_shader_parameter("track_map", _tracks_tex)
	material.set_shader_parameter("track_rect", Vector4(area.position.x, area.position.y, _tw * TRACK_CELL, _th * TRACK_CELL))


# ---------------------------------------------------------------- soft ground: slowing and tracks
## How soft the ground is at a place, 0 firm .. 1 deep mud, as the season has it (seasons.gd): mud is soft unless
## a drought has baked it or a frost has frozen it; a ploughed field is soft; anything is when it is soaked;
## and lying snow takes a print whatever is under it.
func softness(pos: Vector3) -> float:
	var s := Seasons.it.now if Seasons.it != null else Vector4(1, 0, 0, 0)
	var kind := kind_at(pos)
	var frozen := s.w > 0.5
	var soft := 0.0
	if kind == "mud":
		var year := fposmod(s.x, 4.0)
		var summer := clampf(1.0 - absf(year - 1.0), 0.0, 1.0)
		soft = 0.0 if frozen else clampf(0.65 + 0.35 * s.y - 0.8 * summer * (1.0 - s.y), 0.0, 1.0)
	elif not frozen:
		if kind == "farm":
			soft = 0.3 + 0.3 * s.y
		elif kind != "lawn" and kind != "meadow":
			soft = 0.45 * smoothstep(0.55, 1.0, s.y)
	return soft


## How much the ground here slows whoever walks on it: 1 not at all. Only mud does, more the wetter it is (down
## to `mud_slow` in the worst of it).
func slow_at(pos: Vector3) -> float:
	if kind_at(pos) != "mud":
		return 1.0
	return lerpf(1.0, mud_slow, softness(pos))


## Does the ground here take a print? In soft ground, or in lying snow.
func takes_tracks(pos: Vector3) -> bool:
	return softness(pos) > 0.25 or (Seasons.it != null and Seasons.it.now.z > 0.15)


## A foot comes down here: `dir` the way they are going, `side` -1 left foot, 1 right. `drag` is someone
## crawling or being dragged: a swathe, not a print. Nothing happens on firm ground.
func stamp(pos: Vector3, dir: Vector3, side: int, drag := false) -> void:
	if _tracks == null or not takes_tracks(pos):
		return
	var d := Vector2(dir.x, dir.z)
	if d.length() < 0.01:
		return
	d = d.normalized()
	var across := Vector2(-d.y, d.x)
	var at := Vector2(pos.x, pos.z) + across * (0.16 * side)
	if drag:
		for i in range(-2, 3):
			_press(at + across * (i * TRACK_CELL), 0.75)
	else:
		# A print: bigger than a real boot, so it reads from the camera's height. Heel, sole and toe, two wide.
		for i in 3:
			_press(at + d * (i * TRACK_CELL), 1.0 if i < 2 else 0.8)
			_press(at + d * (i * TRACK_CELL) + across * (TRACK_CELL * side), 0.9 if i < 2 else 0.7)
	_tracks_dirty = true
	set_process(true)


func _press(p: Vector2, depth: float) -> void:
	var x := floori((p.x - area.position.x) / TRACK_CELL)
	var y := floori((p.y - area.position.y) / TRACK_CELL)
	if x >= 0 and y >= 0 and x < _tw and y < _th:
		_tracks.set_pixel(x, y, Color(maxf(_tracks.get_pixel(x, y).r, depth), 0, 0))


## Wipe every track (rain washes them out; fresh snow covers them).
func clear_tracks() -> void:
	if _tracks != null:
		_tracks.fill(Color(0, 0, 0))
		_tracks_dirty = true
		set_process(true)


# New prints go to the graphics card a few times a second at most, and not at all when nobody is making any.
func _process(delta: float) -> void:
	_tracks_t -= delta
	if _tracks_t > 0.0:
		return
	if _tracks_dirty:
		_tracks_tex.update(_tracks)
		_tracks_dirty = false
		_tracks_t = 0.2
	else:
		set_process(false)


## Standing grass wherever the ground is painted as grass: long blades on meadow, tussocks on rough ground. (Lawn
## is short enough to be the painted surface alone.) Call it after the painting is done. Returns how many tufts.
func grow_grass() -> int:
	var total := 0
	for pair in [["meadow", "meadow"], ["rough", "tussock"]]:
		var want := int(KINDS[pair[0]]) * 16
		var per_cell := float(GrassBlades.KINDS[pair[1]]["density"]) * CELL * CELL
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(pair[0])
		var pts := PackedVector2Array()
		for y in _h:
			for x in _w:
				if _img.get_pixel(x, y).r8 != want:
					continue
				var n := int(per_cell) + (1 if rng.randf() < per_cell - int(per_cell) else 0)
				for i in n:
					var p := area.position + (Vector2(x, y) + Vector2(rng.randf(), rng.randf())) * CELL
					if Cover.has_room(p, null):
						pts.append(p)
		if not pts.is_empty():
			add_child(GrassBlades.at_points(pair[1], pts))
			total += pts.size()
	return total


## What the ground is made of at a place ("soil", "road"...), for anything that cares (footsteps, mud, tracks).
func kind_at(pos: Vector3) -> String:
	var c := _cell(Vector2(pos.x, pos.z))
	if _img == null or c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return "soil"
	var n := roundi(_img.get_pixel(c.x, c.y).r8 / 16.0)
	for k: String in KINDS:
		if int(KINDS[k]) == n:
			return k
	return "soil"
