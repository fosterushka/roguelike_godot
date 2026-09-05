shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float pixel_ratio = 1.0;
uniform float size_pixels = 16.0;
uniform float opacity = 0.5;
uniform float seed_value = 0.5;
uniform float angle = 0.0;
uniform vec3 color_a : source_color = vec3(0.60784,0.43922,0.27843);
uniform vec3 color_b : source_color = vec3(0.81569,0.66667,0.44706);
float hash_value(float value){return fract(sin(value*91.17)*43758.5453);}
void vertex(){
 vec4 center=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(0.0,0.0,0.0,1.0);
 center.xy+=VERTEX.xy*max(1.0,size_pixels*pixel_ratio)*2.0/VIEWPORT_SIZE*center.w;
 POSITION=center;
}
void fragment(){
 vec2 point=UV*2.0-1.0;
 point=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*point;
 float grain=.72+hash_value(floor(point.x*7.0)+floor(point.y*9.0)*13.0+seed_value*23.0)*.28;
 float alpha=(1.0-smoothstep(.28,1.0,length(point)))*grain*opacity;
 if(alpha<.01){discard;}
 ALBEDO=mix(color_a,color_b,hash_value(seed_value*17.0));
 ALPHA=alpha;
}
