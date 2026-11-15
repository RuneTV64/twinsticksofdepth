// ShamblerMale_Muscular: zombie part variants built on MaleBody_Muscular.
// Six swap slots (Head, Torso, ArmL, ArmR, LegL, LegR), three states each (Intact, Rotted, Destroyed).
// Every variant is skinned to the exact MaleBody_Muscular skeleton, so any mix of slots shares one rig.
// Rot lives in COLOR.b: 0 to .3 dead skin (higher = bruised), .3 to .45 decay rim, .45 to .5 the fat under the skin,
// .5 to .8 muscle (deeper = darker), above .8 bone.
// The wounds are opened for real: holes cut through the skin, each with a wall through the layers. What shows at the
// bottom of a hole is one inner surface that zombie_decay.gdshader paints (bone, organs, blood); none of the insides
// are modelled. Nothing hangs out of the model either: spilling guts and flying limbs are for the game's effects.
const MB=require('./male_body_muscular.js'),{makeRig}=require('./rig.js'),AN=require('./anatomy.js');
const LBSK=1.7;
const SLOTS=['Head','Torso','ArmL','ArmR','LegL','LegR'],STATES=['Intact','Rotted','Destroyed'];
// states that are never rolled at spawn, only switched to in play
const EXTRA={Head:['Decapitated']};
function slotOf(name){
  if(/^(head|neck|ear)/.test(name))return'Head';if(name==='torso')return'Torso';
  const m=/^(upperArm|forearm|hand|index|middle|ring|pinky|thumb)([LR])/.exec(name);if(m)return'Arm'+m[2];
  const l=/^(thigh|calf|foot|toe\d)([LR])/.exec(name);if(l)return'Leg'+l[2];throw new Error('no slot for '+name);}

// deterministic value noise
const hash=(x,y,z,s)=>{const h=Math.sin(x*127.1+y*311.7+z*74.7+s*19.19)*43758.5453;return h-Math.floor(h);};
function noise3(x,y,z,s){const X=Math.floor(x),Y=Math.floor(y),Z=Math.floor(z),fx=x-X,fy=y-Y,fz=z-Z,u=t=>t*t*(3-2*t),a=u(fx),b=u(fy),c=u(fz);let r=0;
  for(let i=0;i<2;i++)for(let j=0;j<2;j++)for(let k=0;k<2;k++)r+=hash(X+i,Y+j,Z+k,s)*(i?a:1-a)*(j?b:1-b)*(k?c:1-c);return r;}
const fbm=(x,y,z,s)=>noise3(x,y,z,s)*.6+noise3(x*2.3,y*2.3,z*2.3,s+7)*.3+noise3(x*5.1,y*5.1,z*5.1,s+13)*.1;
const ss=(v,a,b)=>{const t=Math.min(1,Math.max(0,(v-a)/(b-a)));return t*t*(3-2*t);};
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2],len=v=>Math.hypot(v[0],v[1],v[2]),unit=v=>{const l=len(v)||1;return[v[0]/l,v[1]/l,v[2]/l];};
function normals(P,I){const N=new Float32Array(P.length);
  for(let i=0;i<I.length;i+=3){const a=I[i]*3,b=I[i+1]*3,c=I[i+2]*3,ux=P[b]-P[a],uy=P[b+1]-P[a+1],uz=P[b+2]-P[a+2],vx=P[c]-P[a],vy=P[c+1]-P[a+1],vz=P[c+2]-P[a+2];
    const nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;for(const k of[a,b,c]){N[k]+=nx;N[k+1]+=ny;N[k+2]+=nz;}}
  for(let i=0;i<N.length;i+=3){const l=Math.hypot(N[i],N[i+1],N[i+2])||1;N[i]/=l;N[i+1]/=l;N[i+2]/=l;}return N;}

// ---------- base: the untouched body with its export data, per part ----------
function buildBase(detail){
  const parts=MB.build({detail}),rig=makeRig(parts,MB.SPEC),X=rig.X,S=MB.SPEC;
  const out=parts.map((p,k)=>{const s=X.skin[k],n=p.P.length/3,base=p.name.replace(/[LR]\d*$/,'');
    const J=new Uint8Array(n*4),W=new Float32Array(n*4),UV=new Float32Array(n*2),UV2=new Float32Array(n*2),COL=new Uint8Array(n*4);
    for(let i=0;i<n;i++){const A=s.A[i],B=s.B[i],w=s.W[i],t=s.TW[i];let ws;
      if(s.SC[i]){const b=s.SC[i],wa=Math.min(1,Math.max(0,(s.WA[i]-.5)*LBSK+.5)),wc=Math.max(s.WC[i],wa),wt=t>=0?w:0;ws=[[1,1-wc],[b===X.BL?3:4,wc*(1-wa)],[b+3,wc*wa*(1-wt)],[b+4,wc*wa*wt]];}
      else if(t>=0)ws=[[A,1-w],[t,w]];else if(A===B||w>=1)ws=[[B,1]];else ws=[[A,1-w],[B,w]];
      ws=ws.filter(e=>e[1]>1e-4);const sum=ws.reduce((a,e)=>a+e[1],0);ws.forEach((e,q)=>{J[i*4+q]=e[0];W[i*4+q]=e[1]/sum;});
      const L=p.L,f=L?Math.round(L[i*4+3]):0;let code=f;const c8=x=>Math.round(255*Math.min(1,Math.max(0,x)));
      if(L&&f<=1){UV[i*2]=L[i*4];UV[i*2+1]=L[i*4+1];UV2[i*2]=L[i*4+2];}
      else if(f===2)COL[i*4]=c8(L[i*4]);
      else if(f===3){COL[i*4]=c8(L[i*4]);UV[i*2]=s.P0[i*3];UV[i*2+1]=s.P0[i*3+1];COL[i*4+1]=c8(s.P0[i*3+2]/.3+.5);}
      else if(f>=4){UV[i*2]=L[i*4];UV[i*2+1]=L[i*4+1];UV2[i*2]=L[i*4+2];}
      else if(base==='thigh'){code=8;UV[i*2]=s.P0[i*3];UV[i*2+1]=s.P0[i*3+1];}
      COL[i*4+3]=code*17;}
    return{name:p.name,slot:slotOf(p.name),P:new Float32Array(s.P0),N:new Float32Array(s.N0),I:Uint32Array.from(p.I),J,W,UV,UV2,COL};});
  // bone names, in the same order and spelling as MaleBody_Muscular's exporter
  const names=['Hips','Chest','Neck','ClavicleL','ClavicleR'];for(const sd of['L','R'])for(const n of['Thigh','Calf','Foot','UpperArm','UpperArmRoll','Forearm','ForearmRoll','Hand'])names.push(n+sd);
  names.push('Head');parts.forEach(p=>{if(p.jp)names.push(p.name[0].toUpperCase()+p.name.slice(1));});if(names.length!==rig.bones)throw new Error('bone names '+names.length);
  return{detail,parts:out,names,piv:X.piv.map(v=>v.slice()),par:X.par.slice(),BL:X.BL,BR:X.BR,HD:X.HD,NB:rig.bones,S,DK:detail,K:AN.skinTable(out.find(p=>p.name==='torso'))};
}

// ---------- geometry helpers ----------
const clonePart=p=>({name:p.name,slot:p.slot,P:new Float32Array(p.P),N:new Float32Array(p.N),I:Uint32Array.from(p.I),J:new Uint8Array(p.J),W:new Float32Array(p.W),UV:new Float32Array(p.UV),UV2:new Float32Array(p.UV2),COL:new Uint8Array(p.COL),rot:new Float32Array(p.P.length/3),touch:new Float32Array(p.P.length/3)});
// along/axis helpers: the segment a part hangs on, joint to joint
function segOf(B,name){const s=/[L]/.test(name.replace(/^[a-z]+/,''))?'L':'R',b=s==='L'?B.BL:B.BR,P=B.piv;
  if(/^upperArm/.test(name))return[P[b+3],P[b+5]];if(/^forearm/.test(name))return[P[b+5],P[b+7]];
  if(/^thigh/.test(name))return[P[b],P[b+1]];if(/^calf/.test(name))return[P[b+1],P[b+2]];if(/^hand/.test(name))return[P[b+7],sub(P[b+7],[0,.11,0])];
  if(name==='torso')return[[0,.86,0],[0,1.54,0]];if(name==='head')return[[0,1.56,0],[0,1.80,0]];if(name==='neck')return[[0,1.47,0],[0,1.66,0]];
  if(/^foot/.test(name))return[P[b+2],sub(P[b+2],[0,0,-.15])];return null;}
// pick the surface point on a part at a fraction along its segment that faces a given direction
function anchor(B,part,t,dir){const sg=segOf(B,part.name),A=sg[0],D=sub(sg[1],A),dd=dot(D,D),d=unit(dir);let best=-1e9,bi=0;
  for(let i=0;i<part.P.length/3;i++){const p=[part.P[i*3],part.P[i*3+1],part.P[i*3+2]],al=dot(sub(p,A),D)/dd,n=[part.N[i*3],part.N[i*3+1],part.N[i*3+2]];
    const sc=dot(n,d)*1.0-Math.abs(al-t)*6;if(sc>best){best=sc;bi=i;}}
  return[part.P[bi*3],part.P[bi*3+1],part.P[bi*3+2]];}

// how far inside a wound patch a vertex is: above 0 inside it, 1 at the centre, below 0 in the bruised skin round it
function patchT(part,i,c,o){return patchAt([part.P[i*3],part.P[i*3+1],part.P[i*3+2]],c,o);}
// the same for any point
function patchAt(p,c,o){const P=p,i=0,r=o.r,seed=o.seed||1,ax=o.ax?unit(o.ax):null,el=o.elong||1,v=[P[i*3]-c[0],P[i*3+1]-c[1],P[i*3+2]-c[2]];let d=len(v);
  // elongated along the limb: shrink the along-axis part of the distance
  if(ax){const a=dot(v,ax);d=Math.sqrt(Math.max(0,d*d-a*a)+(a/el)*(a/el));}
  if(d>r*2.3)return null;
  const jag=1+.62*(fbm(P[i*3]*34,P[i*3+1]*34,P[i*3+2]*34,seed)-.5)*2+.25*(noise3(P[i*3]*110,P[i*3+1]*110,P[i*3+2]*110,seed+2)-.5),rr=r*jag*(o.stretch?1+o.stretch*Math.abs(v[1])/Math.max(len(v),1e-6):1);
  return 1-d/rr;}
// a wound patch: carves in along the normal, writes rot in layers the way flesh is built: torn skin at the edge, a thin
// band of fat, then muscle. kinds: flesh, bone (bone shows in the middle), gut (deep dark)
function wound(part,c,o){const P=part.P,N=part.N,n=P.length/3,seed=o.seed||1,dep=o.depth||.008;
  for(let i=0;i<n;i++){const t=patchT(part,i,c,o);if(t===null)continue;let rot,dd=0;
    if(t<=0){const h=1+t/1.1;if(h<=0)continue;rot=.15+.14*h*h;}
    else{const core=ss(t,.08,.32);dd=dep*core*(.75+.5*fbm(P[i*3]*60,P[i*3+1]*60,P[i*3+2]*60,seed+3));
      rot=t<.1?.38:t<.2?.47:.52+.23*fbm(P[i*3]*70,P[i*3+1]*70,P[i*3+2]*70,seed+5);
      if(o.kind==='bone'&&t>.45){rot=.92;dd*=.55;}
      if(o.kind==='gut'&&t>.3){rot=.74+.06*fbm(P[i*3]*90,P[i*3+1]*90,P[i*3+2]*90,seed+9);}}
    if(rot>part.rot[i]){part.rot[i]=rot;}
    if(dd){P[i*3]-=N[i*3]*dd;P[i*3+1]-=N[i*3+1]*dd;P[i*3+2]-=N[i*3+2]*dd;}
    part.touch[i]=Math.max(part.touch[i],t>-.3?1:0);}}

// a real opening: the skin inside the patch is removed and the edge gets a wall running in to the muscle underneath,
// layered skin, fat, muscle, so you look into the body at whatever is behind (ribs, muscle wall, organs)
function hole(part,c,o){const P=part.P,N=part.N,n=P.length/3,open=o.open||.2,gone=new Uint8Array(n);
  for(let i=0;i<n;i++){const t=patchT(part,i,c,o);if(t===null)continue;
    if(t>open){gone[i]=1;continue;}
    let rot;if(t<=0){const h=1+t/1.1;if(h<=0)continue;rot=.15+.14*h*h;}else{rot=t<open*.5?.34:.38;const dd=.004*ss(t,0,open);P[i*3]-=N[i*3]*dd;P[i*3+1]-=N[i*3+1]*dd;P[i*3+2]-=N[i*3+2]*dd;}
    if(rot>part.rot[i])part.rot[i]=rot;part.touch[i]=Math.max(part.touch[i],t>-.3?1:0);}
  return openUp(part,gone,o.wall,o.wallRot);}
// drop every triangle that touches a removed vertex; with `wall`, line each opening with a wall down to wall(p, normal)
function openUp(part,gone,wall,wallRot){const P=part.P,n=P.length/3,keep=[];
  const cutE=new Set();   // edges of the triangles taken out: only these become the rim of an opening (the mesh has seams of its own)
  for(let t=0;t<part.I.length;t+=3){const a=part.I[t],b=part.I[t+1],c=part.I[t+2];
    if(gone[a]||gone[b]||gone[c]){for(const [u,w] of [[a,b],[b,c],[c,a]])cutE.add(u<w?u+'_'+w:w+'_'+u);continue;}keep.push(a,b,c);}
  if(keep.length===part.I.length)return 0;
  const E=new Map();for(let t=0;t<keep.length;t+=3)for(let e=0;e<3;e++){const a=keep[t+e],b=keep[t+(e+1)%3],k=a<b?a+'_'+b:b+'_'+a;E.set(k,E.has(k)?null:[a,b]);}
  const nxt=new Map();for(const [k,v] of E)if(v&&cutE.has(k))nxt.set(v[0],v[1]);
  const loops=[],seen=new Set();for(const s0 of nxt.keys()){if(seen.has(s0))continue;const L=[];let c=s0;while(c!==undefined&&!seen.has(c)){seen.add(c);L.push(c);c=nxt.get(c);}if(L.length>2)loops.push(L);}
  const add={P:[],J:[],W:[],rot:[]},I=keep.slice();let nv=n;
  if(wall)for(const L of loops){const R=wallRot||[.40,.47,.56,.68],F=[0,.12,.3,1],base=nv;   // skin edge, fat, muscle, deep muscle (or, for bone, its own layers)
    for(let k=0;k<4;k++)L.forEach(v=>{const p=[P[v*3],P[v*3+1],P[v*3+2]],q=wall(p,[part.N[v*3],part.N[v*3+1],part.N[v*3+2]]),f=F[k];
      add.P.push(p[0]+(q[0]-p[0])*f,p[1]+(q[1]-p[1])*f,p[2]+(q[2]-p[2])*f);add.J.push(...part.J.slice(v*4,v*4+4));add.W.push(...part.W.slice(v*4,v*4+4));add.rot.push(R[k]);});
    for(let k=0;k<3;k++)for(let j=0;j<L.length;j++){const a=base+k*L.length+j,b=base+k*L.length+(j+1)%L.length,ma=a+L.length,mb=b+L.length;I.push(b,a,ma,b,ma,mb);}
    nv+=L.length*4;}
  const tot=nv,NP=new Float32Array(tot*3),NN=new Float32Array(tot*3),NJ=new Uint8Array(tot*4),NW=new Float32Array(tot*4),NU=new Float32Array(tot*2),NU2=new Float32Array(tot*2),NC=new Uint8Array(tot*4),NR=new Float32Array(tot),NT=new Float32Array(tot);
  NP.set(P);NN.set(part.N);NJ.set(part.J);NW.set(part.W);NU.set(part.UV);NU2.set(part.UV2);NC.set(part.COL);NR.set(part.rot);NT.set(part.touch);
  NP.set(add.P,n*3);NJ.set(add.J,n*4);NW.set(add.W,n*4);NR.set(add.rot,n);for(let i=n;i<tot;i++)NT[i]=1;   // wall verts carry no detail code and get fresh normals
  Object.assign(part,{P:NP,N:NN,J:NJ,W:NW,UV:NU,UV2:NU2,COL:NC,rot:NR,touch:NT,I:Uint32Array.from(I)});
  compact(part);return loops.length;}

// dead skin everywhere: blotchy bruising and pooled blood low on the body
function deadSkin(part,seed){const P=part.P,n=P.length/3;for(let i=0;i<n;i++){const x=P[i*3],y=P[i*3+1],z=P[i*3+2],m=fbm(x*11,y*11,z*11,seed),pool=.08*(1-ss(y,.15,.8));
  // dark veins: thin ridges of a second noise field
  const vn=Math.abs(fbm(x*26+3,y*18,z*26,seed+31)-.5),vein=vn<.022?.27:vn<.04?.19:0;
  part.rot[i]=Math.max(part.rot[i],Math.min(.29,Math.max(.05+Math.max(0,m-.4)*.75+pool,vein)));}}

// recompute normals only where the surface was changed, so the body's tuned seams keep their shading
function settle(part){const NN=normals(part.P,part.I);for(let i=0;i<part.P.length/3;i++)if(part.touch[i]){for(let k=0;k<3;k++)part.N[i*3+k]=NN[i*3+k];}}

// cut a part: drop every triangle that touches a vertex past the cut, then close the hole with a ragged cap of flesh and bone
function cut(part,beyond,capRot,capPush,capCode){const P=part.P,n=P.length/3,gone=new Uint8Array(n);for(let i=0;i<n;i++)gone[i]=beyond(P[i*3],P[i*3+1],P[i*3+2])?1:0;
  const keep=[];for(let t=0;t<part.I.length;t+=3){const a=part.I[t],b=part.I[t+1],c=part.I[t+2];if(gone[a]||gone[b]||gone[c])continue;keep.push(a,b,c);}
  // boundary edges: used once, in the direction a->b of the kept triangle
  const E=new Map();for(let t=0;t<keep.length;t+=3)for(let e=0;e<3;e++){const a=keep[t+e],b=keep[t+(e+1)%3],k=a<b?a+'_'+b:b+'_'+a;E.set(k,E.has(k)?null:[a,b]);}
  const nxt=new Map();for(const v of E.values())if(v)nxt.set(v[0],v[1]);
  const loops=[],seen=new Set();for(const s of nxt.keys()){if(seen.has(s))continue;const L=[];let c=s;while(c!==undefined&&!seen.has(c)){seen.add(c);L.push(c);c=nxt.get(c);}if(L.length>2)loops.push(L);}
  // rebuild arrays: kept verts in place, plus cap verts (copies of the rim, then a center)
  const add={P:[],N:[],J:[],W:[],rot:[]},I=keep.slice();let nv=n;
  for(const L of loops){let c=[0,0,0];L.forEach(v=>{c[0]+=P[v*3];c[1]+=P[v*3+1];c[2]+=P[v*3+2];});c=c.map(x=>x/L.length);
    // cap normal: average of the rim's outward drift, pointing away from the kept body
    // same winding as the cap triangles (b,a,center), so this is the cap's true outward normal
    let cn=[0,0,0];for(let i=0;i<L.length;i++){const a=[P[L[i]*3],P[L[i]*3+1],P[L[i]*3+2]],b=[P[L[(i+1)%L.length]*3],P[L[(i+1)%L.length]*3+1],P[L[(i+1)%L.length]*3+2]];
      const u=sub(a,b),w=sub(c,b);cn=[cn[0]+u[1]*w[2]-u[2]*w[1],cn[1]+u[2]*w[0]-u[0]*w[2],cn[2]+u[0]*w[1]-u[1]*w[0]];}cn=unit(cn);
    const vert=(p,src,r)=>{add.P.push(p[0],p[1],p[2]);add.N.push(...cn);add.J.push(...part.J.slice(src*4,src*4+4));add.W.push(...part.W.slice(src*4,src*4+4));add.rot.push(r);};
    // order: rim copies, then the center, then a ring of jagged mid points so the cap is not a flat disc
    const rim0=nv,ci=rim0+L.length,mid0=ci+1;
    L.forEach(v=>vert([P[v*3],P[v*3+1],P[v*3+2]],v,.62));
    vert([c[0]+cn[0]*(capPush||0),c[1]+cn[1]*(capPush||0),c[2]+cn[2]*(capPush||0)],L[0],capRot);
    L.forEach((v,j)=>{const k=.55,jit=(hash(j,v,1,3)-.5)*.012;vert([c[0]+(P[v*3]-c[0])*k+cn[0]*jit,c[1]+(P[v*3+1]-c[1])*k+cn[1]*jit,c[2]+(P[v*3+2]-c[2])*k+cn[2]*jit],v,.7);});
    for(let j=0;j<L.length;j++){const a=rim0+j,b=rim0+(j+1)%L.length,ma=mid0+j,mb=mid0+(j+1)%L.length;
      I.push(b,a,ma, b,ma,mb, mb,ma,ci);}
    nv+=L.length*2+1;}
  // pack: drop unused verts
  const tot=nv,NP=new Float32Array(tot*3),NN=new Float32Array(tot*3),NJ=new Uint8Array(tot*4),NW=new Float32Array(tot*4),NU=new Float32Array(tot*2),NU2=new Float32Array(tot*2),NC=new Uint8Array(tot*4),NR=new Float32Array(tot),NT=new Float32Array(tot);
  NP.set(P);NN.set(part.N);NJ.set(part.J);NW.set(part.W);NU.set(part.UV);NU2.set(part.UV2);NC.set(part.COL);NR.set(part.rot);NT.set(part.touch);
  NP.set(add.P,n*3);NN.set(add.N,n*3);NJ.set(add.J,n*4);NW.set(add.W,n*4);NR.set(add.rot,n);
  const code=part.COL[3];for(let i=n;i<tot;i++)NC[i*4+3]=capCode!==undefined?capCode*17:(code>=34&&code<=51?0:code);// cap verts carry no detail code, or the code they're given
  Object.assign(part,{P:NP,N:NN,J:NJ,W:NW,UV:NU,UV2:NU2,COL:NC,rot:NR,touch:NT,I:Uint32Array.from(I)});
  compact(part);return loops.length;}
function compact(part){const n=part.P.length/3,used=new Int32Array(n).fill(-1);let k=0;for(const v of part.I)if(used[v]<0)used[v]=k++;
  const f=(A,w,T)=>{const o=new T(k*w);for(let i=0;i<n;i++)if(used[i]>=0)for(let j=0;j<w;j++)o[used[i]*w+j]=A[i*w+j];return o;};
  Object.assign(part,{P:f(part.P,3,Float32Array),N:f(part.N,3,Float32Array),J:f(part.J,4,Uint8Array),W:f(part.W,4,Float32Array),UV:f(part.UV,2,Float32Array),UV2:f(part.UV2,2,Float32Array),COL:f(part.COL,4,Uint8Array),rot:f(part.rot,1,Float32Array),touch:f(part.touch,1,Float32Array),I:part.I.map(v=>used[v])});}

// the muscle under a limb's skin: the same shape a little smaller, so a hole in the skin has something behind it
function innerLimb(part,inset){const c=clonePart(part),n=c.P.length/3;c.name=part.name+'Muscle';c.slot=null;
  for(let i=0;i<n;i++){for(let k=0;k<3;k++)c.P[i*3+k]-=part.N[i*3+k]*inset;c.rot[i]=.6;c.UV[i*2]=c.UV[i*2+1]=c.UV2[i*2]=c.UV2[i*2+1]=0;c.COL[i*4]=56;c.COL[i*4+1]=0;c.COL[i*4+3]=INNER.limb*17;}
  c.N=normals(c.P,c.I);return c;}
// gouge that muscle down toward the bone under a wound: inside the patch the surface sinks until the bone stands well
// out of it. The bone itself is not modelled: the shader knows where each limb bone runs (LIMB_BONES, written into it
// by gen_decay_shader.js) and paints it as a round shape wherever it stands out of this surface.
function pit(mus,c,o,bones){const P=mus.P,n=P.length/3;
  for(let i=0;i<n;i++){const t=patchT(mus,i,c,o);if(t===null||t<=.08)continue;const p=[P[i*3],P[i*3+1],P[i*3+2]];let best=null,bd=1e9;
    for(const [A,Bq,r] of bones){const d=sub(Bq,A),u=Math.min(1,Math.max(0,dot(sub(p,A),d)/dot(d,d))),q=[A[0]+d[0]*u,A[1]+d[1]*u,A[2]+d[2]*u],dist=len(sub(p,q));if(dist<bd){bd=dist;const dir=unit(sub(p,q));best=[q[0]+dir[0]*r*.1,q[1]+dir[1]*r*.1,q[2]+dir[2]*r*.1];}}
    const k=ss(t,.08,.5);for(let j=0;j<3;j++)P[i*3+j]+=(best[j]-p[j])*k;mus.rot[i]=.6+.16*k;mus.COL[i*4]=Math.round(56+110*k);}
  mus.N=normals(mus.P,mus.I);}
// open a limb down to the bone: a real hole in the skin, the muscle gouged out under it, the bones painted in the gouge
const LIMB_BONES={};   // every bone a limb wound goes down to: name -> {A, B, r}, in the body's rest position
function toTheBone(B,part,t,dir,o,bones,extra){const sg=segOf(B,part.name),oo=Object.assign({ax:sub(sg[1],sg[0])},o),mus=innerLimb(part,.008),c=anchor(B,part,t,dir);
  hole(part,c,Object.assign({wall:(p,nrm)=>[p[0]-nrm[0]*.0085,p[1]-nrm[1]*.0085,p[2]-nrm[2]*.0085]},oo));pit(mus,c,oo,bones.map(b=>[b.A,b.B,b.r]));
  bones.forEach(b=>{LIMB_BONES[b.name]={A:b.A,B:b.B,r:b.r};});extra.push(mus);}

// a bare bone stub: a thin tapered shaft with a splintered end, rigid on one joint
function boneStub(name,A,B,r,joint,seed,DK){const ax=unit(sub(B,A)),L=len(sub(B,A)),seg=Math.max(6,Math.round(9*Math.max(DK,.6))),rings=6,P=[],I=[];
  let u=Math.abs(ax[1])<.9?[0,1,0]:[1,0,0];const e1=unit([ax[1]*u[2]-ax[2]*u[1],ax[2]*u[0]-ax[0]*u[2],ax[0]*u[1]-ax[1]*u[0]]),e2=[ax[1]*e1[2]-ax[2]*e1[1],ax[2]*e1[0]-ax[0]*e1[2],ax[0]*e1[1]-ax[1]*e1[0]];
  for(let j=0;j<=rings;j++){const t=j/rings;for(let s=0;s<seg;s++){const a=s/seg*Math.PI*2,end=j===rings?(hash(s,j,seed,5)*.9+.1):0,tt=Math.min(1,t)-end*.22/rings*rings*.18;
    const rr=r*(1.15-.25*t+(j===0?.25:0))*(j===rings?.75+.35*hash(s,1,seed,9):1),c=[A[0]+ax[0]*L*tt,A[1]+ax[1]*L*tt,A[2]+ax[2]*L*tt];
    P.push(c[0]+(e1[0]*Math.cos(a)+e2[0]*Math.sin(a))*rr,c[1]+(e1[1]*Math.cos(a)+e2[1]*Math.sin(a))*rr,c[2]+(e1[2]*Math.cos(a)+e2[2]*Math.sin(a))*rr);}}
  for(let j=0;j<rings;j++)for(let s=0;s<seg;s++){const a=j*seg+s,b=j*seg+(s+1)%seg,c=a+seg,d=b+seg;I.push(a,b,c,b,d,c);}
  const tip=P.length/3;P.push(B[0]-ax[0]*L*.04,B[1]-ax[1]*L*.04,B[2]-ax[2]*L*.04);for(let s=0;s<seg;s++)I.push(rings*seg+s,rings*seg+(s+1)%seg,tip);
  const base=P.length/3;P.push(A[0]-ax[0]*.004,A[1]-ax[1]*.004,A[2]-ax[2]*.004);for(let s=0;s<seg;s++)I.push((s+1)%seg,s,base);
  const n=P.length/3,Pf=new Float32Array(P),I32=Uint32Array.from(I);
  // orient outward
  let vol=0;for(let i=0;i<I32.length;i+=3){const a=I32[i]*3,b=I32[i+1]*3,c=I32[i+2]*3;vol+=Pf[a]*(Pf[b+1]*Pf[c+2]-Pf[b+2]*Pf[c+1])-Pf[a+1]*(Pf[b]*Pf[c+2]-Pf[b+2]*Pf[c])+Pf[a+2]*(Pf[b]*Pf[c+1]-Pf[b+1]*Pf[c]);}
  if(vol<0)for(let i=0;i<I32.length;i+=3){const t=I32[i+1];I32[i+1]=I32[i+2];I32[i+2]=t;}
  const J=new Uint8Array(n*4),W=new Float32Array(n*4),rot=new Float32Array(n);for(let i=0;i<n;i++){J[i*4]=joint;W[i*4]=1;rot[i]=i>=rings*seg||i/seg>=rings-.01?.9:.95;}
  for(let s=0;s<seg;s++)rot[s]=.66;// where the bone leaves the flesh
  return{name,slot:null,P:Pf,N:normals(Pf,I32),I:I32,J,W,UV:new Float32Array(n*2),UV2:new Float32Array(n*2),COL:new Uint8Array(n*4),rot,touch:new Float32Array(n)};}

// ---------- the recipes ----------
// arm and leg local frames, matching how the body builds them
function armFrames(B,s){const S=B.S,sh=[s*S.shoulder[0],S.shoulder[1],-.008],ao=s*S.armOut,rZ=(p,a)=>{const c=Math.cos(a),n=Math.sin(a);return[p[0]*c-p[1]*n,p[0]*n+p[1]*c,p[2]];},rX=(p,a)=>{const c=Math.cos(a),n=Math.sin(a);return[p[0],p[1]*c-p[2]*n,p[1]*n+p[2]*c];};
  const up=p=>{const q=rZ(p,ao);return[q[0]+sh[0],q[1]+sh[1],q[2]+sh[2]];},fo=p=>{const q=rX(p,S.elbowBend);return up([q[0],q[1]-S.elbowLen,q[2]]);};
  const toFore=(x,y,z)=>{const q=rZ([x-sh[0],y-sh[1],z-sh[2]],-ao);return rX([q[0],q[1]+S.elbowLen,q[2]],-S.elbowBend);};return{fo,toFore};}

// Part codes of the painted inner surfaces (written to COLOR.a as code * 17; zombie_decay.gdshader paints each kind):
// the muscle inside a limb, the inner wall of the torso, the skull under the scalp, the cut of a severed neck.
const INNER={limb:15,torso:14,skull:13,neck:12};
const NECK_CUT={y:1.59,slope:.18};   // the cut of a severed neck: its height at z = 0, and how much it drops toward the front
const BREAKS={'4L':[.80,1],'5L':[.70,1],'6L':[.76,1],'5R':[.86,.97]};   // the ribs snapped in the Destroyed torso: [from, to] along the bone
function makeVariant(B,slot,state){
  let torsoTears=[];   // where the Destroyed torso's inner wall is torn through (the anatomy map records it)
  const headBreaks=[]; // where the Destroyed head's skull is broken open (the same)
  const parts=B.parts.filter(p=>p.slot===slot).map(clonePart),get=n=>parts.find(p=>p.name===n),drop=new Set(),extra=[],sd=slot.slice(-1),s=sd==='L'?1:-1,b=sd==='L'?B.BL:B.BR;
  const seed={Head:11,Torso:23,ArmL:37,ArmR:41,LegL:53,LegR:67}[slot]+(state==='Destroyed'?100:0);
  parts.forEach(p=>deadSkin(p,seed));
  if(slot==='Torso')neckBlood(get('torso'),B.DK);   // before any holes are cut, while the mesh is still in its rows
  const W=(pn,t,dir,o)=>{const p=get(pn);if(!p)return;if(o.elong&&!o.ax){const sg=segOf(B,p.name);if(sg)o.ax=sub(sg[1],sg[0]);}wound(p,anchor(B,p,t,dir),o);};
  const side=(v)=>[v[0]*s,v[1],v[2]];// mirror x for the right side
  if(slot==='Torso'&&state!=='Intact'){
    // Opened for real: the skin is cut away and each hole has a wall running in through the layers. At the bottom of a
    // hole is one inner surface, and the shader paints the anatomy on it from the anatomy map (gen_anatomy_map.js):
    // ribs, cartilage, sternum, collarbone, shoulder blade, spine, hip bone on muscle, and, where that surface is torn
    // through in the Destroyed torso, the organs behind it. No bones or organs are modelled.
    const K=B.K,torso=get('torso'),far=state==='Destroyed';
    // the inner edge of a skin hole sits on that inner surface where it is close under the skin, else a short way in
    // (`deep` lets a hole go further in: the back and the hips have thick muscle over them)
    const wallTo=cap=>(p,nrm)=>{const q=AN.projectEnv(p,AN.CORE_IN-.0015),d=len(sub(q,p)),inward=Math.hypot(q[0],q[2])<Math.hypot(p[0],p[2]);
      if(!inward||d<.006)return[p[0]-nrm[0]*.012,p[1]-nrm[1]*.012,p[2]-nrm[2]*.012];if(d>cap)return[p[0]+(q[0]-p[0])*cap/d,p[1]+(q[1]-p[1])*cap/d,p[2]+(q[2]-p[2])*cap/d];return q;};
    const wall=wallTo(.03),holes=[],tears=[];
    const H=(t,dir,ho)=>{const c=anchor(B,torso,t,dir);hole(torso,c,Object.assign({wall:ho.deep?wallTo(ho.deep):wall},ho));holes.push({c,r:ho.r*Math.sqrt(ho.elong||1)});return c;};
    // where the inner surface is torn through too, under a skin hole (same patch, a little smaller): the shader paints the organs there
    const tear=(c,ho,k)=>tears.push({c:AN.projectEnv(c,AN.CORE_IN),o:Object.assign({},ho,{r:ho.r*k,seed:(ho.seed||1)+50})});
    if(state==='Rotted'){
      H(.6,side([.9,0,-.4]),{r:.085,seed:3,ax:[0,1,0],elong:1.3});                 // the flank: ribs showing on one side
      H(.3,side([-.4,0,1]),{r:.062,seed:5,ax:[1,0,0],elong:1.5});                  // a tear across the belly, down to the muscle
      H(.72,side([.25,.2,1]),{r:.036,seed:9});                                      // a bite on the chest, down to the cartilage
      H(.765,side([-.36,.1,-.93]),{r:.062,seed:33,deep:.06});                       // the upper back, down to the shoulder blade
      H(.22,side([-.86,0,-.5]),{r:.056,seed:11,deep:.06});}                         // above the hip, down to the crest of the hip bone
    if(far){
      const gut={r:.128,seed:13,stretch:.25},chest={r:.1,seed:15};
      tear(H(.4,[.15,0,1],gut),gut,.86);                                            // the gut torn open
      tear(H(.63,[.2,0,1],chest),chest,.84);                                        // the chest torn open over the heart
      H(.58,side([-1,0,-.2]),{r:.075,seed:17});                                     // ribs at the side
      H(.75,[0,.1,-1],{r:.05,seed:19,ax:[0,1,0],elong:1.9});                       // the spine at the back
      H(.86,side([.7,.4,.4]),{r:.04,seed:23});                                      // the collarbone
      H(.77,side([.55,.1,-.83]),{r:.062,seed:27,deep:.06});                         // the other shoulder blade, beside the spine
      H(.22,side([.88,0,-.47]),{r:.06,seed:21,deep:.06});}                          // the hip bone
    // the inner surface: only the patches of it that can be seen through a hole are kept
    const inner=AN.shell('innerWall',K,AN.CORE_IN,{detail:B.DK,rot:.6,taper:false}),n=inner.P.length/3,gone=new Uint8Array(n);
    // (COLOR.g says whether this torso is the one torn through; where exactly is in the anatomy map, from `tears`)
    for(let i=0;i<n;i++){const p=[inner.P[i*3],inner.P[i*3+1],inner.P[i*3+2]];gone[i]=holes.some(h=>len(sub(p,h.c))<h.r*2.4+.03)?0:1;
      inner.COL[i*4+1]=far?255:0;inner.COL[i*4+3]=INNER.torso*17;}
    openUp(inner,gone,null);inShadow(inner,K);extra.push(inner);torsoTears=tears;}
  if(slot==='Head'&&state==='Decapitated'){
    // head taken off: a short ragged neck stump with what's in a neck showing in the cut, and blood run down the neck
    drop.add('head');drop.add('earL');drop.add('earR');
    const nk=get('neck'),cutY=1.59,HD=B.HD;
    cut(nk,(x,y,z)=>{const a=Math.atan2(z,x);return y>cutY-.18*z+.022*(fbm(Math.cos(a)*2.6+7,Math.sin(a)*2.6+7,3,seed)-.5)*2+.008*(hash(Math.round(a*9),4,seed,1)-.5);},.7,-.004,INNER.neck);
    for(let i=0;i<nk.P.length/3;i++){const x=nk.P[i*3],y=nk.P[i*3+1],z=nk.P[i*3+2],top=cutY-.18*z;
      // whatever followed the head bone now follows the neck, so the stump holds still if the head bone moves
      for(let k=0;k<4;k++)if(nk.J[i*4+k]===HD)nk.J[i*4+k]=2;
      // rim of the stump: torn decay, then blood running down in streaks
      const d=top-y,a=Math.atan2(z,x),streak=noise3(Math.cos(a)*7+11,Math.sin(a)*7+11,.5,seed+4),run=streak>.6?.015+.1*(streak-.6)/.4:.012;
      if(d<.012)nk.rot[i]=Math.max(nk.rot[i],d<.004?.66:.4);else if(d<run)nk.rot[i]=Math.max(nk.rot[i],.5+.12*(1-d/run));
      nk.touch[i]=1;}
    // what's in a neck is painted on the cut by the shader, from where each thing sits: the vertebra with the spinal cord
    // behind it, the windpipe open at the front, the gullet behind that, and the big vessels either side
    W('neck',.25,[0,0,1],{r:.022,depth:.006,kind:'flesh',seed:31});}
  else if(slot==='Head'&&state!=='Intact'){
    // Under the scalp is one inner surface, the skull. In the Destroyed head the shader paints it broken open, from the
    // anatomy map: the thick edge of broken bone, and the brain a centimetre below it, wrinkled, gouged and bloody.
    const hd=get('head'),skull=innerLimb(hd,.0045),scalp=(p,nrm)=>[p[0]-nrm[0]*.0042,p[1]-nrm[1]*.0042,p[2]-nrm[2]*.0042];
    skull.name='skull';for(let i=0;i<skull.P.length/3;i++){skull.rot[i]=.93;skull.COL[i*4]=26;skull.COL[i*4+1]=0;skull.COL[i*4+3]=INNER.skull*17;}
    const open=(t,dir,o)=>{const c=anchor(B,hd,t,dir);hole(hd,c,Object.assign({wall:scalp},o));return c;};
    if(state==='Rotted'){
      open(.72,side([.55,.6,-.3]),{r:.036,seed:29,ax:[0,.4,1],elong:1.7});         // the scalp torn off the skull
      W('head',.5,side([-.3,.2,-1]),{r:.026,depth:.005,kind:'flesh',seed:4});
      W('neck',.45,side([-.7,0,.7]),{r:.034,depth:.009,kind:'flesh',seed:5});
      // torn ear: the top half is gone
      const ear=get('earL');if(ear){const c=[0,0,0];for(let i=0;i<ear.P.length/3;i++)for(let k=0;k<3;k++)c[k]+=ear.P[i*3+k]/(ear.P.length/3);
        cut(ear,(x,y,z)=>y>c[1]-.002+.006*(hash(Math.round(z*400),1,2,3)-.5),.66,0);}
      extra.push(skull);}
    if(state==='Destroyed'){
      // (COLOR.g says this is the broken skull; where it's broken is in the anatomy map, from `breaks`)
      const smash=(t,dir,o,k)=>{const c=open(t,dir,o);headBreaks.push({c,o:Object.assign({},o,{r:o.r*k,seed:o.seed+50})});};
      for(let i=0;i<skull.P.length/3;i++)skull.COL[i*4+1]=255;
      smash(.68,side([.75,.45,-.35]),{r:.07,seed:7,stretch:.2},.74);                // the side of the skull broken open
      smash(.88,side([.2,1,-.2]),{r:.032,seed:9},.72);                              // and a hole in the top
      W('neck',.4,side([.8,0,.4]),{r:.05,depth:.013,kind:'flesh',seed:11});
      // the back of the neck torn down to the spine
      toTheBone(B,get('neck'),.55,[0,0,-1],{r:.03,seed:13},[{name:'neckSpine',A:[0,1.492,-.030],B:[0,1.640,-.018],r:.0105,joint:2}],extra);
      drop.add('earR');extra.push(skull);}}
  if(slot.indexOf('Arm')===0){const F=armFrames(B,s);
    if(state==='Rotted'){
      W('upperArm'+sd,.5,side([.9,0,.4]),{r:.04,depth:.012,kind:'flesh',seed:3,elong:2});
      // a long tear down the forearm to the two forearm bones
      toTheBone(B,get('forearm'+sd),.45,side([.3,0,1]),{r:.04,seed:5,elong:2.6},[
        {name:'radius'+sd,A:F.fo([.012*s,-.006,.007]),B:F.fo([.011*s,-.243,.010]),r:.0070,joint:b+5},
        {name:'ulna'+sd,A:F.fo([-.012*s,.002,-.006]),B:F.fo([-.012*s,-.243,-.008]),r:.0064,joint:b+5}],extra);
      W('upperArm'+sd,.2,side([.1,0,-1]),{r:.032,depth:.008,kind:'flesh',seed:7});
      W('forearm'+sd,.15,side([.2,0,-1]),{r:.03,depth:.008,kind:'flesh',seed:8});
      W('hand'+sd,.4,side([0,0,1]),{r:.018,depth:.003,kind:'bone',seed:9});
      // a missing finger: the pinky ends at its first joint, chewed down to the bone
      drop.add('pinky'+sd+'2');drop.add('pinky'+sd+'3');const pk=get('pinky'+sd+'1');
      if(pk){let lo=1e9,hi=-1e9;for(let i=0;i<pk.P.length/3;i++){lo=Math.min(lo,pk.P[i*3+1]);hi=Math.max(hi,pk.P[i*3+1]);}
        for(let i=0;i<pk.P.length/3;i++){const t=(hi-pk.P[i*3+1])/(hi-lo);if(t>.55)pk.rot[i]=t>.85?.93:.62;}}}
    if(state==='Destroyed'){
      // gone below the elbow, a third of the forearm left, the two forearm bones sticking out
      const cutY=-.09;['hand','index','middle','ring','pinky','thumb'].forEach(n=>{for(const p of parts)if(p.name.indexOf(n+sd)===0)drop.add(p.name);});
      const fa=get('forearm'+sd);
      cut(fa,(x,y,z)=>{const q=F.toFore(x,y,z),a=Math.atan2(q[2],q[0]*s);return q[1]<cutY+.35*q[2]+.032*(fbm(Math.cos(a)*2.4+3,Math.sin(a)*2.4+3,1,seed)-.5)*2+.012*(hash(Math.round(a*7),2,seed,1)-.5);},.68,-.006);
      for(let i=0;i<fa.P.length/3;i++){const q=F.toFore(fa.P[i*3],fa.P[i*3+1],fa.P[i*3+2]),t=ss(q[1]-.35*q[2],cutY+.045,cutY+.005);if(fa.rot[i]<.6&&t>0){fa.rot[i]=Math.max(fa.rot[i],.3+.36*t);fa.touch[i]=1;}}
      extra.push(boneStub('radius'+sd,F.fo([.012*s,cutY+.03,.008]),F.fo([.014*s,cutY-.05,.012]),.0075,b+5,seed,B.DK));
      extra.push(boneStub('ulna'+sd,F.fo([-.012*s,cutY+.03,-.006]),F.fo([-.016*s,cutY-.03,-.009]),.0068,b+5,seed+1,B.DK));
      W('upperArm'+sd,.62,side([.7,0,.7]),{r:.04,depth:.012,kind:'flesh',seed:13,elong:1.8});
      // a gouge in the back of the upper arm, down to the humerus
      toTheBone(B,get('upperArm'+sd),.3,side([-.2,0,-1]),{r:.036,seed:14,elong:2},[{name:'humerus'+sd,A:B.piv[b+3],B:B.piv[b+5],r:.0105,joint:b+3}],extra);}}
  if(slot.indexOf('Leg')===0){
    if(state==='Rotted'){
      // the shin torn open down the bone: tibia in front, the thin fibula beside it
      {const kx=s*.101;toTheBone(B,get('calf'+sd),.42,[0,0,1],{r:.03,seed:3,elong:3.2},[
        {name:'tibia'+sd,A:[kx+.004*s,.495,.011],B:[kx+.006*s,.130,.014],r:.0112,joint:b+1},
        {name:'fibula'+sd,A:[kx+.024*s,.485,-.006],B:[kx+.024*s,.135,-.004],r:.0056,joint:b+1}],extra);}
      W('thigh'+sd,.45,side([.8,0,.6]),{r:.05,depth:.014,kind:'flesh',seed:5,elong:1.8});
      W('calf'+sd,.3,side([-.4,0,-1]),{r:.04,depth:.018,kind:'flesh',seed:7,elong:1.4});
      W('thigh'+sd,.85,[0,0,1],{r:.035,depth:.008,kind:'flesh',seed:8});
      W('foot'+sd,.5,side([.6,1,.3]),{r:.02,depth:.004,kind:'bone',seed:9});
      drop.add('toe5'+sd+'2');const tt=get('toe5'+sd+'1');if(tt){let lo=1e9,hi=-1e9;for(let i=0;i<tt.P.length/3;i++){lo=Math.min(lo,tt.P[i*3+2]);hi=Math.max(hi,tt.P[i*3+2]);}
        for(let i=0;i<tt.P.length/3;i++){const t=(tt.P[i*3+2]-lo)/(hi-lo);if(t>.5)tt.rot[i]=t>.85?.92:.62;}}}
    if(state==='Destroyed'){
      // gone below the knee: a short ragged calf, shin bone and fibula showing. This leg makes a crawler.
      const kx=s*.101,cutY=.385;['foot','toe'].forEach(n=>{for(const p of parts)if(p.name.indexOf(n)===0)drop.add(p.name);});
      const ca=get('calf'+sd);
      cut(ca,(x,y,z)=>{const a=Math.atan2(z,(x-kx)*s);return y<cutY-.55*z+.045*(fbm(Math.cos(a)*2.4+5,Math.sin(a)*2.4+5,2,seed)-.5)*2+.015*(hash(Math.round(a*8),3,seed,1)-.5);},.68,-.008);
      for(let i=0;i<ca.P.length/3;i++){const t=ss(ca.P[i*3+1]+.55*ca.P[i*3+2],cutY+.07,cutY+.01);if(ca.rot[i]<.6&&t>0){ca.rot[i]=Math.max(ca.rot[i],.3+.36*t);ca.touch[i]=1;}}
      extra.push(boneStub('tibia'+sd,[kx+.004*s,cutY+.03,.016],[kx+.006*s,cutY-.075,.022],.011,b+1,seed,B.DK));
      extra.push(boneStub('fibula'+sd,[kx+.028*s,cutY+.03,-.004],[kx+.031*s,cutY-.04,-.002],.006,b+1,seed+1,B.DK));
      W('thigh'+sd,.55,side([.5,0,.85]),{r:.05,depth:.014,kind:'flesh',seed:13,elong:1.8});
      W('thigh'+sd,.35,side([-.3,0,-1]),{r:.04,depth:.012,kind:'flesh',seed:14});}}
  const keep=parts.filter(p=>!drop.has(p.name));keep.forEach(settle);if(state!=='Intact')bloodRun(B,keep);
  const all=keep.concat(extra);all.forEach(p=>{for(let i=0;i<p.P.length/3;i++)p.COL[i*4+2]=Math.round(255*Math.min(1,p.rot[i]));});
  // any vertex still without a normal (the walls of a hole cut in an inner part, such as the broken skull) gets one
  all.forEach(p=>{let NN=null;for(let i=0;i<p.N.length/3;i++){if(Math.hypot(p.N[i*3],p.N[i*3+1],p.N[i*3+2])>.5)continue;NN=NN||normals(p.P,p.I);
    const l=Math.hypot(NN[i*3],NN[i*3+1],NN[i*3+2]);if(l>.5)for(let k=0;k<3;k++)p.N[i*3+k]=NN[i*3+k];else{p.N[i*3]=0;p.N[i*3+1]=1;p.N[i*3+2]=0;}}});
  return{slot,state,name:slot+'_'+state,parts:all,crawler:slot.indexOf('Leg')===0&&state==='Destroyed',tears:torsoTears,breaks:headBreaks};
}

// merge a variant's parts into one primitive's arrays
function merge(v){let nv=0,ni=0;v.parts.forEach(p=>{nv+=p.P.length/3;ni+=p.I.length;});
  const o={P:new Float32Array(nv*3),N:new Float32Array(nv*3),UV:new Float32Array(nv*2),UV2:new Float32Array(nv*2),COL:new Uint8Array(nv*4),J:new Uint8Array(nv*4),W:new Float32Array(nv*4),I:new Uint32Array(ni)};
  let vo=0,io=0;v.parts.forEach(p=>{const n=p.P.length/3;o.P.set(p.P,vo*3);o.N.set(p.N,vo*3);o.UV.set(p.UV,vo*2);o.UV2.set(p.UV2,vo*2);o.COL.set(p.COL,vo*4);o.J.set(p.J,vo*4);o.W.set(p.W,vo*4);
    for(let i=0;i<p.I.length;i++)o.I[io+i]=p.I[i]+vo;io+=p.I.length;vo+=n;});
  o.nv=nv;o.tris=ni/3;return o;}

function buildAll(detail){const B=buildBase(detail),V=[];for(const sl of SLOTS)for(const st of STATES.concat(EXTRA[sl]||[]))V.push(makeVariant(B,sl,st));return{B,V};}
// Blood that has run from the wounds. Every wound vertex can start a stream: it runs down the body (down the limb,
// for an arm or leg) for a random length, and soaks a little way out all round the wound. The amount is baked into
// UV2.y (0 = none, 1 = at the wound); the shader decides what the blood looks like from how long he's been dead.
function bloodRun(B,parts){const src=[];
  for(const p of parts){const sg=segOf(B,p.name),limb=/^(upperArm|forearm|hand|thigh|calf|foot)/.test(p.name)&&sg;let ax=[0,-1,0];if(limb){ax=unit(sub(sg[1],sg[0]));if(ax[1]>0)ax=[-ax[0],-ax[1],-ax[2]];}
    for(let i=0;i<p.P.length/3;i++){if(p.rot[i]<.34)continue;const x=p.P[i*3],y=p.P[i*3+1],z=p.P[i*3+2],h=hash(Math.round(x*900),Math.round(y*900),Math.round(z*900),5);
      // only some points of a wound bleed a stream, and thinly: each one follows the line of the mesh down from where it starts
      const L=h<.84?0:(.05+.26*Math.pow(hash(Math.round(x*700),Math.round(z*700),3,9),1.5))*(limb?1.25:1),w=.0065+.003*hash(Math.round(y*800),Math.round(x*800),7,2);
      src.push([x,y,z,ax[0],ax[1],ax[2],L,w]);}}
  if(!src.length)return;
  for(const p of parts)for(let i=0;i<p.P.length/3;i++){const x=p.P[i*3],y=p.P[i*3+1],z=p.P[i*3+2];let b=0;
    for(const s0 of src){const dx=x-s0[0],dy=y-s0[1],dz=z-s0[2],d2=dx*dx+dy*dy+dz*dz;if(d2>.11)continue;
      if(d2<.00026)b=Math.max(b,.9*(1-Math.sqrt(d2)/.0161)+.05);                              // soaked in round the wound
      const dv=dx*s0[3]+dy*s0[4]+dz*s0[5];if(dv<=0||dv>s0[6])continue;const dh=Math.sqrt(Math.max(0,d2-dv*dv));if(dh>=s0[7])continue;
      b=Math.max(b,(1-(dh/s0[7])*(dh/s0[7]))*(.56+.44*(1-dv/s0[6])));}                         // a stream, thinning toward its end
    p.UV2[i*2+1]=b;}}

// Blood from the neck, for when the head comes off (or the neck is torn): streams running down from the base of the
// neck over the shoulders, chest and back, each following a line of the mesh for a random length. Baked into UV2.x
// on the torso; the shader shows it by how much neck_blood the shambler is given.
function neckBlood(part,DK){const P=part.P,n=P.length/3,S=Math.max(DK<1?5:6,Math.round(56*DK)),rings=Math.floor(n/S)-2;if(rings<4)return;
  let top=rings-1;while(top>0&&P[(top*S)*3+1]>1.5)top--;
  for(let c=0;c<S;c++){const h=hash(c,3,7,11);let L=h<.6?0:.06+.42*Math.pow(hash(c,9,2,5),1.5),run=0;
    for(let j=top;j>=0;j--){const i=j*S+c;if(j<top){const k=(j+1)*S+c;run+=Math.hypot(P[i*3]-P[k*3],P[i*3+1]-P[k*3+1],P[i*3+2]-P[k*3+2]);}
      const collar=.85*(1-ss(run,.0,.022));part.UV2[i*2]=Math.max(collar,run<L?.38+.62*(1-run/L):0);}}   // streams thin out and break up as they run
  for(let j=top+1;j<rings;j++)for(let c=0;c<S;c++)part.UV2[(j*S+c)*2]=.9;}

// the insides sit in the body's own shadow: bake how far under the skin each vertex is into COLOR.r (the shader darkens by it)
function inShadow(part,K){const P=part.P;for(let i=0;i<P.length/3;i++){const d=K.rho(P[i*3+1],Math.atan2(P[i*3],P[i*3+2]))-Math.hypot(P[i*3],P[i*3+2]);
  part.COL[i*4]=Math.max(part.COL[i*4],Math.round(255*Math.min(.8,Math.max(0,(d-.008)*10))));}}
// the insides on their own, for review renders: everything anatomy.js builds, with no skin over it
function anatomyOnly(B){const K=B.K,o={detail:B.DK,shoulder:B.piv[B.BL+3]},full={detail:B.DK,full:true},bones=()=>[...AN.buildRibs(K,o),...AN.buildSternum(K,o),...AN.buildClavicles(K,o),...AN.buildScapulae(K,o),...AN.buildSpine(K,o),...AN.buildPelvis(K,full)];
  const parts=[AN.shell('muscleWall',K,AN.CORE_IN,{detail:B.DK,rot:.6}),...bones()];
  const organs=[AN.shell('cavityLining',K,AN.LINER_IN,{detail:B.DK,rot:.79,inward:true}),...bones(),...AN.buildOrgans(K,o)];
  const fin=ps=>{ps.forEach(p=>{inShadow(p,K);for(let i=0;i<p.P.length/3;i++)p.COL[i*4+2]=Math.round(255*Math.min(1,p.rot[i]));});return ps;};
  return[{slot:'Torso',state:'Skeleton',name:'Torso_Skeleton',parts:fin(parts),crawler:false},{slot:'Torso',state:'Organs',name:'Torso_Organs',parts:fin(organs),crawler:false}];}
module.exports={buildBase,makeVariant,merge,buildAll,anatomyOnly,patchAt,SLOTS,STATES,EXTRA,BREAKS,LIMB_BONES,NECK_CUT};
