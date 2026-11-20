shader_type spatial;
// One kind of grass on its own, as part of the ground's surface: for a patch or a lawn. (A whole level's ground is
// ground.gdshader.) It follows the season and the weather; set season_override to pin a patch to its own.
#include "res://assets/ground/ground_lib.gdshaderinc"
#include "res://assets/ground/dirt_types.gdshaderinc"
#include "res://assets/ground/grass_types.gdshaderinc"

uniform int kind : hint_range(8, 10) = 8;           // 8 lawn, 9 meadow, 10 rough
uniform vec4 season_override = vec4(-1.0, 0.0, 0.0, 0.0);   // x < 0: follow the world's season

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 texel = ground_texel(wp.xz);
	vec2 p = ground_point(texel);
	GroundEnv e = ground_env(season_override.x < 0.0 ? ground_season : season_override);
	Ground g = grass_pick(kind, p, texel, e);
	vec3 c = ground_color(g, texel);
	ALBEDO=pow(c,vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

#include "res://assets/ground/ground_light.gdshaderinc"
