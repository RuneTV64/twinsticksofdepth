// The pieces dirt is made of. Each one takes a spot of ground (in metres, at a texel centre) and changes it.
// A kind of dirt (dirt_types.gdshaderinc) is just a choice of these in an order.
//
//   dirt_base      the earth itself: patches, clods with a lit side, the cracks between them
//   dirt_pebbles   stones lying in it, with their shadows
//   dirt_cracks    a crazed surface: dried clay, or ground split by frost
//   dirt_furrows   ploughed rows: ridges and troughs across a direction
//   dirt_ruts      a cart track: two ruts, a crown between, loose edges
//   dirt_wet       damp to soaked: darker, with glints
//   dirt_puddles   standing water in the low places (ice in a frost), with rain rings
//   dirt_leaves    fallen leaves
//   dirt_sprouts   small green things coming up
//   dirt_stubble   cut stalks in rows
//   dirt_frost     hoar frost on the high points
//   dirt_snow      lying snow, filling the low places first
//
// Everything here is in the ground's frame (ground_lib: x across the screen, y down it). DIRT_SUN is the way to
// the level's sun along the ground, in that frame: bumps are lit on that side.

const vec2 DIRT_SUN = vec2(-0.173, 0.985);

// How low this spot lies, 0 high .. 1 low: where water stands and snow gathers. The same everywhere it is asked.
float dirt_low(vec2 p) {
	return 1.0 - (gfbm(p * 0.55 + 7.3) * 0.8 + gnoise(p * 1.9 + 2.1) * 0.2);
}

// The earth itself. `lump` is the size of its clods (clods to the metre); `rough` 0 trodden smooth .. 1 broken up.
// Returns how high this spot stands in its clod (0 between clods .. 1 on top), for frost and snow.
float dirt_base(vec2 p, float lump, float rough, inout Ground g) {
	float patch = gfbm(p * 0.9 + 3.1);
	GroundCell c = gcell(p * lump);
	float top = smoothstep(0.62, 0.12, c.d1);
	float side = -dot(c.to / max(c.d1, 0.001), DIRT_SUN);          // +1 on the sunny side of the clod
	float gap = smoothstep(0.1, 0.0, c.d2 - c.d1);                 // the dark line between two clods
	g.v = 0.47 + 0.3 * (patch - 0.5) + (c.id - 0.5) * 0.12 * rough;
	g.v += rough * (0.16 * side * (1.0 - top) + 0.06 * top - 0.13 * gap);
	// Smaller lumps on the big ones, and fine crumbs.
	GroundCell c2 = gcell(p * lump * 2.3 + 7.0);
	g.v += rough * 0.09 * -dot(c2.to / max(c2.d1, 0.001), DIRT_SUN) * smoothstep(0.1, 0.5, c2.d1);
	g.v += (gnoise(p * 7.0) - 0.5) * 0.05 * rough;
	return top * (1.0 - gap);
}

// Stones. `amount` 0 none .. 1 a gravelly lot. Returns 1 on a stone.
float dirt_pebbles(vec2 p, float amount, inout Ground g) {
	GroundCell s = gcell(p * 2.2 + 31.7);
	float r = 0.1 + 0.24 * fract(s.id * 7.31) * fract(s.id * 3.17);
	if (s.id > 1.0 - 0.5 * amount) {
		float side = -dot(s.to / max(s.d1, 0.001), DIRT_SUN);
		if (s.d1 < r) {
			g.ramp = R_STONE;
			g.v = 0.4 + 0.3 * side * smoothstep(0.0, r, s.d1) + (fract(s.id * 13.7) - 0.5) * 0.2;
			return 1.0;
		}
		if (s.d1 < r * 1.6 && side < -0.2) {
			g.v -= 0.2;       // its shadow, on the side away from the sun
		}
	}
	return 0.0;
}

// A crazed surface. `amount` 0 whole .. 1 wide cracks; `plate` plates to the metre. `ice` 0..1 fills the cracks
// with frost (ground split by cold shows its cracks white). Returns 1 in a crack.
float dirt_cracks(vec2 p, float amount, float plate, float ice, inout Ground g) {
	if (amount <= 0.01) {
		return 0.0;
	}
	vec2 q = p + (vec2(gnoise(p * 1.7), gnoise(p * 1.7 + 9.0)) - 0.5) * 0.25;   // wander, so no straight edges
	GroundCell k = gcell(q * plate);
	float edge = k.d2 - k.d1;
	float width = 0.012 + 0.085 * amount;
	if (edge < width) {
		if (ice > 0.5 && gh1(floor(p * GROUND_TEXELS) * 0.37) < ice * 0.65) {
			g.ramp = R_ICE;
			g.v = 0.72;
		} else {
			g.v = 0.1;
		}
		return 1.0;
	}
	// Each plate: a little dished, its edges curled up and catching the light on the sunny side.
	float lip = smoothstep(width + 0.12, width, edge) * amount;
	float side = -dot(k.to / max(k.d1, 0.001), DIRT_SUN);
	g.v += lip * (0.14 * side - 0.03) + (k.id - 0.5) * 0.1 * amount;
	// Hairline cracks inside the plates once it is really dry.
	if (amount > 0.55) {
		GroundCell h = gcell(q * plate * 2.7 + 13.0);
		if (h.d2 - h.d1 < 0.03 * (amount - 0.4)) {
			g.v -= 0.22;
		}
	}
	return 0.0;
}

// Which row a spot is in, for rows running along `dir` (unit) `period` metres apart: whole numbers count the
// rows, the fraction is across one (0 and 1 in the troughs, 0.5 on the ridge). The rows wander a little.
float dirt_row(vec2 p, vec2 dir, float period) {
	vec2 across = vec2(-dir.y, dir.x);
	return dot(p, across) / period + (gnoise(vec2(dot(p, dir) * 0.35, dot(p, across) * 0.2)) - 0.5) * 0.28;
}

// Ploughed rows running along `dir`, `period` metres from ridge to ridge.
// Returns how high the spot is: 0 the bottom of a trough .. 1 a ridge top.
float dirt_furrows(vec2 p, vec2 dir, float period, inout Ground g) {
	vec2 across = vec2(-dir.y, dir.x);
	float ph = fract(dirt_row(p, dir, period));
	float ridge = 0.5 - 0.5 * cos(ph * 6.2832);
	float climb = sin(ph * 6.2832);                       // + going up toward the ridge along `across`
	float lit = -climb * dot(across, DIRT_SUN);           // the face that looks at the sun
	g.v += 0.2 * lit - 0.2 * (1.0 - ridge) * (1.0 - ridge) + 0.05 * ridge;
	return ridge;
}

// A cart track running along `dir`. `lat` metres from its middle (signed), `half` its half width.
// Returns x = 1 in a rut, y = 1 at the loose edge.
vec2 dirt_ruts(vec2 p, vec2 dir, float lat, float half, inout Ground g) {
	float along = dot(p, dir);
	float wob = (gnoise(vec2(along * 0.4, 3.0)) - 0.5) * 0.3;
	float track = min(half * 0.5, 0.78);                  // ruts this far either side of the middle
	float off = abs(abs(lat + wob) - track);
	float rut = smoothstep(0.3, 0.12, off);
	float wall = smoothstep(0.34, 0.2, off) - smoothstep(0.2, 0.08, off);   // the sloping sides of a rut
	float s = sign(abs(lat + wob) - track) * sign(lat + wob);               // which way the wall faces
	vec2 across = vec2(-dir.y, dir.x);
	float edge = smoothstep(half - 0.7, half, abs(lat));
	g.v -= 0.14 * rut;
	g.v += wall * 0.16 * s * dot(across, DIRT_SUN);
	// Pressed smooth in the ruts, with the faint marks of what went over it.
	g.v += rut * 0.05 * (step(0.5, fract(along * 2.2 + gh1(vec2(floor(along * 2.2), 1.0)))) - 0.5);
	// The crown between the ruts stands a little proud and paler.
	g.v += 0.05 * (1.0 - rut) * (1.0 - edge) * smoothstep(track, 0.0, abs(lat));
	return vec2(rut, edge);
}

// Damp to soaked: `wet` 0..1. Wet earth is darker, and it glints.
void dirt_wet(vec2 p, vec2 texel, float wet, inout Ground g) {
	g.v -= 0.2 * wet;
	if (wet > 0.35 && gh1(texel * 0.913 + 2.7) > 0.992 - 0.012 * wet) {
		g.v += 0.4;
	}
}

// Standing water where the ground lies low. `amount` 0 none .. 1 half under water; `low` from dirt_low() (a
// track's ruts and a field's troughs pass their own). `frozen` 0..1 turns it to ice. `rain` 0..1 puts rings on it.
// Returns 1 in the water.
float dirt_puddles(vec2 p, vec2 texel, float amount, float low, float frozen, float rain, int mud_ramp, inout Ground g) {
	float level = 0.8 - 0.12 * amount;               // how low it has to be
	if (amount <= 0.02 || low < level - 0.035) {
		return 0.0;
	}
	if (low < level) {
		// The wet margin: dark mud.
		g.ramp = mud_ramp;
		g.v = min(g.v, 0.3) - 0.1;
		return 0.0;
	}
	float depth = low - level;
	if (frozen > 0.5) {
		g.ramp = R_ICE;
		g.v = 0.58 + 0.2 * gnoise(p * 1.3 + 4.0);
		GroundCell k = gcell(p * 3.1 + 5.0);
		if (k.d2 - k.d1 < 0.045) {
			g.v = 0.95;                               // white cracks in the ice
		} else if (k.d1 < 0.09) {
			g.v += 0.18;                              // air caught in it
		}
		if (depth < 0.02) {
			g.v += 0.2;                               // frosted white at the edge
		}
		return 1.0;
	}
	g.ramp = R_WATER;
	// The sky in it: mostly mid, brighter toward the middle, slow drifting cloud.
	g.v = 0.42 + 0.3 * smoothstep(0.0, 0.2, depth) * gnoise(p * 0.8 + vec2(TIME * 0.03, 0.0)) + 0.12 * gnoise(p * 3.0);
	if (depth < 0.018) {
		g.v -= 0.22;                                  // the dark line of its edge
	}
	if (gh1(texel * 0.611 + floor(TIME * 3.0) * 0.17) > 0.994) {
		g.v += 0.4;                                   // a glint
	}
	if (rain > 0.05) {
		// Rain rings: each cell drops one now and then; the ring spreads and fades. Stepped like sprite frames.
		float t = floor(TIME * 10.0) / 10.0;
		GroundCell d = gcell(p * 2.4 + 17.0);
		float age = fract(t * (0.5 + 0.5 * d.id) + d.id * 7.0);
		if (d.id < rain && abs(d.d1 - age * 0.45) < 0.035 && age < 0.85) {
			g.v += 0.3 * (1.0 - age);
		}
	}
	return 1.0;
}

// Fallen leaves. `amount` 0 none .. 1 a thick fall.
void dirt_leaves(vec2 p, float amount, inout Ground g) {
	if (amount <= 0.01) {
		return;
	}
	GroundCell l = gcell(p * 3.3 + 91.0);
	if (l.id > amount * 0.5) {
		return;
	}
	float a = l.id * 61.0;
	vec2 ax = vec2(cos(a), sin(a));
	float lng = dot(l.to, ax);
	float wid = dot(l.to, vec2(-ax.y, ax.x));
	if (length(vec2(lng, wid * 1.8)) < 0.4) {
		g.ramp = R_LEAF;
		g.v = 0.3 + 0.55 * fract(l.id * 23.0);          // each leaf its own colour: ochre, orange, rust
		if (abs(wid) < 0.05) {
			g.v -= 0.18;                               // the midrib
		}
		g.v += 0.1 * sign(wid) * dot(vec2(-ax.y, ax.x), DIRT_SUN);
	}
}

// Small green things coming up. `amount` 0 none .. 1 a good scatter.
void dirt_sprouts(vec2 p, float amount, inout Ground g) {
	if (amount <= 0.01) {
		return;
	}
	GroundCell s = gcell(p * 3.4 + 51.0);
	// A little tuft: two or three blades fanning out from a point.
	float blade = abs(s.to.x + 0.6 * s.to.y * sign(fract(s.id * 5.0) - 0.5));
	if (s.id < amount * 0.42 && s.d1 < 0.3 && (blade < 0.09 || abs(s.to.x) < 0.06) && s.to.y > -0.1) {
		g.ramp = R_GREEN;
		g.v = 0.4 + 0.45 * fract(s.id * 19.0) + 0.5 * s.to.y;
	}
}

// Cut stalks standing in rows along `dir`, `period` metres apart (what a harvest leaves).
void dirt_stubble(vec2 p, vec2 dir, float period, float amount, inout Ground g) {
	if (amount <= 0.01) {
		return;
	}
	float u = dirt_row(p, dir, period);
	float row = abs(fract(u) - 0.5);
	float along = dot(p, dir) * 5.0;
	float n = gh1(vec2(floor(along), floor(u)));
	if (row < 0.1 && n < amount * 0.75 && fract(along) < 0.55) {
		g.ramp = R_STRAW;
		g.v = 0.4 + 0.45 * fract(n * 31.0);
	}
}

// Seedlings set out along the ridge tops of rows (a sown field in spring).
void dirt_seedlings(vec2 p, vec2 dir, float period, float amount, inout Ground g) {
	if (amount <= 0.01) {
		return;
	}
	float u = dirt_row(p, dir, period);
	float along = dot(p, dir) * 3.2 + gh1(vec2(floor(u), 7.0)) * 3.0;
	float n = gh1(vec2(floor(along), floor(u)));
	vec2 c = vec2(fract(along) - 0.5, (fract(u) - 0.5) * 2.2);
	if (n < amount && length(c) < 0.26) {
		g.ramp = R_GREEN;
		g.v = 0.5 + 0.35 * fract(n * 29.0) - 0.7 * length(c) + 0.25 * step(0.0, c.x * DIRT_SUN.x);
	}
}

// Hoar frost: it whitens what stands highest first, in patches (thicker where the air lay still). `high` 0..1
// how high this spot stands.
void dirt_frost(vec2 p, vec2 texel, float amount, float high, inout Ground g) {
	if (amount <= 0.01) {
		return;
	}
	// Frozen ground is harder and paler all over.
	g.v += 0.05 * amount;
	float rime = high * 0.75 + gfbm(p * 1.3 + 23.0) * 0.55 + gh1(texel * 0.577 + 5.5) * 0.14;
	float line = 1.52 - 0.5 * amount;
	if (rime > line) {
		g.ramp = R_ICE;
		g.v = 0.5 + 1.6 * (rime - line) + 0.12 * gh1(texel * 0.291);     // thin and grey at its edge, white where thick
	}
}

// Lying snow. `amount` 0 none .. 1 everything under; `low` 0..1 how low the spot lies (snow fills the low places
// and the lee of things first, and melts off the high ones first). Returns 1 under snow.
float dirt_snow(vec2 p, vec2 texel, float amount, float low, inout Ground g) {
	if (amount <= 0.01) {
		return 0.0;
	}
	float cover = gfbm(p * 0.8 + 41.0) * 0.55 + gnoise(p * 3.3 + 8.0) * 0.2 + 0.25 * (1.0 - low);
	float line = amount * 0.85 + 0.08;
	if (cover > line) {
		return 0.0;
	}
	g.ramp = R_SNOW;
	// Drifted: soft hollows, a lit side, and a thin dirty edge where it is melting back.
	float drift = gfbm(p * 1.4 + 3.0);
	float slope = drift - gfbm((p + DIRT_SUN * 0.12) * 1.4 + 3.0);
	g.v = 0.86 - 2.2 * slope + 0.06 * (drift - 0.5);
	if (line - cover < 0.03) {
		g.v -= 0.25;
	}
	if (gh1(texel * 0.803 + 1.3) > 0.985) {
		g.v = 1.0;                                    // a sparkle
	}
	return 1.0;
}
