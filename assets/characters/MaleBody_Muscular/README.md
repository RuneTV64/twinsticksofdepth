# MaleBody_Muscular export

Close-up master and two lighter versions of the same body, each with the full skeleton. No animations are included.

## Files

| File | Triangles | Use |
| --- | --- | --- |
| `MaleBody_Muscular.glb` | 48,488 | Close-up master |
| `MaleBody_Muscular_mid.glb` | 15,220 | Medium distance |
| `MaleBody_Muscular_low.glb` | 5,032 | Far away or crowds |
| `male_body_muscular_skin.gdshader` | | Skin shader with the drawn details (not yet run in Godot) |
| `MaleBody_Muscular_source.zip` | | The recipe that builds the body, the rig and these files |

All three versions share the same 72 bones with the same names, so one animation works on all of them.

## Model

- Units are metres, Y is up, he faces +Z, feet at the origin, 1.80 tall.
- Each file is one mesh with one material and standard 4-bone skin weights.
- Rest pose is arms down at the sides.

## Skeleton (72 bones)

- Hips, Chest, Neck, Head
- ClavicleL/R, UpperArmL/R, UpperArmRollL/R, ForearmL/R, ForearmRollL/R, HandL/R
- ThighL/R, CalfL/R, FootL/R
- Fingers: IndexL1-3, MiddleL1-3, RingL1-3, PinkyL1-3, ThumbL1-3 (and R)
- Toes: Toe1L1-2 to Toe5L1-2 (and R)

The two Roll bones on each arm only twist along the arm. Put the palm-turning part of a forearm rotation on ForearmRoll and the turn of the upper arm on UpperArmRoll, and the skin twists smoothly.

## Drawn details

Nails, hand tendons, veins, palm creases, foot tendons, the armpit shadow, nipples and the shorts are drawn by the shader. The mesh carries the data they need:

- `UV` and `UV2`: fine coordinates for the detail on that part
- `COLOR`: red is a shadow amount, green is a coarse depth, alpha is a part code
- `CUSTOM0`: each vertex's rest position (x, y, z) and the y of its rest normal (w). In the GLB these are
  `TEXCOORD_2` (rest x, y) and `TEXCOORD_3` (rest z, rest normal y); Godot imports the pair as `CUSTOM0` on its own.

## Rest position (added 15 Nov 2026)

Shaders that paint by place on the body (freckles, vitiligo, body hair, rot, grime) used to read the vertex
position. In Godot that position is already moved by the skeleton, so the patterns stayed fixed in space and slid
over a limb as it moved. The three GLBs were re-exported with the rest position stored on every vertex, and the
living and zombie shaders paint from that.

Nothing else changed: positions, normals, UVs, colors, skin weights, triangles, bones and bind poses were compared
with the approved files and are identical, value for value. If you already imported the body, replace the three
`.glb` files with these (same names) and let Godot reimport. Animations made for the body keep working, because
the skeleton and bone names are the same.

With Godot's default material you get the plain body. Assign `male_body_muscular_skin.gdshader` to the material to get the details.

## What is different from the viewer

- **Shoulders:** Godot's standard skinning thins the shoulder a little when the arm is straight overhead. Up to arms-out level it matches the viewer closely.
- **Armpit rounding:** the viewer rounds the armpit as the arm lifts. That is calculated live and is not in these files. The armpit shadow is.
- **Breathing:** the viewer's idle swells the chest. That was part of the test animation and is not in the files.
