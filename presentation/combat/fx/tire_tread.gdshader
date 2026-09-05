shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec3 world_point;
varying vec4 tread_data;
void vertex() {
 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 tread_data = INSTANCE_CUSTOM;
}
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 float side = abs(UV.x - 0.5);
 float shoulder = 1.0 - smoothstep(0.42, 0.5, side);
 float ends = smoothstep(0.0, 0.07, UV.y) * smoothstep(0.0, 0.07, 1.0 - UV.y);
 float block = abs(fract(UV.y * 2.0 + side * 2.6 + tread_data.x) - 0.5);
 float chevron = 1.0 - smoothstep(0.17, 0.26, block);
 float channel = smoothstep(0.035, 0.075, side);
 float rim = smoothstep(0.37, 0.40, side) * (1.0 - smoothstep(0.43, 0.47, side));
 float breakup = mix(0.62, 1.0, grain(floor(world_point.xz * 18.0)));
 float alpha = max(chevron * channel, rim * 0.58) * shoulder * ends * breakup * COLOR.a;
 if (alpha < 0.012) { discard; }
 ALBEDO = mix(COLOR.rgb, COLOR.rgb * 1.2 + vec3(0.035), rim);
 ALPHA = alpha;
}
