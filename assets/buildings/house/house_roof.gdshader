shader_type spatial;
// A pitched roof of shingles. `ridge_x`: the ridge runs along X (the slopes fall to north and south); otherwise
// along Z.
//
//   shingles  rows four texels deep, each row set off from the last, a shadow under every row
//   weather   dark and streaked when wet, moss up from the eaves in the damp seasons, leaves in autumn,
//             frost, and snow that lies in patches and then covers it
//   wear      0 whole; 1 shingles missing and lifted; 2 bare patches down to the dark boards
#include "res://assets/buildings/house/house_lib.gdshaderinc"

uniform bool ridge_x = true;
uniform float eave_y = 2.7;        // the height of the eaves: moss grows up from here

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
	// Along the ridge, and down the slope (measured on the slope itself, so rows keep their depth).
	float across = ridge_x ? wp.z : wp.x;
	vec2 uv = vec2(ridge_x ? wp.x : wp.z, across / max(n.y, 0.3) * sign(ridge_x ? n.z : n.x));
	vec2 t = house_texel(uv);
	vec2 p = house_point(t);
	float w = wear * 0.5;
	float row = floor(t.y / 4.0);
	float in_row = mod(t.y, 4.0);
	float off = mod(row, 2.0) * 3.0;
	float tile = floor((t.x + off) / 5.0);
	float edge = mod(t.x + off, 5.0) < 1.0 ? 1.0 : 0.0;
	float id = gh1(vec2(tile, row));
	Surf s = surf(H_SHINGLE, 0.56 + (id - 0.5) * 0.22);
	s.v -= in_row > 2.5 ? 0.26 : 0.0;       // the shadow under the row above
	s.v -= edge * 0.12;
	// Shingles gone, in ones and then in patches: the dark boards under them.
	if (id < w * 0.2 || gfbm(p * 0.8 + 21.0) < (wear - 1.0) * 0.36) {
		s = surf(H_WOOD, 0.14 + in_row * 0.02);
	} else if (id > 1.0 - w * 0.15) {
		s.v += 0.14;                          // one lifted, catching the light
	}
	// Moss, thickest at the eaves; more on a worn roof.
	float up_roof = max(wp.y - eave_y, 0.0);
	float damp = e.spring * 0.5 + e.autumn * 0.7 + e.wet * 0.3 + w * 0.7;
	if (gfbm(p * vec2(1.6, 2.4) + 6.0) < damp * 0.27 - up_roof * 0.1) {
		s = gsurf(R_GREEN, 0.26 + id * 0.12);
	}
	// Fallen leaves, caught on it in autumn.
	GroundCell lf = gcell(p * 5.0 + 9.0);
	if (lf.d1 < 0.3 && lf.id < e.autumn * 0.3) {
		s = gsurf(R_LEAF, 0.4 + lf.id * 1.2);
	}
	s = house_weather(s, p, t, e, 1.0, 9.0);
	ltexel = t;
	vec3 c = house_color(s, t);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/buildings/house/house_light.gdshaderinc"
