import {createRequire} from 'node:module';
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const source=process.argv[2], require=createRequire(path.join(source,'package.json')), THREE=require('three');
const {RNG,clamp}=await import(pathToFileURL(path.join(source,'src/client/core/math.ts')));
const {createWindDebrisField}=await import(pathToFileURL(path.join(source,'src/client/infrastructure/three/wind-debris.ts')));
const effects=readFileSync(path.join(source,'src/client/infrastructure/three/effects.ts'),'utf8');
const fn=effects.slice(effects.indexOf('  function spawnLightningStrike('),effects.indexOf('  function spawnConductiveArc('));
const bolts=[];
for(const seed of [0,991827,4294967295]){
 const scene=new THREE.Scene(),events=[];
 const spawn=new Function('THREE','RNG','clamp','v3','scaledEffectCylinder','scene','push',fn+'; return spawnLightningStrike;')(THREE,RNG,clamp,(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z),(r,h,s,m)=>{const mesh=new THREE.Mesh(new THREE.CylinderGeometry(1,1,1,s),m);mesh.scale.set(r,h,r);return mesh;},scene,e=>events.push(e));
 spawn(new THREE.Vector3(),seed);scene.updateMatrixWorld(true);
 bolts.push({seed,life:events[0].life,matrices:scene.children[0].children.filter(n=>n.isMesh).map(n=>n.matrixWorld.elements)});
}
const scene=new THREE.Scene(),camera=new THREE.OrthographicCamera(-49.6,49.6,31,-31,.1,500);camera.position.set(34,45,39);camera.lookAt(0,0,5);camera.updateMatrixWorld(true);camera.updateProjectionMatrix();
const random=new RNG(991827),field=createWindDebrisField({THREE,scene,camera,random:{next:()=>random.next(),range:(a,b)=>random.range(a,b)},cachedGeometry:(_,f)=>f()},{capacity:84});
for(let i=0;i<8;i++)field.spawn({direction:new THREE.Vector3(.6,0,.8),strength:30});
for(let i=0;i<60;i++)field.update(1/60);
const matrix=new THREE.Matrix4(),color=new THREE.Color();const wind=[];
for(let i=0;i<8;i++){scene.children[0].getMatrixAt(i,matrix);scene.children[0].getColorAt(i,color);wind.push({matrix:matrix.elements.slice(),color:color.toArray()});}
const {createWeatherParticleGeometry}=await import(pathToFileURL(path.join(source,'src/client/infrastructure/three/weather-particles.ts')));
const {createWeatherLayers}=await import(pathToFileURL(path.join(source,'src/client/infrastructure/three/weather-layers.ts')));
const shaderSource=readFileSync(path.join(source,'src/client/infrastructure/three/weather-shader.ts'),'utf8').replace(/^import .*;$/mg,'').replace('export function createWeatherShader','function createWeatherShader').replace(': boolean[] | null','');
const createWeather=new Function('isTouch','createWeatherParticleGeometry','createWeatherLayers',shaderSource+';return createWeatherShader;')(false,createWeatherParticleGeometry,createWeatherLayers);
const weatherScene=new THREE.Scene();
const weather=createWeather({THREE,scene:weatherScene,camera,quality:{effectScale:.82}},{getEnvironment:()=>({anchor:new THREE.Vector3(12,0,-4),velocity:new THREE.Vector3(3,0,7),windDirection:new THREE.Vector3(.6,0,.8),windStrength:30})});
const uniforms=weatherScene.children[0].material.uniforms;
const snapshot=()=>({time:uniforms.uTime.value,rain:uniforms.uRain.value,storm:uniforms.uStorm.value,fog:uniforms.uFog.value,lightning:uniforms.uLightning.value,drift:uniforms.uDrift.value.toArray(),visible:weatherScene.children.map(x=>x.visible)});
const rain=[];
for(const type of ['storm','foggy','rainy','clear']){
 weather.setWeather(type);
 for(let i=0;i<60;i++)weather.update(1/60);
 rain.push({type,...snapshot()});
}
weather.flashLightning();weather.update(.1);rain.push({type:'flash',...snapshot()});
const particles=weatherScene.children.map(layer=>({capacity:layer.geometry.instanceCount,data:Array.from(layer.geometry.attributes.aParticle.array.slice(0,32))}));
writeFileSync('tests/fixtures/weather_view.json',JSON.stringify({bolts,wind,rain,particles}));
