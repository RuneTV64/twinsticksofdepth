// Made by source/gen_street_ramps.py. Don't edit: change the stops there and run it again.
// Every street material's 8-shade ramp, lightest (0) to darkest (7), as sRGB. Their numbers start at
// STREET_FIRST so they can share a `Ground` spot with the ground's own ramps.
const int STREET_FIRST = 100;
const int S_ASPHALT = 100;  // asphalt: pale when old and dry, near black new or wet
const int S_CONCRETE = 101; // kerbs and sidewalk slabs
const int S_YELLOW = 102;   // road paint: the centre line
const int S_WHITE = 103;    // road paint: stop lines and crossings
const int S_IRON = 104;     // manhole covers and drain grates: cast iron, rusting
const vec3 STREET_RAMPS[40] = vec3[40](
	vec3(0.639, 0.624, 0.604), vec3(0.547, 0.534, 0.519), vec3(0.457, 0.446, 0.435), vec3(0.372, 0.363, 0.354), vec3(0.296, 0.289, 0.286), vec3(0.229, 0.224, 0.230), vec3(0.170, 0.168, 0.182), vec3(0.114, 0.114, 0.137),
	vec3(0.894, 0.875, 0.824), vec3(0.807, 0.787, 0.736), vec3(0.715, 0.697, 0.650), vec3(0.612, 0.598, 0.567), vec3(0.507, 0.496, 0.485), vec3(0.399, 0.391, 0.404), vec3(0.300, 0.294, 0.322), vec3(0.204, 0.200, 0.239),
	vec3(0.957, 0.847, 0.408), vec3(0.890, 0.748, 0.314), vec3(0.812, 0.648, 0.234), vec3(0.702, 0.540, 0.198), vec3(0.582, 0.435, 0.176), vec3(0.452, 0.332, 0.167), vec3(0.337, 0.247, 0.155), vec3(0.227, 0.169, 0.141),
	vec3(0.965, 0.957, 0.925), vec3(0.893, 0.881, 0.840), vec3(0.812, 0.797, 0.753), vec3(0.705, 0.692, 0.659), vec3(0.588, 0.578, 0.560), vec3(0.463, 0.454, 0.457), vec3(0.347, 0.341, 0.359), vec3(0.235, 0.231, 0.263),
	vec3(0.576, 0.529, 0.486), vec3(0.494, 0.449, 0.415), vec3(0.412, 0.371, 0.349), vec3(0.336, 0.304, 0.302), vec3(0.267, 0.243, 0.256), vec3(0.204, 0.187, 0.211), vec3(0.151, 0.141, 0.168), vec3(0.102, 0.098, 0.125)
);
