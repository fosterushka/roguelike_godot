shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform vec3 base_color : source_color = vec3(.35);
uniform sampler2D base_texture : source_color, filter_nearest;
uniform bool has_base_texture = false;
uniform float elapsed = 0.0;
uniform float burn = 0.0;
uniform float opacity = 1.0;
varying vec3 local_position;
varying vec3 view_normal;
float hash_value(vec3 p){p=fract(p*.3183099+vec3(.1,.17,.13));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
void vertex(){
 local_position=VERTEX;
 view_normal=normalize(MODELVIEW_NORMAL_MATRIX*NORMAL);
 float buckle=sin(VERTEX.y*4.7+VERTEX.x*2.1+elapsed*3.0)*burn*.018;
 VERTEX+=NORMAL*buckle;
}
void fragment(){
 float noise=hash_value(floor(local_position*5.0));
 float char_amount=smoothstep(.08,.82,burn+noise*.3);
 float wave=abs(sin(local_position.x*8.0+local_position.y*11.0+local_position.z*7.0+noise*5.0));
 float cracks=smoothstep(.91,.995,wave)*smoothstep(.05,.42,burn)*(1.0-smoothstep(.72,1.0,burn));
 float light=.34+max(0.0,dot(normalize(view_normal),normalize(vec3(.3,.8,.45))))*.66;
 vec3 char_color=mix(vec3(.055,.047,.042),vec3(.13,.075,.035),noise*.55);
 vec3 surface_color=base_color;
 if(has_base_texture){surface_color*=texture(base_texture,UV).rgb;}
 vec3 color=mix(surface_color*light,char_color,char_amount);
 color+=vec3(2.3,.34,.025)*cracks*(.75+sin(elapsed*14.0+noise*8.0)*.25);
 ALBEDO=color;
 ALPHA=opacity;
}
