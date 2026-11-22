#!/usr/bin/env python3
"""Makes furniture_ramps.gdshaderinc: the 8-shade ramps of what furniture is covered in and made of, beyond the
house's own wood and paint (house_ramps.gdshaderinc).

The same recipe as the ground's ramps (assets/ground/source/gen_ramps.py): a few colour stops, lightest first,
highlights a little warmer and shadows cooler. Natural colours: household cloth is muted, linen is off-white,
cast iron is nearly black.

Their numbers start at 16, after the house's eight, so a house `Surf` can be on one of the house's ramps or one
of these: furniture.gdshader's furn_color() tells them apart.

Run:  python3 gen_furniture_ramps.py > ../furniture_ramps.gdshaderinc
Another fabric is one more line here (keep the three fabrics first) and its number as a piece's `fabric`.
"""
RAMPS = [
    ("RUST",    ["#e0a48c", "#bc6c58", "#8c4440", "#5a2c32", "#301a24"], "upholstery and blankets: brick red"),
    ("MOSS",    ["#cdd2a0", "#9da66c", "#6c7848", "#444e36", "#242a26"], "upholstery and blankets: olive"),
    ("DENIM",   ["#c4d2e4", "#8fa4c4", "#5f769c", "#3c4c70", "#202842"], "upholstery and blankets: blue"),
    ("LINEN",   ["#fbf7ea", "#e6dfcc", "#bcb4a2", "#807a74", "#444148"], "sheets, pillows, mattress ticking"),
    ("IRON",    ["#8a8684", "#625f62", "#434148", "#2a2931", "#16161d"], "cast iron: a stove"),
    ("ENAMEL",  ["#fbfbf6", "#e4e6e2", "#b8bcbc", "#7c8088", "#42444e"], "white enamel: a fridge"),
    ("EMBER",   ["#fff0b8", "#ffc85e", "#f08a32", "#b04a24", "#5c2620"], "fire behind a stove's door"),
    ("BRASS",   ["#f6e2a0", "#d8b660", "#a6843e", "#6c5430", "#3a2e26"], "knobs and handles"),
    ("BRICK",   ["#e0a088", "#b8664e", "#8c4636", "#5c2e2a", "#2e1a1c"], "a fireplace's brick"),
    ("LACQUER", ["#8a7466", "#54423c", "#33282a", "#1e1820", "#0e0c14"], "a piano's black lacquer"),
    ("SCREEN",  ["#eef6ff", "#a6c4e2", "#5a7896", "#2a3a4c", "#0e141c"], "a television's glass, dark or lit"),
    ("BEIGE",   ["#f2e8d0", "#d4c6a2", "#a69676", "#6a604e", "#34302c"], "old beige plastic: a phone, a lamp base"),
]
FIRST = 16


def rgb(h):
    return [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]


def ramp(stops, n=8):
    cols = [rgb(s) for s in stops]
    out = []
    for i in range(n):
        t = i / (n - 1) * (len(cols) - 1)
        a = min(int(t), len(cols) - 2)
        f = t - a
        out.append([cols[a][k] + (cols[a + 1][k] - cols[a][k]) * f for k in range(3)])
    return out


print("// Made by source/gen_furniture_ramps.py. Don't edit: change the stops there and run it again.")
print("// What furniture is covered in and made of: 8-shade ramps, lightest (0) to darkest (7), as sRGB. Their")
print("// numbers start at FURN_FIRST, after the house's own ramps.")
print("const int FURN_FIRST = %d;" % FIRST)
for i, (name, stops, what) in enumerate(RAMPS):
    print("const int F_%s = %d;%s// %s" % (name, FIRST + i, " " * (7 - len(name)), what))
print("const vec3 FURN_RAMPS[%d] = vec3[%d](" % (len(RAMPS) * 8, len(RAMPS) * 8))
rows = []
for name, stops, what in RAMPS:
    rows.append("\t" + ", ".join("vec3(%.3f, %.3f, %.3f)" % tuple(c) for c in ramp(stops)))
print(",\n".join(rows))
print(");")
