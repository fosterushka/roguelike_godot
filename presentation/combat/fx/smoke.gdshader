shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;

  uniform vec3 uColor : source_color = vec3(0.45);
  uniform float uDensity = 1.0;
  uniform float uOpacity = 1.0;
  uniform float uSeed = 0.0;
  uniform float uTime = 0.0;
  

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

  float smokeNoise(vec2 point) {
    float value = noise(point) * 0.5;
    value += noise(point * 2.03 + 9.17) * 0.27;
    value += noise(point * 4.07 - 3.61) * 0.15;
    value += noise(point * 8.11 + 21.4) * 0.08;
    return value;
  }

  void fragment() {
    vec2 centered = UV * 2.0 - 1.0;
    float edgeDistance = length(centered);
    if (edgeDistance > 1.05) discard;

    float seedPhase = uSeed * 13.71;
    vec2 drift = vec2(
      sin(uTime * 0.31 + seedPhase),
      uTime * 0.23 + cos(seedPhase) * 0.17
    );
    float curl = noise(centered * 1.35 + vec2(seedPhase, uTime * 0.16)) - 0.5;
    mat2 rotation = mat2(vec2(cos(curl), -sin(curl)), vec2(sin(curl), cos(curl)));
    vec2 warped = rotation * centered * 1.72 + drift + vec2(curl * 0.35, 0.0);
    float turbulence = smokeNoise(warped + vec2(uSeed * 5.3, uSeed * -3.7));
    float wisps = noise(warped * vec2(1.35, 2.1) - vec2(uTime * 0.16, uTime * 0.28));
    float silhouette = edgeDistance + (0.5 - turbulence) * 0.44 + (0.5 - wisps) * 0.12;
    float body = 1.0 - smoothstep(0.34, 1.0, silhouette);
    float core = 1.0 - smoothstep(0.05, 0.82, edgeDistance + (0.5 - turbulence) * 0.2);
    float lowerDissolve = smoothstep(-1.0, -0.55 + turbulence * 0.22, centered.y);
    float alpha = body * mix(0.64, 1.0, core) * lowerDissolve * uDensity * uOpacity;
    if (alpha < 0.012) discard;

    vec3 litColor = mix(uColor * 0.56, uColor * 1.22, turbulence * 0.68 + core * 0.32);
    ALBEDO = litColor; ALPHA = alpha;
  }

void vertex(){ float flutter=sin(uTime*1.7+UV.y*5.4)*0.035*UV.y; VERTEX.x+=flutter; MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]); MODELVIEW_MATRIX[0].xyz*=length(MODEL_MATRIX[0].xyz); MODELVIEW_MATRIX[1].xyz*=length(MODEL_MATRIX[1].xyz); }
