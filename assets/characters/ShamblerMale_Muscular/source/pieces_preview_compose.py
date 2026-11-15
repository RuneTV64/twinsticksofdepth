# Builds the cut-off piece sheets from the renders of piecetest.gd (MODE=sheet and MODE=live).
from PIL import Image, ImageDraw, ImageFont
BG = (18, 14, 22); BAND = (24, 19, 30); TX = (233, 217, 200); MU = (168, 149, 143); AC = (217, 162, 115)
FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
FS = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
K = 2
NAMES = [('ArmL', 'Intact'), ('ArmL', 'Rotted'), ('ArmR', 'Intact'), ('ArmR', 'Rotted'), ('LegL', 'Intact'), ('LegL', 'Rotted'),
         ('LegR', 'Intact'), ('LegR', 'Rotted'), ('Head', 'Intact'), ('Head', 'Rotted'), ('Head', 'Destroyed')]
def text(d, cx, y, t, f, c):
    w = d.textlength(t, font=f); d.text((cx - w / 2, y), t, font=f, fill=c)
# every piece, front and cut face
rows = [('From the front', 'out/pc_front.png'), ('The cut face', 'out/pc_cut.png')]
ims = [Image.open(p).convert('RGB') for _, p in rows]; W, H = ims[0].width * K, ims[0].height * K
s = Image.new('RGB', (W, 40 + 2 * (30 + H) + 52), BG); d = ImageDraw.Draw(s)
d.text((8, 10), 'The cut-off pieces: each built from the part as it looked, cut on the same line as the stump', font=FB, fill=TX)
y = 40
for (t, _), im in zip(rows, ims):
    d.text((8, y + 4), t, font=FB, fill=AC); y += 30
    s.paste(im.resize((W, H), Image.NEAREST), (0, y)); y += H
d.rectangle((0, y, W, y + 52), fill=BAND)
for i, (sl, st) in enumerate(NAMES):   # pieces sit 0.3 m apart, centred; the camera shows 0.62 m of height
    cx = W / 2 + (i - 5) * 0.3 * (H / 0.62)
    text(d, cx, y + 6, sl, FB, TX); text(d, cx, y + 30, 'from ' + st, FS, MU)
s.save('out/pieces.png'); print('out/pieces.png', s.size)
# in play: before, the moment after, and fallen
cap = [('Before', 'posed: arm raised, leg bent, head tilted'), ('The moment after', 'the pieces start exactly where the parts were'),
       ('Fallen', 'thrown, landed and settled on the floor')]
ims = [Image.open(f'out/pl_{n}.png').convert('RGB') for n in ('0before', '1after', '2fallen')]; w, h = ims[0].width * K, ims[0].height * K
s = Image.new('RGB', (w * 3 + 16, 40 + h + 52), BG); d = ImageDraw.Draw(s)
d.text((8, 10), 'In play: dismember("ArmL"), ("LegR") and ("Head") with pieces_scene set', font=FB, fill=TX)
d.rectangle((0, 40 + h, s.width, 40 + h + 52), fill=BAND)
for i, (im, (a, b)) in enumerate(zip(ims, cap)):
    x = i * (w + 8); s.paste(im.resize((w, h), Image.NEAREST), (x, 40))
    text(d, x + w / 2, 40 + h + 6, a, FB, TX); text(d, x + w / 2, 40 + h + 30, b, FS, MU)
s.save('out/pieces_live.png'); print('out/pieces_live.png', s.size)
