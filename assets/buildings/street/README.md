# Street

Streets in the 8-shade 3D-Pixel look, made the way the house and the fences are: one style, a few shapes, and
one shader that changes them with the weather, the seasons and how worn they are. **Status: in review** (made
21 Nov 2026; never seen on Forward+, only on the cloud's software renderer).

## What it is

- A street is laid as flat 9 m tiles on a grid: a 6 m carriageway with a kerb and a 1.5 m sidewalk each side.
  A tile is three of the house kit's cells wide, so houses, fences and streets line up.
- You say which grid cells are street. Each tile works out which neighbours it joins, and so its shape: a
  **straight**, a **bend**, a **T junction**, a **crossroads**, or a **dead end** with a rounded head. Corners
  are rounded off, and tiles meet without a seam.
- `street.gdshader` draws every tile: asphalt with its stone showing, darker where the wheels ran; a dashed
  yellow centre line; a white crossing and stop line on every arm of a junction; a manhole on some straights
  and a drain grate in the gutter; a concrete kerb; sidewalk slabs 1.5 m square.

## What a street does

Every object has to do something to the player (the owner's rule):

- **It is firm in all weather.** No mud, so nothing slows you, and no footprints, so nothing can follow your
  trail along it. The exception is lying snow, where a street shows your tracks like anywhere else.
- **It is open.** There is no cover on a street and nothing to hide in.
- **It is pavement.** With a sledgehammer it breaks up a square metre at a time, gives rock, and leaves a
  ragged hole down to the stone bed. A worn street breaks up sooner.
- **Water stands on it** when it rains: in the gutters and the potholes.

Measured in the game's test level (`tools/street_test.gd`, cloud run, 21 Nov 2026):

| | On the street | On bare ground beside it |
|---|---|---|
| Dry summer, 10 m walked | no prints | no prints |
| Rain, 10 m walked | no prints | 8 prints |
| Lying snow, 10 m walked | 14 prints | 14 prints |

A square metre takes 10 sledgehammer blows laid sound, 6 cracked, 3 breaking up, and leaves 3 rocks. Fists get
nowhere.

## Lamps and signs

What stands along a street (`street_kit.gd`: `lamp()`, `signpost()`, `name_sign()`, and `furnish()`, which puts
them where a street would have them: a lamp on each straight on alternate sides, a stop sign facing what comes
in on every arm of a junction, a name sign at its corner, a warning where a dead end begins).

**A street lamp** is a 3.5 m steel post with a glass lantern on top.

- Lit, at night it lights the ground for 8 m round it. Whoever stands in that light is seen from as far as by
  day, and so is whatever they are looking at.
- The lantern is glass, above your head. Put the crosshair on it and shoot it out, or throw a rock at it, and
  that stretch of street goes dark. Its glass falls to the ground under it.
- Bring the post down and the lantern comes with it.
- Power is a stand-in: a street's lamps are lit unless you say otherwise (`lit`), and one put up worn out is
  dark.

**A sign** is a steel plate on a thin post: a stop sign, a street name (two blades at a corner), or a warning
diamond.

- It tells you where you are: walk up to it and the prompt reads it out.
- It is no cover.
- It rings when it is hit: a noise you can make on purpose without firing a shot.

Measured in the test level (`tools/lamp_test.gd`, cloud run, 21 Nov 2026):

| | |
|---|---|
| At night, under a lit lamp | light 1.00; you are seen from the full daytime distance |
| At night, in the dark of the crossroads | light 0.08; seen from 0.36 of it |
| A lamp's light along the ground | full to 2 m, 0.86 at 4 m, 0.33 at 6 m, gone by 8 m |
| One shot at the lantern from 7.5 m | lantern gone, light out, 1 broken glass under it, post standing |
| A rock thrown at one from 6.5 m | lantern gone, light out |
| A lamp post | 3 sledgehammer blows, 18 with the hatchet, about 330 from a zombie; its lantern goes with it |
| A sign's post | 2 sledgehammer blows, 9 with the hatchet, about 165 from a zombie |
| A sign punched once | zombies 5 m and 9 m off turned to it; one 14 m off did not hear |

`street_prop.gdshader` draws all of it on plain boxes: the post, the lantern's frame, cap and glass (glowing
when lit), and each sign's face, cutting away a stop sign's corners and a warning sign's diamond. Wet darkens
it, frost and snow sit on every cap; wear rusts the posts, fades the paint, shoots holes in the signs and
breaks the lantern's glass.

## How it changes

Three things change the look with no change of mesh, as with the house:

- **The season and the weather** (`ground_season`): wet asphalt goes nearly black and water stands in the
  gutters and potholes (ice in a frost, rain rings in rain); a dry summer bleaches it; autumn's leaves gather
  along the kerbs; hoar frost; lying snow, with footprints in it.
- **How worn it is** (`wear` 0, 1, 2): cracks, old cracks sealed with tar, paint fading; then crazing all
  over, potholes through to the bed, and weeds in every crack and joint (green in the growing seasons, dead
  straw after).
- **Holes**: a square metre that has been broken up is cut out of the tile, and the ground's stone bed shows
  through. (A tile that has been broken into gets a material of its own; the rest share one per shape.)

It includes the cutaway too, like everything else.

## Laying a street

```gdscript
var s := StreetKit.new(level, Vector3(-14, 0, -94), 1)     # the north-west corner of grid cell (0, 0); wear 0..2
s.plan([" # ",
        "###",
        " # "])                                             # rows north to south, "#" = street
s.open(Vector2i(1, 2), "S")                                 # it carries on south though nothing is laid there
s.build()
```

`add(cells)` and `line(a, b)` mark cells too. `what_at(p)` says what is at a spot: "road", "kerb", "sidewalk"
or nothing. The corner is rounded to whole metres, so a tile's 81 square metres are the ones the breaking code
counts in.

## Files

| File | What it is |
|---|---|
| `street_kit.gd` | `StreetKit`: marks cells, works out the shapes, lays the tiles |
| `street.gdshader` | Draws every shape, in every weather and stage of wear |
| `street_ramps.gdshaderinc` | Asphalt, concrete, road paint and iron: their 8-shade ramps (generated) |
| `source/gen_street_ramps.py` | Makes the ramps from colour stops |
| `preview/street_shapes.png` | The five shapes, and all of them in one plan |
| `preview/street_seasons.png` | A junction through the year |
| `preview/street_wear.png` | The three stages of wear, and square metres broken up |
| `preview/street_town.png` | With kit houses, a fence, lamps and signs |
| `street_prop.gdshader` | Draws lamp posts, lanterns, sign posts and sign plates |
| `street_sign.gd` | `StreetSign`: what a sign says to whoever walks up to it |
| `preview/street_props.png` | A lamp by day and lit, the signs, their wear, in snow |
| `preview/street_furnished.png` | A junction and a town with their lamps and signs, by day and with the daylight down |
| `source/lamp_test.gd` | The headless test of lamps and signs (in the repository: `tools/lamp_test.gd`) |
| `source/street_preview.gd` | The harness that renders the sheets (in the repository: `tools/street_preview.gd`) |
| `source/street_test.gd` | The headless test of what a street does in play (in the repository: `tools/street_test.gd`) |

What the game itself needed for it, outside this folder: a new kind of ground, `bed` (packed stone and grit),
which a street lays under itself (`ground.gd` `paint()`, `dirt_types.gdshaderinc` `dirt_bed()`); a surface
that isn't its whole rectangle (`Breakable.on_shape`); and a weaker surface (`Breakable.thin`). For the lamps:
`Daylight.remove_lamp()`, and the fog shader is now sent the lamps nearest the player when there are more than
it takes (`fog.gd`).

## Not checked, not done

- Forward+ on Godot 4.7: colours, the stepped light, cost.
- It is flat. The kerb is drawn, not raised: nothing steps up or down, and nothing rolls into the gutter.
- Streets run north-south and east-west only, on level ground, one width. No diagonals, curves, lanes, or
  parking.
- The whole tile breaks as pavement: a sidewalk slab is as hard as the carriageway.
- Lamps and signs come with the kit; hydrants, benches, bins, post boxes and parked cars do not.
- A lamp has no power to lose: it is lit or it isn't. It doesn't flicker, and nothing switches a street off.
- A sign's plate is part of its post: it can't be hit or taken off on its own, and a shot passes through it.
- Signs face north, east, south or west only. A name sign shows marks, not letters: the prompt reads it.
- The lit look in the pictures is the lamp's own light with the daylight turned down. The game's darkness is
  a screen effect the harness doesn't have.
- Footsteps are no louder on it than on grass. A pothole doesn't trip or slow anyone.
- Worn all over, not where it was used. Weeds are drawn, not grown: nothing spreads with the years yet.
- Two streets laid side by side join into one wide slab.
