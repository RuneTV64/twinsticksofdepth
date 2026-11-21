shader_type spatial;
// The outline round a character (owner, 21 Nov 2026: zombies and people must stand out at every zoom).
// A second drawing of the character's own mesh, put on as its material_overlay by the game's scripts (outline.gd),
// so the approved character shaders and models are not touched. The copy is pushed out along the surface by a set
// number of screen pixels and drawn inside out (only its back faces): the body itself hides all of it but the rim.
//
// - The same width on screen at every zoom (`width_px` at 900 pixels high, scaled with the window).
// - Unshaded, one flat colour: the kind's own (outline.gd sets one shared material per kind).
// - Wound insides are left out: the inner surfaces under the holes in a zombie's skin (part codes 12 to 15 in
//   COLOR.a, as the decay shader reads them) are neither pushed out nor drawn, so no rim is drawn inside a wound.
// - It fades with the zombie: `dissolve` is the same per-zombie value the decay shader reads (pinned to the same
//   slot), and a dither takes the outline away a little ahead of the body.
// - Flashes: `outline_flash` turns it to the kind's flash colour (an enemy you hadn't seen for a while comes into
//   view); `outline_warn` to the warning colour and a pixel wider (a zombie winding up a grab or a lunge, a raider
//   lining up a shot). Both are per-character values in slots no character shader uses.
// - No cutaway: the bodies aren't cut, so their outlines aren't either. The night layer (fog.gd) is drawn over it
//   like everything else, so in the dark the outline is as dark as the body.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque, skip_vertex_transform;

uniform vec3 color : source_color = vec3(0.09, 0.075, 0.06);
uniform vec3 flash_color : source_color = vec3(0.6, 0.6, 0.5);
uniform vec3 warn_color : source_color = vec3(1.0, 0.62, 0.12);
uniform float width_px = 2.0;
uniform float warn_extra_px = 1.0;
// Part codes from this one up are wound insides (zombies: 12). Living bodies have none: 99.
uniform float wound_codes_from = 99.0;

instance uniform float dissolve : instance_index(8) = 0.0;      // the decay shader's own slot 8
instance uniform float outline_flash : instance_index(14) = 0.0;
instance uniform float outline_warn : instance_index(15) = 0.0;

varying float v_wound;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	float code = floor(COLOR.a * 15.0 + 0.5);
	v_wound = code >= wound_codes_from - 0.5 ? 1.0 : 0.0;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * view;
	vec2 n_clip = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy;
	float px = (width_px + warn_extra_px * step(0.5, outline_warn)) * VIEWPORT_SIZE.y / 900.0;
	if (v_wound < 0.5 && length(n_clip) > 1e-5) {
		// Pixels to clip space: 2 / size per pixel, times w so it holds after the divide.
		clip.xy += normalize(n_clip) * px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
	VERTEX = view.xyz;
	NORMAL = n_view;
}

void fragment() {
	if (v_wound > 0.5) {
		discard;
	}
	if (dissolve > 0.0 && bayer4(FRAGCOORD.xy) < dissolve * 1.6) {
		discard;   // a step ahead of the body, so no rim is ever left round nothing
	}
	vec3 c = color;
	if (outline_flash > 0.5) {
		c = flash_color;
	}
	if (outline_warn > 0.5) {
		c = warn_color;
	}
	ALBEDO = c;
}
