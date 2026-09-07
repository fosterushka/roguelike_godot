shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform float uTime = 0.0;
uniform float biome_border = 260.0;
uniform float biome_blend = 90.0;
uniform float biome_wave = 95.0;
uniform float biome_frequency = 0.004;
varying vec3 world_point;

float terrain_hash(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float terrain_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 weight = fract(point);
	weight = weight * weight * (3.0 - 2.0 * weight);
	return mix(mix(terrain_hash(cell), terrain_hash(cell + vec2(1, 0)), weight.x),
		mix(terrain_hash(cell + vec2(0, 1)), terrain_hash(cell + vec2(1, 1)), weight.x), weight.y);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 point = world_point.xz;
	float broad = terrain_noise(point * 0.028);
	float brush = terrain_noise(point * vec2(0.11, 0.22) + vec2(17, 4));
	float fine = terrain_noise(point * 0.52 + vec2(6, 23));
	float soil = smoothstep(0.57, 0.78, broad + brush * 0.2);
	float dry = smoothstep(0.58, 0.86, terrain_noise(point * 0.065 + vec2(-11, 28)));
	vec3 meadow = mix(vec3(0.31, 0.43, 0.22), vec3(0.59, 0.64, 0.32), smoothstep(0.24, 0.72, brush));
	vec3 color = mix(meadow, vec3(0.57, 0.42, 0.27), soil * 0.76);
	color = mix(color, vec3(0.74, 0.62, 0.38), dry * 0.4);
	float biome = point.x + sin(point.y * biome_frequency) * biome_wave;
	float badlands = smoothstep(biome_border - biome_blend, biome_border + biome_blend, biome);
	float tundra = 1.0 - smoothstep(-biome_border - biome_blend, -biome_border + biome_blend, biome);
	vec3 sand = mix(vec3(0.61, 0.38, 0.22), vec3(0.83, 0.66, 0.4), brush);
	vec3 frost = mix(vec3(0.41, 0.48, 0.48), vec3(0.82, 0.87, 0.84), smoothstep(0.25, 0.64, broad + brush * 0.2));
	color = mix(color, sand, badlands);
	color = mix(color, frost, tundra);
	color += (fine - 0.5) * 0.025;
	ALBEDO = pow(color, vec3(2.2));
	ROUGHNESS = 1.0;
}
