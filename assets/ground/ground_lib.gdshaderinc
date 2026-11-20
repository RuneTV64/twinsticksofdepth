// The ground's shared tools: the texel grid, noise, the season, and the 8-shade pick. Every ground shader starts
// by including this. (8-shade 3D-Pixel: each material is one 8-shade ramp; patterns move a spot lighter or darker
// along its ramp; the step between shades is Bayer-dithered; a little grit nudges odd pixels a shade.)
//
// The ground is drawn on a grid of world-space texels (GROUND_TEXELS to the metre), so it is pixel art that stays
// put on the ground as the camera pans, whatever the zoom.
#include "res://assets/ground/ground_ramps.gdshaderinc"

const float GROUND_TEXELS = 16.0;

// The time of year and the weather, project-wide (seasons.gd sets it; project.godot declares it):
//   x  time of year: 0 spring, 1 summer, 2 autumn, 3 winter (3.5 = late winter; 4 is spring again)
//   y  wetness: 0 bone dry .. 1 raining now
//   z  snow lying: 0 none .. 1 deep
//   w  frost: 0 none .. 1 hard frost
global uniform vec4 ground_season;

// What the season comes to at one spot. Made once per pixel by ground_env() and handed to every module.
struct GroundEnv {
	float spring;
	float summer;
	float autumn;
	float winter;
	float wet;
	float snow;
	float frost;
	float dry;      // summer drought: dry season and no rain
};

// One spot of ground: which ramp it is on, and how light along it (0 darkest .. 1 lightest).
struct Ground {
	int ramp;
	float v;
};

float _season_w(float x, float c) {
	float d = abs(x - c);
	return clamp(1.0 - min(d, 4.0 - d), 0.0, 1.0);
}

// `s` is ground_season, or a material's own override of it.
GroundEnv ground_env(vec4 s) {
	GroundEnv e;
	float x = mod(s.x, 4.0);
	e.spring = _season_w(x, 0.0);
	e.summer = _season_w(x, 1.0);
	e.autumn = _season_w(x, 2.0);
	e.winter = _season_w(x, 3.0);
	e.wet = clamp(s.y, 0.0, 1.0);
	e.snow = clamp(s.z, 0.0, 1.0);
	e.frost = clamp(s.w, 0.0, 1.0);
	e.dry = e.summer * (1.0 - e.wet);
	return e;
}

// ---- noise (all of it takes metres and is asked at texel centres, so it comes out as crisp texels)
float gh1(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 gh2(vec2 p) {
	float n = gh1(p);
	return vec2(n, gh1(p + n * 37.0 + 11.7));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(gh1(i), gh1(i + vec2(1.0, 0.0)), f.x), mix(gh1(i + vec2(0.0, 1.0)), gh1(i + vec2(1.0, 1.0)), f.x), f.y);
}

float gfbm(vec2 p) {
	return gnoise(p) * 0.58 + gnoise(p * 2.1 + 17.3) * 0.28 + gnoise(p * 4.3 + 5.1) * 0.14;
}

// A scatter of cells (lumps, stones, plates, leaves): the nearest cell's distance, the next nearest's, the
// nearest's own random number, and the way to its middle.
struct GroundCell {
	float d1;
	float d2;
	float id;
	vec2 to;
};

GroundCell gcell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	GroundCell c;
	c.d1 = 9.0;
	c.d2 = 9.0;
	c.id = 0.0;
	c.to = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + gh2(i + g) - f;
			float d = length(r);
			if (d < c.d1) {
				c.d2 = c.d1;
				c.d1 = d;
				c.id = gh1(i + g + 3.7);
				c.to = r;
			} else if (d < c.d2) {
				c.d2 = d;
			}
		}
	}
	return c;
}

float gbayer(vec2 texel) {
	int bx = int(mod(texel.x, 4.0));
	int by = int(mod(texel.y, 4.0));
	float b[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (b[by * 4 + bx] + 0.5) / 16.0;
}

// The texel grid is turned to face the camera, so its texels are square to the screen and not diamonds. The
// camera is set 45 degrees round and never turns (camera_rig.gd yaw_deg); if that changes, change this to match.
// "Frame" below means the ground measured that way: x across the screen, y down it, in metres.
const float GROUND_TURN = 0.70710678;     // cos and sin of 45 degrees

vec2 ground_frame(vec2 world_xz) {
	return vec2(world_xz.x - world_xz.y, world_xz.x + world_xz.y) * GROUND_TURN;
}

vec2 ground_world(vec2 frame) {
	return vec2(frame.x + frame.y, frame.y - frame.x) * GROUND_TURN;
}

// The texel a world position is in, and that texel's centre in metres (in the frame).
vec2 ground_texel(vec2 world_xz) {
	return floor(ground_frame(world_xz) * GROUND_TEXELS);
}

vec2 ground_point(vec2 texel) {
	return (texel + 0.5) / GROUND_TEXELS;
}

// The colour (sRGB) of a spot: its place on its ramp, dithered into one of the 8 shades, with a little grit.
vec3 ground_color(Ground g, vec2 texel) {
	float f = (1.0 - clamp(g.v, 0.0, 1.0)) * 8.0 + (gbayer(texel) - 0.5) * 0.6;
	float grit = gh1(texel * 0.731 + 9.1);
	f += grit > 0.955 ? 1.0 : (grit < 0.045 ? -1.0 : 0.0);
	int ix = clamp(int(floor(f)), 0, 7);
	return GROUND_RAMPS[g.ramp * 8 + ix];
}
