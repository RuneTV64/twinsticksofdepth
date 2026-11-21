# Furniture

Furniture for the house kit, in the 8-shade 3D-Pixel look: one plain, sturdy household style, seventeen pieces,
and rugs and curtains. **Status: in review** (made 21 Nov 2026; never seen on Forward+, only on the cloud's
software renderer).

## The pieces, and what each is for

Every object has to do something to the player (the owner's rule). Measured in the game's test level
(`tools/furniture_test.gd`, cloud run, 21 Nov 2026), each piece sound:

| Piece | Height | Cover | Zombie blows | Hatchet | Leaves | What it does now |
|---|---|---|---|---|---|---|
| Couch | 0.85 m | low | 9 | 2 | wood, cloth | crouch behind it, vault it |
| Armchair | 0.85 m | low | 4 | 1 | wood, cloth | the same |
| Table | 0.78 m | low | 6 | 1 | wood | hides you crouched; a zombie climbs over it |
| Chair | 0.9 m | low | 2 | 1 | wood | in the way; a zombie climbs over it |
| Kitchen counter | 0.9 m | low | 7 | 2 | wood | cover along a wall, any length |
| Stove | 0.9 m | low | 600 | 32 | metal | cast iron; lay wood on it and light it, and **water boils on it** |
| Fridge | 1.8 m | high | 315 | 17 | metal, plastic | stops sight |
| Bed | 0.8 m | low | 15 | 3 | wood, cloth | crouch behind it, vault it |
| Wardrobe | 1.9 m | high | 11 | 2 | wood | stops sight; has to be beaten down or gone round |
| Dresser | 0.85 m | low | 5 | 1 | wood | cover |
| Bookshelf | 1.9 m | high | 8 | 2 | wood | stops sight; shelves to search |

### The living room (21 Nov 2026: the first theme, a middle-class living room, its furniture session)

| Piece | Height | Cover | Zombie blows | Hatchet | Leaves | What it does now |
|---|---|---|---|---|---|---|
| Coffee table | 0.45 m | low | 3 | 1 | wood | get down behind it, vault it; a shelf underneath to search |
| Side table | 0.6 m | low | 2 | 1 | wood | a drawer to search |
| TV cabinet | 0.55 m | low | 3 | 1 | wood | a cabinet to search (the television comes with the appliances) |
| Display cabinet | 1.85 m | high | 8 | 2 | wood, **glass** | stops sight; glass shelves and a cupboard to search; smashed, it is broken glass to pick up |
| Fireplace | 1.15 m (the chimney breast to 2.55) | low | about 1,000 | 54 | brick, metal | brick: 9 sledgehammer blows. **A fire**: lay wood in it, light it with a match, and it lights the room (full at 1.5 m, a quarter at 4 m: you see by it and are seen in it) and boils water in a pot |
| Piano | 1.25 m | low | 14 | 3 | wood, metal | **played, it is heard 28 m off** (a gunshot is 30): a lure. Play it and leave by the back |
| Rug | flat | none | not a solid thing | | | **footsteps on it are heard half as far** (walking 4.5 m to 2.25). Rolled up (nothing standing on it) it is an item, "Rolled-up rug" (6 kg, two hands, a poor club, cut up for cloth), laid again wherever you stand |
| Curtains at a window | | | not a solid thing | | | **drawn, nobody sees in or out**: they stop sight both ways but not shots, thrown things or anyone climbing through. Click to draw or open; Shift+click takes them down: the "Curtains" item (a cloak) |

Cloud run (`tools/living_test.gd`): a raider 7 m outside the living room's south window, the player 1 m in:
curtains drawn, neither saw the other; open, both did; drawn, a shot's line to him was still clear. The piano
was heard by a zombie 24 m off and not one 32 m off. Walking on a rug was heard 2.25 m, off it 4.5 m. Over 200
rolls each: a coffee table holds about 2 things, a side table 1, a TV cabinet 3, a display cabinet 5 (from the
living room's things). The display cabinet smashed left wood and glass.

A piece put down damaged or about to give starts at 60% or 30% of that (a wardrobe: 11, 7, 4 zombie blows).
In the furnished kit house: hunkered in front of the couch you are hidden from across it; someone the far
side of the fridge is not seen, someone the far side of the table is; a zombie with a chair or the kitchen
table between it and you climbed over in under 3 s; a bottle of water put on the kitchen stove, once it had wood, a
match and a pot, had boiled 20 s later.

What each is meant to do once the system it waits for exists (`FurnitureKit.LATER`; none of it is built): the
fridge, wardrobe, dresser and counter are containers to search; the bed is for sleep; the couch and chairs for
sitting to rest; the bookshelf for books; the stove for cooking and warmth (the fire you have to feed is built).

## How it is made

- `furniture_kit.gd` (`FurnitureKit`). A piece is a few boxes joined into one mesh (a couch is a seat, a back
  and two arms; a bed is a frame, a mattress, a blanket, two pillows and a headboard), built once for each
  kind and shared. It stands on a floor facing north, east, south or west.
- Every piece goes through `Solid` (`solid.gd`): it is made of something (wood; wood and cloth; cast iron;
  steel and plastic), it is cover on the floor it stands on, and it breaks like the rest of the world.
  Furniture is lighter than walls (`Breakable.thin_to`), and a piece breaks whole. Cloth is a new material:
  it leaves "Torn cloth".
- `furniture.gdshader` paints every face of every box, texel by texel on the face's own grid (16 to the
  metre), by the part it plays: boards, a front of drawers with brass knobs, panelled doors, shelves of
  books, upholstery with its cushion seams, a sheet, a striped blanket, pillows, cast iron with a fire
  behind the stove's door, white enamel, a worktop, cupboard doors. The mesh tells it which.
- What changes the look, with no change of mesh:
  - **how worn it is** (`wear` 0, 1, 2, the three stages of damage): scuffs and fading, books and a drawer
    gone; then cloth torn to the stuffing, drawers and doors out, rust on the iron and the enamel;
  - **the season**, but indoors only the damp gets at it, and only once it is worn: darker, with mould in
    the wet and the cold;
  - **the cutaway**: furniture stands while you are indoors (as the stairs do), and opens only round you,
    round the crosshair, and above the storey you are on;
  - the wood (`stain`: pine, oak, walnut) and the cloth (`fabric`: brick red, olive, blue).
- It uses the house kit's shared files and ramps, with eight ramps of its own
  (`furniture_ramps.gdshaderinc`, from `source/gen_furniture_ramps.py`).

## Putting furniture down

```gdscript
var f := FurnitureKit.new(level, 0)                      # wear 0..2; then the wood and the cloth
f.put("couch", Vector3(19.5, 0, -28.6), "N")             # where its middle stands on the floor; its front
f.counter(Vector2(24.2, -33.5), Vector2(25.9, -33.5), 0.0, "S")

# Or a whole ordinary house (3 cells by 2, as HouseKit.house builds it):
FurnitureKit.furnish(level, house_origin, 2)             # the house's origin, how many storeys
```

`furnish` makes a living room inside the front door round a fireplace (a hearth rug, the couch against the west
wall with a coffee table and a side table, an armchair facing the fire, a bookshelf, a display cabinet,
curtains drawn at its two windows), a den in the back room (the piano under its curtained window, a rug, the TV
cabinet, a dresser), a kitchen in the east room (counter, stove, fridge, table, two chairs), and upstairs two
bedrooms.

```gdscript
f.rug(Vector3(21, 0, -29.25), Vector2(1.8, 1.0), 0)        # its middle, its length and width, quarter turns
f.curtains(window_point, a_point_inside)                  # at the nearest window on that storey
```

## Files

| File | What it is |
|---|---|
| `furniture_kit.gd` | `FurnitureKit`: builds the pieces, puts them down, furnishes a house |
| `furniture.gdshader` | Paints every part of every piece, at every stage of wear |
| `furniture_ramps.gdshaderinc` | Cloth, linen, cast iron, enamel, embers and brass: their 8-shade ramps (generated) |
| `source/gen_furniture_ramps.py` | Makes the ramps from colour stops |
| `preview/furniture_pieces.png` | Every piece, from the front, the side and behind |
| `preview/furniture_wear.png` | The three stages of wear, and the damp |
| `preview/furniture_colours.png` | The three woods and the three cloths |
| `preview/furniture_house.png` | The kit house furnished: the living room round its fireplace, the den, the kitchen |
| `preview/living_room.png` | The living room's pieces, sound (the fire lit, one window's curtains drawn and one open) and worn out |
| `../../../rug.gd`, `window_curtains.gd`, `piano.gd` | (in the game's root) the rug, curtains at a window, a piano's keys |
| `source/living_test.gd` | The headless test of the living room's pieces (in the repository: `tools/living_test.gd`) |
| `source/furniture_preview.gd` | The harness that renders the sheets (in the repository: `tools/furniture_preview.gd`) |
| `source/furniture_test.gd` | The headless test of what each piece does in play (in the repository: `tools/furniture_test.gd`) |

## Not checked, not done

- Forward+ on Godot 4.7: colours, the stepped light, cost.
- The dresser, wardrobe, kitchen counter, fridge and bookshelf can be searched (`stash.gd`: the kit puts a `Stash` on each; what is in it spills on the floor if the piece is broken). Nothing can be sat on, slept in or cooked on yet.
- Nothing can be pushed, dragged, tipped over or stood on, so furniture can't be used to block a door or a
  window.
- The stove is cold until wood is laid on it and lit with a match, and burns the wood down (campfire.gd); its door glows while it burns. It gives no light or warmth. The fireplace does give light; neither gives warmth (there is no warmth need yet), and there is no smoke.
- There is no bathroom (bath, sink, toilet): those wait for water from taps and for the hygiene and toilet
  needs. No lamps, pictures or a television yet (the appliances session).
- The piano's tune is only a noise (there are no sounds yet); playing it has no pose. Curtains don't burn or
  tear, and a broken window leaves them hanging. A rug does nothing to glass on it, and laid on stairs it
  floats. The fireplace's chimney breast is only drawn (what you walk into is the fireplace's box).
- What you walk into is one plain box round the whole piece, so you can't step between a chair's legs or
  see under a table, and a shot is stopped by a bed's whole box.
- One style and one size of each. `furnish` only knows the ordinary 3 by 2 house, and puts nothing in a
  basement.
- A worn piece is worn all over, not where it was hit; a broken one leaves the usual plain heap.
