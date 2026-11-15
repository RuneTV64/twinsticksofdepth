"""Stack the rows rendered by zombie_anim_preview.gd into one sheet: zombie_anim_sheet.py out.png row0.png row1.png ..."""
import sys
from PIL import Image

rows = [Image.open(p).convert("RGB") for p in sys.argv[2:]]
w = max(r.width for r in rows)
sheet = Image.new("RGB", (w, sum(r.height for r in rows)), (30, 25, 36))
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.height
sheet.save(sys.argv[1])
