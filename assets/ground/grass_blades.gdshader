shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
// Standing grass: tufts of blades (grass_blades.gd scatters them). It goes with the grass painted on the ground
// (grass_types.gdshaderinc) and keeps the same colours and the same seasons:
//   spring   short and bright         summer   full height, yellowing in a drought
//   autumn   going to straw           winter   dead, beaten down, frost on the tips, buried by snow
// The blades sway (in sprite steps, 10 a second), and they part round whoever walks or crawls through them
// (grass_push, a project-wide value the player keeps up to date), so you can see where someone is going.
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/ground/dirt_types.gdshaderinc"
#include "res://assets/ground/grass_types.gdshaderinc"

// Whoever is pushing through the grass: xyz = where they are, w = how wide a swathe they part (0 = nobody).
global uniform vec4 grass_push;

uniform float straw_bias = 0.0;        // how much more of it is straw than the season alone would make
uniform float sway = 0.12;             // m the tips move in the wind, for a blade a metre tall
uniform float snow_bury = 0.7;         // how much of its height deep snow hides
uniform vec4 season_override = vec4(-1.0, 0.0, 0.0, 0.0);   // x < 0: follow the world's season

varying vec3 wp;
varying float grow;                    // how tall it stands just now, as a share of full height

void vertex() {
	GroundEnv e = ground_env(season_override.x < 0.0 ? ground_season : season_override);
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = UV.y;                                        // 0 at the foot .. 1 at the tip
	// How tall the season lets it stand.
	grow = (0.62 * e.spring + 1.0 * e.summer + 0.9 * e.autumn + 0.5 * e.winter) * (1.0 - snow_bury * e.snow);
	float tall = VERTEX.y - root.y;
	VERTEX.y = root.y + tall * grow;
	// Winter grass lies over; all grass leans with the wind.
	float t = floor(TIME * 10.0) / 10.0;
	float wind = 0.6 * sin(t * 1.7 + root.x * 0.9 + root.z * 1.3) + 0.4 * sin(t * 0.83 + root.x * 0.31 - root.z * 0.2);
	vec2 lean = vec2(0.94, 0.34) * (wind * sway + 0.25 * e.winter) * h * h * tall;
	// Parting round whoever is in it: pushed away from them and pressed down.
	if (grass_push.w > 0.0) {
		vec2 away = root.xz - grass_push.xz;
		float d = length(away);
		float f = (1.0 - smoothstep(grass_push.w * 0.35, grass_push.w, d)) * step(abs(root.y - grass_push.y), 1.5);
		if (f > 0.0) {
			lean += (d > 0.01 ? away / d : vec2(1.0, 0.0)) * f * h * tall * 0.75;
			VERTEX.y = root.y + (VERTEX.y - root.y) * (1.0 - 0.72 * f);
		}
	}
	VERTEX.xz += lean;
	wp = VERTEX;
}

void fragment() {
	GroundEnv e = ground_env(season_override.x < 0.0 ? ground_season : season_override);
	float h = UV.y;
	float rnd = UV.x;
	Ground g;
	g.ramp = fract(rnd * 7.3) < grass_straw(e, straw_bias) ? R_STRAW : R_GREEN;
	g.v = 0.24 + 0.4 * h + 0.2 * (rnd - 0.5) + 0.05 * e.spring - 0.1 * e.winter - 0.08 * e.wet;
	// Seed heads from high summer, frost on the tips, snow caught on what still shows.
	if (h > 0.82 && fract(rnd * 13.1) < 0.4 * (e.summer + e.autumn)) {
		g.ramp = R_STRAW;
		g.v = 0.85;
	}
	if (h > 0.6 && fract(rnd * 3.7) < e.frost * 0.8) {
		g.ramp = R_ICE;
		g.v = 0.55 + 0.4 * h;
	}
	if (e.snow > 0.25 && h > 0.75 - 0.4 * e.snow && fract(rnd * 5.1) < e.snow) {
		g.ramp = R_SNOW;
		g.v = 0.9;
	}
	// Texels: across the screen and up the blade, the same size as the ground's.
	vec2 texel = vec2(floor(ground_frame(wp.xz).x * GROUND_TEXELS), floor(wp.y * GROUND_TEXELS));
	vec3 c = ground_color(g, texel);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Lit like the ground it stands on, whichever way a blade happens to face.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

#include "res://assets/ground/ground_light.gdshaderinc"
