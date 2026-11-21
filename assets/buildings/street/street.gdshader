shader_type spatial;
// A street, drawn on flat 9 m tiles: a 6 m carriageway with a kerb and a 1.5 m sidewalk each side. One shader
// draws every tile; `links` says which of the tile's four sides the street carries on through, and the shape
// follows: a straight, a bend, a T, a crossroads, a dead end with a rounded head. Tiles meet without a seam.
//
//   carriageway  asphalt with its aggregate showing, darker where the wheels ran, a dashed yellow centre line;
//                at a junction a white crossing and stop line on every arm; a manhole here and there, a drain
//                grate in the gutter
//   kerb         a concrete edge, lit on top, in shadow on its face
//   sidewalk     concrete slabs 1.5 m square, rounded off at corners
//   weather      wet asphalt goes nearly black and water stands in the gutters and the potholes (ice in a frost,
//                rain rings in rain); a dry summer bleaches it; autumn's leaves gather along the kerbs; hoar
//                frost; lying snow, and footprints in it
//   wear         0 sound; 1 cracked, the cracks sealed with tar, paint fading, weeds starting in the joints;
//                2 crazed all over, potholes down to the stone bed, paint nearly gone, weeds in every crack
//                (green in the growing seasons, dead straw after)
//   holes        a square metre broken up with a sledgehammer is cut out (ragged), and the bed under it shows
//
// The texels are the world's own, 16 to the metre and square to the street (as a house's floor is), so kerbs
// and paint run true. Noise, dither, the season and the weather come from the ground's library.
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/ground/dirt_modules.gdshaderinc"
#include "res://assets/buildings/street/street_ramps.gdshaderinc"
#include "res://cutaway.gdshaderinc"

uniform float wear : hint_range(0.0, 2.0) = 0.0;
uniform vec4 season_override = vec4(-1.0, 0.0, 0.0, 0.0);   // x < 0: follow the world's season
uniform int links = 5;                 // which sides it carries on through: 1 north (-z), 2 east (+x), 4 south, 8 west
uniform ivec3 holes = ivec3(0);        // the square metres broken up: bit (x + z * 9) of 81, 27 to a number
// Footprints in lying snow: the ground's own tracks map (ground.gd).
uniform sampler2D track_map : filter_nearest, repeat_disable;
uniform vec4 track_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool has_tracks = false;

const float HALF_ROAD = 3.0;
const float KERB = 0.125;
const float WALK = 1.5;
const float FILLET = 1.5;

varying vec3 wp;
varying vec3 lp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
}

bool lk(int bit) {
	return (links & bit) != 0;
}

float sd_box(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// How far a spot (x east, y south, from the tile's middle) is from the carriageway's edge: under 0 on the
// carriageway. (StreetKit.edge() in street_kit.gd is the same sum: keep them in step.)
float street_d(vec2 q) {
	float d = length(q) - HALF_ROAD;                 // the middle: a round head for a dead end, the outside of a bend
	if (lk(1)) {
		d = min(d, sd_box(q, vec2(0.0, -2.5), vec2(HALF_ROAD, 2.5)));
	}
	if (lk(4)) {
		d = min(d, sd_box(q, vec2(0.0, 2.5), vec2(HALF_ROAD, 2.5)));
	}
	if (lk(2)) {
		d = min(d, sd_box(q, vec2(2.5, 0.0), vec2(2.5, HALF_ROAD)));
	}
	if (lk(8)) {
		d = min(d, sd_box(q, vec2(-2.5, 0.0), vec2(2.5, HALF_ROAD)));
	}
	// Where two arms meet at a corner, the sidewalk's corner is rounded off.
	vec2 s = sign(q);
	bool ax = s.x > 0.0 ? lk(2) : lk(8);
	bool az = s.y > 0.0 ? lk(4) : lk(1);
	if (ax && az && abs(q.x) > HALF_ROAD && abs(q.y) > HALF_ROAD) {
		d = min(d, FILLET - length(abs(q) - vec2(HALF_ROAD + FILLET)));
	}
	return d;
}

vec3 street_color(Ground g, vec2 texel) {
	float f = (1.0 - clamp(g.v, 0.0, 1.0)) * 8.0 + (gbayer(texel) - 0.5) * 0.6;
	int ix = clamp(int(floor(f)), 0, 7);
	return g.ramp >= STREET_FIRST ? STREET_RAMPS[(g.ramp - STREET_FIRST) * 8 + ix] : GROUND_RAMPS[g.ramp * 8 + ix];
}

void fragment() {
	if (cutaway_hidden(wp, FRAGCOORD.xy)) {
		discard;
	}
	vec2 texel = floor(wp.xz * GROUND_TEXELS);
	vec2 p = (texel + 0.5) / GROUND_TEXELS;                     // this texel's middle, in the world
	vec2 mid = wp.xz - lp.xz;                                   // the tile's middle, in the world
	vec2 q = p - mid;                                           // ... and this texel from it
	float d = street_d(q);
	if (d >= WALK) {
		discard;                                                // beyond the sidewalk: the ground shows
	}
	// A square metre that has been broken up: cut out, with a ragged edge.
	vec2 qq = q + (vec2(gnoise(p * 2.3 + 1.0), gnoise(p * 2.3 + 17.0)) - 0.5) * 0.5;
	ivec2 cell = ivec2(clamp(floor(qq + 4.5), 0.0, 8.0));
	int bit = cell.x + cell.y * 9;
	int word = bit < 27 ? holes.x : (bit < 54 ? holes.y : holes.z);
	if (((word >> (bit % 27)) & 1) != 0) {
		discard;
	}
	GroundEnv e = ground_env(season_override.x < 0.0 ? ground_season : season_override);
	float w = wear * 0.5;
	// Things grow in what breaks open: green in the growing seasons, dead after.
	float grow = e.spring * 0.8 + e.summer * (1.0 - 0.6 * e.dry) + e.autumn * 0.45 + e.winter * 0.12;
	int weed = e.autumn + e.winter > 0.6 ? R_STRAW : R_GREEN;
	// Which arm of the tile this is on: `along` out from the middle, `lat` across (over 0: the lane coming in).
	bool ns = lk(1) || lk(4);
	bool ew = lk(2) || lk(8);
	int count = int(lk(1)) + int(lk(2)) + int(lk(4)) + int(lk(8));
	vec2 a = abs(q.x) > abs(q.y) ? vec2(sign(q.x), 0.0) : vec2(0.0, sign(q.y));
	if (ns && !ew) {
		a = vec2(0.0, q.y >= 0.0 ? 1.0 : -1.0);
	} else if (ew && !ns) {
		a = vec2(q.x >= 0.0 ? 1.0 : -1.0, 0.0);
	}
	bool on_arm = a.x > 0.5 ? lk(2) : (a.x < -0.5 ? lk(8) : (a.y > 0.5 ? lk(4) : lk(1)));
	float along = dot(q, a);
	float lat = dot(q, vec2(a.y, -a.x));
	float run = abs(a.x) > 0.5 ? p.x : p.y;                    // how far along the street, in the world
	bool through = count == 2 && (ns != ew);                    // a plain straight
	bool plain = ns != ew;                                      // a straight or a dead end: one line of travel

	Ground g;
	float low = 0.0;          // how low the spot lies: where water stands
	float gutter = 0.0;       // 0..1: against the kerb, where leaves and water gather
	bool sealed = false;      // paint and iron: nothing grows through
	if (d < 0.0) {
		// ---- the carriageway
		g.ramp = S_ASPHALT;
		g.v = 0.4 + 0.1 * w + (gfbm(p * 0.45 + 3.0) - 0.5) * 0.12;
		float agg = gh1(texel * 0.371 + 1.7);
		g.v += agg > 0.93 ? 0.14 : (agg < 0.07 ? -0.09 : 0.0);           // the stone in it
		gutter = smoothstep(-0.45, -0.06, d);
		if (on_arm || plain) {
			float wheel = min(abs(abs(lat) - 0.75), abs(abs(lat) - 2.25));
			g.v -= 0.035 * smoothstep(0.35, 0.1, wheel);                  // polished darker where the wheels ran
		}
		g.v -= 0.07 * gutter;
		low = max(dirt_low(p) * 0.74, gutter * (0.55 + 0.42 * gfbm(vec2(run * 0.35, 3.0 + sign(lat)))));
		// Cracks: long ones first, then crazing all over.
		GroundCell c1 = gcell(p * 1.3 + 2.0);
		bool crack = c1.d2 - c1.d1 < 0.035 && gnoise(p * 0.4 + 9.0) < w * 1.2 - 0.15;
		GroundCell c2 = gcell(p * 5.0 + 6.0);
		crack = crack || (c2.d2 - c2.d1 < 0.07 && gfbm(p * 0.6 + 1.0) < (w - 0.45) * 0.95);
		// Old cracks sealed with tar: black snakes.
		GroundCell c3 = gcell(p * 0.7 + 11.0);
		if (wear > 0.5 && c3.d2 - c3.d1 < 0.02 && gnoise(p * 0.3 + 21.0) < 0.42) {
			g.v = 0.1;
		}
		if (crack) {
			if (gh1(texel * 0.53 + 1.0) < grow * (0.2 + 0.55 * w)) {
				g.ramp = weed;
				g.v = 0.42 + 0.3 * gh1(texel * 0.91);
			} else {
				g.v -= 0.26;
			}
		}
		// ---- paint
		float worn = gfbm(p * 5.0 + 3.0) + gh1(texel * 0.77) * 0.3;      // where it has worn off
		bool keeps = worn > w * 0.56 + 0.1;
		bool arm_out = on_arm && along > HALF_ROAD;
		// The centre line: all along a straight, up to the head of a dead end, and on the arms of a bend.
		if (abs(lat) < 0.0626 && mod(floor(run * GROUND_TEXELS), 72.0) < 32.0
				&& (plain ? (through || on_arm) : (count == 2 && arm_out))) {
			if (keeps) {
				g.ramp = S_YELLOW;
				g.v = 0.7;
				sealed = true;
			}
		}
		if (count >= 3 && arm_out) {
			// A crossing over the mouth of each arm, and a stop line for what comes in.
			bool zebra = along > 3.1 && along < 4.0 && abs(lat) < 2.85 && mod(floor((lat + 3.0) * GROUND_TEXELS), 12.0) < 6.0;
			bool stop = along > 4.2 && along < 4.45 && lat > 0.07 && lat < 2.85;
			if ((zebra || stop) && keeps) {
				g.ramp = S_WHITE;
				g.v = 0.72;
				sealed = true;
			}
		}
		// ---- iron: a manhole on some straights, a drain in the gutter of every one
		if (through) {
			float id = gh1(mid * 0.137 + 4.0);
			vec2 mh = q - (ns ? vec2(id < 0.5 ? -1.5 : 1.5, (id - 0.5) * 5.0) : vec2((id - 0.5) * 5.0, id < 0.5 ? -1.5 : 1.5));
			float mr = length(mh);
			if (fract(id * 7.0) < 0.5 && mr < 0.44) {
				g.ramp = S_IRON;
				g.v = mr > 0.36 ? 0.3 : (0.5 + 0.12 * (mod(floor(mh.x * 16.0) + floor(mh.y * 16.0), 2.0) - 0.5));
				sealed = true;
				low = 0.0;
			}
			if (d > -0.4 && d < -0.03 && mod(run + 2.0, 9.0) < 0.75) {
				g.ramp = S_IRON;
				g.v = mod(floor(run * GROUND_TEXELS), 2.0) < 1.0 ? 0.08 : 0.45;       // the slots
				sealed = true;
				low = 0.0;
			}
		}
		// ---- potholes: through the asphalt to the stone bed
		float ph = gfbm(p * 0.8 + 5.0) + (gnoise(p * 3.0) - 0.5) * 0.15;
		float hole_at = (w - 0.3) * 0.4;
		if (!sealed && ph < hole_at) {
			g.ramp = gh1(texel * 0.29 + 3.0) > 0.8 ? R_STONE : R_ROAD;    // packed grit, a stone here and there
			g.v = 0.26 + 0.2 * gnoise(p * 9.0);
			low = 1.0;
		} else if (!sealed && ph < hole_at + 0.035) {
			g.v -= 0.26;                                                  // its broken lip
		}
	} else if (d < KERB) {
		// ---- the kerb: lit on top, its face in shadow
		g.ramp = S_CONCRETE;
		g.v = d < 0.0625 ? 0.46 : 0.74;
		if (mod(floor(run * GROUND_TEXELS), 24.0) < 1.0) {
			g.v -= 0.16;
		}
		if (gh1(floor(vec2(run * 0.67, 5.0)) + 2.0) < w * 0.35) {
			g.v -= 0.2;                                                   // a length of it broken
		}
	} else {
		// ---- the sidewalk: slabs
		g.ramp = S_CONCRETE;
		vec2 slab = floor(texel / 24.0);
		float id = gh1(slab + 7.3);
		g.v = 0.56 + (id - 0.5) * 0.08 + (gnoise(p * 9.0) - 0.5) * 0.05;
		bool joint = mod(texel.x, 24.0) < 1.0 || mod(texel.y, 24.0) < 1.0;
		GroundCell c = gcell(p * 1.6 + 4.0);
		bool crack = c.d2 - c.d1 < 0.04 && gnoise(p * 0.5 + 6.0) < w * 1.1 - 0.1;
		if (id < w * 0.3) {
			g.v -= 0.07;                                                  // a slab that has sunk
		}
		gutter = 0.5 * smoothstep(WALK - 0.4, WALK, d);                   // leaves blow up against the far edge
		low = dirt_low(p) * 0.7 + (id < w * 0.3 ? 0.12 : 0.0);
		if (joint || crack) {
			if (gh1(texel * 0.53 + 1.0) < grow * (0.1 + 0.6 * w)) {
				g.ramp = weed;
				g.v = 0.42 + 0.3 * gh1(texel * 0.91);
			} else {
				g.v -= crack ? 0.26 : 0.18;
			}
		}
	}
	// ---- the weather
	bool stone = g.ramp >= STREET_FIRST || g.ramp == R_STONE;
	if (stone) {
		g.v -= e.wet * (g.ramp == S_ASPHALT ? 0.26 : 0.13);              // wet asphalt is nearly black
		g.v += e.dry * 0.05;
		if (e.wet > 0.35 && gh1(texel * 0.913 + 2.7) > 0.991 - 0.012 * e.wet) {
			g.v += 0.4;                                                   // a glint
		}
		dirt_leaves(p, e.autumn * (0.14 + 0.8 * gutter), g);
	}
	float water = dirt_puddles(p, texel, max(smoothstep(0.3, 1.0, e.wet), 0.4 * e.frost), low, e.frost,
		smoothstep(0.8, 1.0, e.wet) * (1.0 - step(0.5, e.frost)), g.ramp, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, 0.55, g);
	}
	float snowed = dirt_snow(p, texel, e.snow, low, g);
	if (snowed > 0.5 && has_tracks) {
		float track = texture(track_map, (wp.xz - track_rect.xy) / track_rect.zw).r;
		if (track > 0.01) {
			g.ramp = R_ICE;                                               // trodden snow: packed, blue-grey
			g.v = 0.42 - 0.22 * track;
		}
	}
	vec3 c = street_color(g, texel);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/ground/ground_light.gdshaderinc"
