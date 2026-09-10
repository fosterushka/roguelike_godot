shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float rain_wind : hint_range(-1.0, 1.0) = 0.0;

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
	float tear_row = floor(uv.y * 22.0);
	float tear = step(0.91, noise(vec2(tear_row, floor(TIME * 7.0)))) * (noise(vec2(tear_row, tick)) - 0.5);
	uv.x += (jitter * 3.5 + tear * 55.0 + tracking * (24.0 + pulse * 20.0)) * SCREEN_PIXEL_SIZE.x * amount;
	uv.y += sin(TIME * 19.0) * SCREEN_PIXEL_SIZE.y * amount * (0.8 + pulse * 2.0);
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
			vec2 point = fract(cells) - vec2(0.3 + seed * 0.4, 0.5);
			float width = mix(0.025, 0.065, smoothstep(-0.10, 0.015, point.y));
			float radius = length(point / vec2(width, 0.105));
			float active = step(seed, rain * 0.14);
			float lens = (1.0 - smoothstep(0.65, 1.0, radius)) * active * rain;
			uv += point * lens * 0.024;
			drop_light += (smoothstep(0.62, 0.83, radius) - smoothstep(0.83, 1.0, radius)) * active * rain * (-point.y * 0.9);
		}
	}
	vec2 fringe = vec2((3.5 + tracking * 8.0 + pulse * 4.0) * amount * SCREEN_PIXEL_SIZE.x, 0.0);
	vec3 color = vec3(texture(screen_texture, uv + fringe).r, texture(screen_texture, uv).g, texture(screen_texture, uv - fringe).b);
	float grain = noise(vec2(floor(uv.x / SCREEN_PIXEL_SIZE.x), row) + tick) - 0.5;
	float scanline = 1.0 - step(1.0, mod(row, 3.0));
	color *= 1.0 - (scanline * 0.23 + tracking * 0.22) * amount;
	color += (grain * 0.30 + tracking * 0.08) * amount;
	color += vec3(0.025, -0.01, 0.035) * amount;
	color += vec3(drop_light);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
