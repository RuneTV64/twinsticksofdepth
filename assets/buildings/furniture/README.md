# Furniture

Furniture for the house kit, in the 8-shade 3D-Pixel look: one plain, sturdy household style, eleven pieces.
**Status: in review** (made 21 Nov 2026; never seen on Forward+, only on the cloud's software renderer).

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
| Stove | 0.9 m | low | 600 | 32 | metal | cast iron, and lit: **water boils on it** |
| Fridge | 1.8 m | high | 315 | 17 | metal, plastic | stops sight |
| Bed | 0.8 m | low | 15 | 3 | wood, cloth | crouch behind it, vault it |
| Wardrobe | 1.9 m | high | 11 | 2 | wood | stops sight; has to be beaten down or gone round |
| Dresser | 0.85 m | low | 5 | 1 | wood | cover |
| Bookshelf | 1.9 m | high | 8 | 2 | wood | stops sight |

A piece put down damaged or about to give starts at 60% or 30% of that (a wardrobe: 11, 7, 4 zombie blows).
In the furnished kit house: hunkered in front of the couch you are hidden from across it; someone the far
side of the fridge is not seen, someone the far side of the table is; a zombie with a chair or the kitchen
table between it and you climbed over in under 3 s; a bottle of water put on the kitchen stove had boiled 20 s
later.

What each is meant to do once the system it waits for exists (`FurnitureKit.LATER`; none of it is built): the
fridge, wardrobe, dresser and counter are containers to search; the bed is for sleep; the couch and chairs for
sitting to rest; the bookshelf for books; the stove for cooking, warmth, and a fire you have to feed.

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

`furnish` makes a living room inside the front door (couch, armchair, bookshelf), a kitchen in the east room
(counter, stove, fridge, table, two chairs), a dresser in the back room, and upstairs two bedrooms.

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
| `preview/furniture_house.png` | The kit house furnished: ground floor, upstairs, and derelict |
| `source/furniture_preview.gd` | The harness that renders the sheets (in the repository: `tools/furniture_preview.gd`) |
| `source/furniture_test.gd` | The headless test of what each piece does in play (in the repository: `tools/furniture_test.gd`) |

## Not checked, not done

- Forward+ on Godot 4.7: colours, the stepped light, cost.
- Nothing can be searched, sat on, slept in or cooked on yet. Those wait for loot, rest and food.
- Nothing can be pushed, dragged, tipped over or stood on, so furniture can't be used to block a door or a
  window.
- The stove is always lit and needs no fuel. It gives no light or warmth.
- There is no bathroom (bath, sink, toilet): those wait for water from taps and for the hygiene and toilet
  needs. No small things either: lamps, rugs, pictures, a television, low tables.
- What you walk into is one plain box round the whole piece, so you can't step between a chair's legs or
  see under a table, and a shot is stopped by a bed's whole box.
- One style and one size of each. `furnish` only knows the ordinary 3 by 2 house, and puts nothing in a
  basement.
- A worn piece is worn all over, not where it was hit; a broken one leaves the usual plain heap.
