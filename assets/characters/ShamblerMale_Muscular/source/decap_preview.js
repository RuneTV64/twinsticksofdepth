// Review tiles for the decapitated stump: close views, plus full body
const Z=require('./shambler.js'),R=require('./preview.js'),fs=require('fs');const out=process.argv[2];fs.mkdirSync(out,{recursive:true});
const {V}=Z.buildAll(+(process.env.DK||1)),M={};V.forEach(v=>M[v.name]=Z.merge(v));
const body=o=>Z.SLOTS.map(s=>M[s+'_'+(o[s]||'Intact')]),K=4;
[[0,.35,0],[-.8,.35,1],[Math.PI*.8,.3,2],[-1.5708,.1,3]].forEach(([y,p,k])=>{const v={W:64,H:80,yaw:y,yc:1.5,hh:.2,pitch:p,cx:0,cz:0},im=R.render(body({Head:'Decapitated'}),v,[1,1,1,1,1,1]);R.png(`${out}/decap_${k}.png`,v.W*K,v.H*K,R.scaleUp(im,v.W,v.H,K));});
[[0,0],[1,-.8]].forEach(([k,y])=>{const v={W:64,H:96,yaw:y,yc:.9,hh:1,pitch:.1,cx:0,cz:0},im=R.render(body({Head:'Decapitated',Torso:'Rotted',ArmR:'Destroyed'}),v,[0,0,0,0,0,0]);R.png(`${out}/decap_full_${k}.png`,v.W*K,v.H*K,R.scaleUp(im,v.W,v.H,K));});
