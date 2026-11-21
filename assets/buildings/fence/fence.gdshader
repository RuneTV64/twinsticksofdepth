shader_type spatial;
// A timber fence, drawn on one thin box: the shader decides, texel by texel, what stands there (a post, a
// picket, a board, a rail, a gate's brace) and cuts the rest away, so the gaps are real gaps. Three kinds:
//
//   0 picket   1.0 m: pointed pickets three texels wide with two texels between, two rails behind them
//   1 board    1.875 m: tight upright boards with clipped tops; three rails on the inside
//   2 rail     1.25 m: stout posts and three rails, nothing else
//
// Posts stand at both ends of a run and evenly between (`run_start`, `run_len`); they are a little taller,
// with a cap. The side whose normal points along `outward` is the good side (pickets and boards in front,
// rails behind); the other shows the rails across them. A gate leaf (`gate`) is laid out on the leaf itself,
// so it keeps its pattern as it swings, has no posts, and is braced corner to corner.
//
//   paint    -1 bare timber: warm when new, silvering as it wears; 0 cream, 1 sage, 2 slate (the house's
//            paints); 3 white
//   weather  wet darkens it in streaks, a dry summer bleaches it, algae climbs the foot in the damp seasons,
//            leaves gather against it in autumn, frost, and snow on every cap, rail and point
//   wear     0 sound; 1 paint peeling, timber silvered, a picket or a rail gone, boards split;
//            2 many gone or broken off short, rails hanging
#include "res://assets/buildings/house/house_lib.gdshaderinc"

uniform int kind : hint_range(0, 2) = 0;
uniform int paint : hint_range(-1, 3) = -1;
uniform vec3 outward = vec3(0.0, 0.0, 1.0);
uniform bool along_x = true;           // the run goes along the world's X (else along Z)
uniform float ground_y = 0.0;
uniform float run_start = 0.0;         // where the run starts along its axis (m, world)
uniform float run_len = 2.4;
uniform bool gate = false;
uniform vec2 leaf = vec2(1.2, 1.0);    // a gate leaf's width and height (m)
uniform float leaf_out = 1.0;          // which side of the leaf (local +z or -z) is the good side

varying vec3 wp;
varying vec3 wn;
varying vec3 lp;
varying vec3 ln;
varying vec2 ltexel;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lp = VERTEX;
	ln = NORMAL;
}

// What stands at one texel of the fence.
const int NOTHING = 0;
const int POST = 1;
const int UPRIGHT = 2;     // a picket or a board
const int RAIL = 3;
const int BRACE = 4;       // a gate's diagonal

struct Piece {
	int what;
	float id;        // 0..1, steady for one picket, board, rail or post
	float shade;     // lighter or darker for its edges
	bool cap;        // its top texel: snow lies here
	bool behind;     // seen through a gap, behind the uprights
};

Piece nothing() {
	return Piece(NOTHING, 0.0, 0.0, false, false);
}

// The height (in texel rows) of each kind: the box is this tall, and so are the posts.
int rows_of(int k) {
	return k == 0 ? 16 : (k == 1 ? 30 : 20);
}

// Is row `ty` on one of the kind's rails? Returns the rail's number (1..) or 0. `drop` lowers it (a sagging rail).
int rail_at(int k, float ty, float drop) {
	float r = ty + drop;
	if (k == 0) {
		return (r >= 4.0 && r < 6.0) ? 1 : ((r >= 10.0 && r < 12.0) ? 2 : 0);
	}
	if (k == 1) {
		return (r >= 4.0 && r < 6.0) ? 1 : ((r >= 14.0 && r < 16.0) ? 2 : ((r >= 24.0 && r < 26.0) ? 3 : 0));
	}
	return (r >= 4.0 && r < 6.0) ? 1 : ((r >= 10.0 && r < 12.0) ? 2 : ((r >= 16.0 && r < 18.0) ? 3 : 0));
}

Piece fence_piece(float tu, float ty, float len_t, bool good_side, float w, float seed) {
	float rows = float(rows_of(kind));
	if (ty < 0.0 || ty >= rows) {
		return nothing();
	}
	float post_w = kind == 2 ? 3.0 : 2.0;
	float bay = 0.0;
	float bay_len = len_t;
	float in_bay = tu;
	// ---- posts: at both ends, and evenly between
	if (!gate) {
		float want = (kind == 2 ? 2.7 : 2.4) * GROUND_TEXELS;
		float n = max(1.0, floor((len_t - post_w) / want + 0.5));
		float step = (len_t - post_w) / n;
		float k0 = floor(tu / step);
		for (int i = 0; i < 2; i++) {
			float at = floor((k0 + float(i)) * step + 0.5);
			if (k0 + float(i) <= n && tu >= at && tu < at + post_w) {
				float c = tu - at;
				return Piece(POST, gh1(vec2(k0 + float(i), 31.0) + seed), (c < 1.0 ? 0.05 : -0.08) + (ty >= rows - 1.0 ? 0.12 : 0.0),
					ty >= rows - 1.0, false);
			}
		}
		bay = k0;
		bay_len = step;
		in_bay = tu - floor(k0 * step + 0.5);
	} else if (kind == 2 && (tu < 2.0 || tu >= len_t - 2.0) && ty < rows - 1.0) {
		// A rail gate's two stiles.
		return Piece(POST, 0.5, tu < 1.0 || tu >= len_t - 1.0 ? 0.04 : -0.06, ty >= rows - 2.0, false);
	}
	// ---- rails, and a gate's brace
	float rail_id = 0.0;
	int rail = 0;
	for (int r = 1; r <= 3; r++) {
		float id = gh1(vec2(bay * 7.0 + float(r), 17.0) + seed);
		// A worn rail sags from one end; a failing one has gone.
		float sag = id < w * 0.5 ? floor(in_bay / max(bay_len, 1.0) * (2.0 + id * 8.0)) : 0.0;
		if (rail_at(kind, ty, sag) == r && !(kind == 2 && gate)) {
			if (id > 1.0 - max(w - 0.5, 0.0) * 0.5) {
				continue;
			}
			rail = r;
			rail_id = id;
		}
	}
	if (kind == 2 && gate) {
		// A farm gate: four bars.
		float m = mod(ty - 1.0, 5.0);
		if (ty >= 1.0 && ty < rows - 1.0 && m < 2.0) {
			rail = 1 + int(floor((ty - 1.0) / 5.0));
			rail_id = gh1(vec2(float(rail), 23.0) + seed);
		}
	}
	bool brace = false;
	if (gate) {
		float lo = kind == 2 ? 2.0 : 5.0;
		float hi = kind == 0 ? 10.0 : (kind == 1 ? 24.0 : 17.0);
		float line = lo + (hi - lo) * tu / max(len_t - 1.0, 1.0);
		brace = abs(ty - line) < (kind == 1 ? 1.6 : 1.1) && (!good_side || kind == 2);
	}
	// ---- uprights
	Piece up = nothing();
	if (kind == 0) {
		float c = mod(in_bay + (gate ? 0.0 : 3.0), 5.0);
		float pk = floor((in_bay + (gate ? 0.0 : 3.0)) / 5.0);
		float id = gh1(vec2(bay * 13.0 + pk, 5.0) + seed);
		float top = 14.0;
		// Wear: some pickets gone altogether, some snapped off short.
		if (id < w * 0.14 + max(w - 0.5, 0.0) * 0.3) {
			top = -1.0;
		} else if (id < w * 0.3 + max(w - 0.5, 0.0) * 0.4) {
			top = 4.0 + floor(id * 97.0 - floor(id * 97.0 / 6.0) * 6.0) - (c == 1.0 ? 1.0 : 0.0);
		}
		if (c < 3.0 && ty >= 1.0 && (ty < top || (ty == top && c == 1.0))) {
			up = Piece(UPRIGHT, id, (c < 1.0 ? 0.05 : (c > 1.5 ? -0.1 : 0.0)) + (ty >= top - 1.0 ? 0.06 : 0.0), ty == top || (ty == top - 1.0 && c != 1.0), false);
		}
	} else if (kind == 1) {
		float c = mod(in_bay, 3.0);
		float bd = floor(in_bay / 3.0);
		float id = gh1(vec2(bay * 13.0 + bd, 9.0) + seed);
		float top = rows - 2.0;
		if (id < max(w - 0.5, 0.0) * 0.28) {
			top = -1.0;
		} else if (id < w * 0.16) {
			top = 9.0 + floor(id * 211.0 - floor(id * 211.0 / 14.0) * 14.0) + (c == 1.0 ? 1.0 : 0.0);
		}
		// The clipped corners: the seam texel is left out of the top row.
		if (ty < top || (ty == top && c > 0.5)) {
			up = Piece(UPRIGHT, id, c < 1.0 ? -0.18 : (c > 1.5 ? 0.03 : 0.0), ty == top, false);
			// A split down a worn board.
			if (id > 1.0 - w * 0.4 && c > 1.5 && mod(ty + id * 40.0, 13.0) < 7.0) {
				up.shade -= 0.3;
			}
		}
	}
	// ---- which is in front
	Piece rl = nothing();
	if (brace) {
		rl = Piece(BRACE, 0.4, 0.0, false, false);
	}
	if (rail > 0) {
		float edge = rail_at(kind, ty + 1.0, 0.0) == 0 ? 0.08 : -0.1;      // light on its top edge, shadow under
		rl = Piece(RAIL, rail_id, edge, edge > 0.0, false);
	}
	if (kind == 2) {
		return rl;
	}
	if (good_side) {
		if (up.what != NOTHING) {
			return up;
		}
		rl.behind = true;
		return rl.what == BRACE ? nothing() : rl;
	}
	return rl.what != NOTHING ? rl : up;
}

void fragment() {
	if (cutaway_hidden(wp, FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(wn);
	GroundEnv e = house_env();
	float w = wear * 0.5;
	float rows = float(rows_of(kind));
	float tu;
	float ty;
	float len_t;
	bool top;
	bool good;
	float y;
	float seed;
	if (gate) {
		vec3 l = normalize(ln);
		top = abs(l.y) > 0.5;
		len_t = floor(leaf.x * GROUND_TEXELS + 0.5);
		tu = clamp(floor((lp.x + leaf.x * 0.5) * GROUND_TEXELS), 0.0, len_t - 1.0);
		ty = floor((lp.y + leaf.y * 0.5) * GROUND_TEXELS + 0.001);
		good = l.z * leaf_out > 0.0;
		y = lp.y + leaf.y * 0.5;
		seed = 3.0;
	} else {
		top = abs(n.y) > 0.5;
		len_t = floor(run_len * GROUND_TEXELS + 0.5);
		tu = clamp(floor(((along_x ? wp.x : wp.z) - run_start) * GROUND_TEXELS + 0.001), 0.0, len_t - 1.0);
		ty = floor((wp.y - ground_y) * GROUND_TEXELS + 0.001);
		good = dot(n, outward) > 0.0;
		y = wp.y - ground_y;
		seed = floor(run_start * 3.7) + (along_x ? 0.0 : 50.0);
	}
	if (top) {
		ty = n.y > 0.0 || gate ? rows - 1.0 : 0.0;       // the top of the box: only what reaches it shows
	}
	ty = min(ty, rows - 1.0);
	Piece q = fence_piece(tu, ty, len_t, good, w, seed);
	// Autumn's leaves, caught against the foot of a picket or board fence.
	bool litter = !gate && kind != 2 && !top && ty < 1.0 + (kind == 1 ? 1.0 : 0.0)
		&& gh1(vec2(tu, ty) * 1.31 + seed) < e.autumn * 0.55 + e.winter * 0.12;
	if (q.what == NOTHING && !litter) {
		discard;
	}
	// The texel's place in the world, for the weather's patterns.
	vec2 t = vec2(tu + floor(run_start * GROUND_TEXELS), ty + floor(ground_y * GROUND_TEXELS));
	vec2 p = house_point(t);
	Surf s;
	if (q.what == NOTHING) {
		s = gsurf(R_LEAF, 0.35 + gh1(t * 0.7) * 0.4);
	} else {
		bool rough = kind == 2 || q.what == POST && kind != 0;       // split rails and posts are never painted
		vec2 grain = q.what == RAIL || q.what == BRACE ? p : p.yx;     // along the piece
		float v = 0.6 + (q.id - 0.5) * 0.14 + q.shade - (q.behind ? 0.24 : 0.0);
		if (paint >= 0 && !rough) {
			s = paint == 3 ? surf(H_TRIM, v + 0.12) : surf(paint, v + 0.04);
			// Paint peels along the grain to bare silvered wood.
			if (gfbm(grain * vec2(1.3, 6.0) + q.id * 9.0) < w * 0.66 - 0.04) {
				s = house_wood(grain, v - 0.1);
			}
		} else {
			// Bare timber: warm when new, silver-grey as the weather gets at it; rough timber starts half way.
			float grey = w * w * 1.1 + w * 0.2 + (rough ? 0.42 : 0.08);
			if (gfbm(grain * vec2(1.1, 5.0) + q.id * 9.0) < grey) {
				s = house_wood(grain, v - 0.06);
			} else {
				s = surf(H_FLOOR, v - 0.14 + (gnoise(vec2(grain.x * 2.0, grain.y * 22.0)) - 0.5) * 0.1);
			}
			if (gh1(t * 0.913 + 7.0) < 0.012) {
				s.v -= 0.25;                                          // a knot
			}
		}
		s.v -= w * 0.06;
		// Algae up from the ground in the damp seasons, further on a worn fence.
		float damp = e.spring * 0.5 + e.autumn * 0.7 + e.wet * 0.4 + w * 0.6;
		if (y < 0.12 + damp * 0.45 && gfbm(p * vec2(2.2, 4.0) + 2.0) < damp * 0.34 - y * 0.5) {
			s = gsurf(R_GREEN, 0.26 + q.shade);
		}
		s = house_weather(s, p, t, e, top ? 1.0 : 0.0, y);
		// Snow sits on every cap, rail and point.
		if (q.cap && gh1(vec2(tu, floor(ty / 3.0)) * 0.77 + 1.0) < e.snow * 2.2) {
			s = gsurf(R_SNOW, 0.88);
		}
	}
	ltexel = t;
	vec3 c = house_color(s, t);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/buildings/house/house_light.gdshaderinc"
