class_name GoreTiles
extends RefCounted
## The painted surface of the corpse pile: a sheet of modular tiles, each a patch of what a crushed crowd leaves.
## Rib cages, long bones with their knuckled ends, skulls, pelvises, spines, hands, torn-off limbs with the bone
## standing out of the stump, loops of gut, sinew and ligament strung between, flaps of skin, fat, pooled blood.
##
## Every tile is drawn by code from the same few shapes, with its own random roll, so no two are alike, and each
## keeps clear of its own edge, so any tile fits against any other, any way round. The pile's shader lays a base
## of pulped meat under them all and picks a tile, a turn and a flip for each 0.8 m cell (corpse_pile.gd).
##
## A texel stores: r = which colour (PALETTE index / 16), g = how far it stands up (for shading), b = 1 where the
## tile has something drawn (0 = the base shows through).
## Colours follow the art direction: bone is never white in a body (ivory and pink fresh, yellow and greasy, stained
## dark); cartilage and sinew are off-white; flesh goes from wet red to dusky to grey-green; skin is dead skin, in
## every skin tone.

const TILE := 40            # texels per tile (a 0.8 m cell: 50 texels a metre)
const COLS := 6
const ROWS := 4
const COUNT := COLS * ROWS

const PALETTE: Array[Color] = [
	Color(0.07, 0.02, 0.02),   # 0 clot
	Color(0.17, 0.03, 0.03),   # 1 dark blood
	Color(0.33, 0.05, 0.05),   # 2 blood
	Color(0.47, 0.12, 0.10),   # 3 wet red flesh
	Color(0.36, 0.20, 0.18),   # 4 dusky flesh
	Color(0.33, 0.34, 0.25),   # 5 grey-green rot
	Color(0.18, 0.19, 0.13),   # 6 dark olive rot
	Color(0.80, 0.70, 0.60),   # 7 bone, ivory and pink
	Color(0.72, 0.62, 0.40),   # 8 bone, yellow and greasy
	Color(0.45, 0.36, 0.24),   # 9 bone, stained
	Color(0.82, 0.80, 0.70),   # 10 sinew, ligament, cartilage
	Color(0.74, 0.64, 0.36),   # 11 fat
	Color(0.55, 0.38, 0.36),   # 12 gut
	Color(0.66, 0.60, 0.52),   # 13 dead skin, pale
	Color(0.30, 0.22, 0.18),   # 14 dead skin, dark
	Color(0.45, 0.47, 0.38),   # 15 dead skin, gone grey-green
]
const SKINS: Array[int] = [13, 13, 14, 15]

static var _tex: ImageTexture
static var _img: Image


## The sheet, made the first time it is asked for.
static func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(image())
	return _tex


static func image() -> Image:
	if _img != null:
		return _img
	_img = Image.create(COLS * TILE, ROWS * TILE, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 1))
	var rng := RandomNumberGenerator.new()
	for i in COUNT:
		rng.seed = 7919 * (i + 1)
		_tile(Vector2i((i % COLS) * TILE, (i / COLS) * TILE), rng, i)
	return _img


## The sheet as plain colours, for looking at (tools/gore_tiles_preview.gd).
static func preview() -> Image:
	var src := image()
	var out := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8)
	for y in src.get_height():
		for x in src.get_width():
			var p := src.get_pixel(x, y)
			var c := PALETTE[1] if p.b < 0.5 else PALETTE[clampi(roundi(p.r * 255.0 / 16.0), 0, 15)]
			out.set_pixel(x, y, c * (0.7 + 0.45 * p.g) if p.b >= 0.5 else c)
	return out


# ---------------------------------------------------------------- one tile
static func _tile(o: Vector2i, rng: RandomNumberGenerator, i: int) -> void:
	var c := Vector2(TILE, TILE) * 0.5
	# What lies underneath first: blood, slabs of meat, skin. Then two big pieces, different on every tile. Then
	# the scraps and strings over the top.
	_pool(o, _spot(rng, 8.0), rng.randf_range(6.0, 11.0), rng)
	for k in rng.randi_range(2, 3):
		_meat(o, _spot(rng, 6.0), rng)
	if rng.randf() < 0.6:
		_skin_flap(o, _spot(rng, 7.0), rng)
	for which in [i % 8, (i * 3 + 5) % 8]:
		match which:
			0:
				_ribcage(o, c + _jit(rng, 5.0), rng.randf() * TAU, rng)
			1:
				_limb(o, _spot(rng, 9.0), rng)
			2:
				_skull(o, _spot(rng, 9.0), rng.randf() * TAU, rng)
			3:
				_pelvis(o, _spot(rng, 11.0), rng.randf() * TAU, rng)
			4:
				_gut(o, _spot(rng, 9.0), rng)
				_spine(o, _spot(rng, 9.0), rng)
			5:
				_long_bone(o, _spot(rng, 9.0), rng)
				_long_bone(o, _spot(rng, 9.0), rng)
			6:
				_limb(o, _spot(rng, 9.0), rng)
				_hand(o, _spot(rng, 8.0), rng.randf() * TAU, rng, true)
			7:
				_long_bone(o, _spot(rng, 9.0), rng)
				_hand(o, _spot(rng, 8.0), rng.randf() * TAU, rng, false)
	if rng.randf() < 0.5:
		_gut(o, _spot(rng, 9.0), rng)
	if rng.randf() < 0.6:
		_fat(o, _spot(rng, 7.0), rng)
	for k in rng.randi_range(1, 2):
		var from := _spot(rng, 6.0)
		_sinew(o, from, from + _jit(rng, 9.0), rng)


static func _spot(rng: RandomNumberGenerator, margin: float) -> Vector2:
	return Vector2(rng.randf_range(margin, TILE - margin), rng.randf_range(margin, TILE - margin))


static func _jit(rng: RandomNumberGenerator, r: float) -> Vector2:
	return Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))


# ---------------------------------------------------------------- brushes
## One texel, kept a texel clear of the tile's edge so tiles never show a seam.
static func _px(o: Vector2i, x: int, y: int, idx: int, h: float) -> void:
	if x < 1 or y < 1 or x >= TILE - 1 or y >= TILE - 1:
		return
	_img.set_pixel(o.x + x, o.y + y, Color(idx * 16.0 / 255.0, clampf(h, 0.0, 1.0), 1.0, 1.0))


## A round-ended stroke from a to b, w texels wide: `mid` down its middle, `edge` at its sides (so it reads as
## round), standing h high.
static func _stroke(o: Vector2i, a: Vector2, b: Vector2, w: float, mid: int, edge: int, h: float) -> void:
	var r := w * 0.5
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	for y in range(int(floor(minf(a.y, b.y) - r)), int(ceil(maxf(a.y, b.y) + r)) + 1):
		for x in range(int(floor(minf(a.x, b.x) - r)), int(ceil(maxf(a.x, b.x) + r)) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d <= r:
				_px(o, x, y, mid if d < r * 0.55 else edge, h * (1.0 - 0.5 * d / maxf(r, 0.01)))


static func _blob(o: Vector2i, c: Vector2, rx: float, ry: float, rot: float, mid: int, edge: int, h: float) -> void:
	var m := maxf(rx, ry)
	for y in range(int(floor(c.y - m)), int(ceil(c.y + m)) + 1):
		for x in range(int(floor(c.x - m)), int(ceil(c.x + m)) + 1):
			var p := (Vector2(x + 0.5, y + 0.5) - c).rotated(-rot)
			var d := Vector2(p.x / maxf(rx, 0.01), p.y / maxf(ry, 0.01)).length()
			if d <= 1.0:
				_px(o, x, y, mid if d < 0.7 else edge, h * (1.0 - 0.6 * d))


## A wandering line through a few points (sinew, gut): straight strokes between them.
static func _path(o: Vector2i, pts: Array[Vector2], w: float, mid: int, edge: int, h: float) -> void:
	for i in pts.size() - 1:
		_stroke(o, pts[i], pts[i + 1], w, mid, edge, h)


static func _bone_colours(rng: RandomNumberGenerator) -> Array[int]:
	# Fresh ivory, or greasy yellow, each with a stained edge; or stained right through.
	var r := rng.randf()
	if r < 0.4:
		return [7, 9]
	if r < 0.8:
		return [8, 9]
	return [9, 6]


# ---------------------------------------------------------------- the pieces
## A long bone (thigh, shin, upper arm): a shaft with a knuckled end either side, sometimes snapped.
static func _long_bone(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	var col := _bone_colours(rng)
	var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
	var half := rng.randf_range(9.0, 14.0)
	var a := c - dir * half
	var b := c + dir * half
	var side := dir.orthogonal()
	if rng.randf() < 0.3:
		# Snapped: two halves a little out of line, marrow dark in the break.
		var m := c + side * rng.randf_range(-1.5, 1.5)
		_stroke(o, a, m - dir, 3.0, col[0], col[1], 0.9)
		_stroke(o, m + dir * 1.5 + side * 2.0, b, 3.0, col[0], col[1], 0.9)
		_blob(o, m, 1.4, 1.4, 0.0, 1, 1, 0.5)
	else:
		_stroke(o, a, b, 3.0, col[0], col[1], 0.9)
	# The ends: two knuckles at one, a ball at the other.
	_blob(o, a + side * 1.7, 2.5, 2.5, 0.0, col[0], col[1], 1.0)
	_blob(o, a - side * 1.7, 2.5, 2.5, 0.0, col[0], col[1], 1.0)
	_blob(o, b + side * 1.3, 2.9, 2.9, 0.0, col[0], col[1], 1.0)
	# A rag of meat still on it.
	if rng.randf() < 0.6:
		var q := a.lerp(b, rng.randf_range(0.25, 0.75))
		_blob(o, q + side * 1.5, 3.0, 1.6, dir.angle(), 3, 2, 0.6)


## Ribs: a run of backbone with ribs curving off both sides, some broken short, shreds of meat between.
static func _ribcage(o: Vector2i, c: Vector2, rot: float, rng: RandomNumberGenerator) -> void:
	var col := _bone_colours(rng)
	var ax := Vector2.RIGHT.rotated(rot)
	var side := ax.orthogonal()
	var n := rng.randi_range(6, 8)
	var half := n * 1.9
	_blob(o, c, half + 1.5, 10.5, rot, 4, 1, 0.3)          # what is left inside: dark and dusky
	for i in n:
		var u := lerpf(-half, half, i / float(n - 1))
		var base := c + ax * u
		_blob(o, base, 1.7, 1.7, 0.0, col[0], col[1], 0.95)   # a vertebra
		for s in [-1.0, 1.0]:
			if rng.randf() < 0.12:
				continue                                         # this one is gone
			var reach := rng.randf_range(9.5, 13.0) * (1.0 - 0.25 * absf(u) / half)
			if rng.randf() < 0.25:
				reach *= rng.randf_range(0.35, 0.7)                # broken short
			# A rib bows away from the spine and sweeps back (ribs slope: down toward the front).
			var pts: Array[Vector2] = []
			for k in 5:
				var t := k / 4.0
				pts.append(base + side * s * reach * sin(t * PI * 0.5) + ax * (2.2 * t * t))
			_path(o, pts, 1.9, col[0], col[1], 0.85)
			if rng.randf() < 0.3:
				_blob(o, pts[4], 1.3, 0.9, 0.0, 10, 10, 0.8)       # the cartilage end, off-white
	if rng.randf() < 0.7:
		_blob(o, c + side * rng.randf_range(-4.0, 4.0), 3.5, 2.0, rot + 0.6, 3, 2, 0.5)


## A skull: the dome, eye sockets, the nose hole, a row of teeth; sometimes cracked, sometimes with scalp still on.
static func _skull(o: Vector2i, c: Vector2, rot: float, rng: RandomNumberGenerator) -> void:
	var col := _bone_colours(rng)
	var f := Vector2.RIGHT.rotated(rot)       # the way the face points
	var s := f.orthogonal()
	_blob(o, c, 7.4, 6.3, rot, col[0], col[1], 1.0)
	_blob(o, c + f * 5.4, 4.2, 4.4, rot, col[0], col[1], 0.9)            # the face
	_blob(o, c + f * 4.4 + s * 2.4, 1.9, 1.6, rot, 0, 0, 0.2)            # sockets
	_blob(o, c + f * 4.4 - s * 2.4, 1.9, 1.6, rot, 0, 0, 0.2)
	_blob(o, c + f * 6.8, 1.1, 1.0, rot, 0, 0, 0.2)                      # nose
	if rng.randf() < 0.7:
		for k in range(-2, 3):
			var tp := c + f * 9.0 + s * (k * 1.1)
			_px(o, int(tp.x), int(tp.y), 10, 0.9)                           # teeth
	if rng.randf() < 0.5:
		var a := c + s * rng.randf_range(-3.0, 3.0) - f * 4.0
		_path(o, [a, a + f * 3.0 + s * 1.5, a + f * 5.5 - s * 0.5], 0.9, 0, 0, 0.3)   # a crack
	if rng.randf() < 0.4:
		_blob(o, c - f * 2.5 + s * 1.5, 3.5, 2.6, rot, 6, 0, 0.9)           # scalp and matted hair


static func _pelvis(o: Vector2i, c: Vector2, rot: float, rng: RandomNumberGenerator) -> void:
	var col := _bone_colours(rng)
	var ax := Vector2.RIGHT.rotated(rot)
	var s := ax.orthogonal()
	for side in [-1.0, 1.0]:
		_blob(o, c + s * side * 5.0, 5.5, 4.2, rot + side * 0.5, col[0], col[1], 0.95)   # the wings
		_blob(o, c + s * side * 4.0 + ax * 4.0, 2.4, 2.0, rot, col[0], col[1], 0.85)
		_blob(o, c + s * side * 4.0 + ax * 4.0, 1.1, 0.9, rot, 1, 1, 0.3)                 # the hole
		_blob(o, c + s * side * 6.5 - ax * 0.5, 1.6, 1.6, 0.0, 1, 1, 0.3)                 # the hip socket
	_blob(o, c - ax * 1.5, 2.2, 3.0, rot, col[0], col[1], 1.0)                             # the base of the spine
	_blob(o, c + ax * 5.5, 1.2, 1.6, rot, 10, 10, 0.8)                                     # cartilage at the front


static func _spine(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	var col := _bone_colours(rng)
	var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
	var bend := rng.randf_range(-0.12, 0.12)
	var p := c - dir * 10.0
	for i in 9:
		_blob(o, p, 1.5, 1.5, 0.0, col[0], col[1], 0.95)
		_stroke(o, p - dir.orthogonal() * 2.2, p + dir.orthogonal() * 2.2, 0.9, col[1], col[1], 0.7)
		dir = dir.rotated(bend)
		p += dir * 2.6
		_px(o, int(p.x - dir.x * 1.3), int(p.y - dir.y * 1.3), 10, 0.7)   # the disc between


## A hand: bones fanned from the wrist, or a whole dead hand with the skin on.
static func _hand(o: Vector2i, c: Vector2, rot: float, rng: RandomNumberGenerator, skinned: bool) -> void:
	var col := _bone_colours(rng)
	var skin: int = SKINS[rng.randi() % SKINS.size()]
	var f := Vector2.RIGHT.rotated(rot)
	if skinned:
		_blob(o, c, 2.8, 2.4, rot, skin, 4, 0.8)
	for k in 5:
		var a := rot + (k - 2) * 0.33 + rng.randf_range(-0.08, 0.08)
		var d := Vector2.RIGHT.rotated(a)
		var l := 6.5 if k != 0 else 4.0
		var curl := rng.randf_range(-0.5, 0.9)
		var mid := c + d * l * 0.55
		var tip := mid + d.rotated(curl) * l * 0.5
		if skinned:
			_path(o, [c + d * 1.5, mid, tip], 1.5, skin, 4, 0.8)
		else:
			_path(o, [c + d * 1.0, mid, tip], 1.0, col[0], col[1], 0.85)
			_px(o, int(mid.x), int(mid.y), 10, 0.9)                       # a knuckle
	_stroke(o, c - f * 1.0, c - f * 3.0, 2.0, 3 if skinned else col[0], 2 if skinned else col[1], 0.7)


## A torn-off arm or leg with the skin on: the bone stands out of the stump, red round it, sinew trailing.
static func _limb(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	var skin: int = SKINS[rng.randi() % SKINS.size()]
	var col := _bone_colours(rng)
	var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
	var half := rng.randf_range(9.0, 13.0)
	var w := rng.randf_range(6.0, 8.0)
	var a := c - dir * half
	var b := c + dir * half
	var elbow := c + dir.orthogonal() * rng.randf_range(-3.0, 3.0)
	_path(o, [a, elbow, b], w, skin, 4 if skin != 14 else 0, 0.75)
	# The far end: a hand or foot, a lump with stubs.
	_blob(o, b + dir * 2.0, w * 0.55, w * 0.45, dir.angle(), skin, 4, 0.75)
	for k in range(-1, 2):
		_stroke(o, b + dir * 3.0, b + dir * 5.5 + dir.orthogonal() * (k * 1.6), 1.1, skin, 4, 0.7)
	# The stump: raw meat, the bone end, strings.
	_blob(o, a, w * 0.6, w * 0.6, 0.0, 3, 2, 0.7)
	_stroke(o, a + dir * 1.0, a - dir * rng.randf_range(2.5, 5.0), 1.8, col[0], col[1], 1.0)
	for k in rng.randi_range(2, 4):
		var e := a - dir * rng.randf_range(3.0, 7.0) + dir.orthogonal() * rng.randf_range(-4.0, 4.0)
		_path(o, [a, a.lerp(e, 0.5) + _jit(rng, 1.2), e], 0.8, 10, 10, 0.6)
	# Where the skin has split along it.
	if rng.randf() < 0.6:
		var q := a.lerp(b, rng.randf_range(0.3, 0.7))
		_stroke(o, q - dir * 2.5, q + dir * 2.5, 1.4, 3, 2, 0.5)


## Gut: a fat loose loop, lighter along its top, dark between the coils.
static func _gut(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	var pts: Array[Vector2] = []
	var p := c
	var a := rng.randf() * TAU
	var mid := 12 if rng.randf() < 0.6 else 5
	for i in rng.randi_range(7, 11):
		pts.append(p)
		a += rng.randf_range(0.5, 1.3) * (1.0 if i % 2 == 0 else -1.0)
		p += Vector2.RIGHT.rotated(a) * rng.randf_range(3.0, 4.5)
	_path(o, pts, 5.4, 1, 0, 0.35)
	_path(o, pts, 3.8, mid, 4, 0.7)


## Sinew, ligament, a strip of tendon: thin, pale, strung in a sagging line, a few together.
static func _sinew(o: Vector2i, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var sag := (b - a).orthogonal().normalized() * rng.randf_range(-4.0, 4.0)
	for k in rng.randi_range(1, 3):
		var off := _jit(rng, 1.5)
		_path(o, [a + off, a.lerp(b, 0.5) + sag + off, b + off], 0.8, 10, 10, 0.75)


static func _skin_flap(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	var skin: int = SKINS[rng.randi() % SKINS.size()]
	var rot := rng.randf() * TAU
	_blob(o, c + _jit(rng, 1.0), rng.randf_range(6.0, 9.0), rng.randf_range(4.0, 6.0), rot, 3, 2, 0.35)   # the raw underside, showing round it
	_blob(o, c, rng.randf_range(5.0, 8.0), rng.randf_range(3.0, 5.0), rot, skin, 4, 0.5)
	for k in rng.randi_range(1, 3):
		_blob(o, c + _jit(rng, 6.0), rng.randf_range(1.5, 3.0), rng.randf_range(1.0, 2.0), rng.randf() * TAU, skin, 4, 0.5)


## A slab of torn muscle: red, darker at the edge, streaked with pale fibre and a little fat.
static func _meat(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	var rot := rng.randf() * TAU
	var rx := rng.randf_range(6.0, 11.0)
	var ry := rng.randf_range(4.0, 7.0)
	var mid := 3 if rng.randf() < 0.65 else (4 if rng.randf() < 0.6 else 5)   # wet red, or gone dusky, or grey-green
	_blob(o, c, rx, ry, rot, mid, 2 if mid == 3 else 6, 0.55)
	var along := Vector2.RIGHT.rotated(rot)
	for k in rng.randi_range(2, 4):
		var off := along.orthogonal() * rng.randf_range(-ry * 0.6, ry * 0.6)
		_stroke(o, c + off - along * rx * 0.6, c + off + along * rx * 0.6, 0.8, 2 if mid == 3 else 4, 2, 0.6)   # the grain
	if rng.randf() < 0.5:
		_stroke(o, c - along * rx * 0.5, c + along * rx * 0.3, 0.9, 10, 10, 0.7)   # a white band of tendon through it


static func _fat(o: Vector2i, c: Vector2, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(3, 6):
		_blob(o, c + _jit(rng, 4.0), rng.randf_range(1.0, 2.2), rng.randf_range(1.0, 2.0), 0.0, 11, 8, 0.6)


## Pooled blood: dark, flat, with a clotted middle.
static func _pool(o: Vector2i, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	_blob(o, c, r, r * rng.randf_range(0.6, 0.9), rng.randf() * TAU, 1, 2, 0.15)
	_blob(o, c + _jit(rng, 2.0), r * 0.45, r * 0.35, rng.randf() * TAU, 0, 1, 0.1)
	for k in rng.randi_range(2, 5):
		var d := Vector2.RIGHT.rotated(rng.randf() * TAU) * r * rng.randf_range(0.9, 1.4)
		_blob(o, c + d, 1.1, 0.9, 0.0, 2, 2, 0.15)
