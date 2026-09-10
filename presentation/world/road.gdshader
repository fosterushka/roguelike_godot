shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back, depth_prepass_alpha;
uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 road_color : source_color = vec4(0.815686, 0.690196, 0.541176, 1.0);
uniform bool junction = false;
float road_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	float edge;
	if (junction) {
		edge = 1.0 - smoothstep(0.39, 0.5, length(UV - vec2(0.5)));
	} else {
		float noise = road_hash(floor(UV * vec2(19.0, 7.0))) * 0.075;
		edge = 1.0 - smoothstep(0.74 + noise, 1.0, abs(UV2.x));
	}
	if (edge < 0.035) { discard; }
	vec4 sampled = texture(road_texture, UV);
	ALBEDO = sampled.rgb * road_color.rgb;
	ALPHA = sampled.a * edge;
	if (ALPHA < 0.035) { discard; }
	ROUGHNESS = 1.0;
}
