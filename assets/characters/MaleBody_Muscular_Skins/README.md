# MaleBody_Muscular living skins

Living skin tones and looks for MaleBody_Muscular, so the living (not undead) people in the game don't all look
alike. There are five skin tone groups, named by heritage, with three tones each: 15 tones in all. Every tone gets
all five looks, freckles and vitiligo included.

Zombies use these too: a shambler is rolled as one of these people (`LivingBody.roll_look()`), keeps their tone
and look, drained by death and evened out by the rot, and `turn_from(person)` turns a living body.

Naming treats everyone the same: no group or tone is named for a color of person. Groups are named by heritage,
and tones get material and pigment names.

Status: **approved**, 15 Nov 2026. Compiled and test-rendered in Godot 4.5. MaleBody_Muscular itself is
approved and locked. Its shape and skeleton are untouched; on 15 Nov 2026 its three GLBs gained each vertex's rest
position so these looks stay on the skin when he moves (see "Staying on the skin" below).

## Files

| File | What it is |
| --- | --- |
| `body_living.gdshader` | Skin shader: the approved body shader's lighting and drawn details, plus skin tones and looks |
| `living_body.gd` | Rolls a skin tone, a look and a hair color for each body, and sets them on the shader |
| `source/skin_tones.js` | The skin tones, looks and hair colors. Shared with the zombie decay shader, so zombies are rolled as these same people |
| `source/gen_living_shader.js` | Builds `body_living.gdshader` from `male_body_muscular_skin.gdshader` and `skin_tones.js` |
| `source/preview_render.gd.txt`, `source/living_preview_compose.py.txt` | The Godot scene script and the script that made the previews |
| `source/pose_preview_compose.py.txt` | Makes the posed before and after sheets (this one and the zombie one) |
| `preview/` | For each group, a 3 x 5 grid (front and back) and close-ups, and a palm strip where the palms differ |
| `preview/living_pose.png` | Two bodies at rest and posed, before and after the rest-position change |

## Skin tones (`skin_tone`)

| Group (`groups` key) | Tones |
| --- | --- |
| European (`european`) | 0 Porcelain (fair, pink undertone), 1 Cream (the approved MaleBody_Muscular skin, unchanged), 2 Fawn (warm, sun-browned) |
| African (`african`) | 3 Umber (medium, warm), 4 Mahogany, 5 Ebony (the deepest, with a cool undertone in the shadows) |
| Latin American (`latin`) | 6 Golden (light, warm), 7 Copper (red-brown), 8 Bronze (deeper brown) |
| Asian (`asian`) | 9 Wheat (light corn), 10 Honey (warm golden), 11 Almond (soft, muted brown) |
| Middle Eastern & South Asian (`mideast_southasia`) | 12 Sand (light, olive undertone), 13 Caramel (warm, medium), 14 Chestnut (deep, cool undertone) |

Each tone carries its own skin, flush, aged-skin, nail, freckle, age-spot and palm colors, because these differ
from tone to tone:

- **Freckles and age spots** are orange-tan and tan on the European tones, and a shade darker than the skin on
  the others.
- **Palms and soles** are lighter and pinker than the rest of the skin on the deeper tones (Umber, Mahogany,
  Ebony, Copper, Bronze, Almond, Caramel, Chestnut), with the palm creases still drawn. The undersides of the
  fingers and the base of the thumb stay skin colored: the model only marks the palm itself, and guessing the
  finger side from its direction would break once the arms animate.
- **Grey hair** on the old look is sparser the deeper the tone, so it reads as a light sprinkle, not white specks.
- **Flush** stays close to the skin color on the deeper tones.
- **Nails** use the approved body's recipe over each tone, which makes them lighter than the skin on the deeper
  tones, as in life.

## Looks (`variant`)

| `variant` | Look | What it adds |
| --- | --- | --- |
| 0 | Freckles | Light clusters on the face, shoulders, upper back and arms; light body hair |
| 1 | Clean shaven | Smooth skin, a faint razor shadow on the jaw, almost no body hair |
| 2 | Hairy | Chest hair, a line down the belly, forearms, legs, a little on the upper back, and stubble on the jaw and neck |
| 3 | Old | Sallower, thinner skin, wrinkles (deepest on the neck), age spots on the head, hands, forearms and shoulders, sparse grey hair and stubble |
| 4 | Vitiligo | Milky pink-white patches where the skin has lost its color (subtle on Porcelain, as in life, and stronger the deeper the tone): sharp-edged, mostly mirrored left and right, most often on the hands and fingers, wrists, around the mouth, elbows, knees and feet, with a few on the chest, back and limbs. Some edges have a slightly darker rim. How far it spreads differs from body to body |

Every look also gets a living flush where the blood sits close: ears, cheeks, nose, knees, elbows, hands and feet.
That flush is what sets them apart from the shamblers.

`hair_color` colors the body hair and stubble: 0 blond, 1 ginger, 2 brown, 3 dark, 4 grey. Fair hair shows less,
the way it does in life. `look_seed` moves the freckles, hair and spots so no two bodies match.

There's no scalp hair, eyebrows or face yet: the head has no face. Those come with the face and hair modules.

## Staying on the skin

Freckles, vitiligo, body hair, stubble, wrinkles and age spots are placed by where they are on the body. The
shader reads that place from the rest position stored in the model (`CUSTOM0`), not from where the limb is now, so
they move with the arm or leg. Before this change they stayed fixed in space and slid over a moving limb.

It needs the MaleBody_Muscular GLBs from 15 Nov 2026 or later. With an older GLB the shader still works but falls
back to the old behavior.

## In Godot

1. Right-click `MaleBody_Muscular.glb`, choose **New Inherited Scene**, attach `living_body.gd` to the root, and save.
2. Each instance rolls its own look when it spawns.
3. Call `roll()` for a new look. Call `roll(-1, 3)` to force a look (here, old) with any tone. Call `set_look(tone, variant, hair, seed)` for an exact one.
4. `describe()` gives a readable name, like "Fawn, hairy, dark hair".

Inspector settings: `groups` (which groups to roll from; default all five), `variant_weights` (an extra weight on
each look, on top of the group's own; 0 turns a look off) and `roll_seed`. Each group sets how often each look
rolls (`looks` in `living_body.gd`): freckles 1, clean shaven 2, hairy 1.5, old 1, vitiligo 1, except Asian, where
hairy is 1. Hair color is weighted by look and group: for example, European freckled bodies lean ginger and blond,
most other groups are mostly dark-haired, and old is grey.

## Adding a skin tone group

In `source/skin_tones.js`, append the new group's tones to `TONES`, each with skin, flush, old, freckle and
age-spot stops, plus palm stops if its palms and soles differ from the skin, and `grey` if grey hair should show
less. Then add the group to `GROUPS` in `living_body.gd` with its tone numbers and hair weights, and regenerate both
shaders (living and zombie decay). Existing tone
numbers never move, so bodies already set up keep their look.

## Tested

The shader compiles and renders in Godot 4.5 with the close-up master GLB. Adding each group left the earlier tones
pixel-for-pixel the same, and the renaming changed names only. `living_body.gd` was run on 400 bodies: looks roll
by weight, and `set_look` reaches the shader. This was on a machine without a GPU, using Godot's Compatibility
renderer, which ignores per-instance values; the previews set them per material instead. Still to check in your
project: Forward+ on Godot 4.7.

The rest-position change was checked two ways. At rest, the renders match the earlier ones apart from a few
pixels per body (rounding). Posed by turning bones in Godot (one arm raised, the other forearm bent), the details
now move with the limbs; `preview/living_pose.png` shows before and after. It has not been run with a real
animation yet.
