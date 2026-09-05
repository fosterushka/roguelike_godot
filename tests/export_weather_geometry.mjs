import {createRequire} from 'node:module';
import {writeFileSync} from 'node:fs';
import path from 'node:path';
const source=process.argv[2];
const require=createRequire(path.join(source,'package.json'));
const THREE=require('three');
const recipes={funnel:new THREE.CylinderGeometry(7.8,.75,24,48,24,true),bolt6:new THREE.CylinderGeometry(1,1,1,6),bolt5:new THREE.CylinderGeometry(1,1,1,5)};
const meshes=Object.entries(recipes).map(([name,g])=>{
 const indices=Array.from(g.index.array);for(let i=0;i<indices.length;i+=3)[indices[i+1],indices[i+2]]=[indices[i+2],indices[i+1]];
 const attributes={};for(const k of ['position','normal','uv'])attributes[k]=Array.from(g.attributes[k].array);
 return {name,attributes,indices,matrix:new THREE.Matrix4().elements,instances:null,cast_shadow:false,receive_shadow:false,material:{name:'weather-source',color:'ffffff',unshaded:true,opacity:1,roughness:1,metallic:0,lambert:false,backside:false,vertex_colors:false,transparent:false,double_sided:true,emission:'000000',emission_energy:0}};
});
writeFileSync('data/visual_models/weather_geometry.json',JSON.stringify({source:'tornado-vfx.ts and effects.ts original Three primitive buffers',meshes}));
