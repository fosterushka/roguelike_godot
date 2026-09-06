shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

float noise(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 24.0);
	float row = floor(uv.y / SCREEN_PIXEL_SIZE.y);
	float tracking = pow(max(0.0, 1.0 - abs(uv.y - fract(TIME * 0.19)) / 0.045), 2.0);
	float jitter = noise(vec2(floor(row / 5.0), tick)) - 0.5;
	float amount = intensity * (0.75 + pulse * 0.25);
	uv.x += (jitter * 1.8 + tracking * (9.0 + pulse * 8.0)) * SCREEN_PIXEL_SIZE.x * amount;
	vec2 fringe = vec2((1.5 + tracking * 4.0 + pulse * 2.0) * amount * SCREEN_PIXEL_SIZE.x, 0.0);
	vec3 color = vec3(texture(screen_texture, uv + fringe).r, texture(screen_texture, uv).g, texture(screen_texture, uv - fringe).b);
	float grain = noise(vec2(floor(uv.x / SCREEN_PIXEL_SIZE.x), row) + tick) - 0.5;
	float scanline = 1.0 - step(1.0, mod(row, 3.0));
	color *= 1.0 - (scanline * 0.16 + tracking * 0.12) * amount;
	color += (grain * 0.19 + tracking * 0.035) * amount;
	color += vec3(0.025, -0.01, 0.035) * amount;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
