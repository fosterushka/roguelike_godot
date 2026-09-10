shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;

  uniform vec3 uLightColor : source_color = vec3(1.0,1.0,0.9843);
  uniform vec3 uDarkColor : source_color = vec3(0.7255,0.749,0.7412);
  uniform float uTime = 0.0;
  
  varying float vOpacity;
  varying float vAge;
  varying float vSeed;
  uniform float expansion;
  uniform float fade_in_ratio;

  float hash(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
  }

  float noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);
    return mix(
      mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x),
      mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x),
      local.y
    );
  }

  float turbulence(vec2 point) {
    float value = noise(point) * 0.54;
    value += noise(point * 2.07 + 5.13) * 0.29;
    value += noise(point * 4.19 - 8.71) * 0.17;
    return value;
  }

  void fragment() {
    if (vOpacity < 0.012) discard;
    vec2 centered = UV * 2.0 - 1.0;
    float seedPhase = vSeed * 17.17;
    float curl = noise(centered * 1.8 + vec2(seedPhase, uTime * 0.14 + vAge * 0.27)) - 0.5;
    centered += vec2(curl * 0.24, noise(centered.yx * 2.3 - seedPhase) * 0.12 - 0.06);
    float densityNoise = turbulence(centered * 2.15 + vec2(seedPhase, vAge * 0.31));
    float edge = length(centered) + (0.5 - densityNoise) * 0.42;
    float body = 1.0 - smoothstep(0.46, 1.03, edge);
    float core = 1.0 - smoothstep(0.04, 0.72, length(centered));
    float alpha = body * mix(0.82, 1.0, core) * vOpacity;
    if (alpha < 0.012) discard;
    vec3 color = mix(uDarkColor, uLightColor, 0.48 + densityNoise * 0.36 + core * 0.16);
    ALBEDO = color; ALPHA = alpha;
  }

// INSTANCE_CUSTOM: birth time, lifetime, seed, opacity.
// COLOR: world drift xyz and initial rotation. All values are uploaded at spawn.
void vertex() {
  vAge = max(0.0, uTime - INSTANCE_CUSTOM.x);
  float life = max(0.0001, INSTANCE_CUSTOM.y);
  float ratio = clamp(vAge / life, 0.0, 1.0);
  vSeed = INSTANCE_CUSTOM.z;
  vOpacity = INSTANCE_CUSTOM.w * min(1.0, ratio / fade_in_ratio) * (1.0 - ratio * ratio);
  float phase = vSeed * 19.1;
  vec3 drift = COLOR.rgb * vAge;
  // Integrated lateral swirl is independent of frame rate.
  drift.x += (cos(phase) - cos(phase + vAge * 2.2)) * (0.045 / 2.2);
  drift.z += (sin((phase + vAge * 2.2) * 0.83) - sin(phase * 0.83)) * (0.045 / (2.2 * 0.83));
  float angle = COLOR.a + vAge * mix(-0.34, 0.34, fract(vSeed * 7.31));
  VERTEX.xy = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * VERTEX.xy;
  VERTEX.xy *= 1.0 + ratio * expansion;
  if (vAge >= life) { VERTEX = vec3(0.0); }
  vec4 origin = MODEL_MATRIX[3] + vec4(drift, 0.0);
  MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], origin);
  MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
  MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}
