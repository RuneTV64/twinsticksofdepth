shader_type spatial;
// Painted woodwork: doors, window frames, stairs, the boards across a boarded window (`bare`: unpainted).
//
//   wood     upright planks three texels wide with a seam between
//   weather  wet darkens it, frost and snow lie on what faces up (outdoors: `outdoors`)
//   wear     0 sound paint; 1 peeling to bare wood; 2 split and mostly bare
#include "res://assets/buildings/house/house_lib.gdshaderinc"

uniform bool bare = false;
uniform bool outdoors = true;

varying vec3 wp;
varying vec3 wn;
varying vec2 ltexel;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
