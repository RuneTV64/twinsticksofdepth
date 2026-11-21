// How a house takes the light: in three steps (dark, half, full), as the ground does (ground_light.gdshaderinc).
// A flat wall is one step all over, with no dither (a dithered step would checker the whole wall); the edge of a
// shadow falling across it is dithered on the surface's own texels. Include it last; the fragment shader must
// set `ltexel` to the texel it drew.
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float facing = clamp(floor(nl * 2.0 + 0.5) * 0.5, 0.0, 1.0);
	float b = gbayer(ltexel) - 0.5;
	float lit = clamp(floor(ATTENUATION * 2.0 + 0.5 + b * 0.6) * 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += facing * lit * LIGHT_COLOR / PI;
}
