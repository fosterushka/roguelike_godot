shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float uTime;
uniform vec2 uAnchor;
uniform vec2 uDrift;
varying vec2 vUv;
varying float vSeed;
varying float vEdge;
uniform float uRain;
uniform float uStorm;
uniform float uFog;
uniform float uLightning;

  float weatherHash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
  }
  float weatherNoise(vec2 p) {
    vec2 cell = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(weatherHash(cell), weatherHash(cell + vec2(1, 0)), f.x),
      mix(weatherHash(cell + vec2(0, 1)), weatherHash(cell + vec2(1, 1)), f.x), f.y);
  }

void vertex(){
    vec2 drift = uDrift + vec2(0.7, 0.3) * uTime;
    vec2 center = mod(INSTANCE_CUSTOM.xy + drift - uAnchor + 48.0, 96.0) - 48.0;
    vec4 viewPosition = MODELVIEW_MATRIX * vec4(center.x + uAnchor.x,
      1.8 + INSTANCE_CUSTOM.z * 3.0, center.y + uAnchor.y, 1.0);
    viewPosition.xy += VERTEX.xy * vec2(16.0 + INSTANCE_CUSTOM.w * 15.0, 3.0 + INSTANCE_CUSTOM.z * 4.0);
    vUv = UV;
    vSeed = INSTANCE_CUSTOM.z;
    vEdge = 1.0 - smoothstep(32.0, 48.0, length(center));
    POSITION = PROJECTION_MATRIX * viewPosition;
  }
void fragment(){
    vec2 p = vUv * 2.0 - 1.0;
    float edge = 1.0 - smoothstep(0.15, 1.0, dot(p, p));
    vec2 flow = vUv * vec2(4.0, 2.0) + vec2(-uTime * 0.12, vSeed * 19.0);
    float cloud = weatherNoise(flow) * 0.65 + weatherNoise(flow * 2.8 + uTime * 0.07) * 0.35;
    float density = smoothstep(0.22, 0.8, cloud) * edge * vEdge;
    float alpha = density * (uFog * 0.23 + uRain * 0.045 + uStorm * 0.07);
    if (alpha < 0.003) discard;
    vec3 color = mix(vec3(0.48, 0.57, 0.56), vec3(0.25, 0.34, 0.4), uStorm);
    color = mix(color, vec3(0.82, 0.91, 1.0), uLightning * 0.8);
    ALBEDO = color; ALPHA = alpha;
    
  }
