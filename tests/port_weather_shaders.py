"""Translate the original weather layer shaders, preserving their equations."""
from pathlib import Path
import re,sys
source=Path(sys.argv[1])/'src/client/infrastructure/three'
noise=re.search(r'weatherNoise = `([\s\S]+?)`;', (source/'weather-particles.ts').read_text())[1]
def section(text,name): return re.search(name+r' = `([\s\S]+?)`;',text)[1].replace('${weatherNoise}',noise)
def split(code):
 head,body=code.split('  void main() {',1)
 return head,body[:body.rindex('}')]
for name,file,vname,fname in [('rain','weather-shader.ts','vertexShader','fragmentShader'),('splash','weather-layers.ts','splashVertexShader','splashFragmentShader'),('mist','weather-layers.ts','mistVertexShader','mistFragmentShader')]:
 text=(source/file).read_text()
 vh,v=split(section(text,vname)); fh,f=split(section(text,fname))
 declarations=[]
 for line in (vh+fh).splitlines():
  if line.strip().startswith(('uniform','varying')) and line.strip() not in declarations: declarations.append(line.strip())
 v=v.replace('aParticle','INSTANCE_CUSTOM').replace('modelViewMatrix','MODELVIEW_MATRIX').replace('projectionMatrix','PROJECTION_MATRIX').replace('position','VERTEX').replace('vUv = uv;', 'vUv = UV;').replace('gl_Position','POSITION')
 f=f.replace('gl_FragColor = vec4(color, alpha);','ALBEDO = color; ALPHA = alpha;').replace('gl_FragColor = vec4(color, alpha * (1.0 + uLightning * 0.5));','ALBEDO = color; ALPHA = alpha * (1.0 + uLightning * 0.5);').replace('gl_FragColor = vec4(mix(vec3(0.46, 0.62, 0.68), vec3(0.9, 0.96, 1.0), uLightning), alpha);','ALBEDO = mix(vec3(0.46, 0.62, 0.68), vec3(0.9, 0.96, 1.0), uLightning); ALPHA = alpha;').replace('#include <colorspace_fragment>','')
 result='shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\n'+'\n'.join(declarations)+'\n'
 if name=='mist': result+=noise+'\n'
 result+='void vertex(){'+v+'}\nvoid fragment(){'+f+'}\n'
 Path('presentation/world/weather_'+name+'.gdshader').write_text(result)
