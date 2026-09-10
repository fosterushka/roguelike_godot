shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float rain_wind : hint_range(-1.0, 1.0) = 0.0;

float noise(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float static_noise(uvec2 pixel, uint tick) {
	uint value = pixel.x * 1973u + pixel.y * 9277u + tick * 26699u;
	value = (value ^ (value >> 16u)) * 2246822519u;
	value = (value ^ (value >> 13u)) * 3266489917u;
	value ^= value >> 16u;
	return float(value & 65535u) / 65535.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 24.0);
	float amount = intensity * (0.75 + pulse * 0.25);
	float drop_light = 0.0;
	// Dry jammer interference needs no lens-droplet calculations.
	if (rain > 0.0) {
		for (int layer = 0; layer < 2; layer++) {
			// Sparse, small beads sliding down the lens, with round heads and narrow tails.
			float rows = 9.0 + float(layer) * 5.0;
			vec2 density = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) * rows;
			vec2 cells = SCREEN_UV * density;
			cells.y -= TIME * (2.0 + float(layer) * 1.3) * (1.0 + abs(rain_wind) * 0.3);
			cells.x -= TIME * rain_wind * 0.18;
			vec2 id = floor(cells);
			float seed = noise(id + float(layer) * 31.0);
			if (seed <= rain * 0.14) {
				vec2 point = fract(cells) - vec2(0.3 + seed * 0.4, 0.5);
				float width = mix(0.025, 0.065, smoothstep(-0.10, 0.015, point.y));
				float radius = length(point / vec2(width, 0.105));
				float lens = (1.0 - smoothstep(0.65, 1.0, radius)) * rain;
				uv += point * lens * 0.024;
				drop_light += (smoothstep(0.62, 0.83, radius) - smoothstep(0.83, 1.0, radius)) * rain * (-point.y * 0.9);
			}
		}
	}
	vec3 color = texture(screen_texture, uv).rgb;
	// Broadband static: no tracking bars, scanlines, RGB split or frame jitter.
	if (amount > 0.0) {
		float grain = static_noise(uvec2(SCREEN_UV / SCREEN_PIXEL_SIZE), uint(tick));
		float speckle = step(0.97, grain) - step(grain, 0.03);
		color += ((grain - 0.5) * 0.34 + speckle * 0.16) * amount;
	}
	color += vec3(drop_light);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
