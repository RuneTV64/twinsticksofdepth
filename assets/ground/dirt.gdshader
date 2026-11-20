shader_type spatial;
// One kind of dirt on its own: for a patch, a path, a floor of earth. (A whole level's ground, with every kind
// on one mesh and soft borders between them, is ground.gdshader, driven by ground.gd.)
// It follows the season and the weather (seasons.gd); set season_override to pin a patch to its own (under a
// roof it never rains).
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/ground/dirt_types.gdshaderinc"

uniform int kind : hint_range(0, 4) = 0;            // 0 soil, 1 farm, 2 road, 3 clay, 4 mud
uniform vec2 direction = vec2(1.0, 0.0);            // the way the rows or the road run, on the ground (x, z)
uniform vec2 road_point = vec2(0.0, 0.0);           // road: any point on its middle line (x, z)
uniform float road_width = 4.0;
uniform vec4 season_override = vec4(-1.0, 0.0, 0.0, 0.0);   // x < 0: follow the world's season

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 texel = ground_texel(wp.xz);
	vec2 p = ground_point(texel);
	GroundEnv e = ground_env(season_override.x < 0.0 ? ground_season : season_override);
	vec2 dir = normalize(ground_frame(direction));
	float lat = dot(p - ground_frame(road_point), vec2(-dir.y, dir.x));
	Ground g = dirt_pick(kind, p, texel, dir, lat, road_width * 0.5, e);
	vec3 c = ground_color(g, texel);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/ground/ground_light.gdshaderinc"
