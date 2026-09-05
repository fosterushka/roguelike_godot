// Development-only: exact source Three buffers for native authored world recipes.
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';
const source=process.argv[2];if(!source)throw Error('Pass source checkout');
const require=createRequire(path.join(source,'package.json'));const THREE=require('three');
const {TERRAIN_COLORS}=await import(pathToFileURL(path.join(source,'src/client/infrastructure/three/terrain-surface.ts')));
const scene=readFileSync(path.join(source,'src/client/infrastructure/three/scene.ts'),'utf8');
const start=scene.indexOf('const materials = {')+'const materials = '.length;
const expression=scene.slice(start,scene.indexOf('\n  const sharedMaterials',start)).trim().replace(/;$/,'');
const materials=new Function('THREE','TERRAIN_COLORS',`return (${expression})`)(THREE,TERRAIN_COLORS);
const world=readFileSync(path.join(source,'src/client/infrastructure/three/world-builder.ts'),'utf8');
const section=world.slice(world.indexOf('  function createUtilityPole'),world.indexOf('  for (const village of layout.villages)'));
const recipes=new Map();
for(const match of section.matchAll(/\b(box|cylinder|cone|sphere)\(([^;]+?)\);/g)){
 const shape=match[1],args=match[2].split(',').map(s=>s.trim());const dims=args.slice(0,shape==='box'?3:shape==='cylinder'?4:shape==='cone'?3:1).map(Number);
 if(dims.some(x=>!Number.isFinite(x)))throw Error(match[0]);
 const names=[...match[2].matchAll(/materials\.(\w+)/g)].map(m=>m[1]);
 for(const name of names){const key=shape+':'+dims.map(x=>x.toFixed(6)).join(':')+':'+name;recipes.set(key,{shape,dims,name});}
}
const meshes=[];
for(const [key,{shape,dims,name}] of recipes){
 let g=shape==='box'?new THREE.BoxGeometry(...dims):shape==='cylinder'?new THREE.CylinderGeometry(...dims):shape==='cone'?new THREE.ConeGeometry(...dims):new THREE.IcosahedronGeometry(dims[0],1);
 const m=materials[name];if(m.flatShading){g=g.index?g.toNonIndexed():g.clone();g.computeVertexNormals();}
 const indices=g.index?Array.from(g.index.array):Array.from({length:g.attributes.position.count},(_,i)=>i);for(let i=0;i<indices.length;i+=3)[indices[i+1],indices[i+2]]=[indices[i+2],indices[i+1]];
 const attributes={};for(const k of ['position','normal','uv','color'])if(g.attributes[k])attributes[k]=Array.from(g.attributes[k].array);
 meshes.push({name:key,attributes,indices,matrix:new THREE.Matrix4().elements,instances:null,cast_shadow:true,receive_shadow:true,material:{name,color:m.color.getHexString(),roughness:m.roughness??.9,metallic:m.metalness??0,unshaded:!!m.isMeshBasicMaterial,lambert:!!m.isMeshLambertMaterial,backside:m.side===THREE.BackSide,vertex_colors:!!m.vertexColors,opacity:m.opacity,transparent:m.transparent,double_sided:m.side===THREE.DoubleSide,emission:m.emissive?.getHexString()||'000000',emission_energy:m.emissiveIntensity??0}});
}
writeFileSync('data/visual_models/world_primitives.json',JSON.stringify({source:'world-builder.ts exact literal primitives',provenance:{world:createHash('sha256').update(world).digest('hex'),scene:createHash('sha256').update(scene).digest('hex')},meshes}));
console.log(`${meshes.length} exact primitive recipes`);
