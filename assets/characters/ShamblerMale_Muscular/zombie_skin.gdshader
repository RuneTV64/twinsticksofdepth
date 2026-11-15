// ShamblerMale_Muscular skin shader for Godot 4. Built from the MaleBody_Muscular skin shader: same 8-shade banded lighting,
// dither and drawn details (nails, tendons, veins, creases, shorts), with dead skin, decay, raw flesh and bone.
// NOT yet compiled or run in Godot.
// Data it reads: UV and UV2 (fine coordinates), COLOR (r = shadow amount, g = rest depth, b = rot, a = part code / 15).
// Rot: 0 to .3 dead skin (higher = bruised, veins), .3 to .45 decay rim, .45 to .8 raw flesh (deeper = darker), above .8 bone.
shader_type spatial;
render_mode unshaded;

uniform vec3 key_dir = vec3(-0.46, 0.63, 0.63); // light direction, in view space
uniform float ambient = 0.13;
uniform float pixel_size = 1.0; // screen pixels per art pixel, for the dither pattern

const vec3 SKIN0[8] = vec3[8](vec3(0.6824, 0.6706, 0.5961), vec3(0.5804, 0.5686, 0.4980), vec3(0.4784, 0.4667, 0.4078), vec3(0.3882, 0.3765, 0.3373), vec3(0.3020, 0.2902, 0.2784), vec3(0.2196, 0.2039, 0.2353), vec3(0.1451, 0.1294, 0.1686), vec3(0.0745, 0.0588, 0.0941));
const vec3 SKIN1[8] = vec3[8](vec3(0.6196, 0.6510, 0.5176), vec3(0.5216, 0.5569, 0.4314), vec3(0.4235, 0.4627, 0.3529), vec3(0.3373, 0.3765, 0.2941), vec3(0.2588, 0.2941, 0.2431), vec3(0.1882, 0.2157, 0.2039), vec3(0.1294, 0.1373, 0.1490), vec3(0.0745, 0.0588, 0.0941));
const vec3 SKIN2[8] = vec3[8](vec3(0.6706, 0.6039, 0.5804), vec3(0.5686, 0.5020, 0.4902), vec3(0.4706, 0.4000, 0.4039), vec3(0.3804, 0.3098, 0.3333), vec3(0.2980, 0.2314, 0.2706), vec3(0.2157, 0.1647, 0.2196), vec3(0.1451, 0.1098, 0.1608), vec3(0.0745, 0.0588, 0.0941));
const vec3 DECAY[8] = vec3[8](vec3(0.4902, 0.4235, 0.2980), vec3(0.4039, 0.3373, 0.2431), vec3(0.3216, 0.2588, 0.1922), vec3(0.2549, 0.2000, 0.1647), vec3(0.1922, 0.1490, 0.1412), vec3(0.1373, 0.1020, 0.1176), vec3(0.0941, 0.0706, 0.0941), vec3(0.0588, 0.0431, 0.0667));
const vec3 FLESH[8] = vec3[8](vec3(0.7608, 0.4000, 0.3373), vec3(0.6549, 0.3137, 0.2745), vec3(0.5451, 0.2314, 0.2235), vec3(0.4314, 0.1725, 0.2000), vec3(0.3255, 0.1216, 0.1725), vec3(0.2275, 0.0863, 0.1412), vec3(0.1490, 0.0627, 0.1059), vec3(0.0745, 0.0392, 0.0706));
const vec3 BONE[8] = vec3[8](vec3(0.9255, 0.8863, 0.7608), vec3(0.8431, 0.7961, 0.6588), vec3(0.7529, 0.6941, 0.5529), vec3(0.6353, 0.5765, 0.4471), vec3(0.5098, 0.4549, 0.3608), vec3(0.3765, 0.3294, 0.2902), vec3(0.2431, 0.2078, 0.2078), vec3(0.1098, 0.0902, 0.1255));
const vec3 CLOTH[8] = vec3[8](vec3(0.5255, 0.5176, 0.4902), vec3(0.4510, 0.4431, 0.4196), vec3(0.3765, 0.3686, 0.3490), vec3(0.3098, 0.3020, 0.2941), vec3(0.2431, 0.2314, 0.2471), vec3(0.1804, 0.1725, 0.2000), vec3(0.1294, 0.1176, 0.1529), vec3(0.0745, 0.0667, 0.1059));
const vec3 NAIL[8] = vec3[8](vec3(0.7882, 0.7412, 0.5412), vec3(0.6588, 0.6118, 0.4471), vec3(0.5333, 0.4902, 0.3608), vec3(0.4157, 0.3725, 0.3020), vec3(0.3059, 0.2627, 0.2471), vec3(0.2000, 0.1647, 0.2000), vec3(0.1294, 0.1059, 0.1451), vec3(0.0706, 0.0549, 0.0863));

instance uniform int skin_tone : hint_range(0, 2) = 0; // 0 grey, 1 green, 2 bruised. The spawner sets this per shambler.

float b2(vec2 a){a=floor(a);return fract(a.x*0.5+a.y*a.y*0.75);}
float b4(vec2 a){return b2(0.5*a)*0.25+b2(a);}
float q2(float a){return a*a;}
float q4(float a){return a*a*a*a;}
void td(float zk,float vk,float u,float v,inout vec3 g){float t=clamp((v+0.004)/(vk+0.004),0.0,1.0),u0=0.004+0.3*zk,uc=mix(u0,zk,t),d=(u-uc)/0.0028,e=exp(-d*d),fa=(1.0-smoothstep(-0.03,-0.01,v))*smoothstep(vk-0.006,vk+0.006,v),sl=(zk-u0)/(vk+0.004);g.x-=1.1*fa*d*e;g.y+=1.1*fa*d*e*sl;float du=(u-zk)/0.008,dv=(v-vk-0.004)/0.008,ek=exp(-du*du-dv*dv);g.x-=du*ek;g.y-=dv*ek;}
void vn(float a,float b,float c,float f,float p,float va,float vb,float u,float v,inout vec3 g){float uc=a+b*v+c*sin(f*v+p),d=(u-uc)/0.0034,e=exp(-d*d),fa=smoothstep(va,va+0.012,v)*(1.0-smoothstep(vb-0.012,vb,v)),k=0.9*fa*d*e;g.x-=k;g.y+=k*(b+c*f*cos(f*v+p));}
void ft(float d0,float d1,float amp,float u,float t,float rf,inout vec3 g){float xi=-0.006+(d0+0.006)*t/d1,d=(u-xi)/0.0036,k=amp*rf/0.0036*2.0*d*exp(-d*d);g.x-=k;g.y+=k*(d0+0.006)/d1;}
void cu(float a,float b,float c,float f,float p,float ua,float ub,float u,float v,inout vec3 g){float vc=a+b*u+c*sin(f*u+p),d=(v-vc)/0.002,e=exp(-d*d),fa=smoothstep(ua,ua+0.008,u)*(1.0-smoothstep(ub-0.008,ub,u)),k=1.1*fa*d*e;g.y+=k;g.x-=k*(b+c*f*cos(f*u+p));g.z+=fa*e;}

void fragment() {
	vec3 n=normalize(NORMAL);
	float code=floor(COLOR.a*15.0+0.5);
	vec2 uv=UV;
	float w2=UV2.x;
	vec3 rp=vec3(uv.x,uv.y,(COLOR.g-0.5)*0.3);
	float crs=0.0;
	if(code>3.5&&code<7.5){
	float u=uv.x,v=uv.y,sd=w2,kk=abs(sd)*1.3;
	vec3 g=vec3(0.0);
	vec3 dp1=dFdx(VERTEX),dp2=dFdy(VERTEX);
	vec2 d1=dFdx(uv),d2=dFdy(uv);
	float det=d1.x*d2.y-d2.x*d1.y;
	vec3 Tu=vec3(0.0),Tv=vec3(0.0);
	if(abs(det)>0.00000000000001){
	Tu=normalize((dp1*d2.y-dp2*d1.y)/det);
	Tv=normalize((dp2*d1.x-dp1*d2.x)/det);
	}
	if(code>5.5){
	float rf=0.046-0.32*(v-0.04);
	ft(-0.028,0.142,0.085,u,v,rf,g);
	ft(-0.006,0.148,0.065,u,v,rf,g);
	ft(0.011,0.143,0.06,u,v,rf,g);
	ft(0.026,0.134,0.055,u,v,rf,g);
	ft(0.040,0.121,0.05,u,v,rf,g);
	kk=sd*0.75*clamp((v-0.03)/0.03,0.0,1.0)*clamp((0.14-v)/0.035,0.0,1.0);
	}
	else{
	if(sd>0.0){
	td(0.036,-0.098,u,v,g);
	td(0.014,-0.102,u,v,g);
	td(-0.008,-0.099,u,v,g);
	td(-0.029,-0.091,u,v,g);
	vn(-0.0319,-0.397,0.003,110.0,0.0,-0.09,-0.002,u,v,g);
	vn(0.0008,0.233,0.0,0.0,0.0,-0.088,-0.05,u,v,g);
	vn(0.01905,-0.119,0.0025,140.0,1.0,-0.078,-0.004,u,v,g);
	}
	else{
	cu(-0.08556,-0.339,0.003,50.7,2.03,-0.043,0.024,u,v,g);
	cu(-0.06,-0.25,-0.0025,52.0,1.0,-0.022,0.042,u,v,g);
	cu(-0.007,0.0,0.0015,60.0,1.57,-0.03,0.03,u,v,g);
	cu(0.001,0.0,0.0012,70.0,0.4,-0.026,0.026,u,v,g);
	float t=clamp((v+0.068)/0.056,0.0,1.0),uc=0.006+0.034*pow(1.0-t,1.8),d=(u-uc)/0.002,e=exp(-d*d),fa=smoothstep(-0.07,-0.062,v)*(1.0-smoothstep(-0.02,-0.012,v)),k=1.1*fa*d*e;
	g.x+=k;
	g.y+=k*0.034*1.8*pow(1.0-t,0.8)/0.056;
	g.z+=fa*e;
	}
	crs=abs(sd)*g.z;
	}
	n=normalize(n-kk*(g.x*Tu+g.y*Tv));
	}
	float I=ambient+0.98*max(dot(n,normalize(key_dir)),0.0)+0.08*max(n.x*0.7-n.y*0.2+n.z*0.2,0.0)-0.13*crs;
	float nv=code<1.5?w2:0.0;
	bool nail=false;
	float rim=0.0;
	if(nv>0.05){
	float d=atan(uv.y,uv.x);
	if(code>0.5){
	nail=q4((nv-0.61)/0.31)+q4(d/0.98)<1.0;
	if(!nail&&q4((nv-0.575)/0.355)+q4(d/1.16)<1.0)rim=2.0;
	}
	else{
	nail=q2((nv-0.55)/0.32)+q2(d/0.85)<1.0;
	if(!nail&&q2((nv-0.55)/0.39)+q2(d/1.04)<1.0)rim=1.0;
	}
	}
	if(nail)I+=0.11;
	if(code>1.5&&code<3.5)I-=0.5*COLOR.r;
	I+=(b4(floor(FRAGCOORD.xy/pixel_size))-0.5)*0.14;
	bool cl=((code>2.5&&code<3.5)||code>7.5)&&rp.y>0.835&&rp.y<1.035&&abs(rp.x)<0.25;
	float cf=0.0;
	if(code>2.5&&code<3.5){
	if(rp.z>0.05&&rp.y>1.28&&rp.y<1.35){
	float nd=length(vec2(abs(rp.x)-0.102,rp.y-1.314));
	if(nd<0.016)rim=max(rim,nd<0.010?2.0:1.0);
	}
	if(rp.z<-0.06){
	float cx=rp.x/0.0055;
	cf=0.38*exp(-cx*cx)*smoothstep(0.872,0.9,rp.y)*(1.0-smoothstep(0.93,0.98,rp.y));
	}
	}
	float rot=COLOR.b;
	float base=floor(clamp((1.1-(I-cf))/1.1,0.0,0.999)*8.0);
	int mat=0;
	float ix=base;
	if(rot>0.8){mat=5;}
	else if(rot>0.45){mat=4;ix=base+(rot>0.72?2.0:(rot>0.6?1.0:0.0));}
	else if(rot>0.3){mat=3;}
	else if(nail){mat=2;ix=base+rim;}
	else if(cl){mat=1;ix=base+1.0+rim;}
	else{ix=base+rim+(rot>0.24?2.0:(rot>0.16?1.0:0.0));}
	ix=min(ix,7.0);
	vec3 c=SKIN0[0];
	for(int i=0;i<8;i++){
	if(float(i)==ix){
	if(mat==5)c=BONE[i];
	else if(mat==4)c=FLESH[i];
	else if(mat==3)c=DECAY[i];
	else if(mat==2)c=NAIL[i];
	else if(mat==1)c=CLOTH[i];
	else if(skin_tone==1)c=SKIN1[i];
	else if(skin_tone==2)c=SKIN2[i];
	else c=SKIN0[i];
	}
	}
	ALBEDO=pow(c,vec3(2.2));
}
