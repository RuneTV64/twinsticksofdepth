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
## Dirt is 0 to 7, grass from 8 (dirt_types.gdshaderinc, grass_types.gdshaderinc).
const KINDS := {"soil": 0, "farm": 1, "road": 2, "clay": 3, "mud": 4, "lawn": 8, "meadow": 9, "rough": 10}

static var it: Ground

var area := Rect2()
var road_width := 4.0
var material: ShaderMaterial
var mesh: MeshInstance3D

var _img: Image
var _tex: ImageTexture
var _w := 0
var _h := 0
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
