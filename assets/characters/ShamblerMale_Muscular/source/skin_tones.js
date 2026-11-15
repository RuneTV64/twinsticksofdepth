// Skin tones, looks and hair shared by every body shader: the living skin (gen_living_shader.js) and the
// zombie decay shader (gen_decay_shader.js) both build from this, so a person keeps their tone, freckles,
// vitiligo and hair when they turn.
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const ramp = st => { const s = st.map(hex), o = []; for (let i = 0; i < 8; i++) { const t = i / 7 * (s.length - 1), k = Math.min(Math.floor(t), s.length - 2), f = t - k; o.push(s[k].map((v, j) => Math.round(v + (s[k + 1][j] - v) * f))); } return o; };
// nails: the approved body's recipe, a pink-white nail ramp mixed 40% over the tone's own skin ramp
const NAILBASE = ramp(['#f4dfcd', '#d2a999', '#986e6c', '#54394b', '#1a1422']);
const nailFor = sk => NAILBASE.map((c, i) => c.map((v, j) => Math.round(sk[i][j] + (v - sk[i][j]) * 0.4)));

// ---- shared ramps (fixed order; new ones go at the end of this list only if TONES is moved after them)
const SHARED = [
  ['CLOTH',   ramp(['#9495aa', '#5c5d75', '#30314a', '#12111e'])],                  // the approved shorts
  ['HAIR_BLOND',  ramp(['#e3c88c', '#b8955c', '#7e6040', '#45332e', '#17111a'])],
  ['HAIR_GINGER', ramp(['#d47a48', '#a4502e', '#6c3024', '#3a1a20', '#140b12'])],
  ['HAIR_BROWN',  ramp(['#8c6649', '#634634', '#422e28', '#241921', '#0d0910'])],
  ['HAIR_DARK',   ramp(['#4c3e3a', '#33282a', '#231b20', '#140f16', '#08060b'])],
  ['HAIR_GREY',   ramp(['#dcd8d0', '#aaa59e', '#76716e', '#423e42', '#161419'])],
  ['VITILIGO',    ramp(['#f6e2d6', '#d6b2a4', '#9a7074', '#4e3646', '#18121f'])],   // skin that has lost its color: milky pink-white
];
// ---- skin tones, by group. Each lists skin, flush, old-skin, freckle and age-spot stops, and palm stops for palms
// and soles (left out = the same as the skin). Nails are made from the skin.
// On the European tones freckles are orange-tan and age spots tan liver spots; on the others both are a shade
// darker than the skin.
const EURO_FRECKLE = ['#c98a5a', '#9a5e3e', '#653a30', '#3a2229', '#16101a'];
const EURO_SPOT = ['#b4855e', '#8a6046', '#5a3c35', '#32222a', '#140e18'];
// Group "european": 0 Porcelain, 1 Cream (the approved MaleBody_Muscular skin), 2 Fawn.
// Group "african": 3 Umber, 4 Mahogany, 5 Ebony. Palms and soles are lighter and pinker than the rest of the skin.
// Group "latin" (Latin American): 6 Golden, 7 Copper (red-brown), 8 Bronze. Palms lighter on Copper and Bronze.
// Group "asian": 9 Wheat (light corn), 10 Honey, 11 Almond (soft brown). Palms lighter on Almond.
// Group "mideast_southasia" (Middle Eastern & South Asian): 12 Sand, 13 Caramel, 14 Chestnut, with an olive
// undertone. Palms lighter on Caramel and Chestnut.
const TONES = [
  { group: 'european', name: 'Porcelain',
    skin:  ['#f3d4c2', '#cf9c8a', '#8e5a5a', '#472d40', '#18121f'],
    flush: ['#f2c0b2', '#d3867e', '#924e58', '#4a2a40', '#18121f'],
    old:   ['#ebd3c6', '#c3a094', '#8a6466', '#47313f', '#18121f'], freckle: EURO_FRECKLE, spot: EURO_SPOT },
  { group: 'european', name: 'Cream',
    skin:  ['#efc9a0', '#c08a68', '#84554c', '#452d3c', '#18121f'],
    flush: ['#efb694', '#c47660', '#874a4a', '#462a3c', '#18121f'],
    old:   ['#e7c8a9', '#b48c72', '#7a5852', '#43303c', '#18121f'], freckle: EURO_FRECKLE, spot: EURO_SPOT },
  { group: 'european', name: 'Fawn',
    skin:  ['#e0b285', '#ab7853', '#72493b', '#3d2836', '#16101c'],
    flush: ['#e0a17a', '#ad684b', '#76423b', '#3e2636', '#16101c'],
    old:   ['#d8b592', '#a17d61', '#6c4e44', '#3b2a34', '#16101c'], freckle: EURO_FRECKLE, spot: EURO_SPOT },
  { group: 'african', name: 'Umber', grey: 0.4,
    skin:    ['#c8946a', '#956044', '#623d31', '#35222b', '#140d16'],
    flush:   ['#c88866', '#955640', '#633732', '#35222b', '#140d16'],
    old:     ['#bb9272', '#8c654c', '#5d4238', '#33242c', '#140d16'],
    freckle: ['#90603f', '#674330', '#452c27', '#261821', '#0e0910'],
    spot:    ['#784a31', '#563625', '#3a2422', '#21151d', '#0d080f'],
    palm:    ['#dcb092', '#b48268', '#7c5249', '#40283a', '#160e18'] },
  { group: 'african', name: 'Mahogany', grey: 0.3,
    skin:    ['#8a5a3e', '#62402e', '#402826', '#23161d', '#0c080e'],
    flush:   ['#8c553d', '#633b2d', '#412626', '#23161d', '#0c080e'],
    old:     ['#81604c', '#5c4337', '#3e2d2c', '#23191f', '#0c080e'],
    freckle: ['#603c2b', '#442a21', '#2d1b1c', '#190f16', '#09060b'],
    spot:    ['#4e2f1e', '#382318', '#261716', '#150d13', '#08050a'],
    palm:    ['#c49478', '#966850', '#66423e', '#362134', '#140c16'] },
  { group: 'african', name: 'Ebony', grey: 0.25,
    skin:    ['#664434', '#472d26', '#2e1d1f', '#191016', '#08060a'],
    flush:   ['#684031', '#482b25', '#2f1c1e', '#191016', '#08060a'],
    old:     ['#614a3e', '#453430', '#2d2226', '#191318', '#08060a'],
    freckle: ['#452b22', '#311d1a', '#201317', '#120a10', '#060408'],
    spot:    ['#3a2318', '#291813', '#1b1012', '#10090d', '#050307'],
    palm:    ['#ae7e62', '#835641', '#583935', '#2e1e2c', '#110a13'] },
  { group: 'latin', name: 'Golden', grey: 0.7,
    skin:    ['#dcaa74', '#a87448', '#704436', '#3c2632', '#150f1b'],
    flush:   ['#dea070', '#ab6844', '#724034', '#3d2632', '#150f1b'],
    old:     ['#d4ad84', '#a07a58', '#6a4a3e', '#3a2a32', '#150f1b'],
    freckle: ['#a86e44', '#7c4c30', '#52322a', '#2e1c24', '#120b14'],
    spot:    ['#9a6644', '#704830', '#4a3028', '#291b22', '#100a12'] },
  { group: 'latin', name: 'Copper', grey: 0.5,
    skin:    ['#c8865a', '#9a5838', '#663630', '#36202a', '#140c16'],
    flush:   ['#cc7a54', '#9c4e34', '#68302c', '#36202a', '#140c16'],
    old:     ['#bc8a66', '#8c5e44', '#5e3e36', '#33222a', '#140c16'],
    freckle: ['#94573a', '#6a3c2a', '#462724', '#27161f', '#0e080f'],
    spot:    ['#844e32', '#5e3826', '#3e2522', '#22141c', '#0d070e'],
    palm:    ['#d8a080', '#ac7058', '#764a44', '#3e2636', '#160c16'] },
  { group: 'latin', name: 'Bronze', grey: 0.4,
    skin:    ['#a8744c', '#7a4e34', '#50322a', '#2b1b22', '#0f0a10'],
    flush:   ['#ac6a46', '#7c4632', '#522c28', '#2c1a22', '#0f0a10'],
    old:     ['#a07a5c', '#74563f', '#4c3630', '#2a1e23', '#0f0a10'],
    freckle: ['#7a4a30', '#583524', '#3a231f', '#21141a', '#0b070c'],
    spot:    ['#6c3f28', '#4c2d1f', '#33201c', '#1c1117', '#0a060b'],
    palm:    ['#cc9a7a', '#9e6c52', '#6a4440', '#38223a', '#140c16'] },
  { group: 'asian', name: 'Wheat',
    skin:    ['#f0d0a4', '#c69c70', '#86604c', '#45303a', '#17111d'],
    flush:   ['#f0c09a', '#c8886a', '#8a5650', '#46303a', '#17111d'],
    old:     ['#e6cfae', '#b89a7c', '#7e6254', '#43323a', '#17111d'],
    freckle: ['#c8986a', '#9a6c48', '#644434', '#38242a', '#150e18'],
    spot:    ['#b88a62', '#8c6448', '#5c4036', '#33242a', '#140e18'] },
  { group: 'asian', name: 'Honey', grey: 0.85,
    skin:    ['#e2b680', '#b2834e', '#76503a', '#3e2a32', '#150f1b'],
    flush:   ['#e2a87a', '#b4744c', '#7a4838', '#3f2832', '#150f1b'],
    old:     ['#d8b48c', '#a8845e', '#704e40', '#3c2c32', '#150f1b'],
    freckle: ['#ac7a4c', '#805634', '#56382c', '#302024', '#120b14'],
    spot:    ['#9c6c46', '#744e32', '#4c342a', '#2a1c22', '#100a12'] },
  { group: 'asian', name: 'Almond', grey: 0.6,
    skin:    ['#bc9a74', '#8e6c48', '#5e4434', '#33242a', '#130d17'],
    flush:   ['#c08e6a', '#926446', '#624032', '#35232a', '#130d17'],
    old:     ['#b49c80', '#887056', '#5a483c', '#32272c', '#130d17'],
    freckle: ['#8c6a46', '#664c32', '#46322a', '#281b20', '#0f0910'],
    spot:    ['#7c5c3c', '#5a432e', '#3c2c26', '#22181d', '#0d080e'],
    palm:    ['#d4b696', '#a88668', '#74584c', '#3e2c38', '#160e18'] },
  { group: 'mideast_southasia', name: 'Sand', grey: 0.8,
    skin:    ['#dcb88e', '#a98a60', '#6e5840', '#3a2e32', '#141018'],
    flush:   ['#deae86', '#ac7c5a', '#70503e', '#3b2c32', '#141018'],
    old:     ['#d4b896', '#a48a6a', '#6c5848', '#3a3034', '#141018'],
    freckle: ['#a88458', '#7c603e', '#52402e', '#2e2428', '#110d14'],
    spot:    ['#9a7650', '#70563a', '#4a3a2e', '#2a2026', '#100c12'] },
  { group: 'mideast_southasia', name: 'Caramel', grey: 0.6,
    skin:    ['#c8965e', '#966a3c', '#624430', '#34242a', '#130d16'],
    flush:   ['#cc8c5a', '#986038', '#643e2e', '#35232a', '#130d16'],
    old:     ['#bc9a74', '#8c704e', '#5c4838', '#33282c', '#130d16'],
    freckle: ['#946436', '#6c4828', '#482f24', '#28191e', '#0f0910'],
    spot:    ['#845830', '#603f24', '#402a22', '#23161c', '#0d080e'],
    palm:    ['#d8b08a', '#ac8462', '#76564a', '#3e2c38', '#160e18'] },
  { group: 'mideast_southasia', name: 'Chestnut', grey: 0.4,
    skin:    ['#94704c', '#6a5034', '#46342a', '#261c20', '#0e0a10'],
    flush:   ['#986848', '#6c4a32', '#48302a', '#271a20', '#0e0a10'],
    old:     ['#8c705a', '#665240', '#443632', '#261e22', '#0e0a10'],
    freckle: ['#6c5036', '#4e3a28', '#342620', '#1d1519', '#0a070c'],
    spot:    ['#5e4430', '#443222', '#2e211d', '#1a1217', '#09060b'],
    palm:    ['#c8a07c', '#9c7456', '#6a4c42', '#382634', '#140c16'] },
];

module.exports = { hex, ramp, NAILBASE, nailFor, SHARED, TONES, EURO_FRECKLE, EURO_SPOT };
