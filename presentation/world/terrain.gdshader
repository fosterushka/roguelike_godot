shader_type spatial;
render_mode diffuse_burley;
uniform float uTime = 0.0;
varying vec3 world_point;
float terrain_hash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float terrain_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(terrain_hash(i),terrain_hash(i+vec2(1,0)),f.x),mix(terrain_hash(i+vec2(0,1)),terrain_hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_point.xz;
 float broad=terrain_noise(p*.028),medium=terrain_noise(p*.11+vec2(17,4)),fine=terrain_noise(p*.52+vec2(6,23)),micro=terrain_noise(p*2.6+vec2(31,9));
 float soil=smoothstep(.5,.78,broad+medium*.28);
 float dry=smoothstep(.58,.86,terrain_noise(p*.065+vec2(-11,28))+fine*.12);
 float rock=smoothstep(.61,.84,terrain_noise(p*.19+vec2(44,-8))+soil*.2);
 float pebble=smoothstep(.9,.975,micro)*rock;
 float pale=smoothstep(.945,.992,terrain_hash(floor(p*2.9+13.0)));
 float crack=(1.0-smoothstep(.015,.055,abs(fine-.5)))*soil*.48;
 vec3 color=mix(vec3(.282,.373,.196),vec3(.635,.604,.282),medium*.82+fine*.1);
 color=mix(color,vec3(.412,.271,.169),soil*.68);
 color=mix(color,vec3(.651,.420,.220),dry*.32);
 color=mix(color,vec3(.561,.545,.447),pebble*.72);
 color+=pale*vec3(.075,.065,.035);color-=crack*vec3(.13,.105,.07);
 color+=sin(dot(p,vec2(.048,.029))+uTime*.22)*.008;
 ALBEDO=color;ROUGHNESS=clamp(.76+soil*.15+micro*.08-pebble*.2,.58,1.0);
}
