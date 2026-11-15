(function(root){
function makeRig(parts,S){
  const ss=(v,a,b)=>{const t=Math.min(1,Math.max(0,(v-a)/(b-a)));return t*t*(3-2*t);};
  const rZ=(p,a)=>{const c=Math.cos(a),s=Math.sin(a);return[p[0]*c-p[1]*s,p[0]*s+p[1]*c,p[2]];};
  const rX=(p,a)=>{const c=Math.cos(a),s=Math.sin(a);return[p[0],p[1]*c-p[2]*s,p[1]*s+p[2]*c];};
  const rY=(p,a)=>{const c=Math.cos(a),s=Math.sin(a);return[p[0]*c+p[2]*s,p[1],-p[0]*s+p[2]*c];};
  const add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]],sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],
    unit=v=>{const l=Math.hypot(v[0],v[1],v[2])||1;return[v[0]/l,v[1]/l,v[2]/l];},cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
  // bones: 0 hips, 1 chest, 2 head, then per side (L base 3, R base 11):
  // +0 thigh +1 calf +2 foot +3 upper arm +4 upper-arm roll +5 forearm +6 forearm roll +7 hand
  // bones: 0 hips, 1 chest, 2 neck, 3/4 clavicles (L/R), then per side: thigh calf foot arm armRoll forearm forearmRoll hand; then head, then fingers
  const piv=[[0,.92,0],[0,1.12,0],[0,1.47,-.012],[.03,1.45,.01],[-.03,1.45,.01]],par=[-1,0,1,1,1],axis=[],side={},AX={},BL=5,BR=13;
  for(const s of[1,-1]){const b=piv.length,sh=[s*S.shoulder[0],S.shoulder[1],-.008],ao=s*S.armOut;
    const up=p=>add(rZ(p,ao),sh),el=up([0,-S.elbowLen,0]),wr=up(add(rX([0,-S.wristLen,0],S.elbowBend),[0,-S.elbowLen,0]));
    piv.push([s*S.hip[0],S.hip[1],0],[s*.1,S.knee,.003],[s*.105,S.ankle,0],sh,el,el,wr,wr);par.push(0,b,b+1,s>0?3:4,b+3,b+4,b+5,b+6);
    axis[b+4]=unit(sub(el,sh));axis[b+6]=unit(sub(wr,el));
    const D=v=>rZ(rX(rX(rY(v,-s*.55),-.1),S.elbowBend),ao),n=unit(D([-s,0,0])),d=unit(D([0,-1,0]));
    AX[b]={n,d,h:unit(cross(d,n)),tu:unit(D([0,0,1])),tv:unit(D([0,1,0])),fu:rY([s,0,0],s*.14),fv:rY([0,0,1],s*.14)};
    side[s>0?'L':'R']={b,s,q:p=>rZ([p[0]-sh[0],p[1]-sh[1],p[2]-sh[2]],-ao)};}
  // finger and thumb bones, read from the joint data the model records on each segment
  const HD=piv.length;piv.push([0,1.585,-.005]);par.push(2);
  const FB={},hinge=[],boneOf=new Map();
  parts.forEach(p=>{if(!p.jp)return;const m=/^(.*?)([LR])(\d*)$/.exec(p.name),base=m[1],b=side[m[2]].b,k=+m[3],i=piv.length;
    const toe=base.indexOf('toe')===0;FB[b]=FB[b]||{};const arr=FB[b][base]=FB[b][base]||[];
    piv.push(p.jp);par.push(k===1?(toe?b+2:b+7):arr[k-2]);hinge[i]=unit(p.jh);arr.push(i);boneOf.set(p,i);});
  for(const b of[BL,BR]){const t=FB[b].thumb,md=unit(sub(piv[t[1]],piv[t[0]]));AX[b].u=unit(cross(md,AX[b].n));AX[b].m=md;}
  // shoulder: the upper arm follows the arm bone by how far a point sits from the arm's own axis, measured as an angle at the joint.
  // The weight falls off evenly all the way round, so no part of the cap overtakes another however far the arm swings.
  const A0=.5,A1=3.1,R0=.015,R1=.05;
  const shF=(sd,x,y,z)=>{const pv=piv[sd.b+3],d=axis[sd.b+4],vx=x-pv[0],vy=y-pv[1],vz=z-pv[2],l=Math.hypot(vx,vy,vz)||1e-9,al=Math.acos(Math.max(-1,Math.min(1,(vx*d[0]+vy*d[1]+vz*d[2])/l)));
    const f=1-Math.min(1,Math.max(0,(al-A0)/(A1-A0)));return[.5+(f-.5)*ss(l,R0,R1),ss(Math.abs(x),.085,.18)*ss(y,1.32,1.41)];};
  const NB=piv.length,skin=parts.map(p=>{const n=p.P.length/3,A=new Uint8Array(n),B=new Uint8Array(n),W=new Float32Array(n),TW=new Int8Array(n).fill(-1),SC=new Uint8Array(n),WA=new Float32Array(n),WC=new Float32Array(n);
    const m=/^(.*?)([LR])(\d*)$/.exec(p.name),base=m?m[1]:p.name,sd=m?side[m[2]]:null,b=sd?sd.b:0;
    if(boneOf.has(p)){const bi=boneOf.get(p);A.fill(bi);B.fill(bi);
      if(base==='thumb'&&+m[3]===1){const o=piv[bi],e=piv[FB[b].thumb[1]],dv=sub(e,o),ll=dv[0]*dv[0]+dv[1]*dv[1]+dv[2]*dv[2];A.fill(b+7);
        for(let i=0;i<n;i++){const t=((p.P[i*3]-o[0])*dv[0]+(p.P[i*3+1]-o[1])*dv[1]+(p.P[i*3+2]-o[2])*dv[2])/ll;W[i]=ss(t,-.05,.7);}}
      return{A,B,W,TW,SC,WA,WC,P0:new Float32Array(p.P),N0:new Float32Array(p.N)};}
    for(let i=0;i<n;i++){const x=p.P[i*3],y=p.P[i*3+1],z=p.P[i*3+2];let a=0,c=0,w=0;
      if(base==='torso'){const ax=Math.abs(x);
        if(y>1.32&&ax>.085){a=1;c=x>0?3:4;w=ss(ax,.085,.18)*ss(y,1.32,1.41);}
        else if(y>1.455){a=1;c=2;w=ss(y,1.47,1.535)*(1-ss(ax,.06,.085));}else{a=0;c=1;w=ss(y,1.02,1.28);}}
      else if(base==='neck'){if(y<1.53){a=1;c=2;w=ss(y,1.475,1.525);}else{a=2;c=HD;w=ss(y,1.535,1.585);}}
      else if(base==='head'||base==='ear'){a=HD;c=HD;w=0;}
      else if(base==='thigh'){if(y>.7){a=0;c=b;w=1-ss(y,.87,.97);}else{a=b;c=b+1;w=1-ss(y,.46,.56);}}
      else if(base==='calf'){if(y>.3){a=b;c=b+1;w=1-ss(y,.46,.56);}else{a=b+1;c=b+2;w=1-ss(y,.06,.13);}}
      else if(base==='foot'||base.indexOf('toe')===0){a=b+1;c=b+2;w=1-ss(y,.06,.13);}
      else{const q=sd.q([x,y,z]),q2=rX([q[0],q[1]+S.elbowLen,q[2]],-S.elbowBend),we=1-ss(q[1],-.35,-.25),wh=1-ss(q2[1],-.285,-.235);
        if(base==='upperArm'){
          if(q[1]>-.25){const f=shF(sd,x,y,z);SC[i]=b;WA[i]=f[0];WC[i]=1-(1-f[1])*(1-f[0]);a=b+3;c=b+3;w=Math.max(0,(-.05-q[1])/.2);if(q[1]<-.05)TW[i]=b+4;}
          else{a=b+4;c=b+5;w=we;}}
        else if(base==='forearm'){
          if(q2[1]>-.055){a=b+4;c=b+5;w=we;}
          else if(q2[1]>-.235){a=b+5;c=b+5;w=(-.055-q2[1])/.18;TW[i]=b+6;}
          else{a=b+6;c=b+7;w=wh;}}
        else{a=b+6;c=b+7;w=wh;}}
      A[i]=a;B[i]=c;W[i]=w;}
    return{A,B,W,TW,SC,WA,WC,P0:new Float32Array(p.P),N0:new Float32Array(p.N)};});
  parts.forEach((p,k)=>{p.P0=skin[k].P0;});
  // armpit: wherever the posed arm and the torso meet, both surfaces swell slightly toward each other so they join on a curve instead of a hard line.
  // Only the extra over the rest pose is added, so the rest pose is untouched.
  const FK=.07,FA=.3;
  const ringAt=(R,v)=>{const hi0=R.length-1,asc=R[hi0][0]>R[0][0],mn=Math.min(R[0][0],R[hi0][0]),mx=Math.max(R[0][0],R[hi0][0]);
    if(v<=mn)return{r:asc?R[0]:R[hi0],out:mn-v};if(v>=mx)return{r:asc?R[hi0]:R[0],out:v-mx};
    let lo=0,hi=hi0;while(hi-lo>1){const m=(lo+hi)>>1;if((R[m][0]<=v)===asc)lo=m;else hi=m;}
    const a=R[lo],b=R[hi],f=(v-a[0])/(b[0]-a[0]);return{r:a.map((x,j)=>x+(b[j]-x)*f),out:0};};
  const dist=(R,a,u,w)=>{const q=ringAt(R,a),r=q.r,du=u-r[1],dw=w-r[2],ex=r[6],
    g=Math.pow(Math.pow(Math.abs(du)/r[3],ex)+Math.pow(Math.abs(dw)/(dw>=0?r[4]:r[5]),ex),1/ex),L=Math.hypot(du,dw);return Math.max(g>1e-3?L*(1-1/g):-1,q.out);};
  const sw=(d,k)=>{d=Math.abs(d);return d<k?k*.25*(1-d/k)*(1-d/k):0;},KB=S.armBlend,swell=d=>sw(d,KB),swp=(d,t)=>{const a=sw(d,KB);return a+(sw(d,FK)*FA*4-a)*t;};
  const torsoP=parts.find(p=>p.name==='torso'),pits=[];
  for(const key of['L','R']){const sd=side[key],armP=parts.find(p=>p.name==='upperArm'+key),pv=piv[sd.b+3],d=axis[sd.b+4],arm=[],tor=[];
    const zone=(x,y,z)=>{const vx=x-pv[0],vy=y-pv[1],vz=z-pv[2],l=Math.hypot(vx,vy,vz)||1e-9,al=Math.acos(Math.max(-1,Math.min(1,(vx*d[0]+vy*d[1]+vz*d[2])/l)));return(1-ss(l,.2,.27))*(1-ss(al,.9,1.4));};
    for(let i=0;i<armP.P.length/3;i++){const x=armP.P[i*3],y=armP.P[i*3+1],z=armP.P[i*3+2],g=zone(x,y,z);if(g>0)arm.push(i,g,swell(dist(torsoP.R,y,x,z)));}
    for(let i=0;i<torsoP.P.length/3;i++){const x=torsoP.P[i*3],y=torsoP.P[i*3+1],z=torsoP.P[i*3+2];if(x*sd.s<.1||y>1.42)continue;const g=zone(x,y,z)*(1-ss(y,1.36,1.42));
      if(g>0){const q=sd.q([x,y,z]);tor.push(i,g,swell(dist(armP.R,q[1],q[0],q[2])));}}
    pits.push({sd,armP,arm,tor});}
  const Rm=new Array(NB),Tm=new Array(NB),Rs=new Array(NB),Ts=new Array(NB),ID=[1,0,0,0,1,0,0,0,1],
    mul=(a,b)=>{const o=new Array(9);for(let i=0;i<3;i++)for(let j=0;j<3;j++)o[i*3+j]=a[i*3]*b[j]+a[i*3+1]*b[3+j]+a[i*3+2]*b[6+j];return o;},
    app=(m,v)=>[m[0]*v[0]+m[1]*v[1]+m[2]*v[2],m[3]*v[0]+m[4]*v[1]+m[5]*v[2],m[6]*v[0]+m[7]*v[1]+m[8]*v[2]],
    Rx=a=>{const c=Math.cos(a),s=Math.sin(a);return[1,0,0,0,c,-s,0,s,c];},Ry=a=>{const c=Math.cos(a),s=Math.sin(a);return[c,0,s,0,1,0,-s,0,c];},Rz=a=>{const c=Math.cos(a),s=Math.sin(a);return[c,-s,0,s,c,0,0,0,1];},
    Ra=(u,a)=>{const c=Math.cos(a),s=Math.sin(a),t=1-c,x=u[0],y=u[1],z=u[2];return[c+t*x*x,t*x*y-s*z,t*x*z+s*y,t*x*y+s*z,c+t*y*y,t*y*z-s*x,t*x*z-s*y,t*y*z+s*x,c+t*z*z];};
  // o: {L:[local 3x3 per bone], T:{bone:[x,y,z]}, tw:{rollBone:angle}, cs:[sx,sy,sz] chest skin scale, ground:bool}
  const tr=m=>[m[0],m[3],m[6],m[1],m[4],m[7],m[2],m[5],m[8]];
  // raise a collarbone by C while keeping the arm's own direction as given
  const girdle=(L,b,C,arm)=>{L[b===BL?3:4]=C;L[b+3]=mul(mul(tr(C),arm),L[b+3]||ID);};
  const LA=new Array(NB),LG=new Float32Array(NB),LT=new Array(NB),Z3=[0,0,0];
  function apply(o){const L=o.L,T=o.T||{},tw=o.tw||{};
    for(let i=0;i<NB;i++){const p=piv[i],l=axis[i]?Ra(axis[i],tw[i]||0):(L[i]||ID),lp=app(l,p),tl=T[i]||Z3,lt=[p[0]-lp[0]+tl[0],p[1]-lp[1]+tl[1],p[2]-lp[2]+tl[2]];
      {const c=Math.max(-1,Math.min(1,(l[0]+l[4]+l[8]-1)/2)),g=Math.acos(c),ax=[l[7]-l[5],l[2]-l[6],l[3]-l[1]],al=Math.hypot(ax[0],ax[1],ax[2]);LG[i]=al>1e-9?g:0;LA[i]=al>1e-9?[ax[0]/al,ax[1]/al,ax[2]/al]:[1,0,0];LT[i]=tl;}
      if(par[i]<0){Rm[i]=l;Tm[i]=lt;}else{const pr=Rm[par[i]];Rm[i]=mul(pr,l);Tm[i]=add(app(pr,lt),Tm[par[i]]);}}
    if(o.ground){let lo=1e9;for(const b of[BL,BR]){const y=app(Rm[b+1],piv[b+2])[1]+Tm[b+1][1];if(y<lo)lo=y;}const dy=S.ankle-lo;for(let i=0;i<NB;i++)Tm[i][1]+=dy;}
    for(let i=0;i<NB;i++){Rs[i]=Rm[i];Ts[i]=Tm[i];}
    if(o.cs){const sc=[o.cs[0],0,0,0,o.cs[1],0,0,0,o.cs[2]],p=piv[1],sp=app(sc,p);Rs[1]=mul(Rm[1],sc);Ts[1]=add(app(Rm[1],[p[0]-sp[0],p[1]-sp[1],p[2]-sp[2]]),Tm[1]);}
    parts.forEach((p,k)=>{const s=skin[k],P=p.P,N=p.N,P0=s.P0,N0=s.N0,n=P.length/3;
      for(let i=0;i<n;i++){const j=i*3,t=s.TW[i];let x=P0[j],y=P0[j+1],z=P0[j+2],nx=N0[j],ny=N0[j+1],nz=N0[j+2];
        if(s.SC[i]){const b=s.SC[i],wa=s.WA[i],wc=s.WC[i];
          if(t>=0){const ang=s.W[i]*(tw[t]||0);if(ang){const m=Ra(axis[t],ang),pv=piv[t],dx=x-pv[0],dy=y-pv[1],dz=z-pv[2];
            x=pv[0]+m[0]*dx+m[1]*dy+m[2]*dz;y=pv[1]+m[3]*dx+m[4]*dy+m[5]*dz;z=pv[2]+m[6]*dx+m[7]*dy+m[8]*dz;
            const ux=m[0]*nx+m[1]*ny+m[2]*nz,uy=m[3]*nx+m[4]*ny+m[5]*nz,uz=m[6]*nx+m[7]*ny+m[8]*nz;nx=ux;ny=uy;nz=uz;}}
          for(let lv=0;lv<2;lv++){const bi=lv?(b===BL?3:4):b+3,w=lv?wc:wa;if(w>0&&LG[bi]){const m=Ra(LA[bi],w*LG[bi]),pv=piv[bi],dx=x-pv[0],dy=y-pv[1],dz=z-pv[2];
            x=pv[0]+m[0]*dx+m[1]*dy+m[2]*dz;y=pv[1]+m[3]*dx+m[4]*dy+m[5]*dz;z=pv[2]+m[6]*dx+m[7]*dy+m[8]*dz;
            const ux=m[0]*nx+m[1]*ny+m[2]*nz,uy=m[3]*nx+m[4]*ny+m[5]*nz,uz=m[6]*nx+m[7]*ny+m[8]*nz;nx=ux;ny=uy;nz=uz;}}
          if(o.cs){const pv=piv[1],k=1-wa;x=pv[0]+(x-pv[0])*(1+k*(o.cs[0]-1));y=pv[1]+(y-pv[1])*(1+k*(o.cs[1]-1));z=pv[2]+(z-pv[2])*(1+k*(o.cs[2]-1));}
          const a=Rm[1],ta=Tm[1];
          P[j]=a[0]*x+a[1]*y+a[2]*z+ta[0];P[j+1]=a[3]*x+a[4]*y+a[5]*z+ta[1];P[j+2]=a[6]*x+a[7]*y+a[8]*z+ta[2];
          N[j]=a[0]*nx+a[1]*ny+a[2]*nz;N[j+1]=a[3]*nx+a[4]*ny+a[5]*nz;N[j+2]=a[6]*nx+a[7]*ny+a[8]*nz;continue;}
        if(t>=0){const a=Rs[s.A[i]],ta=Ts[s.A[i]],ang=s.W[i]*(tw[t]||0);
          if(ang){const m=Ra(axis[t],ang),pv=piv[t],dx=x-pv[0],dy=y-pv[1],dz=z-pv[2];
            x=pv[0]+m[0]*dx+m[1]*dy+m[2]*dz;y=pv[1]+m[3]*dx+m[4]*dy+m[5]*dz;z=pv[2]+m[6]*dx+m[7]*dy+m[8]*dz;
            const ux=m[0]*nx+m[1]*ny+m[2]*nz,uy=m[3]*nx+m[4]*ny+m[5]*nz,uz=m[6]*nx+m[7]*ny+m[8]*nz;nx=ux;ny=uy;nz=uz;}
          P[j]=a[0]*x+a[1]*y+a[2]*z+ta[0];P[j+1]=a[3]*x+a[4]*y+a[5]*z+ta[1];P[j+2]=a[6]*x+a[7]*y+a[8]*z+ta[2];
          N[j]=a[0]*nx+a[1]*ny+a[2]*nz;N[j+1]=a[3]*nx+a[4]*ny+a[5]*nz;N[j+2]=a[6]*nx+a[7]*ny+a[8]*nz;continue;}
        const ia=s.A[i],ib=s.B[i],w=s.W[i];
        if(ia===ib||w>=1){const a=Rs[ib],ta=Ts[ib];
          P[j]=a[0]*x+a[1]*y+a[2]*z+ta[0];P[j+1]=a[3]*x+a[4]*y+a[5]*z+ta[1];P[j+2]=a[6]*x+a[7]*y+a[8]*z+ta[2];
          N[j]=a[0]*nx+a[1]*ny+a[2]*nz;N[j+1]=a[3]*nx+a[4]*ny+a[5]*nz;N[j+2]=a[6]*nx+a[7]*ny+a[8]*nz;continue;}
        // blended vertex: turn it by a fraction w of the child joint's rotation, then apply the parent
        const a=ib===1?Rm[ia]:Rs[ia],ta=ib===1?Tm[ia]:Ts[ia],pv=piv[ib],tl=LT[ib];
        if(ib===1&&o.cs){x=pv[0]+(x-pv[0])*(1+w*(o.cs[0]-1));y=pv[1]+(y-pv[1])*(1+w*(o.cs[1]-1));z=pv[2]+(z-pv[2])*(1+w*(o.cs[2]-1));}
        if(w>0&&LG[ib]){const m=Ra(LA[ib],w*LG[ib]),dx=x-pv[0],dy=y-pv[1],dz=z-pv[2];
          x=pv[0]+m[0]*dx+m[1]*dy+m[2]*dz;y=pv[1]+m[3]*dx+m[4]*dy+m[5]*dz;z=pv[2]+m[6]*dx+m[7]*dy+m[8]*dz;
          const ux=m[0]*nx+m[1]*ny+m[2]*nz,uy=m[3]*nx+m[4]*ny+m[5]*nz,uz=m[6]*nx+m[7]*ny+m[8]*nz;nx=ux;ny=uy;nz=uz;}
        x+=w*tl[0];y+=w*tl[1];z+=w*tl[2];
        P[j]=a[0]*x+a[1]*y+a[2]*z+ta[0];P[j+1]=a[3]*x+a[4]*y+a[5]*z+ta[1];P[j+2]=a[6]*x+a[7]*y+a[8]*z+ta[2];
        N[j]=a[0]*nx+a[1]*ny+a[2]*nz;N[j+1]=a[3]*nx+a[4]*ny+a[5]*nz;N[j+2]=a[6]*nx+a[7]*ny+a[8]*nz;}});
    // stand on whatever part of either foot is lowest, toes included
    for(const pt of pits){const b=pt.sd.b,tt=ss(LG[b+3],.12,.6),Rc=Rm[1],Tc=Tm[1],Ra2=Rm[b+3],Ta=Tm[b+3],AP=pt.armP.P,AN=pt.armP.N,TP=torsoP.P,TN=torsoP.N;
      for(let k=0;k<pt.arm.length;k+=3){const j=pt.arm[k]*3,x=AP[j]-Tc[0],y=AP[j+1]-Tc[1],z=AP[j+2]-Tc[2];
        const e=pt.arm[k+1]*(swp(dist(torsoP.R,Rc[1]*x+Rc[4]*y+Rc[7]*z,Rc[0]*x+Rc[3]*y+Rc[6]*z,Rc[2]*x+Rc[5]*y+Rc[8]*z),tt)-pt.arm[k+2]);
        if(e){AP[j]+=AN[j]*e;AP[j+1]+=AN[j+1]*e;AP[j+2]+=AN[j+2]*e;}}
      for(let k=0;k<pt.tor.length;k+=3){const j=pt.tor[k]*3,x=TP[j]-Ta[0],y=TP[j+1]-Ta[1],z=TP[j+2]-Ta[2];
        const q=pt.sd.q([Ra2[0]*x+Ra2[3]*y+Ra2[6]*z,Ra2[1]*x+Ra2[4]*y+Ra2[7]*z,Ra2[2]*x+Ra2[5]*y+Ra2[8]*z]);
        const e=pt.tor[k+1]*(swp(dist(pt.armP.R,q[1],q[0],q[2]),tt)-pt.tor[k+2]);
        if(e){TP[j]+=TN[j]*e;TP[j+1]+=TN[j+1]*e;TP[j+2]+=TN[j+2]*e;}}}
    if(o.sole){let lo=1e9;for(const p of soles){const P=p.P;for(let j=1;j<P.length;j+=3)if(P[j]<lo)lo=P[j];}const dy=sole0-lo;
      parts.forEach(p=>{const P=p.P;for(let j=1;j<P.length;j+=3)P[j]+=dy;});for(let i=0;i<NB;i++)Tm[i]=[Tm[i][0],Tm[i][1]+dy,Tm[i][2]];}}
  const soles=parts.filter(p=>/^(foot|toe)/.test(p.name));let sole0=1e9;for(const p of soles)for(let j=1;j<p.P.length;j+=3)if(p.P[j]<sole0)sole0=p.P[j];
  const TAU=Math.PI*2,T2=-.38;
  function walk(t){const ph=TAU*t/1.0,L=[],sn=Math.sin(ph),cs=Math.cos(ph),drop=[0,0],pit=[0,0];
    L[0]=mul(Ry(-.09*sn),Rz(-.035*cs));L[1]=mul(Rx(.035),mul(Ry(.19*sn),Rz(.035*cs)));L[2]=mul(Rx(-.03),Ry(-.09*sn));
    [0,Math.PI].forEach((off,k)=>{const b=BL+k*8,f=ph+off,th=.45*Math.sin(f),kn=.08+.9*Math.pow(Math.max(0,Math.cos(f+.15)),2),w=.7-.3*Math.cos(f);
      L[b]=Rx(-th);L[b+1]=Rx(kn);L[b+2]=Rx((th-kn)*w);L[b+3]=mul(Rx(.72*th),Rz(k?.17:-.17));L[b+5]=Rx(-(.04+.34*Math.max(0,-Math.sin(f))));
      drop[k]=.41*Math.cos(th)+.43*Math.cos(th-kn);pit[k]=(kn-th)*(1-w);});
    // toes: while a foot is near the ground and tipped toe-down, its toes bend up to stay flat
    [BL,BR].forEach((b,k)=>{const h=Math.max(drop[0],drop[1])-drop[k],a=Math.min(.55,Math.max(0,pit[k]))*(1-ss(h,.02,.09));for(let i=0;i<5;i++)toe(L,b,i,-a,0);});
    apply({L,T:{0:[-.012*cs,0,0]},ground:true});}
  function idleLayer(t){const b=.5-.5*Math.cos(TAU*t/3.8),sw=Math.sin(TAU*t/7.6),L=[];
    L[1]=mul(Rx(-.022*b),Rz(.014*sw));L[2]=mul(Rx(.018*b),Rz(-.014*sw));
    L[BL+3]=mul(Rz(-.2+.02*b),Rx(.02*sw));L[BR+3]=mul(Rz(.2-.02*b),Rx(-.02*sw));L[BL+5]=Rx(.05-.03*b);L[BR+5]=Rx(.05-.03*b);
    return{L,T:{1:[0,.011*b,0]},tw:{},cs:[1+.012*b,1,1+.06*b]};}
  function idle(t){apply(idleLayer(t));}
  function wave(t){const o=idleLayer(t*.9),L=o.L,per=3.4,k=Math.floor(t/per)%2,u=(t/per)%1,sg=k?1:-1,b=k?BL:BR;
    const env=ss(u,.02,.24)*(1-ss(u,.76,.98)),e2=ss(u,.2,.32)*(1-ss(u,.68,.8)),f=TAU*3*(u-.2)/.6,os=Math.sin(f)*e2,os2=Math.sin(f-.6)*e2;
    const pre=(i,m)=>{L[i]=mul(m,L[i]||ID);};
    girdle(L,b,Rz(sg*.12*env),mul(Rz(sg*1.02*env),Rx(-.1*env)));o.tw[b+4]=-sg*(Math.PI/2)*env;
    pre(b+5,Rx(-(1.42*env+.16*os)));o.tw[b+6]=sg*T2*env;
    L[b+7]=mul(Ra(AX[b].n,.42*os2),Ra(AX[b].h,-.12*env));
    pre(1,mul(Rz(sg*.035*env),Ry(-sg*.05*env)));pre(2,Rz(sg*.06*env));
    apply(o);}
  function wrists(t){const o=idleLayer(t*.9),L=o.L,per=2.4,seg=Math.floor(t/per)%3,u=(t/per)%1,w=Math.sin(TAU*2*u);
    const pre=(i,m)=>{L[i]=mul(m,L[i]||ID);};
    [[BL,1],[BR,-1]].forEach(([b,sg])=>{pre(b+3,Rx(-.28));o.tw[b+4]=-sg*.4;pre(b+5,Rx(-1.2));
      o.tw[b+6]=seg===2?sg*1.0*w:0;L[b+7]=seg===0?Ra(AX[b].h,.6*w):seg===1?Ra(AX[b].n,.42*w):ID;});
    apply(o);}
  const FN=['index','middle','ring','pinky'];
  function curl(L,b,name,c){const f=FB[b][name];L[f[0]]=Ra(hinge[f[0]],1.25*c);L[f[1]]=Ra(hinge[f[1]],1.45*c);L[f[2]]=Ra(hinge[f[2]],.9*c);}
  function thumb(L,b,c){const t=FB[b].thumb;L[t[0]]=mul(Ra(AX[b].u,.8*c),mul(Ra(hinge[t[0]],.4*c),Ra(AX[b].m,0*c)));L[t[1]]=Ra(hinge[t[1]],.45*c);L[t[2]]=Ra(hinge[t[2]],.6*c);}
  function fingers(t){const o=idleLayer(t*.9),L=o.L,per=2.6,seg=Math.floor(t/per)%3,u=(t/per)%1;
    const pre=(i,m)=>{L[i]=mul(m,L[i]||ID);};
    [[BL,1],[BR,-1]].forEach(([b,sg])=>{girdle(L,b,Rz(sg*.12),mul(Rz(sg*1.02),Rx(-.1)));o.tw[b+4]=-sg*Math.PI/2;pre(b+5,Rx(-1.42));o.tw[b+6]=sg*T2;L[b+7]=Ra(AX[b].h,-.1);
      if(seg===0){const c=.5-.5*Math.cos(TAU*2*u);FN.forEach(n=>curl(L,b,n,c));thumb(L,b,c);}
      else if(seg===1){FN.forEach((n,i)=>{const v=Math.max(0,Math.sin(TAU*2*u-i*.75));curl(L,b,n,v*v);});thumb(L,b,0);}
      else{const c=.5-.5*Math.cos(TAU*2*u);curl(L,b,'index',.62*c);FN.slice(1).forEach(n=>curl(L,b,n,.08*c));thumb(L,b,c);}});
    apply(o);}
  function head(t){const o=idleLayer(t*.9),L=o.L,per=2.6,seg=Math.floor(t/per)%4,u=(t/per)%1,w=Math.sin(TAU*u),K=1;
    let n=ID,h=ID;
    if(seg===0){n=Ry(.6*w*K);h=Ry(.62*w*K);}
    else if(seg===1){const v=w<0?-w*.85:-w*.8;n=Rx(-.42*v*K);h=Rx(-.58*v*K);}
    else if(seg===2){n=Rz(.2*w*K);h=Rz(.3*w*K);}
    else{const c=Math.cos(TAU*u);n=mul(Ry(.45*w),Rx(.22*c));h=mul(Ry(.45*w),Rx(.3*c));}
    L[2]=mul(n,L[2]||ID);L[HD]=h;apply(o);}
  function arms(t){const o=idleLayer(t*.9),L=o.L,per=2.8,seg=Math.floor(t/per)%5,u=(t/per)%1,c=.5-.5*Math.cos(TAU*u),CK=1;
    const pre=(i,m)=>{L[i]=mul(m,L[i]||ID);};
    [[BL,1],[BR,-1]].forEach(([b,sg])=>{
      if(seg===0){const g=ss(c,.25,.95);girdle(L,b,mul(Rz(sg*.4*g*CK),Ry(-sg*.15*g*CK)),Rx(-2.85*c));pre(b+5,Rx(.12*c));}
      else if(seg===1){const g=ss(c,.25,.95);girdle(L,b,Rz(sg*.5*g*CK),Rz(sg*2.9*c));o.tw[b+4]=-sg*1.2*c;pre(b+5,Rx(.12*c));}
      else if(seg===2){pre(b+3,Rx(-.25*c));pre(b+5,Rx(-2.35*c));o.tw[b+6]=-sg*.5*c;}
      else if(seg===3){girdle(L,b,Ry(sg*.18*c*CK),Rx(.95*c));pre(b+5,Rx(-.5*c));}
      else{const e=ss(u,0,.2)*(1-ss(u,.8,1)),v=Math.sin(TAU*2*u)*e;girdle(L,b,Rz(sg*.15*e*CK),Rz(sg*1.45*e));pre(b+5,Rx(.15*e));o.tw[b+4]=-sg*(.6+.9*v)*e;o.tw[b+6]=sg*1.3*v;}});
    apply(o);}
  const TN=['toe1','toe2','toe3','toe4','toe5'];
  // toe joints: positive curls the toe down, negative lifts it
  function toe(L,b,i,a1,a2){const t=FB[b][TN[i]];L[t[0]]=Ra(hinge[t[0]],a1);L[t[1]]=Ra(hinge[t[1]],a2);}
  function toes(t){const o=idleLayer(t*.9),L=o.L,per=3.0,seg=Math.floor(t/per)%3,u=(t/per)%1;o.sole=true;
    if(seg===0){[BL,BR].forEach(b=>{for(let i=0;i<5;i++){const v=Math.max(0,Math.sin(TAU*2*u-i*.55));toe(L,b,i,-.62*v*v,-.2*v*v);}});}
    else if(seg===1){const c=ss(u,.05,.4)*(1-ss(u,.62,.97)),a=.72*c;[BL,BR].forEach(b=>{L[b+2]=Rx(a);for(let i=0;i<5;i++)toe(L,b,i,-a,0);});
      L[1]=mul(Rx(.03*c),L[1]||ID);}
    else{const e=ss(u,.02,.22)*(1-ss(u,.8,.98)),c=.5-.5*Math.cos(TAU*2*ss(u,.22,.8)),b=BL;
      L[0]=Rz(.045*e);L[1]=mul(Rz(-.05*e),L[1]||ID);o.T[0]=[-.035*e,0,0];L[b]=mul(Rx(-1.0*e),Rz(-.045*e));L[b+1]=Rx(1.05*e);L[b+2]=Rx(.12*e);L[BR]=Rz(-.045*e);
      for(let i=0;i<5;i++){const d=Math.max(0,Math.min(1,c*1.5-i*.1));toe(L,b,i,.5*d,.75*d);}}
    apply(o);}
  function jointPos(i){const p=app(Rm[i],piv[i]);return add(p,Tm[i]);}
  function rest(){apply({L:[]});}
  function handAxes(){return[app(Rm[BL+7],AX[BL].tu),app(Rm[BL+7],AX[BL].tv),app(Rm[BR+7],AX[BR].tu),app(Rm[BR+7],AX[BR].tv),app(Rm[BL+2],AX[BL].fu),app(Rm[BL+2],AX[BL].fv),app(Rm[BR+2],AX[BR].fu),app(Rm[BR+2],AX[BR].fv)];}
  return{apply,walk,idle,wave,wrists,fingers,head,arms,toes,jointPos,rest,handAxes,HD,handL:BL+7,handR:BR+7,bones:NB,pivots:piv,parents:par};
}
root.makeRig=makeRig;
})(window);
