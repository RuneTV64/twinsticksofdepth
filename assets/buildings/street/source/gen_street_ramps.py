#!/usr/bin/env python3
"""Makes street_ramps.gdshaderinc: the 8-shade ramp of every material a street is made of.

The same recipe as the ground's ramps (assets/ground/source/gen_ramps.py): a few colour stops, lightest first,
highlights a little warmer and shadows cooler. Natural colours: old asphalt is a pale grey, new or wet asphalt
is nearly black, road paint is chalky.

Their numbers start at 100, so one `Ground` spot can be on a street ramp or on one of the ground's own (water,
snow, leaves, weeds): street.gdshader's street_color() tells them apart.

Run:  python3 gen_street_ramps.py > ../street_ramps.gdshaderinc
"""
RAMPS = [
    ("ASPHALT",  ["#a39f9a", "#7a7774", "#545250", "#363537", "#1d1d23"], "asphalt: pale when old and dry, near black new or wet"),
    ("CONCRETE", ["#e4dfd2", "#bdb8ab", "#8f8c86", "#5f5d62", "#34333d"], "kerbs and sidewalk slabs"),
    ("YELLOW",   ["#f4d868", "#d6ac3e", "#a57c2e", "#6b4e2a", "#3a2b24"], "road paint: the centre line"),
    ("WHITE",    ["#f6f4ec", "#d6d2c6", "#a6a39c", "#6e6c6e", "#3c3b43"], "road paint: stop lines and crossings"),
    ("IRON",     ["#93877c", "#6e635c", "#4c4547", "#302c33", "#1a1920"], "manhole covers and drain grates: cast iron, rusting"),
]
FIRST = 100


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


print("// Made by source/gen_street_ramps.py. Don't edit: change the stops there and run it again.")
print("// Every street material's 8-shade ramp, lightest (0) to darkest (7), as sRGB. Their numbers start at")
print("// STREET_FIRST so they can share a `Ground` spot with the ground's own ramps.")
print("const int STREET_FIRST = %d;" % FIRST)
for i, (name, stops, what) in enumerate(RAMPS):
    print("const int S_%s = %d;%s// %s" % (name, FIRST + i, " " * (9 - len(name)), what))
print("const vec3 STREET_RAMPS[%d] = vec3[%d](" % (len(RAMPS) * 8, len(RAMPS) * 8))
rows = []
for name, stops, what in RAMPS:
    rows.append("\t" + ", ".join("vec3(%.3f, %.3f, %.3f)" % tuple(c) for c in ramp(stops)))
print(",\n".join(rows))
print(");")
