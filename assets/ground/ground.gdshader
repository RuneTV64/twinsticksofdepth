shader_type spatial;
// A whole level's ground on one mesh: every kind of dirt (and grass), laid out by a map that ground.gd paints.
// The borders between kinds wander and break up into single texels, so nothing meets on a straight line.
// It follows the season and the weather (seasons.gd).
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/ground/dirt_types.gdshaderinc"
#include "res://assets/ground/grass_types.gdshaderinc"

// The map, one texel to a quarter metre: r = the kind (its number x 16 / 255), g = for a road, how far across it
// this spot is (0 one edge .. 1 the other), b and a = the way its rows or its road run (x and z, as 0..1).
// The same picture is read twice: unsmoothed for the kind, smoothed for the rest.
uniform sampler2D kind_map : filter_nearest, repeat_disable;
uniform sampler2D aim_map : filter_linear, repeat_disable;
uniform vec4 map_rect = vec4(0.0, 0.0, 1.0, 1.0);     // what the map covers on the ground: x, z, width, depth
uniform float road_width = 4.0;
uniform float border = 0.5;                            // m the borders between kinds wander

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 texel = ground_texel(wp.xz);
	vec2 p = ground_point(texel);
	GroundEnv e = ground_env(ground_season);
	// Which kind: looked up a little way off (a slow wander plus a per-texel scatter), so borders are ragged.
	vec2 q = p + (vec2(gnoise(p * 1.1 + 2.0), gnoise(p * 1.1 + 31.0)) - 0.5) * 2.0 * border + (gh2(texel * 0.37) - 0.5) * 0.7 * border;
	int kind = int(floor(texture(kind_map, (ground_world(q) - map_rect.xy) / map_rect.zw).r * 255.0 / 16.0 + 0.5));
	vec4 aim = texture(aim_map, (ground_world(p) - map_rect.xy) / map_rect.zw);
	vec2 dir = aim.ba * 2.0 - 1.0;
	dir = length(dir) > 0.05 ? normalize(ground_frame(dir)) : vec2(1.0, 0.0);
	// (A turn keeps left and right as they were, so "how far across the road" needs no change.)
	float lat = (aim.g * 2.0 - 1.0) * road_width * 0.5;
	Ground g;
	if (kind >= GRASS_FIRST) {
		g = grass_pick(kind, p, texel, e);
	} else {
		g = dirt_pick(kind, p, texel, dir, lat, road_width * 0.5, e);
	}
	vec3 c = ground_color(g, texel);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/ground/ground_light.gdshaderinc"
