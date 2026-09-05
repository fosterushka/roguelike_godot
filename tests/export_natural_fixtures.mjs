import {createRequire} from 'node:module';
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const source=process.argv[2];
const require=createRequire(path.join(source,'package.json'));
const THREE=require('three');
const {RNG}=await import(pathToFileURL(path.join(source,'src/client/core/math.ts')).href);
const {runtimeWorldPropId,createRockFormationCollisionSegments}=await import(pathToFileURL(path.join(source,'src/shared/world-collision-manifest.ts')).href);
const {generateWorldLayout}=await import(pathToFileURL(path.join(source,'src/shared/world-layout.ts')).href);
const sourceText=readFileSync(path.join(source,'src/client/infrastructure/three/world-builder.ts'),'utf8');
const names=['addTree','addBoulder','addScrub','addDeadTree','createFenceLine','scatterGroundCover','rotateOffset','appendLandmarkBox','appendStructure','createRockFormation'];
const functions=names.map(name=>{const start=sourceText.indexOf('function '+name+'(');let end=sourceText.indexOf('{',start)+1,depth=1;for(;depth>0;end++){if(sourceText[end]==='{')depth++;else if(sourceText[end]==='}')depth--;}return sourceText.slice(start,end);}).join('\n');
const pools=['treeTrunks','treeCrowns','treeCrownsAlt','treeBranches','rockInstances','stoneInstances','scrubInstances','deadBrushInstances','grassTufts','flowerInstances','fencePosts','fenceRails','woodStructure','cliffFaces','cliffStrata'];
const durability={tree:[.9,28],deadTree:[.78,20],boulder:[.82,58],scrub:[.48,7],fence:[1.05,14]};
const run=new Function('THREE','RNG','runtimeWorldPropId','seed','durability','formation','createRockFormationCollisionSegments',`
const TAU=Math.PI*2,random=new RNG(seed^0x68bc21eb),v3=(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z),instances={},props=[],layout={seed},rockObstacles=[];
${pools.map(name=>`const ${name}='${name}';instances['${name}']=[];`).join('\n')}
function appendInstance(pool,position,rotation,scale){const dummy=new THREE.Object3D();dummy.position.copy(position);dummy.rotation.copy(rotation);dummy.scale.copy(scale);dummy.updateMatrix();instances[pool].push(dummy.matrix.elements);return instances[pool].length-1;}
function makeStaticPart(pool,instance){return {pool,instance};}
function registerDestructible(kind,x,z,scale=1,visual={},overrides={}){const radius=durability[kind][0]*scale,hp=durability[kind][1]*scale;props.push({id:runtimeWorldPropId(seed,kind,x,z,radius),kind,x,z,radius,hp,salvage:overrides.salvage||0,parts:visual.parts});}
function isOpenDressingPoint(){return true;}
${functions}
addTree(123.456,-27.821,1.2);addTree(-87.321,41.205,.78,true);addBoulder(72.961,221.884,1.3);addScrub(-60.543,91.319,.8,true);addDeadTree(45.678,-72.91,1.05);createFenceLine(72.882,-141.137,1.3,6);scatterGroundCover(77,-31,9,20,true);
createRockFormation(formation);
return {seed,state:random.state,instances,props,formation,rockObstacles};`);
writeFileSync('tests/fixtures/natural_props.json',JSON.stringify([0,72841,991827,4294967295].map(seed=>run(THREE,RNG,runtimeWorldPropId,seed,durability,generateWorldLayout(seed).rockFormations[0],createRockFormationCollisionSegments))));
console.log('Exact source natural factories fixtures written');
