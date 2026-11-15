# ShamblerMale_Muscular

Zombie version of MaleBody_Muscular, built from swappable parts so every shambler can look different.

Status: **approved**, 15 Nov 2026. The decay shader and scripts have been compiled and test-rendered in Godot 4.5; the shambler scene has not been set up in the game project yet.

## Files

| File | What it is |
| --- | --- |
| `ShamblerMale_Muscular.glb` | Close-up master: all 19 part meshes |
| `ShamblerMale_Muscular_mid.glb` | Medium distance |
| `ShamblerMale_Muscular_low.glb` | Far away and crowds |
| `ShamblerMale_Muscular_Pieces.glb`, `_Pieces_mid.glb`, `_Pieces_low.glb` | The cut-off pieces (forearm and hand, lower leg and foot, head) that fly off when a part comes off in play, at the same three detail levels. See "Cut-off pieces" |
| `zombie_decay.gdshader` | **Use this one.** Colors the body by how long he's been dead (five decay stages), starting from who he was: any of the 15 living skin tones and five looks |
| `source/skin_tones.js` | The skin tones, looks and hair colors shared with the living skin shader; `gen_decay_shader.js` builds from it |
| `freshness.gd` | The Freshness status: how far something has gone off. Shared with food later |
| `shambler.gd` | Picks a part for each slot, rolls his Freshness and who he was (skin tone, look, hair), flags crawlers |
| `zombie_skin.gdshader` | The first skin shader, with three fixed skin tones. Kept for comparison |
| `anatomy_map.gd` | The torso's anatomy painted into a map, as a script (class `AnatomyMap`). The shader paints the inside of torso wounds from it. `shambler.gd` hands it to the shader |
| `source/gen_anatomy_map.js` | Makes `anatomy_map.gd` (the torso's and the head's maps) from the anatomy in `anatomy.js`, and `anatomy_consts.json`, which tells `gen_decay_shader.js` where the maps sit, where the limb bones run and where the neck is cut |
| `source/pieces_preview.gd`, `source/pieces_preview_compose.py` | What made the piece previews: the Godot test scene (every piece, and a shambler losing three parts) and the sheet layout |
| `source/shambler.js`, `source/anatomy.js`, `source/export_shambler.js` | The recipe: `shambler.js` builds the parts, cuts the wounds and lays the inner surfaces; `anatomy.js` holds the anatomy the painting is made from (ribcage, shoulder blades, spine, pelvis, organs), which is not put into the game models; `export_shambler.js` writes the GLBs. It needs MaleBody_Muscular's `male_body_muscular.js` and `rig.js` beside it |

## How it is put together

- **Six slots:** Head, Torso, ArmL, ArmR, LegL, LegR.
- **Three states per slot:** Intact, Rotted and Destroyed.
- **Mesh names:** each GLB has one mesh per slot and state, named like `Torso_Rotted`, so 18 in all, plus `Head_Decapitated`, which makes 19.
- **Skeleton:** every mesh is skinned to one copy of the MaleBody_Muscular skeleton, with the same 72 bones, names and rest pose. Any animation made for the body works on the shambler.
- **Triangle count:** with all six slots Intact, a shambler has the same 48,488 triangles as the body. Destroyed limbs make it lighter. A wounded torso costs a little more than an intact one, for the walls of its holes and the inner surface under them: at full detail about 14,500 (Rotted) and 14,900 (Destroyed), against 10,900 Intact (mid: 4,300 and 4,600 against 3,000; low: 1,400 and 1,600 against 700). The heaviest possible shambler is about 61,000 triangles at full detail, 19,500 at mid and 6,600 at low.

| Slot | Rotted | Destroyed |
| --- | --- | --- |
| Head | The scalp torn off a patch of skull, a neck bite, the top of the left ear torn off | The skull broken open on one side and holed on top, painted with a red edge of broken bone and the brain showing inside, gouged and bloody; the right ear gone; the back of the neck torn down to the spine |
| Torso | Real holes in the skin: the ribs showing at one flank, a bite on the chest down to the rib cartilage, a tear across the belly down to the muscle, the upper back open down to his left shoulder blade, and a wound above his left hip down to the crest of the hip bone | Torn open from chest to belly: sternum and ribs with some ribs snapped off, the lungs, heart, liver and stomach behind them, the intestines in the belly, ribs showing at the side, the spine at the back with his right shoulder blade bare beside it, the collarbone at the shoulder, and his right hip open down to the hip bone |
| Arm | A long forearm tear down to the radius and ulna, upper-arm wounds, the pinky gone from the first joint | Gone a third of the way down the forearm, with both forearm bones sticking out of a ragged stump; a gouge in the back of the upper arm down to the humerus |
| Leg | The shin torn open down to the tibia, with the fibula beside it, a thigh tear, a bite out of the calf, the little toe gone | Gone below the knee, with the shin bone and fibula showing. **A destroyed leg makes a crawler.** |

**Head_Decapitated** is a fourth head state for after the head comes off. It's a short, ragged neck stump with what's in a neck showing in the cut: a cervical vertebra with the spinal cord behind it, the windpipe as an open tube of cartilage at the front, the gullet behind that, and the big vessels either side. Blood runs down the neck, and down over the shoulders, chest and back (see Blood). A spawn never rolls it; call `dismember("Head")` to switch to it in play. Anything that followed the Head bone is moved onto the Neck bone, so the stump holds still if an animation moves the head.

## Cut-off pieces

When a hit takes a forearm, a lower leg or the head off in play, the part that came away flies off as a loose
piece. `ShamblerMale_Muscular_Pieces.glb` (and `_mid`, `_low`) holds one mesh for each:

| Piece | What it is | Made from | Triangles (full / mid / low) | Mass |
| --- | --- | --- | --- | --- |
| `ArmL_*`, `ArmR_*` | The lower two thirds of the forearm and the whole hand | Intact or Rotted | about 5,900 / 2,100 / 1,100 | 1.2 kg |
| `LegL_*`, `LegR_*` | The lower two thirds of the shin and the whole foot | Intact or Rotted | 8,200 to 10,100 / 2,800 to 3,400 / 1,100 to 1,300 | 3.5 kg |
| `Head_*` | The head, ears and the top of the neck | Intact, Rotted or Destroyed | 2,800 to 5,100 / 1,000 to 1,900 / 270 to 410 | 5.0 kg |

Mesh names are the slot and the state the part was in before it came off, e.g. `ArmL_Rotted`, so a piece looks
exactly like the part it replaces: the same wounds, rot, blood, and the same skin, freckles and hair once the shader
is on it. The piece is cut on exactly the same line as its stump (Destroyed arm or leg, or Head_Decapitated), so the
two fit. The cut face is closed:

- **Arm and leg:** raw flesh with the two bones' broken ends a little proud of it, bone round the edge and red
  marrow in the middle. The skin round the cut is torn, and blood has soaked into it, further in streaks.
- **Head:** the neck's cut seen from below, painted by the shader like the stump's: the vertebra hanging a little
  below the cut with the spinal cord, and the windpipe, gullet and big vessels as open tubes you look up into.

**Pieces are rigid:** no skeleton, so the fingers, wrist and ankle stay as they were at rest. Each mesh is modelled
in the frame of the bone it hangs from (`ForearmRollL/R` for an arm, `CalfL/R` for a leg, `Head` for the head), so
placed at that bone's pose it lands exactly where the part was, however the body was posed. The file also keeps
each vertex's rest position on the body, so the shader paints the piece exactly as it painted the part. In the
file each piece sits where it belongs on the body (Rotted ones moved 0.8 m to his left and Destroyed ones 1.6 m, so
they can be looked at side by side); the game only uses the meshes.

**In play:** set `pieces_scene` on the shambler to one of the pieces files (the low one is plenty for most
distances). Then `dismember(slot, impulse)` does the swap and throws the piece: a `RigidBody3D` with the right
mesh, mass, a convex collision shape and this shambler's look, added to the shambler's parent (or `pieces_parent`),
pushed by `impulse`. It returns the piece and also sends `piece_spawned(slot, piece)`. A part that's already gone
gives no piece. `spawn_piece(slot, from_state)` makes one without changing the body. Pieces don't age with the
shambler's Freshness afterward, and there's no limit on how many stay: clearing old ones is up to the game.
If the shambler node is scaled, the piece comes out at full size.

## What's inside

The wounds are real openings, not dents: the skin is cut away and the edge of each hole has a wall running in
through the layers (torn skin, a thin band of yellow fat, then muscle). What you see at the bottom of a hole is
**painted, not modelled**. Under each hole is one inner surface, and the shader paints on it what lies there in a
real body. No bones or organs are in the models, which keeps the triangle count close to the plain body's.

- **Torso:** the painting comes from the anatomy map (`anatomy_map.gd`). The map was made by building the anatomy
  properly once (`source/anatomy.js`: 12 pairs of ribs with their cartilage and the costal arch, sternum,
  collarbones, shoulder blades with their ridge and socket, spine, hip bones and sacrum, lungs, heart, liver,
  stomach, colon and small intestine, sized from his own joints, skin and ribcage) and writing down what you see
  looking straight in at it from every direction and height. So each wound shows what really lies under that spot:
  ribs over muscle at the flank, cartilage under the chest bite, the shoulder blade on the upper back, the crest of
  the hip bone at the waist. In Torso_Destroyed the inner surface is torn through over the chest and gut, and there
  the shader paints what's behind it: the lungs behind the ribs, heart, liver, stomach and intestines, with four
  ribs snapped and red at the breaks.
- **Every wound's painting has depth.** The torso is the fullest case. The map records not only what is in each direction but how far from the
  body's axis it is, so it is a relief, not a flat picture. For every pixel of a torso wound the shader follows the
  line of sight through that relief: first through the bones, which stand in front of the muscle wall and are
  about a centimetre thick, so you can see under them; then, where the wall is torn through, on into the cavity to
  the organs, from 3 cm in front of the wall (the bulging gut) to 8.5 cm behind it. What the line meets first is what's painted. So the ribs hide what's
  behind them, slide across the organs as the view moves, and things further in are darker. It works on a posed
  body too: the direction of sight is worked out in the body's rest space.
- **The gut is a pile, not a diagram.** The small intestine is one long tube thrown into the belly in loops that
  wander, double back and lie over each other, three layers deep; the front layer bulges out past the belly wall
  and shows through the tear. Among it are torn bits of the yellow fatty apron, dark clots and strands of sinew,
  the colon is lumpy, and blood pools low in the belly. (It used to be six tidy rows.)
- **Anatomical layout.** The thoracic spine starts at the base of the neck, well above the top of the breastbone,
  and each rib slopes down to the front. The upper ribs' cartilage runs level to the breastbone. The lower ribs
  drop further and their cartilage sweeps back up along the costal arch, the upside-down V under the chest. The
  breastbone runs from 1.46 m down to 1.24 m (22 cm with its tip). The lowest rib ends at 1.11 m, about 6 cm above
  the top of the hip bone, as in life. An earlier build had the back of the ribcage 6 cm too low, which made the
  cartilage climb steeply and bunch up at the front, and the lower ribs stopped 5 cm short at the bottom (12 cm
  above the hip bone); both are fixed, and the shoulder blades and lumbar spine moved with it.
- **A chest, not a cage.** Three things made the front of the chest look like a textbook plate, and are changed.
  The point where each rib's bone ends and its cartilage begins now moves round to the side going down (the first
  rib's cartilage is about 2.5 cm, the lower ones 8 to 13 cm), which gives the wide upside-down V under the chest
  instead of a narrow one. The cartilage is pearly off-white, a little greyer than bone; blue is only how diagrams
  draw it. And where the chest is torn, the muscle between the ribs stays, as it does in a real chest, ripped
  through only in ragged patches and where ribs are snapped off; before, the whole wall was gone and bare ribs hung
  over the organs like an anatomy model. Below the ribs the belly wall is still fully torn away.
- **Limbs:** the muscle under a limb wound is gouged, and the bones are painted as round shapes standing out of
  the gouge: radius and ulna in the forearm, tibia and fibula in the shin, the humerus in the upper arm, the spine
  in the back of the neck. The shader knows where each bone runs in the body and follows the line of sight to it,
  so the bone is properly round, lit as a round thing, and shifts against the muscle as the view moves. The bone
  stubs that stick out of a destroyed arm or leg are still small models, because they stick out.
- **Head:** under the scalp is the skull. In Head_Rotted a patch of scalp is torn off it. In Head_Destroyed the
  skull is broken away where the anatomy map says, and through the break you see the brain about a centimetre
  below: its folds, the groove between its halves, gouged and bloody in the middle of the break. The broken edge
  of the skull shows its thickness, with red spongy bone at the rim.
- **Neck:** the cut of Head_Decapitated has depth too: the vertebra stands a little proud with the spinal cord in
  its canal, and the windpipe, gullet and big vessels are open tubes you look down into.

**Gore.** The insides are a mess, not a clean anatomy picture. The shader smears blood over the bone, cartilage
and organs and runs it down them, with dark clots in lumps; the deeper inside and the higher his `gore`, the more
of it, so bone shows through in patches. The raw flesh of every wound wall gets the same. It ages with him: wet
red when he's just turned, darker and clotted in rigor, olive-brown sludge once he's bloated and putrid, a black
crust at the end.

**The insides go off with the body.** Each organ has its own color only while he's fresh (pink lungs, deep red
heart and liver, pale pink gut). In rigor they're still their own colors but dull and dusky, the blood settled out
of them. Bloated, they're grey-green. Putrid, they're dark olive-black slime, with maggots. Dried, they're
black-brown. The raw flesh of the wounds follows the same path: wet red, darker red, dusky grey-brown, dark
olive-brown, dried black. (An earlier build kept the organs fresh-colored right through rigor and left them a
light grey-green, then a warm pinkish brown, in a blackened body.)

**Bone is never white.** White bone is sun-bleached bone, long after the flesh has gone. In a body it starts
ivory, pink with blood; goes yellow and greasy as he bloats; is stained dark olive-brown by the rot when he's
putrid; and dries tan-brown at the end, a little lighter than the leathery skin round it. Cartilage goes off
sooner than bone and ends the same colors. (An earlier build left the bones pale against a blackened body.)

**Nothing hangs out of the model.** Guts spilling, blood, bits of brain and intestine, and limbs flying off are
for the game's live effects (see "Effects in the game" below), not part of the character model.

Limits: the map is about 2.5 mm per dot, so very close up it's blocky, in keeping with the pixel style. Each
organ is a surface, not a solid, so at a very flat angle its edge can look stretched. Thin bones (the forearm's)
show as thin slivers. The depth has a cost: for each pixel of a wound the shader reads the map up to about 100
times in the torso and 80 in the head, steps 45 times down the neck stump, and tests 11 bones in a limb. Wounds
are a small part of the screen, so this should be cheap, but it hasn't been measured on a real graphics card. If
it ever matters, the step counts can be cut for zombies far from the camera.

## Blood

Blood runs from the wounds. When the model is built, some points of every wound start a stream: it runs down the
body (down the limb, on an arm or leg) for a random length, and blood soaks a little way out all round the wound.
Where it has run is stored in the model (`UV2.y`), so it follows the wounds each part actually has.

- **On skin** it shows as thin streams with ragged edges, clotted thicker close to the wound. `gore` sets how
  freely he has bled.
- **On the shorts** a wound doesn't show through cleanly: the cloth is torn round it with a dark frayed edge, the
  wound shows through the tear, and blood soaks into the fabric in a wide stain round and below it.
- **From the neck.** When the head comes off, blood runs from the base of the neck down over the shoulders, chest
  and back. A torn neck bleeds less the same way. The torso meshes carry these streams (`UV2.x`) and the shader shows
  them by `neck_blood`, which `shambler.gd` sets from the head: 1 Decapitated, 0.5 Destroyed, 0.3 Rotted, 0 Intact.
  It updates when `dismember("Head")` is called in play.
- **It ages with him.** Just turned, it's wet and bright red with a shine. Then it darkens, clots to maroon-brown
  through the bloat, and dries to a brown-black crust that flakes away on the oldest.

### Three ways a head dies

Each will get its own visual effect when finished:

| Death | What it is | Status |
| --- | --- | --- |
| **Pierced brain** | Something goes through the skull. The head stays on and mostly whole. | To do: needs faces, then a destroyed-face set |
| **Destroyed head** | The head is smashed or blown apart. | `Head_Destroyed` has the skull broken open over the brain; the destroyed face comes after faces |
| **Decapitated** | The head comes off. | `Head_Decapitated` is done |

## In Godot

1. Put this folder anywhere under `res://`.
2. Right-click `ShamblerMale_Muscular.glb`, choose **New Inherited Scene**, attach `shambler.gd` to the root, and save.
3. Each instance of that scene picks its own look when it spawns. Check `is_crawler`, or connect to the `rolled(parts, crawler)` signal, to choose crawler movement.
4. To force a look, call `roll({"LegL": "Destroyed"})`, or call `show_parts({...}, tone)` for an exact one.
5. `shambler.gd` gives the shader the anatomy map by itself. If you set up a material by hand, call
   `material.set_shader_parameter("anatomy_map", AnatomyMap.texture())`, or the torso's wounds show plain muscle.
6. To throw the cut-off parts as physics pieces, set `pieces_scene` to `ShamblerMale_Muscular_Pieces_low.glb` (or
   `_mid` or the full one). See "Cut-off pieces".
7. When a hit takes a part off in play, call `dismember("Head")`, `dismember("ArmL")` and so on. It swaps the part, throws the piece if `pieces_scene` is set (pass an impulse as the second argument; the piece is returned), and emits `dismembered(slot, crawler)`. `is_decapitated` and `is_crawler` stay up to date.

You can change these settings on the script in the Inspector:

| Setting | Default | What it does |
| --- | --- | --- |
| `chance_rotted` | .40 | Chance a slot rolls Rotted |
| `chance_destroyed` | .15 | Chance a slot rolls Destroyed |
| `max_lost_legs` | 1 | Most legs one shambler can lose |
| `groups`, `variant_weights` | all five groups; 1 each | Who he was: which skin tone groups to roll from and an extra weight per look, the same as on a living body (see MaleBody_Muscular living skins) |
| `roll_seed` | -1 | Any number other than -1 gives the same shambler every time |
| `pieces_scene` | none | The cut-off pieces file. When set, `dismember()` throws the part that came off as a physics piece |
| `pieces_parent` | empty | Where pieces are added; empty uses the shambler's parent |

## Decay and Freshness

Each shambler rolls a **Freshness** when he spawns: 1.0 means he just turned, 0.0 means he's been dead a long time. `zombie_decay.gdshader` colors him from that value. A freshly turned shambler goes paler than he was in life, never green: the darkening only starts once he bloats, then deepens through green and olive-black to dark leathery brown.

## Who he was

Every zombie was a person, so each shambler is rolled as one: a skin tone (any of the 15 living tones, in the same
five heritage groups), a look (freckles, clean shaven, hairy, old or vitiligo) and a hair color, with the same
weights as the living (`LivingBody.roll_look()` in `living_body.gd`, which this needs in the project). Freshly
turned, his tone is drained and paler than in life (chalky on lighter skin, ashen on deeper skin); in rigor
it's still pale but waxy (yellowed on lighter skin, ashen on deeper skin). His
freckles, age spots, wrinkles and vitiligo show while he's fresh and fade through the bloat; from then on the rot
evens everyone out, with deeper tones a shade darker. Body hair and stubble outlast the skin, thinning at the end.

The look uses the same seed and patterns as the living skin shader, so a person who turns keeps their freckles,
vitiligo patches and stubble in the same places. `turn_from(person)` does that in one call: it copies a living
body's tone, look, hair and seed onto a freshly turned shambler.

| Stage | Freshness | What it looks like |
| --- | --- | --- |
| Fresh | 1.00 to 0.88 | Paler than in life: the blood has drained from the skin, so lighter skin goes chalky and deeper skin ashen. Blood starting to pool in the feet and hands. Blue-purple nails. Wounds wet and red, bone pink |
| Rigor | 0.88 to 0.68 | Still pale, but waxy and yellowed. Lividity set dark purple across the back he lay on, with pale pressure points at the shoulder blades and buttocks, and in the feet and hands. Stiffest here |
| Bloated | 0.68 to 0.44 | Green, starting at the lower belly and spreading. Veins marbling black. Skin starting to slip off |
| Putrid | 0.44 to 0.20 | Olive-black and wet. Skin sloughing off in patches. Maggots in the wounds. Wounds grey-brown |
| Dried | 0.20 to 0.00 | Leathery dark brown. Wounds dried black. Bone stained yellow-brown |

Some parts run ahead of the rest once he's past rigor: the belly, old bruises and random blotches. Hands and feet dry out first at the end. Colors follow what a body actually does (pale first, darker only as it rots); the mood comes from where he is and how he's lit, not from darkened palettes. About 8% of pixels are nudged a shade lighter or darker, the same as the living skin.

**Grime** is drawn in its own earth colors, and each shambler has his own amount (`grime`, 0 clean to 1 caked):
mud splashed up the feet and shins, breaking up as it climbs, with flecks above; dust settled on whatever faces up
(head, shoulders, upper back, tops of the feet); grass and earth stains on the knees and hands from crawling and
grabbing; and a few thin smears down the torso, back and shorts. Dust shows best on deeper skin, as it does in life.

**Values the shader reads per shambler** (instance uniforms, which `shambler.gd` sets):

| Value | Range | What it does |
| --- | --- | --- |
| `freshness` | 0 to 1 | How long he's been dead (above) |
| `skin_tone` | 0 to 14 | Who he was: the living skin tone (see the living skins) |
| `variant` | 0 to 4 | His look: freckles, clean shaven, hairy, old, vitiligo |
| `hair_color` | 0 to 4 | Blond, ginger, brown, dark, grey |
| `look_seed` | any number | Places his freckles, vitiligo and hair; the same seed as in life gives the same spots |
| `decay_seed` | any number | Moves the blotches, marbling, slipped skin and stains so no two look alike |
| `gore` | 0 to 1 | How much blood is spattered on the hands, arms, chest and shorts, and how freely his wounds have bled |
| `grime` | 0 to 1 | How dirty he is: mud, dust, stains and smears |
| `neck_blood` | 0 to 1 | Blood run down from the neck over the torso; set from the head's state |

The shared uniforms `ambient` (0.13), `pixel_size` and `grit` (0.08) are on the material, matching the living skin.

**Spawner settings** (Freshness group in the Inspector): `stage_weights` sets how often each stage rolls (default Fresh 2, Rigor 2, Bloated 3, Putrid 3, Dried 1). `rotted_scale_fresh` and `rotted_scale_old` (0.6 and 1.25) make fresh shamblers roll fewer Rotted parts; the Rotted parts they do get show as fresh bites and tears. `groups`, `variant_weights`, `gore_range` and `grime_range` (0.1 to 0.9) set the rest.

**In play:**

- `stage()` gives the stage name.
- `rigor()` gives the rigor mortis stiffness, from 0 (loose) to 1 (fully stiff). It's highest in the Rigor stage; use it for stiff, jerky movement.
- To force a look, call `roll({}, 1.0)` for one who just turned. Call `set_skin(freshness, tone, look, hair, look_seed, decay_seed, gore, grime)` for an exact look.
- `turn_from(person)` turns a living body (a `LivingBody`) into this shambler, keeping who they were.
- To let him rot during play, set `freshness.hours_to_rot` and call `freshness.age(hours)`. The shader updates on its own, and `stage_changed` fires at each border.

**Freshness for food.** `freshness.gd` is a plain Resource and knows nothing about zombies. `Freshness.new(1.0, Freshness.FOOD, 72.0)` gives food that goes Fresh, Stale, Spoiled, Rotten over 72 game hours. You can pass your own stage list the same way.

**`show_parts()` changed:** it now takes only the parts, `show_parts({...})`. The look is set with `set_skin()`.

## Data the shader reads

This is the same as MaleBody_Muscular, plus the blue channel:

- `UV` and `UV2`: fine coordinates for the drawn details
- `COLOR.r`: shadow amount
- `COLOR.g`: coarse depth
- `COLOR.a`: part code
- `UV2.y`: blood run-off from the wounds (0 none, 1 at the wound)
- `UV2.x` on the torso: blood run down from the neck (the hands, feet and nails use `UV2.x` for their drawn details, as before)
- `CUSTOM0`: each vertex's rest position (x, y, z) and the y of its rest normal (w), so the rot blotches, veins, stains, grime and who-he-was details stay on the skin as he moves. In the GLB these are `TEXCOORD_2` and `TEXCOORD_3`; Godot imports the pair as `CUSTOM0` on its own. Added 15 Nov 2026; nothing else in the meshes changed. Dust settles on what faced up at rest, and stays there
- `COLOR.b`: rot, read by these ranges:

| Rot value | What it shows |
| --- | --- |
| 0 to .3 | Dead skin, with blotches and veins |
| .3 to .45 | Torn skin at the edge of a wound |
| .45 to .5 | The band of fat under the skin |
| .5 to .8 | Muscle, darker the deeper it is |
| Above .8 | Bone |

The inner surfaces carry their own part code in `COLOR.a` (code x 17), which tells the shader what to paint:

| Code | Surface | What the shader paints, and from what |
| --- | --- | --- |
| 15 | The muscle inside a limb | Round bones standing out of the gouge, from where each limb bone runs (written into the shader by `gen_decay_shader.js`) |
| 14 | The inner wall of the torso | The anatomy map, as a relief with depth: bones in front of this surface, and the organs behind it where the wall is torn through. `COLOR.g` marks the torso that is torn (Torso_Destroyed); where it's torn is in the map |
| 13 | The skull | The head's anatomy map, as a relief: the skull, and the brain below it where it's broken away. `COLOR.g` marks the head that is broken (Head_Destroyed) |
| 12 | The cut of a severed neck | The vertebra standing proud, and the windpipe, gullet and vessels as open tubes, from where each sits |

`COLOR.r` on these holds how deep under the skin they are, for the depth shading. The older `zombie_skin.gdshader`
doesn't know these codes and shows the inner surfaces as plain flesh and bone.

## Effects in the game

Planned as live effects, not model parts: guts spilling out, blood, bits of brain and intestine, and limbs that
come off, fly and pile up on the ground. That's doable in Godot 4:

- **Blood and bits:** `GPUParticles3D` with small pixel-sized quads or chunks, set off at the wound when
  `dismembered` fires or a hit lands. Particles can collide with the ground and stay as decals or small meshes.
- **Limbs and heads:** done: the cut-off pieces and `dismember()` throwing them. See "Cut-off pieces".
- **Piles:** loose pieces and stains need a cap on how many stay, with the oldest fading out.

The blood and bits, and the cap on piles, are not built yet.

## Not done yet

- **Faces:** the head has no face, the same as the body. Destroyed faces come after the faces are made.
- **Pierced brain:** not made yet. See the three head deaths above.
- **Animations:** shambling, crawling and attack animations are still to be made in Godot. `rigor()` is there for them to read. The painted details now follow posed limbs (`preview/decay_pose.png`, bones turned by hand in Godot); they haven't been run with a real animation yet.
- **Gore effects:** blood and bits as particles, and a cap on how many pieces stay. See "Effects in the game".
- **Late-stage zombies:** the anatomy the painting is made from could also be exported as real models for a few late-stage variants, if they're wanted later.
- **Tested so far:** `zombie_decay.gdshader`, `freshness.gd` and `shambler.gd` compile and run in Godot 4.5. The previews were rendered in Godot using the close-up master GLB. That machine used Godot's Compatibility renderer without a GPU, which ignores per-instance values, so the previews set them per material instead. The shader code is otherwise unchanged. Still to check in your project: the shambler scene under Forward+ on Godot 4.7.
