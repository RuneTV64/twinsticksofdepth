// Made by source/gen_house_ramps.py. Don't edit: change the stops there and run it again.
// Every house material's 8-shade ramp, lightest (0) to darkest (7), as sRGB.
const int H_PAINT = 0;    // painted clapboard: cream
const int H_SAGE = 1;     // painted clapboard: sage green
const int H_SLATE = 2;    // painted clapboard: slate blue
const int H_WOOD = 3;     // bare weathered wood: silver-grey
const int H_PLASTER = 4;  // inside wall plaster
const int H_SHINGLE = 5;  // roof shingles: weathered grey-brown
const int H_FLOOR = 6;    // floorboards: warm, worn
const int H_TRIM = 7;     // painted trim, doors, stairs: off-white
const vec3 HOUSE_RAMPS[64] = vec3[64](
	vec3(0.957, 0.933, 0.863), vec3(0.894, 0.859, 0.769), vec3(0.820, 0.776, 0.675), vec3(0.713, 0.667, 0.580), vec3(0.592, 0.549, 0.489), vec3(0.457, 0.424, 0.399), vec3(0.339, 0.315, 0.316), vec3(0.227, 0.212, 0.235),
	vec3(0.812, 0.863, 0.753), vec3(0.713, 0.778, 0.663), vec3(0.613, 0.687, 0.573), vec3(0.508, 0.582, 0.481), vec3(0.406, 0.475, 0.396), vec3(0.307, 0.365, 0.318), vec3(0.225, 0.270, 0.251), vec3(0.149, 0.180, 0.188),
	vec3(0.784, 0.839, 0.878), vec3(0.681, 0.745, 0.798), vec3(0.578, 0.649, 0.714), vec3(0.475, 0.546, 0.620), vec3(0.379, 0.443, 0.521), vec3(0.289, 0.339, 0.418), vec3(0.213, 0.250, 0.322), vec3(0.141, 0.165, 0.227),
	vec3(0.788, 0.718, 0.612), vec3(0.696, 0.626, 0.531), vec3(0.603, 0.535, 0.454), vec3(0.504, 0.448, 0.387), vec3(0.408, 0.362, 0.324), vec3(0.314, 0.280, 0.266), vec3(0.230, 0.207, 0.211), vec3(0.149, 0.137, 0.157),
	vec3(0.949, 0.918, 0.847), vec3(0.893, 0.853, 0.771), vec3(0.828, 0.780, 0.691), vec3(0.736, 0.683, 0.602), vec3(0.627, 0.575, 0.510), vec3(0.502, 0.454, 0.416), vec3(0.380, 0.343, 0.332), vec3(0.259, 0.235, 0.251),
	vec3(0.761, 0.714, 0.675), vec3(0.667, 0.620, 0.594), vec3(0.573, 0.527, 0.515), vec3(0.478, 0.437, 0.444), vec3(0.389, 0.354, 0.376), vec3(0.304, 0.278, 0.314), vec3(0.225, 0.207, 0.248), vec3(0.149, 0.137, 0.180),
	vec3(0.847, 0.659, 0.424), vec3(0.762, 0.567, 0.347), vec3(0.673, 0.477, 0.278), vec3(0.575, 0.394, 0.229), vec3(0.471, 0.315, 0.188), vec3(0.361, 0.239, 0.157), vec3(0.264, 0.176, 0.132), vec3(0.173, 0.118, 0.110),
	vec3(0.984, 0.973, 0.933), vec3(0.928, 0.910, 0.855), vec3(0.861, 0.836, 0.771), vec3(0.757, 0.731, 0.673), vec3(0.639, 0.612, 0.571), vec3(0.504, 0.480, 0.466), vec3(0.376, 0.356, 0.362), vec3(0.251, 0.235, 0.259)
);
