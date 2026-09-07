shader_type spatial;
render_mode diffuse_toon, specular_disabled;
varying vec3 local_point;
varying vec4 stone_color;

float grain(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	local_point = VERTEX;
	stone_color = COLOR;
}

void fragment() {
	// Object-space grain has no UV seams or stretched patches on tiny stones.
	float coarse = grain(floor(local_point * 34.0));
	float fine = grain(floor(local_point * 110.0));
	float strata = smoothstep(0.35, 0.65, sin(local_point.y * 31.0 + local_point.x * 3.0) * 0.5 + 0.5);
	ALBEDO = stone_color.rgb * (0.88 + coarse * 0.14 + fine * 0.06 + strata * 0.08);
	ROUGHNESS = 0.96;
}
