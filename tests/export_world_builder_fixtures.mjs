import {createRequire} from 'node:module';
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const source=process.argv[2];
const require=createRequire(path.join(source,'package.json'));
const THREE=require('three');
const load=p=>import(pathToFileURL(path.join(source,p)).href);
const {buildWorld}=await load('src/client/infrastructure/three/world-builder.ts');
const {TERRAIN_COLORS}=await load('src/client/infrastructure/three/terrain-surface.ts');
const sourceText=readFileSync(path.join(source,'src/client/infrastructure/three/scene.ts'),'utf8');
const start=sourceText.indexOf('const materials = {')+'const materials = '.length;
const expression=sourceText.slice(start,sourceText.indexOf('\n  const sharedMaterials',start)).trim().replace(/;$/,'');
const materials=new Function('THREE','TERRAIN_COLORS',`return (${expression})`)(THREE,TERRAIN_COLORS);
const poolNames=['treeTrunks','treeCrowns','treeCrownsAlt','treeBranches','rockInstances','stoneInstances','scrubInstances','deadBrushInstances','grassTufts','flowerInstances','barrelInstances','crateInstances','fencePosts','fenceRails','ironStructure','metalStructure','woodStructure','redStructure','tankInstances','earthStructure','ruinStructure','scarStructure','trenches','bowls','rims','decals','char','cliffFaces','cliffStrata'];
const fixtures=[];
for(const seed of [0,72841,991827]){
 const cache=new Map();
 const runtime={THREE,materials,world:new THREE.Group(),quality:{effectScale:.82},v3:(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z),box:(x,y,z,m)=>new THREE.Mesh(new THREE.BoxGeometry(x,y,z),m),cylinder:(a,b,h,s,m)=>new THREE.Mesh(new THREE.CylinderGeometry(a,b,h,s),m),cone:(r,h,s,m)=>new THREE.Mesh(new THREE.ConeGeometry(r,h,s),m),sphere:(r,m,s=8)=>new THREE.Mesh(new THREE.IcosahedronGeometry(r,1),m),cachedGeometry:(key,create)=>{if(!cache.has(key))cache.set(key,create());return cache.get(key)}};
 const world=buildWorld(runtime,{dirtRoad:new THREE.Texture(),battlefieldScarDecal:new THREE.Texture()},seed);
 const meshes=[];runtime.world.traverse(node=>{if(node.isInstancedMesh)meshes.push(node)});meshes.shift();
 const pools={};
 for(let index=0;index<poolNames.length;index++){const mesh=meshes[index];const samples=[];for(const i of [...new Set([0,Math.floor(mesh.count/2),mesh.count-1])].filter(i=>i>=0&&i<mesh.count)){const matrix=new THREE.Matrix4();mesh.getMatrixAt(i,matrix);samples.push({index:i,matrix:matrix.elements})}pools[poolNames[index]]={count:mesh.count,samples};}
 fixtures.push(structuredClone({seed,props:world.destructibleProps.map(p=>({id:p.networkId,kind:p.kind,x:p.position.x,z:p.position.z,radius:p.radius,hp:p.hp,salvage:p.salvage,village_id:p.village?.id??null})),villages:world.villages.map(({id,x,z,tribute,deploymentAnchors})=>({id,x,z,tribute,deploymentAnchors})),rocks:world.rockObstacles,landmarks:world.landmarks.map(({id,x,z,type})=>({id,x,z,type})),pools,terrainDetails:world.terrainDetails,renderedFeatures:world.renderedBattlefieldFeatures,biomeCenters:world.biomeCenters.map(({x,z})=>({x,z})),roadsideAnchors:world.roadsideAnchors.map(({x,z})=>({x,z}))}));
 console.log('Exported source builder '+seed+': '+world.destructibleProps.length+'props');
 world.dispose();
}
writeFileSync('tests/fixtures/world_builder.json',JSON.stringify(fixtures));
