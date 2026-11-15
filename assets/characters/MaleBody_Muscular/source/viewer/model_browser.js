(function(root){
const TAU=Math.PI*2,sp=(v,e)=>Math.sign(v)*Math.pow(Math.abs(v),e);
function finish(name,P,I){
  let vol=0;for(let i=0;i<I.length;i+=3){const a=I[i]*3,b=I[i+1]*3,c=I[i+2]*3;
    vol+=P[a]*(P[b+1]*P[c+2]-P[b+2]*P[c+1])-P[a+1]*(P[b]*P[c+2]-P[b+2]*P[c])+P[a+2]*(P[b]*P[c+1]-P[b+1]*P[c]);}
  if(vol<0)for(let i=0;i<I.length;i+=3){const t=I[i+1];I[i+1]=I[i+2];I[i+2]=t;}
  return{name,P:new Float32Array(P),N:normals(P,I),I:new Uint16Array(I)};
}
function normals(P,I){
  const N=new Float32Array(P.length);
  for(let i=0;i<I.length;i+=3){const a=I[i]*3,b=I[i+1]*3,c=I[i+2]*3;
    const ux=P[b]-P[a],uy=P[b+1]-P[a+1],uz=P[b+2]-P[a+2],vx=P[c]-P[a],vy=P[c+1]-P[a+1],vz=P[c+2]-P[a+2];
    const nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;
    for(const k of[a,b,c]){N[k]+=nx;N[k+1]+=ny;N[k+2]+=nz;}}
  for(let i=0;i<N.length;i+=3){const l=Math.hypot(N[i],N[i+1],N[i+2])||1;N[i]/=l;N[i+1]/=l;N[i+2]/=l;}
  return N;
}
function ringAt(R,v){const hi0=R.length-1,asc=R[hi0][0]>R[0][0],mn=Math.min(R[0][0],R[hi0][0]),mx=Math.max(R[0][0],R[hi0][0]);
  if(v<=mn)return{r:asc?R[0]:R[hi0],out:mn-v};if(v>=mx)return{r:asc?R[hi0]:R[0],out:v-mx};
  let lo=0,hi=hi0;while(hi-lo>1){const m=(lo+hi)>>1;if((R[m][0]<=v)===asc)lo=m;else hi=m;}
  const a=R[lo],b=R[hi],f=(v-a[0])/(b[0]-a[0]);return{r:a.map((x,j)=>x+(b[j]-x)*f),out:0};}
function delta(R,a,u,w){const q=ringAt(R,a),r=q.r,du=u-r[1],dw=w-r[2],ex=r[6],
  g=Math.pow(Math.pow(Math.abs(du)/r[3],ex)+Math.pow(Math.abs(dw)/(dw>=0?r[4]:r[5]),ex),1/ex),L=Math.hypot(du,dw);
  return Math.max(g>1e-3?L*(1-1/g):-1,q.out);}
function fillet(part,dfn,k){const P=part.P,N=part.N;
  for(let i=0;i<P.length;i+=3){const d=Math.abs(dfn(P[i],P[i+1],P[i+2]));if(d<k){const o=k*.25*(1-d/k)*(1-d/k);P[i]+=N[i]*o;P[i+1]+=N[i+1]*o;P[i+2]+=N[i+2]*o;}}
  part.N=normals(part.P,part.I);}
function loft(name,rings,o){
  o=o||{};const S=o.seg||24,sub=o.sub||4,xf=o.xf||(p=>p),disp=o.disp,n=rings.length,R=[];
  let e0=2.2;rings=rings.map(r=>{if(r[6])e0=r[6];return[r[0],r[1],r[2],r[3],r[4],r[5],e0];});
  const g=i=>rings[Math.max(0,Math.min(n-1,i))];
  for(let i=0;i<n-1;i++)for(let k=0;k<sub;k++){const t=k/sub,a=g(i-1),b=g(i),c=g(i+1),d=g(i+2);
    R.push(b.map((_,j)=>0.5*(2*b[j]+(-a[j]+c[j])*t+(2*a[j]-5*b[j]+4*c[j]-d[j])*t*t+(-a[j]+3*b[j]-3*c[j]+d[j])*t*t*t)));}
  R.push(rings[n-1]);
  const P=[],I=[],Q=[];
  R.forEach(r=>{const y=r[0],cx=r[1],cz=r[2],rx=Math.max(r[3],.002),rf=Math.max(r[4],.002),rb=Math.max(r[5],.002),ex=2/r[6];
    for(let s=0;s<S;s++){const a=s/S*TAU,c=Math.cos(a),sn=Math.sin(a);
      let x=rx*sp(c,ex),z=(sn>=0?rf:rb)*sp(sn,ex);
      if(disp){const m=disp(y,cx+x,cz+z);x*=m;z*=m;}
      let X=cx+x,Z=cz+z,Y=y;if(o.lab)Q.push(o.lab(y,X,Z));if(o.warp){const w=o.warp(y,X,Z);X=w[0];Z=w[1];if(w.length>2)Y=w[2];}
      P.push(...xf([X,Y,Z]));}});
  for(let j=0;j<R.length-1;j++)for(let s=0;s<S;s++){const a=j*S+s,b=j*S+(s+1)%S,c=a+S,d=b+S;I.push(a,c,b,b,c,d);}
  const L=R.length-1,nb=P.length/3;
  for(const j of[0,L])for(let s=0;s<S;s++)P.push(P[(j*S+s)*3],P[(j*S+s)*3+1],P[(j*S+s)*3+2]);
  const b0=P.length/3;P.push(...xf([R[0][1],R[0][0],R[0][2]]));const t0=b0+1;P.push(...xf([R[L][1],R[L][0],R[L][2]]));
  for(let s=0;s<S;s++){I.push(b0,nb+s,nb+(s+1)%S);I.push(t0,nb+S+(s+1)%S,nb+S+s);}
  const part=finish(name,P,I);part.R=R;
  if(o.nl){const nv=P.length/3,Lb=new Float32Array(nv*4),w=(i,j,s)=>{const a=s/S*TAU-o.nl.a0;Lb[i*4]=Math.cos(a);Lb[i*4+1]=Math.sin(a);Lb[i*4+2]=-R[j][0]/o.nl.l;Lb[i*4+3]=o.nl.toe;};
    for(let j=0;j<R.length;j++)for(let s=0;s<S;s++)w(j*S+s,j,s);
    for(let s=0;s<S;s++){w(nb+s,0,s);w(nb+S+s,L,s);}
    Lb[b0*4+2]=-R[0][0]/o.nl.l;Lb[b0*4+3]=o.nl.toe;Lb[t0*4+2]=-R[L][0]/o.nl.l;Lb[t0*4+3]=o.nl.toe;part.L=Lb;}
  if(o.lab){const Lb=new Float32Array(P.length/3*4),put=(i,q)=>{for(let k=0;k<4;k++)Lb[i*4+k]=q[k];};
    Q.forEach((q,i)=>put(i,q));for(let s=0;s<S;s++){put(nb+s,Q[s]);put(nb+S+s,Q[L*S+s]);}put(b0,[0,0,0,Q[0][3]]);put(t0,[0,0,0,Q[0][3]]);part.L=Lb;}
  return part;
}
function ell(name,c,r,o){
  o=o||{};const xf=o.xf||(p=>p),U=o.u||16,V=o.v||10,P=[],I=[];
  for(let j=0;j<=V;j++){const ph=j/V*Math.PI;for(let i=0;i<U;i++){const th=i/U*TAU;
    P.push(...xf([c[0]+r[0]*Math.sin(ph)*Math.cos(th),c[1]+r[1]*Math.cos(ph),c[2]+r[2]*Math.sin(ph)*Math.sin(th)]));}}
  for(let j=0;j<V;j++)for(let i=0;i<U;i++){const a=j*U+i,b=j*U+(i+1)%U,c2=a+U,d=b+U;I.push(a,c2,b,b,c2,d);}
  return finish(name,P,I);
}
const rotZ=(p,a)=>{const c=Math.cos(a),s=Math.sin(a);return[p[0]*c-p[1]*s,p[0]*s+p[1]*c,p[2]];};
const rotX=(p,a)=>{const c=Math.cos(a),s=Math.sin(a);return[p[0],p[1]*c-p[2]*s,p[1]*s+p[2]*c];};
const rotY=(p,a)=>{const c=Math.cos(a),s=Math.sin(a);return[p[0]*c+p[2]*s,p[1],-p[0]*s+p[2]*c];};
const add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]];
const G=(v,w)=>Math.exp(-(v/w)*(v/w)),band=(y,a,b,f)=>Math.min(1,Math.max(0,(y-a)/f))*Math.min(1,Math.max(0,(b-y)/f));

const SPEC={height:1.80,headDrop:0,shoulder:[.199,1.414,0],elbowLen:.30,wristLen:.26,hip:[.092,.92,0],knee:.51,ankle:.08,armOut:.27,elbowBend:-.22,ankleBlend:.025,hipBlend:.03,armBlend:.022,elbowBlend:.026,neckBlend:.024,thumbBlend:.018,faceMount:{chin:1.557,brow:1.705,hairline:1.765,earY:1.673,earX:.0785,front:.078,neckTop:1.605}};

const PIT={r0:.07,r1:.18,a0:.5,a1:1.1,d0:-.005,d1:.05,amt:.9};
function build(){
  const parts=[],S=SPEC;
  const lean=(part,dfn,k)=>{const P=part.P,N=part.N,e=.0015;for(let i=0;i<P.length;i+=3){const x=P[i],y=P[i+1],z=P[i+2],d=Math.abs(dfn(x,y,z));if(d>=k)continue;
    let gx=dfn(x+e,y,z)-dfn(x-e,y,z),gy=dfn(x,y+e,z)-dfn(x,y-e,z),gz=dfn(x,y,z+e)-dfn(x,y,z-e);const gl=Math.hypot(gx,gy,gz);if(gl<1e-9)continue;
    const w=.5*(1-d/k)*(1-d/k);let nx=N[i]*(1-w)+gx/gl*w,ny=N[i+1]*(1-w)+gy/gl*w,nz=N[i+2]*(1-w)+gz/gl*w;const l=Math.hypot(nx,ny,nz)||1;N[i]=nx/l;N[i+1]=ny/l;N[i+2]=nz/l;}};
  const ss=(v,a,b)=>{const t=Math.min(1,Math.max(0,(v-a)/(b-a)));return t*t*(3-2*t);};
  const torsoDisp=(y,x,z)=>{let m=1;const ax=Math.abs(x);
    if(z>0){const pd=Math.max(0,1-Math.pow((ax-.088)/.105,2)-Math.pow((y-1.325)/.09,2));
      m+=.175*ss(ax,.005,.028)*(1-ss(ax,.135,.195))*ss(y,1.246,1.298)*(1-ss(y,1.335,1.435))*(.70+.30*pd);
      m-=.05*G(x,.009)*band(y,1.27,1.42,.03);
      m-=.09*G(x,.015)*band(y,1.0,1.26,.05);
      m-=.12*G(x,.012)*G(y-1.075,.012);
      for(const yy of[1.135,1.195,1.25])m-=.035*G(y-yy,.008)*Math.min(1,Math.max(0,(.075-ax)/.02));}
    else{m-=.12*G(x,.02)*band(y,1.0,1.47,.05);m+=.035*G(ax-.036,.022)*band(y,1.0,1.30,.07);m-=.05*G(ax-.048,.012)*G(y-1.025,.012);
      m+=.095*G(ax-.098,.044)*G(y-1.365,.048);
      m+=.09*G(ax-(.075+.34*(y-1.10)),.038)*band(y,1.10,1.37,.06);
      m+=.055*G(ax-.034,.026)*band(y,1.30,1.47,.05);
      m-=.05*G(ax-.062,.014)*band(y,1.30,1.42,.04);}
    return m;};
  const gluteOff=(y,X)=>{const ax=Math.abs(X),dy=(y-.924)/(y<.924?.064:.140),dx=(ax-.082)/(ax<.082?.086:.100),d=Math.sqrt(dx*dx+dy*dy),e=Math.pow(d,1.7);
    return(d<1?.023*(1-e*e*(3-2*e)):0)-.016*G(X,.010)*band(y,.86,1.0,.035);};
  const gluteWarp=(y,X,Z)=>{if(Z>=0){const dx=X/.054,dy=(y-.900)/(y<.900?.050:.066),d=Math.sqrt(dx*dx+dy*dy);return d<1?[X,Z+.033*(1-d*d*(3-2*d))*ss(Z,0,.03)]:[X,Z];}
    return[X,Z-gluteOff(y,X)*ss(-Z,0,.05),y+.014*G(X,.022)*ss(.905-y,0,.03)*ss(-Z,0,.04)];};
  const torsoP=loft('torso',[
    [.860,0,.006,.045,.034,.038,2.2],[.876,0,.004,.156,.082,.102,2.5],[.95,0,.006,.172,.098,.108,2.6],[1.01,0,.008,.165,.100,.092],
    [1.08,0,.008,.143,.094,.079],[1.16,0,.004,.146,.098,.088],[1.24,0,0,.168,.106,.102,2.5],[1.32,0,-.006,.188,.111,.116,2.6],
    [1.39,0,-.010,.192,.105,.114],[1.43,0,-.012,.186,.090,.104,2.4],[1.458,0,-.012,.166,.076,.097],[1.494,0,-.013,.114,.062,.086,2.2],[1.538,0,-.008,.046,.042,.048,2.0]],
    {seg:56,sub:8,disp:torsoDisp,warp:gluteWarp});parts.push(torsoP);
  const neckP=loft('neck',[[1.47,0,-.014,.080,.060,.072,2.0],[1.52,0,-.010,.062,.055,.063],[1.585,0,.001,.054,.053,.057],[1.655,0,.006,.050,.050,.056]],{seg:20});parts.push(neckP);
  fillet(neckP,(x,y,z)=>delta(torsoP.R,y,x,z),S.neckBlend);fillet(torsoP,(x,y,z)=>delta(neckP.R,y,x,z),S.neckBlend);
  const hd=p=>[p[0],p[1]-S.headDrop,p[2]];
  const headDisp=(y,x,z)=>1-.030*G(Math.abs(x)-.074,.02)*G(y-1.722,.022)*G(z-.035,.03);
  const headWarp=(y,X,Z)=>[X*(1-.18*ss(Z,-.005,.08)*(1-ss(y,1.60,1.68))),Z];
  const headP=loft('head',[
    [1.557,0,.042,.007,.008,.008,2.2],[1.578,0,.032,.040,.040,.040,2.2],[1.605,0,.020,.056,.056,.060,2.2],[1.640,0,.010,.066,.066,.084,2.3],
    [1.685,0,.004,.073,.074,.095,2.3],[1.730,0,0,.077,.080,.100],[1.770,0,-.002,.068,.068,.090,2.2],[1.794,0,-.006,.040,.038,.056,2.0],[1.800,0,-.008,.012,.012,.016]],
    {seg:32,sub:5,disp:headDisp,warp:headWarp,xf:hd});parts.push(headP);
  lean(headP,(x,y,z)=>delta(neckP.R,y,x,z),.02);lean(neckP,(x,y,z)=>delta(headP.R,y,x,z),.02);
  const earBowl=(y,X,Z)=>X>0?G(Z+.002,.009)*G(y-.003,.019):0;
  const earWarp=(y,X,Z)=>[X>0?X-.0055*earBowl(y,X,Z)+.002*ss(-Z,.008,.02)*G(y-.012,.022):X,Z];
  for(const s of[1,-1])parts.push(loft('ear'+(s>0?'L':'R'),[[-.033,0,.003,.004,.004,.004,2.0],[-.024,0,.003,.0065,.009,.009,2.1],[-.008,0,.001,.008,.012,.014,2.2],[.010,0,-.001,.0085,.014,.021],[.025,0,-.002,.008,.012,.019],[.033,0,-.002,.005,.005,.009,2.0]],
    {seg:6,sub:2,warp:earWarp,lab:(y,X,Z)=>[earBowl(y,X,Z),0,0,2],xf:p=>{const q=add(rotZ(rotX(rotY(p,-.32),-.12),-.08),[.0785,1.673,-.010]);return hd([s*q[0],q[1],q[2]]);}}));
  const armD=[];
  for(const s of[1,-1]){const n=s>0?'L':'R';
    const sh=[s*S.shoulder[0],S.shoulder[1],-.008],ao=s*S.armOut;
    const up=p=>add(rotZ(p,ao),sh),fo=p=>up(add(rotX(p,S.elbowBend),[0,-S.elbowLen,0])),ha=p=>fo(add(rotX(rotY(p,-s*.55),-.1),[0,-S.wristLen,0]));
    const armP=loft('upperArm'+n,[[.056,-s*.018,0,.026,.034,.034,2.1],[.036,-s*.010,0,.054,.064,.064],[-.02,s*.005,0,.073,.077,.075],[-.085,s*.005,0,.063,.067,.067],[-.115,s*.002,.002,.056,.061,.060],[-.16,0,.006,.058,.071,.063],[-.225,0,.003,.048,.054,.051],[-.305,0,0,.036,.039,.039]],{xf:up,seg:28});parts.push(armP);
    const foreP=loft('forearm'+n,[[.03,0,0,.033,.035,.037,2.1],[-.05,0,0,.051,.049,.052],[-.12,0,0,.043,.042,.043],[-.20,0,0,.029,.031,.031],[-.265,0,0,.024,.028,.028]],{xf:fo});parts.push(foreP);
    const iup=(x,y,z)=>rotZ([x-sh[0],y-sh[1],z-sh[2]],-ao),dArm=(x,y,z)=>{const q=iup(x,y,z);return delta(armP.R,q[1],q[0],q[2]);},
      dFore=(x,y,z)=>{const q=iup(x,y,z),q2=rotX([q[0],q[1]+S.elbowLen,q[2]],-S.elbowBend);return delta(foreP.R,q2[1],q2[0],q2[2]);};
    fillet(armP,(x,y,z)=>delta(torsoP.R,y,x,z),S.armBlend);fillet(armP,dFore,S.elbowBlend);fillet(foreP,dArm,S.elbowBlend);armD.push(dArm);
    const handP=loft('hand'+n,[[.016,0,0,.020,.024,.024,2.3],[0,0,0,.0255,.0295,.0295,2.3],[-.022,0,.002,.019,.036,.032,2.8],[-.055,0,.004,.015,.044,.040,3.2],[-.09,0,.004,.013,.043,.040,3.4],[-.104,0,.004,.0115,.042,.039,3.2],[-.113,0,.004,.006,.038,.036,2.6]],{xf:ha,seg:20,lab:(y,X,Z)=>[Z,y,Math.max(-1,Math.min(1,s*X/.006)),s>0?4:5]});parts.push(handP);
    const chain=(name,lens,rw,angs,rot,post,nd,bed,ax,i0)=>{let j=[0,0,0];const rt=rw*.92;lens.forEach((l,i)=>{const jj=j,aa=angs[i],k=1-i*.07,q=(y,f,e)=>[y,0,0,rt*k*f,rw*k*f,rw*k*f,e];
      const d=rw*k*.7,rings=i===lens.length-1?[q(d,.5,2.0),q(.002,1,2.4),q(-l*.55,.95,2.4),q(-l*.86,.86,2.2),q(-l,.52,2.0)]:[q(d,.5,2.0),q(.002,1,2.4),q(-l*.5,.93,2.4),q(-l,.98,2.4),q(-l-d,.5,2.0)];
      const tip=i===lens.length-1,fp=loft(name+n+(i+1+(i0||0)),rings,{seg:tip?16:10,sub:tip?3:2,xf:p=>post(add(rot(p,aa),jj)),nl:tip?{a0:Math.atan2(nd[1],nd[0]),l:l,toe:bed?1:0}:null});
      if(ax){const o=post(jj),e=post(add(jj,ax));fp.jp=o;fp.jh=[e[0]-o[0],e[1]-o[1],e[2]-o[2]];}parts.push(fp);
      j=add(j,rot([0,-l,0],aa));});};
    const curl=(p,a)=>rotZ(p,-s*a);
    [['index',[-.098,.036],[.036,.022,.020],.0104,[.15,.45,.65],-.06],['middle',[-.102,.014],[.040,.025,.021],.0108,[.20,.55,.80],0],
     ['ring',[-.099,-.008],[.037,.023,.020],.0102,[.26,.66,.94],.05],['pinky',[-.091,-.029],[.029,.017,.018],.0090,[.32,.77,1.07],.11]]
      .forEach(f=>chain(f[0],f[2],f[3],f[4],curl,p=>ha(add(rotX(p,f[5]),[-s*.001,f[1][0],f[1][1]])),[s,0],0,[0,0,-s]));
    // thumb: a metacarpal segment rooted near the wrist carries the thumb's base muscle, then two phalanges
    const tT=[-s*.007,-.064,.064],mA=-(.71),mBz=.028-tT[2],mB=[0,-mBz/Math.tan(-mA),mBz],mL=Math.hypot(mB[1],mB[2]);
    const tpost=p=>ha(add(rotZ(p,-s*.30),tT));
    const metaP=loft('thumb'+n+'1',[[.012,0,0,.010,.012,.012,2.0],[0,0,0,.0165,.019,.020,2.2],[-mL*.4,0,0,.0165,.0175,.019],[-mL*.8,0,0,.014,.0145,.015],[-mL,0,0,.0128,.013,.013],[-mL-.0085,0,0,.007,.007,.007,2.0]],
      {seg:10,sub:2,xf:p=>tpost(add(rotX(p,mA),mB))});
    {const o=tpost(mB),e=tpost(add(mB,[1,0,0]));metaP.jp=o;metaP.jh=[e[0]-o[0],e[1]-o[1],e[2]-o[2]];}
    parts.push(metaP);
    chain('thumb',[.032,.028],.0122,[-(.52),-(.34)],rotX,tpost,[0,1],0,[1,0,0],1);
    const ihand=(x,y,z)=>{const q=iup(x,y,z),q2=rotX([q[0],q[1]+S.elbowLen,q[2]],-S.elbowBend);return rotY(rotX([q2[0],q2[1]+S.wristLen,q2[2]],.1),s*.55);},
      dHand=(x,y,z)=>{const h=ihand(x,y,z);return delta(handP.R,h[1],h[0],h[2]);},
      dMeta=(x,y,z)=>{const h=ihand(x,y,z),pl=rotZ([h[0]-tT[0],h[1]-tT[1],h[2]-tT[2]],s*.30),m=rotX([pl[0]-mB[0],pl[1]-mB[1],pl[2]-mB[2]],-mA);return delta(metaP.R,m[1],m[0],m[2]);};
    fillet(metaP,dHand,S.thumbBlend);fillet(handP,dMeta,S.thumbBlend);
    // make the shading agree across the join: near the seam each surface leans its normals toward the other's
    lean(metaP,dHand,S.thumbBlend*1.2);lean(handP,dMeta,S.thumbBlend*1.2);
    const lx=x=>s*x;
    const thighP=loft('thigh'+n,[[.96,lx(.090),.004,.080,.086,.086,2.2],[.88,lx(.096),.006,.092,.100,.090],[.78,lx(.099),.012,.092,.106,.100],[.67,lx(.101),.014,.080,.094,.078],[.57,lx(.101),.009,.062,.068,.060],[.515,lx(.100),.004,.050,.060,.051],[.49,lx(.100),.002,.049,.055,.050]],{seg:28});parts.push(thighP);
    fillet(thighP,(x,y,z)=>delta(torsoP.R,y,x,z+(z<0?gluteOff(y,x):0)),S.hipBlend);
    const calfP=loft('calf'+n,[[.525,lx(.100),.002,.049,.054,.050,2.2],[.46,lx(.101),-.004,.055,.047,.068],[.39,lx(.101),-.008,.064,.044,.088],[.30,lx(.103),-.004,.047,.040,.060],[.18,lx(.104),0,.034,.034,.040],[.115,lx(.105),0,.030,.032,.036],[.085,lx(.105),.002,.0305,.039,.040],[.065,lx(.105),.004,.032,.052,.052],[.045,lx(.105),.008,.0325,.064,.062]],{seg:28,sub:6,disp:(y,X,Z)=>{const dx=(X-lx(.105))*s,h=Math.hypot(dx,Z)||1,wm=Math.pow(Math.max(0,(-dx*.97+Z*.1)/h),3),wl=Math.pow(Math.max(0,(dx*.92-Z*.38)/h),3);const lo=Math.min(1,Math.max(0,(y-.046)/.018));return 1+lo*(.27*wm*G(y-.084,.024)+.25*wl*G(y-.072,.022));}});parts.push(calfP);
    const fx=p=>add(rotY(p,s*.14),[lx(.105),0,0]);
    const sm=v=>{v=Math.min(1,Math.max(0,v));return v*v*(3-2*v);};
    const archWarp=(t,X,Z)=>{const at=sm(1-Math.abs(t-.05)/.08),md=sm((-s*X+.005)/.04),lf=sm((.07-Z)/.066),k=at*md*lf;return[X+s*.012*k,Z+.011*k];};
    const footP=loft('foot'+n,[[-.062,0,.031,.003,.004,.004,2.0],[-.060,0,.031,.010,.012,.012,2.0],[-.055,0,.032,.018,.022,.023,2.0],[-.046,0,.034,.025,.031,.032,2.0],[-.030,0,.037,.030,.042,.037,2.05],[-.005,0,.040,.033,.052,.040,2.1],[.04,s*.002,.039,.039,.046,.033,2.2],[.09,s*.004,.029,.047,.032,.027,2.25],[.125,s*.005,.019,.050,.019,.019,2.3],[.146,s*.005,.013,.046,.011,.013,2.25],[.153,s*.005,.010,.041,.006,.009,2.15]],
      {seg:32,sub:4,warp:archWarp,xf:p=>fx([p[0],p[2],p[1]]),lab:(t,X,Z)=>[s*X,t,sm((Z-.55*(.085-(t-.04)*.56))/.006),s>0?6:7]});parts.push(footP);
    const FK=S.ankleBlend;
    fillet(calfP,(x,y,z)=>{const q=rotY([x-lx(.105),y,z],-s*.14);return delta(footP.R,q[2],q[0],q[1]);},FK);
    fillet(footP,(x,y,z)=>delta(calfP.R,y,x,z),FK);
    const bend=(p,a)=>rotZ(p,a);
    [['toe1',-.033,.142,[.032,.028],.0135],['toe2',-.011,.148,[.028,.022],.0088],['toe3',.006,.143,[.025,.020],.0083],['toe4',.021,.134,[.022,.017],.0079],['toe5',.035,.121,[.018,.014],.0074]]
      .forEach(t=>chain(t[0],t[3],t[4],[-.20,.0],bend,p=>fx([p[2]+s*t[1]+s*.005,p[0]+Math.max(t[4]*.98,.0105),-p[1]+t[2]]),[1,0],1,[0,0,1]));
  }
  fillet(torsoP,(x,y,z)=>Math.min(Math.abs(armD[0](x,y,z)),Math.abs(armD[1](x,y,z))),S.armBlend);
  const tR=parts.filter(p=>p.name.indexOf('thigh')===0).map(p=>p.R);
  fillet(torsoP,(x,y,z)=>{const zz=z+(z<0?gluteOff(y,x):0);return Math.min(Math.abs(delta(tR[0],y,x,zz)),Math.abs(delta(tR[1],y,x,zz)));},S.hipBlend);
  // armpit shade: the patch of flank the arm rests against, and the patch of arm resting against it, carry a shadow value that shows once the arm lifts away
  parts.forEach(p=>{const m=/^upperArm([LR])$/.exec(p.name),tor=p.name==='torso';if(!m&&!tor)return;const n=p.P.length/3,L=new Float32Array(n*4);
    for(let i=0;i<n;i++){const x=p.P[i*3],y=p.P[i*3+1],z=p.P[i*3+2],k=m?(m[1]==='L'?0:1):(x>0?0:1),s=k?-1:1,ao=s*S.armOut;
      const vx=x-s*S.shoulder[0],vy=y-S.shoulder[1],vz=z+.008,r=Math.hypot(vx,vy,vz)||1e-9,al=Math.acos(Math.max(-1,Math.min(1,(vx*Math.sin(ao)-vy*Math.cos(ao))/r)));
      const gate=(1-ss(r,PIT.r0,PIT.r1))*(1-ss(al,PIT.a0,PIT.a1)),d=m?delta(torsoP.R,y,x,z):armD[k](x,y,z);
      L[i*4]=PIT.amt*gate*(1-ss(d,PIT.d0,PIT.d1));L[i*4+3]=m?2:3;}
    p.L=L;});
  return parts;
}
root.MaleBody1={name:'MaleBody_Muscular',SPEC,build};
})(window);
