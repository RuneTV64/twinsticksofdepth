# Builds the anatomy and part preview sheets from the Godot renders (see render_anatomy_all.sh).
import json
from PIL import Image, ImageDraw, ImageFont
BG = (18, 14, 22); BAND = (24, 19, 30); TX = (233, 217, 200); MU = (168, 149, 143); AC = (217, 162, 115)
FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
FS = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
L = lambda n, k: (lambda im: im.resize((im.width * k, im.height * k), Image.NEAREST))(Image.open(n).convert('RGB'))


def grid(out, title, rows, gap=8, col_heads=None, row_heads=None):
    """rows: list of lists of (image, label, sublabel). Labels sit in a band under each tile."""
    lab = 46 if any(t[1] for r in rows for t in r) else 0
    left = 96 if row_heads else 0; top = 40 + (26 if col_heads else 0)
    W = left + max(sum(t[0].width for t in r) + gap * (len(r) - 1) for r in rows)
    H = top + sum(max(t[0].height for t in r) + lab + gap for r in rows)
    s = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(s); d.text((8, 10), title, font=FB, fill=TX)
    if col_heads:
        x = left
        for t, h in zip(rows[0], col_heads):
            tw = d.textlength(h, font=FB); d.text((x + t[0].width / 2 - tw / 2, 40), h, font=FB, fill=AC); x += t[0].width + gap
    y = top
    for ri, r in enumerate(rows):
        hh = max(t[0].height for t in r); x = left
        if row_heads: d.text((8, y + hh / 2 - 10), row_heads[ri], font=FB, fill=AC)
        if lab: d.rectangle((left, y + hh, W, y + hh + lab), fill=BAND)
        for im, a, b in r:
            s.paste(im, (x, y))
            for t, f, c, dy in [(a, FB, TX, 4), (b, FS, MU, 26)]:
                if t: tw = d.textlength(t, font=f); d.text((x + im.width / 2 - tw / 2, y + hh + dy), t, font=f, fill=c)
            x += im.width + gap
        y += hh + lab + gap
    s.save(out); print(out, s.size)


# the anatomy the painting is made from (review models only: none of this is in the game files)
grid('out/anatomy_inside.png', 'What the painting is made from: the anatomy as models (review only, not in the game files)',
     [[(L('pa_inside_0.png', 2), 'Front', 'skeleton on the muscle wall, and with the organs'), (L('pa_inside_2.png', 2), 'Back', '')]])
# the map the shader paints from (the torso's maps on top, the head's under them)
mp = Image.open('anatomy_map_preview.png').convert('RGB'); mp = mp.resize((mp.width * 2, mp.height * 2), Image.NEAREST); hw = mp.width // 2; th = 512
dm = Image.open('anatomy_map_depth.png').convert('RGB'); dm = dm.resize((dm.width * 2, dm.height * 2), Image.NEAREST)
grid('out/anatomy_map.png', 'The anatomy map: the torso and the head unwrapped (back at the edges, front in the middle), as the shader reads it',
     [[(mp.crop((0, 0, hw, th)), 'Torso, in front: the bones', 'lying on the muscle wall'), (mp.crop((hw, 0, mp.width, th)), 'Torso, behind the wall: the organs', 'seen where the wall is torn through')],
      [(dm.crop((0, 0, hw, th)), 'How far out each bone is', 'lighter = nearer the skin; the red tint is where Torso_Destroyed is torn through'), (dm.crop((hw, 0, dm.width, th)), 'How far in each organ is', 'this is what gives the painting its depth')],
      [(mp.crop((0, th, hw, mp.height)), 'Head: the skull', 'dark where Head_Destroyed is broken away, red at the edge of the break'), (mp.crop((hw, th, mp.width, mp.height)), 'Head: the brain under it', 'its folds, and the gouge under the break')]])
# depth: the same wound from four angles
grid('out/anatomy_depth.png', 'The painting has depth: Torso_Destroyed from four angles. The ribs stay in front and slide across the organs behind them',
     [[(L('cdp_3.png', 3), 'From his right', ''), (L('cdp_1.png', 3), 'Right of centre', ''), (L('cdp_0.png', 3), 'Front', ''), (L('cdp_2.png', 3), 'Left of centre', '')]])
# the painted insides, close up
grid('out/anatomy_painted.png', 'Painted insides, close up (freshly turned)',
     [[(L('cfl_0.png', 3), 'Flank', 'ribs on muscle, the corner of the shoulder blade'), (L('cs_r_0.png', 3), 'Upper back', 'the shoulder blade'), (L('ch_r_1.png', 3), 'Hip', 'the crest of the hip bone')],
      [(L('cf_r_0.png', 3), 'Torso_Rotted, front', 'a chest bite to the cartilage, a belly tear to the muscle'), (L('cf_d_0.png', 3), 'Torso_Destroyed, front', 'sternum, ribs, lungs, liver, stomach, gut'), (L('cs_d_0.png', 3), 'Torso_Destroyed, back', 'spine and shoulder blade')]])
# the opened torsos
v = ['Front', 'From his right', 'From his left', 'Back']
grid('out/anatomy_torso.png', 'The opened torsos, freshly turned: Torso_Rotted (left of each pair) and Torso_Destroyed (right)',
     [[(L(f'pa_torso_{i}.png', 2), v[i], '') for i in (0, 1)], [(L(f'pa_torso_{i}.png', 2), v[i], '') for i in (2, 3)]])
# limbs down to the bone
grid('out/anatomy_limbs.png', 'Limb wounds down to the bone: round bones painted standing out of the gouge',
     [[(L('pa_fore_0.png', 3), 'Arm_Rotted', 'radius and ulna in the forearm'), (L('pa_shin_0.png', 3), 'Leg_Rotted', 'tibia in the shin, fibula beside it'), (L('pa_hum_0.png', 3), 'Arm_Destroyed', 'a gouge down to the humerus')]])
# every slot, three states
slots = ['Head', 'Torso', 'ArmL', 'ArmR', 'LegL', 'LegR']
grid('out/all_slots.png', 'Every slot, three states (freshly turned)',
     [[(L(f'ps_{sl}_{st}_0.png', 2), '', '') for st in ('Intact', 'Rotted', 'Destroyed')] for sl in slots], gap=4,
     col_heads=['Intact', 'Rotted', 'Destroyed'], row_heads=slots)
# the wounded heads
hv = ['Front', 'Back, from his left', 'Back, from his right', 'From his left']
grid('out/anatomy_head.png', 'Head_Rotted (top) and Head_Destroyed (bottom): the skull under the scalp, and the brain a centimetre below where it is broken',
     [[(L(f'hd_Rotted_{k}_0.png', 2), hv[k], '') for k in range(4)], [(L(f'hd_Destroyed_{k}_0.png', 2), hv[k], '') for k in range(4)]])
# decapitated: the stump close up, and the blood down the body
grid('out/decapitated.png', 'Head_Decapitated: the vertebra standing proud, and the open windpipe, gullet and vessels to look down into',
     [[(L('hdc_0_0.png', 2), 'Front', ''), (L('hdc_1_0.png', 2), 'From his right', ''), (L('hdc_2_0.png', 2), 'From behind', ''), (L('hdc_3_0.png', 2), 'From above', '')],
      [(L('hdc_full_0.png', 3), 'Blood down the chest', ''), (L('hdc_full_1.png', 3), 'and down the back', '')]])
# mixed parts
TONES = ['Porcelain', 'Cream', 'Fawn', 'Umber', 'Mahogany', 'Ebony', 'Golden', 'Copper', 'Bronze', 'Wheat', 'Honey', 'Almond', 'Sand', 'Caramel', 'Chestnut']
STAGES = [('Fresh', .88), ('Rigor', .68), ('Bloated', .44), ('Putrid', .2), ('Dried', 0)]
mix = json.load(open('mix.json'))
im0, im1 = L('pm_mix_0.png', 3), L('pm_mix_1.png', 3)
W, H = im0.size; s = Image.new('RGB', (W, 40 + H * 2 + 46 * 2 + 8), BG); d = ImageDraw.Draw(s)
d.text((8, 10), 'Mixed shamblers: five looks put together from the parts', font=FB, fill=TX)
ppm = 150 / 2.05 * 3
for k, im in enumerate((im0, im1)):
    y = 40 + k * (H + 46 + 4); s.paste(im, (0, y)); d.rectangle((0, y + H, W, y + H + 46), fill=BAND)
    for j, (p, t, f) in enumerate(mix):
        cx = W / 2 + (j - 2) * 0.62 * ppm
        for txt, fnt, c, dy in [(next(n for n, th in STAGES if f >= th), FB, TX, 4), (TONES[t], FS, MU, 26)]:
            tw = d.textlength(txt, font=fnt); d.text((cx - tw / 2, y + H + dy), txt, font=fnt, fill=c)
s.save('out/lineup.png'); print('out/lineup.png', s.size)

# blood: run-off from the wounds, and how it ages
bl = [('Wet', 'just turned'), ('Dark', 'rigor'), ('Clotted', 'bloated'), ('Dried', 'putrid: flaking')]
imgs = [L('pb_full_0.png', 3), L('pb_full_1.png', 3), L('pb_close_0.png', 2), L('pb_close_1.png', 2)]
Wd = max(i.width for i in imgs); H = 40 + sum(i.height + 46 + 8 for i in imgs)
s = Image.new('RGB', (Wd, H), BG); d = ImageDraw.Draw(s); d.text((8, 10), 'Blood: it runs from the wounds, soaks the shorts, and ages with him', font=FB, fill=TX)
y = 40
for im, (ppm, gap) in zip(imgs, [(150 / 2.05 * 3, .66), (150 / 2.05 * 3, .66), (140 / .85 * 2, .6), (140 / .85 * 2, .6)]):
    s.paste(im, ((Wd - im.width) // 2, y)); d.rectangle((0, y + im.height, Wd, y + im.height + 46), fill=BAND)
    for j, (a, b) in enumerate(bl):
        cx = Wd / 2 + (j - 1.5) * gap * ppm
        for txt, f, c, dy in [(a, FB, TX, 4), (b, FS, MU, 26)]:
            tw = d.textlength(txt, font=f); d.text((cx - tw / 2, y + im.height + dy), txt, font=f, fill=c)
    y += im.height + 46 + 8
s.save('out/decay_blood.png'); print('out/decay_blood.png', s.size)
