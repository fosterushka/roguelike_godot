shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float uTime = 0.0;
uniform float uIntensity = 0.0;
varying vec2 vUv;
varying float vPulse;
varying vec3 vSurface;

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
    vec3 transformed = VERTEX;
    float height = clamp((transformed.y + 12.0) / 24.0, 0.0, 1.0);
    float twist = uTime * mix(2.8, 1.15, height) + height * 9.0;
    float bend = sin(uTime * 0.62 + height * 5.4) * height * 0.42;
    mat2 rotation = mat2(vec2(cos(twist), -sin(twist)), vec2(sin(twist), cos(twist)));
    float fluting = 1.0 + sin(atan(VERTEX.z, VERTEX.x) * 5.0 + height * 19.0 - uTime * 2.3) * 0.07;
    transformed.xz *= mix(0.72, 1.0, height * height) * fluting;
    transformed.xz = rotation * transformed.xz;
    transformed.x += bend;
    transformed.z += cos(uTime * 0.48 + height * 4.2) * height * 0.3;
    transformed.y *= smoothstep(0.0, 0.2, uIntensity);
    vUv = UV;
    vSurface = vec3(normalize(VERTEX.xz), height);
    vPulse = 0.72 + 0.28 * sin(height * 34.0 - uTime * 8.0);
    VERTEX = transformed;
  }
void fragment(){
    float angle = uTime * 0.7 + vUv.y * 8.0;
    mat2 spin = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
    vec2 wrapped = spin * vSurface.xy;
    vec2 flow = wrapped * 3.4 + vec2(vUv.y * 9.0, -uTime * 0.65);
    float broad = weatherNoise(flow);
    float detail = weatherNoise(flow * 2.6 + broad * 1.8);
    float filaments = weatherNoise(flow * 6.5 + detail * 2.0);
    float bands = broad * 0.5 + detail * 0.34 + filaments * 0.16;
    float spiral = 0.5 + 0.5 * sin(vUv.y * 65.0 + wrapped.x * 6.0 - uTime * 5.0 + detail * 4.0);
    float bottomFade = smoothstep(0.0, 0.06, vUv.y);
    float topFade = 1.0 - smoothstep(0.78, 1.0, vUv.y);
    float density = smoothstep(0.18, 0.78, bands) * (0.7 + spiral * 0.3);
    float alpha = density * 0.72 * vPulse * bottomFade * topFade * uIntensity;
    if (alpha < 0.012) discard;
    float lighting = clamp(dot(wrapped, normalize(vec2(-0.6, 0.8))) * 0.3 + 0.55, 0.0, 1.0);
    vec3 dustColor = mix(vec3(0.12, 0.105, 0.09), vec3(0.48, 0.4, 0.29), bands * 0.7 + lighting * 0.3);
    vec3 cloudColor = mix(vec3(0.11, 0.15, 0.18), vec3(0.42, 0.49, 0.51), bands * 0.65 + lighting * 0.35);
    vec3 color = mix(dustColor, cloudColor, smoothstep(0.12, 0.8, vUv.y));
    ALBEDO = color; ALPHA = alpha;
    
  }
