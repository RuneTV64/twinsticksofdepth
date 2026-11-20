# Ground

The ground for levels, in the 8-shade 3D-Pixel look: kinds of dirt (and grass) that follow the season and the
weather. **Status: in review** (made 20 Nov 2026; never seen on Forward+, only on the cloud's software renderer).

## What it is

- The ground is drawn on a grid of world-space texels, 16 to the metre, turned 45 degrees to face the game camera,
  so it is pixel art that stays put on the ground as the camera pans and zooms.
- Every material is one 8-shade ramp (`ground_ramps.gdshaderinc`, made by `source/gen_ramps.py`). A pattern moves a
  spot lighter or darker along its ramp; the step between shades is Bayer-dithered; a little grit nudges odd
  texels a shade. Colours are natural ones: dry earth pale, wet earth dark, nothing darkened to look gritty.
- It is modular. `dirt_modules.gdshaderinc` has the pieces (the earth itself, pebbles, cracks, furrows, ruts,
  wet, puddles, leaves, sprouts, seedlings, stubble, frost, snow); `dirt_types.gdshaderinc` makes each kind of
  dirt from a choice of them. A new kind is one more short function.
- Light falls on it in three steps, dithered on its own texels (`ground_light.gdshaderinc`), so shadows and the
  edge of a lamp's light are pixel art too.

## Kinds of dirt

| # | Kind | What it is |
|---|---|---|
| 0 | soil | ordinary ground: clods, a few stones; sprouts in spring, leaves in autumn |
| 1 | farm | a ploughed field: rows; seedlings in spring, stubble in autumn, snow lying in the troughs |
| 2 | road | a dirt road: two ruts, a crown, loose stones at the edges; the ruts hold the water and the ice |
| 3 | clay | bare clay: cracked when dry or frozen, slick when wet |
| 4 | mud | a wet place: dark and puddled; dries to cracked flats in a drought, freezes hard |

## Kinds of grass

Painted on the ground's map like the dirts; drawn as blades (each texel column cut into strokes, lighter at the
tip, darker at the foot). Green in spring, yellowing in a dry summer and through autumn, dead straw in winter.

| # | Kind | What it is |
|---|---|---|
| 8 | lawn | short grass, close and even: a yard, a verge, grazed ground; daisies in spring |
| 9 | meadow | long grass: flowers in spring and summer, seed heads later, straw by autumn |
| 10 | rough | tussocks and weeds with bare earth between: waste ground, the edge of a field |

Standing grass (`grass_blades.gd`, `grass_blades.gdshader`) is tufts of real blades scattered on top, one draw
call a patch, in four kinds: `short` (0.2 m), `meadow` (0.5 m), `tall` (1 m: the grass you can hide in) and
`tussock` (0.38 m clumps). It keeps the same colours and seasons as the painted grass: short and bright in
spring, full height in summer, going to straw, beaten down and frosted in winter, buried by snow. The blades
sway in sprite steps, and they part round whoever walks or crawls through them (`grass_push`, a project-wide
shader value the player keeps up to date), wider the lower you are.

## Seasons and weather

One project-wide shader value, `ground_season` (declared in `project.godot`, kept by `seasons.gd`):
x = time of year (0 spring, 1 summer, 2 autumn, 3 winter), y = wetness (1 = raining now), z = snow lying,
w = frost. What each does: spring is damp with green coming up; summer is pale and dry, and clay and mud crack;
rain darkens everything, fills the low places and puts rings on the water; autumn brings leaves and stubble;
frost whitens the high points, splits bare ground and fills the cracks with ice ("cold and cracked"), and turns
standing water to ice; snow fills the low places first and leaves a road's ruts dark.
A material can be pinned to its own season with `season_override` (under a roof it never rains).

## Using it

A whole level's ground, every kind on one mesh with ragged borders between them:

```gdscript
add_child(Seasons.new())
var g := Ground.new()
add_child(g)
g.setup(Rect2(-40, -112, 80, 152), "soil")      # the area (x, z, width, depth) and what it is made of
g.road([Vector2(0, 38), Vector2(2, 10), Vector2(0, -36)])
g.rect("farm", Rect2(16, 12, 20, 20), 20.0)     # rows 20 degrees round
g.blob("mud", Vector2(-8, 20), 4.0)
g.rect("meadow", Rect2(-38, -30, 14, 34))
g.apply()
g.grow_grass()                                  # standing grass wherever it is painted meadow or rough
add_child(GrassBlades.in_rect("tall", Rect2(6, 8, 9, 7)))   # or a patch of standing grass where you say
```

One kind on its own (a patch, an earth floor): a `ShaderMaterial` with `dirt.gdshader` and its `kind`.
`Ground.it.kind_at(pos)` says what the ground is made of at a place, for footsteps, mud and tracks later.

## Soft ground: mud that slows, and tracks

- `Ground.softness(pos)` says how soft the ground is as the season has it: mud is soft unless a drought has
  baked it or a frost has frozen it; a ploughed field is a little soft; bare ground is when it is soaked.
- Mud slows whoever walks in it (`slow_at()`): to about 0.6 of walking speed in spring, 0.5 in rain
  (`mud_slow`), not at all when dried out or frozen. The player, zombies and raiders alike.
- Feet leave prints in soft ground and in lying snow (`stamp()`): a print a stride for anyone walking, a
  swathe for anyone crawling. They are kept in a second map (a texel to 0.125 m) and drawn by `ground.gdshader`:
  pressed dark in earth, holding a little water when it is wet, packed blue-grey in snow. Rain washes them out
  and fresh snow covers them (`clear_tracks()`); otherwise they stay. Prints are drawn bigger than a real boot
  so they read from the camera's height.

## Files

| File | What it is |
|---|---|
| `ground_lib.gdshaderinc` | the texel grid, noise, the season, the 8-shade pick |
| `ground_ramps.gdshaderinc` | every material's 8-shade ramp (generated) |
| `ground_light.gdshaderinc` | stepped, dithered light |
| `dirt_modules.gdshaderinc` | the pieces dirt is made of |
| `dirt_types.gdshaderinc` | the kinds of dirt |
| `grass_types.gdshaderinc` | the kinds of grass that are part of the ground's surface |
| `dirt.gdshader` | one kind of dirt on its own |
| `grass.gdshader` | one kind of painted grass on its own |
| `grass_blades.gdshader` | standing grass: sway, seasons, parting round the player |
| `grass_blades.gd` | `GrassBlades`: makes the tuft meshes and scatters them |
| `ground.gdshader` | a whole level's ground from a painted map |
| `ground.gd` | `Ground`: builds the slab and paints the map |
| `seasons.gd` | `Seasons`: the time of year and the weather |
| `source/gen_ramps.py` | makes the ramps |
| `preview/` | review sheets, made by `tools/ground_preview.gd` |

## Not checked, not done

- Forward+ on Godot 4.7: colours, the stepped light, shadows falling on it (the cloud renderer drew none), cost.
- Zoomed right out a texel is about a screen pixel, so fine detail may shimmer.
- Standing grass: no shadows cast, nothing but the player parts it (zombies and raiders walk through it
  unmoved), and its cost with tens of thousands of tufts is unmeasured.
- Nobody follows tracks yet (raiders don't read yours), tracks don't fade with time, grass takes none, and the
  ground makes no difference to footstep noise.
- Prints sit on a plain world grid, not the ground's turned one, so close up they look like small diamonds.
- The texel grid is turned to the camera's fixed 45 degrees (`GROUND_TURN` in `ground_lib`); if the camera's
  angle ever changes, change it to match.
