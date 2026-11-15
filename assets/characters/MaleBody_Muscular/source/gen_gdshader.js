const fs=require('fs'),v=fs.readFileSync('./widget/viewer_mbl.js','utf8');
const FS=eval(v.slice(v.indexOf("const FS=")+9,v.indexOf("const mat=")).trim().replace(/;$/,''));
const fix=s=>s.replace(/(?<![\w.])\.(\d)/g,'0.$1').replace(/(?<![\w.])(\d+)\.(?!\d)/g,'$1.0');
const fnText=name=>{const i=FS.indexOf(name);let d=0,j=FS.indexOf('{',i);for(;;j++){if(FS[j]==='{')d++;if(FS[j]==='}'){d--;if(!d)break;}}return FS.slice(i,j+1);};
const fns=['float b2(','float b4(','float q2(','float q4(','void td(','void vn(','void ft(','void cu('].map(fnText);
let main=FS.slice(FS.indexOf('void main(){')+12,FS.lastIndexOf('}'));
const sub=(a,b)=>{if(!main.includes(a))throw new Error('missing: '+a);main=main.split(a).join(b);};
sub('vec3 n=normalize(vN);','vec3 n=normalize(NORMAL);float code=floor(COLOR.a*15.0+0.5);vec2 uv=UV;float w2=UV2.x;vec3 rp=vec3(uv.x,uv.y,(COLOR.g-0.5)*0.3);');
sub('vec3 g=vec3(0.),Tu,Tv;','vec3 g=vec3(0.);vec3 dp1=dFdx(VERTEX),dp2=dFdy(VERTEX);vec2 d1=dFdx(uv),d2=dFdy(uv);float det=d1.x*d2.y-d2.x*d1.y;vec3 Tu=vec3(0.),Tv=vec3(0.);if(abs(det)>0.00000000000001){Tu=normalize((dp1*d2.y-dp2*d1.y)/det);Tv=normalize((dp2*d1.x-dp1*d2.x)/det);}');
sub('Tu=vL.w>6.5?hx[6]:hx[4];Tv=vL.w>6.5?hx[7]:hx[5];','');sub('Tu=vL.w>4.5?hx[2]:hx[0];Tv=vL.w>4.5?hx[3]:hx[1];','');
sub('if(vL.w>3.5){','if(code>3.5&&code<7.5){');
sub('if(vL.w>1.5&&vL.w<3.5)I-=.5*vL.x;','if(code>1.5&&code<3.5)I-=.5*COLOR.r;');
sub('bool cl=vR.y>.835&&vR.y<1.035&&abs(vR.x)<.25;','bool cl=((code>2.5&&code<3.5)||code>7.5)&&rp.y>.835&&rp.y<1.035&&abs(rp.x)<.25;');
sub('I=amb+','I=ambient+');sub('keyDir','normalize(key_dir)');sub('gl_FragCoord.xy','floor(FRAGCOORD.xy/pixel_size)');sub('gl_FragColor=vec4(c,1.);','ALBEDO=pow(c,vec3(2.2));');
main=main.replace(/vL\.x/g,'uv.x').replace(/vL\.y/g,'uv.y').replace(/vL\.z/g,'w2').replace(/vL\.w/g,'code').replace(/vR\./g,'rp.').replace(/pal3\[/g,'PAL3[').replace(/pal2\[/g,'PAL2[').replace(/pal\[/g,'PAL[');
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const ramp=st=>{const s=st.map(hex),o=[];for(let i=0;i<8;i++){const t=i/7*(s.length-1),k=Math.min(Math.floor(t),s.length-2),f=t-k;o.push(s[k].map((v,j)=>Math.round(v+(s[k+1][j]-v)*f)));}return o;};
const SK=ramp(['#efc9a0','#c08a68','#84554c','#452d3c','#18121f']),CL=ramp(['#9495aa','#5c5d75','#30314a','#12111e']),NR=ramp(['#f4dfcd','#d2a999','#986e6c','#54394b','#1a1422']).map((c,i)=>c.map((v,j)=>Math.round(SK[i][j]+(v-SK[i][j])*.4)));
const arr=(n,r)=>'const vec3 '+n+'[8] = vec3[8]('+r.map(c=>'vec3('+c.map(x=>(x/255).toFixed(4)).join(', ')+')').join(', ')+');';
const body=fix(main).replace(/;/g,';\n\t').replace(/\{/g,'{\n\t').replace(/\}/g,'}\n\t');
const out=`// MaleBody_Muscular skin shader for Godot 4. 8-shade banded lighting plus the drawn details:
// nails, hand tendons, veins and palm creases, foot tendons, armpit shadow, ear bowl, nipples and shorts.
// Generated from the tested viewer shader. NOT yet compiled or run in Godot.
// Data it reads: UV and UV2 (fine coordinates), COLOR (r = shadow amount, g = rest depth, a = part code / 15).
shader_type spatial;
render_mode unshaded;

uniform vec3 key_dir = vec3(-0.46, 0.63, 0.63); // light direction, in view space
uniform float ambient = 0.13;
uniform float pixel_size = 1.0; // screen pixels per art pixel, for the dither pattern

${arr('PAL',SK)}
${arr('PAL2',CL)}
${arr('PAL3',NR)}

${fns.map(f=>fix(f)).join('\n')}

void fragment() {
	${body.trim()}
}
`;
fs.writeFileSync('./export/male_body_muscular_skin.gdshader',out);
const bad=[/vL\b/,/vR\b/,/hx\[/,/gl_/,/(?<![\w.])\.\d/,/\d\.(?![\d])/,/precision/,/varying/].filter(r=>r.test(out)).map(String);
console.log('bytes',out.length,'| braces',out.split('{').length===out.split('}').length,'| parens',out.split('(').length===out.split(')').length,'| leftovers',bad.join(' ')||'none');
