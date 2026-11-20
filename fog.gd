extends Node3D
## Fog of war. A full-screen pass that darkens everything the player can't see right now:
##  - in view (the player's sight rays reach it): clear
##  - seen before: stays clear at first, then slowly grays over as time passes since you last
##    looked. Gray means "it's been a while": worth checking again for supplies.
##  - never seen: almost black
## It reads the depth buffer to find where each pixel really is in the world, so wall faces
## and tops are judged by their own position, not the ground behind them.

@export var explored_dim := 0.5      # how dark a long-unvisited area gets (0 = clear, 1 = black)
@export var stale_delay := 20.0      # seconds an area stays fully clear after you last saw it
@export var stale_time := 120.0      # seconds after that for the gray to fade all the way in
@export var unexplored_dim := 0.9    # how dark never-seen areas look
@export var edge_soft := 0.7         # meters over which the edge of your view fades
@export var see_past := 0.6          # meters past a ray's end still lit, so the wall it hit shows

## The part of the world the explored map covers (XZ). Set these before adding the node.
var map_min := Vector2(-48.0, -48.0)
var map_size := Vector2(96.0, 96.0)
const CELL := 0.5                    # meters per explored-map cell

var _cells_x := 0
var _cells_y := 0

var player: Player
var cam: Camera3D

var _mat: ShaderMaterial
var _explored: Image
var _explored_tex: ImageTexture
var _mark_t := 0.0
var _lamps_sent := -1
var _beams_sent := 0
## How black the dead of night is drawn where no lamp reaches (1 = pitch black).
@export var dark_max := 0.82
var _clock := 0.0   # game seconds; what "last seen" times are measured against

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D explored_tex : filter_linear, repeat_disable;
uniform vec2 player_xz;
uniform float rays[RAY_COUNT];   // distance to the first wall in each direction
uniform float face_angle;        // the cone: same formula as Player.sight_limit()
uniform float half_fov;
uniform float taper;
uniform float sight_range;
uniform float sight_near;
uniform vec2 map_min;
uniform vec2 map_size;
uniform float explored_dim;
uniform float unexplored_dim;
uniform float now;
uniform float stale_delay;
uniform float stale_time;
uniform float edge_soft;
uniform float see_past;
// Light and dark (daylight.gd): how dark the open is, how far the dark lets you see, and the lamps.
uniform float dark;              // 0 day .. 1 the dead of night
uniform float dark_max;          // how black full dark is drawn
uniform float night_sight;       // share of your sight the daylight leaves you
uniform vec4 lamps[LAMP_COUNT];  // xyz = where, w = radius (0 = unused)
uniform vec4 beams[BEAM_COUNT];        // carried torches: xy = where (x, z), zw = which way (x, z); see Daylight
uniform vec4 beam_shapes[BEAM_COUNT];  // x = range (0 = unused), y = cos of half its angle, z = the glow round the holder

void vertex() {
	// Cover the whole screen whatever the camera is doing.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	float fog = unexplored_dim;
	float night = dark;
	if (depth > 0.000001) {
		// Rebuild the world position of whatever is drawn at this pixel.
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		view.xyz /= view.w;
		vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;

		vec2 rel = world.xz - player_xz;
		float dist = length(rel);
		float ang = atan(rel.y, rel.x);
		float f = (ang + PI) / TAU * float(RAY_COUNT);
		int i0 = int(floor(f)) % RAY_COUNT;
		int i1 = (i0 + 1) % RAY_COUNT;
		float wall = mix(rays[i0], rays[i1], fract(f)) + see_past;
		float off = abs(mod(ang - face_angle + PI, TAU) - PI);
		// How lit this spot is by a lamp or a fire: a lit place shows from as far as ever, and isn't darkened.
		float lit = 0.0;
		for (int li = 0; li < LAMP_COUNT; li++) {
			float lr = lamps[li].w;
			if (lr > 0.0) {
				lit = max(lit, 1.0 - smoothstep(lr * 0.35, lr, length(world.xz - lamps[li].xz)));
			}
		}
		for (int bi = 0; bi < BEAM_COUNT; bi++) {
			vec4 bs = beam_shapes[bi];
			if (bs.x > 0.0) {
				vec2 brel = world.xz - beams[bi].xy;
				float bd = length(brel);
				lit = max(lit, 1.0 - smoothstep(bs.z * 0.5, bs.z, bd));
				if (bd > 0.01 && bd < bs.x) {
					float along = dot(brel, beams[bi].zw) / bd;
					lit = max(lit, smoothstep(bs.y, bs.y + 0.04, along) * (1.0 - smoothstep(bs.x * 0.6, bs.x, bd)));
				}
			}
		}
		night = dark * (1.0 - lit);
		float far = sight_range * mix(night_sight, 1.0, lit);
		float cone = mix(far, min(sight_near, far), smoothstep(half_fov, half_fov + taper, off));
		float reach = min(wall, cone);
		float in_view = 1.0 - smoothstep(reach - edge_soft, reach, dist);

		// r = ever seen (0/1), g = when it was last seen (0 where never). Dividing the
		// filtered g by the filtered r gives the last-seen time of the seen cells nearby.
		vec2 e = texture(explored_tex, (world.xz - map_min) / map_size).rg;
		float seen = e.r;
		float last_seen = e.g / max(e.r, 0.001);
		float stale = smoothstep(stale_delay, stale_delay + stale_time, now - last_seen);
		fog = mix(unexplored_dim, explored_dim * stale, seen) * (1.0 - in_view);
	}
	ALBEDO = vec3(0.0);
	// Blending happens in linear light, where 6% left still reads as fairly bright.
	// Convert so the dim values mean what they look like on screen.
	// The dark lies over everything, seen or not; the fog of war goes on top of it.
	float seen_alpha = 1.0 - pow(1.0 - fog, 2.2);
	ALPHA = 1.0 - (1.0 - seen_alpha) * (1.0 - night * dark_max);
}
"""


func _ready() -> void:
	# Two float channels per cell: r = ever seen, g = game time it was last seen.
	_cells_x = int(ceil(map_size.x / CELL))
	_cells_y = int(ceil(map_size.y / CELL))
	_explored = Image.create(_cells_x, _cells_y, false, Image.FORMAT_RGF)
	_explored.fill(Color(0, 0, 0))
	_explored_tex = ImageTexture.create_from_image(_explored)

	var sh := Shader.new()
	sh.code = SHADER.replace("RAY_COUNT", str(Player.SIGHT_RAYS)).replace("LAMP_COUNT", str(Daylight.LAMP_MAX)).replace("BEAM_COUNT", str(Daylight.BEAM_MAX))
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.render_priority = 5   # over the world and faded enemies, under the reticle (10)
	_mat.set_shader_parameter("explored_tex", _explored_tex)
	_mat.set_shader_parameter("map_min", map_min)
	_mat.set_shader_parameter("map_size", Vector2(_cells_x, _cells_y) * CELL)

	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	quad.mesh = qm
	quad.material_override = _mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.extra_cull_margin = 16384.0   # never culled: the shader places it on screen itself
	quad.position = Vector3(0.0, 0.0, -1.0)
	cam.add_child(quad)


func _process(delta: float) -> void:
	if player == null or player.sight_rays.size() != Player.SIGHT_RAYS:
		return
	_mat.set_shader_parameter("player_xz", Vector2(player.global_position.x, player.global_position.z))
	_mat.set_shader_parameter("rays", player.sight_rays)
	_mat.set_shader_parameter("face_angle", player.facing_angle())
	_mat.set_shader_parameter("half_fov", deg_to_rad(player.sight_fov_deg) * 0.5)
	_mat.set_shader_parameter("taper", Player.SIGHT_TAPER)
	_mat.set_shader_parameter("sight_range", player.view_range)   # the view as it is now (shrinks behind cover)
	_mat.set_shader_parameter("sight_near", player.view_near)
	_clock += delta
	_mat.set_shader_parameter("now", _clock)
	_mat.set_shader_parameter("stale_delay", stale_delay)
	_mat.set_shader_parameter("stale_time", maxf(stale_time, 0.01))
	_mat.set_shader_parameter("explored_dim", explored_dim)
	_mat.set_shader_parameter("unexplored_dim", unexplored_dim)
	_mat.set_shader_parameter("edge_soft", edge_soft)
	_mat.set_shader_parameter("see_past", see_past)
	_mat.set_shader_parameter("dark", 1.0 - Daylight.level)
	_mat.set_shader_parameter("dark_max", dark_max)
	_mat.set_shader_parameter("night_sight", Daylight.sight_share())
	if not Daylight.beams.is_empty() or _beams_sent > 0:
		# The torches that are on, nearest to the player first (only so many can be drawn).
		var ids: Array = Daylight.beams.keys()
		if ids.size() > Daylight.BEAM_MAX:
			var me := player.global_position
			ids.sort_custom(func(a, b): return (Daylight.beams[a]["pos"] as Vector3).distance_squared_to(me) < (Daylight.beams[b]["pos"] as Vector3).distance_squared_to(me))
		var bp := PackedVector4Array()
		var bs := PackedVector4Array()
		bp.resize(Daylight.BEAM_MAX)
		bs.resize(Daylight.BEAM_MAX)
		_beams_sent = mini(ids.size(), Daylight.BEAM_MAX)
		for i in _beams_sent:
			var b: Dictionary = Daylight.beams[ids[i]]
			var p3: Vector3 = b["pos"]
			var d3: Vector3 = b["dir"]
			bp[i] = Vector4(p3.x, p3.z, d3.x, d3.z)
			bs[i] = Vector4(float(b["range"]), float(b["cos"]), Daylight.BEAM_GLOW, 0.0)
		_mat.set_shader_parameter("beams", bp)
		_mat.set_shader_parameter("beam_shapes", bs)
	if _lamps_sent != Daylight.lamps.size():
		# (Lamps don't move: sent when one is added.)
		_lamps_sent = Daylight.lamps.size()
		var arr := PackedVector4Array()
		arr.resize(Daylight.LAMP_MAX)
		for i in mini(_lamps_sent, Daylight.LAMP_MAX):
			var lp: Vector3 = Daylight.lamps[i]["pos"]
			arr[i] = Vector4(lp.x, lp.y, lp.z, float(Daylight.lamps[i]["radius"]))
		_mat.set_shader_parameter("lamps", arr)
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = 0.1
		_mark_explored()


## Remember everything currently in view: walk each sight ray and stamp the cells under it
## with the current time.
func _mark_explored() -> void:
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var white := Color(1.0, _clock, 0.0)
	var cell := CELL
	# Twice as many spokes as sight rays, so cells at the far end of the cone aren't skipped.
	var spokes := Player.SIGHT_RAYS * 2
	for i in spokes:
		var a := -PI + i * TAU / spokes
		var dir := Vector2(cos(a), sin(a))
		var reach: float = player.sight_reach_angle(a) + see_past
		var d := 0.0
		while d <= reach:
			var p := origin + dir * d
			var cx := int(floor((p.x - map_min.x) / cell))
			var cy := int(floor((p.y - map_min.y) / cell))
			if cx >= 0 and cy >= 0 and cx < _cells_x and cy < _cells_y:
				_explored.set_pixel(cx, cy, white)
			d += cell * 0.9
	_explored_tex.update(_explored)


## Has this spot ever been in view?
func is_explored(pos: Vector3) -> bool:
	var cx := int(floor((pos.x - map_min.x) / CELL))
	var cy := int(floor((pos.z - map_min.y) / CELL))
	if cx < 0 or cy < 0 or cx >= _cells_x or cy >= _cells_y:
		return false
	return _explored.get_pixel(cx, cy).r > 0.5
