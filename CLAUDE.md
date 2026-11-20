# Twin Sticks of Depth

Godot 4 twin-stick zombie game (the owner works in Godot 4.7, Forward+). PC only, mouse and keyboard only (owner,
20 Nov 2026: there is too much to build to keep a controller working too; maybe later). Design and tune new
controls for mouse and keyboard; don't spend time on controller support. The controller bindings and stick aiming
were stripped out the same day at the owner's request (`input_setup.gd`, `player.gd`, `hud.gd`, `main.gd`).
Forward+ only: no Compatibility renderer, no web or phone builds (owner, 15 Nov 2026). The level is built in code (see README.md);
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

## Camera

- The camera never turns (owner, 20 Nov 2026): it stays locked looking north, and only pans. No rotation of any
  kind, snapped or free. Code may go on assuming a fixed view (lighting, mouse-to-world mapping).
- Cutaway (built 20 Nov 2026, untested on the owner's PC): whatever stands between the camera and the player is cut
  open, with a dithered edge, so the player is never hidden behind a wall or a tall building. The feet of walls
  (up to 0.95 m) stay. `cutaway.gdshaderinc` has the test (`cutaway_hidden(world_pos, FRAGCOORD.xy)`); any spatial
  shader takes part by including it and discarding. `cutaway.gd` (`Cutaway`, one node in the level) sets three
  project-wide shader globals once a frame (`cutaway_focus`, `cutaway_view`, `cutaway_shape`, declared in
  `project.godot` under `[shader_globals]`). The test level's walls, crates and doors use `Cutaway.solid(colour)`
  (`level_solid.gdshader`, one shared material per colour). V switches it off and on. The cut edge isn't capped
  (you see through the wall, not a filled section), and cut parts stop casting shadows.
- The buildings themselves are for another day (owner): custom modular building pieces in the 8-shade pixel look.
  Their shaders must include the cutaway.
- Render: `tools/preview/cutaway.png` (off and on, behind a one-storey wall and behind a tall block), made by
  `tools/cutaway_preview.gd`.

## Where the game is going (owner, 20 Nov 2026)

The aim is something like Project Zomboid with its own, better flavour. Two places the owner means to beat it:

- Time. Zomboid is great for about the first six in-game months; after the first winter the years just repeat.
  This game should keep changing as time passes. (Already planned: seasons, zombies rotting through their stages,
  the clean-up lore.) Nothing designed yet beyond that.
- Losing a character. Death stays permanent, but the player shouldn't always start from a blank slate. Idea:
  special starting builds ("character slates") are unlocked by getting a character's stats or skills a certain
  way AND finding a particular thing (a hat, a badge) at a particular place in the game. Example, tentative: level
  the Electrician skill and meet the criteria, and a later character can start as one. So the character is lost
  but the progress toward a kind of start is kept, and players are more likely to keep going after a death.
  Not designed yet: skills don't exist, and the unlock criteria, items and places are open. Ask before building.
- Order of work as the owner sees it: loot is more important than buildings; modular building assets come later;
  spawning and how the horde moves, and the turning-undead mechanic, are also still to come.

## Loot (being designed with the owner, 20 Nov 2026; nothing built)

The owner's decisions so far. Sketch of the loot screen: `tools/sketches/loot_screen_sketch.png` (its HTML beside
it). The owner said to sketch before building anything; wait for their critique of the sketch.

- Carrying: without a bag you have weighted slots (hands, belt, pockets, and so on). Bags and containers are a
  full grid.
- Searching drawers is a minigame of its own: the screen shows the actual drawer as a grid and you rummage in it.
  Half the menu is your storage, the other half the thing you are searching. It should cost you your view, so
  the player has to keep looking over their shoulder. First search takes time and is exposed; a container you
  have already searched opens at once.
- Loot on zombies comes from tables by who they were: gender, ethnicity, where they are, and profession (told by
  what they wear), and by how decomposed they are: damaged and ruined items turn up more on bloated and putrid ones.
- Food rots at about Zomboid's pace, but the game is more forgiving: rotten food still gives seeds and makes
  compost. Farming is to be more accessible. Compost feeds soil quality, which is tracked across seasons.
- A game day is long: 2 to 4 real hours. It is a slow game; eating and the like must not crowd out the fighting
  and looting.
- First items: mostly household things; two guns (one small calibre, one high-powered); some clothing; helmets
  and the like for head protection; food and water.
- Ammunition and loading weapons as in Zomboid (magazines, rounds), but smoother and far less menu-driven. The
  owner wants to design this together: propose, don't just build.
- Owner on the sketch (20 Nov 2026): ALT to look behind you is fine as a default key. The drawer uncovers by
  column, and the drawer's own background is the meter: it fills, and as each column fills the items in it
  appear. A hurry key fills it faster and makes noise; skill makes searching more efficient. Hurrying and steering
  with the mouse are combined: the mouse picks which column fills, the hurry key speeds it. Things hidden under
  other things (layered clutter) is wanted: "exactly what I was thinking". Wording: "some clothes have pockets";
  storage mostly comes from containers and backpacks, pockets take small items.
- Open question from the owner: how do you empty the chamber without firing, and take rounds out of a magazine?
  Claude proposed a "make safe" key and dragging rounds out of the gun or magazine in the inventory; not agreed yet.
- Claude's earlier layout, which the owner answered against: items are records (weight, condition, category);
  container contents are rolled when first opened; time is applied on opening (spoiling, picked over by others);
  nothing respawns in a cupboard; keepsakes unlock starting builds.

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
- Posing budget: `ZombieBody` ranks live zombies by distance from the player 4 times a second; only the nearest
  `full_rate_count` (30) within 6 m pose at 60/s, the rest of the crowd within 14 m at 30/s. Zombies reaching for,
  holding, biting or lunging at the player always pose at 60/s. A 226-pile: 83 -> 30 zombies at 60/s (all 226
  within 6 m would be about 13,600 -> 7,700 poses/s). The cloud machine runs at ~7 FPS, below every posing rate,
  so it can't show rate limits; count rates (`rate_snapshot`) instead of timing them there. Owner's PC with it:
  226-zombie pile 28 -> 45 FPS; horde walking in 77 -> 98 FPS.
- Merged meshes: `shambler.gd` (`merge_parts`, on) shows the parts as one merged mesh (one surface, same skin), so a
  zombie is 1 draw call (+ shadow) and 16 per-object shader values instead of 6-7 meshes. Merged meshes are cached by
  model and mix of parts and shared; a new mix takes ~1-4 ms to build once (dismembering may build one). 126
  zombies: draw calls 2,370 -> 558, zombie meshes 756 -> 126; even Compatibility no longer overflows its shader
  values. Exact: same vertices, triangles and data channels as the parts. Owner's PC: 226 piled 45 -> 80 FPS, draw
  calls 4,402 -> 860; horde walking in 98 -> 139 FPS. It dropped to ~44 FPS while panning the camera: every
  mid/low swap rebuilt the zombie and called `load()`, which costs ~1 ms per call even for a loaded file. Now the
  model files are loaded once (`ZombieBody._scene()`), and a swap is `shambler.use_model()`: same skeleton, bones and
  bind poses at every level (checked), so only the merged mesh changes (~0.02 ms). Never call `load()` per frame or
  per spawn; keep the resource.
- Panning drop (owner's PC, 226 piled: ~77-80 FPS, ~50-55 while moving the cursor): the look crosshair roams up to
  10 m and the camera follows it, so panning swept the crowd back and forth across the mid/low line (cloud sim:
  80 swaps/s), each swap making the graphics card rebuild that zombie's skinning buffers. Now detail is measured
  from where the camera rests over the player (not the panned camera), checked 4 times a second per zombie, at most
  2 swaps a frame: panning causes no swaps (cloud sim 80 -> 10/s, the same as with the crosshair still). Owner's PC
  with it (17 Nov 2026): 226 piled, 92 FPS (was 77-80), posing 3.8 ms/frame, physics 6.3 ms, 927 draw calls, 8.1M
  triangles; while panning it dips only to ~86 and holds. Panning drop solved. Remaining crowd ideas, not needed
  now: C++ posing once poses settle; the unaccounted engine time (skeleton updates) if hordes grow past ~250.
- Less robotic (owner, 17 Nov 2026: "quite robotic"). The chest, neck, head, upper arms and forearms ride on damped
  springs (`_spring()`, implicit steps so stiff springs stay stable; tuned by decay in `_spring_tune()`: rigor stiff
  and damped, bloated/putrid floppy), kicked by the body's own speeding up, slowing, turning and footfalls
  (`_kick_springs()`), plus a twitch every few seconds. Each step gets its own length, pace and sideways lurch, with
  halting steps more often the more he drags. Reaching arms paw in uneven arcs with soft elbows, limp wrists and
  grasping fingers; the head turns toward its target. Springs run only in view within 14 m (`springs` to switch
  off): about +38% per posing there. Motion clips: `source/zombie_anim_clip.gd` + `zombie_anim_gif.py`
  (before/after GIFs in `preview/zombie_motion_*.gif`); stills can't show motion.
- Lock-on (sticky aim, 20 Nov 2026, untested on the owner's PC): `player.gd` `_lock_pull()`. Once the mouse rests,
  a crosshair within `lock_on_mouse_radius` 1 m of a living enemy the player can see settles onto it (dead centre
  inside `lock_on_core` 0.5 m, fading to nothing at the radius, so it never sticks) and follows it; moving the
  mouse takes it off. Exports in the Lock-on group. (The stick version went with the controller.)
- Debug keys: G adds a test gunner at the crosshair (Shift+G removes them); T adds a raider (Shift+T removes those);
  V switches the cutaway off and on.
- Debug keys: F1 help, C character page, F3 input check, F5/F6/F7 crowd test, L all zombies on the low model. Don't bind F8 (the
  Godot editor's Stop Running Project; it closes the game even from the game window), nor F10/F11/F12 or other
  editor debugger keys.
- Far zombies use the low model: `ZombieBody` swaps mid/low by distance from the camera's rest point over the player
  (`low_beyond` 21 m, `mid_within` 19.5 m; on screen zombies are 15 to 29 m away) with `shambler.use_model()`,
  checked 4 times a second, at most 2 swaps a frame. Godot's automatic mesh LODs
  are kept off (`lod_bias` 64), as on the player: the shader needs the per-vertex data.

## Cover system (built 20 Nov 2026, in review; untested on the owner's PC)

Designed with the owner on 20 Nov 2026 for raiders and other players as well as zombies. Rule: to see is to be seen.
Design doc: the **Cover System Design** artifact, https://claude.ai/artifact/VpVzHHYeFH4q8hfbBtyckg (a Claude Docs
document; keep it in step when the rules change).

- `cover.gd` (`Cover`): no hand placement. Every solid box on the ground (`main.gd` `_box`) is registered; each side
  0.6 m or longer is a cover face. Top up to 1.5 m is low cover (crates, window sills, cars), taller is high. Wall
  pieces in a line join up, so you slide along a wall and under its windows.
- Controls (`player.gd`, Cover exports): Cover is Space. Tap = slide into the nearest cover (toward the move
  stick) or leave it. Hold = go to the cover spot the crosshair marks (cyan ring; read before lock-on shifts the
  crosshair); the crosshair recentres on arrival. Pushing firmly away leaves; a dash or a grab also takes you out.
  Cover + pushing into low cover vaults it (window sills too).
- Roll (owner, 20 Nov 2026): two quick Cover taps (within 0.28 s) when not in cover roll you about 3.2 m the way
  you are moving, or the way you face if standing still. An ordinary person's roll (owner: "not a super hero"):
  you turn into it, it is a burst that picks up and dies away over 0.55 s, you come up facing the way you rolled,
  and then spend 0.45 s getting to your feet (no moving, turning to your aim or attacking) before control comes
  back. It costs 32 stamina, a third of an ordinary bar, and needs 60% of that to start. Nothing can grab you while
  going over; while getting up, anything can. Once up you turn round to your aim at `roll_turn_speed` 9 rad/s,
  with the mouse too (owner: mouse aim, normally instant, is eased here). Not while held, winded, or standing on bodies. The first tap still
  acts at once (it may start a slide to cover; the second tap drops that and rolls). `player.gd` Roll exports;
  the tumble and the getting up are in `player_body.gd` (two moments of the tumble are on the cover pose sheet).
- Three states (`cover_mode`):
  - hunker: hidden. Shots that cross the cover are stopped. You see only `cover_hunker_sight` 4 m all round (the
    fog closes in, enemies beyond fade).
  - peek: hold the stick toward low cover, or along it at an open end (low or high), for 0.4 s. Normal view; enemies
    see you; a shot crossing the cover has a 15% chance to hit, and it is always a head hit.
  - pop: Ready held. Near an open end you lean out round it, otherwise you stand up over low cover (high cover away
    from an end has no angle). Hit as normal.
- Head hit on the player: 75% of full health (owner, 20 Nov 2026, after looking at how Project Zomboid and its
  Bandits mod do it). On zombies a headshot is still a kill.
- Blind fire: attack without Ready in cover fires over low cover or round the near end of high cover, toward the
  crosshair, 14 degrees either way, slower, no aimed bonus.
- Shots (`projectile.gd` `wall_hit`): low cover never stops a shot by itself, it goes over; someone hunkered behind
  it is protected by `Player.take_shot()`. Standing behind low cover without being in it gives no protection.
- Zombies never use cover. One you are hidden from notices you at 0.35 of its range; one that was chasing goes to
  where it last saw you. They climb over low cover.
- Poses are in `player_body.gd` (squat, peek, lean, gun up for blind fire, vault). Review sheet:
  `tools/preview/cover_poses.png`, made by `tools/cover_pose_preview.gd`.
- Zombies climb low cover (see Zombies over cover). Raiders use cover and are protected by it (see Raiders).

## Zombies over cover and over each other (built 20 Nov 2026, in review; untested on the owner's PC)

The owner asked for zombies to shamble over cover and, sometimes, to get over walls by piling up, like the film
World War Z but mindless: an accident, not a plan. All of it is in `enemy.gd` (the Climbing exports).

- Pressing: a zombie walking into something solid counts how long (`_press_t`). After 0.6 to 1.6 s (longer when
  stiff) it goes over if the top is within `climb_reach` 1.5 m of its feet (0.6 m with no legs), the thing is no
  deeper than 2.6 m, and there is room to land inside the world (`Cover.bounds`). So every piece of low cover,
  window sills included, is climbed by one zombie alone.
- Going over (`state` "climb"): a scripted move, on its belly over the top and off the far edge, 2 to 4 s; it lands
  knocked down and gets up. A drop of 1.8 m or more can shake a limb off a rotten one.
- Only where zombies are dense (owner, 20 Nov 2026). Density is the number on their feet within about 3 m
  (`_density()`, from the crowd grid, looked at twice a second by zombies that are pushing). Under 12, nothing.
- The heap (a couple of dozen): a zombie that has pushed for 2 s at something it can't get over, with 12 or more
  standing round it, has a 20% chance every half second of going under them (`state` "heap"). The fallen don't count
  as standing, so a small crowd stops once enough have gone under. Zombies that die pressing or on a heap join it
  as corpses until they fade. Heaps are kept by 0.8 m cell (`Enemy._heap`), 4 live bodies deep (0.4 m each).
- Everyone walks on the bodies: `perch` is how high a zombie (or the player) stands; only the visual is raised, the
  physics body stays on the ground. A step up of more than 0.85 m stops it. One stuck for 3 s shuffles sideways
  along what stopped it (`mill_speed`), which is how it blunders onto the heap. From 1.1 m up, the top of a 2.6 m
  wall is in reach and it goes over. The one on top drags itself out after 3 s with no crowd round it.
- Crushing (hundreds): a full heap that another zombie goes under crushes its bottom body. That zombie is freed for
  good (owner: no respawn) and becomes 0.15 m of the corpse pile in that cell: `corpse_pile.gd` (`CorpsePile.it`,
  one node for the level, made on the first crush). The pile stays and compounds; it stops at `max_height` 7 m,
  about two and a half storeys (Claude's pick; the owner said 2 to 3). It is one mesh with a gore shader and a
  stain round its foot, rebuilt at most twice a second.
- Still alive in it: 1 crushed zombie in 8 is trapped alive (see Look, below, for what shows). Within 1 m it has a
  35% chance a second to grab whoever is there (player or raider): a 0.7 s stagger, and half the time a 10 damage
  bite.
- People in the press: when a zombie goes under within 1.6 m of the person it was reaching for, that person takes
  8 damage (`take_crush`). Raiders don't walk on piles yet.
- The player on bodies (`player.gd`, Corpse pile exports): 0.4 speed, no run or dash, stamina drains, an 8% a
  second chance of losing footing (more when hurried, shaken or panicked), composure drains, eyes are higher so
  you see over more. At a wall whose top is within 1.6 m of your feet, Cover while pushing into it climbs over.
- Finishers (owner, 20 Nov 2026; `player.gd`, Finisher exports): crosshair on the head of a zombie that is down
  (crawling, knocked down, in a heap), within 1.7 m, then attack. Unarmed: stomp. Gun, weapon away: rifle butt
  (1.4 times a stomp). Blows by Strength: a blow is STR/14 of a sound skull, so 14 = one blow, 10 = two, 6 =
  three; rot softens the skull (`Enemy.take_stomp`). Gun, Ready: one round to the head, certain and loud. The same
  works on a trapped one in the pile. Lock-on and the prompt go to the head of a downed zombie. The stomp has a
  leg pose in `player_body.gd` (not rendered for review yet); the butt uses the bash pose.
- Cloud runs with the player behind the wall. One storey (2.6 m): 12 zombies, nothing; 16, a few go under, none
  over; 24, 11 over in a minute in one run and 3 in another; 200, 90 over in 30 s and 27 crushed. A 9 m wall, 250
  zombies, 150 s: 145 crushed into a 3 m pile, 105 left, 10 to 20 trapped alive.
- Zombies don't look for heaps or ramps; they only ever walk at their prey. The climb and the heap use the crawl
  pose. Nothing is done per tick when there is no heap and no pile.
- Look (owner, 20 Nov 2026: the first pictures "did not look good at all"; it has to be gnarly, with bones, blood,
  limbs, ligaments and sinew, built from modular pieces picked at random; and zombies on a heap were too far apart,
  "a cheer routine"):
  - `gore_tiles.gd` (`GoreTiles`) draws, by code, a sheet of 24 tiles (40 texels, one per 0.8 m cell): rib cages,
    long bones, skulls, pelvises, spines, hands, torn limbs with the bone out of the stump, gut, sinew, slabs of
    meat, skin, fat, pooled blood. Each keeps clear of its own edge, so any fits any. The pile's shader lays pulp
    under them and picks a tile, a turn and a flip per cell; steep faces are painted from the side. Change the
    shapes or the colours there (the palette is in both files). Sheet: `tools/preview/gore_tiles.png`.
  - Real pieces in the pile: a crushed zombie leaves up to three of its own limbs or its head (`ShamblerPiece`,
    frozen, with its skin and rot) half-buried where it went under; pieces the pile rises over are removed; at
    most 140 show.
  - The trapped ones are those pieces (owner: the player must not be able to tell): a live one is an arm (or a
    head, which only bites) that looks like any other and doesn't move until it grabs. Any piece can be stomped
    or shot; the game then says whether it was alive.
  - The pile slumps: a body landing on a spot 3 or more higher than a neighbour slides to the neighbour, so it is a
    mound, not a pillar. Its mesh points are the cell middles, so the drawn surface is exactly `height_at()`.
  - Heaps are packed: 0.24 m a body, 6 deep, each sprawled at any angle on front, side or back, clawing where it
    lies; zombies on bodies scramble on all fours (`zombie_body.gd`: prone when `perch` > 0.3) and crowd to half
    their usual spacing. A body with 3 or more lying on it has a 12% chance every half second of being crushed.
  - Torn apart: going under (20%, one limb), dragging itself out of a heap (30% a limb, up to two), and going over
    a wall off a heap (25% a limb, up to two) cost limbs. Past 50 loose pieces lying about, new ones aren't left.
  - With these: 24 zombies at one storey, 3 to 6 over in 90 s, 2 or 3 crushed; 250 at 9 m, about 175 crushed into a
    1.1 m mound that spreads wide, 75 left, 17 trapped alive.
- Review pictures (software renderer): `tools/preview/zombie_heap.png` (40 at one storey),
  `corpse_pile.png` (250 at 9 m), `corpse_pile_alone.png` (the same pile with the zombies left out),
  `gore_tiles.png`; made by `tools/zombie_heap_preview.gd` (N, SECONDS, H, HIDE, ZOOM) and
  `tools/gore_tiles_preview.gd`.
- Owner on the pile's look (20 Nov 2026): "good enough for now", but it reads as a pile of skeletons. When it is
  next worked on: far more meat, guts and organs than bone, ooze and rot fluids, and a mix of states, since some
  bodies went in freshly turned and some long rotted (the tiles only vary bone colour and a few flesh colours now).
- To come (owner): how zombies spawn and how the horde moves; the turning-undead mechanic; the pile's clean-up
  (the maggots, flies and worms lore).

## Character sheet (built 20 Nov 2026, in review; untested on the owner's PC)

The owner wants stats that cross The Sims with a zombie RPG: like Zomboid, with its own flavor. First version, from
a list of "the human experience as stats" the owner brought; the picks below are Claude's and are up for critique.

- `character_sheet.gd` (`CharacterSheet`): the Player has one (`player.sheet`); raiders and other players should too.
- Seven attributes, 1 to 20, 10 = an ordinary adult: STR, DEX, END, CON, INT, WIS, CHA. Wired: STR (load, barging,
  punches, shoves), DEX (aimed damage, headshots, reload, blind-fire spread), END (stamina, regen, top speed), CON
  (health, healing), WIS (all-round awareness, keeping composure). INT and CHA are shown but do nothing yet
  (skills, crafting, people). `CharacterSheet.GOVERNS` / `LATER` say what each does and is meant to do.
  `player.recompute_stats()` turns them into numbers; at all 10s the game plays exactly as before.
- Needs (the Sims side): food, water, rest, 100 = satisfied. They bring staged conditions (Hungry, Very hungry,
  Starving...) but don't run down yet: `needs_rate` is 0 until there is a clock and things to eat and drink.
- Composure, 100 calm to 0 panic: zombies within 6 m and being held wear it down, damage knocks it, quiet brings
  it back (twice as fast hunkered in cover). Shaken under 50, Panicked under 20: worse aim, wilder blind fire.
- Fight-or-flight (a trait every person has): grabbed or hurt, 8 s of Adrenaline (+10% speed, effort costs 40%
  less, Hurt ignored), then a 15 s Crash (slow stamina regen); it can't hit again for a minute after.
- Conditions also come from health (Hurt under 50%, Badly hurt under 25%: slower, worse aim; new, the game had no
  penalty for low health), load (Overloaded) and Winded. They are rebuilt 4 times a second on the sheet's slow
  clock (`Player._tick_timers`), into multipliers the Player reads (`speed_mult`, `aim_mult`...).
- The page: C. PgUp PgDn picks a row, - = changes it (test
  editing: this becomes levelling and eating). Conditions also list at the right edge of the screen. Render:
  `tools/preview/character_page.png`.
- Not built: picked traits (good and bad, at character creation), skills and XP, food and drink, sleep, the clock,
  body temperature, caffeine and other consumables, soreness, clothing and footwear effects.

## Raiders (built 20 Nov 2026, in review; untested on the owner's PC)

The owner asked for raiders made from the existing player model and skin layers, with AI.

- `raider.gd` (`Raider extends Enemy`, kind "raider"): being an Enemy means the player's shots, punches, shoves,
  bash, lock-on and composure threat all work on them unchanged. It overrides everything zombie about Enemy.
- Body: `raider_body.gd` (`RaiderBody extends PlayerBody`): the MaleBody_Muscular mid model from
  `assets/characters/` (it has the rest positions) with `body_living.gdshader`, one shared material, a look rolled
  per raider with `LivingBody.roll_look()`. `player_body.gd`'s `animate()` now takes anyone with the Player's state
  fields, so raiders have every player pose, cover included. They carry the same box gun. Nothing else marks them
  as raiders yet (no clothes exist): they look like the player with a different skin.
- Each has a `CharacterSheet` with attributes rolled 8 to 12: CON sets health (60 at 10), END speed, DEX aim;
  being hurt drops composure and spoils their aim for a while.
- AI (`mode`): idle (on watch, sees 26 m in a 150 degree cone, 4 m all round; comes to gunshots), fight, search
  (goes to where it last saw or heard you, looks about, goes home), return.
- Fighting: `_pick_cover()` finds cover between it and you within 12 m, with a clear straight walk there and a
  clear line to you once popped out; then it cycles hunker (reloads) -> peek -> pop out, aim 0.55 s, 1 to 3 shots
  -> hunker. No cover: fights in the open, sidestepping. Within 1.5 m it clubs you (your guard shoves it off).
  Lost you for 4 s: two blind shots at where you were, then a flank (cover your own cover doesn't shield you
  from), and after 12 s it comes looking.
- Cover is the same rule both ways (`Raider.cover_result()`, read by `projectile.gd`): hunkered, your shot across
  its cover is stopped; peeking, 15% it hits, and that is a kill; popped out, a normal hit. A hunkered raider can't
  see you and isn't drawn (it pops in and out of view; there is no fade on the living shader).
- Shots: 12 damage, 5 degrees either side at DEX 10. Three raiders took a player standing in the open at 14 m
  from 100 to 4 health in 10 s (cloud run). Dead raiders drop a one-time ammo pickup and respawn after 120 s
  (test-level stand-in).
- Level: a raider camp in the south-west of the yard (three raiders, low walls, crates, a standing wall), with
  cover on the way in. T adds a raider at the crosshair, Shift+T removes those.
- Raiders and zombies fight (owner, 20 Nov 2026). Zombies: `Enemy.prey` is whoever they are after, the nearest
  living person noticed (the player or a raider), picked twice a second in `_pick_prey()`; they grab, hold, bite and
  lunge at a raider through the same calls as at the player (`take_grab`, `take_bite`, `take_attack`...). Raiders:
  a zombie in sight within 11 m is shot at (slower and 1.6 times wilder than their fire at you, 6% headshots);
  within 6 m it comes before the fight with you; under 4 m they back away, at arm's length they club it (often
  knocking it down); held, they club a holder off every 1.1 s. Zombies near a raider wear its composure down like
  the player's. Raider gunfire draws zombies within 30 m. Raider and gunner shots hit zombies in the way, never
  raiders. Cloud runs: three raiders at the camp killed 12 zombies in 29 s unhurt (the camp's walls held the zombies
  off, since zombies can't climb); one raider in the open against 4 was grabbed and bitten to under half health.
  A raider killed by zombies does not turn into one yet.
- Limits: straight-line movement only (no path finding in the game); raiders don't vault, don't use windows on
  purpose, and don't talk to each other beyond not sharing a spot.
- Review sheet: `tools/preview/raiders.png`, made by `tools/raider_preview.gd`.

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
