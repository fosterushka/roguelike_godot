"""Translate original shader equations without retuning constants."""
from pathlib import Path
import re,sys
source=Path(sys.argv[1])/'src/client/infrastructure/three'
text=(source/'tornado-vfx.ts').read_text()
skirt=(source/'tornado-dust-skirt.ts').read_text()
noise=re.search(r'weatherNoise = `([\s\S]+?)`;', (source/'weather-particles.ts').read_text())[1]
def section(text,name): return re.search(name+r' = `([\s\S]+?)`;',text)[1].replace('${weatherNoise}',noise)
def body(code): return code[code.index('  void main() {')+len('  void main() {'):code.rindex('}')]
def matrices(code):
 for arg in ['twist','angle']:
  code=code.replace(f'mat2(cos({arg}), -sin({arg}), sin({arg}), cos({arg}))',f'mat2(vec2(cos({arg}), -sin({arg})), vec2(sin({arg}), cos({arg})))')
 return code
header='shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\nuniform float uTime = 0.0;\nuniform float uIntensity = 0.0;\n'
v=body(section(text,'funnelVertexShader')).replace('position','VERTEX').replace('vUv = uv;','vUv = UV;').replace('gl_Position = projectionMatrix * modelViewMatrix * vec4(transformed, 1.0);','VERTEX = transformed;')
f=body(section(text,'funnelFragmentShader')).replace('gl_FragColor = vec4(color, alpha);','ALBEDO = color; ALPHA = alpha;').replace('#include <colorspace_fragment>','')
Path('presentation/world/tornado_funnel.gdshader').write_text(matrices(header+'varying vec2 vUv;\nvarying float vPulse;\nvarying vec3 vSurface;\n'+noise+'\nvoid vertex(){'+v+'}\nvoid fragment(){'+f+'}\n'))
f=body(section(skirt,'fragmentShader')).replace('gl_FragColor = vec4(color, alpha);','ALBEDO = color; ALPHA = alpha;').replace('#include <colorspace_fragment>','')
Path('presentation/world/tornado_skirt.gdshader').write_text(matrices(header+'varying vec2 vUv;\n'+noise+'\nvoid vertex(){vUv=UV;}\nvoid fragment(){'+f+'}\n'))
v=body(section(text,'particleVertexShader')).replace('aSeed','INSTANCE_CUSTOM.b').replace('aRadius','INSTANCE_CUSTOM.g').replace('aAngle','INSTANCE_CUSTOM.r').replace('vec4 mvPosition = modelViewMatrix * vec4(transformed, 1.0);','vec4 mvPosition = MODELVIEW_MATRIX * vec4(transformed, 1.0);').replace('gl_Position = projectionMatrix * mvPosition;','POSITION = PROJECTION_MATRIX * mvPosition;').replace('gl_PointSize =','float point_size =')
v+='\nPOSITION.xy += VERTEX.xy * point_size * 2.0 / VIEWPORT_SIZE * POSITION.w;\n'
f=body(section(text,'particleFragmentShader')).replace('gl_PointCoord','UV').replace('gl_FragColor = vec4(mix(vec3(0.39, 0.29, 0.19), vec3(0.15, 0.17, 0.18), step(0.72, vSeed)), shape * vAlpha);','ALBEDO = mix(vec3(0.39, 0.29, 0.19), vec3(0.15, 0.17, 0.18), step(0.72, vSeed)); ALPHA = shape * vAlpha;').replace('#include <colorspace_fragment>','')
Path('presentation/world/tornado_particles.gdshader').write_text(matrices(header+'varying float vAlpha;\nvarying float vSeed;\nvoid vertex(){'+v+'}\nvoid fragment(){'+f+'}\n'))
f=section(text,'dustFragmentShader').replace('varying','varying').replace('void main()', 'void fragment()').replace('gl_FragCoord','FRAGCOORD').replace('gl_FragColor','COLOR').replace('#include <colorspace_fragment>','')
Path('presentation/world/tornado_overlay.gdshader').write_text('shader_type canvas_item;\n'+f)
