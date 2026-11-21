"""Put the pictures written by zombie_fall_preview.gd (SHEET=impaled CLIP=n) together as one moving picture, the
cases side by side:  impaled_gif.py out.gif "Label=/path/prefix" ...   (pictures are prefix_000.png, prefix_001.png, ...)"""
import glob
import sys
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
cases = [a.split("=", 1) for a in sys.argv[2:]]
sets = [[Image.open(f).convert("RGB") for f in sorted(glob.glob(p + "_[0-9][0-9][0-9].png"))] for _, p in cases]
n = min(len(s) for s in sets)
w, h = sets[0][0].size
bar = 30
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
except Exception:
    font = ImageFont.load_default()
frames = []
for i in range(n):
    fr = Image.new("RGB", (w * len(sets), h + bar), (30, 25, 36))
    d = ImageDraw.Draw(fr)
    for c, s in enumerate(sets):
        fr.paste(s[i], (c * w, bar))
        d.text((c * w + 8, 7), cases[c][0], fill=(232, 217, 199), font=font)
    frames.append(fr.quantize(colors=96, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=66, loop=0, optimize=True)
