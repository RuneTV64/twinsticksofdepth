extends SceneTree
## Review sheet for clothes (clothes.gd, clothes.gdshader): a row of players, each dressed in an outfit, front on
## (or SIDE=1 side on, BACK=1 from behind). The outfits here show what the clothes system can draw; most of the
## pieces in them are made up for the picture (records of their own, not game items): the themed bedrooms will
## bring the real ones. ROW 1 is the game's own items (Items.DEFS) as they are worn.
##
## Run from a scratch copy of the game project (copy this file to its root), software OpenGL under xvfb:
##   ROW=0 OUT=/tmp/clothes_0.png xvfb-run -a -s "-screen 0 2800x1600x24" godot --rendering-driver opengl3 \
##       --resolution 2700x620 -s res://clothes_preview.gd
## Test-only patch for the software renderer: it skips the linear->sRGB step, so both the skin shader and the
## clothes shader output their palette colours directly.

const DT := 1.0 / 60.0
const GAP := 1.35

var _frames := 0
var _skin: Shader
var _cloth: Shader


static func L(cut: String, ink: String, more := {}) -> Dictionary:
	var look := {"cut": cut, "ink": ink}
	look.merge(more)
	return {"look": look}


func _outfits(row: int) -> Array:
	if row == 2:
		# Close up on the chest: a shirt on a muscular man must read as a man in a shirt.
		return [
			["Bare", []],
			["T-shirt", [L("tee", "white")]],
			["Dark t-shirt", [L("tee", "dark")]],
			["Tank top", [L("tank", "green")]],
			["Shirt, buttoned", [_as(L("longsleeve", "#8aa0b8", {"detail": "buttons"}), "shirt")]],
			["Hoodie", [_as(L("hoodie", "red", {"thick": 0.012}), "shirt")]],
		]
	if row == 3:
		# The living room's odds and ends: magazines rolled round a forearm (ROW 3).
		return [
			["Start clothes", ["t_shirt", "jeans", "belt", "socks", "sneakers"]],
			["Magazine guard, left arm", ["t_shirt", "jeans", "belt", "socks", "sneakers", "magazine_bracer"]],
			["Both arms", ["t_shirt", "jeans", "belt", "socks", "sneakers", "magazine_bracer", "magazine_bracer_r"]],
			["Both, under curtains as a cloak", ["t_shirt", "jeans", "belt", "socks", "sneakers", "magazine_bracer", "magazine_bracer_r", "curtains"]],
		]
	if row == 1:
		return [
			["Bare (for scale)", []],
			["Start: t-shirt, jeans, belt, socks, sneakers", ["t_shirt", "jeans", "belt", "socks", "sneakers"]],
			["Curtains as a cloak", ["t_shirt", "jeans", "belt", "socks", "sneakers", "curtains"]],
			["Tablecloth knotted into a bundle", ["t_shirt", "jeans", "belt", "socks", "sneakers", "tablecloth"]],
			["Throw blanket round the shoulders", ["t_shirt", "jeans", "belt", "socks", "sneakers", "throw_blanket"]],
			["Lace runner as a scarf", ["t_shirt", "jeans", "belt", "socks", "sneakers", "table_runner"]],
			["Cushion cover as a sack", ["t_shirt", "jeans", "belt", "socks", "sneakers", "cushion_cover"]],
			["Curtain tie-back as a sling", ["t_shirt", "jeans", "belt", "socks", "sneakers", "curtain_tieback"]],
			["Boots, helmet, backpack", ["t_shirt", "jeans", "belt", "socks", "boots", "helmet", "backpack"]],
		]
	var tee := L("tee", "white")
	var jeans := L("jeans", "blue", {"pat": "denim", "ink2": "water", "detail": "jeans", "thick": 0.01})
	var belt := L("belt", "leather", {"pat": "leather", "thick": 0.014})
	var socks := L("socks", "white", {"pat": "knit"})
	var sneakers := L("shoes", "white", {"ink2": "red", "detail": "laces", "thick": 0.02})
	return [
		["Bare (for scale)", []],
		["Basics", [tee, jeans, belt, socks, sneakers]],
		["Dressed to the nines", [_as(L("longsleeve", "white", {"detail": "buttons"}), "shirt"), L("jacket", "dark", {"open": 0.12, "thick": 0.016}),
			L("jeans", "dark", {"thick": 0.012}), L("belt", "leather", {"pat": "leather"}), L("socks", "dark"),
			L("shoes", "leather", {"pat": "leather", "thick": 0.02}), L("band", "steel", {"pat": "metal", "side": "L", "thick": 0.012}),
			L("lenses", "dark", {"shape": "lens", "pat": "glass", "thick": 0.012}), L("ring", "yellow", {"pat": "metal", "side": "L"})]],
		["Winter: parka, beanie, scarf, gloves, boots", [L("hoodie", "olive", {"thick": 0.012}), L("coat", "crimson", {"thick": 0.03, "detail": "zip"}),
			L("beanie", "blue", {"pat": "knit", "thick": 0.014}), L("scarf", "yellow", {"pat": "stripes", "ink2": "red", "thick": 0.02}),
			L("gloves", "dark", {"pat": "knit", "thick": 0.012}), L("jeans", "blue", {"pat": "denim", "ink2": "water"}),
			L("boots", "leather", {"pat": "leather", "thick": 0.022, "detail": "laces"})]],
		["Raider: hood, bandana, sling, pack", [L("hoodie", "dark", {"thick": 0.012}), L("hood", "dark", {"thick": 0.014}),
			L("bandana", "red", {"pat": "print", "ink2": "white"}), _as(L("longsleeve", "red", {"pat": "check", "ink2": "dark", "open": 0.16, "thick": 0.014}), "outer"),
			L("strap", "leather", {"shape": "strap", "pat": "leather", "thick": 0.016}), L("pack", "olive", {"shape": "pack", "pat": "plain", "thick": 0.1}),
			L("jeans", "olive", {"thick": 0.012}), L("gloves", "leather", {"pat": "leather"}), L("boots", "dark", {"pat": "leather", "thick": 0.022})]],
		["Balaclava, tank, shorts", [L("balaclava", "dark", {"pat": "knit", "shape": "slot", "thick": 0.01}), L("tank", "green"),
			L("shorts", "card", {"thick": 0.012}), L("socks", "white", {"pat": "knit"}), L("shoes", "dark", {"detail": "laces"})]],
		["Dressing gown, slippers", [L("robe", "#7a4f6e", {"pat": "plain", "thick": 0.02, "open": 0.06}), _as(L("belt", "#7a4f6e", {"thick": 0.024}), "cloak"),
			L("shoes", "#a08870", {"thick": 0.02})]],
		["Skirt, cardigan, stockings", [L("tee", "#d8c8b8"), _as(L("longsleeve", "#8a5a6a", {"pat": "knit", "open": 0.1, "thick": 0.014, "detail": "buttons"}), "outer"),
			L("skirt", "#4a4e6a", {"pat": "check", "ink2": "#6a3a3a", "flare": 0.25}), L("socks", "dark", {"cover": {"foot": ["bottom", "top"], "leg": ["bottom", "knee+0.06"]}}),
			L("shoes", "dark", {"pat": "leather"})]],
		["Torn, filthy, bloody", [_worn(L("longsleeve", "#8a8a7a"), 0.5, 0.6, 0.5), _worn(L("jeans", "blue", {"pat": "denim", "ink2": "water"}), 0.35, 0.7, 0.2),
			L("boots", "leather", {"pat": "leather", "thick": 0.02})]],
	]


const PLACE_OF := {"tank": "undershirt", "tee": "undershirt", "longsleeve": "shirt", "hoodie": "shirt", "jacket": "outer",
	"coat": "outer", "robe": "outer", "cloak": "cloak", "shawl": "cloak", "poncho": "cloak", "jeans": "legs", "shorts": "legs",
	"skirt": "legs", "socks": "socks", "shoes": "feet", "boots": "feet", "gloves": "hands", "belt": "waist", "band": "wrist_l",
	"ring": "fingers", "beanie": "head", "cap": "head", "hood": "head", "helmet": "head", "bandana": "face", "balaclava": "face",
	"scarf": "neck", "lenses": "eyes", "strap": "strap", "pack": "back"}


func _as(rec: Dictionary, place: String) -> Dictionary:
	rec["wear"] = place
	return rec


func _worn(rec: Dictionary, tatter: float, grime: float, blood: float) -> Dictionary:
	rec["state"] = {"tatter": tatter, "grime": grime, "blood": blood}
	return rec


func _init() -> void:
	_skin = Shader.new()
	_skin.code = FileAccess.get_file_as_string("res://body/male_body_muscular_skin.gdshader").replace("ALBEDO=pow(c,vec3(2.2));", "ALBEDO=c;")
	_cloth = Shader.new()
	_cloth.code = FileAccess.get_file_as_string("res://clothes.gdshader").replace("ALBEDO = pow(col, vec3(2.2));", "ALBEDO = col;")
	_build.call_deferred(int(OS.get_environment("ROW")))


func _build(row: int) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.24)
	world.add_child(env)
	var cells := _outfits(row)
	var turn := Vector3(0, 0, 1)
	if OS.get_environment("SIDE") != "":
		turn = Vector3(-1, 0, 0)
	if OS.get_environment("BACK") != "":
		turn = Vector3(0, 0, -1)
	for i in cells.size():
		var c: Array = cells[i]
		var x := (i - (cells.size() - 1) * 0.5) * (0.75 if row == 2 else GAP)
		var p := Player.new()
		p.position = Vector3(x, 0.0, 0.0)
		world.add_child(p)
		p.set_physics_process(false)
		p.set_process_input(false)
		p._body.material.shader = _skin
		p.facing = turn
		var layers := []
		if row == 1 or row == 3:
			for k in p.inv.worn.keys():
				p.inv.worn.erase(k)
			for id: String in c[1]:
				var it := Items.make(id)
				var place := str(Items.DEFS[id]["wear"])
				p.inv.worn[place] = it
			layers = Clothes.layers_of(p.inv.worn)
		else:
			# Outermost first, as Clothes.layers_of() orders the game's own: by where each is worn.
			for rec: Dictionary in c[1]:
				if not rec.has("wear"):
					rec["wear"] = PLACE_OF.get(str(rec["look"]["cut"]), "shirt")
			layers = Clothes.layers_from(c[1])
		p._body.dress(layers)
		if p._body._clothes != null:
			(p._body._clothes.material_override as ShaderMaterial).shader = _cloth
		for n in 60:
			p._update_visuals(DT)
		p._body.dress(layers)
		p._reticle.visible = false
		p._reticle_x.visible = false
		var l := Label3D.new()
		l.text = c[0]
		l.font_size = 22
		l.outline_size = 8
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = 200
		l.position = Vector3(x, 1.75 if row == 2 else 2.25, 0.0)
		world.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.0
	world.add_child(cam)
	cam.position = Vector3(0.0, 4.0, 12.0)
	cam.look_at(Vector3(0.0, 1.05, 0.0))
	if row == 2:
		cam.size = 1.1          # the chest, close
		cam.position = Vector3(0.0, 3.0, 12.0)
		cam.look_at(Vector3(0.0, 1.28, 0.0))
	cam.make_current()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
