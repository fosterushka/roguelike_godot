shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

#include "res://presentation/world/fog_lamp_beam.gdshaderinc"
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 fog_color : source_color;
uniform float fog_density = 0.0;

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
    vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    view /= view.w;
    vec3 world_point = (INV_VIEW_MATRIX * view).xyz;
    float density = fog_density * (1.0 - lamp_coverage(world_point.xz));
    ALBEDO = fog_color;
    ALPHA = 1.0 - exp(-density * max(0.0, -view.z));
}
