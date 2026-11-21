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

## Heights on the body at rest (m), for cuts: the one body there is (1.80 m, arms down at the sides; the bones'
## own rest heights where there is a bone). "top" and "bottom" are past either end.
const MARK := {
	"bottom": -9.0, "sole": 0.0, "ankle": 0.09, "shin": 0.3, "knee": 0.51, "thigh": 0.7, "crotch": 0.86,
	"hip": 0.92, "waist": 1.0, "navel": 1.06, "chest": 1.25, "armpit": 1.32, "shoulder": 1.45, "neck_lo": 1.49,
	"neck": 1.53, "chin": 1.575, "mouth": 1.615, "nose": 1.65, "eyes": 1.69, "brow": 1.715, "crown": 1.8,
	"biceps": 1.27, "elbow": 1.12, "forearm": 1.0, "wrist": 0.88, "knuckles": 0.8, "top": 9.0,
}
const AREAS := ["torso", "arm", "hand", "leg", "foot", "neck", "head", "face"]

## Cuts: what a kind of garment covers, area -> [from, to] in MARK names (+ or - metres).
const CUTS := {
	"tank": {"torso": ["hip+0.04", "neck_lo-0.03"]},
	"tee": {"torso": ["hip+0.04", "top"], "arm": ["biceps-0.03", "top"]},
	"longsleeve": {"torso": ["hip+0.03", "top"], "arm": ["wrist+0.015", "top"]},
	"hoodie": {"torso": ["hip", "top"], "arm": ["wrist+0.01", "top"], "neck": ["bottom", "neck-0.01"]},
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
	var keep := []
	keep.resize(Mesh.ARRAY_MAX)
	keep[Mesh.ARRAY_VERTEX] = v
	keep[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
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


## Put a clothes layer on this body mesh: a sibling drawn with the same skin and skeleton. Returns it; its
## material is its own (set_layers() dresses it).
static func put_on(body: MeshInstance3D, pixel_size: float) -> MeshInstance3D:
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
	mat.set_shader_parameter("eyes_y", MARK["eyes"])
	mat.set_shader_parameter("waist_y", MARK["waist"])
	mi.material_override = mat
	return mi


## "knee+0.06" -> a height.
static func height(spec) -> float:
	if spec is float or spec is int:
		return float(spec)
	var s := str(spec)
	for sign_at in [s.find("+"), s.find("-", 1)]:
		if sign_at > 0:
			return float(MARK.get(s.substr(0, sign_at), 0.0)) + float(s.substr(sign_at))
	return float(MARK.get(s, 0.0))


## The colour of an ink: a name from ItemArt.INK, or "#rrggbb".
static func ink(spec, fallback := Color(0.5, 0.5, 0.5)) -> Color:
	var s := str(spec)
	if s.begins_with("#"):
		return Color(s)
	return ItemArt.INK.get(s, fallback)


## One worn thing as a layer to draw: its look resolved (cut to heights, inks to colours) with its own state.
## `def` is an item record (Items.DEFS[id]) or any record with a "look"; `item` the carried item (state).
static func layer(def: Dictionary, item: Dictionary = {}) -> Dictionary:
	var look: Dictionary = def.get("look", {})
	var cover: Dictionary = look.get("cover", CUTS.get(str(look.get("cut", "")), {}))
	var cov := {}
	for area: String in AREAS:
		if cover.has(area):
			cov[area] = Vector2(height(cover[area][0]), height(cover[area][1]))
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
static func layers_of(worn: Dictionary) -> Array:
	var out := []
	var seen := []
	for pl: Array in PLACES:
		var it = worn.get(pl[0])
		if it == null or seen.has(it) or not Items.DEFS.has(it["id"]):
			continue
		seen.append(it)
		var d: Dictionary = Items.DEFS[it["id"]]
		if d.has("look"):
			out.append(layer(d, it))
	return out


## Records with a "wear" place and a "look" (not game items: what someone else has on, like a raider), as layers
## outermost first.
static func layers_from(recs: Array) -> Array:
	var sorted := recs.duplicate()
	sorted.sort_custom(func(x, y): return place_index(str(x.get("wear", ""))) < place_index(str(y.get("wear", ""))))
	var out := []
	for rec: Dictionary in sorted:
		out.append(layer(rec, rec.get("state", {})))
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
## Where on the body a blow to a part can land: [area, low, high] (heights at rest), picked at random.
const SPOTS := {
	"Head": [["head", 1.56, 1.8], ["face", 1.56, 1.73], ["neck", 1.49, 1.56]],
	"Torso": [["torso", 0.88, 1.5]],
	"ArmL": [["arm", 0.88, 1.44], ["arm", 0.88, 1.44], ["arm", 0.88, 1.44], ["hand", 0.7, 0.88]],
	"ArmR": [["arm", 0.88, 1.44], ["arm", 0.88, 1.44], ["arm", 0.88, 1.44], ["hand", 0.7, 0.88]],
	"LegL": [["leg", 0.1, 0.9], ["leg", 0.1, 0.9], ["leg", 0.1, 0.9], ["foot", 0.0, 0.09]],
	"LegR": [["leg", 0.1, 0.9], ["leg", 0.1, 0.9], ["leg", 0.1, 0.9], ["foot", 0.0, 0.09]],
}


## What is worn over a spot on this part, outermost first: the items. `spot` is [area, height] (spot_on()).
static func over(worn: Dictionary, part: String, spot: Array) -> Array:
	var out := []
	var seen := []
	var right := part.ends_with("R")
	for pl: Array in PLACES:
		var it = worn.get(pl[0])
		if it == null or seen.has(it) or not Items.DEFS.has(it["id"]):
			continue
		seen.append(it)
		var L := layer(Items.DEFS[it["id"]], it)
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


static func spot_on(part: String) -> Array:
	var choices: Array = SPOTS.get(part, SPOTS["Torso"])
	var s: Array = choices[randi() % choices.size()]
	return [s[0], randf_range(float(s[1]), float(s[2]))]


## A bite, a cut or a blow at a part, met by what is worn there, outermost first. Each layer may stop it (its
## `guard` for that kind, less as it is torn); a stopped bite or cut tears it. Returns
## {"stopped": item or {}, "through": [items it went through]}. Things it goes through get blood on them.
static func meet(worn: Dictionary, part: String, kind: String) -> Dictionary:
	var spot := spot_on(part)
	var through := []
	for it in over(worn, part, spot):
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
