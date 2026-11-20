// How ground takes the light: in three steps (dark, half, full), the step dithered on the ground's own texels,
// so a shadow or the edge of a lamp's light falls across it as pixel art and not as a soft gradient. Include it
// after ground_lib and give it the fragment's world position in a varying called `wp`.
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float b = gbayer(ground_texel(wp.xz)) - 0.5;
	float band = clamp(floor(nl * 2.0 + 0.5 + b * 0.6) * 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
