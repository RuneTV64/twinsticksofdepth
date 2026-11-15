// Builds zombie_skin.gdshader from MaleBody_Muscular's skin shader: same lighting, drawn details and dither,
// with dead skin (three tones), decay, raw flesh and bone picked by the rot amount in COLOR.b.
const fs=require('fs'),{PAL}=require('./preview.js');
const src=fs.readFileSync(process.argv[2],'utf8');
const arr=(n,r)=>`const vec3 ${n}[8] = vec3[8](${r.map(c=>`vec3(${c.map(v=>(v/255).toFixed(4)).join(', ')})`).join(', ')});`;
let s=src;
s=s.replace(/^\/\/ MaleBody_Muscular skin shader[\s\S]*?shader_type spatial;/m,
`// ShamblerMale_Muscular skin shader for Godot 4. Built from the MaleBody_Muscular skin shader: same 8-shade banded lighting,
// dither and drawn details (nails, tendons, veins, creases, shorts), with dead skin, decay, raw flesh and bone.
// NOT yet compiled or run in Godot.
// Data it reads: UV and UV2 (fine coordinates), COLOR (r = shadow amount, g = rest depth, b = rot, a = part code / 15).
// Rot: 0 to .3 dead skin (higher = bruised, veins), .3 to .45 decay rim, .45 to .8 raw flesh (deeper = darker), above .8 bone.
shader_type spatial;`);
s=s.replace(/^const vec3 PAL\[8\].*\n^const vec3 PAL2\[8\].*\n^const vec3 PAL3\[8\].*$/m,
[arr('SKIN0',PAL.skin[0]),arr('SKIN1',PAL.skin[1]),arr('SKIN2',PAL.skin[2]),arr('DECAY',PAL.decay),arr('FLESH',PAL.flesh),arr('BONE',PAL.bone),arr('CLOTH',PAL.cloth),arr('NAIL',PAL.nail)].join('\n')
+'\n\ninstance uniform int skin_tone : hint_range(0, 2) = 0; // 0 grey, 1 green, 2 bruised. The spawner sets this per shambler.');
const oldTail=/\tfloat ix=min\(floor[\s\S]*?ALBEDO=pow\(c,vec3\(2\.2\)\);/;
if(!oldTail.test(s))throw new Error('tail not found');
s=s.replace(oldTail,
`	float rot=COLOR.b;
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
	ALBEDO=pow(c,vec3(2.2));`);
if(/PAL[23]?\[/.test(s))throw new Error('old palette still referenced');
fs.writeFileSync(process.argv[3],s);console.log('wrote',process.argv[3],s.length,'chars');
