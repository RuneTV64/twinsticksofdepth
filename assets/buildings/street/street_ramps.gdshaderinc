// Made by source/gen_street_ramps.py. Don't edit: change the stops there and run it again.
// Every street material's 8-shade ramp, lightest (0) to darkest (7), as sRGB. Their numbers start at
// STREET_FIRST so they can share a `Ground` spot with the ground's own ramps.
const int STREET_FIRST = 100;
const int S_ASPHALT = 100;  // asphalt: pale when old and dry, near black new or wet
const int S_CONCRETE = 101; // kerbs and sidewalk slabs
const int S_YELLOW = 102;   // road paint: the centre line
const int S_WHITE = 103;    // road paint: stop lines and crossings
const int S_IRON = 104;     // manhole covers and drain grates: cast iron, rusting
const int S_STEEL = 105;    // galvanised steel: lamp posts and sign posts
const int S_RED = 106;      // sign paint: a stop sign
const int S_SIGN = 107;     // sign paint: a street name's green
const int S_GLOW = 108;     // a lit lamp's glass
const vec3 STREET_RAMPS[72] = vec3[72](
	vec3(0.639, 0.624, 0.604), vec3(0.547, 0.534, 0.519), vec3(0.457, 0.446, 0.435), vec3(0.372, 0.363, 0.354), vec3(0.296, 0.289, 0.286), vec3(0.229, 0.224, 0.230), vec3(0.170, 0.168, 0.182), vec3(0.114, 0.114, 0.137),
	vec3(0.894, 0.875, 0.824), vec3(0.807, 0.787, 0.736), vec3(0.715, 0.697, 0.650), vec3(0.612, 0.598, 0.567), vec3(0.507, 0.496, 0.485), vec3(0.399, 0.391, 0.404), vec3(0.300, 0.294, 0.322), vec3(0.204, 0.200, 0.239),
	vec3(0.957, 0.847, 0.408), vec3(0.890, 0.748, 0.314), vec3(0.812, 0.648, 0.234), vec3(0.702, 0.540, 0.198), vec3(0.582, 0.435, 0.176), vec3(0.452, 0.332, 0.167), vec3(0.337, 0.247, 0.155), vec3(0.227, 0.169, 0.141),
	vec3(0.965, 0.957, 0.925), vec3(0.893, 0.881, 0.840), vec3(0.812, 0.797, 0.753), vec3(0.705, 0.692, 0.659), vec3(0.588, 0.578, 0.560), vec3(0.463, 0.454, 0.457), vec3(0.347, 0.341, 0.359), vec3(0.235, 0.231, 0.263),
	vec3(0.576, 0.529, 0.486), vec3(0.494, 0.449, 0.415), vec3(0.412, 0.371, 0.349), vec3(0.336, 0.304, 0.302), vec3(0.267, 0.243, 0.256), vec3(0.204, 0.187, 0.211), vec3(0.151, 0.141, 0.168), vec3(0.102, 0.098, 0.125),
	vec3(0.855, 0.867, 0.878), vec3(0.759, 0.777, 0.793), vec3(0.660, 0.684, 0.705), vec3(0.555, 0.581, 0.609), vec3(0.454, 0.480, 0.514), vec3(0.357, 0.382, 0.420), vec3(0.266, 0.286, 0.325), vec3(0.176, 0.192, 0.231),
	vec3(0.961, 0.604, 0.471), vec3(0.905, 0.425, 0.314), vec3(0.835, 0.273, 0.189), vec3(0.723, 0.206, 0.162), vec3(0.597, 0.156, 0.146), vec3(0.458, 0.122, 0.139), vec3(0.339, 0.100, 0.127), vec3(0.227, 0.082, 0.114),
	vec3(0.608, 0.847, 0.667), vec3(0.417, 0.726, 0.523), vec3(0.260, 0.610, 0.399), vec3(0.202, 0.506, 0.332), vec3(0.156, 0.410, 0.276), vec3(0.122, 0.320, 0.231), vec3(0.094, 0.243, 0.188), vec3(0.067, 0.169, 0.145),
	vec3(1.000, 0.973, 0.871), vec3(1.000, 0.941, 0.763), vec3(0.995, 0.900, 0.649), vec3(0.975, 0.831, 0.514), vec3(0.904, 0.730, 0.407), vec3(0.783, 0.598, 0.326), vec3(0.615, 0.450, 0.266), vec3(0.431, 0.298, 0.212)
);
