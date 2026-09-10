shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float uTime = 0.0;
uniform float uIntensity = 0.0;
varying vec2 vUv;

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

void vertex(){vUv=UV;}
void fragment(){
    vec2 p = vUv * 2.0 - 1.0;
    float radius = length(p);
    // Noise can move the edge inward by at most 0.125.
    if (radius >= 1.125 || radius <= 0.035) discard;
    float angle = uTime * 0.9 - radius * 5.0;
    vec2 swirl = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
    float broad = weatherNoise(swirl * 5.0 + 12.0);
    float detail = weatherNoise(swirl * 14.0 + broad * 2.0);
    float edge = 1.0 - smoothstep(0.32, 1.0, radius + (broad - 0.5) * 0.25);
    float eye = smoothstep(0.035, 0.16, radius);
    float alpha = edge * eye * (broad * 0.55 + detail * 0.25) * uIntensity * 0.62;
    if (alpha < 0.008) discard;
    vec3 color = mix(vec3(0.16, 0.12, 0.08), vec3(0.49, 0.38, 0.23), broad * 0.7 + detail * 0.3);
    ALBEDO = color; ALPHA = alpha;
    
  }
