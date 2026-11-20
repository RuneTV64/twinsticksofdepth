shader_type spatial;
// A plain solid colour for the test level's walls, crates and doors, with the cutaway (cutaway.gdshaderinc): it
// opens up where it stands between the camera and the player. The real building pieces will have their own
// shaders and include the cutaway the same way.
#include "res://cutaway.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.5, 0.5, 0.5);
uniform float metal = 0.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway_hidden(wp, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = 1.0 - 0.5 * metal;
}
