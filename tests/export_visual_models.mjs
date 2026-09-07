// Rebuild with: node --import <source>/node_modules/tsx/dist/loader.mjs tests/export_visual_models.mjs <source>
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
const source = process.argv[2];
if (!source) throw new Error('Pass original Iron Caravan source checkout');
const require = createRequire(path.join(source, 'package.json'));
const THREE = require('three');
const importSource = p => import(pathToFileURL(path.join(source, p)).href);
const { createPriorityEnemyViews } = await importSource('src/client/infrastructure/three/priority-enemy-views.ts');
const { createCaravanViews } = await importSource('src/client/infrastructure/three/caravan-views.ts');
const { createEnemyViews } = await importSource('src/client/infrastructure/three/enemy-views.ts');
const { setWeaponAimTarget } = await importSource('src/client/infrastructure/three/weapon-aim.ts');
const { createSoldierPool } = await importSource('src/client/infrastructure/three/soldier-pool.ts');
const { TERRAIN_COLORS } = await importSource('src/client/infrastructure/three/terrain-surface.ts');
const sceneSource = readFileSync(path.join(source,'src/client/infrastructure/three/scene.ts'),'utf8');
const materialStart = sceneSource.indexOf('const materials = {') + 'const materials = '.length;
const materialEnd = sceneSource.indexOf('\n  const sharedMaterials', materialStart);
const materialExpression = sceneSource.slice(materialStart, materialEnd).trim().replace(/;$/, '');
const materials = new Function('THREE','TERRAIN_COLORS',`return (${materialExpression})`)(THREE,TERRAIN_COLORS);
for(const [name, material] of Object.entries(materials)) material.name=name;
const cache = new Map();
const runtime = {THREE,materials,scene:new THREE.Group(),sharedMaterials:new Set(),random:{range:(a,b)=>(a+b)/2,pick:a=>a[0],int:(a,b)=>a,next:()=>.5},cachedGeometry:(key,f)=>{if(!cache.has(key))cache.set(key,f());return cache.get(key)},mesh:(g,m)=>new THREE.Mesh(g,m),box:(x,y,z,m)=>new THREE.Mesh(new THREE.BoxGeometry(x,y,z),m),cylinder:(a,b,h,s,m)=>new THREE.Mesh(new THREE.CylinderGeometry(a,b,h,s),m),cone:(r,h,s,m)=>new THREE.Mesh(new THREE.ConeGeometry(r,h,s),m),sphere:(r,m,s=8)=>new THREE.Mesh(new THREE.IcosahedronGeometry(r,1),m),addCartoonOutline:(parent,part,factor)=>{const m=new THREE.MeshBasicMaterial({color:0x241c16,side:THREE.BackSide});m.name='outline';const outline=new THREE.Mesh(part.geometry,m);outline.position.copy(part.position);outline.quaternion.copy(part.quaternion);outline.scale.copy(part.scale).multiplyScalar(factor);outline.name='outline';parent.add(outline)}};
runtime.mesh=(geometry,material,cast=true,receive=true)=>{const result=new THREE.Mesh(geometry,material);result.castShadow=cast;result.receiveShadow=receive;result.userData.sharedGeometry=true;return result;};
runtime.box=(x,y,z,material=materials.stone)=>runtime.mesh(runtime.cachedGeometry(`b:${x}:${y}:${z}`,()=>new THREE.BoxGeometry(x,y,z)),material);
runtime.cylinder=(a,b,h,segments=8,material=materials.wood)=>runtime.mesh(runtime.cachedGeometry(`c:${a}:${b}:${h}:${segments}`,()=>new THREE.CylinderGeometry(a,b,h,segments)),material);
runtime.cone=(r,h,segments=6,material=materials.roof)=>runtime.mesh(runtime.cachedGeometry(`n:${r}:${h}:${segments}`,()=>new THREE.ConeGeometry(r,h,segments)),material);
runtime.sphere=(r,material=materials.stone,segments=8)=>runtime.mesh(runtime.cachedGeometry(`s:${r}:${segments}`,()=>new THREE.IcosahedronGeometry(r,1)),material);
const caravan = createCaravanViews(runtime);
const priority = createPriorityEnemyViews(runtime,{createWorldHealthBar:()=>null,disposeWorldHealthBar:()=>{}});
const enemies = createEnemyViews(runtime,{...caravan,createWorldHealthBar:()=>null,disposeWorldHealthBar:()=>{}});
const output = path.resolve('data/visual_models');mkdirSync(output,{recursive:true});
const round = x => Math.round(x*1e6)/1e6;
let total=0;
function save(name, root) {
  root.updateMatrixWorld(true);
  const bindings = new Map();
  const bind = (node, role, extra={}) => { if(node) bindings.set(node,{role,initial_visible:node.visible,...extra}); };
  for(const [role,node] of Object.entries(root.userData.semanticBindings||{}))bind(node,role);
  for(const node of root.userData.wheels||[])bind(node,'wheel',{phase:node.userData.phase||0,baseY:node.userData.baseY??node.position.y});
  for(const node of root.userData.rotors||[])bind(node,'rotor');
  for(const node of root.userData.legs||[])bind(node,'walker_leg',{phase:node.userData.phase||0});
  for(const [kind,node] of Object.entries(root.userData.componentAnchors||{}))bind(node,'boss_component',{kind});
  if(root.userData.weaponPitchPivot)bind(root.userData.weaponPitchPivot,'weapon_pitch');
  const jammer=root.userData.counterDroneJammerView;if(jammer){bind(jammer.head,'jammer_head');bind(jammer.scan,'jammer_scan');jammer.pulseBars.forEach((node,index)=>bind(node,'jammer_pulse',{pulse_index:index}));}
  const motionBindings=object=>{const chain=[];let node=object;while(node){if(bindings.has(node)){const parentMatrix=node.parent?.matrixWorld||new THREE.Matrix4();chain.unshift({...bindings.get(node),matrix:node.matrixWorld.elements.map(round),parentMatrix:parentMatrix.elements.map(round),position:node.position.toArray().map(round),rotation:[node.rotation.x,node.rotation.y,node.rotation.z].map(round),rotationOrder:node.rotation.order,scale:node.scale.toArray().map(round)});}if(node===root)break;node=node.parent;}return chain;};
  const meshes=[];
  root.traverse(object=>{
    if(!object.isMesh) return;
    const mat=object.material;const geometry=mat.flatShading?(object.geometry.index?object.geometry.toNonIndexed():object.geometry.clone()):object.geometry;if(mat.flatShading)geometry.computeVertexNormals();
    const indices=geometry.index?Array.from(geometry.index.array):Array.from({length:geometry.attributes.position.count},(_,i)=>i);
    // Godot front faces use clockwise winding, Three uses counterclockwise.
    for(let i=0;i<indices.length;i+=3)[indices[i+1],indices[i+2]]=[indices[i+2],indices[i+1]];
    const attributes={};
    for(const key of ['position','normal','uv','color']) if(geometry.attributes[key]) attributes[key]=Array.from(geometry.attributes[key].array,round);
    object.userData.exportMeshIndex=meshes.length;
    meshes.push({name:object.name||'part',bindings:motionBindings(object),rig:object.userData.animationRig||null,cast_shadow:object.castShadow,receive_shadow:object.receiveShadow,matrix:object.matrixWorld.elements.map(round),attributes,indices,material:{name:mat.name,color:mat.color?.getHexString()||'ffffff',roughness:mat.roughness??.9,metallic:mat.metalness??0,unshaded:mat.isMeshBasicMaterial||false,lambert:mat.isMeshLambertMaterial||false,backside:mat.side===THREE.BackSide,vertex_colors:mat.vertexColors||false,texture:mat.map?.name||'',opacity:mat.opacity,transparent:mat.transparent,double_sided:mat.side===THREE.DoubleSide,emission:mat.emissive?.getHexString()||'000000',emission_energy:mat.emissiveIntensity||0,additive:mat.blending===THREE.AdditiveBlending},animate:root.userData.wheels?.includes(object)?'wheel':root.userData.rotors?.includes(object)?'rotor':'',instances:object.isInstancedMesh?Array.from({length:object.count},(_,i)=>{const m=new THREE.Matrix4();object.getMatrixAt(i,m);return m.elements.map(round)}):null});
  });
  const box = new THREE.Box3().setFromObject(root);const size=box.getSize(new THREE.Vector3()).toArray();
  writeFileSync(path.join(output,`${name}.json`),JSON.stringify({source:'Iron Caravan original Three.js procedural factory',name,bounds:size,meshes}));total+=meshes.length;return {name,meshes:meshes.length,bounds:size};
}
const catalog=[];
for(const kind of ['jammerTruck','repairCrawler','minelayer'])catalog.push(save(kind,priority.createPriorityVehicleView(kind,0,0).group));
for(const kind of ['bike','buggy']){const view=enemies.createRaiderVehicleView(kind,0,0);view.group.userData.wheels=view.wheels;catalog.push(save(kind,view.group));}
for(const kind of ['drone','kamikaze']){const view=enemies.createDroneView(kind,0,0);view.group.position.y=0;view.group.userData.rotors=view.rotors;catalog.push(save(kind,view.group));}
for(const boss of [false,true]){const view=enemies.createEnemyKeepView(0,0,boss);view.group.userData.componentAnchors=view.componentAnchors;catalog.push(save(boss?'boss':'raider',view.group));}
for(let tier=1;tier<=3;tier++)catalog.push(save(`garrison_${tier}`,enemies.createGarrisonView(0,0,tier).group));
const airdropView=enemies.createAirdropView(0,0);airdropView.group.userData.semanticBindings=Object.fromEntries(['aura','canopyRig','flareRoot','flareCore','flareGlow','signalBeam'].map(key=>['airdrop_'+key,airdropView[key]]));catalog.push(save('airdrop',airdropView.group));const healView=enemies.createHealCartView(0,0);healView.group.userData.wheels=healView.wheels;healView.group.userData.semanticBindings={heal_cart_aura:healView.aura};catalog.push(save('heal_cart',healView.group));
for(const kind of ['fuel','salvage']){const g=enemies.createPickupView(new THREE.Vector3(),kind);g.position.y=0;catalog.push(save(`pickup_${kind}`,g));}
for(const kind of ['bullet','sabot','rocket','grenade'])for(const enemy of [false,true])catalog.push(save(`projectile_${enemy?'enemy_':''}${kind}`,enemies.createProjectileView(kind,enemy)));
for(const [name, geometry] of Object.entries({sphere:new THREE.IcosahedronGeometry(1,1),chunk:new THREE.DodecahedronGeometry(.28,0),gear:new THREE.TorusGeometry(.22,.07,5,9),collapse_gear:new THREE.TorusGeometry(.24,.065,5,9),masonry:new THREE.DodecahedronGeometry(.52,0),shockwave:new THREE.RingGeometry(.4,.7,30)})){
 const group=new THREE.Group();group.add(runtime.mesh(geometry,materials.metal,false,false));catalog.push(save('fx_'+name,group));
}
for(const segments of [4,5,6,7,8,9])for(const cone of [false,true]){
 const group=new THREE.Group();group.add(runtime.mesh(cone?new THREE.ConeGeometry(1,1,segments):new THREE.CylinderGeometry(1,1,1,segments),materials.metal,false,false));catalog.push(save(`fx_${cone?'cone':'cylinder'}${segments}`,group));
}
const {createVehicleWreckSystem}=await importSource('src/client/infrastructure/three/vehicle-wrecks.ts');
const wreckSystem=createVehicleWreckSystem(runtime);
for(const kind of ['bike','buggy','jammerTruck','repairCrawler','minelayer']){
 const wreck=wreckSystem.spawn({type:['bike','buggy'].includes(kind)?kind:'priorityVehicle',kind,id:'export',pos:new THREE.Vector3()});
 for(const smoke of wreck.smoke)wreck.visual.remove(smoke);
 catalog.push(save('wreck_'+kind,wreck.visual));
}
wreckSystem.dispose();
const animationFixtures=[];
const soldierScene=new THREE.Group();const pool=createSoldierPool({...runtime,scene:soldierScene});
for(const kind of ['rifleman','ak','bazooka','bomber']){
  const entity={kind,group:new THREE.Group(),instanceIndex:pool.acquireSoldierInstance(kind),phase:0,animationTime:0,moveBlend:0};pool.syncSoldierInstance(entity);
  const group=new THREE.Group();
  const rigParts=[{role:'body',position:[0,1.08,0],rotation:[0,0,0]},{role:'head',position:[0,1.68,.015],rotation:[0,0,0]},{role:'leg',side:-1,position:[-.17,.74,0],rotation:[0,0,0]},{role:'leg',side:1,position:[.17,.74,0],rotation:[0,0,0]},{role:'arm',side:-1,position:[-.39,1.4,0],rotation:[0,0,-.1]},{role:'arm',side:1,position:[.39,1.4,0],rotation:[0,0,.1]},{role:'weapon',side:1,position:kind==='bomber'?[0,1.13,.3]:[-.46,1.23,.24],rotation:[0,0,-.08]}];let rigIndex=0;
  soldierScene.traverse(o=>{if(!o.isInstancedMesh)return;const matrix=new THREE.Matrix4();o.getMatrixAt(entity.instanceIndex,matrix);if(matrix.determinant()===0)return;const part=new THREE.Mesh(o.geometry,o.material);matrix.decompose(part.position,part.quaternion,part.scale);part.userData.animationRig={kind,...rigParts[rigIndex++]};group.add(part)});
  catalog.push(save(kind,group));
  for(const sample of [{phase:0,animationTime:0,moveBlend:0,gaitDirection:1,attackAnimation:0},{phase:1.7,animationTime:2.3,moveBlend:.72,gaitDirection:-.4,attackAnimation:.38},{phase:4.2,animationTime:1.1,moveBlend:1,gaitDirection:1,attackAnimation:.8}]){
    Object.assign(entity,sample);pool.syncSoldierInstance(entity);const matrices=[];
    soldierScene.traverse(o=>{if(!o.isInstancedMesh)return;const m=new THREE.Matrix4();o.getMatrixAt(entity.instanceIndex,m);if(m.determinant()!==0)matrices.push(m.elements);});
    animationFixtures.push({kind,pose:{phase:sample.phase,animation_time:sample.animationTime,move_blend:sample.moveBlend,gait_direction:sample.gaitDirection,attack_animation:sample.attackAnimation,instance_index:entity.instanceIndex},matrices});
  }
  pool.releaseSoldierInstance(entity);
}
const {updateCounterDroneJammerVisual}=await importSource('src/client/infrastructure/three/counter-drone-jammer-view.ts');
const jammerVisual=caravan.createModuleVisual('counterDroneJammer');
updateCounterDroneJammerVisual(jammerVisual,1.7);jammerVisual.updateMatrixWorld(true);const jammerMatrices=[];jammerVisual.traverse(part=>{if(part.isMesh)jammerMatrices.push(part.matrixWorld.elements)});
writeFileSync('tests/fixtures/jammer_animation.json',JSON.stringify({elapsed:1.7,matrices:jammerMatrices}));
writeFileSync('tests/fixtures/source_animation.json',JSON.stringify(animationFixtures));
if(process.env.EXPORT_WORLD === '1'){
 const {buildWorld}=await importSource('src/client/infrastructure/three/world-builder.ts');
 const texture=new THREE.Texture();texture.name='world/dirt-road-v2.png';const crater=new THREE.Texture();crater.name='fx/crater-impact-v2.png';
 runtime.world=new THREE.Group();runtime.v3=(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z);runtime.quality={effectScale:.82};
 const world=buildWorld(runtime,{dirtRoad:texture,battlefieldScarDecal:crater},72841);
 catalog.push(save('world_72841',runtime.world));
 writeFileSync(path.join(output,'world_layout.json'),JSON.stringify({seed:world.seed,roads:world.kingdomRoads,landmarks:world.landmarks.map(({id,x,z,type})=>({id,x,z,type})),villages:world.villages.map(({id,x,z,tribute,deploymentAnchors})=>({id,x,z,tribute,deploymentAnchors})),activityRoutes:world.activityRoutes,activityAnchors:world.activityAnchors,activityBlockers:world.activityBlockers,rockObstacles:world.rockObstacles,props:world.destructibleProps.map(p=>({id:p.networkId,kind:p.kind,position:p.position,radius:p.radius,hp:p.hp,salvage:p.salvage,village_id:p.village?.id||null,parts:(p.parts||[]).filter(part=>part.instanceId>=0).map(part=>({mesh:part.instances.userData.exportMeshIndex,instance:part.instanceId,matrix:part.matrix.elements.map(round)})),meshes:(()=>{const refs=[];for(const group of [...(p.groups||[]),...(p.group?[p.group]:[])])group.traverse(o=>{if(o.isMesh&&o.userData.exportMeshIndex!==undefined)refs.push(o.userData.exportMeshIndex)});return [...new Set(refs)]})()})),terrainDetails:world.terrainDetails,battlefieldFeatures:world.battlefieldFeatures}));
}
const files=['effects.ts','explosion-fireball.ts','rocket-smoke-trail.ts','smoke-shader.ts','vehicle-wrecks.ts','particle-shader.ts','battlefield-retention.ts','weapon-aim.ts','priority-enemy-views.ts','walker-trailer-view.ts','player-vehicle-model.ts','player-vehicle-details.ts','enemy-views.ts','caravan-views.ts','soldier-pool.ts','world-builder.ts','terrain-surface.ts','road-network.ts','battlefield-scars.ts','counter-drone-jammer-view.ts','scene.ts'];
const provenance=files.map(file=>({file:`src/client/infrastructure/three/${file}`,sha256:createHash('sha256').update(readFileSync(path.join(source,'src/client/infrastructure/three',file))).digest('hex')}));
const retired = /^(mine_|player$|walker_trailer$|evolution_|weapon_)/;
let retained=[];try{retained=JSON.parse(readFileSync(path.join(output,'catalog.json'),'utf8')).models.filter(entry=>!catalog.some(current=>current.name===entry.name)&&!retired.test(entry.name));}catch{}
writeFileSync(path.join(output,'catalog.json'),JSON.stringify({models:[...catalog,...retained],provenance},null,2));
console.log(JSON.stringify({models:catalog.length,meshes:total},null,2));

// Executed original source effect functions provide independent numerical fixtures.
const { createEffects } = await importSource('src/client/infrastructure/three/effects.ts');
const { RNG } = await importSource('src/client/core/math.ts');
const { explosionFireballLifecycle } = await importSource('src/client/infrastructure/three/explosion-fireball.ts');
const { rocketSmokeVisualState, sampleRocketTrailSegment } = await importSource('src/client/infrastructure/three/rocket-smoke-trail.ts');
const effectRuntime={...runtime,scene:new THREE.Group(),quality:{effectScale:.82,pixelRatio:1},random:new RNG(81173),v3:(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z)};
const effects=createEffects(effectRuntime,{sound:{explosion(){}},flashImpact(){},textures:{}});
const debrisCases=[];
for(const [kind,intensity,seed] of [['mixed',.75,81173],['wood',2.5,393],['stone',1,98],['mixed',2.2,4111]]){
 effects.clear();effectRuntime.random.state=seed;effects.spawnCrashDebris(new THREE.Vector3(3,0,8),intensity,kind);
 debrisCases.push({kind,intensity,seed,random_state:effectRuntime.random.state,effects:effects.items.map(e=>{e.visual.updateMatrixWorld(true);return {position:e.visual.position.toArray(),rotation:[e.visual.rotation.x,e.visual.rotation.y,e.visual.rotation.z],scale:e.visual.scale.toArray(),velocity:e.vel.toArray(),spin:e.spin.toArray(),life:e.life,floor_y:e.floorY,bounces:e.bounces,parts:e.visual.children.map(p=>({matrix:p.matrix.elements,color:p.material.color.getHexString()}))};})});
}
const collapseCases=[];
for(const [type,boss,seed] of [['vehicle',false,711],['keep',false,384],['garrison',false,932],['keep',true,499]]){
 const rt={...effectRuntime,scene:new THREE.Group(),random:new RNG(seed)};
 const fx=createEffects(rt,{sound:{explosion(){}},flashImpact(){},textures:{rocketScorchDecals:[new THREE.Texture(),new THREE.Texture()],explosionFireball:new THREE.Texture()}});
 const group=new THREE.Group();group.add(runtime.box(1,1,1));
 fx.spawnFortCollapse({}, {type,boss,pos:new THREE.Vector3(3,0,8),radius:5,group});
 const offset=type==='keep'||type==='garrison'?1:0;const count=type==='vehicle'?4:boss?32:type==='garrison'?24:16;
 collapseCases.push({type,boss,seed,random_state:rt.random.state,effects:fx.items.slice(offset,offset+count).map(e=>{e.visual.updateMatrixWorld(true);return {position:e.visual.position.toArray(),rotation:[e.visual.rotation.x,e.visual.rotation.y,e.visual.rotation.z],scale:e.visual.scale.toArray(),velocity:e.vel.toArray(),spin:e.spin.toArray(),life:e.life,floor_y:e.floorY,bounces:e.bounces,parts:e.visual.children.map(p=>({matrix:p.matrix.elements,color:p.material.color.getHexString()}))};})});fx.dispose();
}
writeFileSync('tests/fixtures/source_fx.json',JSON.stringify({collapse:collapseCases,debris:debrisCases,fireball:[.52,.4,.26,.08,0].map(life=>({life,state:explosionFireballLifecycle(life)})),rocket:[0,.1,.7,1.7].map(age=>({age,state:rocketSmokeVisualState(age,1.7,.64,.92)})),segment:sampleRocketTrailSegment({x:1,y:2,z:3},{x:8,y:4,z:9},.38,.21,.2,8)}));
effects.dispose();
