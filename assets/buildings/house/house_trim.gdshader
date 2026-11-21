shader_type spatial;
// Painted woodwork: doors, window frames, stairs, the boards across a boarded window (`bare`: unpainted).
//
//   wood     upright planks three texels wide with a seam between
//   weather  wet darkens it, frost and snow lie on what faces up (outdoors: `outdoors`)
//   wear     0 sound paint; 1 peeling to bare wood; 2 split and mostly bare
#include "res://assets/buildings/house/house_lib.gdshaderinc"

uniform bool bare = false;
uniform bool outdoors = true;
// Stairs: `stair_run` over 0 makes the tops bare wooden treads; with `stair_dir` (the way up, on the ground:
// x, z) each tread gets a pale nosing at its front edge and the shadow of the next riser at its back, and the
// risers are a shade darker than the rest. Each step is a box of its own, so this is by the box's own middle.
uniform float stair_run = 0.0;
uniform vec2 stair_dir = vec2(0.0, 0.0);

varying vec3 wp;
varying vec3 wn;
varying vec3 lp;
varying vec2 ltexel;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lp = VERTEX;
}

void fragment() {
	if (cutaway_hidden(wp, FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(wn);
	GroundEnv e = house_env();
	bool top = abs(n.y) > 0.5;
	vec2 uv = top ? wp.xz : house_wall_uv(wp, n);
	vec2 t = house_texel(uv);
	vec2 p = house_point(t);
	float w = wear * 0.5;
	float plank = floor(t.x / 3.0);
	float id = gh1(vec2(plank, 5.0));
	Surf s = surf(H_TRIM, 0.72 + (id - 0.5) * 0.06);
	if (bare || gfbm(p.yx * vec2(1.2, 6.0) + id * 7.0) < w * 0.7 - 0.05) {
		s = house_wood(p.yx, 0.5 + (id - 0.5) * 0.14);
	}
	s.v -= mod(t.x, 3.0) < 1.0 ? 0.18 : 0.0;
	if (id < w * 0.3 && mod(t.y + id * 30.0, 11.0) < 6.0 && mod(t.x, 3.0) > 1.5) {
		s.v -= 0.3;                           // a split down the plank
	}
	if (stair_run > 0.0) {
		bool has_dir = dot(stair_dir, stair_dir) > 0.1;
		if (top) {
			// A tread: bare boards across the stair, worn pale down the middle.
			vec2 across = has_dir ? vec2(-stair_dir.y, stair_dir.x) : vec2(1.0, 0.0);
			float u = has_dir ? dot(lp.xz, stair_dir) : 0.0;
			float a = dot(wp.xz, across);
			s = surf(H_FLOOR, 0.62 + (gnoise(vec2(a * 14.0, floor(wp.y * 9.0))) - 0.5) * 0.12 + w * 0.08);
			if (has_dir && u < -stair_run * 0.5 + 0.07) {
				s.v += 0.2;                        // the nosing catches the light
			} else if (has_dir && u > stair_run * 0.5 - 0.09) {
				s.v -= 0.34;                       // the shadow under the next riser
			}
			if (gh1(vec2(floor(a * 3.0), floor(wp.y * 9.0))) < w * 0.3) {
				s = surf(H_WOOD, 0.1);              // a tread split through
			}
		} else if (has_dir && dot(n.xz, stair_dir) < -0.5) {
			s.v -= 0.2;                            // a riser, in its own shadow
			s.v -= fract(wp.y * 16.0 / 3.6) > 0.8 ? 0.12 : 0.0;
		}
	}
	if (outdoors) {
		s = house_weather(s, p, t, e, top ? 1.0 : 0.0, 9.0);
	}
	ltexel = t;
	vec3 c = house_color(s, t);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/buildings/house/house_light.gdshaderinc"
