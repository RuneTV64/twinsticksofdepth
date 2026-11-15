// ShamblerMale_Muscular -> GLB. One file per detail level; each holds all 19 part meshes (6 slots x 3 states, plus Head_Decapitated)
// skinned to one copy of the MaleBody_Muscular skeleton. The Godot script shows one state per slot.
const fs=require('fs'),Z=require('./shambler.js');
function exportGLB(detail,file,review){
  const {B,V}=Z.buildAll(detail),NB=B.NB,piv=B.piv,par=B.par;
  if(review)V.push(...Z.anatomyOnly(B));   // review file only: the insides with no skin over them
  const bin=[];let off=0;const views=[],acc=[];
  const add=(arr,type,comp,o)=>{o=o||{};const b=Buffer.from(arr.buffer,arr.byteOffset,arr.byteLength);const pad=(4-off%4)%4;if(pad){bin.push(Buffer.alloc(pad));off+=pad;}
    const v={buffer:0,byteOffset:off,byteLength:b.length};if(o.target)v.target=o.target;views.push(v);bin.push(b);off+=b.length;
    const n={VEC4:4,VEC3:3,VEC2:2,SCALAR:1,MAT4:16}[type],ac={bufferView:views.length-1,componentType:comp,count:arr.length/n,type};if(o.norm)ac.normalized=true;
    if(o.minmax){const mn=new Array(n).fill(1e30),mx=new Array(n).fill(-1e30);for(let i=0;i<arr.length;i++){const k=i%n;if(arr[i]<mn[k])mn[k]=arr[i];if(arr[i]>mx[k])mx[k]=arr[i];}ac.min=mn;ac.max=mx;}
    acc.push(ac);return acc.length-1;};
  const F=5126,AB=34962,EAB=34963,meshes=[],stats=[];
  V.forEach(v=>{const m=Z.merge(v),I=m.nv>65535?m.I:Uint16Array.from(m.I);
    // rest position for shaders that paint by place on the body (Godot: CUSTOM0 xyz = rest position, w = rest normal y)
    const R2=new Float32Array(m.nv*2),R3=new Float32Array(m.nv*2);for(let i=0;i<m.nv;i++){R2[i*2]=m.P[i*3];R2[i*2+1]=m.P[i*3+1];R3[i*2]=m.P[i*3+2];R3[i*2+1]=m.N[i*3+1];}
    meshes.push({name:'Shambler_'+v.name,extras:{slot:v.slot,state:v.state,crawler:v.crawler},primitives:[{attributes:{POSITION:add(m.P,'VEC3',F,{target:AB,minmax:1}),NORMAL:add(m.N,'VEC3',F,{target:AB}),TEXCOORD_0:add(m.UV,'VEC2',F,{target:AB}),TEXCOORD_1:add(m.UV2,'VEC2',F,{target:AB}),TEXCOORD_2:add(R2,'VEC2',F,{target:AB}),TEXCOORD_3:add(R3,'VEC2',F,{target:AB}),
      COLOR_0:add(m.COL,'VEC4',5121,{target:AB,norm:1}),JOINTS_0:add(m.J,'VEC4',5121,{target:AB}),WEIGHTS_0:add(m.W,'VEC4',F,{target:AB})},indices:add(I,'SCALAR',I instanceof Uint32Array?5125:5123,{target:EAB}),material:0,mode:4}]});
    stats.push([v.name,m.tris]);});
  // nodes: 0 = root, 1..NB = bones, then one node per part mesh
  const nodes=[{name:'ShamblerMale_Muscular',children:[]}];
  for(let i=0;i<NB;i++){const p=piv[i],q=par[i]<0?[0,0,0]:piv[par[i]];nodes.push({name:B.names[i],translation:[p[0]-q[0],p[1]-q[1],p[2]-q[2]]});}
  for(let i=0;i<NB;i++)if(par[i]>=0){const pn=nodes[par[i]+1];(pn.children=pn.children||[]).push(i+1);}
  nodes[0].children.push(1);
  V.forEach((v,k)=>{nodes.push({name:v.name,mesh:k,skin:0,extras:{slot:v.slot,state:v.state,crawler:v.crawler}});nodes[0].children.push(nodes.length-1);});
  const ibm=new Float32Array(NB*16);for(let i=0;i<NB;i++){const o=i*16;ibm[o]=ibm[o+5]=ibm[o+10]=ibm[o+15]=1;ibm[o+12]=-piv[i][0];ibm[o+13]=-piv[i][1];ibm[o+14]=-piv[i][2];}
  const skin={name:'ShamblerMale_Muscular_Skeleton',joints:Array.from({length:NB},(_,i)=>i+1),skeleton:1,inverseBindMatrices:add(ibm,'MAT4',F)};
  const json={asset:{version:'2.0',generator:'ShamblerMale_Muscular exporter'},scene:0,scenes:[{name:'ShamblerMale_Muscular',nodes:[0]}],nodes,meshes,skins:[skin],
    materials:[{name:'ZombieSkin',pbrMetallicRoughness:{baseColorFactor:[.42,.41,.36,1],metallicFactor:0,roughnessFactor:.95}}],accessors:acc,bufferViews:views,buffers:[{byteLength:0}]};
  const pad=(4-off%4)%4;if(pad){bin.push(Buffer.alloc(pad));off+=pad;}json.buffers[0].byteLength=off;
  let jb=Buffer.from(JSON.stringify(json));if(jb.length%4)jb=Buffer.concat([jb,Buffer.alloc(4-jb.length%4,0x20)]);
  const head=Buffer.alloc(12);head.writeUInt32LE(0x46546C67,0);head.writeUInt32LE(2,4);head.writeUInt32LE(12+8+jb.length+8+off,8);
  const h1=Buffer.alloc(8);h1.writeUInt32LE(jb.length,0);h1.writeUInt32LE(0x4E4F534A,4);const h2=Buffer.alloc(8);h2.writeUInt32LE(off,0);h2.writeUInt32LE(0x004E4942,4);
  fs.writeFileSync(file,Buffer.concat([head,h1,jb,h2,...bin]));
  return{file,bytes:12+8+jb.length+8+off,stats};}
// The cut-off pieces -> one GLB per detail level. Each piece is a node holding a small skeleton of its own (the bone it
// hangs from, and the hand and fingers or the foot and toes below it) and its skinned mesh. Everything is in the frame
// of that root bone (positions measured from its rest position), so the game can place the piece at the bone's pose
// and it lands exactly where the part was. The piece node's extras carry its slot, the state it was made from, the
// bone, its mass, and `joints`: how each joint may move (see pieceJoints in shambler.js). TEXCOORD_2/3 still hold the rest position on the body, so the
// shader paints it exactly as it was. In the file each piece sits where it belongs on the body, Intact pieces at x 0,
// Rotted ones moved 0.8 m to his left and Destroyed ones 1.6 m, so they can be looked at side by side.
function exportPieces(detail,file){
  const {pieces}=Z.buildPieces(detail),bin=[];let off=0;const views=[],acc=[];
  const add=(arr,type,comp,o)=>{o=o||{};const b=Buffer.from(arr.buffer,arr.byteOffset,arr.byteLength);const pad=(4-off%4)%4;if(pad){bin.push(Buffer.alloc(pad));off+=pad;}
    const v={buffer:0,byteOffset:off,byteLength:b.length};if(o.target)v.target=o.target;views.push(v);bin.push(b);off+=b.length;
    const n={VEC4:4,VEC3:3,VEC2:2,SCALAR:1,MAT4:16}[type],ac={bufferView:views.length-1,componentType:comp,count:arr.length/n,type};if(o.norm)ac.normalized=true;
    if(o.minmax){const mn=new Array(n).fill(1e30),mx=new Array(n).fill(-1e30);for(let i=0;i<arr.length;i++){const k=i%n;if(arr[i]<mn[k])mn[k]=arr[i];if(arr[i]>mx[k])mx[k]=arr[i];}ac.min=mn;ac.max=mx;}
    acc.push(ac);return acc.length-1;};
  const F=5126,AB=34962,EAB=34963,meshes=[],skins=[],nodes=[{name:'ShamblerMale_Muscular_Pieces',children:[]}],stats=[],SHIFT={Intact:0,Rotted:.8,Destroyed:1.6};
  pieces.forEach((pc,k)=>{const m=Z.merge(pc),I=m.nv>65535?m.I:Uint16Array.from(m.I),L=new Float32Array(m.nv*3),R2=new Float32Array(m.nv*2),R3=new Float32Array(m.nv*2);
    for(let i=0;i<m.nv;i++){for(let j=0;j<3;j++)L[i*3+j]=m.P[i*3+j]-pc.pivot[j];R2[i*2]=m.P[i*3];R2[i*2+1]=m.P[i*3+1];R3[i*2]=m.P[i*3+2];R3[i*2+1]=m.N[i*3+1];}
    const extras={slot:pc.slot,from_state:pc.from,bone:pc.bone,mass:pc.mass,joints:pc.joints};if(pc.shapes)extras.shapes=pc.shapes;
    meshes.push({name:'Piece_'+pc.name,primitives:[{attributes:{POSITION:add(L,'VEC3',F,{target:AB,minmax:1}),NORMAL:add(m.N,'VEC3',F,{target:AB}),TEXCOORD_0:add(m.UV,'VEC2',F,{target:AB}),
      TEXCOORD_1:add(m.UV2,'VEC2',F,{target:AB}),TEXCOORD_2:add(R2,'VEC2',F,{target:AB}),TEXCOORD_3:add(R3,'VEC2',F,{target:AB}),COLOR_0:add(m.COL,'VEC4',5121,{target:AB,norm:1}),
      JOINTS_0:add(m.J,'VEC4',5121,{target:AB}),WEIGHTS_0:add(m.W,'VEC4',F,{target:AB})},indices:add(I,'SCALAR',I instanceof Uint32Array?5125:5123,{target:EAB}),material:0,mode:4}]});
    // the piece node, its bones (named as on the body), and the skinned mesh
    const pn=nodes.length;nodes.push({name:pc.name,translation:[pc.pivot[0]+SHIFT[pc.from],pc.pivot[1],pc.pivot[2]],children:[],extras});nodes[0].children.push(pn);
    const b0=nodes.length;pc.bones.forEach((bn,i)=>{const pr=pc.parents[i],t=pr<0?[0,0,0]:pc.rest[i].map((v,j)=>v-pc.rest[pr][j]);nodes.push({name:bn,translation:t});});
    pc.bones.forEach((bn,i)=>{const pr=pc.parents[i];if(pr<0)nodes[pn].children.push(b0+i);else(nodes[b0+pr].children=nodes[b0+pr].children||[]).push(b0+i);});
    const ibm=new Float32Array(pc.bones.length*16);pc.bones.forEach((bn,i)=>{const o=i*16;ibm[o]=ibm[o+5]=ibm[o+10]=ibm[o+15]=1;ibm[o+12]=-pc.rest[i][0];ibm[o+13]=-pc.rest[i][1];ibm[o+14]=-pc.rest[i][2];});
    skins.push({name:pc.name+'_Skeleton',joints:pc.bones.map((b,i)=>b0+i),skeleton:b0,inverseBindMatrices:add(ibm,'MAT4',F)});
    nodes.push({name:pc.name+'_Mesh',mesh:k,skin:skins.length-1});nodes[pn].children.push(nodes.length-1);stats.push([pc.name,m.tris]);});
  const json={asset:{version:'2.0',generator:'ShamblerMale_Muscular pieces exporter'},scene:0,scenes:[{name:'ShamblerMale_Muscular_Pieces',nodes:[0]}],nodes,meshes,skins,
    materials:[{name:'ZombieSkin',pbrMetallicRoughness:{baseColorFactor:[.42,.41,.36,1],metallicFactor:0,roughnessFactor:.95}}],accessors:acc,bufferViews:views,buffers:[{byteLength:0}]};
  const pad=(4-off%4)%4;if(pad){bin.push(Buffer.alloc(pad));off+=pad;}json.buffers[0].byteLength=off;
  let jb=Buffer.from(JSON.stringify(json));if(jb.length%4)jb=Buffer.concat([jb,Buffer.alloc(4-jb.length%4,0x20)]);
  const head=Buffer.alloc(12);head.writeUInt32LE(0x46546C67,0);head.writeUInt32LE(2,4);head.writeUInt32LE(12+8+jb.length+8+off,8);
  const h1=Buffer.alloc(8);h1.writeUInt32LE(jb.length,0);h1.writeUInt32LE(0x4E4F534A,4);const h2=Buffer.alloc(8);h2.writeUInt32LE(off,0);h2.writeUInt32LE(0x004E4942,4);
  fs.writeFileSync(file,Buffer.concat([head,h1,jb,h2,...bin]));
  return{file,bytes:12+8+jb.length+8+off,stats};}
module.exports={exportGLB,exportPieces};
if(require.main===module){const dir=process.argv[2]||'./export_shambler';fs.mkdirSync(dir,{recursive:true});
  for(const [d,f] of[[1,'ShamblerMale_Muscular.glb'],[.56,'ShamblerMale_Muscular_mid.glb'],[.25,'ShamblerMale_Muscular_low.glb']]){const r=exportGLB(d,dir+'/'+f);console.log(f,(r.bytes/1024|0)+'KB',JSON.stringify(r.stats.map(s=>s[0]+':'+s[1])));}
  for(const [d,f] of[[1,'ShamblerMale_Muscular_Pieces.glb'],[.56,'ShamblerMale_Muscular_Pieces_mid.glb'],[.25,'ShamblerMale_Muscular_Pieces_low.glb']]){const r=exportPieces(d,dir+'/'+f);console.log(f,(r.bytes/1024|0)+'KB',JSON.stringify(r.stats.map(s=>s[0]+':'+s[1])));}}
