const fs=require('fs'),zlib=require('zlib'),MB=require('./male_body_muscular.js');
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const ramp=st=>{const s=st.map(hex),o=[];for(let i=0;i<8;i++){const t=i/7*(s.length-1),k=Math.min(Math.floor(t),s.length-2),f=t-k;o.push(s[k].map((v,j)=>Math.round(v+(s[k+1][j]-v)*f)));}return o;};
const RAMPS={skin:ramp(JSON.parse(process.env.SKIN||'["#efc9a0","#c08a68","#84554c","#452d3c","#18121f"]')),cloth:ramp(['#9495aa','#5c5d75','#30314a','#12111e']),nail:ramp(['#f4dfcd','#d2a999','#986e6c','#54394b','#1a1422'])};
const NT=+(process.env.NT||.4);RAMPS.nail=RAMPS.nail.map((c,i)=>c.map((v,j)=>Math.round(RAMPS.skin[i][j]+(v-RAMPS.skin[i][j])*NT)));
const parts=MB.build();
const b4=(x,y)=>{const b2=(x,y)=>{x=Math.floor(x);y=Math.floor(y);const v=x*.5+y*y*.75;return v-Math.floor(v);};return b2(.5*x,.5*y)*.25+b2(x,y);};

function handRelief(u,v,sd){const sm=(a,b,x)=>{const t=Math.min(1,Math.max(0,(x-a)/(b-a)));return t*t*(3-2*t);};let gu=0,gv=0,dk=0;
  if(sd>0){
    const td=(zk,vk)=>{const t=Math.min(1,Math.max(0,(v+.004)/(vk+.004))),u0=.004+.3*zk,uc=u0+(zk-u0)*t,d=(u-uc)/.0028,e=Math.exp(-d*d),fa=(1-sm(-.03,-.01,v))*sm(vk-.006,vk+.006,v),sl=(zk-u0)/(vk+.004);
      gu+=-TS*fa*2*d*e;gv+=TS*fa*2*d*e*sl;const du=(u-zk)/.008,dv=(v-vk-.004)/.008,ek=Math.exp(-du*du-dv*dv);gu+=-KS*2*du*ek;gv+=-KS*2*dv*ek;};
    td(.036,-.098);td(.014,-.102);td(-.008,-.099);td(-.029,-.091);
    const vn=(a,b,c,f,p,va,vb)=>{const uc=a+b*v+c*Math.sin(f*v+p),d=(u-uc)/.0034,e=Math.exp(-d*d),fa=sm(va,va+.012,v)*(1-sm(vb-.012,vb,v)),ucp=b+c*f*Math.cos(f*v+p);gu+=-VS*fa*2*d*e;gv+=VS*fa*2*d*e*ucp;};
    vn(-.0319,-.397,.003,110,0,-.09,-.002);vn(.0008,.233,0,0,0,-.088,-.05);vn(.01905,-.119,.0025,140,1,-.078,-.004);
  }else{
    const cu=(a,b,c,f,p,ua,ub)=>{const vc=a+b*u+c*Math.sin(f*u+p),d=(v-vc)/CW,e=Math.exp(-d*d),fa=sm(ua,ua+.008,u)*(1-sm(ub-.008,ub,u)),vcp=b+c*f*Math.cos(f*u+p);gv+=CS*fa*2*d*e;gu+=-CS*fa*2*d*e*vcp;dk+=fa*e;};
    cu(-.08556,-.339,.003,50.7,2.03,-.043,.024);cu(-.06,-.25,-.0025,52,1,-.022,.042);cu(-.007,0,.0015,60,1.57,-.03,.03);cu(.001,0,.0012,70,.4,-.026,.026);
    {const t=Math.min(1,Math.max(0,(v+.068)/.056)),uc=.006+.034*Math.pow(1-t,1.8),d=(u-uc)/CW,e=Math.exp(-d*d),fa=sm(-.07,-.062,v)*(1-sm(-.02,-.012,v)),ucp=-.034*1.8*Math.pow(1-t,.8)/.056;gu+=CS*fa*2*d*e;gv+=-CS*fa*2*d*e*ucp;dk+=fa*e;}
  }
  const k=Math.abs(sd);return[gu*k,gv*k,dk*k];}
const HE=process.env,TS=+(HE.TS||.55),KS=+(HE.KS||.5),VS=+(HE.VS||.45),CS=+(HE.CS||.55),CW=+(HE.CW||.002),HB=+(HE.HB||1.3),HD=+(HE.HD||.13),FB=+(HE.FB||.75);
function footRelief(u,t,mk){const c01=x=>Math.min(1,Math.max(0,x)),fd=c01((t-.03)/.03)*c01((.14-t)/.035),rf=.046-.32*(t-.04);let gu=0,gv=0;
  const ft=(d0,d1,amp)=>{const xi=-.006+(d0+.006)*t/d1,d=(u-xi)/.0036,k=amp*rf/.0036*2*d*Math.exp(-d*d);gu-=k;gv+=k*(d0+.006)/d1;};
  ft(-.028,.142,.085);ft(-.006,.148,.065);ft(.011,.143,.06);ft(.026,.134,.055);ft(.040,.121,.05);const k=mk*fd*FB;return[gu*k,gv*k,0];}
function view(W,H,yaw,yc,hh,amb,keyA,pvx=0,pvz=0,pit=0){const cp=Math.cos(pit),spi=Math.sin(pit);
  const hw=hh*W/H,zb=new Float32Array(W*H).fill(-1e9),R=new Int8Array(W*H).fill(-1),X=new Uint8Array(W*H);
  const cy=Math.cos(yaw),sy=Math.sin(yaw),L=[Math.sin(keyA)*.8,.7,Math.cos(keyA)*.55],ll=Math.hypot(...L);L.forEach((v,i)=>L[i]=v/ll);
  for(const p of parts){if(globalThis.ONLY&&/R\d*$/.test(p.name))continue;const n=p.P.length/3,sx=new Float32Array(n),syy=new Float32Array(n),sz=new Float32Array(n),nn=new Float32Array(n*3);
    for(let i=0;i<n;i++){const x=p.P[i*3]-pvx,y=p.P[i*3+1],z=p.P[i*3+2]-pvz,vx=x*cy+z*sy,vz=-x*sy+z*cy;
      const y0=y-yc,y1=y0*cp-vz*spi,z1=y0*spi+vz*cp;sx[i]=(vx/hw*.5+.5)*W;syy[i]=(.5-y1/hh*.5)*H;sz[i]=z1;
      const a=p.N[i*3],b=p.N[i*3+1],c=p.N[i*3+2];const nz0=-a*sy+c*cy;nn[i*3]=a*cy+c*sy;nn[i*3+1]=b*cp-nz0*spi;nn[i*3+2]=b*spi+nz0*cp;}
    for(let t=0;t<p.I.length;t+=3){const a=p.I[t],b=p.I[t+1],c=p.I[t+2];
      const x0=sx[a],y0=syy[a],x1=sx[b],y1=syy[b],x2=sx[c],y2=syy[c],ar=(x1-x0)*(y2-y0)-(x2-x0)*(y1-y0);if(Math.abs(ar)<1e-9)continue;
      const mnx=Math.max(0,Math.floor(Math.min(x0,x1,x2))),mxx=Math.min(W-1,Math.ceil(Math.max(x0,x1,x2))),mny=Math.max(0,Math.floor(Math.min(y0,y1,y2))),mxy=Math.min(H-1,Math.ceil(Math.max(y0,y1,y2)));
      for(let py=mny;py<=mxy;py++)for(let px=mnx;px<=mxx;px++){const qx=px+.5,qy=py+.5;
        const w0=((x1-qx)*(y2-qy)-(x2-qx)*(y1-qy))/ar,w1=((x2-qx)*(y0-qy)-(x0-qx)*(y2-qy))/ar,w2=1-w0-w1;if(w0<0||w1<0||w2<0)continue;
        const z=w0*sz[a]+w1*sz[b]+w2*sz[c],i=py*W+px;if(z<=zb[i])continue;zb[i]=z;
        let nx=w0*nn[a*3]+w1*nn[b*3]+w2*nn[c*3],ny=w0*nn[a*3+1]+w1*nn[b*3+1]+w2*nn[c*3+1],nz=w0*nn[a*3+2]+w1*nn[b*3+2]+w2*nn[c*3+2];const l=Math.hypot(nx,ny,nz)||1;nx/=l;ny/=l;nz/=l;
        let crs=0;if(p.L&&p.L[a*4+3]>3.5&&globalThis.HANDAX){const hu=w0*p.L[a*4]+w1*p.L[b*4]+w2*p.L[c*4],hv2=w0*p.L[a*4+1]+w1*p.L[b*4+1]+w2*p.L[c*4+1],hs=w0*p.L[a*4+2]+w1*p.L[b*4+2]+w2*p.L[c*4+2];
          const fl=p.L[a*4+3],g=fl>5.5?footRelief(hu,hv2,hs):handRelief(hu,hv2,hs),o=fl>6.5?6:fl>5.5?4:fl>4.5?2:0,hb=fl>5.5?1:HB,rv=t=>{const z0=-t[0]*sy+t[2]*cy;return[t[0]*cy+t[2]*sy,t[1]*cp-z0*spi,t[1]*spi+z0*cp];},Tu=rv(globalThis.HANDAX[o]),Tv=rv(globalThis.HANDAX[o+1]);
          nx-=hb*(g[0]*Tu[0]+g[1]*Tv[0]);ny-=hb*(g[0]*Tu[1]+g[1]*Tv[1]);nz-=hb*(g[0]*Tu[2]+g[1]*Tv[2]);const l2=Math.hypot(nx,ny,nz)||1;nx/=l2;ny/=l2;nz/=l2;crs=g[2];}
        let I=amb+.98*Math.max(nx*L[0]+ny*L[1]+nz*L[2],0)+.08*Math.max(nx*.7-ny*.2+nz*.2,0)-HD*crs;let bed=false,nl=false;if(p.L&&p.L[a*4+3]<1.5){const lv=k=>w0*p.L[a*4+k]+w1*p.L[b*4+k]+w2*p.L[c*4+k],v=lv(2),toe=lv(3)>.5,d=Math.atan2(lv(1),lv(0));if(v>.05){const pw=toe?4:2,cc=toe?[.61,.31,.98]:[.55,.32,.85];nl=Math.pow(Math.abs((v-cc[0])/cc[1]),pw)+Math.pow(Math.abs(d/cc[2]),pw)<1;bed=!nl&&(toe?Math.pow(Math.abs((v-.575)/.355),4)+Math.pow(Math.abs(d/1.16),4)<1:Math.pow((v-.55)/.39,2)+Math.pow(d/1.04,2)<1)?(toe?2:1):0;}}if(nl)I+=+(process.env.NB||.11);if(p.L){const e3=w0*p.L[a*4+3]+w1*p.L[b*4+3]+w2*p.L[c*4+3];if(e3>1.5&&e3<3.5)I-=+(process.env.EB||.5)*(w0*p.L[a*4]+w1*p.L[b*4]+w2*p.L[c*4]);}I+=(b4(px,H-1-py)-.5)*.14;
        const ry=w0*p.P[a*3+1]+w1*p.P[b*3+1]+w2*p.P[c*3+1],rx=w0*p.P[a*3]+w1*p.P[b*3]+w2*p.P[c*3];
        const cl=(ry>.835&&ry<1.035&&Math.abs(rx)<.25)?1:0;const rz=w0*p.P[a*3+2]+w1*p.P[b*3+2]+w2*p.P[c*3+2];let cf=0;if(p.name==='torso'&&rz>.05){const E=process.env,d=Math.hypot(Math.abs(rx)-+(E.NX||.102),ry-+(E.NY||1.314));if(d<+(E.NO||.016))bed=Math.max(bed||0,d<+(E.NI||.010)?2:1);}if(p.name==='torso'&&rz<-.06){const E=process.env,sq=(v,a,b)=>{const t=Math.min(1,Math.max(0,(v-a)/(b-a)));return t*t*(3-2*t);};cf=+(E.CA||.38)*Math.exp(-Math.pow(rx/+(E.CW||.0055),2))*sq(ry,.872,.9)*(1-sq(ry,+(E.CT0||.93),+(E.CT1||.98)));}
        X[i]=Math.min(7,Math.floor(Math.min(.999,Math.max(0,(1.1-(I-cf))/1.1))*8)+(cl?1:0)+(bed||0));R[i]=nl?2:cl;}}}
  const out=new Uint8Array(W*H*3).fill(40),names=['skin','cloth','nail'];
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x,o=i*3;
    if(R[i]>=0){let ix=X[i];const h=Math.sin(x*12.9898+y*78.233)*43758.5453,f=h-Math.floor(h);if(f<.07)ix=Math.max(0,ix-1);else if(f>.93)ix=Math.min(7,ix+1);
      const c=RAMPS[names[R[i]]][ix];out[o]=c[0];out[o+1]=c[1];out[o+2]=c[2];continue;}
    let nr=-1;if(x>0&&R[i-1]>=0)nr=R[i-1];else if(x<W-1&&R[i+1]>=0)nr=R[i+1];else if(y>0&&R[i-W]>=0)nr=R[i-W];else if(y<H-1&&R[i+W]>=0)nr=R[i+W];
    if(nr>=0){const c=RAMPS[names[nr]][7];out[o]=c[0]*.6;out[o+1]=c[1]*.6;out[o+2]=c[2]*.6;}}
  return out;
}
function png(file,W,H,rgb){const raw=Buffer.alloc((W*3+1)*H);for(let y=0;y<H;y++){raw[y*(W*3+1)]=0;Buffer.from(rgb.buffer,y*W*3,W*3).copy(raw,y*(W*3+1)+1);}
  const crcT=[];for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;crcT[n]=c>>>0;}
  const crc=b=>{let c=0xffffffff;for(const v of b)c=crcT[(c^v)&255]^(c>>>8);return(c^0xffffffff)>>>0;};
  const ch=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(t),d]),c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c]);};
  const ih=Buffer.alloc(13);ih.writeUInt32BE(W,0);ih.writeUInt32BE(H,4);ih[8]=8;ih[9]=2;
  fs.writeFileSync(file,Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),ch('IHDR',ih),ch('IDAT',zlib.deflateSync(raw)),ch('IEND',Buffer.alloc(0))]));}
function sheet(file,W,H,sc,views){const SW=W*sc*views.length,SH=H*sc,o=new Uint8Array(SW*SH*3);
  views.forEach((v,k)=>{const im=view(W,H,...v);for(let y=0;y<SH;y++)for(let x=0;x<W*sc;x++){const s=(Math.floor(y/sc)*W+Math.floor(x/sc))*3,d=(y*SW+k*W*sc+x)*3;o[d]=im[s];o[d+1]=im[s+1];o[d+2]=im[s+2];}});png(file,SW,SH,o);}
const K=-.7;
sheet('full.png',72,88,4,[[0,.9,.95,.13,K],[-.6,.9,.95,.13,K],[-1.5708,.9,.95,.13,K],[Math.PI,.9,.95,.13,K]]);
sheet('upper.png',72,88,4,[[0,1.38,.46,.13,K],[-.6,1.38,.46,.13,K],[-1.5708,1.38,.46,.13,K],[Math.PI,1.38,.46,.13,K]]);
sheet('lower.png',72,88,4,[[0,.47,.5,.13,K],[-.6,.47,.5,.13,K],[-1.5708,.47,.5,.13,K],[Math.PI,.47,.5,.13,K]]);
const hp=parts.find(p=>p.name==='handL');let hc=[0,0,0];for(let i=0;i<hp.P.length;i+=3){hc[0]+=hp.P[i];hc[1]+=hp.P[i+1];hc[2]+=hp.P[i+2];}hc=hc.map(v=>v/(hp.P.length/3));console.log('hc',hc);
const hv=y=>[y,hc[1]-.04,.15,.13,K,hc[0],hc[2]];
sheet('hands.png',72,88,4,[hv(0),hv(-.8),hv(-1.5708),hv(1.5708),hv(Math.PI)]);
const nv=y=>[y,hc[1]-.09,.085,.13,K,hc[0],hc[2]];sheet('nails.png',72,88,4,[nv(0),nv(-.8),nv(-1.5708),nv(-2.3),nv(Math.PI)]);
const fv=(y,p)=>[y,.06,.15,.13,K,.112,.05,p];globalThis.ONLY=1;sheet('feet.png',72,88,4,[fv(1.5708,0),fv(1.2,.5),fv(Math.PI,0),fv(-.9,.9),fv(-1.5708,0),fv(0,.1)]);globalThis.ONLY=0;
const bv=(y,p)=>[y,.09,.21,.13,K,0,.05,p];sheet('feet2.png',72,88,4,[bv(0,.35),bv(-.8,.5),bv(2.4,.4),bv(1.5708,0)]);
const av=(y,p)=>[y,.045,.11,.13,K,.112,.06,p];globalThis.ONLY=1;sheet('arch.png',72,88,4,[av(1.5708,0),av(1.5708,-.35),av(1.5708,.45),av(1.0,.2),av(2.3,-.2)]);const tv=(y,p,k)=>[y,.04,.095,.13,k,.115,.09,p];sheet('tendons.png',72,88,4,[tv(-.3,1.0,K),tv(-.9,.8,K),tv(.7,.8,K),tv(-.3,1.0,.9),tv(0,.5,-1.2)]);globalThis.ONLY=0;
globalThis.ONLY=1;const nv2=(y,p,k)=>[y,.03,.06,.13,k,.112,.165,p];sheet('toenails.png',72,88,4,[nv2(0,1.2,K),nv2(-.6,.8,K),nv2(.5,.9,K),nv2(0,.5,K),nv2(0,1.2,.6)]);globalThis.ONLY=0;
const gv=(y,p)=>[y,.93,.24,.13,K,0,0,p];sheet(process.env.GOUT||'butt.png',72,88,4,[gv(Math.PI,0),gv(2.5,.1),gv(-1.5708,0),gv(Math.PI,.5),gv(Math.PI,-.5)]);
console.log(parts.length,'parts',parts.reduce((a,p)=>a+p.I.length/3,0),'tris');
