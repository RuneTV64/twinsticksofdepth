// The kinds of dirt. Each is a choice of the pieces in dirt_modules.gdshaderinc, in an order, tuned by the season.
// Add a kind by writing one more function like these and giving it a number in dirt_pick().
//
//   0 soil   ordinary ground: clods, a few stones; sprouts in spring, leaves in autumn
//   1 farm   a ploughed field: rows; seedlings in spring, stubble in autumn, snow lying in the troughs
//   2 road   a dirt road: ruts, a crown, loose stones at the edges; the ruts hold the water and the ice
//   3 clay   bare clay: cracked when dry or frozen, slick when wet
//   4 mud    a wet place: dark, puddled; dries to cracked flats in a drought, freezes in ridges
//   5 bed    what lies under a street: packed stone and grit (it shows where the paving has been broken up)
#include "res://assets/ground/dirt_modules.gdshaderinc"

const int DIRT_SOIL = 0;
const int DIRT_FARM = 1;
const int DIRT_ROAD = 2;
const int DIRT_CLAY = 3;
const int DIRT_MUD = 4;
const int DIRT_BED = 5;

// How much water stands about for a wetness: nothing until it is properly wet, and in a frost there is always
// some ice in the low places.
float _dirt_water(GroundEnv e) {
	return max(smoothstep(0.3, 1.0, e.wet), 0.4 * e.frost);
}

float _dirt_rain(GroundEnv e) {
	return smoothstep(0.8, 1.0, e.wet) * (1.0 - step(0.5, e.frost));
}

Ground dirt_soil(vec2 p, vec2 texel, GroundEnv e) {
	Ground g;
	g.ramp = R_LOAM;
	float high = dirt_base(p, 2.7, 1.0, g);
	float low = dirt_low(p);
	g.v += 0.1 * e.dry - 0.03 * e.autumn;
	// Hard frost splits bare ground; a long drought cracks it a little.
	float crack = dirt_cracks(p, 0.14 * e.dry + 0.4 * e.frost, 1.2, e.frost, g);
	float stone = dirt_pebbles(p, 0.16, g);
	if (stone < 0.5 && crack < 0.5) {
		dirt_wet(p, texel, max(e.wet, max(0.3 * e.spring, 0.2 * e.autumn)), g);
		dirt_sprouts(p, 0.75 * e.spring + 0.2 * e.summer * (1.0 - e.dry), g);
		dirt_leaves(p, 0.85 * e.autumn, g);
	}
	float water = dirt_puddles(p, texel, _dirt_water(e), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, high, g);
	}
	dirt_snow(p, texel, e.snow, low, g);
	return g;
}

Ground dirt_farm(vec2 p, vec2 texel, vec2 dir, GroundEnv e) {
	Ground g;
	g.ramp = R_FARM;
	float period = 0.75;
	float high = dirt_base(p, 3.6, 1.0, g);
	float ridge = dirt_furrows(p, dir, period, g);
	float low = dirt_low(p) * 0.62 + (1.0 - ridge) * 0.36;   // the troughs are the low places, where the field itself dips
	g.v += 0.12 * e.dry * ridge;                             // the ridge tops dry out pale and crusted
	float crack = dirt_cracks(p, 0.3 * e.dry * ridge + 0.35 * e.frost, 2.2, e.frost, g);
	float stone = dirt_pebbles(p, 0.12, g);
	if (stone < 0.5 && crack < 0.5) {
		dirt_wet(p, texel, max(e.wet, max(0.35 * e.spring, 0.2 * e.autumn)) * (1.2 - 0.4 * ridge), g);
		dirt_seedlings(p, dir, period, 0.9 * e.spring, g);
		dirt_sprouts(p, 0.3 * e.summer, g);                  // weeds, once nobody is hoeing
		dirt_stubble(p, dir, period, e.autumn, g);
		dirt_leaves(p, 0.3 * e.autumn, g);
	}
	float water = dirt_puddles(p, texel, _dirt_water(e), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, 0.5 * high + 0.6 * ridge, g);
	}
	dirt_snow(p, texel, e.snow, low, g);
	return g;
}

// `lat` metres from the road's middle (signed), `half` its half width.
Ground dirt_road(vec2 p, vec2 texel, vec2 dir, float lat, float half, GroundEnv e) {
	Ground g;
	g.ramp = R_ROAD;
	float high = dirt_base(p, 4.2, 0.55, g);
	vec2 rt = dirt_ruts(p, dir, lat, half, g);
	float rut = rt.x;
	float edge = rt.y;
	g.v += 0.08 * e.dry;                                      // summer dust
	float crack = dirt_cracks(p, 0.5 * e.dry * rut + 0.4 * e.frost * (1.0 - rut), 2.4, e.frost, g);
	float stone = rut > 0.5 ? 0.0 : dirt_pebbles(p, 0.2 + 0.65 * edge, g);
	float wet = max(e.wet, max(0.25 * e.spring, 0.15 * e.autumn));
	if (stone < 0.5 && crack < 0.5) {
		if (rut > 0.5 && wet > 0.3) {
			g.ramp = R_MUD;                                   // churned to mud where the wheels go
			g.v += 0.12;
		}
		dirt_wet(p, texel, wet * (0.7 + 0.5 * rut), g);
		dirt_sprouts(p, (0.5 * e.spring + 0.2 * e.summer) * edge, g);
		dirt_leaves(p, e.autumn * (0.25 + 0.7 * max(edge, rut)), g);    // leaves blow into the ruts and the verges
	}
	// The ruts are the low places: they flood first, and they hold the ice.
	float low = max(dirt_low(p) * 0.8, rut * (0.5 + 0.62 * gfbm(vec2(dot(p, dir) * 0.45, lat * 0.3) + 11.0)));
	float water = dirt_puddles(p, texel, _dirt_water(e), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, 0.6 * high + 0.5 * (1.0 - rut), g);
	}
	dirt_snow(p, texel, e.snow, 1.0 - rut, g);                // snow lies on the crown and the verges; the ruts stay dark
	return g;
}

Ground dirt_clay(vec2 p, vec2 texel, GroundEnv e) {
	Ground g;
	g.ramp = R_CLAY;
	float high = dirt_base(p, 3.0, 0.3, g);
	float low = dirt_low(p);
	g.v += 0.1 * e.dry;
	float crack = dirt_cracks(p, clamp(0.3 + 0.7 * e.dry + 0.45 * e.frost - 0.7 * e.wet, 0.0, 1.0), 1.7, e.frost, g);
	float stone = dirt_pebbles(p, 0.1, g);
	if (stone < 0.5 && crack < 0.5) {
		dirt_wet(p, texel, max(e.wet, 0.2 * e.spring), g);
		dirt_sprouts(p, 0.3 * e.spring, g);
		dirt_leaves(p, 0.5 * e.autumn, g);
	}
	float water = dirt_puddles(p, texel, _dirt_water(e), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, high, g);
	}
	dirt_snow(p, texel, e.snow, low, g);
	return g;
}

Ground dirt_mud(vec2 p, vec2 texel, GroundEnv e) {
	Ground g;
	g.ramp = R_MUD;
	float high = dirt_base(p, 3.4, 0.55, g);
	float low = dirt_low(p);
	// Mud is wet unless the summer has dried it out or the frost has it.
	float wet = clamp(0.65 + 0.35 * e.wet - 0.8 * e.dry - 0.4 * e.frost, 0.0, 1.0);
	g.v += 0.22 * e.dry + 0.1;
	float crack = dirt_cracks(p, 0.85 * e.dry + 0.4 * e.frost, 1.9, e.frost, g);
	if (crack < 0.5) {
		dirt_wet(p, texel, wet, g);
		dirt_sprouts(p, 0.2 * e.spring, g);
		dirt_leaves(p, 0.5 * e.autumn, g);
	}
	float water = dirt_puddles(p, texel, max(_dirt_water(e), 0.45 * wet), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, high, g);
	}
	dirt_snow(p, texel, e.snow, low, g);
	return g;
}

// One kind by number. `dir` is the way rows or a road run (unit); `lat` and `half` are for the road.
Ground dirt_bed(vec2 p, vec2 texel, GroundEnv e) {
	Ground g;
	g.ramp = R_ROAD;
	float high = dirt_base(p, 5.0, 0.4, g);
	g.v -= 0.08;
	float low = dirt_low(p);
	float stone = dirt_pebbles(p, 0.95, g);
	if (stone < 0.5) {
		dirt_wet(p, texel, max(e.wet, 0.2 * e.spring), g);
		dirt_leaves(p, 0.5 * e.autumn, g);
	}
	float water = dirt_puddles(p, texel, _dirt_water(e), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5) {
		dirt_frost(p, texel, e.frost, high, g);
	}
	dirt_snow(p, texel, e.snow, low, g);
	return g;
}

Ground dirt_pick(int kind, vec2 p, vec2 texel, vec2 dir, float lat, float half, GroundEnv e) {
	if (kind == DIRT_BED) {
		return dirt_bed(p, texel, e);
	}
	if (kind == DIRT_FARM) {
		return dirt_farm(p, texel, dir, e);
	}
	if (kind == DIRT_ROAD) {
		return dirt_road(p, texel, dir, lat, half, e);
	}
	if (kind == DIRT_CLAY) {
		return dirt_clay(p, texel, e);
	}
	if (kind == DIRT_MUD) {
		return dirt_mud(p, texel, e);
	}
	return dirt_soil(p, texel, e);
}
