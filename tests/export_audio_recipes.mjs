// Run with the original checkout's tsx loader. No WebAudio context is created.
import {pathToFileURL} from 'node:url';
import {writeFileSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import path from 'node:path';
const source=process.argv[2];
const file=path.join(source,'src/client/audio/sound-system.ts');
const {SoundSystem}=await import(pathToFileURL(file).href);
const sound=new SoundSystem();
let parts=[];
sound.tone=(frequency,duration,type='sine',gain=.035,slide=0,delay=0,filter=0)=>parts.push({kind:'tone',frequency,duration,type,gain,slide,delay,filter});
sound.noise=(duration,gain,frequency,delay=0,type='lowpass')=>parts.push({kind:'noise',duration,gain,frequency,delay,type});
sound.eventReady=()=>true;
const recipes={};
const calls=[];
for(const name of ['hit','crush','bumper','pickup','explosion','horn','contractProgress','contractComplete','repairPulse','mineDrop','mineTrigger','evolve','module','nitro','lowHp','level'])calls.push([name,name,[]]);
for(const name of ['shot','enemyShot'])for(const kind of ['bullet','grenade','sabot','rocket'])calls.push([`${name}_${kind}`,name,[kind]]);
for(const name of ['spawnWarning','activityAnnouncement','activityOutcome','jammerStatus'])for(const flag of [false,true])calls.push([`${name}_${flag}`,name,[flag]]);
for(const kind of ['priority','jammerTruck','repairCrawler'])calls.push([`priorityWarning_${kind}`,'priorityWarning',[kind]]);
for(const distance of [0,130,260,520])calls.push([`thunder_${distance}`,'thunder',[distance]]);
calls.push(["countdownGo","tone",[320,.16,"triangle",.035,280]]);
calls.push(["repairAbility","tone",[340,.15,"triangle",.035,170]]);
calls.push(["mineHack","tone",[620,.12,"square",.025,90]]);
for(const [id,name,args] of calls){parts=[];sound[name](...args);recipes[id]=parts;}
writeFileSync('data/audio_recipes.json',JSON.stringify({source:'src/client/audio/sound-system.ts',sha256:createHash('sha256').update(readFileSync(file)).digest('hex'),master:.72,sfx:.86,recipes},null,2));
console.log(`Extracted ${Object.keys(recipes).length} original sound recipes`);
