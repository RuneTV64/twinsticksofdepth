shader_type spatial;
// Clothes (owner, 21 Nov 2026: "make it so I can dress my character to the nines"). A second, skinned copy of the
// body's own mesh (clothes.gd builds it once and keeps it), drawn over the body: the approved model and skin shader
// are not touched. Everything worn is a layer, outermost first; at each spot the first layer that covers it is
// drawn, and where none does the copy is thrown away and the body shows. The copy is pushed out along the surface
// by the thickness of what covers it there, so a coat is bulkier than a shirt and a bag on the back stands out.
//
// What a layer covers is told by area and height on the body at rest (the mesh's own rest position, carried in
// CUSTOM0 with the area in .w; clothes.gd): for each of torso, arm, hand, leg, foot, neck, head and face a range
// of height, empty when low > high. A side mask keeps it to one side (a watch); a shape draws something that is
// not a band: a strap across the chest, a pack on the back, lenses over the eyes. Holes from wear (`tatter`) are
// gaps in that layer, so what is under it shows.
//
// The look is the game's 8-shade one: each layer's colour is spread into a ramp of eight, lit by bands with a
// Bayer dither, and patterned texel by texel (40 to the metre on the body at rest): knit, denim, check, stripes,
// leather, lace, print, metal, glass. Grime and blood lie on it in blotches.
// Areas: 0 torso, 1 arm, 2 hand, 3 leg, 4 foot, 5 neck, 6 head, 7 face (the front of the head, worked out here).
// Every size that belongs to the body rather than the garment (where the eyes are, how wide the face is, where a
// strap crosses...) comes in as the body's fit (Clothes.BODIES, set by clothes.gd), so one shader dresses every body.
render_mode unshaded, cull_back;

#define MAXL 14

uniform int layer_count = 0;
uniform vec4 cov_a[MAXL];   // torso low, high; arm low, high (rest height, m)
uniform vec4 cov_b[MAXL];   // hand; leg
uniform vec4 cov_c[MAXL];   // foot; neck
uniform vec4 cov_d[MAXL];   // head; face
uniform vec4 ink_a[MAXL];   // main colour rgb, pattern
uniform vec4 ink_b[MAXL];   // second colour rgb, thickness (m)
uniform vec4 form[MAXL];    // shape, side mask (1 left, 2 right, 3 both), open front width (m), flare
uniform vec4 wear[MAXL];    // tatter, grime, blood, detail (1 buttons, 2 zip, 3 laces, 4 jeans seams)

uniform vec3 key_dir = vec3(0.33, 0.82, 0.47);  // toward the light, world space (as the body's)
uniform float ambient = 0.13;
uniform float pixel_size = 1.0;
uniform vec3 tint_color = vec3(1.0, 0.35, 0.3);
uniform float tint_amount = 0.0;
// The body's fit (m, at rest): Clothes.BODIES[body]["fit"], sent by Clothes.put_on(). The defaults are the
// muscular male's.
uniform vec4 fit_face = vec4(0.03, 0.072, 1.69, 0.033);      // face plane z, face half width, eye height, eye half spacing
uniform vec4 fit_eyes = vec4(0.02, 0.055, 1.0, 1.725);       // lens size, temple x, waist height, top of the face
uniform vec4 fit_strap = vec4(0.16, 1.47, -0.15, 0.95);      // a strap across the chest: shoulder x, y; other hip x, y
uniform vec4 fit_back = vec4(0.024, 0.16, 0.085, -0.03);     // strap half width, pack half width, pack strap x, back z
uniform vec4 fit_front = vec4(0.04, 0.06, 0.13, 0.12);       // open front z, button z, leg seam x, foot middle x
uniform vec4 fit_legs = vec4(0.58, 0.78, 0.0, 0.0);          // where jeans wear pale on the thigh: low, high

varying vec3 rest;
varying vec4 area_a;        // one-hot areas 0-3 and 4-7, so the area can be told mid-triangle
varying vec4 area_b;
varying float v_push;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float b2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float b4(vec2 a) { return b2(0.5 * a) * 0.25 + b2(a); }

int area_at(float a, vec3 r) {
	int k = int(a + 0.5);
	if (k == 6 && r.z > fit_face.x && abs(r.x) < fit_face.y && r.y < fit_eyes.w) {
		k = 7;
	}
	return k;
}

vec2 range_of(int i, int k) {
	if (k == 0) return cov_a[i].xy;
	if (k == 1) return cov_a[i].zw;
	if (k == 2) return cov_b[i].xy;
	if (k == 3) return cov_b[i].zw;
	if (k == 4) return cov_c[i].xy;
	if (k == 5) return cov_c[i].zw;
	if (k == 6) return cov_d[i].xy;
	return cov_d[i].zw;
}

// Does layer i cover this spot? (Holes are seen to separately: they only matter for what shows.)
bool covers(int i, int k, vec3 r) {
	int shape = int(form[i].x + 0.5);
	int side = int(form[i].y + 0.5);
	if (abs(r.x) > 0.012) {
		if (r.x > 0.0 && (side & 1) == 0) return false;
		if (r.x < 0.0 && (side & 2) == 0) return false;
	}
	if (shape == 3) {
		// Lenses: two rounds over the eyes and a bridge between, and the arms back along the sides of the head.
		float ey = fit_face.z;
		if (k == 7) {
			vec2 e = vec2(abs(r.x) - fit_face.w, r.y - ey);
			return length(e * vec2(1.0, 1.25)) < fit_eyes.x || (abs(r.x) < fit_face.w * 0.4242424 && abs(r.y - ey - 0.006) < 0.004);
		}
		return k == 6 && abs(r.y - ey - 0.004) < 0.005 && abs(r.x) > fit_eyes.y && r.z > fit_face.x - 0.09;
	}
	vec2 lh = range_of(i, k);
	if (shape == 1) {
		// A strap across the body, shoulder to the other hip, front and back.
		if (k != 0) return false;
		float sx = (side == 2) ? -1.0 : 1.0;
		vec2 a = vec2(fit_strap.x * sx, fit_strap.y);
		vec2 b = vec2(fit_strap.z * sx, fit_strap.w);
		vec2 d = normalize(b - a);
		vec2 p = vec2(r.x, r.y) - a;
		float t = dot(p, d);
		return t > -0.02 && t < length(b - a) + 0.03 && abs(p.x * d.y - p.y * d.x) < fit_back.x;
	}
	if (r.y < lh.x || r.y > lh.y) return false;
	if (shape == 2) {
		// A pack on the back: the back of the torso inside the range, and straps over the shoulders in front.
		if (k != 0) return false;
		if (r.z < fit_back.w && abs(r.x) < fit_back.y) return true;
		return r.z > fit_back.w && abs(abs(r.x) - fit_back.z) < 0.022 && r.y > fit_eyes.z + 0.12;
	}
	if (shape == 5) {
		// The front only (an apron): the front of the torso and of the thighs, nothing behind or on the arms.
		if (k == 0) {
			// A bib apron: a wide skirt below the waist, a narrow bib above it.
			float bib = mix(lh.x, lh.y, 0.42);
			return r.z > fit_back.w + 0.04 && abs(r.x) < (r.y > bib ? 0.095 : 0.165);
		}
		if (k == 3) return r.z > 0.0;
		return false;
	}
	if (shape == 4 && k == 7 && abs(r.y - fit_face.z) < fit_eyes.x * 0.8 && abs(r.x) < fit_face.y * 0.8888889) {
		return false;      // the slot for the eyes in a balaclava
	}
	if (form[i].z > 0.0 && k == 0 && r.z > fit_front.x && abs(r.x) < form[i].z * 0.5) {
		return false;      // worn open down the front
	}
	return true;
}

bool holed(int i, vec3 r) {
	float t = wear[i].x;
	if (t <= 0.0) return false;
	// Ragged holes: a coarse chance that there is a tear here, broken up texel by texel at its edges.
	float big = hash(floor(r * 16.0) + float(i) * 7.31);
	float fine = hash(floor(r * 40.0) + float(i));
	return big < t * 0.45 && fine < 0.6 + (t * 0.45 - big) * 8.0;
}

void vertex() {
	rest = CUSTOM0.xyz;
	float a = CUSTOM0.w;
	area_a = vec4(a < 0.5 ? 1.0 : 0.0, abs(a - 1.0) < 0.5 ? 1.0 : 0.0, abs(a - 2.0) < 0.5 ? 1.0 : 0.0, abs(a - 3.0) < 0.5 ? 1.0 : 0.0);
	area_b = vec4(abs(a - 4.0) < 0.5 ? 1.0 : 0.0, abs(a - 5.0) < 0.5 ? 1.0 : 0.0, a > 5.5 ? 1.0 : 0.0, 0.0);
	int k = area_at(a, rest);
	float push = 0.0;
	for (int i = 0; i < MAXL; i++) {
		if (i >= layer_count) break;
		if (!covers(i, k, rest)) continue;
		float th = ink_b[i].w;
		int shape = int(form[i].x + 0.5);
		if (k == 0 && shape == 0) {
			th += 0.006;      // cloth stands a little off the torso: a shirt is not a second skin
		}
		if (shape == 2 && rest.z < fit_back.w) {
			// The pack: rounded, thickest in its middle.
			vec2 lh = cov_a[i].xy;
			float u = abs(rest.x) / fit_back.y;
			float v = abs(rest.y - (lh.x + lh.y) * 0.5) / max((lh.y - lh.x) * 0.5, 0.05);
			th *= clamp(1.0 - u * u * 0.7 - v * v * 0.7, 0.15, 1.0);
		}
		if (form[i].w > 0.0 && (k == 0 || k == 3)) {
			// Flare: it hangs away from the body below where it starts (a skirt, a cloak, a long coat).
			vec2 lh = range_of(i, k == 0 ? 0 : 3);
			float from = k == 0 ? fit_eyes.z : lh.y;
			th += form[i].w * max(min(from, fit_eyes.z) - rest.y, 0.0);
		}
		push = max(push, th);
	}
	v_push = push;
	VERTEX += NORMAL * (push + 0.003);
}

void fragment() {
	int k = 0;
	float best = area_a.x;
	if (area_a.y > best) { best = area_a.y; k = 1; }
	if (area_a.z > best) { best = area_a.z; k = 2; }
	if (area_a.w > best) { best = area_a.w; k = 3; }
	if (area_b.x > best) { best = area_b.x; k = 4; }
	if (area_b.y > best) { best = area_b.y; k = 5; }
	if (area_b.z > best) { best = area_b.z; k = 6; }
	k = area_at(float(k), rest);
	vec3 r = rest;
	int top = -1;
	for (int i = 0; i < MAXL; i++) {
		if (i >= layer_count) break;
		if (covers(i, k, r) && !holed(i, r)) {
			top = i;
			break;
		}
	}
	if (top < 0) {
		discard;
	}
	int pat = int(ink_a[top].w + 0.5);
	vec3 c1 = ink_a[top].rgb;
	vec3 c2 = ink_b[top].rgb;
	// Texels on the body at rest: across (a blend of x and z, so the sides are patterned too) and up.
	float across = r.x + r.z * (r.x >= 0.0 ? 0.6 : -0.6);
	vec2 tx = floor(vec2(across, r.y) * 40.0);
	float n = hash(vec3(tx, float(top)));

	vec3 nn = normalize(NORMAL);
	float I = ambient + 0.98 * max(dot(nn, normalize((VIEW_MATRIX * vec4(key_dir, 0.0)).xyz)), 0.0)
		+ 0.08 * max(nn.x * 0.7 - nn.y * 0.2 + nn.z * 0.2, 0.0);
	float shift = 0.0;        // shades darker (+) or lighter (-)
	bool second = false;      // drawn in the second colour
	if (pat == 0) {
		shift += (n - 0.5) * 0.5;                                     // plain weave
	} else if (pat == 1) {
		shift += mod(tx.x, 2.0) < 1.0 ? 0.45 : -0.1;                  // knit: ribs
		if (mod(tx.y, 6.0) < 1.0) shift += 0.3;
	} else if (pat == 2) {
		if (mod(tx.x + tx.y, 3.0) < 1.0) shift -= 0.5;              // denim: a twill of paler threads,
		second = n < 0.025;                                           // a fleck of the second colour,
		if (k == 3 && r.z > 0.02 && r.y > fit_legs.x && r.y < fit_legs.y) shift -= 0.7;   // and worn pale on the thighs
	} else if (pat == 3) {
		bool bx = mod(tx.x, 5.0) < 1.0;
		bool by = mod(tx.y, 5.0) < 1.0;
		second = bx || by;                                            // check
		if (bx && by) shift += 1.0;
	} else if (pat == 4) {
		second = mod(tx.y, 6.0) < 2.0;                                // stripes
	} else if (pat == 5) {
		I = mix(I, I * 1.35 - 0.12, 0.8);                             // leather: harder light, creases
		if (n < 0.08) shift += 1.0;
	} else if (pat == 6) {
		second = mod(tx.x + floor(tx.y / 2.0) * 2.0, 4.0) < 1.0 && mod(tx.y, 2.0) < 1.0;   // lace: open work
		if (second) discard;                                          // (the holes show what is under the layer: skin)
	} else if (pat == 7) {
		second = mod(tx.x + mod(floor(tx.y / 3.0), 2.0) * 2.0, 4.0) < 1.0 && mod(tx.y, 3.0) < 1.0;   // printed
	} else if (pat == 8) {
		I = I * 1.4 - 0.15;                                           // metal
	} else if (pat == 9) {
		I = I * 0.5 + (n < 0.2 ? 0.5 : 0.0);                          // glass: dark, with a glint
	}
	// Hems and cuffs: a shade darker along the edges of what it covers.
	vec2 lh = range_of(top, k);
	if (int(form[top].x + 0.5) == 0 && (r.y - lh.x < 0.012 || lh.y - r.y < 0.012)) shift += 0.8;
	// Front details.
	int det = int(wear[top].w + 0.5);
	if (k == 0 && r.z > fit_front.y) {
		if (det == 1 && abs(r.x) < 0.006 && mod(tx.y, 5.0) < 1.0) shift -= 1.5;     // buttons
		if (det == 2 && abs(r.x) < 0.004) { second = true; shift -= 0.5; }            // zip
	}
	if (det == 4 && k == 3 && abs(r.x) > fit_front.z - 0.02 && abs(abs(r.x) - fit_front.z) < 0.004) shift += 0.9;   // seams down the legs
	if (det == 3 && k == 4 && r.z > 0.03 && r.y > 0.035 && abs(abs(r.x) - fit_front.w) < 0.02 && mod(tx.y, 2.0) < 1.0) second = true;   // laces
	// Grime and blood.
	float g = wear[top].y;
	float bl = wear[top].z;
	vec3 base = second ? c2 : c1;
	// Grime gathers low and in patches; blood in splashes with spatter round them.
	float blot = hash(floor(r * 14.0) + 3.1) * 0.6 + hash(floor(r * 40.0) + 5.3) * 0.4;
	float low = clamp(1.0 - (r.y - 0.2) * 0.5, 0.4, 1.0);
	if (g > 0.0 && blot < g * 0.55 * low) {
		base = mix(base, vec3(0.3, 0.24, 0.16), 0.6);
		shift += 0.5;
	}
	float splash = hash(floor(r * 10.0) + 11.7);
	if (bl > 0.0 && (splash < bl * 0.3 && n < 0.85 || splash < bl * 0.45 && n < 0.15)) {
		base = mix(base, vec3(0.36, 0.05, 0.04), 0.85);
	}
	// Eight shades from the colour: lighter and warmer up the ramp, darker and cooler down it.
	float dith = (b4(floor(FRAGCOORD.xy / pixel_size)) - 0.5) * 0.14;
	float ix = clamp(floor(clamp((1.1 - (I + dith)) / 1.1, 0.0, 0.999) * 8.0 + shift + 0.5), 0.0, 7.0);
	vec3 lite = min(base * 1.3 + vec3(0.06, 0.05, 0.02), vec3(1.0));
	vec3 dark = base * 0.16 + vec3(0.03, 0.025, 0.05);
	float t = ix / 7.0;
	vec3 col = mix(lite, dark, t * t * 0.55 + t * 0.45);
	col = mix(col, tint_color, tint_amount);
	ALBEDO = pow(col, vec3(2.2));
}
