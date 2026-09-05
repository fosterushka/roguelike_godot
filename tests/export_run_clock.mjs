import {readFileSync,writeFileSync} from 'node:fs';
import path from 'node:path';
const source=process.argv[2];
const session=readFileSync(path.join(source,'src/client/contexts/session/index.ts'),'utf8');
const multi=readFileSync(path.join(source,'src/client/contexts/multiplayer/index.ts'),'utf8');
const main=readFileSync(path.join(source,'src/client/main.ts'),'utf8');
function body(text,name){const start=text.indexOf('function '+name+'(');const open=text.indexOf('{',start);let depth=1,i=open+1;for(;depth;i++){if(text[i]==='{')depth++;if(text[i]==='}')depth--;}return text.slice(open+1,i-1);}
const fixtures=[];
for(const name of ['intro_resume','pause_hitstop','death']){
 const game={started:true,ended:false,paused:false,introTimer:name==='intro_resume'?2.65:0,introStep:-1,resumeEase:name==='intro_resume'?0:1,hitStop:0,offlineDeathTimer:0};
 const state={deathCinematic:null};const noop=()=>{};let countdown=[];
 const app={session:{game},presentation:{updateCountdown:s=>countdown.push(s),finishGameplayTransition:noop,showStageBanner:noop},sound:{tone:noop},multiplayer:{state}};
 app.session.updateIntro=new Function('game','app','rawDeltaTime',body(session,'updateIntro')).bind(null,game,app);
 const pending=new Function('game','endGame','deltaTime',body(session,'updatePendingDeath')).bind(null,game,()=>{game.ended=true;game.paused=true});
 app.multiplayer.getSimulationTimeScale=new Function('state','clamp',body(multi,'getSimulationTimeScale')).bind(null,state,(v,a,b)=>Math.max(a,Math.min(b,v)));
 const start=main.indexOf('  const inIntro =');const end=main.indexOf('  if (game.started && !game.ended && !game.paused) app.world.updateWeather',start);
 const calculate=new Function('app','game','rawDeltaTime',main.slice(start,end)+'\nreturn {simulationDelta,inIntro};');
 const frames=[];
 for(let i=0;i<180;i++){
  let action='';
  if(name==='pause_hitstop'&&i===10){game.paused=true;action='pause';}
  if(name==='pause_hitstop'&&i===18){game.paused=false;game.resumeEase=0;action='resume';}
  if(name==='pause_hitstop'&&i===23){game.hitStop=Math.max(game.hitStop,Math.min(.075,.014+.7*.045));action='impact';}
  if(name==='death'&&i===5){game.paused=true;game.offlineDeathTimer=2.4;state.deathCinematic={elapsed:0,duration:2.4};action='death';}
  const delta=[.016,.033,.1][i%3],raw=Math.min(delta,.05);
  if(state.deathCinematic)state.deathCinematic.elapsed+=raw;
  pending(raw);const values=calculate(app,game,raw);
  frames.push({delta,action,simulation:values.simulationDelta,intro:game.introTimer,introStep:game.introStep,resume:game.resumeEase,hitStop:game.hitStop,weather:game.started&&!game.ended&&!game.paused?raw:0,deathElapsed:state.deathCinematic?.elapsed??0,deathScale:app.multiplayer.getSimulationTimeScale(),ended:game.ended,countdown:[...countdown]});
 }
 fixtures.push({name,frames});
}
writeFileSync('tests/fixtures/run_clock.json',JSON.stringify(fixtures));console.log('540 exact source run-clock frames');
