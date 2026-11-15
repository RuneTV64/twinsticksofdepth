# Twin Sticks of Depth

Godot 4 twin-stick zombie game (the owner works in Godot 4.7, Forward+). Targets: PC, maybe consoles later,
designed for a controller. Forward+ only: no Compatibility renderer, no web or phone builds (owner, 15 Nov 2026). The level is built in code (see README.md);
the character models, shaders and their scripts are in `assets/characters/` and in our claude.ai Artifacts.

## Working with the owner

- Commit and push to the session's working branch. Push to `main` only when the owner says so for that change; it
  has always been a fast-forward. Never overwrite or rewrite main.
- The owner works at their own PC (Windows, PowerShell, Godot 4.7.2) alongside the session, and commits there too
  (the player rig, `player_body.gd`, came from there). Talk to them as being at it: after a push to main, give them
  `git pull --rebase origin main` to run now. Opening the project in Godot can rewrite `.import`/`.uid` files,
  which blocks a pull; commit matching ones to the repo, or have them `git restore .` first.
- Approved assets (pills say Approved): ask before changing them. MaleBody_Muscular is approved and locked;
  MaleBody_Muscular_Skins and ShamblerMale_Muscular were approved on 15 Nov 2026.
- The owner reviews by looking at renders. Show before/after sheets, and say plainly what a render can't show.

## Naming: zombies and shamblers

- **Zombies** is the name for the undead as a whole group.
- **Shamblers** are one kind of zombie: the most common, slow, and they walk straight at you. Other kinds will get
  their own nicknames, with different AI and some different physical features.
- Every zombie is made from a person, so most use the same base body models as the living, in every body type and
  complexion. Late-stage zombies will get a couple of variant models of their own.
- So shared zombie assets get general names (`zombie_decay.gdshader` colors every zombie by Freshness);
  `shambler.gd` is the spawner for shamblers specifically.
- Time passes in the game, with seasons. A zombie's Freshness (see freshness.gd) is meant to move on with it, so
  zombies age through the decay stages into those late-stage forms. Seasonal decay rates (summer fast, winter
  slow) are to be added with the time system, not before.
- Skin tone naming treats everyone the same: no one is labelled by a color word (white, black, brown, red,
  yellow, olive). Living skin tone groups are named by heritage (European, African, Latin American, Asian,
  Middle Eastern & South Asian) and tones get material or pigment names (European: Porcelain, Cream, Fawn;
  African: Umber, Mahogany, Ebony; Latin American: Golden, Copper, Bronze; Asian: Wheat, Honey, Almond;
  Middle Eastern & South Asian: Sand, Caramel, Chestnut).
- Zombies use the same skin tones and looks as the living (skin_tones.js feeds both the living skin shader and
  zombie_decay.gdshader; shambler.gd rolls through LivingBody.roll_look()), so a person keeps who they were when
  they turn. Build types (skinny, husky, obese) are on hold; the body recipe can make them later without new
  shaders.

## Where game design assets live

All game design assets go into our claude.ai **Artifacts**, so they can be shared across devices and pulled into
any chat. That covers models, shaders, asset scripts, previews, design docs and plans. Finished character assets
also live in this repo under `assets/characters/<AssetName>/`, in the form Godot uses (real `.glb`, `.gd`,
`.gdshader`, with Godot's `.uid` and `.import` files; `source/` and `preview/` carry a `.gdignore`). When an asset
changes, update both, and keep them the same files.

- Character assets: the **Godot Assets** artifact, https://claude.ai/artifact/WRBAYq3aDXi9hMi5zS2wzC
  (MaleBody_Muscular, MaleBody_Muscular_Skins, ShamblerMale_Muscular). Find others with the Artifact tool's
  `list` action.
- Before starting asset work, check the Artifacts first. Work done in an earlier chat may only be there, not in git.
- Layout inside an asset artifact: `files/<AssetName>/`. Models are `.glb.b64.txt` (base64 of the .glb, since
  artifacts can't hold .glb). Godot scripts and shaders are `.gd.txt` / `.gdshader.txt`, Python `.py.txt`. The
  recipe that builds them is under `source/`, preview renders under `preview/`, plus a README.md. List every file
  on the page with a short "what it is", and keep the asset's status pill (approved / in review) current.
- When an asset changes, republish to the same artifact URL (read it first) instead of making a new one.

## Art direction

- Art style: "8-shade 3D-Pixel" (the eight-shade-3d-pixel skill): 8-shade banded ramps, Bayer dither.
- "Dark and gritty" is the game's setting and themes, not a rule that every asset is dark. The mood comes from
  places, lighting and story; assets get natural colors (a farmland area can be pretty). Don't darken palettes
  just to look gritty: dead bodies go pale first and only darken as they rot, for example.
- Zombie wounds are painted, not modelled. A wound is a real hole in the skin with one inner surface under it, and
  the shader paints the anatomy on that surface (ribs, organs, bone; in the torso and head from the anatomy map)
  and smears it with blood, clots and muck: reds and darks inside, not a clean anatomy model. Don't add bones or
  organs as models; it costs too many triangles. Keep wounds big.
- Painted insides must have depth and sit where the real anatomy is. The anatomy map stores how far in each bone
  and organ is, and the shader follows the line of sight through it, so bones stand in front of organs and slide
  across them as the view moves; limb bones are traced as round shapes, the neck stump as open tubes. Check the
  layout against real anatomy (for example, ribs slope down to the front and are evenly spaced there, not bunched).
- Colors of the insides follow real decay too, and darken with the body: nothing inside a blackened corpse stays
  fresh-colored. Organs and raw flesh keep their own colors only while fresh, then go dusky, grey-green, dark
  olive-black, and dried black-brown. Bone is never white in a body (white is sun-bleached bone): ivory and pink
  when fresh, yellow and greasy, stained dark by the rot, tan-brown when dried. Rib cartilage is off-white, not
  the blue of anatomy diagrams.
- Nothing hangs off the zombie model. Spilling guts, blood, and bits of brain and intestine are live effects in
  the game (pixel particle effects), not part of the character model. Parts that come off are separate pieces.
- When something should look or move like the real thing, find out how the real thing behaves first and imitate
  that (for example: how a dead limb moves, what color rotting bone is).

## Cut-off pieces, and what comes next

- When a forearm, lower leg or head comes off in play, `shambler.gd`'s `dismember(slot, impulse)` throws the part
  as a `ShamblerPiece` (`shambler_piece.gd`) from `ShamblerMale_Muscular_Pieces*.glb`: built by `buildPiece()` in
  shambler.js from the part as it looked (Intact/Rotted, or a Destroyed head), cut on the same line as the stump
  (`offSide()`), with its own small skeleton (wrist and fingers, ankle and toes) and its joint ranges and collision
  capsules in the piece node's extras.
- Pieces move like dead limbs by decay stage: Fresh limp (with a few seconds of twitching), Rigor locked in place,
  Bloated/Putrid loose and floppy, Dried stiff. It's a light verlet motion on the joints, not a ragdoll.
- Pieces rot with their own Freshness and then fade away (`zombie_decay_piece.gdshader`'s `dissolve`). The timing
  (`piece_rot_seconds` 180, `piece_fade_seconds` 3) is a stand-in.
- **Next:** the owner has an in-lore mechanic for how pieces (and probably bodies) go away, to be designed in a new
  session. What the owner has said so far (15 Nov 2026):
  - Rotting corpses draw maggots, flies and, eventually, worms. These are the agents that eat and clean up the
    rot, and they can also be gathered as resources.
  - Maggots turn into swarming flies, which fly away when the meat is gone.
  - When the worms are done, they crawl into the ground.
  Ask the owner for the rest before building (for example: when each one arrives, how they're gathered, what
  they're worth, whether they eat whole bodies or only pieces). The hooks are ready: `piece_auto_fade` off makes a
  piece only send `rotted_away`; `piece_rot_seconds` 0 stops its own rotting so the mechanic can drive
  `piece.freshness.value`; `piece.fade_away()` fades one out. The decay shader already draws wriggling maggots in
  wounds and insides from the Bloated stage through Putrid; those could become the mechanic's maggots.
- Later, when asked: blood and bits as particles; faces (then a jaw that drops on the head piece, the pierced-brain
  head death, and a destroyed face); build types; seasonal decay rates with the time system.

## Zombie animations and abilities (built 15 Nov 2026, in review)

- Shamblers in the game use the ShamblerMale_Muscular model: `enemy.gd` makes a `ZombieBody` (`zombie_body.gd`),
  which loads `ShamblerMale_Muscular_mid.glb` with `shambler.gd` on it and the decay shader
  (`zombie_decay_piece.gdshader`, for its `dissolve`: zombies dither away out of the player's view).
- Animation follows the owner's `player_body.gd`: no clips, every bone posed in code each tick from the Enemy's
  state, on the same 72-bone skeleton. One script covers every missing-limb mix and every decay stage. Review sheets:
  `ShamblerMale_Muscular/preview/zombie_anim_*.png`, made by `source/zombie_anim_preview.gd` (+ `zombie_anim_sheet.py`).
- Decay stage changes the movement: the more rotted, the more dragging (a bad leg), lurching and stumbling; rigor is
  stiff and jerky; fully rotted zombies shed parts on their own (`dismember()`).
- Abilities: **crawl, grab, bite.** Grab, then bite: a zombie with at least one hand grabs and holds the player
  (slowed; two hands nearly root), then bites until the player shoves it off (Ready, facing it) or struggles free
  (wiggling the move input); two hands hold harder than one. Zombies with no hands can't grab; they lunge and bite.
- Crawl: zombies missing a leg always crawl. Any zombie can be knocked down to crawl (hard hits, shoves) and gets
  back up. (Crawling under obstacles waits for low obstacles in the level.)
- Heads: a headshot kills and sometimes takes the head off (decapitation is the stand-in until the pierced-brain
  death has its look). A severed head is still alive and can still bite (`severed_head.gd`): a very low chance,
  by accident, when the player steps right by it.
- Stand-ins to revisit: limb loss from any non-lethal hit (12%), knockdown chance, corpse lies 30 s then fades,
  all the timings and damage (exports in `enemy.gd`, held/struggle in `player.gd`).
- The decay shader lights in view space; `zombie_body.gd` points its `key_dir` at the level sun as the camera sees
  it (the camera never turns), so zombies are lit like the player. If the camera ever rotates, update it per frame.
- Per-object shader values: the renderer reserves a block of 16 for every mesh that has any instance uniform set,
  hidden or not (measured in 4.7.2). So `shambler.gd` puts the skin and its values only on the 6 or 7 parts shown,
  and `ZombieBody.new_zombie()` builds a fresh shambler on respawn: about 100 values per zombie. Forward+ has 65,536
  by default (about 650 zombies; raise `rendering/limits/global_shader_variables/buffer_size` for more). A
  dismembered part's old mesh keeps its block until respawn. (Compatibility would only fit about 40; it isn't used.)
- Physics is Jolt (project setting, 15 Nov 2026). Owner's crowd test (F5/F6/F7, readout top right) on an RTX 5070,
  126 zombies piled on the player: Godot physics 33 FPS, physics tick 20.3 ms (posing 5.2, zombie AI+movement 7.2);
  Jolt 66 FPS, 16.4 ms (posing 5.4, AI+movement 4.7). CPU-bound, not GPU.
- Zombies don't collide with each other (mask 1|2): they steer apart (`enemy.gd` `_separation()`, a 1 m grid rebuilt
  once per tick; soft push inside `personal_space` 0.75 m, hard push out of `min_gap` 0.55 m; neighbours looked up
  every other tick, half the crowd each tick). The dissolve is only re-sent when it changes. Cloud bench, 226 zombies:
  zombie AI+movement 20.2 -> 13.6 ms/tick (fade 5.1 -> 1.6, separation 2.5, move_and_slide 5.3, think 3.2); posing
  ~19 ms/tick is now the biggest cost.
- Owner's PC after that (RTX 5070): 126 zombies 76 FPS, physics 14.7 ms; 176 zombies fell to 13 FPS because the
  physics tick passed 16.7 ms (21.2) and Godot ran several ticks per frame to catch up. So posing left the physics
  tick: `Enemy._process()` poses the body once per drawn frame, and `ZombieBody` poses by distance from the player:
  every frame within `full_rate_within` 6 m, 30/s to `half_rate_within` 14 m, 20/s beyond, 10/s out of view, each
  zombie offset. Cloud bench, 226 zombies: posing work 467 -> 175 ms per second; physics ticks 23.6 -> 51.5 per
  second. The readout shows posing per frame and zombie AI per tick. Still to find: about 6-9 ms of the owner's
  physics tick that grows with zombies but isn't zombie AI (guess: skeleton updates, Jolt). C++ posing once poses
  settle. Test harnesses that pose zombies by hand must `set_process(false)` as well as physics.
- Owner's profiler (226 zombies): `_update_fade` was most of the script time (setting `_visual.visible` etc. every
  tick even when unchanged); now Enemy only sets engine properties when they change, and script time fell ~56%.
  Then: ZombieBody caches parts/freshness/rigor once a frame (re-read when parts change); zombies beyond
  `half_rate_beyond` 14 m that are only walking/crawling think and move every other tick covering two (cloud, crowd
  walking in from 21-35 m: zombie AI work -27%, physics keeps 60 ticks/s); close-up posing is capped at 60/s.
  The cloud machine's numbers swing a lot between runs; compare per-second work, and trust the owner's PC.
- Owner's rule (15 Nov 2026): don't track slow things every tick. A zombie's decay and parts are worked out once
  (`ZombieBody.refresh()`: at spawn, when a part comes off, if Freshness changes) into fields (`stiff`, `drag`,
  `walk_mult`...) that posing and AI read; nothing re-derives them per tick. Cut-off pieces rot in `rot_step` 1 s
  steps, not every frame. Build later time-based systems (world time, seasons, the clean-up lore) the same way:
  event-driven or on a slow clock. Owner's PC then: horde walking in, 226 zombies 77 FPS; piled on the player, 28 FPS
  (posing 11.4 ms/frame: everyone is within 6 m, so all pose at 60/s).
- Far zombies use the low model: `ZombieBody` swaps mid/low by distance from the camera (`low_beyond` 21 m,
  `mid_within` 19.5 m; on screen zombies are 15 to 29 m away), at most 2 swaps a frame. Godot's automatic mesh LODs
  are kept off (`lod_bias` 64), as on the player: the shader needs the per-vertex data.

## Character shaders and models: how they are built

The living skin shader and the zombie decay shaders are generated, not hand-written. Everything is in the Godot
Assets artifact and in `assets/characters/` (the recipe under each asset's `source/`; see each README).

- A Godot project needs, for a shambler: the three `ShamblerMale_Muscular*.glb`, `zombie_decay.gdshader`,
  `shambler.gd`, `freshness.gd`, `living_body.gd` and `anatomy_map.gd`; for its pieces also
  `ShamblerMale_Muscular_Pieces*.glb`, `shambler_piece.gd` and `zombie_decay_piece.gdshader`. For a living body:
  the three `MaleBody_Muscular*.glb`, `body_living.gdshader` and `living_body.gd`.
- Details painted by place on the body (freckles, hair, rot, grime, the insides of wounds) read each vertex's rest
  position from `CUSTOM0`, not `VERTEX`, so they stay on the skin when limbs move. Any new body model must export
  it (glTF `TEXCOORD_2` = rest x, y; `TEXCOORD_3` = rest z, rest normal y), as `export_glb.js` does.
- To rebuild the shambler, in `ShamblerMale_Muscular/source/` (with MaleBody_Muscular's `male_body_muscular.js`
  and `rig.js` beside it): `node gen_anatomy_map.js <out>` makes `anatomy_map.gd` and `anatomy_consts.json`;
  `node gen_decay_shader.js zombie_skin.gdshader zombie_decay.gdshader zombie_decay_piece.gdshader` makes both
  shaders (it reads `anatomy_consts.json` and `skin_tones.js`); `node export_shambler.js <out>` makes the shambler
  and pieces GLBs. Change the anatomy in `anatomy.js`, the wounds, cuts and pieces in `shambler.js`, the colors
  in `gen_decay_shader.js`. After a change, check that what shouldn't change is byte-identical.
- Still unchecked: Forward+ on Godot 4.7, a real animation, and the cost of the depth painting and of the pieces on
  a real graphics card.

## Testing Godot assets in a cloud session

No Godot is installed. The official Linux build (4.7.2, the owner's version, works) downloads from GitHub
releases and runs under `xvfb-run` with `--rendering-driver opengl3`; there is no Vulkan, so no Forward+. That software (Compatibility) renderer skips the linear->sRGB step
and ignores instance uniforms, so test harnesses should output palette colors directly
(`ALBEDO=pow(c,vec3(2.2))` -> `ALBEDO=c`, `instance uniform` -> `uniform`) and set per-shambler values per material.
Say so when reporting results, and that Forward+ on 4.7 still needs a check. Test in a scratch copy of the repo,
not the repo itself (importing writes `.godot/` and may touch project files). The preview harnesses are in each
asset's `source/` (`decay_preview_render.gd`, `render_previews.sh`, `pieces_preview.gd`, `pieces_motion.gd`,
`zombie_anim_preview.gd`). The software renderer runs out of per-object shader values past about 20 shamblers, so
render a few at a time; the game level itself renders black there (its lighting needs a check on real hardware).
