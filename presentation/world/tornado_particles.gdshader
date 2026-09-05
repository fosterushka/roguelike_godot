shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float uTime = 0.0;
uniform float uIntensity = 0.0;
varying float vAlpha;
varying float vSeed;
void vertex(){
    float phase = fract(INSTANCE_CUSTOM.b + uTime * mix(0.07, 0.16, INSTANCE_CUSTOM.g));
    float height = phase * 23.0;
    float heightRatio = height / 23.0;
    float radius = mix(1.0, 8.4, pow(heightRatio, 0.78)) * mix(0.68, 1.15, INSTANCE_CUSTOM.g);
    float angle = INSTANCE_CUSTOM.r + uTime * mix(4.8, 2.1, heightRatio) + heightRatio * 11.0;
    vec3 transformed = vec3(cos(angle) * radius, height + 0.35, sin(angle) * radius);
    transformed.xz += vec2(sin(heightRatio * 5.0 + uTime * 0.6), cos(heightRatio * 4.0 + uTime * 0.47)) * heightRatio * 0.45;
    vec4 mvPosition = MODELVIEW_MATRIX * vec4(transformed, 1.0);
    POSITION = PROJECTION_MATRIX * mvPosition;
    vSeed = INSTANCE_CUSTOM.b;
    float point_size = mix(2.0, 6.4, INSTANCE_CUSTOM.g) * mix(0.35, 1.0, uIntensity);
    vAlpha = uIntensity * sin(phase * 3.14159265) * mix(0.3, 0.78, INSTANCE_CUSTOM.g);
  
POSITION.xy += VERTEX.xy * point_size * 2.0 / VIEWPORT_SIZE * POSITION.w;
}
void fragment(){
    vec2 centered = UV * 2.0 - 1.0;
    float angle = vSeed * 31.0;
    centered = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * centered;
    float dust = 1.0 - smoothstep(0.1, 1.0, dot(centered, centered));
    float shard = 1.0 - smoothstep(0.3, 0.7, abs(centered.x) * 0.7 + abs(centered.y) * 1.4);
    float shape = mix(dust, shard, step(0.72, vSeed));
    if (shape * vAlpha < 0.02) discard;
    ALBEDO = mix(vec3(0.39, 0.29, 0.19), vec3(0.15, 0.17, 0.18), step(0.72, vSeed)); ALPHA = shape * vAlpha;
    
  }
