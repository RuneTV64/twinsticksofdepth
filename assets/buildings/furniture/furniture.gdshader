shader_type spatial;
// Furniture. A piece is a few boxes joined into one mesh (furniture_kit.gd); this shader paints every face of
// every box, texel by texel on the face's own grid (16 to the metre), by the part that face plays:
//
//    0 wood          plain boards, the grain along the longer side
//    1 drawers       a front of drawers with brass knobs
//    2 doors         a pair of panelled doors
//    3 shelves       shelves of books
//    4 fabric        upholstery, with the seams between cushions
//    5 sheet         a mattress under a sheet
//    6 blanket       a striped blanket
//    7 pillow
//    8 iron          cast iron: a stove's body
//    9 iron front    a stove's door, with the fire behind its slots when it is lit
//   10 iron top      a stove's top, with its two plates
//   11 enamel        white enamel: a fridge's sides
//   12 fridge front  its two doors and their handles
//   13 worktop       a kitchen counter's top
//   14 cupboards     a run of cupboard doors, one every half metre
//   15 glass doors   a pair of glazed doors on shelves of china: plates and cups behind a glint of glass
//   16 brick         courses of brick in mortar
//   17 fire front    a fireplace's face: brick round a sooty firebox with its grate, the fire in it when lit
//   18 lacquer       a piano's black case, with a sheen down it
//   19 keys          a piano's keyboard from above: white keys, the black ones in their twos and threes
//   20 rug           a patterned rug: a border, a field, a medallion in the middle, in the piece's fabric
//   21 curtain       curtains hanging in folds, in the fabric, with a hem
//
// The mesh tells it which: UV is the spot on the face in metres, UV2 the face's size, COLOR.r the part, COLOR.g
// a number of the face's own (so two faces don't wear alike).
//
//   stain    the wood: 0 pine, 1 oak, 2 walnut
//   fabric   the cloth: 0 brick red, 1 olive, 2 blue
//   wear     0 sound; 1 scuffed, faded, stained, books and a drawer gone; 2 torn to the stuffing, drawers
//            out, rust, and mould where the damp gets in (in the wet and the cold seasons)
//   weather  indoors there is none until the piece is worn; then the damp comes with the season
#include "res://assets/buildings/house/house_lib.gdshaderinc"
#include "res://assets/buildings/furniture/furniture_ramps.gdshaderinc"

uniform int stain : hint_range(0, 2) = 1;
uniform int fabric : hint_range(0, 2) = 0;
uniform bool burning = false;

varying vec3 wp;
varying vec2 ltexel;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 furn_color(Surf s, vec2 texel) {
	if (s.ground || s.ramp < FURN_FIRST) {
		return house_color(s, texel);
	}
	float f = (1.0 - clamp(s.v, 0.0, 1.0)) * 8.0 + (gbayer(texel) - 0.5) * 0.6;
	int ix = clamp(int(floor(f)), 0, 7);
	return FURN_RAMPS[(s.ramp - FURN_FIRST) * 8 + ix];
}

void fragment() {
	// Furniture stands while you are indoors (as the stairs do): it opens only round you, round the crosshair,
	// and above the storey you are on.
	if (cutaway_hidden_standing(wp, FRAGCOORD.xy)) {
		discard;
	}
	int role = int(COLOR.r * 32.0 + 0.5);
	float seed = COLOR.g;
	float tw = max(floor(UV2.x * GROUND_TEXELS + 0.5), 1.0);
	float th = max(floor(UV2.y * GROUND_TEXELS + 0.5), 1.0);
	float tu = clamp(floor(UV.x * GROUND_TEXELS + 0.001), 0.0, tw - 1.0);
	float tv = clamp(floor(UV.y * GROUND_TEXELS + 0.001), 0.0, th - 1.0);
	float mu = min(tu, tw - 1.0 - tu);              // texels in from the nearer side
	float mv = min(tv, th - 1.0 - tv);
	vec2 t = vec2(tu, tv) + floor(seed * 255.0) * vec2(7.0, 13.0);
	vec2 p = (vec2(tu, tv) + 0.5) / GROUND_TEXELS + seed * 17.0;
	float w = wear * 0.5;
	GroundEnv e = house_env();
	bool edge = mu < 1.0 || mv < 1.0;
	bool glow = false;
	bool hard = true;                               // wood, iron, enamel: no stuffing in it
	// ---- wood, the ground of most parts
	float base = stain == 0 ? 0.64 : (stain == 1 ? 0.43 : 0.28);
	vec2 g = UV2.x >= UV2.y ? p : p.yx;
	Surf s = surf(H_FLOOR, base + (gnoise(vec2(g.x * 2.0, g.y * 22.0)) - 0.5) * 0.1);
	if (role == 0) {
		float cross_t = UV2.x >= UV2.y ? tv : tu;
		s.v -= mod(cross_t, 5.0) < 1.0 && (UV2.x >= UV2.y ? th : tw) > 6.0 ? 0.05 : 0.0;
	} else if (role == 1) {
		// Drawers, five texels deep, with a knob (two on a wide one).
		float row = floor(tv / 5.0);
		float r = mod(tv, 5.0);
		float id = gh1(vec2(row, 3.0) + seed * 40.0);
		if (id < max(w - 0.3, 0.0) * 0.5 && !edge) {
			s.v = 0.07 + 0.03 * r;                              // a drawer gone: the dark of the carcass
		} else {
			s.v += r < 1.0 ? -0.2 : 0.04;
			bool knob = (r == 2.0 || r == 3.0) && (tw > 18.0 ? (abs(tu - floor(tw * 0.28)) < 1.0 || abs(tu - floor(tw * 0.72)) < 1.0) : abs(tu - floor(tw * 0.5)) < 1.0);
			if (knob && r == 2.0) {
				s = surf(F_BRASS, 0.72);
			}
		}
	} else if (role == 2 || role == 14) {
		// Doors: a pair (2), or one every half metre along a counter (14).
		float dw = role == 2 ? floor(tw * 0.5) : 8.0;
		float c = mod(tu, dw);
		float in_u = min(c, dw - 1.0 - c);
		if (c < 1.0 && tu > 0.0) {
			s.v -= 0.22;                                        // the gap between two doors
		} else if ((in_u == 2.0 && mv >= 2.0) || (mv == 2.0 && in_u >= 2.0)) {
			s.v += 0.07;                                        // the panel's moulding
		}
		float kv = role == 2 ? floor(th * 0.5) : th - 3.0;
		float ku = role == 2 ? (tu < dw ? dw - 2.0 : dw + 1.0) : (floor(tu / dw) * dw + dw - 2.0);
		if (tu == ku && abs(tv - kv) < 1.0) {
			s = surf(F_BRASS, 0.72);
		}
		if (gh1(vec2(floor(tu / dw), 9.0) + seed * 40.0) < max(w - 0.5, 0.0) * 0.6 && !edge && c >= 1.0) {
			s.v = 0.08;                                         // a door torn off
		}
	} else if (role == 3) {
		// Shelves of books: a board every six texels, spines of all heights and colours between.
		float r = mod(tv, 6.0);
		if (r >= 1.0 && mu >= 1.0) {
			float id = gh1(vec2(tu, floor(tv / 6.0)) * 0.71 + seed * 31.0);
			float tall = 3.0 + floor(fract(id * 13.0) * 2.99);
			if (id < 0.14 + w * 0.6 || r - 1.0 >= tall) {
				s.v = 0.1;                                      // no book there: the dark back of the case
			} else {
				int pick = int(floor(fract(id * 7.0) * 5.99));
				s = pick == 0 ? surf(F_RUST, 0.5) : (pick == 1 ? surf(F_MOSS, 0.5) : (pick == 2 ? surf(F_DENIM, 0.5)
					: (pick == 3 ? surf(H_PAINT, 0.62) : (pick == 4 ? surf(F_BRASS, 0.5) : surf(H_SLATE, 0.45)))));
				s.v += (fract(id * 29.0) - 0.5) * 0.24 + (r - 1.0 == tall - 1.0 ? 0.08 : 0.0);
			}
		}
	} else if (role == 4 || role == 6) {
		// Cloth: upholstery with the seams between its cushions, or a striped blanket.
		hard = false;
		s = surf(F_RUST + fabric, 0.54 + (mod(tu + tv, 2.0) < 1.0 ? 0.02 : -0.02) + 0.08 * w);
		if (role == 4) {
			float n = max(1.0, floor(UV2.x / 0.62 + 0.5));
			float cw = floor(tw / n);
			if (tw >= 14.0 && tu > 0.0 && mod(tu, cw) < 1.0 && tu < cw * n) {
				s.v -= 0.16;
			}
			s.v -= edge ? 0.1 : 0.0;
		} else {
			s.v += mod(tv, 4.0) < 1.0 ? 0.2 : (mod(tu, 6.0) < 1.0 ? 0.09 : 0.0);
			s.v += mv < 1.0 ? 0.06 : 0.0;
		}
	} else if (role == 5 || role == 7) {
		// Linen: a sheet over the mattress, a pillow.
		hard = false;
		s = surf(F_LINEN, (role == 7 ? 0.9 : 0.78) + (gnoise(p * 4.0) - 0.5) * 0.1 - 0.1 * w);
		s.v -= edge ? 0.13 : 0.0;
		if (role == 5 && mod(tu, 3.0) < 1.0 && UV2.y < 0.3) {
			s = surf(F_DENIM, 0.62);                            // the ticking down the mattress's side
		}
	} else if (role >= 8 && role <= 10) {
		// Cast iron.
		s = surf(F_IRON, 0.3 + (gnoise(p * 9.0) - 0.5) * 0.06 + (edge ? 0.07 : 0.0));
		if (role == 9) {
			bool door = mu >= 2.0 && tv >= 2.0 && tv <= th - 4.0;
			bool rim = door && (mu == 2.0 || tv == 2.0 || tv == th - 4.0);
			if (rim) {
				s.v += 0.14;
			} else if (door && mod(tv, 2.0) < 1.0 && mu >= 4.0 && tv >= 4.0 && tv <= th - 7.0) {
				if (burning) {
					float fl = gh1(vec2(tu, tv) + floor(TIME * 6.0));
					s = surf(F_EMBER, 0.62 + 0.3 * fl);         // the fire, through the slots
					glow = true;
				} else {
					s.v = 0.08;
				}
			}
			if (tu == tw - 4.0 && abs(tv - floor(th * 0.55)) < 2.0) {
				s = surf(F_BRASS, 0.6);                         // the latch
				glow = false;
			}
		} else if (role == 10) {
			float r1 = length(vec2(tu - floor(tw * 0.28), tv - floor(th * 0.5)));
			float r2 = length(vec2(tu - floor(tw * 0.72), tv - floor(th * 0.5)));
			if (abs(r1 - 3.0) < 0.6 || abs(r2 - 3.0) < 0.6) {
				s.v += 0.16;                                    // the rings of its two plates
			}
		}
		if (!glow && gfbm(p * 6.0 + 4.0) < w * 0.62 - 0.1) {
			s = surf(F_RUST, 0.34 + 0.2 * gnoise(p * 11.0));
		}
	} else if (role == 11 || role == 12) {
		// White enamel.
		s = surf(F_ENAMEL, 0.86 - (edge ? 0.1 : 0.0) - 0.08 * w + (gnoise(p * 3.0) - 0.5) * 0.04);
		if (role == 12) {
			float split = floor(th * 0.68);
			if (tv == split) {
				s.v -= 0.34;                                    // between the fridge door and the freezer's
			}
			if (tu == tw - 3.0 && ((tv >= split - 5.0 && tv <= split - 2.0) || (tv >= split + 2.0 && tv <= split + 4.0))) {
				s = surf(F_IRON, 0.42);                         // their handles
			}
		}
		// Rust creeps up from the floor and in from the edges.
		if (gfbm(p * 6.0 + 4.0) < w * 0.6 - 0.14 + 0.2 * w * step(tv, 3.0)) {
			s = surf(F_RUST, 0.4 + 0.2 * gnoise(p * 11.0));
		}
	} else if (role == 13) {
		s = surf(H_PLASTER, 0.7 + (gh1(t * 0.61) > 0.88 ? -0.14 : 0.0) - (edge ? 0.1 : 0.0));
	} else if (role == 15) {
		// Glazed doors: a wooden frame round two panes; behind the glass, a shelf every six texels with plates
		// stood on their edges and cups; a glint of the glass across it all. Worn, the china thins out and panes go.
		float dw = floor(tw * 0.5);
		float c = mod(tu, dw);
		float in_u = min(c, dw - 1.0 - c);
		if (in_u >= 1.0 && mv >= 1.0) {
			float r = mod(tv, 6.0);
			float slot = floor(tu / 3.0);
			float id = gh1(vec2(slot, floor(tv / 6.0)) + seed * 23.0);
			if (r < 1.0) {
				s.v = base - 0.06;                                  // the shelf
			} else if (id < 0.8 - w * 0.7 && r >= 1.0 && r <= 4.0 && (mod(tu, 3.0) < 2.0 || r >= 3.0)) {
				s = id < 0.45 ? surf(F_ENAMEL, 0.82 - (r - 1.0) * 0.04) : (id < 0.65 ? surf(F_DENIM, 0.62) : surf(F_BRASS, 0.6));
			} else {
				s.v = 0.1;                                          // the dark back of the cabinet
			}
			bool pane_gone = gh1(vec2(floor(tu / dw), 5.0) + seed * 40.0) < max(w - 0.45, 0.0) * 0.8;
			if (!pane_gone && mod(tu + tv * 0.6, 9.0) < 1.0) {
				s.v += 0.22;                                        // the glint of the glass
			}
		} else if (c < 1.0 && tu > 0.0) {
			s.v -= 0.18;
		}
	} else if (role == 16 || role == 17) {
		// Brick: three-texel courses, one of mortar and two of brick, the joints staggered course by course.
		float course = floor(tv / 3.0);
		bool mortar = mod(tv, 3.0) < 1.0 || mod(tu + mod(course, 2.0) * 2.0, 4.0) < 1.0;
		float bid = gh1(vec2(floor((tu + mod(course, 2.0) * 2.0) / 4.0), course) + seed * 11.0);
		s = mortar ? surf(H_PLASTER, 0.5 + (gnoise(p * 7.0) - 0.5) * 0.08) : surf(F_BRICK, 0.48 + (bid - 0.5) * 0.18);
		if (role == 17) {
			// The firebox: in the middle half of the face, up to two thirds of its height, its top arched.
			float cx = (tu + 0.5) / tw - 0.5;
			float cy = (tv + 0.5) / th;
			float open_h = 0.6 - 0.25 * cx * cx * 4.0;
			bool box = abs(cx) < 0.26 && cy > 0.05 && cy < open_h;
			if (box) {
				s = surf(F_IRON, 0.1 + 0.08 * (cy / open_h));
				if (cy < 0.2 && mod(tu, 2.0) < 1.0) {
					s = surf(F_IRON, 0.34);                         // the grate's bars
				}
				if (burning && cy < open_h * 0.75) {
					float fl = gh1(vec2(tu, tv) + floor(TIME * 7.0));
					float tongue = (open_h * 0.75 - cy) / (open_h * 0.75) * (1.0 - abs(cx) * 3.0);
					if (fl < tongue * 1.6) {
						s = surf(F_EMBER, 0.4 + 0.5 * fl * tongue + 0.2 * (1.0 - cy / open_h));
						glow = true;
					}
				}
			} else if (abs(cx) < 0.33 && cy < open_h + 0.18 && cy > 0.05) {
				s.v -= 0.14 * (1.0 - (cy - open_h) / 0.18 * step(open_h, cy));   // soot round the mouth of it
			}
		}
	} else if (role == 18 || role == 19) {
		// Black lacquer, with a sheen running down it.
		s = surf(F_LACQUER, 0.42 + (mod(tu - tv * 0.35, 14.0) < 1.5 ? 0.2 : 0.0) + (edge ? 0.1 : 0.0) + (gnoise(p * 5.0) - 0.5) * 0.04);
		if (role == 19 && tv < th - 1.0) {
			// The keys: white with a line between, and the black ones on the back half in twos and threes.
			s = surf(F_LINEN, 0.92 - (mod(tu, 2.0) < 1.0 ? 0.0 : 0.08) - w * 0.2);
			float k = mod(tu, 14.0);
			bool black = tv >= floor(th * 0.4) && (k == 1.0 || k == 3.0 || k == 7.0 || k == 9.0 || k == 11.0);
			if (black || gh1(vec2(tu, 4.0) + seed * 9.0) < w * 0.2) {
				s = surf(F_LACQUER, 0.3);                           // black keys (and, worn, keys gone)
			}
		}
	} else if (role == 20) {
		// A rug: a dark border with a gold line inside it, a field, a medallion in the middle, a scatter of motifs.
		hard = false;
		float cx = abs((tu + 0.5) / tw - 0.5) * UV2.x;
		float cy = abs((tv + 0.5) / th - 0.5) * UV2.y;
		s = surf(F_RUST + fabric, 0.5 + (mod(tu + tv, 2.0) < 1.0 ? 0.02 : -0.02));
		if (mu < 2.0 || mv < 2.0) {
			s.v -= 0.2;
		} else if (mu < 3.0 || mv < 3.0) {
			s = surf(F_BRASS, 0.62);
		} else if (cx / max(UV2.x * 0.18, 0.05) + cy / max(UV2.y * 0.24, 0.05) < 1.0) {
			s = (cx / max(UV2.x * 0.18, 0.05) + cy / max(UV2.y * 0.24, 0.05) < 0.55) ? surf(F_LINEN, 0.8) : surf(F_BRASS, 0.55);
		} else if (mod(tu, 6.0) == 3.0 && mod(tv, 6.0) == 3.0) {
			s = surf(F_LINEN, 0.7);
		}
	} else if (role == 21) {
		// Curtains: soft folds every few texels, a darker hem at the foot and a heading at the top.
		hard = false;
		float fold = sin((tu + 0.5) * 1.8 + seed * 6.0);
		s = surf(F_RUST + fabric, 0.46 + 0.12 * fold + (mod(tv, 7.0) < 1.0 ? -0.02 : 0.0));
		if (tv < 1.0 || tv >= th - 1.0) {
			s.v -= 0.14;
		}
	}
	if (role <= 3 || role == 13 || role == 14 || role == 15) {
		s.v -= edge ? 0.1 : 0.0;                                // every wooden part has its outline
		// Scuffs and knocks.
		if (gfbm(p * 5.0 + 2.0) < w * 0.5 - 0.1) {
			s.v += 0.1;
		}
	}
	// ---- cloth wears its own way: stains, then tears to the stuffing
	if (!hard) {
		if (gfbm(p * 3.0 + 6.0) < w * 0.42) {
			s.v -= 0.16;
		}
		if (gfbm(p * 4.0 + 7.0) < (w - 0.5) * 0.52) {
			s = gsurf(R_STRAW, 0.72 + 0.14 * gnoise(p * 14.0));
		}
	}
	// ---- the damp, once a piece is worn: darker, and mould in the wet and the cold
	if (!glow) {
		float damp = w * (0.3 + e.wet * 0.5 + e.autumn * 0.3 + e.winter * 0.3);
		s.v -= damp * 0.12 * smoothstep(0.35, 0.75, gfbm(p * 1.2 + 8.0));
		if (gh1(t * 0.77) < damp * 0.2 * smoothstep(0.45, 0.7, gfbm(p * 0.9 + 1.0))) {
			s = gsurf(R_GREEN, 0.14);
		}
	}
	ltexel = t;
	vec3 c = furn_color(s, t);
	ALBEDO=pow(c,vec3(2.2));
	if (glow) {
		EMISSION=pow(c,vec3(2.2)) * 1.4;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/buildings/house/house_light.gdshaderinc"
