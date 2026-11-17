"""Turn the frames from zombie_anim_clip.gd into a looping GIF: zombie_anim_gif.py <frame dir> <out.gif> [width] [fps]"""
import glob
import sys
from PIL import Image

frames_dir, out = sys.argv[1], sys.argv[2]
width = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
fps = int(sys.argv[4]) if len(sys.argv) > 4 else 20
frames = []
for p in sorted(glob.glob(frames_dir + "/f*.png")):
    im = Image.open(p).convert("RGB")
    im = im.resize((width, round(im.height * width / im.width)), Image.Resampling.NEAREST)
    frames.append(im.quantize(colors=96, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=round(1000 / fps), loop=0, optimize=True)
print("%s: %d frames" % (out, len(frames)))
