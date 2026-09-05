import {writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const source=process.argv[2];
const {updateAmbientFigureBehavior}=await import(pathToFileURL(source+'/src/client/contexts/world/world-activity.ts'));
const {RNG}=await import(pathToFileURL(source+'/src/client/core/math.ts'));
const scenarios=[];
for(const id of ['roaming','threat_recovery','storm_origin','return_home']) {
 const random=new RNG(991827);
 const critter={group:{position:{x:id==='return_home'?20:0,y:0,z:0}},origin:{x:0,y:0,z:0},heading:.3,speed:.21,activityState:'roaming',fleeRemaining:0,recoveryRemaining:2};
 const frames=[];
 for(let i=0;i<480;i++){
  const threats=id==='threat_recovery'&&i<30?[{pos:{x:2,y:0,z:0}},{pos:{x:40,y:0,z:0}}]:[];
  const storm=id==='storm_origin'&&i<20;
  updateAmbientFigureBehavior(critter,1/60,threats,storm,random);
  if(i%20===0||i===479) frames.push({frame:i,x:critter.group.position.x,z:critter.group.position.z,heading:critter.heading,state:critter.activityState,flee:critter.fleeRemaining,recovery:critter.recoveryRemaining});
 }
 scenarios.push({id,frames});
}
writeFileSync(new URL('./fixtures/ambient.json',import.meta.url),JSON.stringify(scenarios));
