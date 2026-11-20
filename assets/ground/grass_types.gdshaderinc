// The kinds of grass that grow as part of the ground's own surface (the standing blades are grass_blades). The
// second batch fills this in; until then every grass kind is drawn as soil.
const int GRASS_FIRST = 8;

Ground grass_pick(int kind, vec2 p, vec2 texel, GroundEnv e) {
	return dirt_soil(p, texel, e);
}
