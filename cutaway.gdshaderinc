// Cutaway: whatever stands between the camera and the player is cut open, so the player is never hidden behind a
// wall or a building. Any spatial shader can use it: include this file, pass the fragment's world position, and
// discard when cutaway_hidden() says so. cutaway.gd keeps the values up to date; they are project-wide shader
// globals (project.godot, [shader_globals]).
//
// What is cut: a fragment nearer the camera than the player, standing higher than the keep-below height (so the
// feet of walls stay, and you can still see where they are), whose line of sight carries on to within `radius` of
// the player. The edge of the opening is dithered, in screen pixels, to match the art.
global uniform vec3 cutaway_focus;   // the player's chest, in the world
global uniform vec3 cutaway_view;    // the way the camera looks (unit)
global uniform vec4 cutaway_shape;   // x = radius (m), y = soft edge (m), z = keep everything below this height (world y), w = 0 off / 1 on

bool cutaway_hidden(vec3 wp, vec2 frag) {
	if (cutaway_shape.w < 0.5 || wp.y < cutaway_shape.z || cutaway_view.y > -0.05) {
		return false;
	}
	// Only what is nearer the camera than the player.
	vec2 flat_view = normalize(cutaway_view.xz);
	if (dot(wp.xz - cutaway_focus.xz, flat_view) > -0.25) {
		return false;
	}
	// Follow this fragment's line of sight on down to the player's height: is the player (or near it) behind it?
	float t = (cutaway_focus.y - wp.y) / cutaway_view.y;
	if (t <= 0.0) {
		return false;
	}
	float d = length((wp + cutaway_view * t).xz - cutaway_focus.xz);
	if (d >= cutaway_shape.x) {
		return false;
	}
	// A dithered edge: fully open inside, thinning out over the soft band.
	float open_amount = clamp((cutaway_shape.x - d) / max(cutaway_shape.y, 0.001), 0.0, 1.0);
	int bx = int(mod(frag.x, 4.0));
	int by = int(mod(frag.y, 4.0));
	float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return open_amount > (bayer[by * 4 + bx] + 0.5) / 16.0;
}
