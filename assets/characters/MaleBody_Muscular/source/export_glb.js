// MaleBody_Muscular -> GLB exporter. One merged mesh, skeleton, standard 4-weight skinning, packed detail data, baked test animations.
const fs=require('fs'),MB=require('./male_body_muscular.js'),{makeRig}=require('./rig.js');
const CLIPS=[['Idle',7.6,'idle'],['Walk',1.0,'walk'],['Wave',6.8,'wave'],['Arms',14,'arms'],['Head',10.4,'head'],['Wrists',7.2,'wrists'],['Fingers',7.8,'fingers'],['Toes',9,'toes']];
const SIDE=['Thigh','Calf','Foot','UpperArm','UpperArmRoll','Forearm','ForearmRoll','Hand'];
const cap=s=>s[0].toUpperCase()+s.slice(1);
// standard skinning thins a joint where two bones share a vertex evenly, so the shoulder's shared band is narrowed for export
const LBSK=+(process.env.LBSK||1.7);

// build one detail level and return everything the file needs, in plain arrays
function assemble(detail){
  const parts=MB.build({detail}),rig=makeRig(parts,MB.SPEC),X=rig.X,NB=rig.bones;
  const names=['Hips','Chest','Neck','ClavicleL','ClavicleR'];
  for(const s of['L','R'])for(const n of SIDE)names.push(n+s);
  names.push('Head');parts.forEach(p=>{if(p.jp)names.push(cap(p.name));});
  if(names.length!==NB)throw new Error('bone name count '+names.length+' vs '+NB);
  let nv=0,ni=0;parts.forEach(p=>{nv+=p.P.length/3;ni+=p.I.length;});
  const P=new Float32Array(nv*3),N=new Float32Array(nv*3),UV=new Float32Array(nv*2),UV2=new Float32Array(nv*2),COL=new Uint8Array(nv*4),
    J=new Uint8Array(nv*4),W=new Float32Array(nv*4),I=nv>65535?new Uint32Array(ni):new Uint16Array(ni);
  let vo=0,io=0;
  parts.forEach((p,k)=>{const s=X.skin[k],n=p.P.length/3,base=p.name.replace(/[LR]\d*$/,'');
    P.set(s.P0,vo*3);N.set(s.N0,vo*3);for(let i=0;i<p.I.length;i++)I[io+i]=p.I[i]+vo;io+=p.I.length;
    for(let i=0;i<n;i++){const v=vo+i,A=s.A[i],B=s.B[i],w=s.W[i],t=s.TW[i];let ws;
      if(s.SC[i]){const b=s.SC[i],wa=Math.min(1,Math.max(0,(s.WA[i]-.5)*LBSK+.5)),wc=Math.max(s.WC[i],wa),wt=t>=0?w:0;ws=[[1,1-wc],[b===X.BL?3:4,wc*(1-wa)],[b+3,wc*wa*(1-wt)],[b+4,wc*wa*wt]];}
      else if(t>=0)ws=[[A,1-w],[t,w]];
      else if(A===B||w>=1)ws=[[B,1]];
      else ws=[[A,1-w],[B,w]];
      ws=ws.filter(e=>e[1]>1e-4);const sum=ws.reduce((a,e)=>a+e[1],0);ws.forEach((e,q)=>{J[v*4+q]=e[0];W[v*4+q]=e[1]/sum;});
      // detail data: UV and UV2 carry the fine coordinates, COLOR carries a shadow amount, a coarse rest depth and the part code
      const L=p.L,f=L?Math.round(L[i*4+3]):0;let code=f;const c8=x=>Math.round(255*Math.min(1,Math.max(0,x)));
      if(L&&f<=1){UV[v*2]=L[i*4];UV[v*2+1]=L[i*4+1];UV2[v*2]=L[i*4+2];}
      else if(f===2)COL[v*4]=c8(L[i*4]);
      else if(f===3){COL[v*4]=c8(L[i*4]);UV[v*2]=s.P0[i*3];UV[v*2+1]=s.P0[i*3+1];COL[v*4+1]=c8(s.P0[i*3+2]/.3+.5);}
      else if(f>=4){UV[v*2]=L[i*4];UV[v*2+1]=L[i*4+1];UV2[v*2]=L[i*4+2];}
      else if(base==='thigh'){code=8;UV[v*2]=s.P0[i*3];UV[v*2+1]=s.P0[i*3+1];}
      COL[v*4+3]=code*17;}
    vo+=n;});
  return{parts,rig,X,NB,names,nv,ni,P,N,UV,UV2,COL,J,W,I};
}
const quat=m=>{const t=m[0]+m[4]+m[8];let x,y,z,w;
  if(t>0){const s=Math.sqrt(t+1)*2;w=s/4;x=(m[7]-m[5])/s;y=(m[2]-m[6])/s;z=(m[3]-m[1])/s;}
  else if(m[0]>m[4]&&m[0]>m[8]){const s=Math.sqrt(1+m[0]-m[4]-m[8])*2;w=(m[7]-m[5])/s;x=s/4;y=(m[1]+m[3])/s;z=(m[2]+m[6])/s;}
  else if(m[4]>m[8]){const s=Math.sqrt(1+m[4]-m[0]-m[8])*2;w=(m[2]-m[6])/s;x=(m[1]+m[3])/s;y=s/4;z=(m[5]+m[7])/s;}
  else{const s=Math.sqrt(1+m[8]-m[0]-m[4])*2;w=(m[3]-m[1])/s;x=(m[2]+m[6])/s;y=(m[5]+m[7])/s;z=s/4;}
  const l=Math.hypot(x,y,z,w);return[x/l,y/l,z/l,w/l];};

function exportGLB(detail,file,anims){
  const a=assemble(detail),{X,NB,names,nv}=a,piv=X.piv,par=X.par;
  const bin=[];let off=0;const views=[],acc=[];
  const add=(arr,type,comp,o)=>{o=o||{};const b=Buffer.from(arr.buffer,arr.byteOffset,arr.byteLength);const pad=(4-off%4)%4;if(pad){bin.push(Buffer.alloc(pad));off+=pad;}
    const v={buffer:0,byteOffset:off,byteLength:b.length};if(o.target)v.target=o.target;views.push(v);bin.push(b);off+=b.length;
    const n={VEC4:4,VEC3:3,VEC2:2,SCALAR:1,MAT4:16}[type],ac={bufferView:views.length-1,componentType:comp,count:arr.length/n,type};
    if(o.norm)ac.normalized=true;
    if(o.minmax){const mn=new Array(n).fill(1e30),mx=new Array(n).fill(-1e30);for(let i=0;i<arr.length;i++){const k=i%n;if(arr[i]<mn[k])mn[k]=arr[i];if(arr[i]>mx[k])mx[k]=arr[i];}ac.min=mn;ac.max=mx;}
    acc.push(ac);return acc.length-1;};
  const F=5126,AB=34962,EAB=34963;
  // Rest position, for shaders that paint by place on the body: TEXCOORD_2 = rest x,y and TEXCOORD_3 = rest z and the
  // rest normal's y. Godot imports the pair as CUSTOM0 (xyz = rest position, w = rest normal y). Without it, anything
  // painted by position stays fixed in space and slides over the skin when a limb moves.
  const R2=new Float32Array(nv*2),R3=new Float32Array(nv*2);for(let i=0;i<nv;i++){R2[i*2]=a.P[i*3];R2[i*2+1]=a.P[i*3+1];R3[i*2]=a.P[i*3+2];R3[i*2+1]=a.N[i*3+1];}
  const prim={attributes:{POSITION:add(a.P,'VEC3',F,{target:AB,minmax:1}),NORMAL:add(a.N,'VEC3',F,{target:AB}),TEXCOORD_0:add(a.UV,'VEC2',F,{target:AB}),TEXCOORD_1:add(a.UV2,'VEC2',F,{target:AB}),TEXCOORD_2:add(R2,'VEC2',F,{target:AB}),TEXCOORD_3:add(R3,'VEC2',F,{target:AB}),
    COLOR_0:add(a.COL,'VEC4',5121,{target:AB,norm:1}),JOINTS_0:add(a.J,'VEC4',5121,{target:AB}),WEIGHTS_0:add(a.W,'VEC4',F,{target:AB})},
    indices:add(a.I,'SCALAR',a.I instanceof Uint32Array?5125:5123,{target:EAB}),material:0,mode:4};
  // nodes: 0 = mesh, 1.. = bones
  const nodes=[{name:'MaleBody_Muscular',mesh:0,skin:0}];
  for(let i=0;i<NB;i++){const p=piv[i],q=par[i]<0?[0,0,0]:piv[par[i]];nodes.push({name:names[i],translation:[p[0]-q[0],p[1]-q[1],p[2]-q[2]]});}
  for(let i=0;i<NB;i++)if(par[i]>=0){const pn=nodes[par[i]+1];(pn.children=pn.children||[]).push(i+1);}
  const ibm=new Float32Array(NB*16);for(let i=0;i<NB;i++){const o=i*16;ibm[o]=ibm[o+5]=ibm[o+10]=ibm[o+15]=1;ibm[o+12]=-piv[i][0];ibm[o+13]=-piv[i][1];ibm[o+14]=-piv[i][2];}
  const skin={name:'MaleBody_Muscular_Skeleton',joints:Array.from({length:NB},(_,i)=>i+1),skeleton:1,inverseBindMatrices:add(ibm,'MAT4',F)};
  const animations=[];
  if(anims)for(const [cname,dur,fn] of CLIPS){const nf=Math.round(dur*12)+1,times=new Float32Array(nf),rot=Array.from({length:NB},()=>new Float32Array(nf*4)),tr0=new Float32Array(nf*3),tr1=new Float32Array(nf*3);
    for(let k=0;k<nf;k++){times[k]=k/12;a.rig[fn](k/12);const L=X.last();
      for(let i=0;i<NB;i++){let q=quat(L.L[i]);if(k){const o=(k-1)*4,r=rot[i];if(q[0]*r[o]+q[1]*r[o+1]+q[2]*r[o+2]+q[3]*r[o+3]<0)q=q.map(v=>-v);}rot[i].set(q,k*4);}
      const t0=L.T[0],t1=L.T[1];tr0.set([piv[0][0]+t0[0],piv[0][1]+t0[1]+L.dy,piv[0][2]+t0[2]],k*3);tr1.set([piv[1][0]-piv[0][0]+t1[0],piv[1][1]-piv[0][1]+t1[1],piv[1][2]-piv[0][2]+t1[2]],k*3);}
    const ta=add(times,'SCALAR',F,{minmax:1}),samplers=[],channels=[];
    const ch=(node,path,arr,type)=>{samplers.push({input:ta,output:add(arr,type,F),interpolation:'LINEAR'});channels.push({sampler:samplers.length-1,target:{node,path}});};
    for(let i=0;i<NB;i++){const r=rot[i];let mv=false;for(let k=0;k<nf&&!mv;k++)if(Math.abs(r[k*4+3])<.999999)mv=true;if(mv)ch(i+1,'rotation',r,'VEC4');}
    ch(1,'translation',tr0,'VEC3');let m1=false;for(let k=0;k<nf;k++)if(Math.abs(tr1[k*3+1]-tr1[1])>1e-6)m1=true;if(m1)ch(2,'translation',tr1,'VEC3');
    animations.push({name:cname,samplers,channels});}
  a.rig.rest();
  const json={asset:{version:'2.0',generator:'MaleBody_Muscular exporter'},scene:0,scenes:[{name:'MaleBody_Muscular',nodes:[0,1]}],nodes,meshes:[{name:'MaleBody_Muscular',primitives:[prim]}],skins:[skin],
    materials:[{name:'Skin',pbrMetallicRoughness:{baseColorFactor:[.75,.54,.41,1],metallicFactor:0,roughnessFactor:.9}}],accessors:acc,bufferViews:views,buffers:[{byteLength:0}]};
  if(animations.length)json.animations=animations;
  const pad=(4-off%4)%4;if(pad){bin.push(Buffer.alloc(pad));off+=pad;}json.buffers[0].byteLength=off;
  let jb=Buffer.from(JSON.stringify(json));if(jb.length%4)jb=Buffer.concat([jb,Buffer.alloc(4-jb.length%4,0x20)]);
  const head=Buffer.alloc(12);head.writeUInt32LE(0x46546C67,0);head.writeUInt32LE(2,4);head.writeUInt32LE(12+8+jb.length+8+off,8);
  const h1=Buffer.alloc(8);h1.writeUInt32LE(jb.length,0);h1.writeUInt32LE(0x4E4F534A,4);const h2=Buffer.alloc(8);h2.writeUInt32LE(off,0);h2.writeUInt32LE(0x004E4942,4);
  fs.writeFileSync(file,Buffer.concat([head,h1,jb,h2,...bin]));
  return{file,tris:a.ni/3,verts:nv,bones:NB,clips:animations.length,bytes:12+8+jb.length+8+off};
}
module.exports={assemble,exportGLB,CLIPS,quat};
if(require.main===module){fs.mkdirSync('./export',{recursive:true});
  for(const [d,f] of[[1,'MaleBody_Muscular.glb'],[.56,'MaleBody_Muscular_mid.glb'],[.25,'MaleBody_Muscular_low.glb']])console.log(JSON.stringify(exportGLB(d,'./export/'+f,false)));}
