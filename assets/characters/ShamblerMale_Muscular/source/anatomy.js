// What's inside the torso, built as geometry: ribcage, sternum, clavicles, shoulder blades, spine, pelvis, the muscle
// wall under the ribs, and the organs behind it.
// None of this is exported into the game models. It is the reference the painting is made from: gen_anatomy_map.js
// looks at it from outside and writes what it sees into the anatomy map, and zombie_decay.gdshader paints the inside
// of each torso wound from that map. Only shell() is used by shambler.js, for the one inner surface under the holes.
// (export_shambler.js can still write these models into a review file, to look at the anatomy on its own.)
//
// Anatomy, in body coordinates (metres, feet at 0, facing +Z, his left is +X):
//   ribs      12 pairs. Each leaves the spine at the back, curves round the side and slopes down toward the front.
//             1-7 (true ribs) reach the sternum through their own costal cartilage. 8-10 (false ribs) each join the
//             cartilage above, which makes the costal arch, the upside-down V under the chest. 11-12 float.
//   sternum   manubrium, body and xiphoid, just under the skin at the front.
//   clavicles from the top of the sternum out to the shoulders, where each meets its shoulder blade.
//   scapulae  the shoulder blades: a thin triangular blade on the back of the ribcage (over ribs 2-7), between the
//             ribs and the skin, with the spine of the scapula (a ridge across its back) running out to the acromion,
//             the shelf over the shoulder joint, and the socket for the arm at the outer corner. They ride on the
//             ribcage and move with the shoulder, not with the chest.
//   spine     vertebral bodies inside, spinous processes pointing back, just under the skin of the back.
//   pelvis    two hip bones and the sacrum. Each hip bone is the ilium (the wing, with the iliac crest along the top:
//             the bone you feel at the waist, from the dimple at the back round to the point at the front), the hip
//             socket, and below it the ischium (the sit bone) and the pubis, which meet at the front. The sacrum is
//             the wedge at the base of the spine between the two wings, ending in the tailbone.
//   organs    lungs fill the ribcage; heart sits front and a little left; liver under the right ribs; stomach under
//             the left; colon frames the belly (up the right, across, down the left); the small intestine is piled
//             inside it in tangled loops, three layers deep, with fat, clots and strands among it.
//
// Part codes written to COLOR.a (code * 17), read by zombie_decay.gdshader:
//   9 bone, 10 cartilage, 11 lung, 12 dark organ (heart, liver), 13 gut (stomach, small intestine), 14 colon,
//   15 muscle wall. A lung-coded part with COLOR.g set is the brain. Rot (COLOR.b) is also set so the older
//   zombie_skin shader still shows flesh and bone.
const CODE = { bone: 9, cartilage: 10, lung: 11, organ: 12, gut: 13, colon: 14, muscle: 15 };
const TAU = Math.PI * 2, PI = Math.PI;
const sp = (v, e) => Math.sign(v) * Math.pow(Math.abs(v), e);
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const len = v => Math.hypot(v[0], v[1], v[2]), unit = v => { const l = len(v) || 1; return [v[0] / l, v[1] / l, v[2] / l]; };
const ss = (v, a, b) => { const t = Math.min(1, Math.max(0, (v - a) / (b - a))); return t * t * (3 - 2 * t); };
const hash = (x, y, z, s) => { const h = Math.sin(x * 127.1 + y * 311.7 + z * 74.7 + s * 19.19) * 43758.5453; return h - Math.floor(h); };
function noise3(x, y, z, s) { const X = Math.floor(x), Y = Math.floor(y), Z = Math.floor(z), fx = x - X, fy = y - Y, fz = z - Z, u = t => t * t * (3 - 2 * t), a = u(fx), b = u(fy), c = u(fz); let r = 0;
  for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) for (let k = 0; k < 2; k++) r += hash(X + i, Y + j, Z + k, s) * (i ? a : 1 - a) * (j ? b : 1 - b) * (k ? c : 1 - c); return r; }
function normals(P, I) { const N = new Float32Array(P.length);
  for (let i = 0; i < I.length; i += 3) { const a = I[i] * 3, b = I[i + 1] * 3, c = I[i + 2] * 3, ux = P[b] - P[a], uy = P[b + 1] - P[a + 1], uz = P[b + 2] - P[a + 2], vx = P[c] - P[a], vy = P[c + 1] - P[a + 1], vz = P[c + 2] - P[a + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx; for (const k of [a, b, c]) { N[k] += nx; N[k + 1] += ny; N[k + 2] += nz; } }
  for (let i = 0; i < N.length; i += 3) { const l = Math.hypot(N[i], N[i + 1], N[i + 2]) || 1; N[i] /= l; N[i + 1] /= l; N[i + 2] /= l; } return N; }

// ---------- the space inside the torso ----------
// The outer surface of the ribcage and belly cavity: [height, half width, front z, back z]. Everything inside is
// placed from this and then kept a safe distance under the real skin.
const ENV = [
  [0.890, .132, .084, -.070], [0.960, .148, .088, -.068], [1.020, .140, .086, -.064], [1.080, .124, .082, -.056],
  [1.140, .124, .082, -.064], [1.200, .134, .086, -.078], [1.260, .142, .090, -.088], [1.320, .144, .089, -.094],
  [1.380, .134, .082, -.096], [1.430, .108, .066, -.094], [1.465, .064, .050, -.086], [1.480, .040, .040, -.078]];
const EX = 2.4;   // how boxy the barrel is
function envAt(y) { const T = ENV; if (y <= T[0][0]) return T[0]; if (y >= T[T.length - 1][0]) return T[T.length - 1];
  for (let i = 0; i < T.length - 1; i++) if (y <= T[i + 1][0]) { const f = (y - T[i][0]) / (T[i + 1][0] - T[i][0]), g = f * f * (3 - 2 * f); return T[i].map((v, j) => v + (T[i + 1][j] - v) * (j ? g : f)); }
  return T[T.length - 1]; }
// a point on the cavity surface: th = 0 at the back midline, PI at the front, positive toward +X; inset moves it inward
function env(y, th, inset) { const e = envAt(y), zc = (e[2] + e[3]) / 2, rz = Math.max(.004, (e[2] - e[3]) / 2 - inset), rx = Math.max(.004, e[1] - inset), k = 2 / EX;
  return [rx * sp(Math.sin(th), k), y, zc - rz * sp(Math.cos(th), k)]; }
const envCenter = y => { const e = envAt(y); return [0, y, (e[2] + e[3]) / 2]; };
// pull a point inside the cavity surface (at this inset) if it's outside it
function clampEnv(p, inset) { const e = envAt(p[1]), zc = (e[2] + e[3]) / 2, rz = Math.max(.004, (e[2] - e[3]) / 2 - inset), rx = Math.max(.004, e[1] - inset);
  const g = Math.pow(Math.abs(p[0]) / rx, EX) + Math.pow(Math.abs(p[2] - zc) / rz, EX); if (g <= 1) return p; const s = Math.pow(g, -1 / EX); return [p[0] * s, p[1], zc + (p[2] - zc) * s]; }
// push a point out onto the cavity surface (used to seat the inner edge of a skin hole on the muscle wall)
function projectEnv(p, inset) { const e = envAt(p[1]), zc = (e[2] + e[3]) / 2, rz = Math.max(.004, (e[2] - e[3]) / 2 - inset), rx = Math.max(.004, e[1] - inset);
  const g = Math.pow(Math.abs(p[0]) / rx, EX) + Math.pow(Math.abs(p[2] - zc) / rz, EX); const s = Math.pow(Math.max(g, 1e-9), -1 / EX); return [p[0] * s, p[1], zc + (p[2] - zc) * s]; }

// The real skin, as a lookup: how far the torso surface is from the body's centre line at each height and direction.
function skinTable(torso) { const Y0 = .86, DY = .005, NY = Math.ceil((1.55 - Y0) / DY) + 1, NA = 64, T = new Float32Array(NY * NA).fill(1e9), P = torso.P;
  for (let i = 0; i < P.length / 3; i++) { const y = P[i * 3 + 1], r = Math.hypot(P[i * 3], P[i * 3 + 2]), a = Math.atan2(P[i * 3], P[i * 3 + 2]);
    const yi = Math.round((y - Y0) / DY), ai = ((Math.round((a + PI) / TAU * NA) % NA) + NA) % NA; if (yi < 0 || yi >= NY) continue;
    for (let dy = -1; dy <= 1; dy++) for (let da = -1; da <= 1; da++) { const yy = yi + dy, aa = (ai + da + NA) % NA; if (yy < 0 || yy >= NY) continue; const k = yy * NA + aa; if (r < T[k]) T[k] = r; } }
  for (let pass = 0; pass < 6; pass++) for (let yi = 0; yi < NY; yi++) for (let ai = 0; ai < NA; ai++) { const k = yi * NA + ai; if (T[k] < 1e8) continue; let s = 0, c = 0;
    for (const [dy, da] of [[0, 1], [0, -1], [1, 0], [-1, 0]]) { const yy = yi + dy, aa = (ai + da + NA) % NA; if (yy < 0 || yy >= NY) continue; const v = T[yy * NA + aa]; if (v < 1e8) { s += v; c++; } } if (c) T[k] = s / c; }
  const rho = (y, a) => { const fy = Math.min(NY - 1.001, Math.max(0, (y - Y0) / DY)), fa = ((a + PI) / TAU * NA % NA + NA) % NA, y0 = Math.floor(fy), a0 = Math.floor(fa), ty = fy - y0, ta = fa - a0, a1 = (a0 + 1) % NA;
    const v = (yy, aa) => { const q = T[yy * NA + aa]; return q < 1e8 ? q : .1; };
    return (v(y0, a0) * (1 - ta) + v(y0, a1) * ta) * (1 - ty) + (v(y0 + 1, a0) * (1 - ta) + v(y0 + 1, a1) * ta) * ty; };
  // keep a point at least `wall` under the skin
  const under = (p, wall) => { const r = Math.hypot(p[0], p[2]), lim = rho(p[1], Math.atan2(p[0], p[2])) - wall; if (r <= lim || r < 1e-6) return p; const s = Math.max(.05, lim) / r; return [p[0] * s, p[1], p[2] * s]; };
  // where the skin of the back is at (x, y): the z of the surface behind the body
  const back = (x, y) => { let a = -.3, b = 0; for (let k = 0; k < 30; k++) { const z = (a + b) / 2; if (Math.hypot(x, z) > rho(y, Math.atan2(x, z))) a = z; else b = z; } return (a + b) / 2; };
  return { rho, under, back }; }

// ---------- mesh builders ----------
function finish(name, P, I, rot, code) { const n = P.length / 3, Pf = new Float32Array(P), I32 = Uint32Array.from(I);
  let vol = 0; for (let i = 0; i < I32.length; i += 3) { const a = I32[i] * 3, b = I32[i + 1] * 3, c = I32[i + 2] * 3; vol += Pf[a] * (Pf[b + 1] * Pf[c + 2] - Pf[b + 2] * Pf[c + 1]) - Pf[a + 1] * (Pf[b] * Pf[c + 2] - Pf[b + 2] * Pf[c]) + Pf[a + 2] * (Pf[b] * Pf[c + 1] - Pf[b + 1] * Pf[c]); }
  if (vol < 0) for (let i = 0; i < I32.length; i += 3) { const t = I32[i + 1]; I32[i + 1] = I32[i + 2]; I32[i + 2] = t; }
  const COL = new Uint8Array(n * 4), R = new Float32Array(n), J = new Uint8Array(n * 4), W = new Float32Array(n * 4);
  for (let i = 0; i < n; i++) { COL[i * 4 + 3] = code * 17; R[i] = typeof rot === 'function' ? rot(i) : rot;
    // bend with the body: the hips and chest bones share the torso by height, the same as the skin over it
    const w = Math.min(1, Math.max(0, (Pf[i * 3 + 1] - 1.05) / .205)); J[i * 4] = 0; J[i * 4 + 1] = 1; W[i * 4] = 1 - w; W[i * 4 + 1] = w; }
  return { name, slot: null, P: Pf, N: normals(Pf, I32), I: I32, J, W, UV: new Float32Array(n * 2), UV2: new Float32Array(n * 2), COL, rot: R, touch: new Float32Array(n) }; }

// a tube swept along a path. pts: [{p, out, ra, rb}] where `out` points away from the body, ra is the half size across
// it (a rib's height) and rb the half size along it (a rib's thickness). ends: 'round' or 'broken'.
function sweep(name, pts, o) { const seg = o.seg || 6, n = pts.length, P = [], I = [], rots = [], dark = [], seed = o.seed || 1;
  for (let j = 0; j < n; j++) { const a = pts[Math.max(0, j - 1)].p, b = pts[Math.min(n - 1, j + 1)].p, t = unit(sub(b, a)); let out = pts[j].out; out = unit(sub(out, mul(t, dot(out, t)))); const up = unit(cross(t, out));
    const broke = (j === 0 && o.endA === 'broken') || (j === n - 1 && o.endB === 'broken');
    for (let s = 0; s < seg; s++) { const an = s / seg * TAU, jag = broke ? .7 + .5 * hash(s, j, seed, 3) : 1, lean = broke ? (hash(s, 7, seed, j) - .3) * .008 * (j === 0 ? -1 : 1) : 0;
      const q = add(add(add(pts[j].p, mul(out, pts[j].rb * Math.cos(an) * jag)), mul(up, pts[j].ra * Math.sin(an) * jag)), mul(t, lean)); P.push(q[0], q[1], q[2]); rots.push(broke ? o.rot - .04 : o.rot); } }
  for (let j = 0; j < n - 1; j++) for (let s = 0; s < seg; s++) { const a = j * seg + s, b = j * seg + (s + 1) % seg, c = a + seg, d = b + seg; I.push(a, b, c, b, d, c); }
  const cap = (j, end, sign) => { const a = pts[Math.max(0, j - 1)].p, b = pts[Math.min(n - 1, j + 1)].p, t = unit(sub(b, a)), k = P.length / 3, broke = end === 'broken';
    const hollow = end === 'hollow', c = add(pts[j].p, mul(t, sign * (broke ? -.003 : hollow ? -.012 : pts[j].rb * .9))); if (hollow) dark.push(k);   // an open tube: you look down into the dark
    P.push(c[0], c[1], c[2]); rots.push(broke ? .7 : o.rot);   // a broken end shows the red marrow
    for (let s = 0; s < seg; s++) { const x = j * seg + s, y = j * seg + (s + 1) % seg; if (sign > 0) I.push(x, y, k); else I.push(y, x, k); } };
  cap(0, o.endA, -1); cap(n - 1, o.endB, 1);
  const part = finish(name, P, I, i => rots[i], o.code); dark.forEach(k => { part.COL[k * 4] = 235; }); return part; }

// a lumpy closed blob: an ellipsoid pushed through `shape` (which can clamp it into the cavity, flatten a side, ...)
function blob(name, c, r, o) { const U = o.u || 14, V = o.v || 10, P = [], I = [];
  for (let j = 0; j <= V; j++) { const ph = j / V * PI; for (let i = 0; i < U; i++) { const th = i / U * TAU; let p = [c[0] + r[0] * Math.sin(ph) * Math.cos(th), c[1] + r[1] * Math.cos(ph), c[2] + r[2] * Math.sin(ph) * Math.sin(th)];
    if (o.shape) p = o.shape(p); P.push(p[0], p[1], p[2]); } }
  for (let j = 0; j < V; j++) for (let i = 0; i < U; i++) { const a = j * U + i, b = j * U + (i + 1) % U, c2 = a + U, d = b + U; I.push(a, c2, b, b, c2, d); }
  return finish(name, P, I, o.rot, o.code); }

// a flat bone: a grid of centre points, each with a half thickness, given two faces and a rim round the edge.
// rows[j][i] = { p, t }. The faces are pushed apart along the grid's own normal.
function plate(name, rows, o) { const nj = rows.length, ni = rows[0].length, P = [], I = [], at = (j, i) => rows[Math.max(0, Math.min(nj - 1, j))][Math.max(0, Math.min(ni - 1, i))].p, N = [];
  for (let j = 0; j < nj; j++) for (let i = 0; i < ni; i++) { let n = cross(sub(at(j, i + 1), at(j, i - 1)), sub(at(j + 1, i), at(j - 1, i))); if (len(n) < 1e-10) n = N.length ? N[N.length - 1] : [0, 0, 1]; N.push(unit(n)); }
  for (const sgn of [1, -1]) for (let j = 0; j < nj; j++) for (let i = 0; i < ni; i++) { const q = add(rows[j][i].p, mul(N[j * ni + i], sgn * rows[j][i].t)), c = o.clamp ? o.clamp(q) : q; P.push(c[0], c[1], c[2]); }
  const id = (s, j, i) => s * nj * ni + j * ni + i;
  for (let j = 0; j < nj - 1; j++) for (let i = 0; i < ni - 1; i++) { const a = id(0, j, i), b = id(0, j, i + 1), c = id(0, j + 1, i), d = id(0, j + 1, i + 1); I.push(a, b, c, b, d, c);
    const e = id(1, j, i), f = id(1, j, i + 1), g = id(1, j + 1, i), h = id(1, j + 1, i + 1); I.push(e, g, f, f, g, h); }
  const loop = []; for (let i = 0; i < ni; i++) loop.push([0, i]); for (let j = 1; j < nj; j++) loop.push([j, ni - 1]); for (let i = ni - 2; i >= 0; i--) loop.push([nj - 1, i]); for (let j = nj - 2; j >= 1; j--) loop.push([j, 0]);
  for (let k = 0; k < loop.length; k++) { const a = loop[k], b = loop[(k + 1) % loop.length], f0 = id(0, a[0], a[1]), f1 = id(0, b[0], b[1]), b0 = id(1, a[0], a[1]), b1 = id(1, b[0], b[1]); I.push(f0, b0, f1, f1, b0, b1); }
  const part = finish(name, P, I, o.rot, o.code);
  for (let s = 0; s < 2; s++) for (let j = 0; j < nj; j++) for (let i = 0; i < ni; i++) if (rows[j][i].ao) part.COL[id(s, j, i) * 4] = Math.round(255 * Math.min(1, rows[j][i].ao));   // hollows drawn a little darker
  return part; }
// points along a smoothed path at even steps of its length
function resample(raw, n) { const sm = smooth(raw, 8), L = [0]; for (let i = 1; i < sm.length; i++) L.push(L[i - 1] + len(sub(sm[i], sm[i - 1]))); const out = [];
  for (let k = 0; k <= n; k++) { const d = L[L.length - 1] * k / n; let i = 1; while (i < sm.length - 1 && L[i] < d) i++; const f = (d - L[i - 1]) / Math.max(1e-9, L[i] - L[i - 1]); out.push(add(sm[i - 1], mul(sub(sm[i], sm[i - 1]), f))); } return out; }

// smooth a path of points (Catmull-Rom), k extra points per span
function smooth(pts, k) { const o = [], n = pts.length, g = i => pts[Math.max(0, Math.min(n - 1, i))];
  for (let i = 0; i < n - 1; i++) for (let s = 0; s < k; s++) { const t = s / k, a = g(i - 1), b = g(i), c = g(i + 1), d = g(i + 2);
    o.push(b.map((_, j) => .5 * (2 * b[j] + (-a[j] + c[j]) * t + (2 * a[j] - 5 * b[j] + 4 * c[j] - d[j]) * t * t + (-a[j] + 3 * b[j] - 3 * c[j] + d[j]) * t * t * t))); }
  o.push(pts[n - 1]); return o; }

// ---------- the ribcage ----------
const RIB_IN = .006;                                   // rib centres sit this far inside the cavity surface
// The back ends sit on the thoracic spine, which starts at the base of the neck (T1, well above the top of the
// breastbone) and runs down 2.85 cm a vertebra. Each rib slopes down to the front, so its bone ends about two
// vertebrae lower than it starts. The upper ribs' cartilage runs level to the breastbone; the lower ribs drop
// further (rib 10 ends at about the second or third lumbar vertebra, a hand's width above the hip bone) and their
// cartilage sweeps back up along the costal arch. (An earlier build had the back ends 6 cm too low, which made all the
// cartilage climb steeply and bunch up at the front, and the lower ribs stop 5 cm short at the bottom.)
// Where the bone ends and the cartilage begins moves round to the side going down: the first rib's cartilage is about
// 2.5 cm long, the seventh's about 12 cm. That is what makes the wide upside-down V under the chest.
const RIBS = [   // back height, drop to the front end, where the bone ends (fraction of the way round), sternum height
  null, [1.515, .060, .88, 1.440], [1.4865, .0765, .83, 1.412], [1.458, .083, .81, 1.385], [1.4295, .0945, .795, 1.358],
  [1.401, .111, .76, 1.332], [1.3725, .1275, .71, 1.306], [1.344, .134, .64, 1.283], [1.3155, .1405, .59, 0],
  [1.287, .147, .55, 0], [1.2585, .1485, .50, 0], [1.230, .100, .40, 0], [1.2015, .0615, .28, 0]];
const TH0 = .04 * PI;                                   // ribs start just beside the spine
const ribTY = (i, u) => { const r = RIBS[i], thE = r[2] * PI; return [TH0 + (thE - TH0) * u, r[0] - r[1] * Math.pow(u, 1.25)]; };
// where a rib's cartilage runs, in (angle, height): to the sternum for true ribs, up into the cartilage above for 8-10
function cartTY(i, u) { const r = RIBS[i], a = ribTY(i, 1);
  let b; if (r[3]) { const e = envAt(r[3]); b = [PI - Math.asin(Math.min(1, Math.pow(.017 / (e[1] - RIB_IN), EX / 2))), r[3]]; } else b = cartTY(i - 1, .42);
  const s = u * u * (3 - 2 * u), lift = r[3] ? 0 : .012 * Math.sin(u * PI);   // the false ribs' cartilage bows a little toward the arch
  return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * (r[3] ? s : u) - lift]; }
function buildRibs(K, opt) { const parts = [], dk = opt.detail, tiny = dk < .4, seg = dk >= .9 ? 6 : dk >= .5 ? 5 : tiny ? 3 : 4, breaks = opt.breaks || {};
  for (let i = 1; i <= 12; i++) for (const side of [1, -1]) { const sd = side > 0 ? 'L' : 'R', key = i + sd, big = i >= 2 && i <= 10;
    const nb = tiny ? (i >= 11 ? 4 : 6) : Math.max(6, Math.round((i >= 11 ? 9 : 20) * Math.max(dk, .45))), ra = (i === 1 ? .0058 : .0066) * (i >= 11 ? .85 : 1), rb = .0042;
    const at = (ty, r1, r2) => { const p = K.under(env(ty[1], ty[0] * side, RIB_IN), .0085); return { p, out: unit(sub(p, envCenter(p[1]))), ra: r1, rb: r2 }; };
    const bone = []; for (let j = 0; j <= nb; j++) { const u = j / nb, taper = j === 0 ? .7 : (i >= 11 ? 1 - .45 * u : 1); bone.push(Object.assign(at(ribTY(i, u), ra * taper, rb * taper), { u })); }
    const br = breaks[key];   // [from, to] along the bone: that stretch is gone, the ends snapped
    if (br) { const A = bone.filter(q => q.u <= br[0]), B = bone.filter(q => q.u >= br[1]);
      if (A.length > 1) parts.push(sweep('rib' + key, A, { seg, rot: .93, code: CODE.bone, endB: 'broken', seed: i * 7 + (side > 0 ? 1 : 2) }));
      if (B.length > 1) parts.push(sweep('rib' + key + 'b', B, { seg, rot: .93, code: CODE.bone, endA: 'broken', seed: i * 11 + (side > 0 ? 3 : 4) }));
    } else parts.push(sweep('rib' + key, bone, { seg, rot: .93, code: CODE.bone }));
    if (i <= 10 && !(br && br[1] >= 1)) { const nc = tiny ? 3 : Math.max(4, Math.round((big ? 9 : 5) * Math.max(dk, .45))), cart = [];
      for (let j = 0; j <= nc; j++) cart.push(at(cartTY(i, j / nc), ra * .86, rb * .9));
      parts.push(sweep('cartilage' + key, cart, { seg, rot: .86, code: CODE.cartilage })); } }
  return parts; }

function buildSternum(K, opt) { const prof = [[1.455, .020], [1.446, .027], [1.428, .029], [1.408, .019], [1.385, .0185], [1.33, .021], [1.292, .0205], [1.274, .016], [1.258, .009], [1.240, .0045]];
  const pts = prof.map(([y, w]) => { const p = K.under(add(env(y, PI, RIB_IN), [0, 0, .001]), .007); return { p, out: [0, 0, 1], ra: w, rb: .0046 }; });
  // ra runs across the body here: the sweep's "up" is tangent x out = (0,-1,0) x (0,0,1) = (-1,0,0)
  return [sweep('sternum', pts, { seg: opt.detail >= .5 ? 8 : 6, rot: .93, code: CODE.bone })]; }

function buildClavicles(K, opt) { const parts = [];
  for (const side of [1, -1]) { const raw = smooth([[.020, 1.451, .050], [.060, 1.461, .058], [.100, 1.468, .040], [.140, 1.462, .014], [.178, 1.452, -.004]], opt.detail >= .5 ? 4 : 2);
    // (the outer third runs inside the top of the shoulder, which belongs to the upper arm's mesh, so it is placed by his shoulder joint, not by the torso's skin)
    const pts = raw.map((q, j) => { const p = q[0] > .125 ? [q[0] * side, q[1], q[2]] : K.under([q[0] * side, q[1], q[2]], .008); return { p, out: unit([p[0] * .3, .5, 1]), ra: .0062 * (j === 0 ? 1.25 : 1), rb: .0055 }; });
    parts.push(girdle(sweep('clavicle' + (side > 0 ? 'L' : 'R'), pts, { seg: opt.detail >= .5 ? 6 : 4, rot: .93, code: CODE.bone }), side)); }
  return parts; }

// The shoulder girdle (collarbone and shoulder blade) moves as one piece with the shoulder: mostly the clavicle bone
// of the skeleton (as the skin over the top of the shoulder does), the rest the chest, the same on every vertex so
// the bones stay rigid.
function girdle(part, side) { for (let i = 0; i < part.P.length / 3; i++) { part.J[i * 4] = 1; part.J[i * 4 + 1] = side > 0 ? 3 : 4; part.W[i * 4] = .2; part.W[i * 4 + 1] = .8; } return part; }

// ---------- the shoulder blades ----------
// opt.shoulder is his left shoulder joint: the socket is set a humeral head's radius inside it and the acromion over it,
// so the girdle is sized to his frame, not to a textbook body.
function buildScapulae(K, opt) { const GLX = opt.shoulder[0] - .026, parts = [], dk = opt.detail, tiny = dk < .4, NJ = dk >= .9 ? 8 : dk >= .5 ? 6 : 4, NI = dk >= .9 ? 5 : dk >= .5 ? 4 : 3, seg = dk >= .9 ? 6 : dk >= .5 ? 5 : 4;
  for (const side of [1, -1]) { const sd = side > 0 ? 'L' : 'R', mir = p => [p[0] * side, p[1], p[2]], keep = p => { const q = K.under(mir(p), .008); return [q[0] * side, q[1], q[2]]; };   // work on his left, mirror at the end
    // three corners: the top and bottom of the inner edge sit a finger's depth under the skin of the back; the outer
    // corner is the socket, at the shoulder joint
    const SA = [.080, 1.478, K.back(.080, 1.478) + .018], IA = [.092, 1.305, K.back(.092, 1.305) + .018], GL = [GLX, opt.shoulder[1] - .009, -.040];
    let n = unit(cross(sub(IA, SA), sub(GL, SA))); if (n[2] > 0) n = mul(n, -1);                 // the blade's back face looks toward the skin
    const e1 = unit(sub(IA, SA)), e2 = unit(cross(e1, n)).map(v => v), L = len(sub(IA, SA)), g = sub(GL, SA), ag = dot(g, e1), bgRaw = dot(g, e2), f2 = bgRaw < 0 ? mul(e2, -1) : e2, bg = Math.abs(bgRaw);
    // a point on the blade from its own coordinates: a down the inner edge, b out toward the socket, h off its back face
    // (the blade is bowed along its height to lie on the curve of the ribcage; past the ribcage its neck bends forward to bring the socket to the joint)
    const on = (a, b, h) => add(add(add(SA, mul(e1, a)), mul(f2, b)), mul(n, (h || 0) + .0035 * Math.sin(PI * Math.min(1, Math.max(0, a / L))) * Math.sin(PI * Math.min(1, Math.max(0, b / bg))) + .009 * Math.sin(PI * Math.min(1, Math.max(0, a / L))) * (1 - Math.min(1, Math.max(0, b / bg))) - .024 * Math.pow(ss(b / bg, .55, 1), 2)));
    const inner = u => [u * L, -.007 * Math.sin(PI * u)];                                        // the inner edge bows toward the spine
    const outer = u => u < .22 ? [ag - .020 + .040 * (u / .22), bg] : (() => { const w = (u - .22) / .78; return [ag + .020 + (L - ag - .020) * w, bg * (1 - w) + .005 * w - .012 * Math.sin(PI * w)]; })();   // the socket, then the outer edge down to the bottom corner
    const rows = []; for (let j = 0; j <= NJ; j++) { const u = j / NJ, A = inner(u), B = outer(u), row = [];
      for (let i = 0; i <= NI; i++) { const v = i / NI, a = A[0] + (B[0] - A[0]) * v, b = A[1] + (B[1] - A[1]) * v;
        const t = .0028 + .0022 * ss(v, .22, 0) + .0042 * ss(v, .7, 1) * (1 - .55 * u) + .0045 * ss(v, .75, 1) * ss(u, .4, .1);    // thin in the middle, thick along the outer edge and at the socket
        // the two hollows of the blade, above and below the ridge, sit a shade darker than its thick edges
        const ao = .30 * Math.exp(-Math.pow((u - .62) / .24, 2) - Math.pow((v - .45) / .32, 2)) + .26 * Math.exp(-Math.pow((u - .11) / .09, 2)) * Math.sin(PI * v);
        row.push({ p: on(a, b), t, ao }); } rows.push(row); }
    parts.push(plate('scapula' + sd, rows.map(r => r.map(q => ({ p: mir(q.p), t: q.t, ao: q.ao }))), { rot: .93, code: CODE.bone, clamp: p => Math.abs(p[0]) > .135 ? p : K.under(p, .0075) }));
    // the spine of the scapula: a ridge standing off the back of the blade, low at the inner edge and tall at the
    // shoulder, where it leaves the blade and turns forward over the joint as the acromion
    const ridge = [[.27 * L, -.003, .0035, .0042], [.27 * L - .010, .28 * bg, .0065, .0045], [.27 * L - .022, .58 * bg, .0095, .0048], [.27 * L - .034, .84 * bg, .0115, .0048]].map(([a, b, ra, rb]) => ({ p: on(a, b, ra * .85), ra, rb }));
    // the acromion sits over the top of his shoulder joint, inside the shoulder (placed from the joint, not from the torso's skin)
    const J = opt.shoulder, acro = [[J[0] - .031, J[1] + .036, J[2] - .050, .0115, .0046], [J[0] - .011, J[1] + .041, J[2] - .030, .0125, .0044], [J[0] - .003, J[1] + .042, J[2] - .002, .0100, .0040]].map(([x, y, z, ra, rb]) => ({ p: [x, y, z], ra, rb, free: true }));
    const path = tiny ? [ridge[0], ridge[2], acro[0], acro[2]] : ridge.concat(acro);
    parts.push(sweep('scapulaSpine' + sd, path.map(q => ({ p: mir(q.free ? q.p : keep(q.p)), out: [0, 1, 0], ra: q.ra, rb: q.rb })), { seg, rot: .93, code: CODE.bone }));
    if (!tiny) {
      // the socket for the arm: a shallow oval pad on the outer corner, and the coracoid, the hook that points forward under the collarbone
      const GA = on(ag, bg);   // the outer corner, where the socket is
      parts.push(blob('glenoid' + sd, mir(add(GA, [.004, 0, .002])), [.0075, .020, .0145], { u: dk >= .9 ? 8 : 6, v: dk >= .9 ? 6 : 5, code: CODE.cartilage, rot: .88 }));
      const cor = [[-.010, .014, .006, .0062], [-.018, .028, .026, .0056], [-.010, .022, .048, .0046]].map(([x, y, z, r]) => ({ p: mir(add(GA, [x, y, z])), out: [0, 1, 0], ra: r, rb: r }));
      parts.push(sweep('coracoid' + sd, cor, { seg: Math.max(4, seg - 1), rot: .93, code: CODE.bone })); }
    parts.filter(p => p.name.endsWith(sd) && /^(scapula|glenoid|coracoid)/.test(p.name)).forEach(p => girdle(p, side)); }
  return parts; }

function buildSpine(K, opt) { const parts = [], tiny = opt.detail < .4, seg = opt.detail >= .5 ? 8 : tiny ? 5 : 6, ys = [];
  for (let i = 1; i <= 12; i++) ys.push([RIBS[i][0], .0115 + .0004 * i]);                        // thoracic, one per rib
  for (let i = 0; i < 5; i++) ys.push([1.164 - i * .037, .0175]);                                // lumbar, heavier and further apart, down to the sacrum
  // (the sacrum, below the last lumbar vertebra, is built with the pelvis)
  ys.forEach(([y, r], k) => { const e = envAt(y), zc = e[3] + .0275 + r * .4;
    // the vertebral body: a short drum, inside, in front of the back wall
    const c = clampEnv([0, y, zc], .020 + r); if (!tiny) parts.push(sweep('vertebra' + k, [{ p: add(c, [0, .0105, 0]), out: [0, 0, 1], ra: r, rb: r * .86 }, { p: add(c, [0, -.0105, 0]), out: [0, 0, 1], ra: r, rb: r * .86 }], { seg, rot: .92, code: CODE.bone }));
    // the spinous process: the knob you can feel down the middle of the back, angled down
    const a = K.under([0, y - .002, e[3] + .012], .006), b = K.under([0, y - .017, e[3] - .0045], .0055);
    parts.push(sweep('spinous' + k, [{ p: a, out: [0, 1, 0], ra: .0052, rb: .0075 }, { p: b, out: [0, 1, 0], ra: .0042, rb: .006 }], { seg: Math.max(4, seg - 2), rot: .92, code: CODE.bone })); });
  return parts; }

// ---------- the pelvis ----------
// opt.full adds the parts no wound reaches yet (hip sockets, sit bones, pubis), for the review renders and for
// late-stage zombies later.
function buildPelvis(K, opt) { const parts = [], dk = opt.detail, tiny = dk < .4, NU = dk >= .9 ? 12 : dk >= .5 ? 9 : 5, NV = dk >= .9 ? 4 : dk >= .5 ? 3 : 2, seg = dk >= .9 ? 8 : dk >= .5 ? 6 : 4, D = PI / 180;
  const under = (p, w) => K.under(p, w);
  for (const side of [1, -1]) { const sd = side > 0 ? 'L' : 'R', mir = p => [p[0] * side, p[1], p[2]];
    // the iliac crest: from the dimple at the back (PSIS) up over the hip and down to the point at the front (ASIS),
    // a little under the skin all the way, as it is in life. [direction round the body, height, depth under the skin]
    const crest = resample([[150, .984, .024], [138, 1.010, .015], [121, 1.029, .014], [101, 1.040, .013], [83, 1.034, .013], [69, 1.013, .014], [58, .990, .016]].map(([a, y, d]) => { const r = K.rho(y, a * D * side) - d; return [r * Math.sin(a * D), y, r * Math.cos(a * D)]; }), NU);
    // the bottom of the wing: from behind the hip socket, over the top of it, to the front
    const base = resample([[.050, .946, -.062], [.062, .934, -.040], [.078, .936, -.018], [.094, .938, .004], [.104, .946, .026], [.108, .956, .046]], NU);
    const rows = []; for (let j = 0; j <= NV; j++) { const v = j / NV, row = [];
      for (let i = 0; i <= NU; i++) { const c = crest[i], b = base[i], p = add(c, mul(sub(b, c), v)), dish = .003 * Math.sin(PI * v), r = Math.hypot(p[0], p[2]) || 1;   // the wing is dished: hollow on the inside, where the gut rests
        row.push({ p: mir([p[0] - p[0] / r * dish, p[1], p[2] - p[2] / r * dish]), t: .0066 - .0032 * ss(v, 0, .45) + .0046 * ss(v, .6, 1), ao: .26 * ss(v, .12, .5) * Math.sin(PI * i / NU) }); } rows.push(row); }
    parts.push(plate('ilium' + sd, rows, { rot: .93, code: CODE.bone, clamp: p => under(p, .0075) }));
    if (opt.full) {
      // the hip socket, open to the side for the head of the thigh bone
      const HC = [.078, .922, 0], HR = [.024, .029, .029], cup = [];
      const sock = blob('hipSocket' + sd, mir(HC), HR, { u: dk >= .9 ? 12 : 9, v: dk >= .9 ? 9 : 7, code: CODE.bone, rot: .93, shape: p => { const lx = p[0] * side - HC[0], d = Math.hypot(p[1] - HC[1], p[2] - HC[2]) / (HR[1] * .78);
        if (lx <= 0 || d >= 1) { cup.push(0); return p; } const k = 1 - d * d; cup.push(k); return [(HC[0] + lx - (lx + .011) * k) * side, p[1], p[2]]; } });
      cup.forEach((k, i) => { if (k > 0) sock.COL[i * 4] = Math.round(70 + 150 * k); });   // the cup is in shadow
      parts.push(sock);
      const rod = (name, raw, radii, k) => { const sm = smooth(raw, k); parts.push(sweep(name + sd, sm.map((q, j) => { const f = j / (sm.length - 1) * (radii.length - 1), a = Math.floor(Math.min(radii.length - 2, f)), w = f - a, R = radii[a].map((v, x) => v + (radii[a + 1][x] - v) * w);
        return { p: mir(under(q, .008)), out: [0, 0, 1], ra: R[0], rb: R[1] }; }), { seg, rot: .93, code: CODE.bone })); };
      // the pubis: forward and in from the socket to the middle, where the two sides meet
      rod('pubis', [[.078, .930, .026], [.054, .921, .054], [.028, .912, .072], [.007, .904, .078]], [[.0085, .0075], [.0085, .007], [.0165, .0075]], dk >= .5 ? 3 : 2);
      // the ischium: down behind the socket to the sit bone, then forward and up to the pubis, closing the ring
      rod('ischium', [[.076, .902, -.020], [.068, .878, -.030], [.060, .856, -.024]], [[.0115, .011], [.0125, .012], [.0155, .014]], dk >= .5 ? 3 : 2);
      rod('ischialRamus', [[.056, .855, -.014], [.046, .860, .016], [.030, .870, .048], [.010, .886, .073]], [[.0075, .0065], [.0068, .006], [.0085, .0065]], dk >= .5 ? 3 : 2); } }
  // the sacrum: a curved wedge between the two wings, wide at the top where the spine sits on it, with the row of
  // knobs down its back, and the tailbone curling forward under it
  const SJ = dk >= .9 ? 6 : dk >= .5 ? 4 : 2, SI = dk >= .9 ? 6 : dk >= .5 ? 4 : 2, sz = u => -.050 - .054 * u + .044 * u * u, sy = u => .972 - .082 * u, rows = [];
  for (let j = 0; j <= SJ; j++) { const u = j / SJ, hw = .044 * Math.pow(1 - u, 1.15) + .011, row = [];
    for (let i = 0; i <= SI; i++) { const v = i / SI * 2 - 1; row.push({ p: [-v * hw, sy(u), sz(u) + .014 * v * v * (1 - .5 * u)], t: (.0092 - .0042 * u) * (1 - .25 * v * v) }); } rows.push(row); }
  parts.push(plate('sacrum', rows, { rot: .92, code: CODE.bone, clamp: p => under(p, .0075) }));
  if (!tiny) for (const u of [.10, .34, .58]) { const a = under([0, sy(u) - .002, sz(u) - .006], .006), b = under([0, sy(u) - .015, sz(u) - .0135], .0055);
    parts.push(sweep('sacralCrest' + Math.round(u * 100), [{ p: a, out: [0, 1, 0], ra: .0048, rb: .0068 }, { p: b, out: [0, 1, 0], ra: .0038, rb: .0052 }], { seg: Math.max(4, seg - 2), rot: .92, code: CODE.bone })); }
  parts.push(sweep('coccyx', [[.889, -.0605, .0085], [.877, -.054, .0065], [.867, -.044, .0042]].map(([y, z, r]) => ({ p: under([0, y, z], .0075), out: [0, 0, -1], ra: r, rb: r * .8 })), { seg: Math.max(4, seg - 2), rot: .92, code: CODE.bone }));
  return parts; }

// ---------- the muscle wall under the ribs, and the dark lining behind the organs ----------
// Below the waist the wall narrows at the sides, inside the wings of the pelvis: the belly wall hangs from the iliac
// crests, and the hip bones flare outside it. s2 is 0 at the front and back midlines and 1 at the sides.
const pelvisTaper = (y, s2) => .042 * ss(y, 1.035, .93) * Math.pow(Math.max(0, s2), .75);
// seat a point on the muscle wall (used for the inner edge of a skin hole)
function projectWall(p, inset) { const e = envAt(p[1]), zc = (e[2] + e[3]) / 2, rz = Math.max(.004, (e[2] - e[3]) / 2 - inset), rx = Math.max(.004, e[1] - inset), gx = Math.pow(Math.abs(p[0]) / rx, EX), g = gx + Math.pow(Math.abs(p[2] - zc) / rz, EX);
  return projectEnv(p, inset + pelvisTaper(p[1], gx / Math.max(g, 1e-9))); }
function shell(name, K, inset, o) { const dk = o.detail, seg = Math.max(14, Math.round(40 * Math.max(dk, .4))), y0 = .892, y1 = o.y1 || 1.476, ny = Math.max(14, Math.round(46 * Math.max(dk, .4))), P = [], I = [];
  for (let j = 0; j <= ny; j++) { const y = y0 + (y1 - y0) * j / ny; for (let s = 0; s < seg; s++) { const th = s / seg * TAU, p = K.under(env(y, th, inset + (o.taper === false ? 0 : pelvisTaper(y, Math.sin(th) * Math.sin(th)))), inset + .0035); P.push(p[0], p[1], p[2]); } }
  for (let j = 0; j < ny; j++) for (let s = 0; s < seg; s++) { const a = j * seg + s, b = j * seg + (s + 1) % seg, c = a + seg, d = b + seg; I.push(a, b, c, b, d, c); }
  const lo = P.length / 3; P.push(...envCenter(y0)); const hi = lo + 1; P.push(...envCenter(y1));
  for (let s = 0; s < seg; s++) { I.push((s + 1) % seg, s, lo); I.push(ny * seg + s, ny * seg + (s + 1) % seg, hi); }
  const part = finish(name, P, I, o.rot, CODE.muscle);
  if (o.inward) { for (let i = 0; i < part.I.length; i += 3) { const t = part.I[i + 1]; part.I[i + 1] = part.I[i + 2]; part.I[i + 2] = t; } part.N = normals(part.P, part.I); }
  return part; }
const CORE_IN = .013, LINER_IN = .017, ORGAN_IN = .0215;

// ---------- the organs ----------
function buildOrgans(K, opt) { const parts = [], dk = opt.detail, U = Math.max(8, Math.round(16 * Math.max(dk, .45))), V = Math.max(6, Math.round(12 * Math.max(dk, .45)));
  const inside = p => clampEnv(p, ORGAN_IN), lump = (p, s, a) => { const n = noise3(p[0] * s, p[1] * s, p[2] * s, 5) - .5; return [p[0] * (1 + n * a), p[1], p[2] * (1 + n * a)]; };
  // heart: front and a little to his left, the point down and left
  const HC = [.016, 1.300, envAt(1.30)[2] - .058], HR = [.040, .050, .034];
  const heartG = p => Math.pow((p[0] - HC[0]) / (HR[0] + .008), 2) + Math.pow((p[1] - HC[1]) / (HR[1] + .008), 2) + Math.pow((p[2] - HC[2]) / (HR[2] + .008), 2);
  parts.push(blob('heart', HC, HR, { u: U, v: V, code: CODE.organ, rot: .62, shape: p => { const t = (HC[1] - p[1]) / HR[1]; const q = [p[0] + .014 * Math.max(0, t), p[1], p[2] + .004 * Math.max(0, t)]; const k = 1 - .45 * Math.max(0, t) * Math.max(0, t);
    return inside([HC[0] + (q[0] - HC[0]) * k + .014 * Math.max(0, t), q[1], HC[2] + (q[2] - HC[2]) * k]); } }));
  // lungs: they fill the ribcage either side, flat against the middle, hollowed where the heart sits
  for (const side of [1, -1]) parts.push(blob('lung' + (side > 0 ? 'L' : 'R'), [side * .070, 1.337, envCenter(1.337)[2] + .002], [.066, .108, .084], { u: U + 2, v: V + 2, code: CODE.lung, rot: .56, shape: p => {
    let q = [side * Math.max(.011, side * p[0]), Math.max(1.232 + .02 * ss(Math.abs(p[0]), .11, .03), p[1]), p[2]]; q = lump(q, 26, .05); q = inside(q);
    const g = heartG(q); if (g < 1) { const s = 1 / Math.sqrt(g); q = [HC[0] + (q[0] - HC[0]) * s, q[1], HC[2] + (q[2] - HC[2]) * s]; if (side * q[0] < .011) q[0] = side * .011; q = inside(q); }
    return q; } }));
  // liver: under the right ribs (his right is -X), thick on the right and tapering to a thin edge across the middle
  parts.push(blob('liver', [-.048, 1.203, envCenter(1.203)[2] + .020], [.090, .042, .064], { u: U + 2, v: V, code: CODE.organ, rot: .7, shape: p => { const thin = 1 - .55 * ss(p[0], -.03, .05);
    return inside(lump([p[0], 1.203 + (p[1] - 1.203) * thin - .012 * ss(p[0], -.04, .05), p[2]], 30, .04)); } }));
  // stomach: under the left ribs, a fat J
  parts.push(blob('stomach', [.050, 1.190, envCenter(1.19)[2] + .028], [.046, .040, .038], { u: U, v: V, code: CODE.gut, rot: .55, shape: p => inside([p[0] - .022 * ss(1.19 - p[1], 0, .04), p[1], p[2]]) }));
  const tube = (name, raw, r, code, rot, bulge, ks) => { const sm = smooth(raw, ks); let s = 0; const pts = sm.map((q, j) => { if (j) s += len(sub(q, sm[j - 1])); const rr = r * (1 + (bulge ? bulge * Math.sin(s * 285) : 0)) * (j === 0 || j === sm.length - 1 ? .75 : 1);
      const p = K.under(clampEnv(q, ORGAN_IN + r), ORGAN_IN + r + .004); return { p, out: [0, 0, 1], ra: rr, rb: rr }; });
    return sweep(name, pts, { seg: dk >= .9 ? 8 : dk >= .5 ? 6 : dk < .4 ? 4 : 5, rot, code }); };
  const zf = y => envAt(y)[2];
  // colon: up his right side, across under the liver and stomach, down his left, and in toward the middle
  const CR = .0185, cz = (x, y) => zf(y) - ORGAN_IN - CR - .004 - .03 * ss(Math.abs(x), .06, .11);
  const colon = [[-.090, .950], [-.100, .985], [-.104, 1.040], [-.104, 1.095], [-.092, 1.132], [-.050, 1.128], [0, 1.114], [.050, 1.126], [.092, 1.138], [.104, 1.100], [.104, 1.040], [.098, .985], [.070, .945], [.030, .930]].map(([x, y]) => [x, y, cz(x, y)]);
  parts.push(tube('colon', colon, CR, CODE.colon, .6, .27, dk >= .5 ? 4 : dk < .4 ? 1 : 2));   // lumpy: the colon is a row of pouches
  // small intestine: not a diagram but a pile. One long tube thrown into the belly in loops that wander, double back
  // and lie over each other, in three layers from the back of the belly to the front, where the front layer bulges
  // out past the belly wall (it shows through the tear). Each strand is a walk that keeps turning and is steered
  // back in when it leaves the belly.
  const frontZ = (x, y, inset) => { const e = envAt(y), zc = (e[2] + e[3]) / 2, rz = Math.max(.004, (e[2] - e[3]) / 2 - inset), rx = Math.max(.004, e[1] - inset), u = Math.min(.999, Math.abs(x) / rx); return zc + rz * Math.pow(1 - Math.pow(u, EX), 1 / EX); };
  const walk = (seed, n, x0, y0, inset, wob) => { const raw = []; let x = x0, y = y0, a = hash(seed, 1, 2, 3) * TAU, k = 0;
    for (let i = 0; i < n; i++) { k = Math.max(-60, Math.min(60, k + (hash(i, seed, 5, 7) - .5) * 30));
      const ex = x / (.086 + .016 * ss(y, 1.1, .95)), ey = (y - 1.028) / .108, out = ex * ex + ey * ey;
      if (out > .75) { let d = Math.atan2(1.028 - y, -x) - a; d = Math.atan2(Math.sin(d), Math.cos(d)); a += d * Math.min(1, (out - .75) * 1.4); }
      a += k * .006; x += Math.cos(a) * .006; y += Math.sin(a) * .006;
      raw.push([x, y, frontZ(x, y, inset) - wob * (.5 + .5 * Math.sin(i * .29 + seed * 1.7)) - .004 * Math.sin(i * .83 + seed)]); } return raw; };
  const loose = (name, raw, r, code, rot, bulge) => { const sm = smooth(raw, 2); let s = 0; const pts = sm.map((q, j) => { if (j) s += len(sub(q, sm[j - 1])); const rr = r * (1 + bulge * Math.sin(s * 240 + r * 900)) * (j === 0 || j === sm.length - 1 ? .7 : 1);
      return { p: K.under(q, .004 + r), out: [0, 0, 1], ra: rr, rb: rr }; }); return sweep(name, pts, { seg: 8, rot, code }); };
  parts.push(loose('gutBack', walk(3, 210, -.03, 1.09, .060, .012), .0128, CODE.gut, .6, .07));
  parts.push(loose('gutMid', walk(11, 230, .04, 1.05, .036, .012), .0124, CODE.gut, .58, .07));
  parts.push(loose('gutFront', walk(29, 250, -.02, 1.11, .008, .010), .0120, CODE.gut, .57, .08));
  parts.push(loose('gutFront2', walk(47, 150, .03, .99, .004, .008), .0116, CODE.gut, .57, .08));
  // among it: torn bits of the fatty apron that hangs over the gut, dark clots in the hollows, and strands of
  // sinew and vessel draped across
  for (let i = 0; i < 6; i++) { const x = (hash(i, 3, 1, 9) - .5) * .15, y = 1.045 + hash(i, 4, 1, 9) * .095, c = [x, y, frontZ(x, y, .012 + .03 * hash(i, 5, 1, 9))], sz = .008 + .008 * hash(i, 6, 1, 9);
    parts.push(blob('fat' + i, c, [sz * 1.5, sz, sz * .55], { u: 9, v: 7, code: CODE.muscle, rot: .47, shape: p => { const n = .6 + .8 * noise3(p[0] * 90, p[1] * 90, p[2] * 90, 21 + i); return K.under([c[0] + (p[0] - c[0]) * n, c[1] + (p[1] - c[1]) * n - .006 * Math.max(0, c[1] - p[1]) / sz, c[2] + (p[2] - c[2]) * n], .005); } })); }
  for (let i = 0; i < 12; i++) { const x = (hash(i, 7, 2, 9) - .5) * .17, y = .94 + hash(i, 8, 2, 9) * .2, c = [x, y, frontZ(x, y, .012 + .035 * hash(i, 9, 2, 9))], sz = .007 + .008 * hash(i, 10, 2, 9);
    parts.push(blob('clot' + i, c, [sz * 1.3, sz, sz], { u: 8, v: 6, code: CODE.organ, rot: .72, shape: p => { const n = .6 + .8 * noise3(p[0] * 110, p[1] * 110, p[2] * 110, 31 + i); return K.under([c[0] + (p[0] - c[0]) * n, c[1] + (p[1] - c[1]) * n, c[2] + (p[2] - c[2]) * n], .005); } })); }
  for (let i = 0; i < 11; i++) { const x0 = (hash(i, 11, 3, 9) - .5) * .16, y0 = 1.06 + hash(i, 12, 3, 9) * .09, x1 = x0 + (hash(i, 13, 3, 9) - .5) * .09, y1 = y0 - .05 - .1 * hash(i, 14, 3, 9), ins = .002 + .02 * hash(i, 15, 3, 9), raw = [];
    for (let j = 0; j <= 8; j++) { const u = j / 8, x = x0 + (x1 - x0) * u + .01 * Math.sin(u * 5 + i), y = y0 + (y1 - y0) * u - .012 * Math.sin(PI * u); raw.push([x, y, frontZ(x, y, ins) + .003]); }
    parts.push(loose('strand' + i, raw, .0022 + .0018 * hash(i, 16, 3, 9), CODE.muscle, .62, 0)); }
  return parts; }

// a loop of small intestine that has slid out through a hole in the belly and hangs down the front.
// o.x: where across the belly; o.top, o.drop, o.wide: where it leaves the belly, how far it hangs and how wide it is
// (given any of these, the loop is laid on the skin exactly, for loops off to one side)
function spilledLoop(K, opt, o) { const SR = .0122, sx = o.x || .02, exact = o.top !== undefined, top = exact ? o.top : 1.045, drop = o.drop || 1, wide = o.wide || 1;
  const X = dx => sx + dx * wide, Y = y => top - (1.045 - y) * drop;
  const frontAt = (x, y) => { if (!exact) return K.rho(y, Math.atan2(sx, .1)) + SR + .003; let z = .1; for (let k = 0; k < 3; k++) { const r = K.rho(y, Math.atan2(x, z)) + SR + .003; z = Math.sqrt(Math.max(1e-4, r * r - x * x)); } return z; };
  const inAt = (x, y) => exact ? clampEnv([x, y, envAt(y)[2] - ORGAN_IN - SR], ORGAN_IN + SR)[2] : envAt(y)[2] - ORGAN_IN - SR;
  const raw = [[-.03, 1.045, 'i', 0], [-.025, 1.03, 'i', .02], [-.022, 1.012, 'f', -.006], [-.026, .985, 'f', 0], [-.02, .955, 'f', .004], [0, .932, 'f', .006],
    [.022, .952, 'f', .004], [.03, .985, 'f', 0], [.026, 1.015, 'f', -.006], [.03, 1.035, 'i', .02], [.036, 1.05, 'i', 0]].map(([dx, y, w, dz]) => { const x = X(dx), yy = Y(y); return [x, yy, (w === 'i' ? inAt(x, yy) : frontAt(x, yy)) + dz]; });
  const pts = smooth(raw, opt.detail >= .5 ? 4 : opt.detail < .4 ? 1 : 2).map((q, j, a) => ({ p: q, out: [0, 0, 1], ra: SR * (j === 0 || j === a.length - 1 ? .8 : 1), rb: SR * (j === 0 || j === a.length - 1 ? .8 : 1) }));
  const part = sweep('spilledLoop', pts, { seg: opt.detail >= .9 ? 8 : opt.detail >= .5 ? 6 : opt.detail < .4 ? 4 : 5, rot: .58, code: CODE.gut });
  for (let i = 0; i < part.P.length / 3; i++) { part.J[i * 4] = 0; part.J[i * 4 + 1] = 1; const w = Math.min(1, Math.max(0, (part.P[i * 3 + 1] - 1.05) / .205)); part.W[i * 4] = 1 - w; part.W[i * 4 + 1] = w; }
  return part; }

// a long limb bone: a shaft from A to B, flared at both ends, rigid on one joint
function longBone(name, A, B, r, joint, dk) { const n = 7, ax = unit(sub(B, A)), out = unit(cross(ax, Math.abs(ax[2]) < .9 ? [0, 0, 1] : [1, 0, 0])), pts = [];
  for (let j = 0; j < n; j++) { const u = j / (n - 1), fl = 1 + .42 * Math.pow(Math.abs(u * 2 - 1), 3); pts.push({ p: add(A, mul(sub(B, A), u)), out, ra: r * fl, rb: r * fl }); }
  const part = sweep(name, pts, { seg: dk >= .9 ? 8 : dk >= .5 ? 6 : 4, rot: .93, code: CODE.bone });
  for (let i = 0; i < part.P.length / 3; i++) { part.J[i * 4] = joint; part.J[i * 4 + 1] = 0; part.W[i * 4] = 1; part.W[i * 4 + 1] = 0; part.COL[i * 4] = 40; }
  return part; }

// fix a part rigidly to one joint
function pin(part, joint) { for (let i = 0; i < part.P.length / 3; i++) { part.J[i * 4] = joint; part.J[i * 4 + 1] = 0; part.W[i * 4] = 1; part.W[i * 4 + 1] = 0; } return part; }

module.exports = { projectWall, pelvisTaper, plate, buildScapulae, buildPelvis, girdle, pin, longBone, CODE, ENV, env, envAt, envCenter, clampEnv, projectEnv, skinTable, sweep, blob, smooth, buildRibs, buildSternum, buildClavicles, buildSpine, buildOrgans, spilledLoop, shell, CORE_IN, LINER_IN, ORGAN_IN, RIB_IN, RIBS, noise3 };
