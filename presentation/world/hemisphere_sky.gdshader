shader_type sky;

uniform vec4 sky_color : source_color = vec4(0.945098, 0.882353, 0.741176, 1.0);
uniform vec4 ground_color : source_color = vec4(0.258824, 0.286275, 0.286275, 1.0);

void sky() {
	COLOR = mix(ground_color.rgb, sky_color.rgb, clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0));
}
