shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float uTime;
uniform float uRain;
uniform vec2 uAnchor;
varying vec2 vUv;
varying float vPhase;
varying float vAlpha;
uniform float uLightning;
void vertex(){
    vPhase = fract(INSTANCE_CUSTOM.z + uTime * mix(1.3, 2.1, INSTANCE_CUSTOM.w));
    vec2 center = mod(INSTANCE_CUSTOM.xy - uAnchor + 38.0, 76.0) - 38.0;
    float size = mix(0.35, 0.85, INSTANCE_CUSTOM.w);
    vec3 transformed = vec3(center.x + uAnchor.x + VERTEX.x * size, 0.075,
      center.y + uAnchor.y - VERTEX.y * size);
    vUv = UV;
    vAlpha = uRain * (1.0 - smoothstep(28.0, 38.0, length(center)))
      * (1.0 - vPhase) * smoothstep(0.0, 0.06, vPhase);
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(transformed, 1.0);
  }
void fragment(){
    vec2 p = vUv * 2.0 - 1.0;
    float radius = length(p);
    float ripple = 1.0 - smoothstep(0.025, 0.085, abs(radius - vPhase * 0.85));
    float impact = exp(-radius * radius * 85.0) * (1.0 - smoothstep(0.08, 0.3, vPhase));
    float brokenEdge = 0.5 + 0.5 * sin(atan(p.y, p.x) * 7.0 + vPhase * 9.0);
    float alpha = (ripple * mix(0.18, 0.5, brokenEdge) + impact) * vAlpha;
    if (alpha < 0.006) discard;
    ALBEDO = mix(vec3(0.46, 0.62, 0.68), vec3(0.9, 0.96, 1.0), uLightning); ALPHA = alpha;
    
  }
