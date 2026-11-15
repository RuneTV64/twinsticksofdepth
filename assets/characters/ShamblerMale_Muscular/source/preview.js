// Preview renderer for the shambler parts: same 8-shade banding, dither and palettes as zombie_skin.gdshader.
const fs=require('fs'),zlib=require('zlib');
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const ramp=st=>{const s=st.map(hex),o=[];for(let i=0;i<8;i++){const t=i/7*(s.length-1),k=Math.min(Math.floor(t),s.length-2),f=t-k;o.push(s[k].map((v,j)=>Math.round(v+(s[k+1][j]-v)*f)));}return o;};
const PAL={
  skin:[ramp(['#aeab98','#807d6c','#57554d','#332f39','#130f18']),ramp(['#9ea684','#727c5e','#4b5543','#2b3231','#130f18']),ramp(['#ab9a94','#7e6c6b','#56444c','#322635','#130f18'])],
  decay:ramp(['#7d6c4c','#564633','#382c27','#1f171d','#0f0b11']),
  flesh:ramp(['#c26656','#923f3a','#5f2430','#341422','#130a12']),
  bone:ramp(['#ece2c2','#c7b994','#938465','#584c45','#1c1720']),
  cloth:ramp(['#86847d','#5a5853','#333037','#13111b']),
  nail:ramp(['#c9bd8a','#8f8460','#5b5045','#2c2430','#120e16'])};
const b4=(x,y)=>{const b2=(x,y)=>{x=Math.floor(x);y=Math.floor(y);const v=x*.5+y*y*.75;return v-Math.floor(v);};return b2(.5*x,.5*y)*.25+b2(x,y);};
const q2=a=>a*a,q4=a=>a*a*a*a;
// shade one fragment the way the shader does; returns [r,g,b]
function shade(I,rot,code,rp,nv,ang,tone,px,py){
  let ix,pal,cl=((code===3)||code===8)&&rp[1]>.835&&rp[1]<1.035&&Math.abs(rp[0])<.25,nail=false,rim=0;
  if(nv>.05&&code<=1){if(code===1){nail=q4((nv-.61)/.31)+q4(ang/.98)<1;if(!nail&&q4((nv-.575)/.355)+q4(ang/1.16)<1)rim=2;}else{nail=q2((nv-.55)/.32)+q2(ang/.85)<1;if(!nail&&q2((nv-.55)/.39)+q2(ang/1.04)<1)rim=1;}}
  if(nail)I+=.11;I+=(b4(px,py)-.5)*.14;
  const base=Math.floor(Math.min(.999,Math.max(0,(1.1-I)/1.1))*8);
  if(rot>.8){pal=PAL.bone;ix=base;cl=false;}
  else if(rot>.45){pal=PAL.flesh;ix=base+(rot>.72?2:rot>.6?1:0);cl=false;}
  else if(rot>.3){pal=PAL.decay;ix=base;cl=false;}
  else{pal=nail?PAL.nail:cl?PAL.cloth:PAL.skin[tone];ix=base+(cl?1:0)+rim+(!cl&&rot>.24?2:!cl&&rot>.16?1:0);}
  return pal[Math.min(7,ix)];}
// rasterize a list of merged meshes; view: {W,H,yaw,yc,hh,pitch,cx,cz}
function render(meshes,v,tones){const{W,H}=v,cy=Math.cos(v.yaw),sy=Math.sin(v.yaw),cp=Math.cos(v.pitch||0),spi=Math.sin(v.pitch||0),hw=v.hh*W/H;
  const L=(()=>{const K=-.7,l=[Math.sin(K)*.8,.7,Math.cos(K)*.55],n=Math.hypot(...l);return l.map(x=>x/n);})();
  const zb=new Float32Array(W*H).fill(-1e9),img=new Uint8Array(W*H*3).fill(0),hit=new Int8Array(W*H).fill(0);
  meshes.forEach((m,mi)=>{const n=m.nv,ox=m.ox||0,sx=new Float32Array(n),syy=new Float32Array(n),sz=new Float32Array(n),nn=new Float32Array(n*3);
    for(let i=0;i<n;i++){const x=m.P[i*3]+ox-(v.cx||0),y=m.P[i*3+1],z=m.P[i*3+2]-(v.cz||0),vx=x*cy+z*sy,vz=-x*sy+z*cy,y0=y-v.yc,y1=y0*cp-vz*spi,z1=y0*spi+vz*cp;
      sx[i]=(vx/hw*.5+.5)*W;syy[i]=(.5-y1/v.hh*.5)*H;sz[i]=z1;const a=m.N[i*3],b=m.N[i*3+1],c=m.N[i*3+2],nz0=-a*sy+c*cy;nn[i*3]=a*cy+c*sy;nn[i*3+1]=b*cp-nz0*spi;nn[i*3+2]=b*spi+nz0*cp;}
    const tone=tones?tones[mi]:0;
    for(let t=0;t<m.I.length;t+=3){const a=m.I[t],b=m.I[t+1],c=m.I[t+2],x0=sx[a],y0=syy[a],x1=sx[b],y1=syy[b],x2=sx[c],y2=syy[c],ar=(x1-x0)*(y2-y0)-(x2-x0)*(y1-y0);if(Math.abs(ar)<1e-9)continue;
      const mnx=Math.max(0,Math.floor(Math.min(x0,x1,x2))),mxx=Math.min(W-1,Math.ceil(Math.max(x0,x1,x2))),mny=Math.max(0,Math.floor(Math.min(y0,y1,y2))),mxy=Math.min(H-1,Math.ceil(Math.max(y0,y1,y2)));
      for(let py=mny;py<=mxy;py++)for(let px=mnx;px<=mxx;px++){const qx=px+.5,qy=py+.5,w0=((x1-qx)*(y2-qy)-(x2-qx)*(y1-qy))/ar,w1=((x2-qx)*(y0-qy)-(x0-qx)*(y2-qy))/ar,w2=1-w0-w1;if(w0<0||w1<0||w2<0)continue;
        const z=w0*sz[a]+w1*sz[b]+w2*sz[c],i=py*W+px;if(z<=zb[i])continue;zb[i]=z;
        let nx=w0*nn[a*3]+w1*nn[b*3]+w2*nn[c*3],ny=w0*nn[a*3+1]+w1*nn[b*3+1]+w2*nn[c*3+1],nz=w0*nn[a*3+2]+w1*nn[b*3+2]+w2*nn[c*3+2];const l=Math.hypot(nx,ny,nz)||1;nx/=l;ny/=l;nz/=l;
        const I=.13+.98*Math.max(nx*L[0]+ny*L[1]+nz*L[2],0)+.08*Math.max(nx*.7-ny*.2+nz*.2,0)-(m.COL[a*4+3]===34||m.COL[a*4+3]===51?.5*(w0*m.COL[a*4]+w1*m.COL[b*4]+w2*m.COL[c*4])/255:0);
        const rot=(w0*m.COL[a*4+2]+w1*m.COL[b*4+2]+w2*m.COL[c*4+2])/255,code=Math.round(m.COL[a*4+3]/17);
        const rp=[w0*m.UV[a*2]+w1*m.UV[b*2]+w2*m.UV[c*2],w0*m.UV[a*2+1]+w1*m.UV[b*2+1]+w2*m.UV[c*2+1]];
        const nv=code<=1?w0*m.UV2[a*2]+w1*m.UV2[b*2]+w2*m.UV2[c*2]:0,ang=Math.atan2(rp[1],rp[0]);
        const col=shade(I,rot,code,rp,nv,ang,tone,px,H-1-py);img.set(col,i*3);hit[i]=1;}}});
  // one-pixel dark outline, and a dark backdrop
  const out=new Uint8Array(W*H*3);for(let i=0;i<W*H;i++){if(hit[i]){out.set(img.subarray(i*3,i*3+3),i*3);continue;}const x=i%W,y=(i/W)|0;
    const nb=(x>0&&hit[i-1])||(x<W-1&&hit[i+1])||(y>0&&hit[i-W])||(y<H-1&&hit[i+W]);const c=nb?[10,8,13]:[30,25,36];out.set(c,i*3);}
  return out;}
function png(file,W,H,rgb){const raw=Buffer.alloc((W*3+1)*H);for(let y=0;y<H;y++){raw[y*(W*3+1)]=0;Buffer.from(rgb.buffer,rgb.byteOffset+y*W*3,W*3).copy(raw,y*(W*3+1)+1);}
  const crcT=[];for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;crcT[n]=c>>>0;}
  const crc=b=>{let c=0xffffffff;for(const v of b)c=crcT[(c^v)&255]^(c>>>8);return(c^0xffffffff)>>>0;};
  const ch=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(t),d]),c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c]);};
  const ih=Buffer.alloc(13);ih.writeUInt32BE(W,0);ih.writeUInt32BE(H,4);ih[8]=8;ih[9]=2;
  fs.writeFileSync(file,Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),ch('IHDR',ih),ch('IDAT',zlib.deflateSync(raw)),ch('IEND',Buffer.alloc(0))]));}
function scaleUp(img,W,H,k){const o=new Uint8Array(W*k*H*k*3);for(let y=0;y<H*k;y++)for(let x=0;x<W*k;x++){const s=((y/k|0)*W+(x/k|0))*3,d=(y*W*k+x)*3;o[d]=img[s];o[d+1]=img[s+1];o[d+2]=img[s+2];}return o;}
module.exports={render,png,scaleUp,PAL};
