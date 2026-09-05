shader_type canvas_item;

  uniform float uTime;
  uniform float uOpacity;

  float hash(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
  }

  float noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);
    return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x), local.y);
  }

  void fragment() {
    vec2 point = FRAGCOORD.xy * 0.004;
    float grit = noise(point + vec2(uTime * 0.62, -uTime * 0.31));
    grit = grit * 0.64 + noise(point * 2.7 - uTime * 0.24) * 0.36;
    float flecks = step(0.92, noise(floor(FRAGCOORD.xy * 0.12) + floor(uTime * 8.0)));
    vec3 color = mix(vec3(0.22, 0.14, 0.075), vec3(0.68, 0.49, 0.27), grit);
    float alpha = uOpacity * (0.15 + grit * 0.34 + flecks * 0.18);
    COLOR = vec4(color, alpha);
    
  }
