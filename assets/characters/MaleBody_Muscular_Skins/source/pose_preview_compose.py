# Builds the "details stay on the skin" sheets: each tile is the same person at rest and posed (one arm raised, the
# other forearm bent), painted from the posed position (before) and from the stored rest position (after).
import sys
from PIL import Image, ImageDraw, ImageFont
BG = (18, 14, 22); BAND = (24, 19, 30); TX = (233, 217, 200); MU = (168, 149, 143); AC = (217, 162, 115)
FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
FS = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
K = 3
L = lambda n: (lambda im: im.resize((im.width * K, im.height * K), Image.NEAREST))(Image.open(n).convert('RGB'))


def sheet(out, title, rows):
    """rows: [(row title, name)] -> before | after, front view"""
    tiles = [(rt, L(f'rp_{n}_old_0.png'), L(f'rp_{n}_new_0.png')) for rt, n in rows]
    w, h = tiles[0][1].size; W = w * 2 + 8; H = 40 + 26 + len(tiles) * (30 + h + 46) + 8
    s = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(s); d.text((8, 10), title, font=FB, fill=TX)
    for k, t in enumerate(['Before: painted from where the limb is now', 'After: painted from the rest position']):
        tw = d.textlength(t, font=FB); d.text((k * (w + 8) + w / 2 - tw / 2, 40), t, font=FB, fill=AC)
    y = 66
    for rt, a, b in tiles:
        d.text((8, y + 4), rt, font=FB, fill=TX); y += 30
        d.rectangle((0, y + h, W, y + h + 46), fill=BAND)
        for k, im in enumerate((a, b)):
            x = k * (w + 8); s.paste(im, (x, y)); ppm = 150 / 1.25 * K
            for j, (t1, t2) in enumerate([('At rest', ''), ('Posed', 'left arm raised, right forearm bent')]):
                cx = x + w / 2 + (j - 0.5) * 1.25 * ppm
                for txt, f, c, dy in [(t1, FB, TX, 4), (t2, FS, MU, 26)]:
                    tw = d.textlength(txt, font=f); d.text((cx - tw / 2, y + h + dy), txt, font=f, fill=c)
        y += h + 46
    s.save(out); print(out, s.size)


sheet('out/living_pose.png', 'Details stay on the skin when he moves',
      [('Mahogany, vitiligo', 'lv'), ('Fawn, hairy', 'lh')])
sheet('out/decay_pose.png', 'Rot, stains and grime stay on the skin when he moves', [('Cream, bloated, bloody and dirty', 'zd')])
