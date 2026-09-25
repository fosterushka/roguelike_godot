uniform vec2 lamp_position = vec2(0.0);
uniform vec2 lamp_direction = vec2(0.0, 1.0);
uniform float lamp_range = 0.0;
uniform float lamp_near_radius = 0.0;
uniform float lamp_half_angle = 0.0;
uniform float lamp_strength = 0.0;
uniform float lamp_angle_edge = 0.0;
uniform float lamp_range_edge = 0.0;

float lamp_coverage(vec2 world_point) {
    vec2 offset = world_point - lamp_position;
    float distance_to_lamp = length(offset);
    if (lamp_strength <= 0.0 || distance_to_lamp >= lamp_range) return 0.0;
    float angle = acos(clamp(dot(offset / max(distance_to_lamp, 0.0001), lamp_direction), -1.0, 1.0));
    float cone = 1.0 - smoothstep(lamp_half_angle * (1.0 - lamp_angle_edge), lamp_half_angle, angle);
    float local_clear = 1.0 - smoothstep(lamp_near_radius * 0.5, lamp_near_radius, distance_to_lamp);
    float end = 1.0 - smoothstep(lamp_range * (1.0 - lamp_range_edge), lamp_range, distance_to_lamp);
    return max(cone, local_clear) * end * lamp_strength;
}
