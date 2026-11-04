import assert from 'node:assert/strict';
const base=process.env.BASE_URL||'http://127.0.0.1:5173';
async function post(b,token){const r=await fetch(base+'/api/game',{method:'POST',headers:{'Content-Type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify(b)});const data=await r.json();assert.equal(r.status,200,data.error);return data}
async function read(s){const r=await fetch(base+'/api/game?code='+code,{headers:{authorization:'Bearer '+s.token}});assert.equal(r.status,200);return r.json()}
const h=await post({type:'create',name:'Recruit Test Host'}),code=h.game.code,sessions=[h];
for(let i=1;i<8;i++)sessions.push(await post({type:'join',code,name:'Recruit Test '+i}));
await post({type:'config',code,data:{Godfather:1,Medic:1,Cop:1,Civi:5}},h.token);
await post({type:'recruitLimit',code,data:{count:2}},h.token);
await post({type:'start',code},h.token);
const views=await Promise.all(sessions.map(read));
const roleSession=role=>sessions[views.findIndex(g=>g.players.find(p=>p.id===g.me).role===role)];
async function finishNight(){let g=await read(h),limit=6;while(g.phase==='night'&&limit-->0)g=(await post({type:'force',code},h.token)).game;assert.notEqual(g.phase,'night');return g}
const gf=roleSession('Godfather'),medic=roleSession('Medic'),cop=roleSession('Cop');
await post({type:'force',code},h.token);
await post({type:'night',code,data:{kind:'recruit',target:medic.game.me}},gf.token);
await finishNight();
let m=await read(medic),own=m.players.find(p=>p.id===m.me);assert.equal(own.role,'Medic');assert.equal(own.team,'Mafia');assert.equal(own.recruited,true);
assert.equal((await read(gf)).recruitsRemaining,1);
const town=await read(cop);assert.equal(town.players.find(p=>p.id===m.me).team,undefined);assert.equal(town.recruitsRemaining,undefined);
await post({type:'skipBlock',code},h.token);
await post({type:'night',code,data:{kind:'skip'}},medic.token);
await post({type:'night',code,data:{kind:'recruit',target:cop.game.me}},gf.token);
await finishNight();
const c=await read(cop);assert.equal(c.players.find(p=>p.id===c.me).role,'Cop');assert.equal(c.players.find(p=>p.id===c.me).team,'Mafia');assert.equal((await read(gf)).recruitsRemaining,0);
await post({type:'skipBlock',code},h.token);
const exhausted=await fetch(base+'/api/game',{method:'POST',headers:{'Content-Type':'application/json',authorization:'Bearer '+gf.token},body:JSON.stringify({type:'night',code,data:{kind:'recruit',target:sessions.find(s=>![gf.game.me,medic.game.me,cop.game.me].includes(s.game.me)).game.me}})});assert.equal(exhausted.status,400);assert.match((await exhausted.json()).error,/no recruitments remaining/);
const victim=sessions.find(s=>![gf.game.me,medic.game.me,cop.game.me].includes(s.game.me));
await post({type:'night',code,data:{kind:'kill',target:victim.game.me}},gf.token);
await post({type:'night',code,data:{kind:'skip'}},medic.token);
await post({type:'night',code,data:{kind:'skip'}},cop.token);
await post({type:'night',code,data:{kind:'check',target:gf.game.me}},cop.token);
await post({type:'night',code,data:{kind:'save',target:victim.game.me}},medic.token);
await finishNight();
assert.equal((await read(medic)).players.find(p=>p.id===victim.game.me).alive,true);
assert.equal((await read(cop)).intel.at(-1).mafia,true);
console.log('Recruitment API passed: configured two-recruit budget, preserved Medic and Cop powers, Mafia membership privacy, remaining count, and exhausted-budget rejection.');
