import assert from 'node:assert/strict';
const base=process.env.BASE_URL||'http://127.0.0.1:5173';
async function post(b,token){const r=await fetch(base+'/api/game',{method:'POST',headers:{'Content-Type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify(b)});const data=await r.json();return {status:r.status,...data}}
const h=await post({type:'create',name:'API Host'});assert.equal(h.status,200);const code=h.game.code;assert.match(code,/^\d{6}$/);const sessions=[h];
for(let i=1;i<6;i++){const j=await post({type:'join',name:'API Player '+i,code});assert.equal(j.status,200);sessions.push(j)}
assert.equal((await post({type:'join',name:'API Host',code})).status,400);
assert.equal((await post({type:'start',code},sessions[1].token)).status,400);
assert.equal((await post({type:'config',code,data:{Godfather:1,Civi:5}},h.token)).status,200);
let r=await post({type:'start',code},h.token);assert.equal(r.game.phase,'roles');assert.equal(r.game.players.filter(p=>p.role).length,1);
for(const s of sessions){r=await post({type:'ready',code},s.token);assert.equal(r.status,200)}assert.equal(r.game.phase,'night');
const nightViews=await Promise.all(sessions.map(s=>fetch(base+'/api/game?code='+code,{headers:{authorization:'Bearer '+s.token}}).then(r=>r.json())));
const results=await Promise.all(sessions.filter((_,i)=>nightViews[i].nightMine).map(s=>post({type:'night',code,data:{kind:'skip'}},s.token)));assert(results.every(r=>r.status===200));
r=await fetch(base+'/api/game?code='+code,{headers:{authorization:'Bearer '+h.token}}).then(r=>r.json());assert.equal(r.phase,'day');assert.equal(r.players.length,6);
for(const s of sessions)r=await post({type:'ready',code},s.token);assert.equal(r.game.phase,'nominate');
const ids=r.game.players.map(p=>p.id);
r=await post({type:'nominate',code,data:{target:ids[5]}},sessions[0].token);assert.equal(r.game.phase,'nominate');
r=await post({type:'nominate',code,data:{target:ids[5]}},sessions[1].token);assert.equal(r.game.phase,'secondary');
assert.equal((await post({type:'nominate',code,data:{target:ids[4]}},sessions[2].token)).status,400);
r=await post({type:'secondary',code,data:{target:ids[4]}},sessions[5].token);assert.equal(r.game.phase,'vote');
for(const s of sessions.slice(4))assert.equal((await post({type:'vote',code,data:{target:ids[4]}},s.token)).status,400);
for(const s of sessions.slice(0,4))r=await post({type:'vote',code,data:{target:ids[4]}},s.token);assert(['night','end'].includes(r.game.phase));
if(r.game.phase==='end'){await post({type:'restart',code},h.token);await post({type:'start',code},h.token);await post({type:'force',code},h.token)}
r=await post({type:'force',code},h.token);assert.equal(r.game.phase,'day');const aliveBefore=r.game.players.filter(p=>p.alive).length,roundBefore=r.game.round;
assert.equal((await post({type:'skipBlock',code},sessions[1].token)).status,400);
r=await post({type:'skipBlock',code},h.token);assert.equal(r.game.phase,'night');assert.equal(r.game.round,roundBefore+1);assert.equal(r.game.players.filter(p=>p.alive).length,aliveBefore);
for(const image of ['town-mascot.jpeg','mafia-character.jpeg']){const r=await fetch(base+'/images/'+image);assert.equal(r.status,200);assert.match(r.headers.get('content-type'),/image/)}
assert.equal((await fetch(base+'/api/game?code='+code,{headers:{authorization:'Bearer invalid'}})).status,400);
const page=await fetch(base);assert.equal(page.status,200);assert.match(await page.text(),/Trust no one/);
console.log('API smoke passed: six independent sessions, eligible night submissions, private roles, first-to-two nominations, nominee voting restriction, host-only skip, both pictures, reconnect, and rendered page.');
