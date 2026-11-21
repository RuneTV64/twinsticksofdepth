shader_type spatial;
// Floorboards (and the ceiling over a room, which is the floor of the room above). `along_x`: the boards run
// along X.
//
//   boards   three texels wide with a dark seam, end joints set off board to board, a knot here and there
//   weather  indoors there is none, until the house is worn: then damp stains, and leaves blown in in autumn
//   wear     0 sound; 1 scuffed pale down the middle of each board, seams opening; 2 boards split and gone
#include "res://assets/buildings/house/house_lib.gdshaderinc"

uniform bool along_x = true;

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
	vec2 uv = abs(n.y) > 0.5 ? (along_x ? wp.xz : wp.zx) : house_wall_uv(wp, n);
	vec2 t = house_texel(uv);
	vec2 p = house_point(t);
	float w = wear * 0.5;
	float lane = floor(t.y / 3.0);
	float in_lane = mod(t.y, 3.0);
	float shift = gh1(vec2(lane, 3.0)) * 50.0;
	float piece = floor((t.x + shift) / 44.0);
	float end = mod(t.x + shift, 44.0) < 1.0 ? 1.0 : 0.0;
	float id = gh1(vec2(piece, lane));
	Surf s = surf(H_FLOOR, 0.6 + (id - 0.5) * 0.16 + (gnoise(vec2(p.x * 1.5, p.y * 18.0)) - 0.5) * 0.08);
	s.v -= in_lane < 1.0 ? 0.2 + w * 0.12 : 0.0;      // the seam; it opens as the floor wears
	s.v -= end * 0.16;
	// A knot.
	GroundCell k = gcell(p * vec2(1.1, 3.0) + 13.0);
	if (k.id > 0.8 && k.d1 < 0.12) {
		s.v -= 0.2;
	}
	// Worn pale where feet go; then split, then gone.
	s.v += w * 0.1 * smoothstep(0.4, 0.7, gfbm(p * 0.7 + 2.0));
	if (id < (wear - 1.0) * 0.2) {
		s = surf(H_WOOD, 0.07);
	} else if (id > 1.0 - w * 0.25 && mod(t.x + id * 9.0, 7.0) < 1.0) {
		s.v -= 0.25;
	}
	// The weather gets into a worn house: damp, and leaves.
	float damp = w * (0.3 + e.wet * 0.7);
	s.v -= damp * 0.22 * smoothstep(0.45, 0.7, gfbm(p * 0.8 + 30.0));
	GroundCell lf = gcell(p * 4.0 + 17.0);
	if (lf.d1 < 0.3 && lf.id < e.autumn * w * 0.3) {
		s = gsurf(R_LEAF, 0.4 + lf.id * 1.5);
	}
	ltexel = t;
	vec3 c = house_color(s, t);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/buildings/house/house_light.gdshaderinc"
