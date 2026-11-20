// The kinds of grass that grow as part of the ground's own surface: what you see lying flat between and under
// the standing blades (grass_blades.gdshader). Painted on the ground's map like the dirts (ground.gd).
//
//   8 lawn     short grass, close and even: a yard, a verge, grazed ground; daisies in spring
//   9 meadow   long grass: flowers in spring and summer, seed heads later, straw by autumn
//   10 rough   tussocks and weeds with bare earth between: waste ground, the edge of a field
//
// Grass is drawn as blades: each texel column is cut into strokes a few texels long, every stroke its own shade,
// lighter at its tip (up the screen) and darker at its foot. Whether a stroke is green or straw goes by the
// season: green in spring, yellowing in a dry summer and through autumn, dead straw in winter.
const int GRASS_FIRST = 8;
const int GRASS_LAWN = 8;
const int GRASS_MEADOW = 9;
const int GRASS_ROUGH = 10;

// How much of the grass has gone to straw, 0 none .. 1 all.
float grass_straw(GroundEnv e, float bias) {
	return clamp(0.8 * e.dry + 0.2 * e.summer + 0.55 * e.autumn + 0.95 * e.winter - 0.15 * e.wet + bias, 0.0, 1.0);
}

// Small flowers scattered in the grass: white ones and yellow ones.
void grass_flowers(vec2 p, float amount, inout Ground g) {
	if (amount <= 0.01) {
		return;
	}
	GroundCell f = gcell(p * 2.4 + 77.0);
	if (f.id < amount * 0.34 && f.d1 < 0.2) {
		bool yellow = fract(f.id * 9.7) > 0.55;
		if (f.d1 < 0.07) {
			g.ramp = R_LEAF;                 // the eye of the flower
			g.v = 0.95;
		} else {
			g.ramp = yellow ? R_LEAF : R_SNOW;
			g.v = yellow ? 0.9 : 0.97;
		}
	}
}

// `len` texels to a blade; `cover` 0..1 how much of the ground the grass hides; `tuft` 0 even .. 1 in tussocks;
// `straw_bias` how much more of it is straw than the season alone would make.
Ground grass_turf(vec2 p, vec2 texel, GroundEnv e, float len, float cover, float tuft, float straw_bias, float flowers) {
	// Bare patches show the soil.
	float thin = gfbm(p * 0.75 + 13.0) * 0.65 + gnoise(p * 3.1 + 4.0) * 0.35;
	GroundCell t = gcell(p * 1.7 + 19.0);                    // tussocks
	float dome = smoothstep(0.75, 0.1, t.d1);
	if (thin + (1.0 - dome) * tuft * 0.45 > cover + 0.12) {
		return dirt_soil(p, texel, e);
	}
	Ground g;
	// The blade this texel is part of.
	float off = floor(gh1(vec2(texel.x * 0.619 + 0.37, texel.x * 0.283 + 91.7)) * len);
	float row = floor((texel.y + off) / len);
	float along = mod(texel.y + off, len);                   // 0 at the tip (up the screen) .. len - 1 at the foot
	float rnd = gh1(vec2(texel.x * 0.731 + 0.13, row * 1.37 + 0.71));
	float straw = grass_straw(e, straw_bias);
	bool dead = fract(rnd * 7.3) < straw;
	g.ramp = dead ? R_STRAW : R_GREEN;
	g.v = 0.32 + 0.26 * rnd + 0.2 * (gfbm(p * 0.6 + 2.0) - 0.5);
	g.v += along < 0.5 ? 0.2 : 0.0;                          // the tip catches the light
	g.v -= along > len - 1.5 ? 0.16 : 0.0;                   // the foot is in shade
	// Tussocks: each a little dome, lit on the sunny side, dark round its foot.
	float side = -dot(t.to / max(t.d1, 0.001), DIRT_SUN);
	g.v += tuft * (0.14 * side * (1.0 - dome) + 0.08 * dome - 0.18 * smoothstep(0.12, 0.0, t.d2 - t.d1));
	g.v += 0.05 * e.spring - 0.1 * e.winter;                 // new growth is bright; dead winter grass is dull
	g.v -= dead ? 0.06 : 0.0;
	dirt_wet(p, texel, 0.45 * e.wet, g);
	// Seed heads on the long grass from high summer: pale tips.
	if (len > 4.5 && along < 0.5 && fract(rnd * 13.1) < 0.35 * (e.summer + e.autumn)) {
		g.ramp = R_STRAW;
		g.v = 0.85;
	}
	grass_flowers(p, flowers * (e.spring + 0.5 * e.summer), g);
	dirt_leaves(p, 0.7 * e.autumn, g);
	// Frost whitens the tips; snow lies on it, the long grass poking through at first.
	dirt_frost(p, texel, e.frost, along < 0.5 ? 0.62 + 0.3 * rnd : 0.25, g);
	float low = dirt_low(p);
	float water = dirt_puddles(p, texel, 0.55 * _dirt_water(e), low, e.frost, _dirt_rain(e), R_MUD, g);
	if (water < 0.5 && !(len > 4.5 && along < 0.5 && rnd > 0.55 + 0.6 * e.snow)) {
		dirt_snow(p, texel, e.snow, low, g);
	}
	return g;
}

Ground grass_pick(int kind, vec2 p, vec2 texel, GroundEnv e) {
	if (kind == GRASS_MEADOW) {
		return grass_turf(p, texel, e, 6.0, 1.0, 0.35, 0.0, 1.0);
	}
	if (kind == GRASS_ROUGH) {
		return grass_turf(p, texel, e, 5.0, 0.62, 1.0, 0.25, 0.25);
	}
	return grass_turf(p, texel, e, 3.0, 0.95, 0.0, -0.1, 0.5);
}
