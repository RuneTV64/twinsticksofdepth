// Render review tiles: each slot in its three states (rest of the body intact), plus a lineup of random shamblers.
const fs=require('fs'),Z=require('./shambler.js'),R=require('./preview.js');
const out=process.argv[2]||'./tiles';fs.mkdirSync(out,{recursive:true});
const {V}=Z.buildAll(+(process.env.DK||1)),M={};V.forEach(v=>M[v.name]=Z.merge(v));
const body=over=>Z.SLOTS.map(s=>M[s+'_'+(over[s]||'Intact')]);
const K=4,tile=(file,meshes,view,tones)=>{const im=R.render(meshes,view,tones);R.png(out+'/'+file,view.W*K,view.H*K,R.scaleUp(im,view.W,view.H,K));};
// per-slot views: [yc, half height, yaws, cx, cz]
const VIEWS={Head:[1.64,.15,[0,-1.2,Math.PI*.75]],Torso:[1.2,.36,[0,-1.0,Math.PI]],ArmL:[1.1,.42,[-.5,-1.5708,2.6],.24],ArmR:[1.1,.42,[.5,1.5708,-2.6],-.24],LegL:[.47,.5,[-.4,-1.5708,2.7],.1],LegR:[.47,.5,[.4,1.5708,-2.7],-.1]};
const list=[];
for(const sl of Z.SLOTS){const [yc,hh,yaws,cx]=VIEWS[sl];for(const st of Z.STATES)yaws.forEach((y,k)=>{const f=`${sl}_${st}_${k}.png`;tile(f,body({[sl]:st}),{W:64,H:80,yaw:y,yc,hh,pitch:.12,cx:cx||0,cz:0},null);list.push(f);});}
// lineup: seeded random rolls, the same rules the Godot spawner uses
let seed=+(process.env.SEED||7);const rnd=()=>{seed=(seed*1103515245+12345)%2147483648;return seed/2147483648;};
const roll=()=>{const o={};for(const s of Z.SLOTS){const r=rnd();o[s]=r<.45?'Intact':r<.85?'Rotted':'Destroyed';}if(o.LegL==='Destroyed'&&o.LegR==='Destroyed'&&rnd()<.6)o.LegR='Rotted';return o;};
const crowd=process.env.RANDOM?Array.from({length:5},()=>({o:roll(),tone:Math.floor(rnd()*3)})):[
  {o:{Head:'Rotted',Torso:'Intact',ArmL:'Rotted',ArmR:'Intact',LegL:'Intact',LegR:'Rotted'},tone:0},
  {o:{Head:'Intact',Torso:'Destroyed',ArmL:'Intact',ArmR:'Rotted',LegL:'Rotted',LegR:'Intact'},tone:1},
  {o:{Head:'Destroyed',Torso:'Rotted',ArmL:'Destroyed',ArmR:'Rotted',LegL:'Intact',LegR:'Intact'},tone:2},
  {o:{Head:'Intact',Torso:'Rotted',ArmL:'Rotted',ArmR:'Destroyed',LegL:'Destroyed',LegR:'Rotted'},tone:0},
  {o:{Head:'Rotted',Torso:'Intact',ArmL:'Intact',ArmR:'Intact',LegL:'Rotted',LegR:'Rotted'},tone:1}];
const meshes=[],tones=[];crowd.forEach((c,i)=>{body(c.o).forEach(m=>{meshes.push(Object.assign({},m,{ox:(i-2)*.62}));tones.push(c.tone);});});
for(const [k,y] of [[0,0],[1,Math.PI]]){const view={W:220,H:96,yaw:y,yc:.92,hh:1.0,pitch:.1,cx:0,cz:0},im=R.render(meshes,view,tones);R.png(out+`/lineup_${k}.png`,view.W*K,view.H*K,R.scaleUp(im,view.W,view.H,K));}
fs.writeFileSync(out+'/lineup.json',JSON.stringify(crowd));
console.log('tiles',list.length,'lineup',JSON.stringify(crowd.map(c=>[c.tone,Object.values(c.o).map(s=>s[0]).join('')])));
