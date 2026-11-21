# House

Parts to build houses with, in the 8-shade 3D-Pixel look: one style (a timber house, painted clapboard outside,
plaster inside, floorboards, a pitched shingle roof), any number of rooms and storeys. **Status: in review**
(made 21 Nov 2026; never seen on Forward+, only on the cloud's software renderer).

## What it is

- Houses are laid out on a grid of 3 m cells. `house_kit.gd` (`HouseKit`) makes the parts and puts them
  together; `HouseKit.house(level, origin, wide, deep, storeys, wear, paint)` builds an ordinary house in one
  call.
- Every part is made through `Solid` (`solid.gd`), so it is made of something and can be broken like the
  rest of the world: outside walls and the roof are wood, inside walls plaster, floors wood, windows glass.
- The look is all in the shaders. They draw on the same world-space texel grid as the ground (16 to the
  metre), from 8-shade ramps (`house_ramps.gdshaderinc`, made by `source/gen_house_ramps.py`), and three
  things change them without a different mesh:
  - **the season and the weather**: the project-wide `ground_season` (`seasons.gd`), the same value the
    ground follows, so a house and its yard change together;
  - **how worn it is**: `wear` 0 sound, 1 damaged, 2 about to give. These are a breakable thing's three
    stages of damage, so a wall being beaten on goes through them; a house can also be built already worn,
    and its parts then start at 60% or 30% of their strength;
  - **the cutaway**: every shader includes it, so a house opens up when it stands between the camera and you.

## The parts

| Part | In `HouseKit` | What it is |
|---|---|---|
| Wall cell, solid | `wall(..., ".")` | 3 m of wall, 2.6 m high |
| Wall cell with a window | `"W"` | a 1.4 m window, sill at 0.9 m, with its pane of glass |
| Wall cell with a door | `"D"` | a 1.1 m doorway with a hinged door |
| Wall cell with an open doorway | `"O"` | the same with no door |
| Inside wall | `wall` with no `outward` | thinner, plaster on both sides |
| No wall | `"_"` | a cell left out of a wall, where two rooms are one (as where the stairs come up) |
| Floor cell | `floor(cells, storey, skip)` | floorboards: the ground floor, or the floor over a room |
| Stairs | `stairs(cell, storey, open)` | two flights and a half landing in one cell, turning back on themselves; open underneath, so one stair can stand over another |
| Basement | `basement(cells)` | a pit cut in the ground, concrete block walls and a slab, one storey down |
| Roof | `roof(cells, storeys)` | a gable roof over any rectangle of cells, with its gable ends |

## The shaders

| File | Draws | Weather | Wear |
|---|---|---|---|
| `house_wall.gdshader` | clapboard outside (three paints: cream, sage, slate), a stone footing, plaster and a skirting board inside | wet streaks, bleaching in a dry summer, algae from the footing in the damp seasons, frost, snow in flecks and drifted at the foot | paint peeling to silvered wood, then boards gone; plaster cracking, then fallen from the lath, with damp and mould |
| `house_roof.gdshader` | shingles in set-off rows | dark when wet, moss from the eaves, leaves in autumn, frost, snow in patches and then cover | shingles missing and lifted, then bare patches |
| `house_floor.gdshader` | floorboards with seams, end joints and knots; or a basement's concrete slab | none indoors until it is worn: then damp stains and blown-in leaves. Water lies on a basement slab when the ground is wet | scuffed pale, seams opening, then boards split and gone; a slab cracks |
| `house_trim.gdshader` | doors and woodwork; stairs, with bare wooden treads, a pale nosing, the shadow of the next riser, darker risers | wet, frost and snow on what is outdoors | paint peeling, then splits; treads split through |

A basement wall is `house_wall.gdshader` with `masonry`: courses of concrete block, a tide mark of damp up
from the floor (higher in the wet), salts above it, cracks and then spalled blocks as it wears.

`house_lib.gdshaderinc` is what they share (the texel grid, the ramps, the weather, the cutaway);
`house_light.gdshaderinc` is how they take the light (three steps, like the ground).

## Files

- `house_kit.gd`: the parts and the builder.
- `house_wall.gdshader`, `house_roof.gdshader`, `house_floor.gdshader`, `house_trim.gdshader`: the shaders.
- `house_lib.gdshaderinc`, `house_light.gdshaderinc`, `house_ramps.gdshaderinc`: what they share.
- `source/gen_house_ramps.py`: makes the ramps. Another paint colour is one more line in it.
- `preview/house_seasons.png`: one house in spring, a dry summer, summer rain, autumn, frost and snow.
- `preview/house_wear.png`: the three stages of wear, outside and (with the roof off) inside.
- `preview/house_parts.png`: every part on its own, at each stage of wear.
- `preview/house_stairs.png`: the stairs from both sides, and over a basement.
- `preview/house_basement.png`: a basement open to the sky, in rain, at each stage of wear.
- `preview/house_paints.png`: the three paints.
- The sheets are made by `tools/house_preview.gd` (in the game's repo).

It needs the ground's shader library (`assets/ground/ground_lib.gdshaderinc`, its ramps) and the game's
`cutaway.gdshaderinc`, `solid.gd`, `breakable.gd`, `door.gd` and `ground_pit.gd` (which cuts the basement's
hole in the ground).

## Floors you can walk

Stairs are real: each flight is a ramp (35 degrees) and the landing a platform. A floor with air under it
(upstairs, or over a basement) is solid to stand on. So upper storeys and basements can be walked into. The
ground's shader takes part in the cutaway, so it opens up over someone in a basement.

## Not done

- The rest of the game is only partly ready for more than one floor: cover, zombies' and raiders' sense of
  where you are, light and tracks still work on the flat map. See the game's notes.
- Stairs have no handrail or balusters, and a stairwell has no rail round it upstairs.
- A basement has no inside walls, windows, hatch or outside door yet.
- Window glass and the dirt under a broken floor are the test level's plain stand-ins, not in this look.
- No window frames, sashes, shutters, gutters, chimney, porch or eaves boards; corners have no corner boards.
- A worn part is drawn worn all over; it doesn't show where it was hit.
- Nothing falls when what held it up is broken.
- Unchecked on Forward+: the colours, the stepped light and the cost.
