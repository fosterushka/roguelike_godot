uniform sampler2D fireball_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform float angle = 0.0;
uniform float alpha_threshold = 0.018;
void vertex() {
 vec2 dimensions = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
 vec2 point = VERTEX.xy * dimensions;
 VERTEX.xy = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * point;
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec4 color = texture(fireball_texture, UV) * tint;
 color.a *= opacity;
 if (color.a < alpha_threshold) { discard; }
 ALBEDO = color.rgb;
 ALPHA = color.a;
}
