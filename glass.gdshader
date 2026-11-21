shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Window glass (solid.gd, Solid.pane). Glass is never cut away: where the cutaway has opened the wall round
// it, the pane is still drawn, at half strength (owner, 21 Nov 2026), so you can always see where the windows
// are. Glass over the storey you are on, in the building you are in, goes with the rest of that storey.
// A plain stand-in look, like the rest of the window.
#include "res://cutaway.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.6, 0.8, 0.95, 0.28);
uniform float cut_alpha = 0.5;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway_lid(wp) && cutaway_room2.w > cutaway_bayer(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.1;
	ALPHA = mix(tint.a, max(tint.a, cut_alpha), cutaway_open(wp, true));
}
