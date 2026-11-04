import assert from 'node:assert/strict';
const base=process.env.BASE_URL||'http://127.0.0.1:5173';
async function post(b,token){const r=await fetch(base+'/api/game',{method:'POST',headers:{'Content-Type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify(b)});return {status:r.status,...await r.json()}}
async function doAction(s,type,data={}){const r=await post({type,code,data},s.token);assert.equal(r.status,200,r.error);return r.game}
async function read(s){const r=await fetch(base+'/api/game?code='+code,{headers:{authorization:'Bearer '+s.token}});assert.equal(r.status,200);return r.json()}
const h=await post({type:'create',name:'Night Order Host'});assert.equal(h.status,200);const code=h.game.code,sessions=[h];
for(let i=1;i<9;i++){const s=await post({type:'join',code,name:'Night Order '+i});assert.equal(s.status,200);sessions.push(s)}
await doAction(h,'config',{Godfather:1,Cop:2,Vis:1,Medic:1,Diddy:1,Civi:3});await doAction(h,'recruitLimit',{count:2});await doAction(h,'start');
const views=await Promise.all(sessions.map(read));const members=role=>sessions.filter((s,i)=>views[i].players.find(p=>p.id===s.game.me).role===role);
const [gf]=members('Godfather'),[cop1,cop2]=members('Cop'),[vis]=members('Vis'),[medic]=members('Medic'),[diddy]=members('Diddy'),[victim]=members('Civi');
let g=await doAction(h,'force');assert.equal(g.nightStep,'mafia');assert.equal((await read(cop1)).nightMine,false);assert.equal((await read(gf)).nightMine,true);
assert.equal((await post({type:'night',code,data:{kind:'check',target:gf.game.me}},cop1.token)).status,400);
g=await doAction(gf,'night',{kind:'kill',target:victim.game.me});assert.equal(g.nightStep,'cop');
g=await doAction(cop1,'night',{kind:'check',target:gf.game.me});assert.equal(g.nightStep,'cop');assert.deepEqual((await read(victim)).ready,[]);assert.equal(g.nightParticipants,undefined);
g=await doAction(cop2,'night',{kind:'check',target:gf.game.me});assert.equal(g.nightStep,'vis');
g=await doAction(vis,'night',{kind:'skip'});assert.equal(g.nightStep,'medic');g=await doAction(medic,'night',{kind:'save',target:victim.game.me});assert.equal(g.nightStep,'diddy');
g=await doAction(diddy,'night',{kind:'silence',target:victim.game.me});assert.equal(g.phase,'day');assert.equal(g.players.find(p=>p.id===victim.game.me).alive,true);assert.equal(g.players.find(p=>p.id===victim.game.me).silenced,true);
assert.equal((await read(cop1)).intel.at(-1).mafia,true);
await doAction(h,'skipBlock');await doAction(gf,'night',{kind:'recruit',target:cop1.game.me});await doAction(cop1,'night',{kind:'skip'});await doAction(cop2,'night',{kind:'skip'});g=await doAction(vis,'night',{kind:'skip'});assert.equal(g.nightStep,'diddy');g=await doAction(diddy,'night',{kind:'skip'});assert.equal(g.phase,'day');
await doAction(h,'skipBlock');g=await doAction(gf,'night',{kind:'skip'});assert.equal(g.nightStep,'mafia');let c=await read(cop1);assert.equal(c.nightMine,true);assert.equal(c.nightCanAct,false);assert.equal(c.players.find(p=>p.id===cop1.game.me).role,'Cop');
assert.equal((await post({type:'night',code,data:{kind:'check',target:gf.game.me}},cop1.token)).status,400);
g=await doAction(cop1,'night',{kind:'skip'});assert.equal(g.nightStep,'cop');c=await read(cop1);assert.equal(c.nightMine,true);assert.equal(c.nightCanAct,true);assert.deepEqual(c.ready,[]);
await doAction(cop1,'night',{kind:'skip'});await doAction(cop2,'night',{kind:'skip'});g=await doAction(vis,'night',{kind:'kill',target:victim.game.me});assert.equal(g.nightStep,'medic');await doAction(medic,'night',{kind:'save',target:victim.game.me});g=await doAction(diddy,'night',{kind:'skip'});assert.equal(g.phase,'day');assert.equal(g.players.find(p=>p.id===victim.game.me).alive,true);
const page=await fetch(base);assert.equal(page.status,200);
console.log('Night API passed: ordered groups, out-of-turn rejection, multi-Cop readiness, private participation, conditional Medic, Vis-triggered protection, and recruited Cop’s two separate turns.');
