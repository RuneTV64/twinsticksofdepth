shader_type spatial;
// What stands along a street: a lamp post, its lantern, a sign's post and its plate. Each is a plain box; this
// shader draws the thing on it, texel by texel on the box's own faces (16 to the metre), and cuts away what
// isn't there (a stop sign's corners, a warning sign's diamond).
//
//   part 0  a post: galvanised steel, grimy at the foot
//   part 1  a lantern: a steel frame and cap round four panes of glass, glowing when it is lit
//   part 2  a sign's plate: `face` 0 a stop sign, 1 a street name's blade, 2 a warning diamond; its back is
//           bare steel
//
//   weather  wet darkens it; hoar frost; snow sits on every cap and top edge
//   wear     0 sound; 1 rust starting at the foot and the joints, paint fading; 2 rusted through in patches,
//            the sign shot up, the lantern's glass broken and dark
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/buildings/street/street_ramps.gdshaderinc"
#include "res://cutaway.gdshaderinc"

uniform int part : hint_range(0, 2) = 0;
uniform int face : hint_range(0, 2) = 0;
uniform bool lit = false;
uniform vec3 size = vec3(0.19, 3.5, 0.19);      // the box (m)
uniform bool along_x = true;                    // a plate's width runs along X (else Z)
uniform float front = 1.0;                      // which side of a plate is its face (+1: south or east)
uniform float ground_y = 0.0;
uniform float wear : hint_range(0.0, 2.0) = 0.0;
uniform vec4 season_override = vec4(-1.0, 0.0, 0.0, 0.0);

varying vec3 wp;
varying vec3 lp;
varying vec3 ln;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
	ln = NORMAL;
}

vec3 prop_color(Ground g, vec2 texel) {
	float f = (1.0 - clamp(g.v, 0.0, 1.0)) * 8.0 + (gbayer(texel) - 0.5) * 0.6;
	int ix = clamp(int(floor(f)), 0, 7);
	return g.ramp >= STREET_FIRST ? STREET_RAMPS[(g.ramp - STREET_FIRST) * 8 + ix] : GROUND_RAMPS[g.ramp * 8 + ix];
}

void fragment() {
	if (cutaway_hidden(wp, FRAGCOORD.xy)) {
		discard;
	}
	GroundEnv e = ground_env(season_override.x < 0.0 ? ground_season : season_override);
	float w = wear * 0.5;
	vec3 n = normalize(ln);
	bool top = n.y > 0.5;
	// This face's own texels: across it and up it, from its bottom left.
	bool xface = abs(n.x) > 0.5;                                // a face looking along X: its width is the box's Z
	float across = top ? lp.x + size.x * 0.5 : (xface ? lp.z + size.z * 0.5 : lp.x + size.x * 0.5);
	float wide = xface && !top ? size.z : size.x;
	float tu = clamp(floor(across * GROUND_TEXELS + 0.001), 0.0, floor(wide * GROUND_TEXELS + 0.5) - 1.0);
	float tv = top ? floor((lp.z + size.z * 0.5) * GROUND_TEXELS + 0.001) : floor((lp.y + size.y * 0.5) * GROUND_TEXELS + 0.001);
	float tw = floor(wide * GROUND_TEXELS + 0.5);
	float th = floor(size.y * GROUND_TEXELS + 0.5);
	vec2 texel = vec2(tu + floor(wp.x * 3.0) * 7.0, tv + floor(wp.z * 3.0) * 5.0);       // (its own, for dither and noise)
	vec2 p = (vec2(tu, tv) + 0.5) / GROUND_TEXELS + wp.xz * 0.37;
	float y = wp.y - ground_y;
	Ground g;
	g.ramp = S_STEEL;
	g.v = 0.62;
	bool glow = false;
	bool cap = top;                                             // snow sits here
	if (part == 0) {
		// ---- a post
		g.v = 0.6 + (gnoise(vec2(tu * 0.7, y * 3.0)) - 0.5) * 0.08 - (tu < 1.0 ? 0.0 : 0.06);
		if (y < 0.3) {
			g.v -= 0.14;                                        // its foot: a collar, and the dirt of the street
		}
		// Rust: up from the foot, down from the top, in streaks.
		float rust = gfbm(vec2(p.x * 6.0, y * 0.9) + 3.0);
		if (rust < w * 0.75 - 0.08 + 0.25 * w * smoothstep(1.2, 0.0, y)) {
			g.ramp = S_IRON;
			g.v = 0.45 + 0.25 * gnoise(p * 9.0);
		}
	} else if (part == 1) {
		// ---- a lantern: frame, cap and glass
		bool frame = top || tu < 1.0 || tu >= tw - 1.0 || tv < 1.0 || tv >= th - 2.0;
		if (frame) {
			g.v = top ? 0.36 : (tv >= th - 2.0 ? 0.42 : 0.3);
			cap = cap || tv >= th - 1.0;
		} else {
			bool broken = gh1(vec2(tu, tv) * 1.7 + floor(wp.xz * 2.0)) < max(w - 0.5, 0.0) * 1.4;
			if (broken) {
				discard;                                        // the glass has gone: you see through the frame
			}
			if (lit && wear < 1.5) {
				g.ramp = S_GLOW;
				g.v = 0.96 - 0.1 * abs(tu - (tw - 1.0) * 0.5) - 0.06 * abs(tv - (th - 2.0) * 0.5);
				glow = true;
			} else {
				g.ramp = S_IRON;
				g.v = 0.22 + (gh1(vec2(tu, tv) + 3.0) > 0.85 ? 0.3 : 0.0);      // dark glass, a glint
			}
		}
	} else {
		// ---- a sign's plate
		bool is_front = !top && (along_x ? n.z * front > 0.5 : n.x * front > 0.5);
		bool edge = !top && !is_front && (along_x ? abs(n.z) < 0.5 : abs(n.x) < 0.5);
		float mu = min(tu, tw - 1.0 - tu);                      // texels in from the nearer side
		float mv = min(tv, th - 1.0 - tv);
		if (!top && !edge) {
			if (face == 0 && mu + mv < 3.0) {
				discard;                                        // a stop sign's eight sides
			}
			if (face == 2 && abs(tu - (tw - 1.0) * 0.5) + abs(tv - (th - 1.0) * 0.5) > tw * 0.5) {
				discard;                                        // a warning sign's diamond
			}
			// Shot up: holes through it.
			if (gh1(vec2(tu, tv) * 0.71 + floor(wp.xz * 2.0) + 5.0) < max(w - 0.5, 0.0) * 0.1) {
				discard;
			}
		}
		g.v = 0.6;
		if (is_front) {
			float fade = w * 0.16;
			if (face == 0) {
				g.ramp = S_RED;
				g.v = 0.62 + fade;
				bool rim = mu < 1.0 || mv < 1.0 || mu + mv < 4.0;
				bool word = tv >= floor(th * 0.5) - 1.0 && tv <= floor(th * 0.5) && mu >= 2.0 && mod(tu - 2.0, 3.0) < 2.0;
				if (rim || word) {
					g.ramp = S_WHITE;
					g.v = 0.8;
				}
			} else if (face == 1) {
				g.ramp = S_SIGN;
				g.v = 0.56 + fade;
				if (tv == 1.0 && mu >= 1.0 && mod(tu, 4.0) < 3.0) {
					g.ramp = S_WHITE;                           // the name, as it reads from across a street
					g.v = 0.82;
				}
			} else {
				float dd = abs(tu - (tw - 1.0) * 0.5) + abs(tv - (th - 1.0) * 0.5);
				g.ramp = S_YELLOW;
				g.v = 0.72 + fade;
				bool rim = dd > tw * 0.5 - 1.5;
				bool mark = abs(tu - (tw - 1.0) * 0.5) < 1.0 && tv >= 3.0 && tv <= 7.0 || (tv >= 7.0 && tv <= 8.0 && abs(tu - (tw - 1.0) * 0.5) < 3.0);
				if (rim || mark) {
					g.ramp = S_IRON;                            // black: its border, and a road that ends
					g.v = 0.1;
				}
			}
			cap = tv >= th - 1.0;
		}
		// Rust eats in from the edges and the bolt holes.
		if (gfbm(p * 7.0 + 9.0) < w * 0.7 - 0.12 + 0.12 * w * step(mu + mv, 3.0)) {
			g.ramp = S_IRON;
			g.v = 0.42 + 0.25 * gnoise(p * 11.0);
		}
	}
	// ---- the weather
	if (!glow) {
		g.v -= e.wet * 0.09;
		g.v += e.dry * 0.03;
		if (gh1(texel * 1.37 + 3.1) < e.frost * (top ? 0.3 : 0.12)) {
			g.ramp = R_ICE;
			g.v = 0.86;
		}
	}
	if (cap && e.snow > 0.12 && gh1(vec2(tu, floor(wp.x + wp.z)) * 0.77 + 1.0) < e.snow * 2.4) {
		g.ramp = R_SNOW;
		g.v = 0.9;
		glow = false;
	}
	vec3 c = prop_color(g, texel);
	ALBEDO=pow(c,vec3(2.2));
	if (glow) {
		EMISSION=pow(c,vec3(2.2)) * 1.6;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/ground/ground_light.gdshaderinc"
