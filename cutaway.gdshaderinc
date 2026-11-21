// Cutaway: whatever stands between the camera and the player is cut open, so the player is never hidden behind a
// wall or a building. Any spatial shader can use it: include this file, pass the fragment's world position, and
// discard when cutaway_hidden() says so. cutaway.gd keeps the values up to date; they are project-wide shader
// globals (project.godot, [shader_globals]).
//
// Three openings, all the same idea (does this fragment hide something the player needs to see?):
//   - round the player (below);
//   - round what the crosshair is on (the cursor cutaway);
//   - the whole building the player is inside: its walls come down to the keep height wherever they hide its
//     floor, and everything over the player's storey (upper floors, the roof) goes.
// Window glass is never cut: glass.gdshader draws it at half strength where the wall round it has gone.
//
// What is cut round the player: a fragment nearer the camera than the player, standing higher than the keep-below height (so the
// feet of walls stay, and you can still see where they are), whose line of sight carries on to within `radius` of
// the player. The edge of the opening is dithered, in screen pixels, to match the art.
global uniform vec3 cutaway_focus;   // the player's chest, in the world
global uniform vec3 cutaway_view;    // the way the camera looks (unit)
global uniform vec4 cutaway_shape;   // x = radius (m), y = soft edge (m), z = keep everything below this height (world y), w = 0 off / 1 on

// The same opening round what the crosshair is on (cutaway.gd: the cursor cutaway). xyz = the spot the
// crosshair is on, in the world; w = how far round it the opening reaches (0 = none).
global uniform vec4 cutaway_aim;
global uniform vec4 cutaway_aim2;    // x = soft edge (m), y = keep everything below this height (world y)

// The building the player is inside (cutaway.gd, Cutaway.add_building).
global uniform vec4 cutaway_room;    // its footprint: min x, min z, max x, max z
global uniform vec4 cutaway_room2;   // x = the floor the player is on, y = keep everything below this, z = the lid: everything over this goes, w = how far open (0 to 1)
global uniform vec4 cutaway_room3;   // x = how far outside the footprint the lid reaches (eaves), y = and above what height out there

float cutaway_bayer(vec2 frag) {
	int bx = int(mod(frag.x, 4.0));
	int by = int(mod(frag.y, 4.0));
	float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (bayer[by * 4 + bx] + 0.5) / 16.0;
}

// How far open the opening toward `focus` is at this fragment (0 = not at all, 1 = fully): it is nearer the
// camera than the focus, above `keep`, and its line of sight carries on to within `radius` of the focus.
float cutaway_round(vec3 wp, vec3 focus, float radius, float soft, float keep) {
	if (wp.y < keep) {
		return 0.0;
	}
	// Only what is nearer the camera than the focus.
	vec2 flat_view = normalize(cutaway_view.xz);
	if (dot(wp.xz - focus.xz, flat_view) > -0.25) {
		return 0.0;
	}
	// Follow this fragment's line of sight on down to the focus's height: is the focus (or near it) behind it?
	float t = (focus.y - wp.y) / cutaway_view.y;
	if (t <= 0.0) {
		return 0.0;
	}
	float d = length((wp + cutaway_view * t).xz - focus.xz);
	// A soft edge: fully open inside, thinning out over the soft band (dithered by whoever asks).
	return clamp((radius - d) / max(soft, 0.001), 0.0, 1.0);
}

// Over the storey the player is on, in the building they are in: upper floors, the roof.
bool cutaway_lid(vec3 wp) {
	if (cutaway_room2.w <= 0.0 || wp.y < cutaway_room2.z) {
		return false;
	}
	if (all(greaterThan(wp.xz, cutaway_room.xy)) && all(lessThan(wp.xz, cutaway_room.zw))) {
		return true;
	}
	float e = cutaway_room3.x;
	return wp.y > cutaway_room3.y && all(greaterThan(wp.xz, cutaway_room.xy - e)) && all(lessThan(wp.xz, cutaway_room.zw + e));
}

// Standing above the keep height and hiding some of the floor of the building the player is in.
bool cutaway_wall(vec3 wp) {
	if (cutaway_room2.w <= 0.0 || wp.y < cutaway_room2.y) {
		return false;
	}
	float t = (cutaway_room2.x - wp.y) / cutaway_view.y;
	vec2 at = (wp + cutaway_view * t).xz;
	return all(greaterThan(at, cutaway_room.xy)) && all(lessThan(at, cutaway_room.zw));
}

// How far open the cutaway is at this fragment, all three openings together. `walls` false leaves out the
// building-wide cutting of walls (for things that should stand while you are indoors: stairs).
float cutaway_open(vec3 wp, bool walls) {
	if (cutaway_shape.w < 0.5 || cutaway_view.y > -0.05) {
		return 0.0;
	}
	float a = cutaway_round(wp, cutaway_focus, cutaway_shape.x, cutaway_shape.y, cutaway_shape.z);
	if (cutaway_aim.w > 0.01) {
		a = max(a, cutaway_round(wp, cutaway_aim.xyz, cutaway_aim.w, cutaway_aim2.x, cutaway_aim2.y));
	}
	if (cutaway_lid(wp) || (walls && cutaway_wall(wp))) {
		a = max(a, cutaway_room2.w);
	}
	return a;
}

bool cutaway_hidden(vec3 wp, vec2 frag) {
	return cutaway_open(wp, true) > cutaway_bayer(frag);
}

// For stairs and the like: they open round the player and the crosshair and under the lid, but stand
// otherwise, so you can see the way up from across the house.
bool cutaway_hidden_standing(vec3 wp, vec2 frag) {
	return cutaway_open(wp, false) > cutaway_bayer(frag);
}
