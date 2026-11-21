# Fence

Timber fences in the 8-shade 3D-Pixel look, made the way the house kit is: one style, a few parts, and one
shader that changes them with the weather, the seasons and how worn they are. **Status: in review** (made
21 Nov 2026; never seen on Forward+, only on the cloud's software renderer).

## The three kinds, and what each is for

Every object has to do something to the player (the owner's rule). Each fence does a different thing:

| Kind | Height | What it does |
|---|---|---|
| `picket` | 1.0 m, painted white | Low cover: you crouch behind it, vault it, shoot over it. A zombie climbs it and lands on its face. It buys a few seconds. |
| `board` | 1.875 m, bare boards | Stops sight and bodies. Nobody vaults it and one zombie can't climb it, so it has to be beaten down or gone round. The way through is the gate. |
| `rail` | 1.25 m, posts and three rails | Hides nobody and stops no sight. About four shots in five go through it; the rest hit a rail. It only slows whoever has to get over it. |
| gate | the fence's height | A hinged leaf in any of the three, 1.25 m wide, opened and shut with interact like a door. |

Measured in the game's test level (`tools/fence_test.gd`, cloud run, 21 Nov 2026). A 1.2 m section, sound:

| Kind | Zombie blows | Punches | Hatchet | Shots | A zombie with you in sight |
|---|---|---|---|---|---|
| Picket | 3 | 6 | 1 | 8 | climbed over in about 4 s |
| Board | 9 | 18 | 2 | 22 | broke through in about 21 s (its gate: 24 s) |
| Rail | 5 | 9 | 1 | 11 | climbed over in about 5 s |

Put up damaged or about to give, a fence starts at 60% or 30% of that. Across a rail fence a zombie 8 m off was
seen, and 31 of 40 level shots reached it; across a board fence it was not seen and none did.

## Spikes

A picket fence has points, and bodies can be impaled on them (the owner's rule: anything with spikes). The kit
gives each kind a `spikes` chance (picket 0.3, the others none); the game does the rest (`enemy.gd`):

- A zombie flopping over the top may stick there, and so may one knocked backward onto it. Being impaled
  doesn't kill it: it hangs on the fence alive, writhing, clawing and kicking, and every few seconds heaves
  to pull itself off, until it does, the fence gives way under it, or someone ends it. A body already on
  the points covers them for the next one over. (The pose is the game's `zombie_body.gd`; pictures in the
  repository: `tools/preview/zombie_impaled.png` and `.gif`.)
- You can catch a leg vaulting one, and coming down on one from a height is a deep wound. Raiders are caught
  too.
- Cloud run (`tools/impale_test.gd`): of 14 zombies sent over one at a time, 5 stuck; of 30 knocked backward
  onto it, 9 came down on the points; the player vaulting 60 times was caught 3 to 7 times.

## How it is made

- `fence_kit.gd` (`FenceKit`). A fence is a run from one point to another along X or Z, with gates anywhere
  along it. Each stretch between gates is one thin box made through `Solid` (`solid.gd`), so it is wood, it
  breaks like everything else, and it is cut where it is hit: a blow knocks out a gap a person wide. What
  is left is splintered wood to pick through.
- `fence.gdshader` draws the posts, pickets, boards and rails on that box, texel by texel on the ground's
  grid (16 to the metre), and cuts the gaps out, so you really see through them. Posts stand at both ends
  of a run and evenly between. One side is the good side (pickets and boards in front); the other shows the
  rails. A gate keeps its pattern as it swings and is braced corner to corner.
- Three things change the look with no change of mesh, as with the house:
  - **the season and the weather** (`ground_season`): wet streaks, a bleached summer, algae up from the
    ground in the damp seasons, autumn leaves caught against the foot, frost, snow on every cap, rail and
    point;
  - **how worn it is** (`wear` 0, 1, 2: the three stages of damage): paint peels, bare timber goes from warm
    to silver-grey, pickets and boards snap off or go missing, rails sag and fall;
  - **the cutaway**: a tall fence between the camera and you opens like a wall.
- Paint: `-1` bare timber, `0` cream, `1` sage, `2` slate (the house's paints), `3` white. Each kind has its
  own (picket white, the others bare). Posts and rails of the board and rail fences are never painted.
- It uses the house kit's shared files (`house_lib.gdshaderinc`, `house_ramps.gdshaderinc`,
  `house_light.gdshaderinc`) and the ground's library, so it needs `assets/buildings/house/` and
  `assets/ground/` beside it.

## Putting a fence up

```gdscript
# A fence right round a rectangle, with a gate in the middle of the south side.
FenceKit.yard(level, Rect2(30, -28, 6, 4), "picket", "S")

# Or run by run. Gates are given as how far along the run their middle is.
var f := FenceKit.new(level, "board", 1)          # kind, wear (0..2), paint (left out: the kind's own)
f.run(Vector2(18, -39.5), Vector2(18, -34), [], Vector2(-1, 0))    # the good side faces west
f.run(Vector2(27, -34), Vector2(30, -34), [1.5])                   # a gate 1.5 m along
```

## Files

| File | What it is |
|---|---|
| `fence_kit.gd` | `FenceKit`: puts up runs, gates and yards |
| `fence.gdshader` | Draws every kind, in every weather and stage of wear |
| `preview/fence_parts.png` | Each kind from both sides, gates shut and open |
| `preview/fence_seasons.png` | A yard of all three through the year |
| `preview/fence_wear.png` | The three stages of wear |
| `preview/fence_paints.png` | The picket fence's paints, and a whitewashed board fence |
| `preview/fence_house.png` | Round the kit house |
| `source/fence_preview.gd` | The harness that renders the sheets (in the repository: `tools/fence_preview.gd`) |
| `source/fence_test.gd` | The headless test of what each fence does in play (in the repository: `tools/fence_test.gd`) |
| `source/impale_test.gd` | The headless test of impaling (in the repository: `tools/impale_test.gd`) |

What the game itself needed for it, outside this folder: `Breakable.gaps` and `thin` (`breakable.gd`),
`Solid.open_up()` (`solid.gd`), `Cover.Box.open` (`cover.gd`), a shot going through gaps (`projectile.gd`),
and `Door.noun` (`door.gd`).

## Not checked, not done

- Forward+ on Godot 4.7: colours, the stepped light, the shadows the cut-out throws, cost.
- A fence is flat: posts are drawn, not modelled, so they are no thicker than the boards.
- Fences run along X or Z only, on level ground. No slopes, no diagonals, no curves.
- A bullet stops at a board fence as it does at a house wall. A real one would go through.
- A gate is a plain door underneath: it blocks sight and shots up to its own height even in a rail fence, it
  has no latch or lock, and zombies beat on it rather than climb it.
- A worn fence is worn all over, not where it was hit. A broken section leaves a clean edge.
- Raiders don't know a rail fence gives no cover (they just never pick it). Nothing is built to mend or put
  up a fence in play.
- An impaled zombie leaves no blood on the points, and the points don't show through it; nothing made for
  impaling (sharpened stakes, iron railings) exists yet.
- One style only: no chain link, iron railings, walls or hedges yet.
