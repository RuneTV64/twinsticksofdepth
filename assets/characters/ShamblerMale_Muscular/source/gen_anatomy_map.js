// Paints the torso's anatomy into a map the shader reads, so the insides of a wound are painted, not modelled, and
// still have depth.
// The real anatomy from anatomy.js (ribs, cartilage, sternum, collarbones, shoulder blades, spine, pelvis, organs) is
// looked at from outside, straight in toward the body's axis, and for each direction round the body and each height
// the map records WHAT is seen and HOW FAR from the axis it is. That second part is what gives the painting depth:
// the shader follows each line of sight through this relief, so bones stand in front of the muscle, organs sit behind
// the wall, and they slide past each other as the view moves.
// The image is two maps side by side, each wrapped round the body (across = direction, 0 at the back, the middle =
// the front; down = height):
//   left,  the bones: everything that lies on or outside the muscle wall (ribs, cartilage, sternum, collarbones,
//          shoulder blades, the knobs of the spine, hip bones), and the wall itself where there is no bone
//   right, the cavity: what is behind the wall (the organs and the bodies of the spine), as far in as DEEP
// In each: R = code * 16 + variant (codes as in anatomy.js), G = distance from the axis in millimetres, B = a baked
// shade (the edges of round things are darker). Variants: on bone, 2 = this is the red marrow end of a snapped rib and
// 4 = this stretch of rib is snapped off, both only in the torso that is torn open; on code 15, 2 = the dark of the cavity
// and 3 = fat.
// The left map's A = where the Destroyed torso's wall is torn through (above half = torn).
// Under the torso's two maps are the head's two, laid out the same way round the head's own upright axis: on the left
// the skull (variant 4 where the Destroyed head's skull is broken away, 2 for the red spongy bone at the edge of the
// break, A = how broken), on the right the brain under it (variant 1 where it's gouged and bloody), with its folds
// and the groove between its halves in the relief.
// It also writes anatomy_consts.json for gen_decay_shader.js: where each map sits, where the limb bones run, and the
// cut of the neck.
// Usage: node gen_anatomy_map.js out_dir   -> anatomy_map.png, anatomy_map_preview.png, anatomy_map.gd
const fs = require('fs'), zlib = require('zlib'), SH = require('./shambler.js'), AN = require('./anatomy.js');
const W = 384, H = 256, Y0 = .885, Y1 = 1.545, R0 = .4, DEEP = .085;   // DEEP: how far behind the wall the cavity is painted
const B = SH.buildBase(1), K = B.K, o = { detail: 1, shoulder: B.piv[B.BL + 3] };
const BREAKS = SH.BREAKS;
const bonesA = [...AN.buildRibs(K, o), ...AN.buildSternum(K, o), ...AN.buildClavicles(K, o), ...AN.buildScapulae(K, o), ...AN.buildSpine(K, o).filter(p => /^spinous/.test(p.name)), ...AN.buildPelvis(K, o)];
const wallOnly = [AN.shell('muscleWall', K, AN.CORE_IN, { detail: 1, rot: .6, y1: 1.535 })], layerA = [...wallOnly, ...bonesA];
const TEARS = SH.makeVariant(B, 'Torso', 'Destroyed').tears;
const layerB = [...AN.buildSpine(K, o).filter(p => !/^spinous/.test(p.name)), ...AN.buildOrgans(K, o)];
const snapped = AN.buildRibs(K, { detail: 1, breaks: BREAKS });   // the ribs as they are in the torn torso
function tris(parts) { const T = []; for (const p of parts) { const code = p.COL[3] / 17; for (let t = 0; t < p.I.length; t += 3) { const a = p.I[t], b = p.I[t + 1], c = p.I[t + 2];
  const rot = (p.rot[a] + p.rot[b] + p.rot[c]) / 3; T.push({ a: [p.P[a * 3], p.P[a * 3 + 1], p.P[a * 3 + 2]], b: [p.P[b * 3], p.P[b * 3 + 1], p.P[b * 3 + 2]], c: [p.P[c * 3], p.P[c * 3 + 1], p.P[c * 3 + 2]], val: code * 16 + (code === 9 && rot < .8 ? 1 : code === 15 && rot < .5 ? 3 : 0), rib: /^(rib|cartilage)/.test(p.name) }); } } return T; }
function rows(T) { const R = Array.from({ length: H }, () => []); for (const t of T) { const lo = Math.min(t.a[1], t.b[1], t.c[1]), hi = Math.max(t.a[1], t.b[1], t.c[1]);
  const r0 = Math.max(0, Math.floor((lo - Y0) / (Y1 - Y0) * H) - 1), r1 = Math.min(H - 1, Math.ceil((hi - Y0) / (Y1 - Y0) * H) + 1); for (let r = r0; r <= r1; r++) R[r].push(t); } return R; }
// first hit of a ray from outside, straight in toward the axis
function cast(Rw, O, D, tmax) { let best = null, bt = tmax; for (const t of Rw) { const e1 = [t.b[0] - t.a[0], t.b[1] - t.a[1], t.b[2] - t.a[2]], e2 = [t.c[0] - t.a[0], t.c[1] - t.a[1], t.c[2] - t.a[2]];
  const px = D[1] * e2[2] - D[2] * e2[1], py = D[2] * e2[0] - D[0] * e2[2], pz = D[0] * e2[1] - D[1] * e2[0], det = e1[0] * px + e1[1] * py + e1[2] * pz; if (Math.abs(det) < 1e-12) continue;
  const inv = 1 / det, tx = O[0] - t.a[0], ty = O[1] - t.a[1], tz = O[2] - t.a[2], u = (tx * px + ty * py + tz * pz) * inv; if (u < 0 || u > 1) continue;
  const qx = ty * e1[2] - tz * e1[1], qy = tz * e1[0] - tx * e1[2], qz = tx * e1[1] - ty * e1[0], v = (D[0] * qx + D[1] * qy + D[2] * qz) * inv; if (v < 0 || u + v > 1) continue;
  const d = (e2[0] * qx + e2[1] * qy + e2[2] * qz) * inv; if (d > 1e-5 && d < bt) { bt = d; const nx = e1[1] * e2[2] - e1[2] * e2[1], ny = e1[2] * e2[0] - e1[0] * e2[2], nz = e1[0] * e2[1] - e1[1] * e2[0], nl = Math.hypot(nx, ny, nz) || 1;
    best = { val: t.val, rib: t.rib, d, facing: Math.abs((nx * D[0] + ny * D[1] + nz * D[2]) / nl) }; } } return best; }
const HH = 128, HY0 = 1.555, HY1 = 1.805, TH = H + HH;   // the head's maps: rows under the torso's
const G = new Float32Array(W * H), HOLE = new Float32Array(W * H), RIBAT = new Uint8Array(W * H);
const RA = rows(tris(layerA)), RB = rows(tris(layerB)), RW = rows(tris(wallOnly)), RS = rows(tris(snapped)), px = Buffer.alloc(W * 2 * TH * 4), mm = r => Math.max(0, Math.min(255, Math.round(r * 1000)));
for (let r = 0; r < H; r++) { const y = Y0 + (r + .5) / H * (Y1 - Y0);
  for (let c = 0; c < W; c++) { const a = (c + .5) / W * 2 * Math.PI - Math.PI, D = [-Math.sin(a), 0, -Math.cos(a)], O = [R0 * Math.sin(a), y, R0 * Math.cos(a)], i = ((H - 1 - r) * W * 2 + c) * 4, j = i + W * 4;   // row 0 of the image is the top
    const hw = cast(RW[r], O, D, R0), ha = cast(RA[r], O, D, R0), wallR = hw ? R0 - hw.d : 0;
    // the closed wall, with whatever bone lies on it
    let va = ha ? ha.val : 15 * 16 + 2;
    if (ha && ha.rib) { const hs = cast(RS[r], O, D, R0), same = hs && Math.abs(hs.d - ha.d) < .004;   // a rib or its cartilage: is it still there in the torn torso?
      if (!same) va = (va & 240) + 4; else if ((hs.val & 15) === 1) va = (va & 240) + 2; }
    px[i] = va; px[i + 1] = ha ? mm(R0 - ha.d) : 0; px[i + 2] = ha ? Math.round(255 * Math.min(1, (1 - ha.facing) * .55 * (ha.val === 15 * 16 ? 0 : 1))) : 230;
    // where the Destroyed torso's wall is torn through
    let g = 0; if (hw) { const wp = [O[0] + D[0] * hw.d, y, O[2] + D[2] * hw.d]; for (const t of TEARS) { const v = SH.patchAt(wp, t.c, t.o); if (v !== null) g = Math.max(g, Math.min(1, Math.max(0, .5 + .45 * v))); }
      HOLE[r * W + c] = AN.noise3(wp[0] * 26, wp[1] * 26, wp[2] * 26, 91) + .35 * AN.noise3(wp[0] * 70, wp[1] * 70, wp[2] * 70, 92); }
    G[r * W + c] = g; RIBAT[r * W + c] = ha && ha.rib ? ((va & 15) === 4 ? 2 : 1) : 0;
    // torn open: what is past the wall, as far in as DEEP. Nothing there = the dark of the cavity. (Only what is close
    // behind the wall: things near the axis would smear right round the map.)
    const hb = cast(RB[r], O, D, R0 * 2 - .1);
    if (hb && wallR - (R0 - hb.d) < DEEP) { px[j] = hb.val; px[j + 1] = mm(R0 - hb.d); px[j + 2] = Math.round(255 * Math.min(1, (1 - hb.facing) * .5)); }
    else { px[j] = 15 * 16 + 2; px[j + 1] = mm(Math.max(0, wallR - DEEP)); px[j + 2] = 215; }
    px[j + 3] = 255; } }
// Where the Destroyed torso's wall is torn through. Below the ribcage the whole belly wall is gone inside the tear.
// Over the ribcage it is not: the muscle between the ribs stays, as it does in a real chest, and is ripped through
// only in ragged patches and where ribs are snapped off. (Tearing it all away left a clean cage of bare ribs over the
// organs, which looked like an anatomy model.)
for (let c = 0; c < W; c++) { let margin = H; for (let r = 0; r < H; r++) if (RIBAT[r * W + c]) { margin = r; break; }   // the lowest rib or cartilage in this direction
  for (let r = 0; r < H; r++) { let g = G[r * W + c];
    if (r >= margin - 2 && g > .5) { let snapped = false; for (let dr = -4; dr <= 4 && !snapped; dr++) for (let dc = -4; dc <= 4; dc++) { const rr = r + dr, cc = (c + dc + W) % W; if (rr >= 0 && rr < H && RIBAT[rr * W + cc] === 2) { snapped = true; break; } }
      if (!snapped && HOLE[r * W + c] < .72) g = Math.min(g, .44); }
    px[((H - 1 - r) * W * 2 + c) * 4 + 3] = Math.round(255 * g); } }
// ---------- the head: skull and brain, round the head's own axis ----------
const headV = SH.makeVariant(B, 'Head', 'Destroyed'), skull = headV.parts.find(p => p.name === 'skull'), HBREAKS = headV.breaks;
let zlo = 9, zhi = -9; for (let i = 0; i < skull.P.length / 3; i++) { zlo = Math.min(zlo, skull.P[i * 3 + 2]); zhi = Math.max(zhi, skull.P[i * 3 + 2]); } const HZC = (zlo + zhi) / 2;
{ const T = tris([skull]), SR = Array.from({ length: HH }, () => []);
  for (const t of T) { const lo = Math.min(t.a[1], t.b[1], t.c[1]), hi = Math.max(t.a[1], t.b[1], t.c[1]), r0 = Math.max(0, Math.floor((lo - HY0) / (HY1 - HY0) * HH) - 1), r1 = Math.min(HH - 1, Math.ceil((hi - HY0) / (HY1 - HY0) * HH) + 1); for (let r = r0; r <= r1; r++) SR[r].push(t); }
  const ss = (v, a, b) => { const t = Math.min(1, Math.max(0, (v - a) / (b - a))); return t * t * (3 - 2 * t); }, rdg = (x, y, z) => 1 - Math.abs(AN.noise3(x, y, z, 7) * 2 - 1);
  for (let r = 0; r < HH; r++) { const y = HY0 + (r + .5) / HH * (HY1 - HY0);
    for (let c = 0; c < W; c++) { const a = (c + .5) / W * 2 * Math.PI - Math.PI, D = [-Math.sin(a), 0, -Math.cos(a)], O = [.3 * Math.sin(a), y, HZC + .3 * Math.cos(a)], i = ((H + HH - 1 - r) * W * 2 + c) * 4, j = i + W * 4;
      const h = cast(SR[r], O, D, .3);
      if (!h) { px[i] = 15 * 16 + 2; px[i + 1] = 0; px[i + 2] = 230; px[i + 3] = 0; px[j] = 15 * 16 + 2; px[j + 1] = 0; px[j + 2] = 230; px[j + 3] = 255; continue; }
      const R = .3 - h.d, wp = [O[0] + D[0] * h.d, y, O[2] + D[2] * h.d]; let g = 0;
      for (const t of HBREAKS) { const v = SH.patchAt(wp, t.c, t.o); if (v !== null) g = Math.max(g, Math.min(1, Math.max(0, .5 + .45 * v))); }
      // the skull: gone where it's broken away, red spongy bone at the edge of the break
      px[i] = 9 * 16 + (g > .56 ? 4 : g > .5 ? 2 : 0); px[i + 1] = mm(R); px[i + 2] = Math.round(255 * Math.min(1, (1 - h.facing) * .3)); px[i + 3] = Math.round(255 * g);
      // the brain under it: folds, the groove between its halves, gouged and bloody in the middle of a break
      if (y < 1.648) { px[j] = 15 * 16 + 2; px[j + 1] = mm(Math.max(0, R - .03)); px[j + 2] = 215; }
      else { const fold = Math.pow(rdg(wp[0] * 64, wp[1] * 64, wp[2] * 64), 5), lump = AN.noise3(wp[0] * 95, wp[1] * 95, wp[2] * 95, 7) - .5, groove = .007 * Math.exp(-(wp[0] / .005) * (wp[0] / .005)) * ss(y, 1.70, 1.74), gouge = ss(g, .86, 1);
        const depth = .0095 + .0035 * fold - .004 * lump + groove + .009 * gouge;
        px[j] = 11 * 16 + (gouge > .4 ? 1 : 0); px[j + 1] = mm(Math.max(0, R - depth)); px[j + 2] = Math.round(255 * Math.min(1, .38 * fold + .6 * groove / .007 + .2 * gouge)); }
      px[j + 3] = 255; } } }
// what the shader generator needs to know
const armsLegs = ['ArmL', 'ArmR', 'LegL', 'LegR']; for (const sl of armsLegs) for (const st of ['Rotted', 'Destroyed']) SH.makeVariant(B, sl, st);
const r4 = v => +v.toFixed(4), consts = { width: W * 2, height: TH, torso: { y0: Y0, y1: Y1, rows: H }, head: { y0: HY0, y1: HY1, rows: HH, zc: r4(HZC) },
  bones: Object.keys(SH.LIMB_BONES).sort().map(n => ({ name: n, a: SH.LIMB_BONES[n].A.map(r4), b: SH.LIMB_BONES[n].B.map(r4), r: r4(SH.LIMB_BONES[n].r) })), neck: SH.NECK_CUT };
// ---- PNG writer
function png(w, h, rgba) { const crcT = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcT[n] = c >>> 0; }
  const crc = b => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]), cr = Buffer.alloc(4); cr.writeUInt32BE(crc(td)); return Buffer.concat([l, td, cr]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6; const raw = Buffer.alloc((w * 4 + 1) * h); for (let y = 0; y < h; y++) rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]); }
const dir = process.argv[2] || '.', data = png(W * 2, TH, px); fs.writeFileSync(dir + '/anatomy_consts.json', JSON.stringify(consts, null, 1)); fs.writeFileSync(dir + '/anatomy_map.png', data);
// a picture of it for people: both maps side by side, in rough colors, darker the nearer the axis
const COLS = { 9: [220, 205, 180], 10: [170, 190, 195], 11: [215, 145, 150], 12: [130, 45, 45], 13: [220, 160, 140], 14: [185, 135, 115], 15: [150, 60, 55] }, pv = Buffer.alloc(W * 2 * TH * 4);
for (let k = 0; k < W * 2 * TH; k++) { const v = px[k * 4], code = v >> 4, vr = v & 15, sh = 1 - .7 * px[k * 4 + 2] / 255, inHead = k >= W * 2 * H, col = code === 15 && vr === 2 ? [40, 14, 20] : code === 15 && vr === 3 ? [205, 185, 120] : inHead && code === 9 && vr === 4 ? [70, 30, 40] : inHead && code === 9 && vr === 2 ? [170, 60, 60] : inHead && code === 11 ? (vr ? [120, 50, 70] : [190, 150, 175]) : COLS[code] || [255, 0, 255];
  pv[k * 4] = col[0] * sh; pv[k * 4 + 1] = col[1] * sh; pv[k * 4 + 2] = col[2] * sh; pv[k * 4 + 3] = 255; }
fs.writeFileSync(dir + '/anatomy_map_preview.png', png(W * 2, TH, pv));
// the relief on its own (distance from the axis as grey), and where the Destroyed torso is torn
const dp = Buffer.alloc(W * 2 * TH * 4); for (let k = 0; k < W * 2 * TH; k++) { const g = Math.max(0, Math.min(255, (px[k * 4 + 1] - 20) * 1.35)), torn = k % (W * 2) < W && px[k * 4 + 3] > 143; dp[k * 4] = torn ? Math.min(255, g + 70) : g; dp[k * 4 + 1] = g; dp[k * 4 + 2] = g; dp[k * 4 + 3] = 255; }
fs.writeFileSync(dir + '/anatomy_map_depth.png', png(W * 2, TH, dp));
// the same map as a script, so Godot needs no import settings: the shader gets it as an ImageTexture built from this
const b64 = data.toString('base64'), lines = b64.match(/.{1,4000}/g).map(l => '\t"' + l + '"').join(' +\n');
fs.writeFileSync(dir + '/anatomy_map.gd', `# The torso's anatomy, painted into a map for zombie_decay.gdshader (made by source/gen_anatomy_map.js; don't edit by hand).
# The shader paints the inside of a torso wound from it: ribs, cartilage, sternum, collarbones, shoulder blades, spine,
# hip bones and organs, each with how far inside the body it sits, which is what gives the painting depth.
# Under the torso's maps are the head's: the skull, where it's broken, and the brain under it.
# It's kept as text so Godot's texture import can't blur or compress it.
# Use: material.set_shader_parameter("anatomy_map", AnatomyMap.texture())   (shambler.gd does this for you)
class_name AnatomyMap

const WIDTH := ${W * 2}
const HEIGHT := ${TH}
const DATA := (
${lines}
)

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture == null:
		var image := Image.new()
		image.load_png_from_buffer(Marshalls.base64_to_raw(DATA))
		_texture = ImageTexture.create_from_image(image)
	return _texture
`);
console.log('anatomy map', W * 2 + 'x' + TH, data.length, 'bytes png;', b64.length, 'chars in anatomy_map.gd; Y', Y0, Y1);
