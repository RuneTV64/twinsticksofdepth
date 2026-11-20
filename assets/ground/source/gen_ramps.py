#!/usr/bin/env python3
"""Makes ground_ramps.gdshaderinc: every ground material's 8-shade ramp.

Each ramp is interpolated from a few colour stops, lightest first: highlight -> mid -> shadow -> near-black, with
the highlights a little warmer and the shadows cooler, as the 8-shade 3D-Pixel style asks. Colours are natural
ones for the material (dry earth is pale, wet earth is dark); nothing is darkened to look gritty.

Run:  python3 gen_ramps.py > ../ground_ramps.gdshaderinc
Add a ramp: add a line to RAMPS, run it, and use its R_NAME constant in a shader.
"""
RAMPS = [
    # name,    stops (lightest to darkest),                          what it is
    ("LOAM",   ["#c49a6c", "#96704a", "#6a4a34", "#432e28", "#231a1e"], "ordinary topsoil"),
    ("FARM",   ["#a67c54", "#7a5438", "#523628", "#352320", "#1c1418"], "tilled farm soil: darker, richer"),
    ("ROAD",   ["#e0c79a", "#bd9c6e", "#8e6f50", "#5c4638", "#33282a"], "packed dirt road: pale and dusty"),
    ("CLAY",   ["#e2b48c", "#c08a5e", "#935f44", "#5e3a34", "#33212a"], "clay: reddish, pale when dry"),
    ("MUD",    ["#9c8262", "#6e563e", "#47362a", "#2a2020", "#15101a"], "wet mud: dark"),
    ("STONE",  ["#d6d0be", "#a9a491", "#77756c", "#494950", "#26262e"], "pebbles and gravel"),
    ("WATER",  ["#dcebf2", "#a4c2d6", "#6c8fb0", "#44608a", "#222e4a"], "standing water, showing the sky"),
    ("ICE",    ["#f6fafc", "#d2e2ec", "#9cb6cc", "#6880a2", "#3c4a6c"], "ice and hoar frost"),
    ("SNOW",   ["#ffffff", "#eaf1f6", "#c2d2e2", "#8ea2c0", "#5a6a90"], "snow"),
    ("LEAF",   ["#e8b04a", "#c97a2c", "#964a22", "#5e2c1e", "#32191c"], "fallen leaves: ochre to rust"),
    ("GREEN",  ["#c4dc74", "#8eb244", "#56802e", "#30542a", "#182e22"], "sprouts, weeds, living grass"),
    ("STRAW",  ["#f0dc98", "#cdae64", "#96783e", "#5c4a2c", "#2e2622"], "stubble, dry grass, straw"),
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


print("// Made by source/gen_ramps.py. Don't edit: change the stops there and run it again.")
print("// Every ground material's 8-shade ramp, lightest (0) to darkest (7), as sRGB.")
for i, (name, stops, what) in enumerate(RAMPS):
    print("const int R_%s = %d;%s// %s" % (name, i, " " * (8 - len(name)), what))
print("const int RAMP_COUNT = %d;" % len(RAMPS))
print("const vec3 GROUND_RAMPS[%d] = vec3[%d](" % (len(RAMPS) * 8, len(RAMPS) * 8))
rows = []
for name, stops, what in RAMPS:
    rows.append("\t" + ", ".join("vec3(%.3f, %.3f, %.3f)" % tuple(c) for c in ramp(stops)))
print(",\n".join(rows))
print(");")
