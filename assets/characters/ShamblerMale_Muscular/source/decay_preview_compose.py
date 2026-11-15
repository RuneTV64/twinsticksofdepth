# Builds the zombie decay preview sheets from the renders (see render_decay_all.sh).
import json
from PIL import Image, ImageDraw, ImageFont
BG = (18, 14, 22); BAND = (24, 19, 30); TX = (233, 217, 200); MU = (168, 149, 143); AC = (217, 162, 115)
FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
FS = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
TONES = ['Porcelain', 'Cream', 'Fawn', 'Umber', 'Mahogany', 'Ebony', 'Golden', 'Copper', 'Bronze',
         'Wheat', 'Honey', 'Almond', 'Sand', 'Caramel', 'Chestnut']
GROUPS = ['European', 'African', 'Latin American', 'Asian', 'Middle Eastern & South Asian']
LOOKS = ['freckles', 'clean shaven', 'hairy', 'old', 'vitiligo']
STAGES = [('Fresh', .88), ('Rigor', .68), ('Bloated', .44), ('Putrid', .2), ('Dried', 0)]
stage = lambda f: next(n for n, t in STAGES if f >= t)
K = 3


def crop_rows(ims):
    bg = ims[0].getpixel((0, 0)); top, bot = 10**9, 0
    for im in ims:
        px = im.load(); w, h = im.size
        rows = [y for y in range(h) if any(px[x, y] != bg for x in range(w))]
        if rows:
            top = min(top, rows[0]); bot = max(bot, rows[-1])
    return max(0, top - 2), bot + 3


def label(d, cx, y, a, b):
    for t, f, c, dy in [(a, FB, TX, 4), (b, FS, MU, 26)]:
        tw = d.textlength(t, font=f); d.text((cx - tw / 2, y + dy), t, font=f, fill=c)


def sheet(out, title, rows):
    """rows: list of (row title or None, [(image, cam_size, gap, [(a, b) per body]) side by side])"""
    built = []
    for rt, panels in rows:
        ims = [p[0] for p in panels]; t, b = crop_rows(ims)
        ims = [im.crop((0, t, im.width, b)).resize((im.width * K, (b - t) * K), Image.NEAREST) for im in ims]
        built.append((rt, ims, panels))
    W = max(sum(i.width for i in ims) + 8 * (len(ims) - 1) for _, ims, _ in built)
    H = 40 + sum((30 if rt else 0) + ims[0].height + 46 for rt, ims, _ in built) + 8
    s = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(s); d.text((8, 10), title, font=FB, fill=TX)
    y = 40
    for rt, ims, panels in built:
        if rt:
            d.text((8, y + 4), rt, font=FB, fill=AC); y += 30
        x = 0; hh = ims[0].height
        d.rectangle((0, y + hh, W, y + hh + 46), fill=BAND)
        for im, (src, cam, gap, labels) in zip(ims, panels):
            s.paste(im, (x, y)); ppm = src.height / cam * K; n = len(labels)
            for j, (a, b) in enumerate(labels):
                label(d, x + im.width / 2 + (j - (n - 1) / 2) * gap * ppm, y + hh, a, b)
            x += im.width + 8
        y += hh + 46
    s.save(out); print(out, s.size)


L = lambda n: Image.open(n).convert('RGB')
FR = [0.95, 0.78, 0.56, 0.32, 0.08]

# one person, alive to dried
people = [('porc', 0, 0, 1), ('maho', 4, 4, 3), ('honey', 10, 2, 3)]
HN = ['blond', 'ginger', 'brown', 'dark', 'grey']
rows = []
for k, t, v, h in people:
    who = f'{TONES[t]}, {LOOKS[v]}, {HN[h]} hair'
    rows.append((who, [(L(f'turn_{k}_alive_0.png'), 2.05, 0.62, [('Alive', 'living skin')]),
                       (L(f'turn_{k}_dead_0.png'), 2.05, 0.62, [(stage(f), f'{f:.2f}') for f in FR])]))
sheet('out/decay_turn.png', 'One person, alive and then turned: tone, freckles, vitiligo and hair carry over', rows)

# the five stages, front and back
st = [(stage(f), f'{f:.2f}') for f in FR]
sheet('out/stages.png', 'Decay stages, front and back (Cream, clean shaven)',
      [(None, [(L('zd_stages_0.png'), 2.05, 0.62, st)]), (None, [(L('zd_stages_1.png'), 2.05, 0.62, st)])])

# a wound as it ages
sheet('out/wounds.png', 'Torso_Destroyed as it ages', [(None, [(L('zd_wounds_0.png'), 0.75, 1.0, st)])])

# every tone, fresh and in rigor
rows = []
for g, ids in enumerate([(0, 1, 2), (3, 4, 5), (6, 7, 8), (9, 10, 11), (12, 13, 14)]):
    lab = [(TONES[t], 'Fresh') for t in ids] + [(TONES[t], 'Rigor') for t in ids]
    rows.append((GROUPS[g], [(L(f'zd_tones{g}_0.png'), 2.05, 0.62, lab), (L(f'zd_tonesb{g}_0.png'), 2.05, 0.62, lab)]))
sheet('out/decay_tones.png', 'Every skin tone, freshly turned and in rigor, front and back', rows)

# random spawns
cp = json.load(open('crowd_params.json'))
cl = [(stage(p['freshness']), f"{TONES[p['skin_tone']]}, {LOOKS[p['variant']]}") for p in cp]
sheet('out/crowd.png', 'Random spawns', [(None, [(L('zd_crowd_0.png'), 2.05, 0.62, cl)]), (None, [(L('zd_crowd_1.png'), 2.05, 0.62, cl)])])

# grime levels, on a light and a deep tone
gl = [('Grime', f'{g:.2f}') for g in (0.0, 0.35, 0.7, 1.0)]
sheet('out/decay_grime.png', 'Grime: mud, dust, grass and earth stains, smears (rigor, from clean to caked)',
      [('Cream', [(L('zd_grime_light_0.png'), 2.05, 0.62, gl), (L('zd_grime_light_1.png'), 2.05, 0.62, gl)]),
       ('Ebony', [(L('zd_grime_deep_0.png'), 2.05, 0.62, gl), (L('zd_grime_deep_1.png'), 2.05, 0.62, gl)])])
