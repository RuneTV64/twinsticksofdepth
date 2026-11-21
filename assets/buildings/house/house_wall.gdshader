shader_type spatial;
// A house wall: painted clapboard outside, plaster inside, on one mesh. The side whose normal points along
// `outward` (and the wall's ends) is the outside; the other side is the room. An inside wall (`inside_wall`)
// is plaster on both sides.
//
//   outside   clapboards three texels deep with a shadow under each lap, butt joints, a stone footing
//   inside    plaster with a skirting board
//   weather   wet streaks, a bleached summer, algae creeping up from the footing in the damp seasons, frost,
//             snow in flecks and drifted against the foot (the room only gets the damp, through a worn wall)
//   wear      0 sound paint; 1 paint peeling to bare silvered wood, cracks in the plaster; 2 boards missing,
//             plaster fallen from the lath, damp and mould
#include "res://assets/buildings/house/house_lib.gdshaderinc"

uniform vec3 outward = vec3(0.0, 0.0, 1.0);
uniform bool inside_wall = false;
uniform int paint : hint_range(0, 2) = 0;      // H_PAINT cream, H_SAGE, H_SLATE
uniform float ground_y = 0.0;                  // the height of the ground this storey's wall stands on
uniform bool masonry = false;                  // a basement wall: concrete block, both sides
uniform bool footing = true;                   // a ground-floor wall has a stone footing; upper storeys don't

varying vec3 wp;
varying vec3 wn;
varying vec2 ltexel;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

Surf siding(vec2 p, vec2 t, float y, GroundEnv e) {
	float w = wear * 0.5;
	if (footing && y < 0.3) {
		// The footing: coursed stone.
		float row = floor(t.y / 2.0);
		float joint = mod(t.x + row * 5.0, 9.0) < 1.0 || mod(t.y, 2.0) < 0.0 ? 1.0 : 0.0;
		Surf f = gsurf(R_STONE, 0.5 + (gh1(vec2(floor((t.x + row * 5.0) / 9.0), row)) - 0.5) * 0.2 - joint * 0.25);
		float damp = e.spring * 0.6 + e.autumn * 0.8 + e.wet * 0.5 + w * 0.5;
		if (gfbm(p * vec2(1.8, 6.0)) < damp * 0.42) {
			f = gsurf(R_GREEN, 0.3);
		}
		return f;
	}
	float row = floor(t.y / 3.0);
	float in_row = mod(t.y, 3.0);
	float seg = floor((t.x + gh1(vec2(row, 7.0)) * 40.0) / 38.0);
	float joint = mod(t.x + gh1(vec2(row, 7.0)) * 40.0, 38.0) < 1.0 ? 1.0 : 0.0;
	float board = gh1(vec2(seg, row));
	Surf s = surf(paint, 0.64 + (board - 0.5) * 0.12);
	// Paint peels off in patches, along the grain, to bare wood.
	float peel = gfbm(p * vec2(1.3, 5.0) + board * 9.0);
	if (peel < w * 0.62 - 0.04) {
		s = house_wood(p, 0.5 + (board - 0.5) * 0.15);
	}
	// A board gone: the dark of the wall behind it.
	if (board < (wear - 1.0) * 0.16) {
		s = surf(H_WOOD, 0.08 + in_row * 0.03);
	} else {
		s.v -= in_row < 1.0 ? 0.24 : 0.0;       // the shadow under the lap
		s.v += in_row > 1.5 ? 0.05 : 0.0;       // light on its top edge
		s.v -= joint * 0.14;
	}
	// Algae: up from the footing in the damp seasons, further on a worn wall.
	float damp = e.spring * 0.5 + e.autumn * 0.7 + e.wet * 0.4 + w * 0.6;
	if (y < 0.3 + damp * 0.5 && gfbm(p * vec2(2.2, 4.0) + 2.0) < damp * 0.3 - (y - 0.3) * 0.5) {
		s = gsurf(R_GREEN, 0.28 + in_row * 0.04);
	}
	return s;
}

// A basement wall: courses of concrete block, damp at the foot, crumbling as it wears.
Surf blockwork(vec2 p, vec2 t, float y, GroundEnv e) {
	float w = wear * 0.5;
	float row = floor(t.y / 3.0);
	float shift = mod(row, 2.0) * 3.0;
	float block = floor((t.x + shift) / 6.0);
	float id = gh1(vec2(block, row));
	Surf s = gsurf(R_STONE, 0.6 + (id - 0.5) * 0.14 + (gnoise(p * 9.0) - 0.5) * 0.06);
	if (mod(t.y, 3.0) < 1.0 || mod(t.x + shift, 6.0) < 1.0) {
		s.v -= 0.2;                                 // the mortar joints
	}
	// The ground's damp comes through: a tide mark up from the floor, higher in the wet, and salts above it.
	float damp = 0.25 + e.wet * 0.35 + e.spring * 0.15 + w * 0.5;
	float tide = damp * (0.5 + gnoise(vec2(p.x * 1.3, 4.0)));
	if (y < tide) {
		s.v -= 0.16;
		if (gfbm(p * vec2(2.0, 5.0) + 3.0) < damp * 0.35) {
			s = gsurf(R_GREEN, 0.2);
		}
	} else if (y < tide + 0.2 && gh1(t * 0.83) < 0.35) {
		s.v += 0.16;
	}
	// Cracks down through the joints, then blocks spalled away.
	GroundCell c = gcell(p * 1.3 + 9.0);
	if (c.d2 - c.d1 < 0.05 && gnoise(p * 0.7 + 2.0) < w * 0.9) {
		s.v -= 0.3;
	}
	if (id < (wear - 1.0) * 0.18) {
		s = gsurf(R_STONE, 0.22 + gnoise(p * 14.0) * 0.12);
	}
	return s;
}

Surf plaster(vec2 p, vec2 t, float y, GroundEnv e) {
	float w = wear * 0.5;
	if (y < 0.13) {
		return surf(H_TRIM, mod(t.y, 2.0) < 1.0 ? 0.62 : 0.78);     // the skirting board
	}
	Surf s = surf(H_PLASTER, 0.76 + (gfbm(p * 1.6) - 0.5) * 0.08);
	// Fallen away from the lath.
	if (gfbm(p * 1.1 + 11.0) < (wear - 0.7) * 0.34) {
		return mod(t.y, 3.0) < 1.0 ? surf(H_WOOD, 0.1) : house_wood(p, 0.42);
	}
	// Cracks.
	GroundCell c = gcell(p * 1.7 + 3.0);
	if (c.d2 - c.d1 < 0.05 && gnoise(p * 0.8 + 5.0) < w * 0.95) {
		s.v -= 0.3;
	}
	// Damp comes through a worn wall: stains down from the top, and mould in the cold seasons.
	float damp = w * (0.4 + e.wet * 0.6 + e.autumn * 0.3 + e.winter * 0.3);
	s.v -= damp * 0.2 * smoothstep(0.35, 0.75, gfbm(vec2(p.x * 1.5, p.y * 0.5) + 8.0));
	if (gh1(t * 0.77) < damp * 0.2 * smoothstep(0.5, 0.7, gfbm(p * 0.9 + 1.0))) {
		s = gsurf(R_GREEN, 0.12);
	}
	return s;
}

void fragment() {
	if (cutaway_hidden(wp, FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(wn);
	GroundEnv e = house_env();
	vec2 uv = house_wall_uv(wp, n);
	bool top = n.y > 0.5;
	if (top) {
		uv = wp.xz;
	}
	vec2 t = house_texel(uv);
	vec2 p = house_point(t);
	float y = wp.y - ground_y;
	Surf s;
	if (masonry) {
		s = blockwork(p, t, y, e);
	} else if (top) {
		// The top of a wall or a sill: trim, with the weather lying on it.
		s = house_weather(surf(H_TRIM, 0.7 - wear * 0.08), p, t, e, 1.0, y);
	} else if (inside_wall || dot(n, outward) < -0.3) {
		s = plaster(p, t, y, e);
	} else {
		s = house_weather(siding(p, t, y, e), p, t, e, 0.0, footing ? y : 9.0);
	}
	ltexel = t;
	vec3 c = house_color(s, t);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/buildings/house/house_light.gdshaderinc"
