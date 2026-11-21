// The house's shared tools. Every house shader starts by including this.
//
// The same look as the ground (8-shade 3D-Pixel): surfaces are drawn on a grid of world-space texels, 16 to the
// metre; each material is one 8-shade ramp; a pattern moves a spot lighter or darker along its ramp; the step
// between shades is Bayer-dithered. The noise, the dither and the season come from the ground's own library, so
// a house and the ground it stands on change with the weather together.
//
// Three things change how a part looks, and none of them needs a different mesh:
//   the season and the weather   `ground_season`, project-wide (seasons.gd): wet, snow, frost, time of year
//   how worn it is               `wear`: 0 sound, 1 damaged, 2 about to give (breakable.gd's three stages)
//   the cutaway                  it opens up when it stands between the camera and the player
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/buildings/house/house_ramps.gdshaderinc"
#include "res://cutaway.gdshaderinc"

uniform float wear : hint_range(0.0, 2.0) = 0.0;
uniform vec4 season_override = vec4(-1.0, 0.0, 0.0, 0.0);   // x < 0: follow the world's season

// One spot of a surface: which ramp, how light along it (0 darkest .. 1 lightest), and whether the ramp is one
// of the ground's (snow, moss, leaves, ice, stone) or one of the house's own.
struct Surf {
	int ramp;
	float v;
	bool ground;
};

Surf surf(int ramp, float v) {
	return Surf(ramp, v, false);
}

Surf gsurf(int ramp, float v) {
	return Surf(ramp, v, true);
}

GroundEnv house_env() {
	return ground_env(season_override.x < 0.0 ? ground_season : season_override);
}

// The colour (sRGB) of a spot: its place on its ramp, dithered into one of the 8 shades.
vec3 house_color(Surf s, vec2 texel) {
	float f = (1.0 - clamp(s.v, 0.0, 1.0)) * 8.0 + (gbayer(texel) - 0.5) * 0.6;
	int ix = clamp(int(floor(f)), 0, 7);
	return s.ground ? GROUND_RAMPS[s.ramp * 8 + ix] : HOUSE_RAMPS[s.ramp * 8 + ix];
}

// A wall's own flat coordinates, in metres: x along it, y up it. `n` is the surface's world normal.
vec2 house_wall_uv(vec3 world, vec3 n) {
	return vec2(abs(n.x) > abs(n.z) ? world.z : world.x, world.y);
}

vec2 house_texel(vec2 uv) {
	return floor(uv * GROUND_TEXELS);
}

vec2 house_point(vec2 texel) {
	return (texel + 0.5) / GROUND_TEXELS;
}

// Bare wood, with a little grain along `p.x`.
Surf house_wood(vec2 p, float v) {
	return surf(H_WOOD, v + (gnoise(vec2(p.x * 2.0, p.y * 22.0)) - 0.5) * 0.12);
}

// What the weather leaves on a surface that faces up or stands in it. `up` 0 a wall .. 1 flat; `y` its height
// above the ground it stands on, in metres (snow drifts against the foot of a wall).
Surf house_weather(Surf s, vec2 p, vec2 texel, GroundEnv e, float up, float y) {
	// Wet: darker, in streaks down a wall.
	float streak = gnoise(vec2(p.x * 5.0, p.y * mix(0.6, 5.0, up)));
	s.v -= e.wet * (0.1 + 0.07 * streak);
	// A dry summer bleaches it a little.
	s.v += e.dry * 0.03;
	// Hoar frost: a scatter of pale texels, thick on what faces the sky.
	if (gh1(texel * 1.37 + 3.1) < e.frost * mix(0.1, 0.28, up)) {
		s = gsurf(R_ICE, 0.86);
	}
	// Snow: it lies on what faces up, clings in flecks to walls, and drifts against their feet.
	float lie = gfbm(p * 0.9 + 4.0);
	if (up > 0.5 && lie < e.snow * 1.1 - 0.1) {
		s = gsurf(R_SNOW, 0.86 + (gnoise(p * 3.0) - 0.5) * 0.2);
	} else if (up <= 0.5 && (y < e.snow * 0.45 * (0.5 + gnoise(vec2(p.x * 1.4, 2.0))) || gh1(texel * 0.91) < e.snow * 0.07)) {
		s = gsurf(R_SNOW, 0.84);
	}
	return s;
}
