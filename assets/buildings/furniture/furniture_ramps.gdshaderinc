// Made by source/gen_furniture_ramps.py. Don't edit: change the stops there and run it again.
// What furniture is covered in and made of: 8-shade ramps, lightest (0) to darkest (7), as sRGB. Their
// numbers start at FURN_FIRST, after the house's own ramps.
const int FURN_FIRST = 16;
const int F_RUST = 16;   // upholstery and blankets: brick red
const int F_MOSS = 17;   // upholstery and blankets: olive
const int F_DENIM = 18;  // upholstery and blankets: blue
const int F_LINEN = 19;  // sheets, pillows, mattress ticking
const int F_IRON = 20;   // cast iron: a stove
const int F_ENAMEL = 21; // white enamel: a fridge
const int F_EMBER = 22;  // fire behind a stove's door
const int F_BRASS = 23;  // knobs and handles
const int F_BRICK = 24;  // a fireplace's brick
const int F_LACQUER = 25;// a piano's black lacquer
const int F_SCREEN = 26; // a television's glass, dark or lit
const int F_BEIGE = 27;  // old beige plastic: a phone, a lamp base
const int F_STEEL = 28;  // stainless steel: a sink, a bin
const vec3 FURN_RAMPS[104] = vec3[104](
	vec3(0.878, 0.643, 0.549), vec3(0.798, 0.518, 0.432), vec3(0.710, 0.401, 0.332), vec3(0.603, 0.311, 0.278), vec3(0.493, 0.240, 0.235), vec3(0.381, 0.186, 0.204), vec3(0.282, 0.142, 0.173), vec3(0.188, 0.102, 0.141),
	vec3(0.804, 0.824, 0.627), vec3(0.696, 0.725, 0.511), vec3(0.588, 0.625, 0.403), vec3(0.478, 0.522, 0.323), vec3(0.379, 0.424, 0.262), vec3(0.289, 0.329, 0.222), vec3(0.213, 0.245, 0.185), vec3(0.141, 0.165, 0.149),
	vec3(0.769, 0.824, 0.894), vec3(0.650, 0.720, 0.822), vec3(0.534, 0.617, 0.746), vec3(0.426, 0.514, 0.657), vec3(0.333, 0.416, 0.562), vec3(0.255, 0.322, 0.464), vec3(0.188, 0.238, 0.362), vec3(0.125, 0.157, 0.259),
	vec3(0.984, 0.969, 0.918), vec3(0.937, 0.915, 0.850), vec3(0.878, 0.850, 0.776), vec3(0.784, 0.754, 0.682), vec3(0.670, 0.641, 0.584), vec3(0.536, 0.511, 0.481), vec3(0.401, 0.383, 0.381), vec3(0.267, 0.255, 0.282),
	vec3(0.541, 0.525, 0.518), vec3(0.452, 0.438, 0.441), vec3(0.367, 0.356, 0.370), vec3(0.297, 0.289, 0.311), vec3(0.235, 0.228, 0.257), vec3(0.179, 0.174, 0.205), vec3(0.131, 0.129, 0.159), vec3(0.086, 0.086, 0.114),
	vec3(0.984, 0.984, 0.965), vec3(0.933, 0.937, 0.920), vec3(0.869, 0.878, 0.865), vec3(0.771, 0.784, 0.780), vec3(0.654, 0.670, 0.679), vec3(0.520, 0.536, 0.562), vec3(0.389, 0.401, 0.436), vec3(0.259, 0.267, 0.306),
	vec3(1.000, 0.941, 0.722), vec3(1.000, 0.852, 0.520), vec3(0.992, 0.750, 0.344), vec3(0.958, 0.611, 0.245), vec3(0.869, 0.469, 0.180), vec3(0.726, 0.326, 0.149), vec3(0.549, 0.230, 0.134), vec3(0.361, 0.149, 0.125),
	vec3(0.965, 0.886, 0.627), vec3(0.897, 0.788, 0.484), vec3(0.819, 0.686, 0.357), vec3(0.707, 0.574, 0.281), vec3(0.586, 0.464, 0.227), vec3(0.456, 0.356, 0.196), vec3(0.339, 0.266, 0.171), vec3(0.227, 0.180, 0.149),
	vec3(0.878, 0.627, 0.533), vec3(0.789, 0.497, 0.403), vec3(0.697, 0.382, 0.292), vec3(0.598, 0.310, 0.239), vec3(0.495, 0.248, 0.198), vec3(0.388, 0.194, 0.171), vec3(0.283, 0.147, 0.141), vec3(0.180, 0.102, 0.110),
	vec3(0.541, 0.455, 0.400), vec3(0.420, 0.343, 0.306), vec3(0.311, 0.244, 0.225), vec3(0.237, 0.186, 0.185), vec3(0.176, 0.139, 0.154), vec3(0.129, 0.103, 0.131), vec3(0.091, 0.074, 0.105), vec3(0.055, 0.047, 0.078),
	vec3(0.933, 0.965, 1.000), vec3(0.772, 0.853, 0.935), vec3(0.608, 0.726, 0.844), vec3(0.438, 0.556, 0.673), vec3(0.299, 0.401, 0.505), vec3(0.192, 0.262, 0.339), vec3(0.118, 0.164, 0.217), vec3(0.055, 0.078, 0.110),
	vec3(0.949, 0.910, 0.816), vec3(0.882, 0.834, 0.713), vec3(0.806, 0.750, 0.611), vec3(0.703, 0.642, 0.512), vec3(0.584, 0.528, 0.418), vec3(0.449, 0.407, 0.328), vec3(0.325, 0.296, 0.249), vec3(0.204, 0.188, 0.173),
	vec3(0.933, 0.941, 0.949), vec3(0.839, 0.854, 0.868), vec3(0.739, 0.760, 0.781), vec3(0.620, 0.645, 0.673), vec3(0.504, 0.530, 0.561), vec3(0.389, 0.413, 0.445), vec3(0.280, 0.300, 0.328), vec3(0.173, 0.188, 0.212)
);
