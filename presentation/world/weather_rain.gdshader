shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float uTime;
uniform float uRain;
uniform float uStorm;
uniform vec2 uWind;
uniform vec2 uDrift;
uniform vec2 uPlayerVelocity;
uniform vec2 uAnchor;
uniform float uSeedRadius = 46.0;
uniform vec2 uDepthRange = vec2(6.0, 110.0);
uniform float uScreenMargin = 1.08;
uniform vec2 uStreakWidthPixels = vec2(0.7, 1.2);
varying vec2 vUv;
varying float vAlpha;
uniform float uLightning;

void vertex() {
    float fallSpeed = mix(26.0, 42.0, uStorm) * mix(0.8, 1.2, INSTANCE_CUSTOM.w);
    float phase = fract(INSTANCE_CUSTOM.z + uTime * fallSpeed / 36.0);
    vec2 flow = uWind + vec2(1.3, 0.5) * uStorm - uPlayerVelocity * 0.08;
    flow += vec2(sin(uTime * 1.4 + INSTANCE_CUSTOM.z * 6.28), cos(uTime * 0.9)) * uStorm;
    // Sample the entire camera frustum instead of a circle around the vehicle.
    // Each streak retains a real view depth, so opaque geometry still occludes it.
    float depth = mix(uDepthRange.x, uDepthRange.y, INSTANCE_CUSTOM.z);
    float perspectiveScale = mix(depth, 1.0, PROJECTION_MATRIX[3][3]);
    vec2 halfSpan = perspectiveScale / vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]);
    vec3 travel = mat3(VIEW_MATRIX) * vec3(uDrift.x, -uTime * fallSpeed, uDrift.y);
    vec2 travelInView = (travel.xy + VIEW_MATRIX[3].xy) / halfSpan;
    vec2 seed = INSTANCE_CUSTOM.xy / uSeedRadius * uScreenMargin;
    vec2 center = mod(seed + travelInView + uScreenMargin, uScreenMargin * 2.0) - uScreenMargin;
    vec4 viewPosition = vec4(center * halfSpan, -depth, 1.0);
    vec3 viewFlow = mat3(VIEW_MATRIX) * vec3(flow.x, -fallSpeed, flow.y);
    vec2 direction = normalize(viewFlow.xy + vec2(0.0001));
    vec2 side = vec2(-direction.y, direction.x);
    float streakLength = mix(0.65, 1.5, uStorm) * mix(0.65, 1.4, INSTANCE_CUSTOM.w);
    float widthPixels = mix(uStreakWidthPixels.x, uStreakWidthPixels.y, INSTANCE_CUSTOM.w);
    vec2 pixelSpan = halfSpan * 2.0 / VIEWPORT_SIZE;
    viewPosition.xy += direction * VERTEX.y * streakLength + side * VERTEX.x * widthPixels * pixelSpan;
    vUv = UV;
    vAlpha = uRain * mix(0.24, 0.5, INSTANCE_CUSTOM.w)
      * smoothstep(0.0, 0.06, phase) * (1.0 - smoothstep(0.92, 1.0, phase));
    POSITION = PROJECTION_MATRIX * viewPosition;
}

void fragment() {
    float edge = 1.0 - smoothstep(0.08, 0.5, abs(vUv.x - 0.5));
    float tail = smoothstep(0.0, 0.18, vUv.y) * (1.0 - smoothstep(0.4, 1.0, vUv.y));
    float alpha = vAlpha * edge * tail;
    if (alpha < 0.003) discard;
    vec3 color = mix(vec3(0.52, 0.68, 0.74), vec3(0.72, 0.84, 0.94), uStorm);
    color = mix(color, vec3(0.95, 0.98, 1.0), uLightning);
    ALBEDO = color;
    ALPHA = alpha * (1.0 + uLightning * 0.5);
}
