(function(){
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const ramp=st=>{const s=st.map(hex),o=[];for(let i=0;i<8;i++){const t=i/7*(s.length-1),k=Math.min(Math.floor(t),s.length-2),f=t-k;o.push(s[k].map((v,j)=>Math.round(v+(s[k+1][j]-v)*f)));}return o;};
const SK=ramp(['#efc9a0','#c08a68','#84554c','#452d3c','#18121f']),CL=ramp(['#9495aa','#5c5d75','#30314a','#12111e']),NR=ramp(['#f4dfcd','#d2a999','#986e6c','#54394b','#1a1422']).map((c,i)=>c.map((v,j)=>Math.round(SK[i][j]+(v-SK[i][j])*.4)));
const RAMPS=[SK,CL,NR],LUT=new Map();RAMPS.forEach((r,ri)=>r.forEach((c,i)=>{const k=c[0]<<16|c[1]<<8|c[2];if(!LUT.has(k))LUT.set(k,[ri,i]);}));
const $=id=>document.getElementById(id),W=72,H=88,cv=$('mbl-cv'),ctx=cv.getContext('2d'),img=ctx.createImageData(W,H);
const renderer=new THREE.WebGLRenderer({antialias:false,alpha:true});renderer.setSize(W,H);renderer.setPixelRatio(1);
const rt=new THREE.WebGLRenderTarget(W,H,{minFilter:THREE.NearestFilter,magFilter:THREE.NearestFilter});
const scene=new THREE.Scene(),cam=new THREE.OrthographicCamera(-1,1,1,-1,.1,20);
const pv=r=>r.map(c=>new THREE.Vector3(c[0]/255,c[1]/255,c[2]/255));
const U={pal:{value:pv(SK)},pal2:{value:pv(CL)},pal3:{value:pv(NR)},keyDir:{value:new THREE.Vector3()},amb:{value:.13},hx:{value:[0,1,2,3,4,5,6,7].map(()=>new THREE.Vector3())}};
const VS='attribute vec4 nl;attribute vec3 rest;varying vec3 vN,vR;varying vec4 vL;void main(){vN=normalMatrix*normal;vR=rest;vL=nl;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}';
const FS='precision highp float;varying vec3 vN,vR;varying vec4 vL;uniform vec3 pal[8];uniform vec3 pal2[8];uniform vec3 pal3[8];uniform vec3 keyDir;uniform float amb;uniform vec3 hx[8];'+
'float b2(vec2 a){a=floor(a);return fract(a.x*.5+a.y*a.y*.75);}float b4(vec2 a){return b2(.5*a)*.25+b2(a);}float q2(float a){return a*a;}float q4(float a){return a*a*a*a;}'+
'void td(float zk,float vk,float u,float v,inout vec3 g){float t=clamp((v+.004)/(vk+.004),0.,1.),u0=.004+.3*zk,uc=mix(u0,zk,t),d=(u-uc)/.0028,e=exp(-d*d),fa=(1.-smoothstep(-.03,-.01,v))*smoothstep(vk-.006,vk+.006,v),sl=(zk-u0)/(vk+.004);'+
'g.x-=1.1*fa*d*e;g.y+=1.1*fa*d*e*sl;float du=(u-zk)/.008,dv=(v-vk-.004)/.008,ek=exp(-du*du-dv*dv);g.x-=du*ek;g.y-=dv*ek;}'+
'void vn(float a,float b,float c,float f,float p,float va,float vb,float u,float v,inout vec3 g){float uc=a+b*v+c*sin(f*v+p),d=(u-uc)/.0034,e=exp(-d*d),fa=smoothstep(va,va+.012,v)*(1.-smoothstep(vb-.012,vb,v)),k=.9*fa*d*e;g.x-=k;g.y+=k*(b+c*f*cos(f*v+p));}'+
'void ft(float d0,float d1,float amp,float u,float t,float rf,inout vec3 g){float xi=-.006+(d0+.006)*t/d1,d=(u-xi)/.0036,k=amp*rf/.0036*2.*d*exp(-d*d);g.x-=k;g.y+=k*(d0+.006)/d1;}'+
'void cu(float a,float b,float c,float f,float p,float ua,float ub,float u,float v,inout vec3 g){float vc=a+b*u+c*sin(f*u+p),d=(v-vc)/.002,e=exp(-d*d),fa=smoothstep(ua,ua+.008,u)*(1.-smoothstep(ub-.008,ub,u)),k=1.1*fa*d*e;g.y+=k;g.x-=k*(b+c*f*cos(f*u+p));g.z+=fa*e;}'+
'void main(){vec3 n=normalize(vN);float crs=0.;'+
'if(vL.w>3.5){float u=vL.x,v=vL.y,sd=vL.z,kk=abs(sd)*1.3;vec3 g=vec3(0.),Tu,Tv;'+
'if(vL.w>5.5){float rf=.046-.32*(v-.04);ft(-.028,.142,.085,u,v,rf,g);ft(-.006,.148,.065,u,v,rf,g);ft(.011,.143,.06,u,v,rf,g);ft(.026,.134,.055,u,v,rf,g);ft(.040,.121,.05,u,v,rf,g);'+
'kk=sd*.75*clamp((v-.03)/.03,0.,1.)*clamp((.14-v)/.035,0.,1.);Tu=vL.w>6.5?hx[6]:hx[4];Tv=vL.w>6.5?hx[7]:hx[5];}else{'+
'if(sd>0.){td(.036,-.098,u,v,g);td(.014,-.102,u,v,g);td(-.008,-.099,u,v,g);td(-.029,-.091,u,v,g);vn(-.0319,-.397,.003,110.,0.,-.09,-.002,u,v,g);vn(.0008,.233,0.,0.,0.,-.088,-.05,u,v,g);vn(.01905,-.119,.0025,140.,1.,-.078,-.004,u,v,g);}'+
'else{cu(-.08556,-.339,.003,50.7,2.03,-.043,.024,u,v,g);cu(-.06,-.25,-.0025,52.,1.,-.022,.042,u,v,g);cu(-.007,0.,.0015,60.,1.57,-.03,.03,u,v,g);cu(.001,0.,.0012,70.,.4,-.026,.026,u,v,g);'+
'float t=clamp((v+.068)/.056,0.,1.),uc=.006+.034*pow(1.-t,1.8),d=(u-uc)/.002,e=exp(-d*d),fa=smoothstep(-.07,-.062,v)*(1.-smoothstep(-.02,-.012,v)),k=1.1*fa*d*e;g.x+=k;g.y+=k*.034*1.8*pow(1.-t,.8)/.056;g.z+=fa*e;}'+
'Tu=vL.w>4.5?hx[2]:hx[0];Tv=vL.w>4.5?hx[3]:hx[1];crs=abs(sd)*g.z;}n=normalize(n-kk*(g.x*Tu+g.y*Tv));}'+
'float I=amb+.98*max(dot(n,keyDir),0.)+.08*max(n.x*.7-n.y*.2+n.z*.2,0.)-.13*crs;'+
'float nv=vL.w<1.5?vL.z:0.;bool nail=false;float rim=0.;'+
'if(nv>.05){float d=atan(vL.y,vL.x);if(vL.w>.5){nail=q4((nv-.61)/.31)+q4(d/.98)<1.;if(!nail&&q4((nv-.575)/.355)+q4(d/1.16)<1.)rim=2.;}'+
'else{nail=q2((nv-.55)/.32)+q2(d/.85)<1.;if(!nail&&q2((nv-.55)/.39)+q2(d/1.04)<1.)rim=1.;}}'+
'if(nail)I+=.11;if(vL.w>1.5&&vL.w<3.5)I-=.5*vL.x;'+
'I+=(b4(gl_FragCoord.xy)-.5)*.14;bool cl=vR.y>.835&&vR.y<1.035&&abs(vR.x)<.25;float cf=0.;'+
'if(vL.w>2.5&&vL.w<3.5){if(vR.z>.05&&vR.y>1.28&&vR.y<1.35){float nd=length(vec2(abs(vR.x)-.102,vR.y-1.314));if(nd<.016)rim=max(rim,nd<.010?2.:1.);}'+
'if(vR.z<-.06){float cx=vR.x/.0055;cf=.38*exp(-cx*cx)*smoothstep(.872,.9,vR.y)*(1.-smoothstep(.93,.98,vR.y));}}'+
'float ix=min(floor(clamp((1.1-(I-cf))/1.1,0.,.999)*8.)+(cl?1.:0.)+rim,7.);vec3 c=pal[0];'+
'for(int i=0;i<8;i++){if(float(i)==ix){c=nail?pal3[i]:(cl?pal2[i]:pal[i]);}}gl_FragColor=vec4(c,1.);}';
const mat=new THREE.ShaderMaterial({uniforms:U,vertexShader:VS,fragmentShader:FS});
const parts=MaleBody1.build(),rig=makeRig(parts,MaleBody1.SPEC),geos=[],spin=new THREE.Group(),hold=new THREE.Group();spin.add(hold);scene.add(spin);
parts.forEach(p=>{const g=new THREE.BufferGeometry(),n=p.P.length/3,L=p.L||new Float32Array(n*4);
 g.setAttribute('position',new THREE.BufferAttribute(p.P,3));g.setAttribute('normal',new THREE.BufferAttribute(p.N,3));g.setAttribute('rest',new THREE.BufferAttribute(p.P0,3));g.setAttribute('nl',new THREE.BufferAttribute(L,4));
 g.setIndex(new THREE.BufferAttribute(p.I,1));const m=new THREE.Mesh(g,mat);m.frustumCulled=false;hold.add(m);geos.push(g);});
rig.fingers(0);const hp=rig.jointPos(rig.handL);
const ZOOMS=[['shoulders',[0,1.45,0],.38],['tall',[0,1.15,0],1.2],['full',[0,.9,0],.95],['upper',[0,1.3,0],.5],['arms',[0,1.2,0],.36],['head',[0,1.58,0],.26],['hand',[hp[0],hp[1]+.07,hp[2]],.15],['legs',[0,.47,0],.5],['hips',[0,.93,0],.3],['feet',[0,.14,.08],.26,.45]];
const VIEWS=[['front',0],['three-quarter',-.6],['side',-1.5708],['back',Math.PI]];
const ANIMS=['head','arms','fingers','wrists','wave','idle','walk','toes'],DEFZ={head:5,arms:1,fingers:6,wrists:4,wave:3,idle:3,walk:2,toes:9};
let anim='toes',zi=9,vi=0,yaw=0,tilt=0,turn=false,drag=false,lx=0,ta=0,acc=0,last=0,dirty=true;
function setZoom(){const z=ZOOMS[zi],hw=z[2]*W/H;cam.left=-hw;cam.right=hw;cam.top=z[2];cam.bottom=-z[2];cam.position.set(0,z[1][1],8);cam.updateProjectionMatrix();hold.position.set(-z[1][0],0,-z[1][2]);tilt=z[3]||0;spin.rotation.x=tilt;$('mbl-zoom').textContent='Zoom: '+z[0];dirty=true;}
function setAnim(a,keepZoom){anim=a;ANIMS.forEach(k=>{const b=$('mbl-a-'+k),on=k===a;b.setAttribute('aria-pressed',on?'true':'false');b.style.background=on?'var(--bg-accent)':'transparent';b.style.color=on?'var(--text-accent)':'var(--text-primary)';});if(!keepZoom){zi=DEFZ[a];setZoom();}dirty=true;}
ANIMS.forEach(k=>{$('mbl-a-'+k).onclick=()=>setAnim(k);});
cv.onpointerdown=e=>{drag=true;lx=e.clientX;turn=false;$('mbl-turn').setAttribute('aria-pressed','false');try{cv.setPointerCapture(e.pointerId);}catch(err){}};
cv.onpointermove=e=>{if(drag){yaw+=(e.clientX-lx)*.012;lx=e.clientX;dirty=true;}};cv.onpointerup=()=>{drag=false;};cv.onpointercancel=()=>{drag=false;};
$('mbl-zoom').onclick=()=>{zi=(zi+1)%ZOOMS.length;setZoom();};
$('mbl-view').onclick=()=>{vi=(vi+1)%VIEWS.length;turn=false;yaw=VIEWS[vi][1];$('mbl-view').textContent='View: '+VIEWS[vi][0];dirty=true;};
$('mbl-turn').onclick=()=>{turn=!turn;$('mbl-turn').setAttribute('aria-pressed',turn?'true':'false');};
$('mbl-speed').oninput=()=>{$('mbl-speed-out').textContent=Math.round($('mbl-speed').value)+'%';};
$('mbl-key').oninput=()=>{$('mbl-key-out').textContent=Math.round($('mbl-key').value)+'°';dirty=true;};
setAnim('toes',true);setZoom();
const px=new Uint8Array(W*H*4),RI=new Int8Array(W*H),IX=new Uint8Array(W*H);
function draw(){
 rig[anim](ta);geos.forEach(g=>{g.attributes.position.needsUpdate=true;g.attributes.normal.needsUpdate=true;});
 spin.rotation.y=yaw;{const h=rig.handAxes(),cy=Math.cos(yaw),sy=Math.sin(yaw),ct=Math.cos(tilt),st=Math.sin(tilt);for(let i=0;i<8;i++){const X=h[i][0]*cy+h[i][2]*sy,Y=h[i][1],Z=-h[i][0]*sy+h[i][2]*cy;U.hx.value[i].set(X,Y*ct-Z*st,Y*st+Z*ct);}}const a=$('mbl-key').value*Math.PI/180;U.keyDir.value.set(Math.sin(a)*.8,.7,Math.cos(a)*.55).normalize();
 renderer.setRenderTarget(rt);renderer.setClearColor(0,0);renderer.clear();renderer.render(scene,cam);
 renderer.readRenderTargetPixels(rt,0,0,W,H,px);renderer.setRenderTarget(null);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const s=((H-1-y)*W+x)*4,i=y*W+x;
  if(px[s+3]<128){RI[i]=-1;continue;}
  let e=LUT.get(px[s]<<16|px[s+1]<<8|px[s+2]);
  if(!e){let bd=1e9;RAMPS.forEach((r,ri)=>r.forEach((c,k)=>{const d=(c[0]-px[s])**2+(c[1]-px[s+1])**2+(c[2]-px[s+2])**2;if(d<bd){bd=d;e=[ri,k];}}));}
  let ix=e[1];const h=Math.sin(x*12.9898+y*78.233)*43758.5453,f=h-Math.floor(h);
  if(f<.07)ix=Math.max(0,ix-1);else if(f>.93)ix=Math.min(7,ix+1);RI[i]=e[0];IX[i]=ix;}
 const D=img.data;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x,o=i*4;
  if(RI[i]>=0){const c=RAMPS[RI[i]][IX[i]];D[o]=c[0];D[o+1]=c[1];D[o+2]=c[2];D[o+3]=255;continue;}
  let nr=-1;if(x>0&&RI[i-1]>=0)nr=RI[i-1];else if(x<W-1&&RI[i+1]>=0)nr=RI[i+1];else if(y>0&&RI[i-W]>=0)nr=RI[i-W];else if(y<H-1&&RI[i+W]>=0)nr=RI[i+W];
  if(nr>=0){const c=RAMPS[nr][7];D[o]=c[0]*.6;D[o+1]=c[1]*.6;D[o+2]=c[2]*.6;D[o+3]=255;}else D[o+3]=0;}
 ctx.putImageData(img,0,0);}
function frame(now){if(!last)last=now;acc+=Math.min(400,now-last);last=now;
 while(acc>=83.333){acc-=83.333;ta+=$('mbl-speed').value/1200;if(turn)yaw+=.07;dirty=true;}
 if(dirty){dirty=false;draw();}requestAnimationFrame(frame);}
requestAnimationFrame(frame);
})();
