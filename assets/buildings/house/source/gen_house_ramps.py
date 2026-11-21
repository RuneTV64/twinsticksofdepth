#!/usr/bin/env python3
"""Makes house_ramps.gdshaderinc: the 8-shade ramp of every material the house is made of.

The same recipe as the ground's ramps (assets/ground/source/gen_ramps.py): a few colour stops, lightest first,
highlights a little warmer and shadows cooler. Natural colours: fresh paint is pale, bare wood goes silver-grey
in the weather, nothing is darkened to look gritty.

Run:  python3 gen_house_ramps.py > ../house_ramps.gdshaderinc
Another paint colour is one more line here and its H_ constant as a wall material's `paint`.
"""
RAMPS = [
    ("PAINT",    ["#f4eedc", "#d8cdb2", "#a89c88", "#6c6460", "#3a363c"], "painted clapboard: cream"),
    ("SAGE",     ["#cfdcc0", "#a3b698", "#74876f", "#48564c", "#262e30"], "painted clapboard: sage green"),
    ("SLATE",    ["#c8d6e0", "#9aacbc", "#6c7e92", "#445064", "#242a3a"], "painted clapboard: slate blue"),
    ("WOOD",     ["#c9b79c", "#a08e78", "#74675a", "#4a4240", "#262328"], "bare weathered wood: silver-grey"),
    ("PLASTER",  ["#f2ead8", "#d9cdb6", "#b0a28e", "#786c64", "#423c40"], "inside wall plaster"),
    ("SHINGLE",  ["#c2b6ac", "#988c88", "#6e6468", "#48424c", "#26232e"], "roof shingles: weathered grey-brown"),
    ("FLOOR",    ["#d8a86c", "#b27f4a", "#865a34", "#553826", "#2c1e1c"], "floorboards: warm, worn"),
    ("TRIM",     ["#fbf8ee", "#e2dccb", "#b4ad9f", "#787270", "#403c42"], "painted trim, doors, stairs: off-white"),
]


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


print("// Made by source/gen_house_ramps.py. Don't edit: change the stops there and run it again.")
print("// Every house material's 8-shade ramp, lightest (0) to darkest (7), as sRGB.")
for i, (name, stops, what) in enumerate(RAMPS):
    print("const int H_%s = %d;%s// %s" % (name, i, " " * (9 - len(name)), what))
print("const vec3 HOUSE_RAMPS[%d] = vec3[%d](" % (len(RAMPS) * 8, len(RAMPS) * 8))
print(",\n".join("\t" + ", ".join("vec3(%.3f, %.3f, %.3f)" % tuple(c) for c in ramp(stops)) for name, stops, what in RAMPS))
print(");")
