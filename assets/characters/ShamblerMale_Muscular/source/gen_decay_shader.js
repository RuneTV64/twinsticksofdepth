// Builds zombie_decay.gdshader from zombie_skin.gdshader: the same 8-shade banded lighting, dither and drawn
// details (nails, tendons, veins, creases, shorts), colored by how long the body has been dead (Freshness).
// Every zombie was a person, so it starts from that person's living skin tone, freckles, vitiligo, age and hair
// (the same data as the living skin shader, from skin_tones.js), drained and grey when fresh, waxy in rigor, and
// evened out by the rot from bloat on.
// Usage: node gen_decay_shader.js zombie_skin.gdshader zombie_decay.gdshader
const fs = require('fs');
const src = fs.readFileSync(process.argv[2], 'utf8');
const ST = require('./skin_tones.js');
// where the anatomy maps sit, where the limb bones run and the cut of the neck: written by gen_anatomy_map.js
const AC = JSON.parse(fs.readFileSync(require('path').join(__dirname, 'anatomy_consts.json'), 'utf8')), f4 = v => v.toFixed(4), v3 = a => 'vec3(' + a.map(f4).join(',') + ')';

// ---- palettes: each is 8 shades, interpolated from highlight to near-black. Warm highlights, cool purple shadows.
// Natural colors: the setting supplies the mood, so nothing is darkened just to look gritty.
const { hex, ramp } = ST;
const toHex = c => '#' + c.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
// Death drains a living color before the rot darkens it: with the blood gone from the skin it loses most of its
// saturation and goes PALER, toward an ashen grey (lighter skin goes chalky, deeper skin goes ashen and lighter).
// Fresh is the palest and a little cool; rigor is still pale but waxy. The darkening only starts with the bloat.
const ASH = [206, 202, 200];
const dead = (stops, desat, tint, pale) => stops.map((h, i) => { const c = hex(h), L = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
  const p = (pale + 0.08 * (1 - L / 255)) * (1 - i / stops.length);   // deeper skin lifts a touch more (ashen); the shadow end stays dark
  const tw = Math.pow(L / 255, 1.5);   // the tint shows on light skin; deep skin goes ashen instead
  return toHex(c.map((v, j) => { const g = v + (L - v) * desat + tint[j] * tw; return g + (ASH[j] * (0.55 + 0.45 * L / 255) - g) * p; })); });
const PALLOR = st => dead(st, 0.45, [-4, 0, 6], 0.22);   // freshly turned: drained and pale, a little blue, no green
const WAXY = st => dead(st, 0.4, [6, 5, -8], 0.14);      // rigor: still pale, waxy and yellowed
const RAMPS = [
  ['BLOAT',        ['#7c8763', '#566048', '#373e36', '#1e2128', '#0b0a10']],   // green discoloration, from the belly out
  ['PUTRID',       ['#6c6c4f', '#49463a', '#342a30', '#1c1420', '#09070c']],   // active decay: olive-black, purple shadows
  ['DRIED',        ['#775b43', '#503c2e', '#342521', '#1c1418', '#09070b']],   // leathery, mummified
  ['LIVOR',        ['#6b4a57', '#4d3443', '#342332', '#1d1422', '#0b0810']],   // lividity: blood pooled low in the body
  ['MARBLE',       ['#4e5843', '#353c33', '#24252a', '#14121b', '#07060b']],   // marbling: the veins going dark
  // wounds by stage
  ['CLOT',         ['#782c2a', '#531a20', '#35101a', '#1c0a12', '#0a0509']],   // fresh wound rim: clotted blood
  ['DECAY',        ['#6a5b40', '#493b2c', '#2f2622', '#1a141a', '#0a080d']],   // old wound rim
  ['FLESH_FRESH',  ['#b0463c', '#7e262c', '#521624', '#2d0c18', '#0f050a']],   // wet red
  ['FLESH',        ['#a0574a', '#743535', '#4b1f2a', '#29111d', '#0d080d']],
  ['FLESH_ROT',    ['#735a50', '#523c3c', '#36262c', '#1d151c', '#0a070b']],   // bloated: dusky grey-brown, gone off
  ['FLESH_PUTRID', ['#514736', '#3a332a', '#272223', '#171418', '#08060a']],   // putrid: dark olive-brown
  ['FLESH_DRY',    ['#5d3a2c', '#3f2620', '#291819', '#160d11', '#070508']],   // dried black jerky
  // Bone is never white inside a body: white is sun-bleached bone, long after the flesh has gone. It starts ivory
  // and pink with blood, goes yellow and greasy, is stained dark by the rot, and dries tan-brown.
  ['BONE_FRESH',   ['#dccbbb', '#b49589', '#83635e', '#4c3339', '#190f16']],   // ivory, pink with blood
  ['BONE',         ['#cdb98a', '#a39164', '#716346', '#403630', '#141018']],   // bloated: yellowed and greasy
  ['BONE_PUTRID',  ['#8d8460', '#655e46', '#443f33', '#27232a', '#0d0b10']],   // putrid: stained dark by the rot, olive-brown
  ['BONE_OLD',     ['#987f56', '#715c40', '#4b3d2f', '#2a2126', '#0e0a10']],   // dried: tan-brown, a little lighter than the leathery skin
  // nails, shorts, stains
  ['NAIL_FRESH',   ['#878094', '#5f5870', '#403a4f', '#231e2f', '#0b0a12']],   // blue-purple, no blood flow
  ['NAIL',         ['#ac9f72', '#7c7052', '#504638', '#29222b', '#0d0b12']],
  ['NAIL_DARK',    ['#584939', '#3d3029', '#28201e', '#151114', '#080608']],
  ['CLOTH',        ['#6a6861', '#484641', '#2c2a30', '#110f17']],
  // blood, as it ages: wet and bright, then darker, then clotted, then a dried crust
  ['BLOOD_WET',    ['#b42026', '#82131b', '#540b15', '#2d070e', '#0d0306']],
  ['BLOOD',        ['#6c1c20', '#4c1119', '#310a14', '#19050c', '#070306']],
  ['BLOOD_CLOT',   ['#5c1f1c', '#401416', '#2a0d11', '#16070b', '#070305']],
  ['BLOOD_OLD',    ['#4c3226', '#36221c', '#241517', '#130b0f', '#060406']],   // dried brown-black
  ['MAGGOT',       ['#e3dbbd', '#c0b490', '#8c8164', '#4d453f', '#16121a']],
  // grime: real dirt in its own colors
  ['MUD',          ['#7a6448', '#574634', '#3a2f26', '#201a1a', '#0b090c']],   // wet earth, splashed up the legs
  ['DUST',         ['#b0a58c', '#857b66', '#5a5246', '#312c2c', '#110f13']],   // dry dust, settled on what faces up
  ['GRASS',        ['#66703f', '#48512f', '#2f3524', '#1a1c17', '#09090b']],   // grass and earth stains
  // what's under the skin: the layers of a wound, and the insides built by anatomy.js
  ['FAT',          ['#c9b88a', '#a08e68', '#72624c', '#423834', '#17121a']],   // the yellow layer just under the skin
  ['TENDON',       ['#dccfc2', '#b3a398', '#80726e', '#49414b', '#18141c']],   // sinew: pale strands through the muscle
  ['CARTILAGE',    ['#ddd6c6', '#b3ab9c', '#807a72', '#49454b', '#18151b']],   // costal cartilage: pearly off-white, a little greyer than bone (blue is only how diagrams draw it)
  ['LUNG',         ['#d79096', '#aa6770', '#754051', '#41253b', '#150c18']],
  ['ORGAN',        ['#963c35', '#6c2527', '#46171f', '#260d17', '#0d050b']],   // heart and liver: deep red-brown
  ['GUT',          ['#dca28c', '#ae7667', '#784b4b', '#432b35', '#160e16']],   // stomach and small intestine: pink-tan
  ['COLON',        ['#bd8973', '#906153', '#623d3d', '#37232c', '#130c13']],
  ['OFFAL',        ['#70745a', '#525545', '#393a37', '#212026', '#0c0b0f']],   // bloated: organs gone off, grey-green
  ['ORGAN_PUTRID', ['#4c4b38', '#37362b', '#252523', '#161519', '#08070a']],   // putrid: dark olive-black slime
  ['MUCK',         ['#6b5c3c', '#4a3f2c', '#302820', '#1a1517', '#09070a']],   // the sludge the insides turn to: dark olive-brown
  ['BRAIN',        ['#dcc3b8', '#b3978c', '#80676a', '#483747', '#17101a']],   // pale pink-grey
];
// The organs in rigor: the blood has settled out of them and they've gone dull and dusky, each still its own color.
const dusk = st => st.map(h => { const c = hex(h), L = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]; return toHex(c.map((v, j) => ((v + (L - v) * 0.42) * 0.78 + [92, 76, 90][j] * 0.22) * 0.84)); });
for (const n of ['LUNG', 'ORGAN', 'GUT', 'COLON', 'BRAIN']) RAMPS.push([n + '_DUSK', dusk(RAMPS.find(r => r[0] === n)[1])]);
// hair (dull and dusty once dead) and drained vitiligo, shared by every tone
const HAIRS = ST.SHARED.filter(([n]) => n.startsWith('HAIR_'));
const hexOf = r => [r[0], r[3], r[5], r[7]].map(toHex);   // 4 stops back out of an 8-shade ramp
HAIRS.forEach(([n, r]) => RAMPS.push([n, dead(hexOf(r), 0.25, [0, 0, 0], 0.85)]));
RAMPS.push(['VITILIGO_DEAD', PALLOR(hexOf(ST.SHARED.find(([n]) => n === 'VITILIGO')[1]))]);
const TONE0 = RAMPS.length;   // tone t uses TONE0 + t*4 + (0 fresh skin, 1 rigor skin, 2 freckles, 3 age spots)
ST.TONES.forEach(t => { const n = t.name.toUpperCase().replace(/ /g, '_');
  RAMPS.push([n + '_FRESH', PALLOR(t.skin)], [n + '_RIGOR', WAXY(t.skin)], [n + '_FRECKLE', PALLOR(t.freckle)], [n + '_SPOT', PALLOR(t.spot)]); });
// deeper tones go a shade darker again once the rot has evened everyone out
const lum = h => { const c = hex(h); return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]; };
const DEEP = ST.TONES.map(t => lum(t.skin[0]) < 130 ? 1 : 0);
const GREY = ST.TONES.map(t => (t.grey ?? 1));
const vec = c => `vec3(${c.map(v => (v / 255).toFixed(4)).join(', ')})`;
const all = RAMPS.flatMap(([, st]) => ramp(st));
const consts = RAMPS.slice(0, TONE0).map(([n], i) => `const int ${n} = ${i};`).join('\n') + `\nconst int TONES = ${TONE0}; // skin tone t uses ramps TONES + t*4 + (0 fresh skin, 1 rigor skin, 2 freckles, 3 age spots)
const float DEEP[${DEEP.length}] = float[${DEEP.length}](${DEEP.map(v => v.toFixed(1)).join(', ')}); // tones that go a shade darker in the rot
const float GREY_SHOW[${GREY.length}] = float[${GREY.length}](${GREY.map(v => v.toFixed(2)).join(', ')}); // how much grey body hair shows`;
const toneDoc = ST.TONES.map((t, i) => `${i} ${t.name}`).join(', ');
const table = `const vec3 RAMPS[${all.length}] = vec3[${all.length}](\n${RAMPS.map(([n, st], i) => '\t' + ramp(st).map(vec).join(', ') + (i < RAMPS.length - 1 ? ',' : '') + ' // ' + n).join('\n')}\n);`;

// ---- reuse the drawn-detail code from zombie_skin as-is
const a = src.indexOf('float b2(vec2 a)');
const b = src.indexOf('\tfloat rot=COLOR.b;');
if (a < 0 || b < 0) throw new Error('zombie_skin.gdshader layout changed: detail block not found');
let details = src.slice(a, b);
const helpersEnd = details.indexOf('void fragment() {');
const helpers = details.slice(0, helpersEnd), fragHead = details.slice(helpersEnd + 'void fragment() {'.length);

const out = `// Zombie decay shader for Godot 4. Every zombie was a person, so this goes on the base bodies' zombie parts
// (first used by ShamblerMale_Muscular). Same 8-shade banded lighting, dither and drawn details as
// zombie_skin.gdshader, but the skin, wounds, nails and bone are colored by how long the body has been dead.
// Generated by source/gen_decay_shader.js from zombie_skin.gdshader. Compiled and test-rendered in Godot 4.5.
//
// Per-shambler values (instance uniforms, set by shambler.gd from its Freshness):
//   freshness   1 = just turned, 0 = long dead. Stages, with some parts running ahead of the rest:
//                 Fresh    1.00 - 0.88  drained and pale, blood pooling in the feet, hands and back, blue nails
//                 Rigor    0.88 - 0.68  waxy and yellowed, the pooled blood set dark purple
//                 Bloated  0.68 - 0.44  green from the belly out, the veins marbling black, skin starting to slip
//                 Putrid   0.44 - 0.20  olive-black and wet, skin sloughing off in patches, maggots in the wounds
//                 Dried    0.20 - 0.00  leathery brown, the wounds dried black, the bone stained
//   skin_tone, variant, hair_color, look_seed
//               who he was: the same values as the living skin shader (body_living.gdshader), so a person keeps
//               their tone, freckles, vitiligo, age spots and hair when they turn. Clearest while fresh; the rot
//               evens everyone out from bloat on, and hair lasts longest.
//               skin_tone: ${toneDoc}
//               variant: 0 freckles, 1 clean shaven, 2 hairy, 3 old, 4 vitiligo
//               hair_color: 0 blond, 1 ginger, 2 brown, 3 dark, 4 grey
//   decay_seed  any number; moves the blotches, marbling and slipped skin so no two look alike.
//   gore        0..1, how much blood is spattered on the hands, arms and chest, and how freely his wounds have bled.
// Blood runs down from every wound (the model carries where, in UV2.y) and soaks into the shorts, which tear where a
// wound is under them. It ages with him: wet and bright red when he's just turned, darker, then clotted
// maroon-brown, then a dried brown-black crust that flakes away.
// Wounds are layered the way flesh is: torn skin at the edge, a thin band of yellow fat, then muscle with fibers and
// pale sinew, then bone. The insides are painted, not modelled: under each hole in the skin is one inner surface,
// and this shader paints on it what lies there. In the torso that comes from the anatomy map (anatomy_map.gd): ribs,
// cartilage, sternum, collarbone, shoulder blade, spine and hip bone on muscle, and where the wall is torn through,
// the lungs, heart, liver, stomach and intestines behind it. In a limb it's the bone lying in the gouge; in the
// head, the skull and the brain where it's broken open; on a severed neck, the vertebra, cord, windpipe, gullet and
// vessels. Each has its own color while fresh, greying and greening as he rots, dried black at the end, and all of
// it is smeared with blood, clots and muck.
// Data it reads from the mesh: UV and UV2 (fine coordinates), COLOR (r = shadow amount, g = rest depth,
// b = rot, a = part code / 15). Rot: 0 to .3 dead skin, .3 to .45 wound rim, .45 to .8 raw flesh, above .8 bone.
shader_type spatial;
render_mode unshaded;

uniform vec3 key_dir = vec3(-0.46, 0.63, 0.63); // light direction, in view space
uniform float ambient = 0.13;  // the same as the living skin, so the change is all in the skin
uniform float pixel_size = 1.0; // screen pixels per art pixel, for the dither pattern
uniform float grit = 0.08;      // share of pixels nudged a shade lighter or darker, the same as the living skin
// The torso's anatomy, painted into a map (AnatomyMap.texture() from anatomy_map.gd; shambler.gd sets it). Two maps side
// by side, each wrapped round the body (across = direction, down = height): on the left the bones that lie on the
// muscle wall, on the right the organs behind it. R = code * 16 + variant, G = how far from the body's axis that
// thing is (mm), B = a baked shade; the left map's A = where the Destroyed torso's wall is torn through.
uniform sampler2D anatomy_map : filter_nearest, repeat_disable;

instance uniform float freshness : hint_range(0.0, 1.0) = 1.0;
instance uniform int skin_tone = 1;
instance uniform int variant : hint_range(0, 4) = 1;
instance uniform int hair_color : hint_range(0, 4) = 2;
instance uniform float look_seed = 0.0;
instance uniform float decay_seed = 0.0;
instance uniform float gore : hint_range(0.0, 1.0) = 0.5;
instance uniform float grime : hint_range(0.0, 1.0) = 0.5;   // how dirty he is: mud, dust, stains and smears
instance uniform float neck_blood : hint_range(0.0, 1.0) = 0.0;   // blood run down from the neck over the torso: 1 when the head is off

${consts}
${table}

varying vec3 v_body; // rest position on the body in metres (feet at 0, facing +Z), so stains stay on the skin as he moves
varying float v_up;  // how far the surface faces up at rest (rest normal y), for dust settled on what faces up

${helpers}float h13(vec3 p){p=fract(p*0.1031);p+=dot(p,p.zyx+31.32);return fract((p.x+p.y)*p.z);}
float vno(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(h13(i),h13(i+vec3(1,0,0)),f.x),mix(h13(i+vec3(0,1,0)),h13(i+vec3(1,1,0)),f.x),f.y),mix(mix(h13(i+vec3(0,0,1)),h13(i+vec3(1,0,1)),f.x),mix(h13(i+vec3(0,1,1)),h13(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm3(vec3 p){return (vno(p)*0.5+vno(p*2.03+3.1)*0.25+vno(p*4.07+7.7)*0.125)/0.875;}
float rdg(vec3 p){return 1.0-abs(vno(p)*2.0-1.0);}
vec3 pal(int r,float ix){return RAMPS[r*8+int(clamp(ix,0.0,7.0))];}

// the anatomy map at a point in the body: x = code * 16 + variant, y = distance from the axis (m), z = shade, w = torn.
// side: 0 the bones, 1 what's behind them. sel: 0 the torso's maps (round the body's axis), 1 the head's (round the head's own).
vec4 amap(vec3 p,float side,float sel){
	float a,v;
	if(sel<0.5){a=atan(p.x,p.z);v=clamp((${f4(AC.torso.y1)}-p.y)/${f4(AC.torso.y1 - AC.torso.y0)},0.0,0.9999)*${f4(AC.torso.rows / AC.height)};}
	else{a=atan(p.x,p.z-(${f4(AC.head.zc)}));v=${f4(AC.torso.rows / AC.height)}+clamp((${f4(AC.head.y1)}-p.y)/${f4(AC.head.y1 - AC.head.y0)},0.0,0.9999)*${f4(AC.head.rows / AC.height)};}
	vec4 m=texture(anatomy_map,vec2((fract(a/6.2831853+0.5)+side)*0.5,v));
	return vec4(floor(m.r*255.0+0.5),m.g*0.255,m.b,m.a);
}
float arad(vec3 p,float sel){return sel<0.5?length(p.xz):length(vec2(p.x,p.z-(${f4(AC.head.zc)})));}

// the limb bones a wound can go down to, in the body's rest position: ${AC.bones.map(b => b.name).join(', ')}
const vec3 BONE_A[${AC.bones.length}]=vec3[${AC.bones.length}](${AC.bones.map(b => v3(b.a)).join(',')});
const vec3 BONE_B[${AC.bones.length}]=vec3[${AC.bones.length}](${AC.bones.map(b => v3(b.b)).join(',')});
const float BONE_R[${AC.bones.length}]=float[${AC.bones.length}](${AC.bones.map(b => f4(b.r)).join(',')});
// where a line of sight meets a round-ended bone (-1 if it misses)
float capsule(vec3 ro,vec3 rd,vec3 pa,vec3 pb,float ra){
	vec3 ba=pb-pa,oa=ro-pa;
	float baba=dot(ba,ba),bard=dot(ba,rd),baoa=dot(ba,oa),rdoa=dot(rd,oa),oaoa=dot(oa,oa);
	float a=baba-bard*bard,b=baba*rdoa-baoa*bard,c=baba*oaoa-baoa*baoa-ra*ra*baba,h=b*b-a*c;
	if(h>=0.0&&a>1e-9){
		float t=(-b-sqrt(h))/a,y=baoa+t*bard;
		if(y>0.0&&y<baba)return t;
		vec3 oc=y<=0.0?oa:ro-pb;
		b=dot(rd,oc);c=dot(oc,oc)-ra*ra;h=b*b-c;
		if(h>0.0)return -b-sqrt(h);
	}
	return -1.0;
}
// what's in the cut of a severed neck at a spot (x, z): x = how far its top stands above the cut (below -0.5: an open
// tube to look down), y = material, z = rot, w = shade
vec4 neckAt(vec2 q){
	float dv=length(q-vec2(0.0,-0.014)),dw=length(q-vec2(0.0,0.026));
	vec2 gq=(q-vec2(0.0,0.010))/vec2(0.0078,0.0042);
	float dg=dot(gq,gq),dves=length(vec2(abs(q.x)-0.025,q.y-0.014));
	if(length(q-vec2(0.0,-0.030))<0.0042)return vec4(0.002,10.0,0.86,0.1);                 // the spinal cord, in its canal
	if(dv<0.0125||(abs(q.x)<0.0045&&q.y<-0.027&&q.y>-0.048))return vec4(0.004,9.0,dv<0.0065?0.7:0.93,0.0);   // the vertebra and its spine, marrow in the middle
	if(dw<0.0098)return dw>0.0064?vec4(0.003,10.0,0.86,0.05):vec4(-1.0,15.0,0.79,0.9);      // the windpipe: an open ring of cartilage
	if(dg<1.0)return dg>0.3?vec4(0.001,13.0,0.58,0.1):vec4(-1.0,15.0,0.79,0.9);             // the gullet, flattened behind it
	if(dves<0.0042)return dves>0.002?vec4(0.001,12.0,0.7,0.1):vec4(-1.0,15.0,0.79,0.9);     // the big vessels either side
	return vec4(-0.002+0.004*vno(vec3(q.x*150.0,3.0,q.y*150.0)),15.0,0.66,0.15);            // the meat of the neck, uneven
}

void vertex() {
	// the model stores each vertex's rest position in CUSTOM0 (xyz, with the rest normal's y in w). VERTEX here is
	// already posed by the skeleton, so painting from it would leave the patterns hanging in the air as limbs move.
	// A model without that data (all zero) falls back to the posed position.
	bool has_rest = dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.000001;
	v_body = has_rest ? CUSTOM0.xyz : VERTEX;
	v_up = has_rest ? CUSTOM0.w : NORMAL.y;
}

void fragment() {${fragHead}	// ---------------- decay
	float rot=COLOR.b;
	// The insides of the wounds are painted, not modelled, and the painting has depth. Under each hole in the skin is
	// one inner surface, and each kind carries its own part code:
	//  15 the muscle inside a limb, gouged where the wound is: the bone is painted as a round shape standing out of it
	//  14 the inner wall of the torso: bones in front of it and, where it's torn through, organs behind (anatomy map)
	//  13 the skull under the scalp: where it's broken away, the brain below it (anatomy map)
	//  12 the cut of a severed neck: the vertebra standing proud, the open windpipe, gullet and vessels to look into;
	//     on the stump, or (COLOR.g) on the underside of the head that came off
	// For each, the line of sight through this pixel is followed to what it meets first, so near things hide far
	// things and slide across them as the view moves.
	// From here on code is the material: 9 bone, 10 cartilage, 11 lung or brain, 12 heart and liver, 13 stomach and
	// small intestine, 14 colon, 15 muscle; inShade is how far in the body's own shadow it sits; body is where on
	// the body the paint sits (so blood and muck are painted on the thing, not on the surface in front of it).
	float inShade=COLOR.r;
	vec3 body=v_body;
	bool brainPx=false;
	float pool=0.0;                   // how much blood has pooled here (low in the torn belly); below 0: a bone standing clear, with less on it
	if(code>11.5){
		// Which way the eye looks, in the body's own rest space. It's worked out from how this surface is laid out on
		// the screen, so it holds when the skeleton has bent the body.
		vec3 dpx=dFdx(VERTEX),dpy=dFdy(VERTEX),dbx=dFdx(v_body),dby=dFdy(v_body),nv=cross(dpx,dpy);
		vec3 ev=PROJECTION_MATRIX[3][3]>0.5?vec3(0.0,0.0,-1.0):normalize(VERTEX);
		float nn=max(dot(nv,nv),1e-24);
		vec3 rd=normalize(dbx*(dot(cross(dpy,nv),ev)/nn)+dby*(dot(cross(nv,dpx),ev)/nn)+normalize(cross(dbx,dby))*(dot(nv,ev)/sqrt(nn)));
		if(code>14.5){
			// a limb: is there a bone standing out of the gouged muscle on this line of sight?
			vec3 ro=v_body-rd*0.08;
			float best=1e9;
			int bi=-1;
			for(int k=0;k<${AC.bones.length};k++){
				float t=capsule(ro,rd,BONE_A[k],BONE_B[k],BONE_R[k]);
				if(t>0.0&&t<best){best=t;bi=k;}
			}
			if(bi>=0&&best<0.081){
				vec3 hp=ro+rd*best,ba=BONE_B[bi]-BONE_A[bi];
				vec3 onAxis=BONE_A[bi]+ba*clamp(dot(hp-BONE_A[bi],ba)/dot(ba,ba),0.0,1.0);
				code=9.0;rot=0.93;body=hp;
				// light it as the round thing it is: its own surface direction, turned back from rest space to the screen
				vec3 nr=normalize(hp-onAxis),nb=cross(dbx,dby);
				float nnb=max(dot(nb,nb),1e-24);
				vec3 nvw=normalize(dpx*(dot(cross(dby,nb),nr)/nnb)+dpy*(dot(cross(nb,dbx),nr)/nnb)+normalize(nv)*(dot(nb,nr)/sqrt(nnb)));
				I=ambient+0.98*max(dot(nvw,normalize(key_dir)),0.0)+(b4(floor(FRAGCOORD.xy/pixel_size))-0.5)*0.14;
				pool=-0.5;
				inShade=0.12+0.3*pow(1.0-max(dot(nr,-rd),0.0),2.0);                             // and a little darker where it turns away into the gouge
			}
		}else if(code>12.5){
			// The torso and the head: the anatomy map is a relief. First the bones, which stand in front of this surface
			// and are about a centimetre thick, so the line of sight can pass under one; then, where this surface is
			// torn or broken through, on to what's behind it.
			float sel=code>13.5?0.0:1.0;
			bool tears=COLOR.g>0.5;                                                        // only the Destroyed torso and head are opened
			float mask=amap(v_body,0.0,sel).w;                                             // is it torn through right here?
			bool torn=tears&&mask>0.56;
			vec4 hit=vec4(sel<0.5?240.0:144.0,0.0,0.0,0.0);                                // nothing in the way: this surface itself (muscle wall, or skull)
			float s=-0.07,ds=0.07/40.0;
			bool found=false;
			for(int k=0;k<40;k++){
				vec3 q=v_body+rd*s;
				float rq=arad(q,sel);
				vec4 m=amap(q,0.0,sel);
				float mc=floor(m.x/16.0),mr=m.x-mc*16.0;
				if(mc<14.5&&rq<=m.y&&rq>=m.y-0.011&&!(tears&&mr>3.5)){hit=m;found=true;break;}   // (a snapped-off rib or broken-away skull isn't there)
				s+=ds;
			}
			if(!found){
				s=0.0;
				if(torn){                                                                  // through the tear: the organs, or the brain
					hit=vec4(242.0,0.0,0.85,0.0);
					float t=sel<0.5?-0.03:0.0,dt=(sel<0.5?0.13:0.04)/34.0;                 // the pile of gut bulges out in front of the belly wall
					bool deep=false;
					for(int k=0;k<34;k++){
						vec3 q=v_body+rd*t;
						vec4 m=amap(q,1.0,sel);
						if(arad(q,sel)<=m.y){hit=m;deep=true;break;}
						t+=dt;
					}
					s=sel<0.5?0.10:0.04;
					if(sel<0.5)pool=smoothstep(1.06,0.95,v_body.y);                        // blood pools low in the belly
					if(deep){                                                              // close in on where it was met
						float lo=t-dt,hi=t;
						for(int k=0;k<4;k++){
							float mid=(lo+hi)*0.5;
							vec3 q=v_body+rd*mid;
							vec4 m=amap(q,1.0,sel);
							if(arad(q,sel)<=m.y){hi=mid;hit=m;}else lo=mid;
						}
						s=hi;
					}
				}else if(tears&&mask>0.5)hit=vec4(sel<0.5?241.0:146.0,0.0,0.3,0.0);        // the ragged edge of the tear, or the red edge of broken bone
			}
			body=v_body+rd*s;
			code=floor(hit.x/16.0);
			float mvar=hit.x-code*16.0;
			inShade=clamp(inShade*0.4+hit.z*0.8+max(s,0.0)*4.5,0.0,1.0);                   // darker the further in
			if(code<9.5)rot=(tears&&mvar>1.5&&mvar<2.5)?0.7:0.93;                          // bone, or the red marrow where it's broken
			else if(code<10.5)rot=0.86;
			else if(code<11.5){brainPx=sel>0.5;rot=brainPx?(mvar>0.5?0.74:0.55):0.56;      // lung, or brain (gouged and bloody in the middle of a break)
				if(brainPx)inShade=clamp(hit.z*0.8+max(s,0.0)*6.0,0.0,1.0);}                  // the brain sits in the shadow of the skull's edge
			else if(code<12.5)rot=0.66;
			else if(code<13.5)rot=0.55;
			else if(code<14.5)rot=0.6;
			else rot=mvar>2.5?0.47:(mvar>1.5?0.79:(mvar>0.5?0.74:0.6));                    // fat, the dark of the cavity, the torn edge, or the muscle wall
		}else{
			// The cut of a severed neck: a slanted cut, with things standing a little above it or opening down into it.
			// COLOR.g marks the other side of the same cut, the underside of a head that came off: there the tissue is
			// above the cut, the vertebra hangs a little below it, and the tubes open upward.
			bool piece=COLOR.g>0.5;
			float s=-0.012,ds=0.045/45.0;
			code=15.0;rot=0.79;inShade=0.9;                                                // nothing met: looking down an open tube
			for(int k=0;k<45;k++){
				vec3 q=v_body+rd*s;
				vec4 nk=neckAt(q.xz);
				// (on the head's underside the cut is measured from this very point of it, which is ragged, not from the
				// ideal slanted cut, so the depth shading follows the real torn surface)
				float top=piece?v_body.y-${f4(AC.neck.slope)}*(q.z-v_body.z)-nk.x:${f4(AC.neck.y)}-${f4(AC.neck.slope)}*q.z+nk.x;
				float into=piece?q.y-top:top-q.y;
				if(into>=0.0){code=nk.y;rot=nk.z;inShade=clamp(into*25.0+nk.w,0.0,0.9);body=q;break;}
				s+=ds;
			}
		}
	}
	float dd=1.0-freshness;                                    // how dead overall
	vec3 bp=body;
	vec3 sp=bp+decay_seed*vec3(1.31,0.71,2.17);
	float dth=b4(floor(FRAGCOORD.xy/pixel_size));                // 0..1, steps stage borders into a dither
	vec3 lsp=bp+look_seed*vec3(1.31,0.71,2.17);                 // the living look's pattern space: same spots as in life
	int tb=TONES+skin_tone*4;
	float deep=DEEP[skin_tone];
	bool head=code<0.5&&bp.y>1.55;
	bool face=head&&bp.z>0.015;
	bool neck=code<0.5&&bp.y>1.44&&bp.y<=1.55&&abs(bp.x)<0.1;
	bool fore=code<0.5&&bp.y>0.8&&bp.y<1.22&&abs(bp.x)>0.16;
	bool shin=code<0.5&&bp.y<0.56;
	bool thigh=code>7.5;
	bool uarm=code>1.5&&code<2.5&&bp.y<1.6;
	bool ear=code>1.5&&code<2.5&&bp.y>=1.6;
	bool torso=code>2.5&&code<3.5;
	bool hand=code>3.5&&code<5.5, foot=code>5.5&&code<7.5;
	// Some places run ahead: the lower belly goes green first, old bruises (baked rot) and random blotches rot sooner,
	// and hands and feet dry out first at the end.
	float belly=exp(-(q2(bp.x+0.07)/0.02+q2(bp.y-0.98)/0.012))*step(0.0,bp.z);
	// (Fresh and Rigor bodies stay even: the head start only kicks in once he's past rigor.)
	float ahead=smoothstep(0.22,0.4,dd);
	float lc=dd+((fbm3(sp*3.5)-0.5)*0.22+rot*0.35+belly*0.24+((hand||foot)?0.1*smoothstep(0.6,0.9,dd):0.0))*ahead;
	float lt=lc+(dth-0.5)*0.07;
	int stg=lt<0.12?0:(lt<0.32?1:(lt<0.56?2:(lt<0.8?3:4)));
	if(code>8.5)I-=0.78*inShade;                                 // the insides sit in the body's own shadow, deeper = darker
	float base=floor(clamp((1.1-(I-cf))/1.1,0.0,0.999)*8.0);
	// the dark-and-gritty pass: some pixels a shade off, grime caked on low and in the creases
	float gh=h13(vec3(floor(FRAGCOORD.xy/pixel_size),7.0));
	float gs=gh<grit*0.5?1.0:(gh<grit?-1.0:0.0);
	float dirt=fbm3(sp*9.0+3.0)*(0.35+0.65*smoothstep(0.75,0.05,bp.y));
	float soil=dirt>0.66?1.0:0.0;                                // a little ground-in shade low on the body
	// grime, in its own colors, more on some than others:
	//  mud splashed up the feet and shins from walking through it, with flecks above the edge;
	//  dust settled on whatever faces up (head, shoulders, upper back, tops of the feet);
	//  grass and earth stains on the knees and hands from crawling and grabbing;
	//  smears down the torso, back and shorts where he's dragged against things.
	int gr=-1;
	float gix=0.0;
	{
		float g=grime;
		float mudLine=0.18+0.32*g+0.12*(fbm3(sp*vec3(6.0,1.5,6.0)+31.0)-0.5);
		float md=smoothstep(mudLine+0.03,mudLine-0.3,bp.y);        // thick at the feet, breaking up as it climbs
		float mn=fbm3(sp*vec3(16.0,8.0,16.0)+33.0);
		float mud=step(mn*0.7+0.3*h13(floor(sp*70.0)+35.0),md*0.52+0.05*g);   // grainy, splashed edge
		float fleck=step(bp.y,mudLine+0.2)*step(1.0-0.05*g,h13(floor(sp*90.0)+41.0));
		float dust=smoothstep(0.35,0.8,v_up)*smoothstep(0.5,0.62,fbm3(sp*10.0+51.0)+0.3*g-0.1);
		float knee=exp(-q2(bp.y-0.5)/0.004)*smoothstep(0.0,0.05,bp.z);
		float stain=max(knee,hand?0.8:0.0)*smoothstep(0.45,0.6,fbm3(sp*12.0+61.0)+0.3*g);
		float smear=(torso||cl)?step(0.6-0.08*g,fbm3(sp*2.0+77.0))*step(0.69,fbm3(sp*vec3(34.0,3.0,34.0)+71.0)):0.0;   // a few thin streaks
		if(mud>0.5||fleck>0.5){gr=MUD;gix=mn<md*0.4?0.0:1.0;}
		else if(stain>0.5){gr=h13(floor(sp*60.0)+5.0)>0.5?GRASS:MUD;gix=1.0;}
		else if(dust>0.5){gr=DUST;gix=0.0;}
		else if(smear>0.5){gr=MUD;gix=1.0;}
	}
	float tdt=(dth-0.5)*0.12;                                    // dither for wound color changes
	// blood: what state it's in for how long he's been dead, and whether it has run or soaked to this spot
	int bl=dd+tdt<0.1?BLOOD_WET:(dd+tdt<0.33?BLOOD:(dd+tdt<0.6?BLOOD_CLOT:BLOOD_OLD));
	bool flaked=dd>0.68&&h13(floor(bp*120.0)+3.0)<(dd-0.68)*1.5;       // the dried crust flakes off in the end
	float nrun=(code>2.5&&code<3.5)?UV2.x*neck_blood:0.0;              // from the neck, down over the shoulders, chest and back
	float braw=max(UV2.y,nrun);
	float brun=max(UV2.y*(0.72+0.56*gore),nrun*(0.9+0.2*gore));
	bool ran=!flaked&&brun>0.5+(vno(vec3(bp.x*85.0,3.0+decay_seed,bp.z*85.0))-0.5)*0.5;   // thin streams with ragged edges
	bool bloody=false;
	int r;
	float ix=base;
	if(code>9.5&&code<14.5){
		// the insides: 10 cartilage, 11 lung (or brain), 12 heart and liver, 13 stomach and small intestine, 14 colon
		if(code<10.5){
			r=dd+tdt<0.4?CARTILAGE:(dd+tdt<0.78?BONE_PUTRID:BONE_OLD);              // cartilage goes off sooner than bone
		}else{
			bool brain=brainPx;
			int live=code<11.5?(brain?BRAIN:LUNG):(code<12.5?ORGAN:(code<13.5?GUT:COLON));
			int dusky=code<11.5?(brain?BRAIN_DUSK:LUNG_DUSK):(code<12.5?ORGAN_DUSK:(code<13.5?GUT_DUSK:COLON_DUSK));
			// they go off with the body: their own colors only while he's fresh, dull and dusky in rigor, grey-green
			// in the bloat, dark olive-black slime when putrid, dried black-brown at the end
			r=dd+tdt<0.14?live:(dd+tdt<0.34?dusky:(dd+tdt<0.58?OFFAL:(dd+tdt<0.8?ORGAN_PUTRID:FLESH_DRY)));
			ix=base+((r==OFFAL&&code>11.5&&code<12.5)?1.0:0.0);
			if(brain){
				if(pow(rdg(bp*64.0),5.0)>0.5)ix+=1.0;                       // the folds
				if(rot>0.7){r=dd+tdt<0.5?bl:FLESH_ROT;ix=base+1.0;}          // gouged and bloody where the skull is broken
			}
			if(dd<0.6&&base<5.0&&h13(floor(bp*85.0)+decay_seed)>0.92)ix-=1.0;      // wet shine while they last
			float mg=smoothstep(0.45,0.58,dd)*(1.0-smoothstep(0.78,0.9,dd));
			vec3 mc=floor(bp*95.0+vec3(sin(TIME*5.0+bp.y*40.0),0.0,cos(TIME*4.0+bp.x*40.0))*0.35);
			if(h13(mc+decay_seed)>1.0-0.05*mg){r=MAGGOT;ix=base-1.0;}
		}
	}else if(rot>0.8){
		r=dd+tdt<0.3?BONE_FRESH:(dd+tdt<0.52?BONE:(dd+tdt<0.78?BONE_PUTRID:BONE_OLD));
	}else if(rot>0.45){
		r=dd+tdt<0.14?FLESH_FRESH:(dd+tdt<0.34?FLESH:(dd+tdt<0.58?FLESH_ROT:(dd+tdt<0.8?FLESH_PUTRID:FLESH_DRY)));   // raw flesh goes off with the body too
		ix=base+(rot>0.72?2.0:(rot>0.6?1.0:0.0));
		if(rot<0.5){
			// the band of fat just under the skin: yellow while fresh, then it goes the way of the flesh
			if(dd+tdt<0.45){r=FAT;ix=base;}
		}else{
			// muscle: fibers running down the body, with pale strands of sinew through it while it's fresh
			if(vno(vec3(bp.x*230.0,bp.y*14.0,bp.z*230.0))>0.64)ix+=1.0;
			if(dd<0.5&&rot<0.72&&vno(vec3(bp.x*130.0,bp.y*7.0,bp.z*130.0)+9.0)>0.86){r=TENDON;ix=base+1.0;}
		}
		// maggots work the wounds once he's well gone, wriggling a little
		float mg=smoothstep(0.45,0.58,dd)*(1.0-smoothstep(0.78,0.9,dd));
		vec3 mc=floor(bp*95.0+vec3(sin(TIME*5.0+bp.y*40.0),0.0,cos(TIME*4.0+bp.x*40.0))*0.35);
		if(h13(mc+decay_seed)>1.0-0.07*mg){r=MAGGOT;ix=base-1.0;}
	}else if(rot>0.3&&cl){
		// a wound under the shorts: the cloth is torn round it, frayed and stuck with blood
		r=CLOTH;
		ix=base+3.0;
		if(h13(floor(bp*150.0)+decay_seed)>0.55){r=bl;ix=base+1.0;}
	}else if(rot>0.3){
		r=dd+tdt<0.3?CLOT:DECAY;
		ix=base+(r==CLOT?0.0:gs);
	}else if(nail){
		r=dd+tdt<0.3?NAIL_FRESH:(dd+tdt<0.75?NAIL:NAIL_DARK);
		ix=base+rim;
	}else if(cl){
		r=CLOTH;
		ix=base+1.0+rim+soil+gs+floor(dd*2.5);                    // the longer dead, the filthier
		// blood soaks into cloth and spreads: a wide stain round and below a wound, plus the odd old stain
		if(!flaked&&(braw*(0.8+0.6*gore)+0.3*(fbm3(sp*10.0+17.0)-0.5)>0.3||fbm3(sp*11.0+21.0)>0.7-0.06*gore)){r=bl;ix=base+1.0+(braw>0.6?1.0:0.0);}
		else if(gr>=0){r=gr;ix=base+gix+1.0;}
	}else{
		r=stg==0?tb:(stg==1?tb+1:(stg==2?BLOAT:(stg==3?PUTRID:DRIED)));
		ix=base+rim+(rot>0.24?2.0:(rot>0.16?1.0:0.0))+((stg>1&&stg<4)?deep:0.0);
		// who he was: freckles, age spots and wrinkles, vitiligo. Clear while fresh, fading through the bloat
		// (stepped into a dither), gone once the rot has the skin.
		bool keep=dth<1.0-smoothstep(0.3,0.55,lc);
		if(keep&&variant==0){
			float top=torso?smoothstep(1.3,1.45,bp.y)*(0.7+0.3*smoothstep(0.0,-0.04,bp.z)):0.0;
			float fz=(face?1.0:0.0)+(head&&!face?0.35:0.0)+top+(uarm?0.85:0.0)+(fore?0.6:0.0)+(hand?0.45:0.0)+(torso?0.15:0.0)+(neck?0.4:0.0)+(ear?0.3:0.0)+0.06;
			fz*=0.45+0.55*fbm3(lsp*5.0+9.0);
			float fh=h13(floor(lsp*125.0)+look_seed*0.37);
			if(fh<fz*0.29){r=tb+2;ix=base+(fh<fz*0.08?1.0:0.0)+rim;}
		}
		if(keep&&variant==3){
			float wz=(neck?1.0:0.0)+(face?0.35:0.0)+(face&&bp.y>1.69?0.25:0.0)+(fore||hand?0.55:0.0)+(torso&&bp.z>0.0&&bp.y<1.2?0.35:0.0)+(ear?0.4:0.0)+0.2;
			float wr=pow(rdg(lsp*vec3(16.0,70.0,16.0)),10.0)+0.5*pow(rdg(lsp*vec3(40.0,40.0,40.0)+3.0),14.0);
			if(wr*wz>0.26)ix+=1.0;
			float sz=(head?1.0:0.0)+(hand?1.0:0.0)+(fore?0.8:0.0)+(torso&&bp.y>1.35?0.55:0.0)+(uarm?0.45:0.0)+0.12;
			vec3 sc=lsp*38.0;
			vec3 sj=fract(sc)-0.5-(vec3(h13(floor(sc)+1.0),h13(floor(sc)+2.0),h13(floor(sc)+3.0))-0.5)*0.4;
			if(h13(floor(sc)+look_seed)<sz*0.3&&length(sj)<0.26+0.18*h13(floor(sc)+4.0)){r=tb+3;ix=base+rim;}
		}
		if(keep&&variant==4){
			bool finger=code<0.5&&bp.y<=0.8&&abs(bp.x)>0.16;
			float mouth=face?exp(-(q2(bp.x)/0.0016+q2(bp.y-1.6)/0.0012)):0.0;
			float wrist=fore?smoothstep(0.93,0.86,bp.y):0.0;
			float knee=(shin||thigh)?exp(-q2(bp.y-0.52)/0.0012)*smoothstep(0.0,0.04,bp.z):0.0;
			float elbow=fore?smoothstep(1.06,1.14,bp.y)*smoothstep(0.0,-0.03,bp.z):0.0;
			float vz=(hand?1.0:0.0)+(finger?1.0:0.0)+wrist*0.9+mouth*0.9+(face?0.3:0.0)+elbow*0.8+knee*0.8+(foot?0.75:0.0)
				+(neck?0.35:0.0)+(torso?0.22:0.0)+(uarm?0.2:0.0)+((thigh||shin)?0.2:0.0)+((head&&!face)?0.25:0.0)+(ear?0.3:0.0);
			vec3 vp=vec3(abs(bp.x),bp.y,bp.z)+look_seed*vec3(0.61,0.37,0.83);
			float vn=fbm3(vp*4.5)+0.1*vno(vp*30.0);
			float th=0.78-0.3*clamp(vz,0.0,1.0);
			if(vn>th){r=VITILIGO_DEAD;ix=base+rim;}
		}
		// lividity: after death the blood sinks and stains the low parts. He lay on his back before he got up, so the
		// back, buttocks and backs of the legs are stained, except the pressure points (shoulder blades, buttocks) that
		// took his weight and stay pale. Since he's been upright, it's sinking into the feet, shins and hanging hands.
		// Faint while fresh, set dark through rigor, lost under the rot later.
		float back=smoothstep(0.0,-0.06,bp.z)*(1.0-smoothstep(-0.105,-0.135,bp.z));
		float lv=(smoothstep(0.5,0.04,bp.y)*0.9+(hand?0.6:0.0)+back*0.9*smoothstep(0.1,0.25,dd))*fbm3(sp*vec3(9.0,5.0,9.0)+5.0);
		lv*=(0.35+0.65*smoothstep(0.0,0.16,dd))*(1.0-smoothstep(0.4,0.62,lc));
		if(lv>0.32+dth*0.1){r=LIVOR;ix+=deep+(lv<0.4?1.0:0.0);}
		// marbling: the veins under the skin go dark and branch, stretched along the limbs
		float mv=pow(rdg(sp*vec3(6.0,2.2,6.0)),14.0)+0.6*pow(rdg(sp*vec3(13.0,5.0,13.0)+4.0),18.0);
		if(mv*smoothstep(0.22,0.4,lc)*(1.0-smoothstep(0.82,0.95,lc))>0.42){r=MARBLE;}
		// slipped skin: from bloat on, patches of skin come away, showing the wet rot underneath (dried black at the end)
		float sl=fbm3(sp*vec3(7.0,4.5,7.0)+11.0),st=0.78-0.16*smoothstep(0.5,0.9,lc);
		if(lc>0.48&&sl>st){
			bool deep=sl>st+0.05;
			r=deep?(stg==4?FLESH_DRY:FLESH_ROT):DECAY;
			ix=base+(deep?1.0:0.0);
		}
		// wet glisten on putrid skin
		if(r==PUTRID&&h13(floor(bp*70.0)+decay_seed)>0.94&&base<4.0)ix-=1.0;
		// blood: on the hands and forearms, down the chest. Bright while fresh, dried brown after.
		float bm=((hand?0.75:0.0)+smoothstep(-0.05,0.25,bp.z)*smoothstep(1.0,1.45,bp.y)*0.55+smoothstep(0.55,1.0,bp.y)*step(0.22,abs(bp.x))*0.25)*gore;
		if(bm*fbm3(sp*7.0+13.0)>0.3&&!flaked){r=bl;ix=base;bloody=true;}
		// blood run down from a wound: clotted thick close to it, with a wet shine while it's fresh
		if(ran){r=bl;ix=base+(braw>0.75&&bl!=BLOOD_WET?1.0:0.0);bloody=true;
			if(bl==BLOOD_WET&&base<5.0&&h13(floor(bp*90.0)+decay_seed)>0.88)ix-=1.0;}
		// hair outlasts the skin: body hair and stubble stay through the rot, thinning out at the end, but not on
		// the patches where the skin has come away
		bool slipped=r==DECAY||r==FLESH_ROT||r==FLESH_DRY;
		if(!slipped&&!bloody){
			float chest=torso?smoothstep(0.0,0.04,bp.z)*smoothstep(1.19,1.27,bp.y)*(1.0-smoothstep(1.40,1.46,bp.y))*(1.0-smoothstep(0.09,0.16,abs(bp.x))):0.0;
			float trail=torso?smoothstep(0.02,0.06,bp.z)*smoothstep(0.96,1.04,bp.y)*(1.0-smoothstep(1.2,1.27,bp.y))*(1.0-smoothstep(0.012,0.035,abs(bp.x))):0.0;
			float upback=torso?smoothstep(0.0,-0.05,bp.z)*smoothstep(1.3,1.42,bp.y)*0.35:0.0;
			float limb=(fore?0.9:0.0)+(shin?0.85:0.0)+(thigh?0.6:0.0)+(uarm?0.22:0.0)+(hand?0.35:0.0)+(foot?0.15:0.0);
			float bodyHair=max(max(chest,trail),max(upback,limb));
			float beard=head?(1.0-smoothstep(1.62,1.665,bp.y))*smoothstep(-0.035,0.005,bp.z):0.0;
			beard=max(beard,neck?smoothstep(0.015,0.045,bp.z)*smoothstep(1.49,1.53,bp.y)*0.7:0.0);
			float bodyAmt=variant==2?1.0:(variant==3?0.45:(variant==0||variant==4?0.28:0.05));
			float beardAmt=variant==2?1.0:(variant==3?0.55:(variant==0||variant==4?0.3:0.12));
			float thin=1.0-0.45*smoothstep(0.75,0.95,lc);
			float hd=bodyHair*bodyAmt*(0.55+0.45*fbm3(lsp*7.0+2.0))*(hair_color==4?GREY_SHOW[skin_tone]:1.0)*thin;
			float bd=beard*beardAmt*(0.7+0.3*fbm3(lsp*12.0))*thin;
			float strand=h13(floor(lsp*vec3(320.0,130.0,320.0))+look_seed);
			float stub=h13(floor(lsp*420.0)+look_seed+5.0);
			float show=hair_color>=2?1.0:(hair_color==1?0.7:0.45);
			int hair=HAIR_BLOND+hair_color;
			if(stub<bd*0.28){r=hair;ix=base;}
			else if(stub<bd*0.8*show)ix+=1.0;
			else if(strand<hd*(variant==2?0.2:0.12)){r=hair;ix=base;}
			else if(strand<hd*(variant==2?0.75:0.5)*show)ix+=1.0;
		}
		if(gr>=0&&!slipped&&!bloody){r=gr;ix=base+gix+rim;}
		else if(r!=LIVOR&&!bloody)ix+=soil+gs;
	}
	// The insides and the raw flesh of a wound are a mess: blood smeared over the bone, cartilage and organs and run
	// down them, dark clots in lumps, and sludge once he's gone off. More of it the deeper inside and the bloodier he is.
	if((code>8.5||rot>0.5)&&r!=MAGGOT){
		float deepIn=code>8.5?inShade:0.0;
		float mess=0.42+0.3*gore+0.4*deepIn+0.3*pool;
		float smear=fbm3(sp*vec3(30.0,8.0,30.0)+91.0);                       // drawn out downward, the way it runs
		float lump=fbm3(sp*42.0+17.0);
		bool hard=rot>0.8||(code>9.5&&code<10.5);                            // bone and cartilage show it most
		int old=dd<0.33?BLOOD:(dd<0.6?BLOOD_CLOT:BLOOD_OLD);                 // a step darker than the blood still running
		if(lump>0.74-0.16*mess){                                             // clots while he's fresh, sludge later, a black crust at the end
			r=dd<0.5?old:(dd<0.82?MUCK:BLOOD_OLD);ix=base+1.0+(lump>0.8?1.0:0.0);
		}else if(smear+tdt>0.80-0.36*mess*(hard?1.0:0.85)){
			r=bl;ix=base+(smear>0.68?1.0:0.0);
			if(bl==BLOOD_WET&&base<5.0&&h13(floor(bp*90.0)+decay_seed)>0.9)ix-=1.0;   // wet shine
		}else if(hard&&smear>0.52)ix+=1.0;                                   // stained where it isn't coated
	}
	vec3 c=pal(r,ix);
	ALBEDO=pow(c,vec3(2.2));
}
`;
if (/SKIN[012]\[|DECAY\[|FLESH\[/.test(out)) throw new Error('old palette still referenced');
fs.writeFileSync(process.argv[3], out);
console.log('wrote', process.argv[3], out.length, 'chars,', RAMPS.length, 'ramps');
