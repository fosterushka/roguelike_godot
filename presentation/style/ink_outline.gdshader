shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink_color : source_color = vec4(0.12, 0.15, 0.18, 1.0);
uniform float width = 0.035;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = MODEL_NORMAL_MATRIX * NORMAL;
	float normal_length = length(world_normal);
	if (normal_length > 0.0001) {
		world_position += world_normal / normal_length * width;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_position, 1.0);
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
