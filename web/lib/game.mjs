export const ROLES = {
 Godfather: {team:'Mafia', icon:'♠', description:'Lead the Mafia. Each night, kill a player or spend one of your host-configured recruitments instead. Recruited players join the Mafia while keeping their original role and powers.'},
 Cop: {team:'Town',icon:'◈',description:'Investigate one player each night to learn whether they belong to the Mafia.'},
 Medic: {team:'Town',icon:'✚',description:'Protect one player each night, including yourself. Protection stops all night kills against that player.'},
 Judge: {team:'Town',icon:'⚖',description:'Once per game, overturn a vote to save the player chosen for elimination.'},
 Vis: {team:'Town',icon:'⌖',description:'A townsperson with one optional night kill for the entire game. Save it for the right moment.'},
 Diddy: {team:'Town',icon:'◌',description:'Silence one other player each night. They may still use the app and vote, but must not speak during the following day.'},
 Kazee: {team:'Town',icon:'✹',description:'During any day phase, sacrifice yourself to eliminate one other living player immediately.'},
 Civi: {team:'Town',icon:'○',description:'Use discussion, nominations, and voting to help your team win. You have no special night power.'}
};
export const teamOf = p => p.team ?? (p.role==='Recruit'?'Mafia':ROLES[p.role]?.team ?? 'Town');
const mafia = p => teamOf(p) === 'Mafia';
export const recruitmentsRemaining = g => Math.max(0,(g.recruitLimit??1)-(g.recruitsUsed??(g.recruitUsed?1:0)));
export const NIGHT_ORDER=['mafia','cop','vis','medic','diddy'];
export const NIGHT_LABELS={mafia:'Mafia',cop:'Cops',vis:'Vis',medic:'Medic',diddy:'Diddy'};
function normalize(g) {
 if(g.recruitLimit===undefined)g.recruitLimit=g.config.Recruit||1;
 if(g.recruitsUsed===undefined)g.recruitsUsed=g.recruitUsed?1:0;
 if('Recruit' in g.config){g.config.Civi=(g.config.Civi||0)+g.config.Recruit;delete g.config.Recruit}
 for(const p of g.players){if(p.role==='Recruit'){p.role='Civi';p.team='Mafia';p.recruited=true}else if(!p.team)p.team=teamOf(p)}
 delete g.recruitUsed;
 if(g.phase==='night'&&!NIGHT_ORDER.includes(g.nightStep))advanceNight(g,0);
}
const alive = g => g.players.filter(p=>p.alive);
const need = (ok,msg) => {if(!ok) throw Error(msg)};
export function newGame(code, name, token, id) {
 return {code, host:id, phase:'lobby', round:0, players:[{id,token,name,alive:true,role:'Civi',team:'Town',used:false,silenced:false}],config:{Godfather:1,Cop:1,Medic:1,Judge:0,Vis:0,Diddy:0,Kazee:0,Civi:2},ready:[],actions:{},nominations:{},votes:{},nominees:[],pending:null,judgeUsed:false,recruitLimit:1,recruitsUsed:0,log:[],intel:{},winner:null};
}
function reset(g,phase) {g.phase=phase;g.ready=[];}
function win(g) {const a=alive(g),m=a.filter(mafia).length; if(!m)g.winner='Town';else if(m>=a.length-m)g.winner='Mafia'; if(g.winner){reset(g,'end');g.log.push(`${g.winner} wins!`);return true}return false}
function pick(counts) {const entries=Object.entries(counts);const max=Math.max(...entries.map(x=>x[1]));const top=entries.filter(x=>x[1]===max);return top[Math.floor(Math.random()*top.length)]?.[0]}
export function nightActor(g,p) {return ['Godfather','Cop','Medic','Diddy'].includes(p.role)||p.role==='Vis'&&!p.used}
function groupMembers(g,step) {
 const a=alive(g);
 if(step==='mafia')return a.filter(mafia);
 if(step==='medic'&&!Object.values(g.actions).some(a=>a.kind==='kill'))return [];
 return a.filter(p=>p.role===({cop:'Cop',vis:'Vis',medic:'Medic',diddy:'Diddy'})[step]&&(step!=='vis'||!p.used));
}
function advanceNight(g,index) {
 for(let i=index;i<NIGHT_ORDER.length;i++){
  const step=NIGHT_ORDER[i],members=groupMembers(g,step);if(!members.length)continue;
  g.nightStep=step;g.nightParticipants=members.map(p=>p.id);g.ready=g.nightParticipants.filter(id=>!!g.actions[id]);
  if(g.nightParticipants.every(id=>g.ready.includes(id)))continue;
  return;
 }
 g.nightStep=null;g.nightParticipants=[];resolveNight(g);
}
function beginNight(g){reset(g,'night');g.actions={};advanceNight(g,0)}
export function nightParticipants(g){return g.phase==='night'?(g.nightParticipants||[]).map(id=>g.players.find(p=>p.id===id)).filter(Boolean):[]}
function resolveNight(g) {
 const saves=new Set(),kills=new Set(),silence=new Set(), recruits=[];
 for(const [id,a] of Object.entries(g.actions)){const p=g.players.find(p=>p.id===id);if(!p?.alive||!a.target)continue;if(a.kind==='save')saves.add(a.target);if(a.kind==='kill')kills.add(a.target);if(a.kind==='silence')silence.add(a.target);if(a.kind==='recruit')recruits.push(a.target);if(a.kind==='check'){const t=g.players.find(p=>p.id===a.target);(g.intel[id]??=[]).push({round:g.round,name:t.name,mafia:mafia(t)})}}
 for(const p of g.players){p.silenced=silence.has(p.id);if(kills.has(p.id)&&!saves.has(p.id))p.alive=false}
 for(const id of recruits){const p=g.players.find(p=>p.id===id);if(p?.alive){p.team='Mafia';p.recruited=true}}
 const deadPlayers=g.players.filter(p=>kills.has(p.id)&&!saves.has(p.id)).map(({id,name})=>({id,name}));
 const silencedPlayers=g.players.filter(p=>p.alive&&p.silenced).map(({id,name})=>({id,name}));
 const savedCount=[...kills].filter(id=>saves.has(id)).length;
 const summary=[deadPlayers.length?deadPlayers.map(p=>p.name).join(', ')+' died.':'No one died.',savedCount?`${savedCount} player${savedCount===1?' was':'s were'} saved.`:'',silencedPlayers.length?`Silenced today: ${silencedPlayers.map(p=>p.name).join(', ')}.`:''].filter(Boolean).join(' ');
 g.lastNight={round:g.round,deadPlayers,savedCount,silencedPlayers,summary};
 g.log.push(`Night ${g.round}: ${summary}`);
 if(!win(g))reset(g,'day');
}
export function eligibleVoters(g) {return alive(g).filter(p=>!g.nominees.includes(p.id));}
function progress(g) {
 if(g.phase==='night'){const members=nightParticipants(g);if(members.length&&members.every(p=>g.ready.includes(p.id)))advanceNight(g,NIGHT_ORDER.indexOf(g.nightStep)+1);return}
 const a=alive(g), participants=g.phase==='vote'?eligibleVoters(g):a; if(!participants.length||!participants.every(p=>g.ready.includes(p.id)))return;
 if(g.phase==='roles'){beginNight(g)}
 else if(g.phase==='day') {reset(g,'nominate');g.nominations={}}
 else if(g.phase==='vote') {const counts=Object.fromEntries(g.nominees.map(id=>[id,0]));for(const voter of eligibleVoters(g)){const id=g.votes[voter.id];if(id in counts)counts[id]++;}g.pending=pick(counts);reset(g,'verdict');if(g.judgeUsed||!a.some(p=>p.role==='Judge'))finishVote(g,false)}
}
function nextNight(g) {g.round++;g.players.forEach(p=>p.silenced=false);g.actions={};g.nominees=[];g.pending=null;g.nominations={};g.votes={};beginNight(g)}
function skipBlock(g,reason) {g.log.push(`Day ${g.round}: ${reason} No one was eliminated.`);nextNight(g)}
function finishVote(g,save){const p=g.players.find(p=>p.id===g.pending);if(!p)return;if(save){g.judgeUsed=true;g.log.push(`The Judge overturned the vote. ${p.name} was spared.`)}else{p.alive=false;g.log.push(`${p.name} was eliminated by the town.`)}g.pending=null;if(!win(g)){nextNight(g)}}
export function act(g,token,type,data={}) {
 normalize(g);
 const p=g.players.find(p=>p.token===token);need(p,'Session expired. Rejoin the lobby.');const host=p.id===g.host;
 if(type==='config'){need(host&&g.phase==='lobby','Only the host can configure the lobby.');for(const r of Object.keys(ROLES)){const n=Number(data[r]??0);need(Number.isInteger(n)&&n>=0&&n<=24,'Invalid role count.');g.config[r]=n}return}
 if(type==='recruitLimit'){need(host&&g.phase==='lobby','Only the host can set recruitments before the game.');const n=Number(data.count);need(Number.isInteger(n)&&n>=0&&n<=24,'Choose between 0 and 24 recruitments.');g.recruitLimit=n;return}
 if(type==='kick'){need(host&&g.phase==='lobby'&&data.target!==p.id,'Cannot remove that player.');g.players=g.players.filter(x=>x.id!==data.target);return}
 if(type==='restart'){need(host&&g.phase==='end','Only the host can start a rematch.');g.players.forEach(p=>{p.alive=true;p.role='Civi';p.team='Town';p.recruited=false;p.used=false;p.silenced=false});g.winner=null;g.judgeUsed=false;g.recruitsUsed=0;g.intel={};g.log=[];g.lastNight=null;g.pending=null;g.nightStep=null;g.nightParticipants=[];reset(g,'lobby');return}
 if(type==='start'){need(host&&g.phase==='lobby','Only the host can start.');need(g.players.length>=4,'At least 4 players are needed.');const deck=Object.entries(g.config).flatMap(([r,n])=>Array(n).fill(r));need(deck.length===g.players.length,'Role total must equal the player count.');const m=deck.filter(r=>ROLES[r].team==='Mafia').length;need(m>0&&m<deck.length-m,'Include Mafia and give Town a starting majority.');need((g.config.Godfather??0)<=1&&(g.config.Judge??0)<=1,'Use at most one Godfather and one Judge.');for(let i=deck.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[deck[i],deck[j]]=[deck[j],deck[i]]}g.players.forEach((p,i)=>{p.role=deck[i];p.team=ROLES[p.role].team;p.recruited=false});g.recruitsUsed=0;g.round=1;reset(g,'roles');return}
 if(type==='skipBlock'){need(host,'Only the host can skip the block.');need(['day','nominate','secondary','vote'].includes(g.phase),'The block can only be skipped before the verdict.');skipBlock(g,'The host skipped the block.');return}
 if(type==='force'){need(host,'Only the host can continue for missing players.');need(['roles','night','day','nominate','secondary','vote','verdict'].includes(g.phase),'No phase to advance.');if(g.phase==='verdict')finishVote(g,false);else if(g.phase==='secondary'){g.nominees.push(alive(g).find(x=>x.id!==g.nominees[0]).id);g.votes={};reset(g,'vote')}else{g.ready=(g.phase==='night'?nightParticipants(g):g.phase==='vote'?eligibleVoters(g):alive(g)).map(p=>p.id);progress(g)}return}
 need(p.alive,'You are a spectator for the rest of this game.');
 if(type==='kazee'){need(p.role==='Kazee'&&['day','nominate','secondary','vote','verdict'].includes(g.phase),'Kazee can act only during the day.');const t=alive(g).find(x=>x.id===data.target&&x.id!==p.id);need(t,'Choose another living player.');p.alive=false;t.alive=false;g.log.push(`${p.name} sacrificed themselves and eliminated ${t.name}.`);if(!win(g)){if(['secondary','vote','verdict'].includes(g.phase)){g.pending=null;g.nominees=[];g.nominations={};reset(g,'nominate')}else progress(g)}return}
 if(type==='judge'){need(g.phase==='verdict'&&p.role==='Judge'&&!g.judgeUsed,'No Judge decision is available.');finishVote(g,!!data.save);return}
 need(!g.ready.includes(p.id),'Your choice is already locked in.');
 if(type==='ready'){need(['roles','day'].includes(g.phase),'Cannot continue yet.');g.ready.push(p.id)}
 else if(type==='night'){need(g.phase==='night','Night has ended.');need(g.nightParticipants.includes(p.id),'It is not your group’s turn.');const kind=data.kind??'skip';if(kind!=='skip'){need(nightActor(g,p),'You have no night power available.');need(g.nightStep===(p.role==='Godfather'?'mafia':p.role.toLowerCase()),'Use your original role’s power during its own turn.');const t=alive(g).find(x=>x.id===data.target);need(t&&(t.id!==p.id||p.role==='Medic'),'Choose a valid living target.');const expected={Godfather:['kill','recruit'],Medic:['save'],Cop:['check'],Vis:['kill'],Diddy:['silence']};need(expected[p.role]?.includes(kind),'Invalid action.');if(p.role==='Godfather')need(!mafia(t),'You cannot target your Mafia teammates.');if(kind==='recruit'){need(recruitmentsRemaining(g)>0,'You have no recruitments remaining.');g.recruitsUsed++}if(p.role==='Vis')p.used=true;g.actions[p.id]={kind,target:t.id}}g.ready.push(p.id)}
 else if(type==='nominate'){need(g.phase==='nominate','Nominations are closed.');need(alive(g).some(x=>x.id===data.target&&x.id!==p.id),'Choose another living player.');g.nominations[p.id]=data.target;g.ready.push(p.id);if(Object.values(g.nominations).filter(id=>id===data.target).length>=2){g.nominees=[data.target];reset(g,'secondary');return}}
 else if(type==='secondary'){need(g.phase==='secondary'&&g.nominees[0]===p.id,'The primary nominee chooses.');need(alive(g).some(x=>x.id===data.target&&x.id!==p.id),'Choose another living player.');g.nominees.push(data.target);g.votes={};reset(g,'vote');return}
 else if(type==='vote'){need(!g.nominees.includes(p.id),'Players on the block cannot vote.');need(g.phase==='vote'&&g.nominees.includes(data.target),'Choose a nominee.');g.votes[p.id]=data.target;g.ready.push(p.id)}else throw Error('Unknown action.');
 progress(g);
}
export function view(g,token){
 normalize(g);
 const me=g.players.find(p=>p.token===token);need(me,'Session expired. Rejoin the lobby.');
 const nightMine=g.phase==='night'&&g.nightParticipants.includes(me.id);
 return {...g,nightParticipants:undefined,ready:g.phase==='night'?g.ready.filter(id=>id===me.id):g.ready,nightMine,nightCanAct:nightMine&&(g.nightStep!=='mafia'||me.role==='Godfather'),actions:undefined,nominations:undefined,votes:undefined,recruitsUsed:me.role==='Godfather'?g.recruitsUsed:undefined,recruitsRemaining:me.role==='Godfather'?recruitmentsRemaining(g):undefined,intel:g.intel[me.id]||[],players:g.players.map(({token,...p})=>{const visible=g.phase==='end'||p.id===me.id||mafia(me)&&mafia(p);return {...p,team:visible?teamOf(p):undefined,recruited:visible?p.recruited:undefined,role:visible?p.role:undefined,used:p.id===me.id?p.used:undefined}}),me:me.id,isHost:g.host===me.id};
}
