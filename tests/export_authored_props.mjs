// Evaluate original factory bodies, independently of GDScript recipes.
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdtempSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import os from 'node:os';
const source=process.argv[2];if(!source)throw Error('Pass original checkout');
const require=createRequire(path.join(source,'package.json'));const THREE=require('three');const esbuild=require('esbuild');
const sourcefile=path.join(source,'src/client/infrastructure/three/world-builder.ts');
let code=readFileSync(sourcefile,'utf8');
const facade={utility_pole:'createUtilityPole',wreck:'createRoadsideWreck',prop_cluster:'createPropCluster',well:'createWell',market_stall:'createMarketStall',windmill:'createWindmill',watchtower:'createWatchtower',pumpjack:'createPumpjack',rock_spire:'createRockSpire',dead_grove:'createDeadGrove',scrap_yard:'createScrapYard',water_tower:'createWaterTower',recycling_factory:'createRecyclingFactory',cargo_crane:'createCargoCrane',refinery:'createRefinery',satellite_array:'createSatelliteArray',critter:'createCritter',grazer:'createGrazer',house:'createHouse',village:'createVillage'};
const injected=`
if(sceneRuntime.factoryTest){
const factories={${Object.entries(facade).map(([k,v])=>`${k}:${v}`).join(',')}};
const initialChildren=world.children.length;
factories[sceneRuntime.factoryTest.name](...sceneRuntime.factoryTest.args);
return {state:worldRandom.state,groups:world.children.slice(initialChildren),props:destructibleProps,animators:ambientAnimators,critters:ambientCritters,villages,activityBlockers,pools:staticInstanceMeshes};
}
`;
code=code.replace('  for (const village of layout.villages) createVillage',injected+'  for (const village of layout.villages) createVillage');
const result=await esbuild.build({stdin:{contents:code,resolveDir:path.dirname(sourcefile),loader:'ts'},bundle:true,platform:'node',format:'esm',write:false});
const temp=mkdtempSync(path.join(os.tmpdir(),'source-authored-'));const bundle=path.join(temp,'factory.mjs');writeFileSync(bundle,result.outputFiles[0].text);const {buildWorld}=await import(pathToFileURL(bundle));
const {TERRAIN_COLORS}=await import(pathToFileURL(path.join(source,'src/client/infrastructure/three/terrain-surface.ts')));
const scene=readFileSync(path.join(source,'src/client/infrastructure/three/scene.ts'),'utf8');const start=scene.indexOf('const materials = {')+'const materials = '.length;
const materials=new Function('THREE','TERRAIN_COLORS',`return (${scene.slice(start,scene.indexOf('\n  const sharedMaterials',start)).trim().replace(/;$/,'')})`)(THREE,TERRAIN_COLORS);for(const [name,mat] of Object.entries(materials))mat.name=name;
function encode(node){node.updateMatrix();return {matrix:node.matrix.elements,mesh:node.isMesh?{shape:node.geometry.type,parameters:node.geometry.parameters,material:node.material.name,cast:node.castShadow,receive:node.receiveShadow}:null,children:node.children.map(encode)}}
const fixtures=[];
for(const seed of [0,72841,991827])for(const name of Object.keys(facade)){
 const args=name==='village'?['village-test',123.456789,257.891234,5]:['utility_pole','wreck','prop_cluster'].includes(name)?[123.456789,257.891234,1.2]:['well','rock_spire','dead_grove','critter','grazer'].includes(name)?[123.456789,257.891234]:[123.456789,257.891234,.37];
 const cache=new Map();const mesh=(g,m)=>{const o=new THREE.Mesh(g,m);o.castShadow=true;o.receiveShadow=true;return o};
 const runtime={THREE,materials,world:new THREE.Group(),factoryTest:{name,args},quality:{effectScale:.82},v3:(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z),box:(x,y,z,m)=>mesh(new THREE.BoxGeometry(x,y,z),m),cylinder:(a,b,h,s,m)=>mesh(new THREE.CylinderGeometry(a,b,h,s),m),cone:(r,h,s,m)=>mesh(new THREE.ConeGeometry(r,h,s),m),sphere:(r,m)=>mesh(new THREE.IcosahedronGeometry(r,1),m),cachedGeometry:(key,f)=>{if(!cache.has(key))cache.set(key,f());return cache.get(key)}};
 const data=buildWorld(runtime,{dirtRoad:new THREE.Texture(),battlefieldScarDecal:new THREE.Texture()},seed);
 fixtures.push({seed,name,args,state:data.state,groups:data.groups.map(encode),props:data.props.map(p=>({id:p.networkId,kind:p.kind,x:p.position.x,z:p.position.z,radius:p.radius,hp:p.hp,salvage:p.salvage,village_id:p.village?.id??null})),animators:data.animators.map(({type,speed,phase,amplitude})=>({type,speed,phase,amplitude})),critters:data.critters.map(({group,origin,...rest})=>({...rest,origin:origin.toArray()})),activityBlockers:data.activityBlockers,poolCounts:data.pools.map(p=>p.count)});
}
writeFileSync('tests/fixtures/authored_props.json',JSON.stringify(fixtures));console.log(`${fixtures.length} independent source authored cases`);
