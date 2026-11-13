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

const MAP_SIZE := 96.0               # meters covered by the explored map, centered on the origin
const MAP_CELLS := 192               # half-meter cells

var player: Player
var cam: Camera3D

var _mat: ShaderMaterial
var _explored: Image
var _explored_tex: ImageTexture
var _mark_t := 0.0
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
uniform float map_size;
uniform float explored_dim;
uniform float unexplored_dim;
uniform float now;
uniform float stale_delay;
uniform float stale_time;
uniform float edge_soft;
uniform float see_past;

void vertex() {
	// Cover the whole screen whatever the camera is doing.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	float fog = unexplored_dim;
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
		float cone = mix(sight_range, sight_near, smoothstep(half_fov, half_fov + taper, off));
		float reach = min(wall, cone);
		float in_view = 1.0 - smoothstep(reach - edge_soft, reach, dist);

		// r = ever seen (0/1), g = when it was last seen (0 where never). Dividing the
		// filtered g by the filtered r gives the last-seen time of the seen cells nearby.
		vec2 e = texture(explored_tex, world.xz / map_size + 0.5).rg;
		float seen = e.r;
		float last_seen = e.g / max(e.r, 0.001);
		float stale = smoothstep(stale_delay, stale_delay + stale_time, now - last_seen);
		fog = mix(unexplored_dim, explored_dim * stale, seen) * (1.0 - in_view);
	}
	ALBEDO = vec3(0.0);
	// Blending happens in linear light, where 6% left still reads as fairly bright.
	// Convert so the dim values mean what they look like on screen.
	ALPHA = 1.0 - pow(1.0 - fog, 2.2);
}
"""


func _ready() -> void:
	# Two float channels per cell: r = ever seen, g = game time it was last seen.
	_explored = Image.create(MAP_CELLS, MAP_CELLS, false, Image.FORMAT_RGF)
	_explored.fill(Color(0, 0, 0))
	_explored_tex = ImageTexture.create_from_image(_explored)

	var sh := Shader.new()
	sh.code = SHADER.replace("RAY_COUNT", str(Player.SIGHT_RAYS))
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.render_priority = 5   # over the world and faded enemies, under the reticle (10)
	_mat.set_shader_parameter("explored_tex", _explored_tex)
	_mat.set_shader_parameter("map_size", MAP_SIZE)

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
	_mat.set_shader_parameter("sight_range", player.sight_range)
	_mat.set_shader_parameter("sight_near", player.sight_near)
	_clock += delta
	_mat.set_shader_parameter("now", _clock)
	_mat.set_shader_parameter("stale_delay", stale_delay)
	_mat.set_shader_parameter("stale_time", maxf(stale_time, 0.01))
	_mat.set_shader_parameter("explored_dim", explored_dim)
	_mat.set_shader_parameter("unexplored_dim", unexplored_dim)
	_mat.set_shader_parameter("edge_soft", edge_soft)
	_mat.set_shader_parameter("see_past", see_past)
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = 0.1
		_mark_explored()


## Remember everything currently in view: walk each sight ray and stamp the cells under it
## with the current time.
func _mark_explored() -> void:
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var white := Color(1.0, _clock, 0.0)
	var cell := MAP_SIZE / MAP_CELLS
	# Twice as many spokes as sight rays, so cells at the far end of the cone aren't skipped.
	var spokes := Player.SIGHT_RAYS * 2
	for i in spokes:
		var a := -PI + i * TAU / spokes
		var dir := Vector2(cos(a), sin(a))
		var reach: float = player.sight_reach_angle(a) + see_past
		var d := 0.0
		while d <= reach:
			var p := origin + dir * d
			var cx := int(floor(p.x / cell + MAP_CELLS * 0.5))
			var cy := int(floor(p.y / cell + MAP_CELLS * 0.5))
			if cx >= 0 and cy >= 0 and cx < MAP_CELLS and cy < MAP_CELLS:
				_explored.set_pixel(cx, cy, white)
			d += cell * 0.9
	_explored_tex.update(_explored)


## Has this spot ever been in view?
func is_explored(pos: Vector3) -> bool:
	var cell := MAP_SIZE / MAP_CELLS
	var cx := int(floor(pos.x / cell + MAP_CELLS * 0.5))
	var cy := int(floor(pos.z / cell + MAP_CELLS * 0.5))
	if cx < 0 or cy < 0 or cx >= MAP_CELLS or cy >= MAP_CELLS:
		return false
	return _explored.get_pixel(cx, cy).r > 0.5
