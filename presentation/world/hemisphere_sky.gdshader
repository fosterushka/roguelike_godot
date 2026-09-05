shader_type sky;

uniform vec4 sky_color : source_color = vec4(0.69, 0.80, 0.90, 1.0);
uniform vec4 ground_color : source_color = vec4(0.31, 0.36, 0.39, 1.0);

void sky() {
	COLOR = mix(ground_color.rgb, sky_color.rgb, clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0));
}
