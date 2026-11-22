class_name Clothes
extends RefCounted
## Clothes (owner, 21 Nov 2026: "Make clothes good. I don't care how you do it just make it so I can dress my
## character to the nines. I want wrists, neck, socks, eyes, face, head, overshirt, undershirt, belt, weapon
## straps, you name it.")
##
## Where things are worn (PLACES), how a garment is drawn (its `look`: a cut from CUTS or its own cover, colours,
## a pattern, a thickness, a shape), what it keeps out (its `guard`: bite, cut, blow, warm), and the slots it
## gives (`pockets`: items.gd). Drawn by clothes.gdshader on a second skinned copy of the body's own mesh, built
## here once per body mesh and kept (shell()); the approved body and its skin shader are not touched.
##
## A worn item may carry its own state: "tatter" 0 to 1 (holes: from bites it stopped, from wear), "grime",
## "blood". They show, and a torn garment keeps less out.

const SHADER := preload("res://clothes.gdshader")
const MAXL := 14

## Where things are worn, outermost first: the order they are drawn and met in (a bite meets the coat before
## the shirt). [key, what the place is called]
const PLACES := [
	["back", "On your back"], ["strap", "Weapon strap"], ["cloak", "Over your shoulders"], ["eyes", "Over your eyes"],
	["head", "On your head"], ["face", "On your face"], ["neck", "Round your neck"],
	["wrist_l", "Left wrist"], ["wrist_r", "Right wrist"], ["hands", "On your hands"], ["fingers", "On your fingers"],
	["outer", "Jacket or coat"], ["waist", "Belt"], ["feet", "On your feet"], ["shirt", "Overshirt"],
	["undershirt", "Undershirt"], ["legs", "Trousers, shorts, skirt"], ["socks", "Socks"], ["underwear", "Underwear"],
]

## Every body has its own fit (owner, 21 Nov 2026: more bodies are coming, a female one and male and female
## skinny, husky and obese, and the clothes must fit them all). A garment is told in landmarks ("to the knee",
## "a hand's width above the wrist"), so one outfit fits every body; the body says where its landmarks are.
##   marks  heights on the body at rest (m), arms down at the sides, feet at 0: what cuts are named by.
##          "top" and "bottom" are past either end.
##   fit    the sizes the shader needs that belong to the body, not the garment (m, at rest; +x is the body's
##          left, +z its front): the face (the plane its front starts at, its half width, the eyes' half spacing,
##          a lens's size, where glasses' arms run, the top of the face), a strap across the chest (from the
##          shoulder to the other hip, and its half width), a pack on the back (its half width, where its straps
##          run, where the back starts), the front (where an open front and buttons start), where jeans' seams
##          run, the middle of a foot, and where jeans wear pale on the thigh.
## A new body: draft its numbers with measure() (tools/body_fit.gd prints them), put them here under its own
## name, set PlayerBody.body_kind for it, and check the clothes sheets (tools/clothes_preview.gd BODY=...).
const DEFAULT_BODY := "male_muscular"
const BODIES := {
	"male_muscular": {
		"marks": {
			"bottom": -9.0, "sole": 0.0, "ankle": 0.09, "shin": 0.3, "knee": 0.51, "thigh": 0.7, "crotch": 0.86,
			"hip": 0.92, "waist": 1.0, "navel": 1.06, "chest": 1.25, "armpit": 1.32, "shoulder": 1.45, "neck_lo": 1.49,
			"neck": 1.53, "chin": 1.575, "mouth": 1.615, "nose": 1.65, "eyes": 1.69, "brow": 1.715, "crown": 1.8,
			"biceps": 1.27, "elbow": 1.12, "forearm": 1.0, "wrist": 0.88, "knuckles": 0.8, "top": 9.0,
		},
		"fit": {
			"face_z": 0.03, "face_half": 0.072, "eye_apart": 0.033, "eye_size": 0.02, "temple": 0.055, "face_top": 1.725,
			"strap": [0.16, 1.47, -0.15, 0.95], "strap_half": 0.024,
			"pack_half": 0.16, "pack_strap_x": 0.085, "back_z": -0.03,
			"front_z": 0.04, "button_z": 0.06, "seam_x": 0.13, "foot_x": 0.12, "thigh_pale": [0.58, 0.78],
		},
	},
}


## A body measured at rest, from its skeleton and its own mesh: what measure() drafts a new body's fit from.
## Bone heights (y), and from the skin: the top of the head, the head's half width and its front, the torso's
## half width at the chest and at the hip, its front and back at the chest, and the middle of the foot.
static func raw(body: MeshInstance3D) -> Dictionary:
	var skel := body.get_node(body.skeleton) as Skeleton3D
	var out := {}
	for b in ["FootL", "CalfL", "ThighL", "Hips", "Chest", "ClavicleL", "Neck", "Head", "UpperArmL", "ForearmL", "HandL", "IndexL1"]:
		var o := skel.get_bone_global_rest(skel.find_bone(b)).origin
		out[b] = o.y
		if b == "Head":
			out["head_z"] = o.z
	var a := shell(body).surface_get_arrays(0)
	var c0: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var crown := 0.0
	var head_w := 0.0
	var head_f := -9.0
	var chest_w := 0.0
	var chest_f := -9.0
	var chest_b := 9.0
	var hip_w := 0.0
	var foot_x := 0.0
	var feet := 0
	for i in range(0, c0.size(), 4):
		var p := Vector3(c0[i], c0[i + 1], c0[i + 2])
		var area := int(c0[i + 3])
		crown = maxf(crown, p.y)
		if area == 6:
			head_w = maxf(head_w, absf(p.x))
			head_f = maxf(head_f, p.z)
		elif area == 0 and absf(p.y - float(out["Chest"]) - 0.13) < 0.03:
			chest_w = maxf(chest_w, absf(p.x))
			chest_f = maxf(chest_f, p.z)
			chest_b = minf(chest_b, p.z)
		elif area == 0 and absf(p.y - float(out["ThighL"])) < 0.03:
			hip_w = maxf(hip_w, absf(p.x))
		elif area == 4 and p.x > 0.0:
			foot_x += p.x
			feet += 1
	out["crown"] = crown
	out["head_w"] = head_w
	out["head_f"] = head_f
	out["chest_w"] = chest_w
	out["chest_f"] = chest_f
	out["chest_b"] = chest_b
	out["hip_w"] = hip_w
	out["foot_x"] = foot_x / maxi(feet, 1)
	return out


## Each mark, between which two of the raw measures it lies (it keeps its place between them from body to body).
const MARK_FROM := {
	"ankle": ["sole", "CalfL"], "shin": ["FootL", "CalfL"], "knee": ["FootL", "ThighL"], "thigh": ["CalfL", "ThighL"],
	"crotch": ["CalfL", "ThighL"], "hip": ["CalfL", "Hips"], "waist": ["Hips", "Chest"], "navel": ["Hips", "Chest"],
	"chest": ["Chest", "ClavicleL"], "armpit": ["Chest", "ClavicleL"], "shoulder": ["Chest", "ClavicleL"],
	"neck_lo": ["Chest", "Head"], "neck": ["Chest", "Head"], "chin": ["Neck", "crown"], "mouth": ["Head", "crown"],
	"nose": ["Head", "crown"], "eyes": ["Head", "crown"], "brow": ["Head", "crown"], "crown": ["Head", "crown"],
	"biceps": ["ForearmL", "UpperArmL"], "elbow": ["HandL", "UpperArmL"], "forearm": ["HandL", "ForearmL"],
	"wrist": ["IndexL1", "ForearmL"], "knuckles": ["IndexL1", "HandL"],
}
## Each size in the fit, as a share of which raw width.
const FIT_FROM := {
	"face_half": "head_w", "eye_apart": "head_w", "eye_size": "head_w", "temple": "head_w", "strap_half": "chest_w",
	"pack_half": "chest_w", "pack_strap_x": "chest_w", "seam_x": "hip_w", "foot_x": "foot_x",
}


## A first draft of the fit for a new body, from its skeleton and mesh: every mark and size keeps the place the
## tuned body (`from`) gives it between the same measures. A draft: check it on the sheets and tune it.
static func measure(body: MeshInstance3D, tuned: MeshInstance3D, from: String = DEFAULT_BODY) -> Dictionary:
	var r := raw(body)
	var t := raw(tuned)
	r["sole"] = 0.0
	t["sole"] = 0.0
	var mk := marks(from)
	var ft := fit(from)
	var m := {"bottom": -9.0, "sole": 0.0, "top": 9.0}
	for k: String in MARK_FROM:
		var ab: Array = MARK_FROM[k]
		var t0 := float(t[ab[0]])
		var t1 := float(t[ab[1]])
		var f := (float(mk[k]) - t0) / (t1 - t0) if absf(t1 - t0) > 0.001 else 0.0
		m[k] = snappedf(float(r[ab[0]]) + f * (float(r[ab[1]]) - float(r[ab[0]])), 0.001)
	var f2 := {}
	for k: String in FIT_FROM:
		f2[k] = snappedf(float(ft[k]) * float(r[FIT_FROM[k]]) / maxf(float(t[FIT_FROM[k]]), 0.001), 0.001)
	# The rest by where they sit on the face, the chest and the body.
	f2["face_z"] = snappedf(float(r["head_z"]) + (float(ft["face_z"]) - float(t["head_z"])) * (float(r["head_f"]) - float(r["head_z"])) / maxf(float(t["head_f"]) - float(t["head_z"]), 0.001), 0.001)
	f2["face_top"] = snappedf(float(m["brow"]) + float(ft["face_top"]) - float(mk["brow"]), 0.001)
	var cf := float(r["chest_f"]) / maxf(float(t["chest_f"]), 0.001)
	f2["front_z"] = snappedf(float(ft["front_z"]) * cf, 0.001)
	f2["button_z"] = snappedf(float(ft["button_z"]) * cf, 0.001)
	f2["back_z"] = snappedf(float(ft["back_z"]) * float(r["chest_b"]) / minf(float(t["chest_b"]), -0.001), 0.001)
	var st: Array = ft["strap"]
	var cw := float(r["chest_w"]) / maxf(float(t["chest_w"]), 0.001)
	var hw := float(r["hip_w"]) / maxf(float(t["hip_w"]), 0.001)
	f2["strap"] = [snappedf(float(st[0]) * cw, 0.001), snappedf(float(m["shoulder"]) + float(st[1]) - float(mk["shoulder"]), 0.001),
		snappedf(float(st[2]) * hw, 0.001), snappedf(float(m["hip"]) + float(st[3]) - float(mk["hip"]), 0.001)]
	var tp: Array = ft["thigh_pale"]
	var kn := float(mk["knee"])
	var hp := float(mk["hip"])
	f2["thigh_pale"] = [snappedf(float(m["knee"]) + (float(tp[0]) - kn) / (hp - kn) * (float(m["hip"]) - float(m["knee"])), 0.001),
		snappedf(float(m["knee"]) + (float(tp[1]) - kn) / (hp - kn) * (float(m["hip"]) - float(m["knee"])), 0.001)]
	return {"marks": m, "fit": f2}


## The marks of a body (DEFAULT_BODY's if it isn't known).
static func marks(body: String = DEFAULT_BODY) -> Dictionary:
	return BODIES.get(body, BODIES[DEFAULT_BODY])["marks"]


static func fit(body: String = DEFAULT_BODY) -> Dictionary:
	return BODIES.get(body, BODIES[DEFAULT_BODY])["fit"]
const AREAS := ["torso", "arm", "hand", "leg", "foot", "neck", "head", "face"]

## Cuts: what a kind of garment covers, area -> [from, to] in a body's marks (+ or - metres).
const CUTS := {
	"tank": {"torso": ["crotch+0.03", "top"], "leg": ["crotch+0.03", "top"]},
	"tee": {"torso": ["crotch+0.03", "top"], "leg": ["crotch+0.03", "top"], "arm": ["biceps-0.03", "top"], "neck": ["bottom", "neck_lo+0.025"]},
	"longsleeve": {"torso": ["crotch+0.03", "top"], "leg": ["crotch+0.03", "top"], "arm": ["wrist+0.015", "top"], "neck": ["bottom", "neck_lo+0.025"]},
	"hoodie": {"torso": ["crotch+0.02", "top"], "leg": ["crotch+0.02", "top"], "arm": ["wrist+0.01", "top"], "neck": ["bottom", "neck-0.01"]},
	"jacket": {"torso": ["hip-0.05", "top"], "arm": ["wrist", "top"], "neck": ["bottom", "neck"]},
	"coat": {"torso": ["bottom", "top"], "leg": ["knee+0.06", "top"], "arm": ["wrist-0.01", "top"], "neck": ["bottom", "chin-0.01"]},
	"robe": {"torso": ["bottom", "top"], "leg": ["shin+0.05", "top"], "arm": ["forearm-0.03", "top"], "neck": ["bottom", "neck-0.02"]},
	"cloak": {"torso": ["bottom", "top"], "leg": ["knee-0.04", "top"], "arm": ["elbow+0.04", "top"], "neck": ["bottom", "neck"]},
	"shawl": {"torso": ["navel", "top"], "arm": ["elbow+0.02", "top"], "neck": ["bottom", "neck-0.02"]},
	"poncho": {"torso": ["crotch", "top"], "leg": ["thigh-0.05", "top"], "arm": ["elbow-0.04", "top"], "neck": ["bottom", "neck-0.02"]},
	"jeans": {"torso": ["bottom", "waist"], "leg": ["ankle+0.01", "top"]},
	"shorts": {"torso": ["bottom", "waist"], "leg": ["knee+0.1", "top"]},
	"skirt": {"torso": ["bottom", "waist"], "leg": ["knee-0.02", "top"]},
	"briefs": {"torso": ["bottom", "hip+0.02"], "leg": ["crotch-0.04", "top"]},
	"socks": {"foot": ["bottom", "top"], "leg": ["bottom", "ankle+0.11"]},
	"shoes": {"foot": ["bottom", "top"], "leg": ["bottom", "ankle+0.025"]},
	"boots": {"foot": ["bottom", "top"], "leg": ["bottom", "ankle+0.2"]},
	"gloves": {"hand": ["bottom", "top"], "arm": ["bottom", "wrist+0.035"]},
	"belt": {"torso": ["waist-0.02", "waist+0.02"]},
	"band": {"arm": ["wrist+0.006", "wrist+0.034"]},
	"bracer": {"arm": ["wrist+0.012", "elbow-0.025"]},
	"ring": {"hand": ["knuckles-0.022", "knuckles-0.012"]},
	"beanie": {"head": ["brow+0.012", "top"]},
	"cap": {"head": ["brow+0.02", "top"]},
	"hood": {"head": ["chin", "top"], "neck": ["bottom", "top"]},
	"helmet": {"head": ["brow+0.005", "top"]},
	"bandana": {"face": ["bottom", "nose+0.005"], "neck": ["bottom", "top"], "head": ["chin-0.01", "mouth"]},
	"balaclava": {"face": ["bottom", "top"], "head": ["bottom", "top"], "neck": ["bottom", "top"]},
	"scarf": {"neck": ["bottom", "top"], "torso": ["neck_lo-0.025", "top"], "head": ["bottom", "chin+0.008"], "face": ["bottom", "chin+0.01"]},
	"lenses": {},
	"strap": {},
	"pack": {"torso": ["waist+0.08", "shoulder-0.04"]},
}
const PATTERNS := {"plain": 0, "knit": 1, "denim": 2, "check": 3, "stripes": 4, "leather": 5, "lace": 6, "print": 7, "metal": 8, "glass": 9}
const SHAPES := {"": 0, "strap": 1, "pack": 2, "lens": 3, "slot": 4}
const DETAILS := {"": 0, "buttons": 1, "zip": 2, "laces": 3, "jeans": 4}

## Which area of the body each bone's skin is: what the shell carries per vertex.
static func _area_of_bone(bone: String) -> int:
	for pre: String in ["UpperArm", "Forearm"]:
		if bone.begins_with(pre):
			return 1
	for pre: String in ["Hand", "Thumb", "Index", "Middle", "Ring", "Pinky"]:
		if bone.begins_with(pre):
			return 2
	if bone.begins_with("Thigh") or bone.begins_with("Calf"):
		return 3
	if bone.begins_with("Foot") or bone.begins_with("Toe"):
		return 4
	if bone == "Neck":
		return 5
	if bone == "Head":
		return 6
	return 0


static var _shells := {}


## The copy of this body's mesh the clothes are drawn on: the same vertices, skin and skeleton, with each
## vertex's rest position and area in CUSTOM0. Built once per mesh and kept.
static func shell(body: MeshInstance3D) -> ArrayMesh:
	var src: Mesh = body.mesh
	if _shells.has(src):
		return _shells[src]
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var per := bo.size() / maxi(v.size(), 1)
	var by_bind := {}
	var skel := body.get_node_or_null(body.skeleton) as Skeleton3D
	var c0 := PackedFloat32Array()
	c0.resize(v.size() * 4)
	for i in v.size():
		var best := 0
		for k in per:
			if w[i * per + k] > w[i * per + best]:
				best = k
		var bind := bo[i * per + best]
		if not by_bind.has(bind):
			var nm := String(body.skin.get_bind_name(bind)) if body.skin != null else ""
			if nm == "" and skel != null and body.skin != null and body.skin.get_bind_bone(bind) >= 0:
				nm = skel.get_bone_name(body.skin.get_bind_bone(bind))
			by_bind[bind] = _area_of_bone(nm)
		c0[i * 4] = v[i].x
		c0[i * 4 + 1] = v[i].y
		c0[i * 4 + 2] = v[i].z
		c0[i * 4 + 3] = float(by_bind[bind])
	# The copy hangs like cloth over the torso and arms (owner, 21 Nov 2026: a shirt on him read as breasts, and
	# the clothes as feminine): it falls from the chest instead of tucking under the pecs, bridges the hollows
	# between them, the abs and the spine, hangs straight down the sides and from the shoulders down the sleeves.
	# CUSTOM0 keeps the skin's own rest position, so what is covered and the patterns don't move.
	var areas := PackedInt32Array()
	areas.resize(v.size())
	for i in v.size():
		areas[i] = int(c0[i * 4 + 3])
		if areas[i] == 3 and v[i].y > 0.78:
			areas[i] = 0          # the tops of the thighs hang with the torso (a shirt's hem comes down over them)
	var hung := _drape(v, a[Mesh.ARRAY_NORMAL], areas)
	if skel != null:
		_drape_arms(hung, v, areas, skel)
	var normals := _soft_normals(hung, a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_INDEX], areas)
	var keep := []
	keep.resize(Mesh.ARRAY_MAX)
	keep[Mesh.ARRAY_VERTEX] = hung
	keep[Mesh.ARRAY_NORMAL] = normals
	keep[Mesh.ARRAY_CUSTOM0] = c0
	keep[Mesh.ARRAY_BONES] = bo
	keep[Mesh.ARRAY_WEIGHTS] = w
	keep[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if per == 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep, [], {}, flags)
	_shells[src] = m
	return m


## How cloth hangs on a torso (first guesses): it falls `DRAPE_FALL` inward for every metre it drops below the
## furthest-out point above it (front, back and sides, so a shirt hangs straight from the chest and the lats
## rather than following the waist in), it bridges a hollow up to `DRAPE_BRIDGE` wide either side, and it stands
## at most `DRAPE_MAX` off the skin (`DRAPE_SIDE_MAX` at the sides, where the arms hang).
const DRAPE_FALL := 0.08
const DRAPE_SIDE_MAX := 0.03
const DRAPE_WAIST_MAX := 0.015    # the sides of the torso: the arms hang close by
const DRAPE_BRIDGE := 7
const DRAPE_MAX := 0.05
const DRAPE_CELL := 0.01


## The torso's vertices (area 0) moved out to where cloth would hang over them, front and back; everything else
## as it was. On a grid of DRAPE_CELL squares across the body at rest: the furthest-out skin in each square,
## carried down each column (falling DRAPE_FALL a metre) and across hollows; each vertex comes out to that.
static func _drape(v: PackedVector3Array, n: PackedVector3Array, areas: PackedInt32Array) -> PackedVector3Array:
	var out := v.duplicate()
	for side in [1.0, -1.0]:
		var grid := {}
		var x0 := 999
		var x1 := -999
		var y0 := 999
		var y1 := -999
		for i in v.size():
			if areas[i] != 0 or n[i].z * side < 0.05:
				continue
			var c := Vector2i(floori(v[i].x / DRAPE_CELL), floori(v[i].y / DRAPE_CELL))
			grid[c] = maxf(float(grid.get(c, -9.0)), v[i].z * side)
			x0 = mini(x0, c.x)
			x1 = maxi(x1, c.x)
			y0 = mini(y0, c.y)
			y1 = maxi(y1, c.y)
		if grid.is_empty():
			continue
		# Down each column: it can't tuck in faster than it falls.
		var hang := {}
		for x in range(x0, x1 + 1):
			var above := -9.0
			for y in range(y1, y0 - 1, -1):
				above -= DRAPE_FALL * DRAPE_CELL
				var c := Vector2i(x, y)
				if grid.has(c):
					above = maxf(float(grid[c]), above)
					hang[c] = above
		# Across each row: over a hollow no wider than the bridge, it stays out at the lower of the two sides.
		var across := {}
		for c: Vector2i in hang:
			var left := -9.0
			var right := -9.0
			for d in range(1, DRAPE_BRIDGE + 1):
				left = maxf(left, float(hang.get(Vector2i(c.x - d, c.y), -9.0)))
				right = maxf(right, float(hang.get(Vector2i(c.x + d, c.y), -9.0)))
			across[c] = maxf(float(hang[c]), minf(left, right) - 0.002)
		for i in v.size():
			if areas[i] != 0 or v[i].z * side < -0.02:
				continue
			var c := Vector2i(floori(v[i].x / DRAPE_CELL), floori(v[i].y / DRAPE_CELL))
			if not across.has(c):
				continue
			var lift := clampf(float(across[c]) - v[i].z * side, 0.0, DRAPE_MAX)
			if lift > 0.0:
				out[i] = Vector3(out[i].x, out[i].y, out[i].z + lift * side)
	# The sides: from the widest point above (the chest, the lats) it hangs straight down, not in at the waist.
	for side in [1.0, -1.0]:
		var widest := {}
		for i in v.size():
			if areas[i] != 0 or n[i].x * side < 0.3:
				continue
			var c := Vector2i(floori(v[i].z / DRAPE_CELL), floori(v[i].y / DRAPE_CELL))
			widest[c] = maxf(float(widest.get(c, -9.0)), v[i].x * side)
		var cols := {}
		for c: Vector2i in widest:
			cols[c.x] = true
		var hang := {}
		for z in cols:
			var above := -9.0
			for y in range(200, -1, -1):
				above -= DRAPE_FALL * DRAPE_CELL
				var c := Vector2i(z, y)
				if widest.has(c):
					above = maxf(float(widest[c]), above)
					hang[c] = above
		for i in v.size():
			if areas[i] != 0 or n[i].x * side < 0.1:
				continue
			var c := Vector2i(floori(v[i].z / DRAPE_CELL), floori(v[i].y / DRAPE_CELL))
			if hang.has(c):
				var lift := clampf(float(hang[c]) - out[i].x * side, 0.0, DRAPE_WAIST_MAX)
				out[i] = Vector3(out[i].x + lift * side, out[i].y, out[i].z)
	return out


## Sleeves hang too: round each arm (its axis from the shoulder to the wrist at rest, in 16 slices round it), the
## cloth stands no closer to the axis than the furthest-out point above it, less DRAPE_FALL a metre. So a sleeve
## falls from the shoulder and the biceps instead of clinging to them. At most DRAPE_SIDE_MAX off the skin.
static func _drape_arms(out: PackedVector3Array, v: PackedVector3Array, areas: PackedInt32Array, skel: Skeleton3D) -> void:
	for s in ["L", "R"]:
		var top := skel.get_bone_global_rest(skel.find_bone("UpperArm" + s)).origin
		var end := skel.get_bone_global_rest(skel.find_bone("Hand" + s)).origin
		var axis := (end - top).normalized()
		var across := axis.cross(Vector3.FORWARD).normalized()
		var deep := axis.cross(across).normalized()
		var mine := func(p: Vector3) -> bool: return (p.x > 0.0) == (s == "L")
		var far := {}
		var spot := {}
		for i in v.size():
			if areas[i] != 1 or not mine.call(v[i]):
				continue
			var d := v[i] - top
			var t := d.dot(axis)
			var r := d - axis * t
			var c := Vector2i(floori(t / DRAPE_CELL), posmod(roundi(atan2(r.dot(deep), r.dot(across)) / TAU * 16.0), 16))
			spot[i] = [c, r.length(), r.normalized()]
			far[c] = maxf(float(far.get(c, 0.0)), r.length())
		var hang := {}
		for k in 16:
			var above := 0.0
			for t in range(0, 80):
				above -= DRAPE_FALL * DRAPE_CELL
				var c := Vector2i(t, k)
				if far.has(c):
					above = maxf(float(far[c]), above)
					hang[c] = above
		var outward := 1.0 if s == "L" else -1.0
		for i in spot:
			var sp: Array = spot[i]
			if (sp[2] as Vector3).x * outward < -0.3:
				continue          # the inside of the sleeve stays where it is, clear of the body
			var lift := clampf(float(hang.get(sp[0], 0.0)) - float(sp[1]), 0.0, DRAPE_SIDE_MAX)
			out[i] += (sp[2] as Vector3) * lift


## Normals for the hung torso: worked out again from its new shape and softened (cloth doesn't show every muscle),
## shared across the mesh's seams. Everything else keeps the skin's own normals.
static func _soft_normals(v: PackedVector3Array, skin: PackedVector3Array, idx: PackedInt32Array, areas: PackedInt32Array) -> PackedVector3Array:
	var weld := {}
	var key := PackedInt32Array()
	key.resize(v.size())
	for i in v.size():
		var k := Vector3i(roundi(v[i].x * 2000.0), roundi(v[i].y * 2000.0), roundi(v[i].z * 2000.0))
		if not weld.has(k):
			weld[k] = weld.size()
		key[i] = weld[k]
	var acc := PackedVector3Array()
	acc.resize(weld.size())
	var nbr := []
	nbr.resize(weld.size())
	for j in weld.size():
		nbr[j] = {}
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var fn := (v[b] - v[a]).cross(v[c] - v[a])
		for q in [a, b, c]:
			acc[key[q]] += fn
		nbr[key[a]][key[b]] = true
		nbr[key[b]][key[c]] = true
		nbr[key[c]][key[a]] = true
		nbr[key[b]][key[a]] = true
		nbr[key[c]][key[b]] = true
		nbr[key[a]][key[c]] = true
	for j in acc.size():
		acc[j] = acc[j].normalized()
	for pass_ in 6:
		var nxt := acc.duplicate()
		for j in acc.size():
			var sum := acc[j] * 2.0
			for o in nbr[j]:
				sum += acc[o]
			nxt[j] = sum.normalized()
		acc = nxt
	var out := skin.duplicate()
	for i in v.size():
		if areas[i] == 0 or areas[i] == 1:
			var nn := acc[key[i]]
			# Its own facing kept if smoothing turned it inside out (thin places).
			out[i] = nn if nn.dot(skin[i]) > 0.0 else skin[i]
	return out


## Put a clothes layer on this body mesh: a sibling drawn with the same skin and skeleton. Returns it; its
## material is its own (set_layers() dresses it).
static func put_on(body: MeshInstance3D, pixel_size: float, kind: String = DEFAULT_BODY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Clothes"
	mi.mesh = shell(body)
	mi.skin = body.skin
	body.get_parent().add_child(mi)
	mi.transform = body.transform
	mi.skeleton = mi.get_path_to(body.get_node(body.skeleton))
	mi.lod_bias = 64.0
	mi.extra_cull_margin = 1.5
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("pixel_size", pixel_size)
	fit_to(mat, kind)
	mi.material_override = mat
	return mi


## Send a body's fit to a clothes material.
static func fit_to(mat: ShaderMaterial, kind: String = DEFAULT_BODY) -> void:
	var m := marks(kind)
	var f := fit(kind)
	var st: Array = f["strap"]
	var tp: Array = f["thigh_pale"]
	mat.set_shader_parameter("fit_face", Vector4(f["face_z"], f["face_half"], m["eyes"], f["eye_apart"]))
	mat.set_shader_parameter("fit_eyes", Vector4(f["eye_size"], f["temple"], m["waist"], f["face_top"]))
	mat.set_shader_parameter("fit_strap", Vector4(st[0], st[1], st[2], st[3]))
	mat.set_shader_parameter("fit_back", Vector4(f["strap_half"], f["pack_half"], f["pack_strap_x"], f["back_z"]))
	mat.set_shader_parameter("fit_front", Vector4(f["front_z"], f["button_z"], f["seam_x"], f["foot_x"]))
	mat.set_shader_parameter("fit_legs", Vector4(tp[0], tp[1], 0.0, 0.0))


## "knee+0.06" -> a height, on this body. (The offsets are metres on every body: a cuff is a cuff.)
static func height(spec, body: String = DEFAULT_BODY) -> float:
	if spec is float or spec is int:
		return float(spec)
	var m := marks(body)
	var s := str(spec)
	for sign_at in [s.find("+"), s.find("-", 1)]:
		if sign_at > 0:
			return float(m.get(s.substr(0, sign_at), 0.0)) + float(s.substr(sign_at))
	return float(m.get(s, 0.0))


## The colour of an ink: a name from ItemArt.INK, or "#rrggbb".
static func ink(spec, fallback := Color(0.5, 0.5, 0.5)) -> Color:
	var s := str(spec)
	if s.begins_with("#"):
		return Color(s)
	return ItemArt.INK.get(s, fallback)


## One worn thing as a layer to draw: its look resolved (cut to heights, inks to colours) with its own state.
## `def` is an item record (Items.DEFS[id]) or any record with a "look"; `item` the carried item (state).
static func layer(def: Dictionary, item: Dictionary = {}, body: String = DEFAULT_BODY) -> Dictionary:
	var look: Dictionary = def.get("look", {})
	var cover: Dictionary = look.get("cover", CUTS.get(str(look.get("cut", "")), {}))
	var cov := {}
	for area: String in AREAS:
		if cover.has(area):
			cov[area] = Vector2(height(cover[area][0], body), height(cover[area][1], body))
		else:
			cov[area] = Vector2(9.0, -9.0)
	var side := str(look.get("side", ""))
	return {
		"cov": cov,
		"ink": ink(look.get("ink", "cloth")), "ink2": ink(look.get("ink2", look.get("ink", "cloth"))),
		"pat": int(PATTERNS.get(str(look.get("pat", "plain")), 0)),
		"thick": float(look.get("thick", 0.008)),
		"shape": int(SHAPES.get(str(look.get("shape", "")), 0)),
		"side": 1 if side == "L" else (2 if side == "R" else 3),
		"open": float(look.get("open", 0.0)), "flare": float(look.get("flare", 0.0)),
		"tatter": float(item.get("tatter", 0.0)), "grime": float(item.get("grime", 0.0)),
		"blood": float(item.get("blood", 0.0)),
		"detail": int(DETAILS.get(str(look.get("detail", "")), 0)),
	}


## Everything worn (place -> item), as layers outermost first. A thing worn over more than one place counts once.
static func layers_of(worn: Dictionary, body: String = DEFAULT_BODY) -> Array:
	var out := []
	var seen := []
	for pl: Array in PLACES:
		var it = worn.get(pl[0])
		if it == null or seen.has(it) or not Items.DEFS.has(it["id"]):
			continue
		seen.append(it)
		var d: Dictionary = Items.DEFS[it["id"]]
		if d.has("look"):
			out.append(layer(d, it, body))
	return out


## Records with a "wear" place and a "look" (not game items: what someone else has on, like a raider), as layers
## outermost first.
static func layers_from(recs: Array, body: String = DEFAULT_BODY) -> Array:
	var sorted := recs.duplicate()
	sorted.sort_custom(func(x, y): return place_index(str(x.get("wear", ""))) < place_index(str(y.get("wear", ""))))
	var out := []
	for rec: Dictionary in sorted:
		out.append(layer(rec, rec.get("state", {}), body))
	return out


static func place_index(place: String) -> int:
	for i in PLACES.size():
		if PLACES[i][0] == place:
			return i
	return PLACES.size()


## Dress a clothes material in these layers (outermost first).
static func set_layers(mat: ShaderMaterial, layers: Array) -> void:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	var c := PackedVector4Array()
	var d := PackedVector4Array()
	var ia := PackedVector4Array()
	var ib := PackedVector4Array()
	var fo := PackedVector4Array()
	var we := PackedVector4Array()
	for i in MAXL:
		var L: Dictionary = layers[i] if i < layers.size() else {}
		if L.is_empty():
			for arr in [a, b, c, d, ia, ib, fo, we]:
				arr.append(Vector4(9.0, -9.0, 9.0, -9.0))
			continue
		var cv: Dictionary = L["cov"]
		a.append(Vector4(cv["torso"].x, cv["torso"].y, cv["arm"].x, cv["arm"].y))
		b.append(Vector4(cv["hand"].x, cv["hand"].y, cv["leg"].x, cv["leg"].y))
		c.append(Vector4(cv["foot"].x, cv["foot"].y, cv["neck"].x, cv["neck"].y))
		d.append(Vector4(cv["head"].x, cv["head"].y, cv["face"].x, cv["face"].y))
		var k1: Color = L["ink"]
		var k2: Color = L["ink2"]
		ia.append(Vector4(k1.r, k1.g, k1.b, L["pat"]))
		ib.append(Vector4(k2.r, k2.g, k2.b, L["thick"]))
		fo.append(Vector4(L["shape"], L["side"], L["open"], L["flare"]))
		we.append(Vector4(L["tatter"], L["grime"], L["blood"], L["detail"]))
	mat.set_shader_parameter("layer_count", mini(layers.size(), MAXL))
	mat.set_shader_parameter("cov_a", a)
	mat.set_shader_parameter("cov_b", b)
	mat.set_shader_parameter("cov_c", c)
	mat.set_shader_parameter("cov_d", d)
	mat.set_shader_parameter("ink_a", ia)
	mat.set_shader_parameter("ink_b", ib)
	mat.set_shader_parameter("form", fo)
	mat.set_shader_parameter("wear", we)


# ------------------------------------------------------------------------------------------- what it keeps out
## Where on the body a blow to a part can land: [area, from, to] in marks, picked at random (an arm is hit three
## times as often as its hand, a leg as its foot).
const SPOTS := {
	"Head": [["head", "chin-0.015", "crown"], ["face", "chin-0.015", "brow+0.015"], ["neck", "neck_lo", "chin-0.015"]],
	"Torso": [["torso", "crotch+0.02", "neck_lo+0.01"]],
	"ArmL": [["arm", "wrist", "shoulder-0.01"], ["arm", "wrist", "shoulder-0.01"], ["arm", "wrist", "shoulder-0.01"], ["hand", "knuckles-0.1", "wrist"]],
	"ArmR": [["arm", "wrist", "shoulder-0.01"], ["arm", "wrist", "shoulder-0.01"], ["arm", "wrist", "shoulder-0.01"], ["hand", "knuckles-0.1", "wrist"]],
	"LegL": [["leg", "ankle+0.01", "hip-0.02"], ["leg", "ankle+0.01", "hip-0.02"], ["leg", "ankle+0.01", "hip-0.02"], ["foot", "sole", "ankle"]],
	"LegR": [["leg", "ankle+0.01", "hip-0.02"], ["leg", "ankle+0.01", "hip-0.02"], ["leg", "ankle+0.01", "hip-0.02"], ["foot", "sole", "ankle"]],
}


## The top of the head on this body, as a spot (what a helmet is checked at).
static func crown_spot(body: String = DEFAULT_BODY) -> Array:
	return ["head", height("crown-0.04", body)]


## What is worn over a spot on this part, outermost first: the items. `spot` is [area, height] (spot_on()).
static func over(worn: Dictionary, part: String, spot: Array, body: String = DEFAULT_BODY) -> Array:
	var out := []
	var seen := []
	var right := part.ends_with("R")
	for pl: Array in PLACES:
		var it = worn.get(pl[0])
		if it == null or seen.has(it) or not Items.DEFS.has(it["id"]):
			continue
		seen.append(it)
		var L := layer(Items.DEFS[it["id"]], it, body)
		if part.begins_with("Arm") or part.begins_with("Leg"):
			if (right and int(L["side"]) & 2 == 0) or (not right and int(L["side"]) & 1 == 0):
				continue
		var area: String = spot[0]
		if int(L["shape"]) == 1:
			if area == "torso" and randf() < 0.2:       # a strap is a narrow thing
				out.append(it)
			continue
		var r: Vector2 = L["cov"][area]
		if float(spot[1]) >= r.x and float(spot[1]) <= r.y:
			out.append(it)
	return out


static func spot_on(part: String, body: String = DEFAULT_BODY) -> Array:
	var choices: Array = SPOTS.get(part, SPOTS["Torso"])
	var s: Array = choices[randi() % choices.size()]
	return [s[0], randf_range(height(s[1], body), height(s[2], body))]


## A bite, a cut or a blow at a part, met by what is worn there, outermost first. Each layer may stop it (its
## `guard` for that kind, less as it is torn); a stopped bite or cut tears it. Returns
## {"stopped": item or {}, "through": [items it went through]}. Things it goes through get blood on them.
static func meet(worn: Dictionary, part: String, kind: String, body: String = DEFAULT_BODY) -> Dictionary:
	var spot := spot_on(part, body)
	var through := []
	for it in over(worn, part, spot, body):
		var g: Dictionary = Items.DEFS[it["id"]].get("guard", {})
		var stop := float(g.get(kind, 0.0)) * (1.0 - float(it.get("tatter", 0.0)))
		if randf() < stop:
			if kind != "blow":
				it["tatter"] = minf(float(it.get("tatter", 0.0)) + (0.1 if kind == "bite" else 0.05), 1.0)
			return {"stopped": it, "through": through, "spot": spot}
		through.append(it)
		if kind != "blow":
			it["tatter"] = minf(float(it.get("tatter", 0.0)) + 0.04, 1.0)
			it["blood"] = minf(float(it.get("blood", 0.0)) + 0.2, 1.0)
	return {"stopped": {}, "through": through, "spot": spot}


## How warm what is worn is, 0 to about 1 (for the warmth need to come): the sum of `guard.warm`, less for holes
## and wet.
static func warmth(worn: Dictionary) -> float:
	var w := 0.0
	var seen := []
	for k in worn:
		var it = worn[k]
		if seen.has(it):
			continue
		seen.append(it)
		var g: Dictionary = Items.DEFS[it["id"]].get("guard", {})
		w += float(g.get("warm", 0.0)) * (1.0 - 0.7 * float(it.get("tatter", 0.0)))
	return w
