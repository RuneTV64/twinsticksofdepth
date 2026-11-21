# Twin Sticks of Depth

Godot 4 twin-stick zombie game (the owner works in Godot 4.7, Forward+). PC only, mouse and keyboard only (owner,
20 Nov 2026: there is too much to build to keep a controller working too; maybe later). Design and tune new
controls for mouse and keyboard; don't spend time on controller support. The controller bindings and stick aiming
were stripped out the same day at the owner's request (`input_setup.gd`, `player.gd`, `hud.gd`, `main.gd`).
Forward+ only: no Compatibility renderer, no web or phone builds (owner, 15 Nov 2026). The level is built in code (see README.md);
the character models, shaders and their scripts are in `assets/characters/` and in our claude.ai Artifacts.

## Where we left off (21 Nov 2026, the owner at work; picking up from a phone)

Everything built in the long session of 20 to 21 Nov is on `main`. The owner has now played all of it on
their PC (21 Nov 2026: "I've tested all of it. It seems fine so far. We can tweak once we get the bulk of the
game put together"). So the "untested on the owner's PC" notes further down are out of date for anything
built before that, and nearly every timing, range and chance is still Claude's first guess: don't tune
unasked, build the bulk first.

The owner's answers to what was open (21 Nov 2026):

- The camera: the fixed 45 degree turn is exactly what they meant.
- The torch: both kinds. The battery one and a burning one now exist (see Light and dark).
- A lost limb may be hidden on the player by the pose code: done (see The bite).
- Ground colours, flooding and the tall grass stay as they are. But overgrowth must come one day: "As the
  years roll by nature will reclaim what is hers." It belongs with the time system (see Where the game is
  going); nothing is designed.
- Raiders seeing 18 m against the player's 40 m is fine for now. Raiders still beat the owner from across
  the screen, because you have to be zoomed in to see what you are doing close up. The owner's thought:
  "might need to add an outline to zombies and players to help them stand out". Proposed and built the same
  day (see Outlines), on `main` since the owner said to push it (after their own update of that day), not yet
  seen by the owner. Checked on top of that update: the level runs clean, the outline sheet renders the same,
  and `impale_test` and `items_test` pass. An impaled zombie keeps its outline while it hangs alive.

Built after those answers and not yet seen by the owner: the burning torch, and lost limbs showing on the
player (sheet: `tools/preview/missing_limbs.png`).

Built 21 Nov 2026, on `main` since the owner said to push it, but not yet seen or played by the
owner: everything can be broken (see Two rules for every object, and Breaking things); bare feet, blood
on the ground and ordinary infection; and how clean water is. Tested headless only.

Built 21 Nov 2026, on `main` since the owner said to push it, but not yet seen or played by the owner:
the house kit, with stairs you can walk and basements, cover and shooting between floors, and
aiming at things above you (see The house kit); buildings that open while you are inside them, glass at
half strength in a cut wall, and the cursor cutaway (see Camera). Review sheets in
`assets/buildings/house/preview/` and `tools/preview/cursor_cutaway.png`.

Built 21 Nov 2026, on `main` since the owner said to push it, but not yet seen or played by the owner:
the fence kit, and bodies impaled on spiked fences with their pose (see The fence kit); and the street
kit (see The street kit). The owner has pivoted back to making assets.

Built 21 Nov 2026, on `main` since the owner said to push it, but not yet seen or played by the owner:
street lamps and signs (see The street kit, Lamps and signs), the furniture kit (see The
furniture kit), the first working items (see The first working items), and searching furniture with
the grid screen and a backpack (see Searching and the grid).

Items by theme: the owner named the first theme on 21 Nov 2026, a middle-class living room. Built first, as
planned, what all four batches share: held things as weapons that wear out, and taking things apart (see Held
weapons and taking apart; on the session branch, not on `main`, not seen by the owner). Waiting on the owner
for: how many items the theme gets, and their answer to the clothes proposal (see Themed item batches) before
any clothes are built.

Held until the owner has play tested (owner, 21 Nov 2026: "We will hold off until play test"): whether
shooting at what the cursor covers is too clunky, and whether firearms should lock on. Don't change aiming
before then. Claude's answer, for when it comes up again: keep the free cursor when Ready (windows, walls,
a spot in the dark and throwing need it), and consider a lock-on that keeps part aiming (the crosshair
snaps to the nearest enemy, a nudge of the mouse picks the part, a firm move breaks it) and a visible
spread ring in place of the hidden hit roll. What to watch for in play: can a head be picked without
zooming in, do misses feel like your own fault, does aiming near a house ever pick the wrong thing.

What was next in the orders already given: sickness, then the new needs (hygiene, morale, toilet, warmth);
the loot system and loading weapons (design together, sketch first); punches using the part picking; a pile
with more meat than bone; spawning and horde migration; modular buildings; the clean-up lore. A session on a
phone can't run Godot either: keep to the same way of working (scratch copy, headless tests, software renders,
say what a picture can't show).

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

- The camera never turns in play (owner, 20 Nov 2026): it only pans and moves in and out. No rotation, snapped
  or free. Later the same day the owner decided the view itself is turned 45 degrees: `camera_rig.gd`
  `yaw_deg` 45, so north is toward the top right of the screen, as in an isometric game. (The owner confirmed on 21 Nov 2026 that this fixed turn is what they
  meant, not a camera the player can rotate.) Anything that maps the
  screen to the ground must go through `Player.screen_to_ground()` / `CamRig.yaw()`: movement keys (up is up
  the screen), mouse travel, the camera lead. Lighting set from the camera (zombie and raider `key_dir`) is
  worked out once at start-up from the camera as it stands, so it follows; it is unchecked on real hardware.
- In and out, and further (owner, 20 Nov 2026; untested on the owner's PC). The mouse wheel moves the camera
  in and out (`camera_rig.gd` `zoom()`, 18 m by default, first 9 to 42 m and now 4.5 to 45 m: see "Matched to
  Project Zomboid" below; the angle never changes). The crosshair roams 16 m (`reticle_range`, was 10) and is kept on the screen: at the edge it stops
  and the view follows it. The camera leads toward it by half (0.45 Ready), never so far that the player leaves
  the screen (`cam_lead_max`). Mouse travel scales with the zoom, so the same hand movement covers the same
  share of the screen. Free look: hold F or the middle mouse button and the camera lets go of the player and
  goes with the crosshair, out to `free_look_range` 30 m (owner: decent, not too generous); let go and it
  comes back. Sight is unchanged: the fog of war doesn't lift. Zoomed right out, every zombie is on the low
  model (the detail swap is by distance from the camera).
- Matched to Project Zomboid (owner, 20 Nov 2026: "compare how far zomboid lets you look and match it").
  What could be found: its zoom steps run from 25% to 250% of the normal view, and aiming (or its pan key)
  pans the camera toward the cursor; no source gives the pan as a number. So: the wheel now goes from 4.5 to
  45 m (0.25 to 2.5 times the default 18 m); the crosshair's reach grows in step with the zoom (16 m at the
  default, up to the edge of sight pulled right back; free look 30 m, up to 50 m); and the player's
  `sight_range` went from 26 to 40 m so there is something to see out there. Raiders still see 18 m.
- The cursor (ring and red x) is scaled with the camera's distance so it is the same size on screen at every
  zoom (`cursor_size` 0.7 of what it was at the default: about 16 px radius at 1600 x 900).
- Cutaway (built 20 Nov 2026, untested on the owner's PC): whatever stands between the camera and the player is cut
  open, with a dithered edge, so the player is never hidden behind a wall or a tall building. The feet of walls
  (up to 0.95 m) stay. `cutaway.gdshaderinc` has the test (`cutaway_hidden(world_pos, FRAGCOORD.xy)`); any spatial
  shader takes part by including it and discarding. `cutaway.gd` (`Cutaway`, one node in the level) sets three
  project-wide shader globals once a frame (`cutaway_focus`, `cutaway_view`, `cutaway_shape`, declared in
  `project.godot` under `[shader_globals]`). The test level's walls, crates and doors use `Cutaway.solid(colour)`
  (`level_solid.gdshader`, one shared material per colour). V switches it off and on. The cut edge isn't capped
  (you see through the wall, not a filled section), and cut parts stop casting shadows.
- Indoors, the whole building opens (owner, 21 Nov 2026: "Walls should cutaway while player is inside the
  building and windows should show albeit at 50% transparency"; built the same day, not seen by the owner).
  - Whatever builds a building says where it stands: `Cutaway.add_building(rect, low, high, ground, storey,
    eaves)` (`HouseKit.house` does; so do `main.gd`'s `_house` and the yard house). While the player's feet
    are inside a footprint, every wall comes down to the keep height (0.95 m) wherever it hides that
    building's floor: the walls on the camera's side and the walls between rooms. The far walls (north and
    west) stand whole. Everything over the storey you are on goes: upper floors, the roof (`room_ceiling`
    2.58 m over your floor). Upstairs the ground floor stays; in a basement the house above goes.
  - It opens and closes over `room_ease` 0.3 s, dithered, as you go in and out, and follows you a storey at
    a time on the stairs (`room_climb`).
  - Stairs stand (`cutaway_hidden_standing` in the trim shader), so you can see the way up from across the
    house; they still open round the player and under the lid.
  - Window glass is never cut (`glass.gdshader`, `Solid.glass(stage)`, one shared material a stage): where
    the wall round it has gone, in any of the three openings, the pane is drawn at 50%. Glass over your
    storey goes with that storey.
  - `Cutaway.hides()` knows the building opening, so the crosshair can't be on what isn't drawn.
- The cursor cutaway (built 21 Nov 2026, not seen by the owner): with the weapon Ready, or looking about
  with free look, the same opening is cut toward the crosshair (`cutaway.gd` `_aim()`, shader globals
  `cutaway_aim`, `cutaway_aim2`): 2.2 m round the line of sight to the crosshair's spot on your floor, once
  it is 2 m or more from you, easing in over 0.14 s. So a wall, a floor above or a roof never hides the spot
  you are aiming at. When the crosshair is on something above your storey (`aim_high`) it opens to that thing
  instead. Weapon away and not looking about, nothing opens. What it shows you is the place, not who is
  there: the fog of war and sight are unchanged.
- Sheet: `tools/preview/cursor_cutaway.png` (`tools/house_preview.gd` with WHO, AIM, AIMHIGH, LOOK: it runs
  the real `Cutaway` node round a stand-in figure). Software renderer; easing and the dither in motion are
  for the owner's PC.
- Not done: things drawn without the cutaway float when the floor under them goes (pickups, wreckage and
  blood upstairs, a zombie you can see up a stairwell); doors are cut like walls (their feet stay); a
  building is one rectangle (an L-shaped house needs more than one); raiders and zombies inside an opened
  building are still only drawn if you can see them.
- More buildings are for another day (owner): custom modular building pieces in the 8-shade pixel look.
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
- Professions are hands-on mini-games (owner, 20 Nov 2026, on seeing the treatment screen: "Trauma Center! I
  loved that game"; a slice or two of it is welcome, and "most professions should work in a similar mini-game
  style way"). So medicine is the model: a skill is something the player does with the mouse, close up, and the
  character's skill changes what they can see and how forgiving it is. Borrow mechanics, never another game's
  names, art, characters or levels. Which professions and what each one's game is are not designed: propose.
- Order of work as the owner sees it: loot is more important than buildings; modular building assets come later;
  spawning and how the horde moves, and the turning-undead mechanic, are also still to come.
- Abilities are earned (owner, 21 Nov 2026): "a lot of this functionality and abilities will have to be
  discovered, earned and or learned." That is a reason to chase the hats and badges that unlock new roles
  (see character slates above): a role is often how you learn its abilities ("Cops learn stuff when they become
  cops because they're cops"). So when building an ability, leave a switch for who has it (as
  `Player.can_bash()` and `Player.reads_tells` do) rather than assuming everyone does. Which abilities belong
  to which role is not designed.
- The view stays top-down (owner, 21 Nov 2026, after asking whether to go first-person: no). What makes the
  game original is its systems, not the camera; first-person is already the crowded field, and the hordes,
  cover, stealth, the cutaway, the art and the posing are all built for this view. Close-up moments (the
  drawer, the treatment screen, a scope, peeking) can borrow first-person's closeness without a switch.

## Reference: Zomboid's buildings and the art style (talked over 21 Nov 2026)

- How many buildings Zomboid has: its only official number is Build 42's "1,400 new unique buildings" and
  20,000 new tiles (about 35,000 tiles in all; Build 41 had about 15,000), plus about 400 procedural basements
  and 75 unique ones. Counts of 8,500 to 9,600 placed buildings come from fan map tools and disagree; an AI
  summary's "2,000 to 3,000 unique templates" had no source. Zomboid has no building models: mappers lay out
  every building by hand from flat tiles. Ours is closer to that than to prefabs, but a layout is a function
  call (`HouseKit.house(...)`), not hand placing. So the number to grow is kinds of piece and styles, and how
  much variety the kit makes by itself, not a count of hand-made buildings.
- An outside AI's take on the 8-shade style, and the verdict: its praise fits and is already built (speed of
  making assets by code, storeys and breaking things in 3D, gear on one skeleton; gear and clothes must carry
  the rest-position data, `CUSTOM0`, or painted detail slides on them). Its camera advice doesn't fit: the
  camera is a perspective one (50 degrees, `camera_rig.gd`), fixed at 45 degrees and never turning (owner), at
  full resolution, zooming 4.5 to 45 m, so a low render resolution scaled up would change pixel size with the
  zoom; our pixels are fixed in the world instead (16 to the metre), which may shimmer zoomed right out.
  "Reserve the brightest two shades for loot" doesn't fit either: each material has its own natural 8-shade
  ramp. The real risk it named is readability (answered for characters by Outlines). Worth keeping for loot
  and furniture: can a small item on a cluttered table be spotted in the dark, and room corners read at night?
  Night darkness is the fog-of-war layer (up to 82% black), so that is where that is won or lost. Corner
  shading in rooms would go in the house shaders; not designed.

## How fighting should feel (owner, 21 Nov 2026)

The fights are one of the main places the game is to beat Zomboid, whose combat feels clunky. The owner: "I
want my game to feel like you are playing a good twin-stick shooter that is also designed in a way to give
you a very rich and detailed survival experience."

- The rule: the depth goes in what happens around a fight, not in the controls during it. The character may
  be limited (hurt legs slow you, shaking hands spoil your aim, a grab holds you, rummaging costs your view):
  that is survival, and it is fair because you can see why. The controls must never fight you: no lag after a
  click, no menus mid-fight, no lockouts you didn't choose. When something feels bad, ask whether it is the
  character's limit (keep it) or the game's friction (cut it).
- Ready is the bridge between the two halves of the game (owner): Ready held, you are in a twin-stick
  shooter; let go, you are in the survival game (levers, traps, bridges, ladders, ropes, doors, loot). You
  should be able to shoot a crowd, lower a bridge or set off a trap, and climb out an upstairs window on a
  rope, switching without a seam. Keep Ready. So:
  - Raising and lowering is instant both ways, with no lockout you can feel.
  - Left-click is attack when Ready and use when lowered; the cursor and prompt always show which.
  - Every interaction can be dropped by holding Ready (owner): working a bridge, climbing onto a rope,
    rummaging. You are never stuck in an animation the game won't let you leave.
  - Switching costs in the world, not the controls: while your hands are busy you are exposed and noisy.
  - Some things want both modes (owner agreed: traps, and likely kicking or shoving a door shut with the gun
    up). Decide per object rather than forcing everything through lowered.
- What twin-stick feel needs, and where it is thin now (Claude's list; none of it built or tuned yet):
  every input answers on the frame it is pressed, and a click made during a swing is remembered for the
  next; a short freeze on contact, sounds by what was hit, and bodies reacting by the part struck; misses you
  can see the reason for (reach, swing arcs, the spread ring idea held for the play test); zombie wind-ups you
  can read before a lunge or grab (fast fresh, slow rotted); weapons that play differently (a hatchet that
  sticks and needs yanking free, a bat that knocks down, a knife quick and quiet but close). Melee weapons are
  where the game is thinnest and where it matters most; "punches using the part picking" is the natural place
  to lay this plumbing for all melee. Reloading, when designed, should have a quick tap with a learnable
  rhythm and leave the deeper handling for when there is time. Response, freeze on contact and hit reactions
  are plumbing, cheaper early than bolted on later; numbers still wait for the bulk to be built.
- Still to watch in the play test: the 0.45 s getting up after a roll, and hit rolls you can't see.
- Parries and counters (owner, 21 Nov 2026): the outline's wind-up warning opens the way to them later. Not
  designed; likely abilities to be learned (see Abilities are earned).

## Outlines (built 21 Nov 2026, in review; not seen by the owner)

The owner: zombies and raiders are hard to pick out, most of all zoomed out ("might need to add an outline to
zombies and players"). Claude proposed, the owner answered, and it was built the same day.

- How: `outline.gdshader`, put on each character's mesh as its `material_overlay` by the game's own scripts
  (`outline.gd`, `Outline`): `zombie_body.gd` (on whatever `shown_meshes()` gives; re-applied in `refresh()`),
  `player_body.gd` and `raider_body.gd`. The approved shaders and models are not touched. The mesh is drawn a
  second time pushed out along its surface and inside out, so only a rim shows. One shared material per kind.
- The same width on screen at every zoom: `width_px` 2 at 900 pixels high, scaled with the window.
- Colours (owner): zombies dark (near black, a warm tint), raiders dark red, the player light; allied people
  and, one day, other players share the player's. Flat colours, no soft edge.
- Shown only on what is drawn: it goes with the body (a hunkered raider isn't drawn, nor is his outline), and
  for zombies it reads the decay shader's own `dissolve` (pinned to the same per-object slot, 8) and fades a
  step ahead of the body. Never through walls. The night layer (`fog.gd`) is drawn over it, so in the dark it is
  as dark as the body. It isn't cut by the cutaway (the bodies aren't either).
- Wound insides are left out (owner's ask): the inner surfaces under the holes in a zombie's skin (part codes
  12 to 15 in the mesh's `COLOR.a`) are neither pushed out nor drawn.
- The dead have none (owner: with this many zombies it is fine to know one is dead; a head shatter and brain
  splatter are planned too). Downed ones keep it. Cut-off pieces and the corpse pile never have one (a live arm
  in the pile must look like a dead one). A raider who respawns gets it back.
- Flashes (owner: "Do it"), per-object values `outline_flash` and `outline_warn` (slots 14 and 15, which no
  character shader uses), sent only when they change (`Enemy._update_outline()`):
  - Seen: an enemy that had been fully out of view for `Outline.SEEN_AFTER` 3 s or more flashes its kind's
    flash colour (zombie pale, raider bright red) for 0.35 s on coming into view.
  - Warn: hot orange and a pixel wider while a zombie winds up a grab or a lunge at the player (`reach`,
    `lunge_wind`) or a raider lines up a shot (popped, before his first shot: `Raider._winding_up()`). Only if
    `Player.reads_tells` (true for everyone for now; it may become a learned ability, with parries and
    counters after).
- An arm across the body gets a line of its own (the inside-out drawing does that). The owner had pictured
  only an outer outline; the sheet shows both. If the inner lines are unwanted, the way to an outer outline
  only is a stencil pass (Godot 4.5 and up), without touching the approved shaders; not built.
- Cost: one more draw per character (Godot skins once, so no second posing): a 226 horde about 860 to about
  1,090 draw calls. Unmeasured: for the owner's PC.
- Sheet: `tools/preview/outline.png` (`tools/outline_preview.gd`: the game's camera angle at 1600 x 900, the
  default 18 m and zoomed out 45 m, with and without; a close-up of a torn chest; the flashes). What it shows:
  at 18 m the crowd, the raider and the player stand clear of the ground; at 45 m the crowd goes from hard to
  find to plain, though a 2 px rim on a figure 25 px tall makes zombies read as dark shapes (thinning it past
  30 m is an option for the owner). What it can't show: Forward+ (the per-object slots, `material_overlay`
  carrying per-object values, `VIEWPORT_SIZE` in the vertex stage are all unchecked there), the night layer,
  the flashes in motion, the cost.

## Loot (being designed with the owner, 20 Nov 2026; searching and the grid are built: see Searching and the grid)

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
- Unloading (agreed in outline): Shift+R is "make safe": the magazine comes out and the chambered round is racked
  out; holding it strips rounds from the magazine. Racking makes a noise. In the inventory a gun opens to show its
  chamber and magazine well, and a magazine shows its rounds, to drag out by hand. Still to settle together: the
  rest of loading (R tap to swap magazines, R hold to thumb rounds in, where magazines are kept).
- Order (owner): enemy AI that follows sound came first, because items will make noise. That is built (see Sound,
  hordes and hunting). The items that exist are the medical ones, the tools and the rest listed under The
  first working items (`items.gd`), with the slot inventory. Searching furniture, the grid screen and a
  backpack are built (see Searching and the grid); loot on zombies, food rotting, guns and loading are not.
- Claude's earlier layout, which the owner answered against: items are records (weight, condition, category);
  container contents are rolled when first opened; time is applied on opening (spoiling, picked over by others);
  nothing respawns in a cupboard; keepsakes unlock starting builds.

## Health, injury and medicine (designed with the owner 20 Nov 2026; the body, treatment and the bite are built)

The owner put this ahead of items: how you take damage, get sick, get injured, get better, get worse and die.
What the owner asked for: Sims-like needs (boredom, hunger, hygiene and so on) feeding a complex medical system;
draw on other games but keep a twist of our own; treating wounds must be its own kind of interaction, different
from the rummaging minigame; and the player must have a reason to learn medical.

Claude's proposal, waiting for the owner's critique (sketch: `tools/sketches/treatment_screen_sketch.png`):

- Wounds are on the body's six parts (the same six the zombie model has), of a few kinds: bruise, cut, deep cut,
  bite, gunshot, break. Blood, not a health bar, is what kills quickly; pain and the injured part's function are
  what slow you.
- Knowing medicine is seeing: an untrained character knows only that it hurts and bleeds. Skill shows what is
  actually wrong (a break or a sprain, an infection starting, where the bleeder is) and where to work.
- Treatment is hands-on work on the wound close up, in order: stop the bleeding, clean it, close it, dress it,
  support it. Each is done with the mouse and what you carry; your pointer shakes with pain and lost composure.
- Other reasons to learn it: anatomy helps you kill (aimed shots, finishers); dissecting the dead is how you
  practise; maggots from corpses clean infected wounds; you can treat other people.
- Needs proposed: food, water, rest (exist), plus hygiene and morale (boredom, company), warmth with the seasons.
- The owner's answers (20 Nov 2026):
  - The bite: surviving it takes the right resources, good timing and luck, and depends on where the bite is.
    Some places can be chopped off. Certain medicines (steroids, maybe) help fight the infection, but only
    amputation and luck can really cure it. The character is permanently disabled afterwards. A hand can be
    replaced by a low-mobility hook or an improvised hand, a leg by a prosthetic or a peg leg; those are to be
    designed later.
  - How close to death: the player must be able to tell they are close to death but not exactly how close.
    Medical gives the best guess, for someone who really wants to know how long they have.
  - Toilet is a need and also a resource: it feeds compost (see Loot). More will be done with it.
  - When you turn, your old character walks the map as a zombie carrying your things: "Absolutely".
  - The hands-on treatment is "exactly what I had in mind".

Built so far (20 Nov 2026, untested on the owner's PC): the foundation only.

- `body_health.gd` (`BodyHealth`, at `sheet.body`): wounds on six parts (Head, Torso, ArmL, ArmR, LegL, LegR),
  each with a kind (bruise, cut, deep cut, bite, gunshot, break), a severity from the damage that caused it, a
  bleed rate and pain. Blood starts at 100; bleeding drains it; at 35 you die ("You bled out"). It comes back
  slowly when nothing bleeds. Everything moves on the sheet's slow clock.
- What makes wounds (`player.gd` `_wound()`): a zombie's bite (an arm, the chest or the head; a leg if it is on
  the ground), a lunge, a raider's clubbing (bruise), a gunshot (mostly the chest), a head hit while peeking, being
  crushed, a bite from the pile or a severed head (a leg).
- Conditions from it (`character_sheet.gd`): Bleeding, Bleeding badly; Pale, Light-headed, Faint, Fading as blood
  falls (slower, worse aim); In pain / In agony (hurt legs slow you, hurt arms spoil your aim; adrenaline hides it);
  Bitten (a label only: the bite's real consequences are not built).
- Never an exact number (owner): the health bar now shows five rough steps of the worse of health and blood;
  `Player.death_feel()` puts it in words ("You are in a bad way", "You are dying"). Damage messages no longer
  give numbers.
- Medical is a stand-in number, 0 to 10, set on the character page (C) until skills exist. 0 to 1: you know what
  hurts and what bleeds. 2: the kind of wound and how bad. 3: you can see it closing. 4 and up: a rough guess at
  how long you have, rougher the less you know.
- Stand-ins: small wounds clot (bleeding halves every 60 s) and close after 150 s (about 60 s stitched and
  dressed). The old health number and its automatic healing are still there underneath.
- Deep wounds (severity 0.55 and up) no longer stop by themselves: they ease to `deep_floor` 0.35 of their
  bleeding and stay there until stitched or dressed. A severe deep cut left alone kills in about 9 minutes.
  Bleeding under `ooze` 0.025 costs no blood.

Items and the treatment screen (built 20 Nov 2026, in review; untested on the owner's PC). The owner said to
build the items needed to test the kits, so only medical items exist.

- `items.gd` (`Items.DEFS`): bandage, clean rag, needle and thread (12 stitches), tweezers, vodka (4 washes),
  painkillers (6), steroids (4), hatchet. A carried item is a Dictionary: `{"id", "n"}` for a stack, `{"id", "uses"}` for something used
  up. `inventory.gd` (`Inventory`, `player.inv`): the agreed weighted slots with no bag: four pockets (0.5 kg),
  two belt (1.5 kg), two hands (20 kg), one thing or one stack each. Jeans pockets are assumed until clothes
  exist. Shown on the character page under Carrying. Carried weight does not feed the WT number yet.
- `item_pickup.gd` (`ItemPickup`): a first-aid box, taken with interact. One by the spawn, one in the yard house.
- `treatment_screen.gd` (`TreatmentScreen`, `hud.treat`): H sits you down (`Player.toggle_treat()`,
  `player.treating`). Left: your body, as much as Medical lets you tell. Right: one wound close up. The pointer
  is your hand: it shakes with pain, lost composure and lost blood (`shake()`), less with Dexterity and
  painkillers. Tools by click or keys 1 to 7. You see only `treat_sight` 3 m while it is open; ALT (`look_up`)
  looks up and stops your hands; moving, being grabbed or being hit puts it down.
  - Press: hold the bare hand or a rag on the wound, best on the bleeder. Pressure holds a deep wound at a fifth
    of what it bleeds left alone, and it wells back up over `well_up_time` 30 s: you work against that.
  - Clean: tweezers take out what is in it (a bullet, a tooth, grit; a miss digs into flesh); vodka is held
    and swept along the wound. Too much blood (over 0.1) hides the wound from tweezers and needle.
  - Close: hold and zigzag the needle across the wound; every crossing is a stitch where it crossed (it has to
    swing 14 px clear each side, so a tremor alone doesn't stitch). `stitches_needed()` 2 to 7; `closed_frac()`
    counts the evenly spaced places that have a stitch near. Slight cuts need none; a bite is left open.
  - Tweezers work like forceps: grip the thing, draw it out slowly, let go clear of the wound. A jerk (the hand
    moving over 700 px/s, smoothed) tears it free and the wound bleeds more: shaking hands do this by themselves.
  - Dress: hold and wind round the wound three turns with a bandage (or a rag, poorer). A bare-hand click takes
    a dressing off (it is lost).
  - Shut in dirty (stitched or dressed unwashed or with something in it) it festers: the pain doesn't ease and
    it closes slowly. What festering leads to waits for sickness.
  - Medical: 1 marks the bleeder; 2 names the wound and shows what is in it; 3 shows where stitches should go.
  - A new hit on a treated wound tears it open: stitches and dressing go.
- J gives a test wound (deep cut, gunshot, bite in turn). Review sheet: `tools/preview/treatment_screen.png`
  (flat placeholder shapes, not the 8-shade look; the skin is one fixed colour, not the character's).
- Not built: splints and breaks (nothing causes a break yet), the wound's own look per body part, treating
  other people, moving items between slots (dropping exists: see The first working items).

The bite, amputation and turning (built 20 Nov 2026, in review; untested on the owner's PC). All the times are
stand-ins until the game has a clock (`body_health.gd`, "the bite").

- A bite takes 92% of the time (`takes_chance`); the player is never told. It starts in the part bitten and
  spreads to the body: an arm in 200 s, a leg in 280 s, the head or chest at once (`spread_time`). From the bite
  you turn in `turn_time` 900 s: Feverish, Sick, Failing (conditions), then "You turned."
- Steroids (4 doses) hold both the spread and the sickness to 0.4 of their pace for 240 s. They cure nothing.
- Amputation, in the treatment screen with the hatchet picked on a wound on an arm or a leg: tie it off above
  (wind a rag or bandage round the cut line; skipping it is allowed and the stump pours), then three blows
  clicked on the line. Each blow costs composure and is heard 10 m off; a miss is wasted and hurts. If the
  infection went in by that limb and has not reached the body, the chance it is cured is 1 minus spread squared
  (+0.1 on steroids, at most 0.97): 96% at 20 s for an arm, 74% at 100 s, 18% at 180 s (cloud, 600 tries each).
  The player is not told whether it worked. A limb can be taken off needlessly.
- The stump is a wound of its own (`stump`): it bleeds hard (0.6, or 0.24 tied) and is pressed and dressed, not
  stitched.
- Gone for good (`body.missing`, until that character dies). An arm: -40% aim, reloading takes twice as long,
  no shoving or guarding, wilder blind fire. A leg: -55% speed, no running, dashing, rolling or vaulting. Hits
  aimed at a missing limb go to the chest. Hooks, improvised hands and peg legs are for later (owner).
- The lost limb shows (owner, 21 Nov 2026: the pose code may hide it). `PlayerBody.show_missing()` draws the
  forearm or the lower leg, and all below it, down to nothing at the elbow or knee, which leaves a closed
  stump; the approved model is not touched, and it is only set when the list of lost limbs changes. With
  the right arm gone the left hand takes the gun's grip. Sheet: `tools/preview/missing_limbs.png`
  (`tools/cover_pose_preview.gd` ROW=3). Stand-ins: the stump is plain skin (no wound, no dressing), a
  one-legged character still stands and walks as if on two (no hop, crutch or lean), and every pose still
  moves the missing arm's shoulder as before.
- What you can tell (`bite_guess()`): Medical 0 to 1, only that you were bitten; 2, that it is infected; 4, how
  far up the limb it has got, or that the bite seems not to have taken.
- Death (`Player._die()`): infected, your old character gets up where you fell as a fresh zombie (`Enemy`
  `was_player`, `carried`), missing the limbs you had lost, with everything you carried; killing it drops "Your
  old things". Not infected, your things lie there as "Your body". The new character starts with nothing. The
  risen zombie's skin is rolled, not yours: the player has no look of its own yet.
- Not built: sickness other than the bite, a turned raider, more than one cutting tool, cauterising, prosthetics.
- Next, in order: the rest of sickness (wound infection is built: see Bare feet, blood and ordinary
  infection); the new needs (hygiene, morale, toilet, warmth).

## Two rules for every object (owner, 20 Nov 2026)

Apply both to everything made from now on: level pieces, furniture, appliances, props, building assets.

1. **Everything can be broken.** Walls, floors, ceilings, stairs, doors, windows, furniture, appliances, street
   signs, pavement. Nothing solid goes into the world except through `Solid` (`solid.gd`), which gives it a
   material and a `Breakable`. A new kind of object needs: what it is made of (one material, or shares of
   several), what it is called, and what its wreckage is. If it needs a new material, add it to
   `materials.gd` with its scrap item and what clears it away. The only exception is the test map's outer
   wall (`fixed`): it is the edge of the map, not a thing in the world.
2. **Everything has a purpose.** "If the object does not interact with the player in some way then it doesn't
   need to exist in game. Everything has a purpose, even if it's just a blade of grass that sways when a
   player walks through it." So no pure decoration: before adding an object, say what the player does with
   it or what it does to the player (cover, a container, something to break for materials, something that
   makes noise, hides you, slows you, lights you). If there is no answer, leave it out.

## Breaking things (built 20 Nov 2026, in review; not seen by the owner)

The owner's order: everything destructible; pavement broken up into rock with the proper tools and enough
work; zombies destroy parts of buildings and tear first at the path of least resistance "of whatever little
catches their attention" (someone jumps in a window and boards it: a zombie that saw it smacks at the window
until it breaks); broken glass and broken appliances stick around, and their materials can be retrieved,
broken; rust and wood rot clear broken things away over time, "the non-biodegradable form of maggots".
This is the foundation; every number in it is Claude's first guess.

- Materials (`materials.gd`, `Materials.DEFS`): glass, wood, plaster, brick, concrete, asphalt, metal,
  plastic. Each has strength per square metre of the thing's biggest face (`hp`), a hardness (`hard`), how
  well each kind of blow works on it, its scrap item, what clears its wreckage away (`agent`) and how far a
  blow on it is heard. Kinds of blow: blunt (fists, boot, rifle butt, zombie hands), chop (hatchet), pound
  (sledgehammer), pierce (bullet). A blow weaker than the material's hardness only scratches it (4% of its
  force): nothing is unbreakable, but the wrong tool takes a very long time. That is the whole of "proper
  tools and enough work".
- `breakable.gd` (`Breakable`, a child of the thing; also in the group "destructible"): `hit(force, kind, at,
  by)`, `hits_left(force, kind)` (the measure of resistance), `feel()` (how it will go, in words), three
  stages of damage (sound, damaged, about to give: the test level darkens the thing a step each). When it
  gives way: wreckage, a noise heard 1.8 times as far as a blow, out of the cover system
  (`Cover.remove_box`; anyone using that cover lets go), freed. Sight and shots open up by themselves
  because both are physics rays. It has no `_process`; things are found through a 2 m grid (`near()`,
  `under()`, `weakest()`).
- `solid.gd` (`Solid`): `box` (anything standing), `pane` (window glass), `board` (planks over a window),
  `slab` / `surface` (floors, pavement). `main.gd`'s `_box`, `_glass` and `_flat_box` go through it.
  - A long wall is cut where it is hit: the first blow cuts a 1.2 m section out as a piece of its own and
    that is what breaks, so a hole is a person wide. Nothing is cut up until it is hit.
  - Window glass is now solid to bodies (physics layer 16, `Solid.GLASS_LAYER`: it stops the player,
    zombies and raiders, not sight). A shot goes through and shatters it; a thrown rock or bottle too.
    Nobody vaults or climbs through an opening with a pane or boards across it (`Breakable.barrier_between`).
  - Floors and pavement are worked a square metre at a time and leave a hole showing dirt.
- In the test level: house walls brick, inside walls plaster, crates wood, cars metal with glass and
  plastic, the street asphalt (since 21 Nov 2026 the street kit's tiles: see The street kit), floors wood, doors wood (the locked one twice as strong, part metal); a
  table and a fridge as one of each sort (the plain street sign that stood with them gave way to the
  street kit's signs); a sledgehammer in the tool box.
- The player (`player.gd`, `_strike_breakable()`, `break_tool()`): Ready, crosshair on the thing (the red x),
  within `break_reach` 1.9 m, left-click. Fists Ready you use the best tool you carry for that material
  (hatchet chops, sledgehammer pounds); gun in hand it is shot, or butted when empty. The prompt names the
  thing, its material, its state and how it will go, never a number. Bare fists on glass may cut your arm
  (35%), on something too hard may bruise it (15%). A failed door barge also splinters the door.
- Zombies (`enemy.gd`, Breaking things exports): one walking into something it can't climb, with prey or a
  drive in its head, beats on it every `smash_every` 1.1 s (slower stiff) with `smash_force` 10 times its
  `walk_mult` (12 fresh, 6 rotted). It goes for whatever within `smash_reach` 1.2 m in front of it will give
  in the fewest blows (`Breakable.weakest`): glass before boards, boards before a door, a door before a
  wall. A low thing it can climb it still climbs, unless glass or boards bar the way; then it breaks them
  first and climbs through. Its blows are not sent out as noise (a horde beating on a house would warm the
  area for ever); the thing giving way is heard.
- Wreckage (`wreck.gd`, `Wreck`): what is left where the thing stood, by material and area. Interact picks
  through it for the scrap items (`glass_shard`, `wood_scrap`, `scrap_metal`, `plastic_scrap`; brick,
  concrete and pavement give the existing `rock`). Wreckage landing within 0.8 m of more joins it.
  - Broken glass crunches under a shod foot (`Wreck.step_on`, from the player's and enemies' footfalls): heard 6 m,
    half that crouched or crawling. Walking on it never removes it (owner, 21 Nov 2026): it stays until it is
    picked up by hand, or goes shard by shard into bare feet. (See Bare feet.) So glass round a window is an
    alarm for whoever walks on it, you included.
  - Rust and rot (`wear.gd`, `Wear`, one node, a 5 s clock): wood and plaster rot (gone in 15 minutes dry),
    metal rusts (30 minutes dry), both up to 3 to 4 times quicker in the wet (`Seasons` wetness); glass,
    stone and plastic stay until taken. What has rusted or rotted away can't
    be salvaged. The times are stand-ins for the clock.
- Debug keys: Shift+P boards the window nearest the crosshair (free and instant: the old stand-in; plain P is
  now the real thing, see The first working items); O breaks what the crosshair is on; Shift+O passes ten
  minutes of rust and rot.
- Stand-ins and not built: the wreckage's look (a scatter of plain bits, not the 8-shade look) and the
  damage stages (a darker colour); no cracks, dust or flying bits; nothing falls when what held it up goes (a wall over a broken
  section stays, no collapse); ceilings, stairs and upper floors don't exist yet; raiders don't break
  things on purpose (their shots do damage walls); no fire; a hole in a floor or pavement does nothing yet
  (it is meant to show soil to dig or plant in); broken appliances give materials only, not parts; a door's
  footprint doesn't follow its swing; zombies have no pose for beating on things; wreckage is drawn whether
  or not you can see the spot.
- Test: `tools/break_test.gd` (headless, in the real level; no picture: the level renders black in the
  cloud, and the look is placeholder anyway). Cloud run, 21 Nov 2026:
  - The level has 258 breakable things. One shot at the yard house's 14.4 m brick wall cut a 1.2 m section
    out of it; that section takes 16 sledgehammer blows, about 370 shots or about 3,900 punches. Once it
    went, a sight ray through the hole was clear and its cover was gone.
  - A crate: 3 hatchet blows, 2 splintered wood left. A square metre of pavement: 10 sledgehammer blows,
    3 rocks; fists get nowhere.
  - A zombie pressed 0.9 m along a brick wall from a window goes for the window (1 blow against about
    2,300 for the brick); at a door, the door (about 44 blows).
  - A zombie outside a shut window with the player inside: the glass went in 3 to 6 s and it was climbing
    through 2 to 3 s later. The same window boarded: one zombie took 23 to 25 s to get through the boards,
    four took 6 to 8 s. A house door, three zombies: 31 s.
  - Glass is still there after 100 footfalls in boots. Dry, wood and plaster wreckage were a third gone at 5 minutes
    and gone by 20; brick, pavement and glass stayed.
  - Seen in the same run and not looked into: zombies wandering the level broke several windows and an
    inside wall on their own, because one with a drive in its head beats on whatever stops it.

## Bare feet, blood and ordinary infection (built 21 Nov 2026, in review; not seen by the owner)

The owner: glass cuts your feet when you walk over it barefoot, and that is how the glass goes: it sticks in
your feet. Blood stays on the shards when they are pulled out. Stepping in fresh zombie blood with foot
wounds can infect you. Stepping on anything with untreated, uncovered foot wounds can make you sick: an
ordinary infection, which can kill you but won't turn you. Old blood or anything particularly gross almost
always infects unless treated and cleaned at once. Every number here is Claude's first guess.

- Barefoot (`Player.barefoot`: true until you put boots on; U puts them on and off, Shift+U is the old test
  switch). A
  bare foot landing on broken glass takes a shard half the time (`Wreck.BARE_CUT`): a cut "on the sole of the
  foot" on that leg (a leg wound with `where` "foot"), with the glass in it, and that shard is gone from the
  ground. A broken window (3 shards) was used up in about 5 barefoot footfalls; in boots it never goes.
  More shards in the same foot make the one wound worse. It is quieter than in boots (3 m).
- Glass as a trap (owner, 21 Nov 2026: stepping on glass must not remove it unless it sticks in a foot; it
  must be cleaned up by hand; and it can be laid as a trap for raiders and other players).
  `Player.lay_glass()` (Y for now) scatters one slot of the broken glass you carry just in front of you: a
  glass `Wreck` like any other, with as many shards as you laid. It cuts you too. Raiders are barefoot like
  everyone: one treading on glass takes a shard half the time (`Raider.cut_foot()`): 5 health, a limp at
  0.55 speed for 25 s, and he cries out (you are told within 14 m). He doesn't learn where you are from it.
  Cloud run: 3 shards laid, a raider took all 3 in 5 footfalls, health 62 to 47. Zombies take
  shards in their feet too and it does nothing to them (owner, 21 Nov 2026), so a horde uses a trap up:
  3 shards went into one zombie's feet in 6 footfalls, its health unchanged.
- Crawling on glass (owner, 21 Nov 2026: "a horrible idea"): prone, each drag over glass has a 0.7 chance
  (`Wreck.CRAWL_CUT`) of a shard, boots or not, in an arm, the chest (likeliest) or a leg: a cut there with
  the glass in it. Crawling in boots over 6 shards put all 6 in the player within 1.4 m. Crawling zombies
  pick it up the same way and don't care. Not built: raiders seeing and going
  round glass, picking it up or laying it; a bloody shard keeping its blood once laid; a proper control
  for laying (it waits for dropping and placing items).
- Glass in a wound is drawn out with the tweezers like anything else and comes out as a `bloody_glass` item
  ("Bloody glass"). A wound with anything still in it never closes. The item does nothing yet.
- Blood on the ground (`spill.gd`, `Spill`, one node in the level): a zombie that is hit leaves its blood
  where it stood, a raider theirs (not infectious). A stain is fresh for 180 s, then old; rain washes it
  away in about a minute and it dries to nothing in 30 minutes (Wear's clock). Drawn as flat patches, red
  fresh and brown-black old: a stand-in look.
- Every wound gathers dirt and grime and has to be cleaned from time to time (owner, 21 Nov 2026); feet
  just gather it a lot faster, most of all barefoot. On the slow clock each wound that isn't a bruise or a
  break and hasn't closed gains `germs`: `open_grime` (full in 30 minutes) or, under a dressing,
  `dressed_grime` (2 hours). The body shrugs off a little (`shrug` 0.1 open, 0.25 dressed); past that the
  wound "wants washing" (its `clean` goes false) and starts to go bad. A dressing has to come off to wash
  under it, and is lost: that is changing the dressing. Cloud run, a deep arm wound held open for an hour:
  never washed, it took hold at 583 s and was fully infected at 733 s; washed and bandaged once, it wanted
  washing at 30 minutes and took hold at 43; with the dressing changed every 10 minutes, nothing.
  Anyone can see a wound is "dirty"; Medical 2 says whether it wants washing or the dressing changing.
- Water washes wounds too (owner, 21 Nov 2026): `water`, "Bottle of water", 4 washes, in the first-aid
  boxes. In the treatment screen it is used exactly as vodka is; it doesn't sting (vodka costs composure).
  It cleans as well as it is clean itself (see How clean water is). The tools are now ten: keys 1 to 9
  and 0.
- A foot wound in boots or under a dressing still takes a quarter of the ordinary dirt of each stride
  (`covered_dirt`), and none of the blood or rot. Crawling, every open wound you have (not only feet) is
  dragged through what you crawl over: dirt, blood, rot, and the zombie-blood roll.
- Walking on an open cut foot (`Player._step_in_it()`, once a stride; open = not dressed and not nearly
  closed): each stride puts dirt in it (`germs`, 0 to 1): ordinary ground a little (`step_dirt` 0.004, up
  to five times that in mud), fresh blood 0.3, old blood or the corpse pile 0.9. Fresh zombie blood also
  rolls for the zombie infection (`blood_takes` 0.3: 110 to 128 in 400 in the cloud), which goes in by
  that leg exactly as a bite there does (so the leg can still come off in time).
- Ordinary infection (`body_health.gd`, `_tick_infection`): dirt left in a wound takes hold (`inf`), faster
  the fouler it is (`infect_time` 90 s at its worst). Washed before it takes hold (`hold` 0.5), that is the
  end of it. After that, washing only stops it getting worse, and the wound has to be kept washed and
  dressed while the body beats it (`fight_time` 300 s). A wound gone fully bad poisons the blood (`septic`);
  720 s later you die: "You died of infection." You don't turn. It clears slowly once no wound is bad.
  - Any wound can go this way, not only feet: one stitched or dressed dirty now does (festering leads
    here).
  - A fever feels the same whichever infection it is (Feverish, Sick, Failing): only Medical tells them
    apart. Medical 0 to 1 sees "hot and swollen"; 2 "infected"; 3 "filthy: wash it now" and "going bad".
    The condition "Infected wound" shows once one has gone fully bad.
- Cloud run (`tools/foot_test.gd`): one step in old blood and then nothing done: took hold at 50 s, fully
  infected at 100 s, dead at 820 s. Washed and bandaged 20 s after the step: nothing came of it. Washed
  and bandaged at 70 s (after it took hold): it never went fully bad and the cut closed. Walking without
  stopping on ordinary ground with an open cut foot: took hold at 106 s.
- The owner's "almost always gets you infected" for old blood and gross things is built as the ordinary
  infection, since it can be cleaned away at once and the zombie kind can't. Ask if that was wrong.
- Not built: footwear other than one pair of boots; glass hurting more as you walk on it; cuts from crawling or falling on glass; the
  player's own blood on the ground; raiders and zombies being cut; anything to do with the bloody shard;
  maggots cleaning an infected wound (antibiotics exist: see The first working items); "gross" things other than old blood and the corpse
  pile (rotting bodies, sewage, the toilet need).

## How clean water is (built 21 Nov 2026, in review; not seen by the owner)

The owner: water has a cleanliness or purity; dirty water can get you sick or infected; it can be purified
with heat, fire, chemicals or a water filter, all to be added. Every number is Claude's first guess.

- Two numbers on carried water (`water.gd`, `Water`), as in life: `dirt` (0 clear to 1 muddy: you can see
  it) and `bugs` (0 safe to 1 teeming: you can't). Clear water can still be bad. The label says how it looks
  and what has been done to it ("cloudy, boiled"), never the bugs. A bottle as found is clean.
- Each way of making it safe does what it really does, so each has a use:
  - Heat: a fire (`campfire.gd`, `Campfire`; `main.gd` `_lamp(pos, radius, true)`). Interact with water in
    your bottle and a cooking pot, and stay within 2.5 m for `BOIL_TIME` 20 s. It kills the bugs; the mud
    stays. (The pot, and fires that want wood and a match: see The first working items.)
  - Chemicals: `purify_tabs` (6). They work after `TAB_WAIT` 60 s and kill everything in clear water, but
    leave about a third of the bugs in water that is still cloudy.
  - A filter: `water_filter` (20 uses). It takes out the dirt and most of the bugs (0.15 left), not all.
  - So muddy water wants filtering and then boiling or tablets; clear water only heat or tablets.
- Filling up (`water_source.gd`, `WaterSource`, a child of the thing that holds the water, so breaking the
  thing ends it): a rain barrel (dirt 0.15, bugs 0.45) and a trough of standing water (0.7, 0.9) by the
  spawn, with a fire and a "Water kit" (tablets, filter). An empty bottle is kept, not lost.
- What dirty water does:
  - Washing a wound with it leaves `Water.wash_germs` in the wound (0.8 of the bugs plus 0.3 of the dirt)
    instead of none; over what the body shrugs off, the wound is not clean and can be worse than before.
  - Drinking it (`Player.drink_water()`, `BodyHealth.drink()`): with a chance equal to the bugs, you get ill
    in the gut. It comes on over about 90 s (Queasy, Sick to the stomach, Wretched: slower, stamina barely
    returns) and passes in about 8 minutes. While Wretched it adds slowly to the same blood poisoning a bad
    wound causes, so it can kill and never turns you. Drinking adds 25 to the water need (which doesn't
    run down yet).
- Keys: right-click the bottle among your things to drink (I opens them; it was the drink key until 21 Nov
  2026); Shift+I treats the water you carry with what you carry, the filter first and then a tablet.
- Cloud run (`tools/water_test.gd`), drinking made ill out of 400 and whether a wash leaves a wound clean:

  | Water | Nothing | Boiled | Tablet | Filtered | Filter + tablet or boil |
  |---|---|---|---|---|---|
  | Rain barrel | 180, not clean | 0, clean | 0, clean | 33, clean | 0, clean |
  | Standing water | 367, not clean | 0, not clean (mud) | 120, not clean | 49, not clean | 0, clean |

- Not built: building a fire where there is no hearth, rain filling barrels, taps, puddles and rivers, more than one bottle being treated at a
  time, water going bad again, chemicals other than tablets (bleach, iodine), filters wearing by how dirty
  the water was, zombie blood or bodies fouling a water source, food.

## The house kit (built 21 Nov 2026, in review; not seen by the owner)

The owner: parts to create modular homes with; one style for now, with several shaders to simulate the
weather, the seasons and the levels of durability; usable for houses of several rooms and levels.
Everything is in `assets/buildings/house/` (its README has the full account) and in the **Building Assets**
artifact (see Where game design assets live).

- One style: a timber house, painted clapboard outside (three paints: cream, sage, slate), plaster inside,
  floorboards, a pitched shingle roof. Laid out on a grid of 3 m cells (`HouseKit.CELL`), walls 2.6 m, a
  storey 2.7 m.
- `house_kit.gd` (`HouseKit`): `wall(a, b, storey, cells, outward)` with a letter a cell ("." solid, "W"
  window, "D" door, "O" open doorway; no `outward` = an inside wall), `floor(cells, storey, skip)`,
  `stairs(cell, storey, open)`, `basement(cells)`, `roof(cells, storeys)`, and `HouseKit.house(level, origin,
  wide, deep, storeys, wear, paint, pin, cellar)` for an ordinary house: a front door to the south, windows
  all round, rooms with open doorways, stairs in the north-west corner, a gable roof.
- Every part goes through `Solid` (rule 1): outside walls and roof wood, inside walls plaster, floors wood
  surfaces, windows the usual panes, the door a `Door`. `Solid.box` now takes a `look` (stage -> Material)
  so a part keeps its shader through the stages of damage and when a long wall is cut where it is hit.
- Four shaders (`house_wall`, `house_roof`, `house_floor`, `house_trim`) on the ground's texel grid and
  8-shade recipe, with their own ramps (`house_ramps.gdshaderinc`, from `source/gen_house_ramps.py`). Three
  things change them, with no change of mesh:
  - the season and weather: they read `ground_season`, as the ground does (wet streaks, a bleached summer,
    algae and moss in the damp seasons, autumn leaves on the roof, frost, snow lying and drifting);
  - `wear` 0, 1, 2: the breakable thing's three stages of damage (peeling paint then missing boards;
    cracked plaster then bare lath, damp and mould; missing shingles; split and missing floorboards). The
    weather only gets indoors as a house wears;
  - the cutaway (every one includes it).
  One shared material for each shader, set of values and stage (`HouseKit.mat`), so no per-object values.
- Durability is real: a house built worn (`wear` 1 or 2) has parts at 60% or 30% strength.
- `Breakable.REACH_UP` 1.9 m: anything whose underside is that far above your feet (the storey above, a
  roof, the wall over a door or window), or that is under the floor you stand on, can't be picked with the
  crosshair or beaten on by a zombie. It can still be broken by code.
- In the test level: a sound two-storey house (3 by 2 cells) with a basement, and a small derelict one
  beside it, in the north-east of the yard.
- Review sheets (software renderer; `tools/house_preview.gd`, MODE house, open or parts):
  `preview/house_seasons.png`, `house_wear.png`, `house_parts.png`, `house_paints.png`.
- Cloud run in the level: 427 breakable things now; a zombie at a kit house goes for a window; one outside
  the derelict house with the player inside was in through the window in about half a minute; a sound
  outside wall section takes about 4 hatchet blows.
- Stairs that look like stairs, and basements (owner, 21 Nov 2026; not seen by the owner). Sheets:
  `preview/house_stairs.png`, `house_basement.png`.
  - `stairs(cell, storey, open)`: two flights of 6 steps and a half landing in one cell, turning back on
    themselves, so they start and finish on the side `open` points to. That neighbouring cell must be open
    floor on both storeys with no wall between (wall kind "_"). Each step is a box of its own, open
    underneath (0.28 m thick), so one stair stands over another: a basement's under the ground floor's. The
    trim shader's `stair_run` and `stair_dir` give bare wooden treads, a pale nosing, the shadow of the
    next riser, darker risers.
  - They are real: each flight is a ramp (35 degrees) and the landing a platform, and a floor with air
    under it (upstairs, over a basement) is a solid body. So upper storeys and basements can be walked.
  - `basement(cells)`: a pit cut in the ground (`ground_pit.gd`, `GroundPit.cut(rect)`: it rebuilds the
    ground's mesh and collision as strips round the holes, from outside the ground asset), concrete block
    walls (`wall()` on storey -1; `house_wall` with `masonry`) and a concrete slab (`house_floor` with
    `concrete`; water lies on it when the ground is wet). `HouseKit.house(..., cellar)` puts one under the
    whole house with stairs down. The kit house in the level has one.
  - The ground's shader now includes the cutaway, so the ground opens over someone in a basement. (That
    is the one change to the ground asset; its artifact has it.)
  - Floors kept apart (`Enemy.LEVEL_GAP` 1.6 m of height): a shot doesn't hit someone on another floor; a
    zombie can't see, grab or bite through a floor (it goes to where it lost you); the crosshair, zombies'
    beating and vaulting only reach what is on your floor (`Breakable.in_reach(feet)`, replacing the flat
    `REACH_UP` test); part aiming is taken on the floor you stand on; no footprints off the ground.
  - Cloud run in the level (`tools/stairs_test.gd`, a body with the player's shape): ground floor 0.00,
    half landing 1.35, upstairs 2.70 and into the next room, back down, the basement's half landing -1.35,
    its floor -2.70 and across it, back up. A zombie one floor up and 1 m away on the map did not grab the
    player in 10 s; put on the same floor, it did.
- Cover and shooting between floors (owner, 21 Nov 2026: "we will have to make a rule for shooting in and
  out of storied windows. Fix the cover system upstairs and downstairs too. I don't really know so I will
  let you brainstorm"; built the same day, not seen by the owner). The rule Claude picked: **a shot is a
  straight line, and you can shoot what you can see.** Nothing special-cases windows; the building's own
  shape decides. Test: `tools/floors_test.gd`.
  - Cover has floors (`cover.gd`): every box and face has a `base` (the height of the floor it stands on:
    0, 2.7 upstairs, -2.7 in a basement) and `top` is its height above that. `Solid.box(..., floor_y)` and
    the kit pass it. Every look-up says how high its feet are (`find_near`, `find_aim`, `has_room`,
    `Box.on(feet)`), so upstairs you take cover on upstairs walls and under upstairs windows, in a basement
    on its walls, and never on another floor's. Cloud run: 456 faces on the ground, 62 upstairs, 20 in the
    basement; by the same wall, feet in the basement get a high face there, on the ground a high face, and
    upstairs the low face under the window.
  - Seeing between floors (`Player.can_see`, `line_clear`): someone on another floor is seen if a straight
    line from your eyes reaches their head or chest (glass doesn't count). Enemies ask 4 times a second.
  - Aiming and shots: the crosshair picks someone on another floor as it always did (where the camera sees
    them), but only parts a shot could reach. The shot then goes along the real line to that part
    (`Player._fire`), and a sloped shot is real geometry: it hits a body only at that body's height
    (`Projectile._at_height`) and is stopped by walls, floors and sills. (A level shot still passes over
    low cover, as before; `Projectile.SLOPED`.) Glass in the way shatters.
  - What comes of it, measured at the kit house's upstairs window:
    - From the window, standing back from it: the ground near the wall is dead ground. Nothing within
      2.5 m can be seen or hit; at 5 m only a head; from 9 m everything.
    - Leaning out: in cover at the sill and popped up (Ready), your shots skip the sill you lean over
      (`shot_skips()`), so you can shoot straight down the wall. You are then out of cover, as popping up
      always means.
    - From the ground at someone standing at the window: at 3 m only the head can be hit; from 8 m the head
      and chest. Someone 2 m back from the window can't be hit from close in, and only in the head from 16 m.
  - Height against low cover (`Cover.shields(f, at, from, rise)`): from no higher than the cover's top it
    is simply in the way; from higher, it hides someone hunkered only if the line passes under its top at
    its near face. Hunkered behind a crate: hidden from the upstairs window at 6 m and 12 m, not at 3 m. A
    wall is worth as much as ever.
  - Raiders: their sight was already a real line. Their shots at someone on another floor now go along
    the real line to the head; one popped up at low cover skips that cover. A raider at the upstairs
    window, not in cover: 0 of 10 hit the player 2 m and 5 m out, 6 of 10 at 10 m.
  - Zombies: one that can see someone on another floor (at a window above, down a stairwell) goes to where
    they are, as to a noise; it still can't grab through a floor.
  - Falling (`Player._land_hard`): a drop over `fall_safe` 2 m bruises both legs, staggers you and is
    heard 6 m; over `fall_hurt` 3.5 m it costs health. Vaulting out of an upstairs window (once the glass
    is gone) is a 2.7 m drop: bruised legs. In the test the player also landed on the window's own broken
    glass and cut a foot.
- Aiming at things above you (owner, 21 Nov 2026: aiming at upstairs windows and shooting or throwing at
  them must break them; "we might need to change the aiming system. Deliberate on this. I want a SMOOTH
  gameplay experience. Zomboid plays like junk"; built the same day, not seen by the owner). What Claude
  decided: the aiming system stays; one rule is added. **The crosshair hits what it covers.** Test:
  `tools/aim_test.gd`.
  - Why not change it: the crosshair on the floor is what makes moving, facing, the camera's lead and
    aiming at people feel the way they do, and all of that is flat. A modifier key or a "floor up, floor
    down" aim mode is what makes Zomboid clumsy; a crosshair that snaps onto walls as it crosses them would
    jerk. So nothing about the mouse, the keys or ordinary aiming changes.
  - The rule (`Player._pick_high`, `aim_high`, `aim_high_at`): the crosshair is a point on your floor, but
    on the screen it may lie over something that stands above your storey (more than `AIM_HIGH` 2.6 m above
    your feet): an upstairs window, the wall round it, a roof. That is found with one ray a frame from the
    camera to the crosshair's spot; the first solid thing or glass on it, if that high, is what you are
    aiming at. It is the same idea already used for which part of an enemy the crosshair is on. The mark
    is drawn on the thing itself, which is the same place on the screen; it turns to the red x and the
    prompt names the thing.
  - Lids and far-side windows (21 Nov 2026, with the cursor cutaway; the owner had asked how windows on the
    far side of a house could be aimed at). A lid (a roof, an upper floor, the top of a wall: any face you
    look down on) is never the target: the ray goes on through it. So from the far side of a house the
    crosshair can be put on an upstairs window in a wall that faces away from the camera, seen from behind
    through the roof, which the cursor cutaway opens. Under a lid only a window or its boards counts (not
    the wall, or the far wall would get in the way of aiming at the ground behind a house), and only if a
    straight line from you reaches it (from the wrong side of the house the near wall is in the way, so
    nothing is picked). Roofs can no longer be aimed at. Up to 12 rays on a frame that goes through lids.
    Cloud run: 4 m north of the kit house, the north wall's upstairs window was picked, the cutaway opened
    2.2 m round it, and one shot broke it; the wall beside it was not picked; from the south side, neither.
  - A shot then goes along the real line to that spot (`_fire`), a throw arcs to it (`_throw`,
    `Thrown.at_thing`): through glass, breaking it, and on to land on the floor inside (a rock lies
    upstairs, the noise is upstairs); off a wall or a roof, which takes the knock, and down to the ground at
    its foot. Glass is now found along the shot's own line (`projectile.gd`), so a sloped shot breaks it.
  - What doesn't count: anything on your own storey (aimed at level, as always, so fights indoors and in
    the open are untouched); anything the cutaway has opened up (`Cutaway.hides()`: it isn't drawn);
    anything above your own ceiling when you are indoors; an enemy under the crosshair comes first.
  - The roof is solid now (shots and thrown things hit it; nothing walks on it).
  - Cloud run, player 8 m south of the kit house: crosshair over the middle upstairs window and the wall
    between two windows picked each of them (the roof was picked too then; it no longer is); over a ground-floor window and over open ground,
    nothing (flat aim). One shot broke the upstairs window and left its glass on the ground under it. A
    rock thrown at another went through and lay on the floor upstairs; one thrown at the wall knocked it
    and lay at its foot. Indoors, and from upstairs looking down, nothing was picked.
  - Not done: the body and gun still turn toward the crosshair's spot on the floor, not toward the thing
    (the shot itself goes to the thing); no arc is shown before a throw; blind fire from cover doesn't use
    it; raiders don't aim at windows; things above you on your own storey (a high shelf, a lamp) can't be
    aimed at. (Windows that face away from the camera could not be picked when this was built; they can
    now: see Lids and far-side windows.)
- Still flat, and to be done before more than one floor plays properly (nothing here is designed with the
  owner yet): zombies and raiders have no way of finding stairs (there is no path finding); zombies notice
  someone on their own floor by distance, through walls, as before; blind fire stays on your floor; a basement is as light as outdoors; mud, tall
  grass and blood on the ground still act on someone on another floor above or below them; punches,
  shoves and finishers go by map distance; the horde's spawning ignores floors; a floor broken through
  doesn't open a hole to the floor below; zombies and raiders take no harm from a fall; no height bonus or
  penalty to aim.
- Also not done: stairs have no handrail, and a stairwell no rail upstairs; a basement has no inside walls,
  windows or hatch; window glass and the dirt under a broken floor are the old plain stand-ins; no window
  frames, gutters, chimney or porch; a worn part is worn all over, not where it was hit; a derelict
  house's windows are whole; nothing collapses; unchecked on Forward+.

## The fence kit (built 21 Nov 2026, in review; not seen by the owner)

The owner: "We will pivot back to making assets. You made dirt. Now make fences. Same design principle as
the house, just fences this time." Everything is in `assets/buildings/fence/` (its README has the full
account) and in the **Building Assets** artifact (`files/Fence/`). On `main` since 21 Nov 2026. Every
number is Claude's first guess.

- One style, timber, three kinds, each with a job of its own (rule 2):
  - `picket`, 1.0 m, painted white: low cover. You crouch behind it, vault it, shoot over it; a zombie
    climbs it and lands on its face.
  - `board`, 1.875 m, bare boards: it stops sight and bodies, nobody vaults it, and one zombie can't climb
    it, so it is beaten down or gone round. The way through is the gate.
  - `rail`, 1.25 m, posts and three rails: it hides nobody and stops no sight; about four shots in five go
    through it and the rest hit a rail. It only slows whoever has to get over it.
  - A gate (1.25 m wide) in any of them: a `Door` called a gate (`Door.noun`), opened with interact.
- `fence_kit.gd` (`FenceKit`): `FenceKit.new(level, kind, wear, paint)`, `run(a, b, gate_at, outward)` (a
  run along X or Z; gates by how far along their middle is; `outward` is the good side) and
  `FenceKit.yard(level, rect, kind, gate_sides, wear, paint, pin)` for a fence right round a rectangle.
  Each stretch between gates is one thin box through `Solid.box` (rule 1): wood, cut where it is hit, and
  it leaves splintered wood. Fences are thinner than walls: `Breakable.thin_to(share)` (picket 0.25, board
  0.4, rail 0.3 of a solid wooden thing its size), and they give half the scrap.
- `fence.gdshader`, one shader for all of it: it draws posts, pickets, boards, rails and a gate's brace on
  the box, texel by texel on the ground's grid, and discards the rest, so the gaps are real gaps. It uses
  the house's shared includes and ramps. The same three things change it as change the house: the season
  and weather (`ground_season`: wet, bleached, algae at the foot, autumn leaves caught against it, frost,
  snow on every cap and rail), `wear` 0, 1, 2 (paint peels, timber silvers, pickets and boards snap off or
  go, rails sag and fall), and the cutaway. Paint -1 bare, 0 to 2 the house's, 3 white.
- What the game needed for an open fence:
  - `Solid.open_up(body, gaps)`: the body goes on the glass layer (stops bodies, not sight);
    `Breakable.gaps` is the share of it that is air, and that share of the shots crossing it go through
    untouched, the rest stop at a rail (`projectile.gd`); `Cover.Box.open`: it is still a face to vault
    and a box to climb, but `Cover.shields()` and `Player.low_hidden_from()` say it hides nobody.
  - `_split` carries `thin`, `gaps` and `salvage_mult` to the pieces it cuts.
- In the test level: a worn-out picket front yard for the derelict house, a boarded back yard behind both
  kit houses (its gate is between them), a rail fence round the ploughed field (gate on the west).
- Review sheets (software renderer; `tools/fence_preview.gd`): `preview/fence_parts.png`,
  `fence_seasons.png`, `fence_wear.png`, `fence_paints.png`, `fence_house.png`.
- Cloud run (`tools/fence_test.gd`), a 1.2 m section, sound:

  | Kind | Zombie blows | Punches | Hatchet | Shots | A zombie with you in sight |
  |---|---|---|---|---|---|
  | Picket | 3 | 6 | 1 | 8 | climbed over in about 4 s |
  | Board | 9 | 18 | 2 | 22 | broke through in about 21 s (its gate: 24 s) |
  | Rail | 5 | 9 | 1 | 11 | climbed over in about 5 s |

  Put up damaged or about to give: 60% and 30% of that. Across the rail fence a zombie 8 m off was seen
  and 31 of 40 level shots reached it; across the board fence it was not seen and none did. The player got
  over the picket and the rail with the cover button, not the board. The level has 449 breakable things.
- Impaling (owner, 21 Nov 2026: "if its got spikes bodies can be impaled on them"; built the same day, not
  seen by the owner). Anything can have spikes: `Breakable.spikes` is the chance a body going over it sticks
  on its points (`Breakable.spiked(p, radius, feet)` finds one). Of the fences only the picket has them
  (0.3). `enemy.gd`, the Impaling exports; test `tools/impale_test.gd`.
  - A zombie climbing over rolls once as it crosses the top (the chance times 0.7 fresh to 1.3 rotted). One
    knocked off its feet toward spikes no higher than its chest (a shove, a hard hit) may come down on them
    (times `impale_shove` 1.3), on its back if it went over backward.
  - Impaled (`state` "impaled", `hung`): it hangs on the fence, hurt (`impale_hurt` 20), thrashing. It can't
    be shoved or knocked down and attacks nobody. It counts as down, so it can be finished like any downed
    one, aimed at where it hangs. Every 2.5 to 5 s it tries to pull itself off: a fresh one gets off 35% of
    the time, a rotted one 10%, and a rotted one that fails may tear a limb off. Each try shakes the fence;
    if the section under it goes, down it comes. One that dies there hangs until the corpse fades.
  - A body on the points covers them: the next one over that spot (within 0.7 m) is not caught.
  - The player vaulting something spiked catches a leg on it now and then (`vault_spike_share` 0.2 of the
    chance, doubled when Shaken): a cut and a stumble. Falling onto one (out of an upstairs window onto a
    picket fence) is a deep cut in the chest or a leg, 15 health and a long stagger, and the fence takes
    the weight. Raiders vaulting one are caught a quarter as often as a zombie (`Raider.spiked()`: hurt, a
    limp, a cry).
  - Cloud run: 14 zombies over a sound picket fence one at a time, 5 stuck; 4 pulled themselves off after
    6 s on average and 1 was still hanging after half a minute (another run: 3 stuck). 30 zombies with
    their backs to the fence knocked down backward: 9 on the points in one run, 15 in another. The player
    vaulting 60 times: caught 3, 7 and 9 times in three runs. Dropped 3.4 m onto the fence: a deep leg wound, health 100 to 85, the section broke.
  - Its pose and animation (owner, 21 Nov 2026: "Remember that being impaled as a zombie doesn't mean you
    are dead"; built the same day, not seen by the owner). `zombie_body.gd` `_pose_impaled()`, `_hang()`,
    `_hung_w`; `Enemy.heave` (0 to 1 over the 0.9 s before each try to pull free). On its front it is
    folded over the fence at the belly: legs hanging down the near side and scrabbling, chest pushed up on
    the far side, head lifted and snapping at its prey, one arm clawing toward it and the other shoving at
    the fence. On its back it is arched over the fence face up: head lifted, arms clawing the air, legs
    kicking. The whole body writhes and see-saws on the points. As a try builds, both hands go to the
    fence, the body heaves up and the legs drive; then it drops back. A fresh one thrashes fast, a rotted
    one slowly and weakly, one in rigor in jerks. Killed there it hangs limp: head and arms down, legs
    dangling. One that pulls free drags itself over and off (the last half of a climb) instead of
    jumping to the ground. Its belly sits on the points (`perch` = the top less 0.12 m).
    Sheet: `tools/preview/zombie_impaled.png`; motion: `tools/preview/zombie_impaled.gif` (made by
    `tools/zombie_fall_preview.gd` SHEET=impaled, CLIP=n for the moving picture, and
    `tools/impaled_gif.py`). Seen from the side on the software renderer; never at the game's camera
    angle or on Forward+.
  - Not built: an impaled one biting whoever comes close; blood on the points; the points showing through
    it; the player or a raider actually stuck and having to pull free; a dead body dropping when its fence goes; pushing or throwing a body onto spikes on purpose
    with a move of its own; fences made for it (sharpened stakes, iron railings).
- Not done: Forward+ unchecked (and the shadows the cut-out throws); posts are drawn, not modelled; fences
  only run along X or Z on level ground; a bullet stops at a board fence as at a house wall; a gate is a
  plain door underneath (it blocks sight to its own height even in a rail fence, has no latch or lock,
  and zombies beat on it rather than climb it); worn all over, not where hit; raiders don't reason about
  rail fences; nothing to build or mend a fence in play; no other styles (chain link, railings, walls,
  hedges).

## The street kit (built 21 Nov 2026, in review; not seen by the owner)

The owner: "Cool. Now make some streets." Made on the house's and the fences' principle. Everything is in
`assets/buildings/street/` (its README has the full account) and in the **Building Assets** artifact
(`files/Street/`). On `main` since 21 Nov 2026. Every number is Claude's first guess.

- One style: a 6 m asphalt carriageway with a concrete kerb and a 1.5 m sidewalk each side, laid as flat
  9 m tiles on a grid (three of the house kit's cells, so houses, fences and streets line up).
- `street_kit.gd` (`StreetKit`): `StreetKit.new(level, origin, wear)`; mark cells with `plan(rows)` ("#" =
  street, rows north to south), `add(cells)` or `line(a, b)`; `open(cell, side)` where a street carries on
  off the plan; `build()`. Each tile works out which neighbours it joins (`links_of`), and so its shape:
  straight, bend, T, crossroads, dead end with a rounded head. `what_at(p)`: "road", "kerb", "sidewalk" or
  "". The origin is rounded to whole metres so a tile's 81 square metres are the breaking code's own.
  `StreetKit.edge()` and the shader's `street_d()` are the same sum (the shape): keep them in step.
- `street.gdshader`, one shader for every tile (shape from `links`): asphalt with its stone showing, wheel
  paths, a dashed yellow centre line, a white crossing and stop line on every arm of a junction, a manhole
  on some straights, drain grates in the gutter, the kerb, sidewalk slabs. Its texels are the world's own,
  square to the street (as a house floor's are), not the ground's turned ones. Ramps:
  `street_ramps.gdshaderinc` from `source/gen_street_ramps.py` (numbered from 100, so one spot can be on a
  street ramp or one of the ground's). The same three things change it as change the house:
  - the season and weather (`ground_season`, using the ground's own puddle, leaf, frost and snow modules):
    wet asphalt nearly black, water in the gutters and potholes (ice in a frost, rain rings), a bleached
    summer, leaves along the kerbs, frost, lying snow with footprints in it (it reads the ground's tracks
    map);
  - `wear` 0, 1, 2: cracks and tar seals and fading paint; then crazing, potholes to the bed, weeds in
    every crack and joint (green in the growing seasons, straw after);
  - the cutaway.
  One shared material a shape, stage and weather (`StreetKit.mat`); a tile that has been broken into gets
  one of its own, with its holes in it (`holes`, 81 bits).
- What a street does (rule 2):
  - Firm in all weather: under itself it lays a new kind of ground, `bed` (packed stone and grit:
    `Ground.paint()`, `dirt_bed()` in `dirt_types.gdshaderinc`), which is never soft. So no mud and no
    prints on a street, and nothing follows a trail along it; in lying snow it takes prints like anywhere.
  - Open: no cover, nothing to hide in.
  - Pavement (rule 1): each tile is a `Solid.surface` ("street", asphalt), broken up a square metre at a
    time; the square metre is cut out of the tile (ragged) and the bed shows. `Breakable.on_shape` keeps
    the corners of a tile that aren't street out of it; `Breakable.thin` makes a worn street weaker.
  - Water stands in its gutters and potholes in rain (the look only: it does nothing yet).
- In the test level the cul-de-sac's plain asphalt and turning circle are gone: a cracked street (wear 1)
  runs four tiles north from the gap in the yard's wall to a crossroads with a dead end west, east and
  north. It is centred on x -0.5 (tiles are whole metres).
- Review sheets (software renderer; `tools/street_preview.gd`, MODE shape, scene, plan or town; HOLES=1):
  `preview/street_shapes.png`, `street_seasons.png`, `street_wear.png`, `street_town.png`.
- Cloud run (`tools/street_test.gd`): a plan of 13 cells worked itself out as 5 straights, 3 bends, 3 dead
  ends, a T and a crossroads. Walking 10 m: dry, no prints on the street or beside it; in rain, none on
  the street and 8 on the bare ground beside it; in lying snow, 14 on each. A square metre: 10 sledgehammer
  blows laid sound, 6 cracked, 3 breaking up; fists get nowhere; 3 rocks left; the crosshair then finds
  nothing there. The level has 8 street tiles and 455 breakable things.
- Lamps and signs (owner, 21 Nov 2026: "Now make street lamps and signs"; built the same day, on `main`
  since 21 Nov 2026, not seen by the owner). In the same
  kit: `StreetKit.lamp(p, on)`, `signpost(p, face, toward, says)` ("stop", "name", "warning"; `sign` is a
  built-in name), `name_sign(p)` (two blades), and `furnish()`: a lamp on each straight on alternate sides,
  a stop sign facing what comes in on every arm of a junction, a name sign at its corner, a warning where
  a dead end begins. Test `tools/lamp_test.gd`; sheets `preview/street_props.png`,
  `street_furnished.png`.
  - A lamp: a steel post (3.5 m, a `Solid.box`, "lamp post") with a glass lantern on top (its own body on
    the glass layer, a `Breakable` "street lamp", `lets_shots`). Lit, it is a `Daylight` lamp (8 m) and an
    `OmniLight3D`: at night whoever stands in it is seen from as far as by day. The lantern is above your
    storey, so the crosshair picks it by the "hits what it covers" rule: a shot or a thrown rock breaks
    it, `Daylight.remove_lamp()` puts the light out, and its glass falls to the ground under it. The
    post's `broke` takes the lantern with it. Power is a stand-in: `StreetKit.lit` (true), and one put up
    worn out (wear 2) is dark.
  - A sign: a thin steel post (a `Solid.box` named by its face) with a plate that is only drawn (it goes
    with the post). `StreetSign` (`street_sign.gd`, an interactable) reads it out: "STOP", "Dead end",
    "Cedar Lane / Maple Street" (`StreetKit.names`). It is no cover, and it rings when hit (metal, 11 m):
    a noise made on purpose without a shot.
  - `street_prop.gdshader`: posts, the lantern (frame, cap, glass glowing when lit), sign faces (a stop
    sign's corners and a warning's diamond are cut away); wet, frost and snow on caps; wear rusts posts,
    fades paint, shoots holes in signs, breaks the lantern's glass. New ramps: steel, red, sign green, glow.
  - `fog.gd` now sends the shader the 8 lamps nearest the player when there are more (picked twice a
    second), and resends when one goes out (`Daylight.lamps_rev`).
  - In the test level: `street.furnish()`: 4 lamps, 4 stop signs, a name sign, 3 dead-end warnings. The
    old plain "street sign" box by the yard's gap is gone. 7 lit lamps in the level now; 470 breakable
    things.
  - Cloud run: at night the light under a lamp is 1.00 and you are seen from the full daytime distance;
    in the dark of the crossroads 0.08 and 0.36. Its light: full to 2 m, 0.86 at 4 m, 0.33 at 6 m, gone
    by 8 m. One shot from 7.5 m with the crosshair on the lantern broke it: light out, 1 glass under it,
    post standing. A rock from 6.5 m did the same. A lamp post: 3 sledgehammer blows, 18 hatchet, about
    330 zombie blows; its lantern went with it and left metal and glass. A sign post: 2, 9, about 165.
    A sign punched once: zombies 5 m and 9 m off turned to it, one at 14 m did not.
  - To come with sound (owner, 21 Nov 2026: "When we make sounds we will make it so you can shoot the
    signs"): a sign's plate is to be something a shot hits, with its own ring. Not before there are sounds.
  - Not done: power (no grid, no flicker, nothing switches a street off); the lit look was only rendered
    with the daylight turned down, not with the game's darkness; a plate can't be hit or taken on its
    own and shots pass through it; signs face the four ways only and show marks, not letters; raiders and
    zombies make nothing of lamps beyond the light; no hydrants, benches, bins or parked cars.
- Not done: Forward+ unchecked; it is flat (the kerb is drawn, not raised); north-south and east-west
  only, one width, no curves, lanes or parking; the whole tile breaks as pavement (a sidewalk slab is as
  hard as the carriageway); footsteps are no louder on it; potholes and puddles do nothing to whoever walks in them;
  worn all over, not where used; weeds are drawn, not grown; two streets side by side join into one slab;
  the cars were left where they were.

## The furniture kit (built 21 Nov 2026, in review; not seen by the owner)

The owner: "make some furniture for the home you designed". Everything is in
`assets/buildings/furniture/` (its README has the full account) and in the **Building Assets** artifact
(`files/Furniture/`). On `main` since 21 Nov 2026. Every number is Claude's first guess.

- Eleven pieces, one plain household style: couch, armchair, table, chair, kitchen counter (any length),
  stove, fridge, bed, wardrobe, dresser, bookshelf.
- `furniture_kit.gd` (`FurnitureKit`): `FurnitureKit.new(level, wear, stain, fabric)`, `put(kind, at,
  facing)` (`at` is the middle of the piece on its floor, y the floor's height), `counter(a, b, floor_y,
  facing)`, and `FurnitureKit.furnish(level, house_origin, storeys, wear, stain, fabric, pin)` for the
  ordinary 3 by 2 `HouseKit.house`: a living room inside the front door, a kitchen in the east room, a
  dresser in the back room, two bedrooms upstairs. `KINDS` has each piece's size and what it is made of;
  `LATER` what it is meant to do once loot, sleep and food exist (none of that is built).
- A piece is a few boxes joined into one mesh (`mesh_of`, built once a kind and shared): UV is the spot on a
  face, UV2 the face's size, COLOR.r the part the face plays, COLOR.g a number of its own.
  `furniture.gdshader` paints by part: boards, drawers, doors, shelves of books, upholstery, sheet,
  blanket, pillow, cast iron (with the fire behind the stove's door), enamel, worktop, cupboards. Ramps:
  the house's, and eight of its own from 16 up (`furniture_ramps.gdshaderinc`,
  `source/gen_furniture_ramps.py`). One shared material for each wood, cloth, stage and weather.
- Rule 1: each piece is a `Solid.box` round the whole of it (Solid's own plain mesh is hidden; the piece's
  mesh is a child), so it is cover on its floor and breaks like anything. `thin_to` makes furniture lighter
  than walls; a piece breaks whole (no splitter). New material `cloth` (`materials.gd`: soft, chopped not
  pounded, it rots) with its scrap `cloth_scrap`, "Torn cloth" (`items.gd`): couch, armchair and bed are
  wood and cloth. The fridge is steel and plastic, the stove cast iron.
- Rule 2, what works now: low pieces (everything but the fridge, wardrobe and bookshelf) are low cover to
  crouch behind and vault, and a zombie climbs them; the three tall ones are high cover and stop sight; a
  stove put down not worn out has a `Campfire` on it, cold until wood is laid on it and lit (see The first
  working items), and then water boils on it and its door glows. Each body carries
  the meta "furniture" (its kind) for the systems to come.
- What changes the look: `wear` 0, 1, 2 (scuffs, fading, books and a drawer gone; then cloth torn to the
  stuffing, drawers and doors out, rust); the season, but indoors only the damp and only on a worn piece
  (mould in the wet and the cold); `stain` (pine, oak, walnut) and `fabric` (brick red, olive, blue); and
  the cutaway, where furniture stands while you are indoors as the stairs do (`cutaway_hidden_standing`).
- In the test level: the sound kit house is furnished on both floors; the derelict one has a worn-out
  couch, table and dresser. 490 breakable things.
- Review sheets (software renderer; `tools/furniture_preview.gd`, MODE pieces, backs or house):
  `preview/furniture_pieces.png`, `furniture_wear.png`, `furniture_colours.png`, `furniture_house.png`.
- Cloud run (`tools/furniture_test.gd`), zombie blows to break each sound piece: chair 2, armchair 4,
  dresser 5, table 6, counter 7, bookshelf 8, couch 9, wardrobe 11, bed 15, fridge 315, stove 600. A
  wardrobe put down sound, damaged, about to give: 11, 7, 4. Hunkered in front of the couch you are hidden
  from across it; the fridge stops sight, the table doesn't; a zombie with a chair or the kitchen table
  between it and the player climbed over in under 3 s; water put on the kitchen stove, once it had wood, a
  match and a pot, had boiled 20 s later. The stairs, floors and aiming tests still pass in the furnished house.
- Not done: Forward+ unchecked; nothing can be sat on, slept in or cooked on (five pieces can be searched
  now: see Searching and the grid); nothing can be
  pushed, tipped or stood on (no blocking a door with a wardrobe); the stove gives no light or warmth; no bathroom, and no small things (lamps, rugs, low tables, a television); what
  you walk into is one box round the piece (no stepping between a chair's legs, no seeing under a table);
  one size of each; `furnish` only knows the 3 by 2 house and leaves the basement empty; worn all over,
  not where hit.

## Themed item batches (owner, 21 Nov 2026; nothing built yet)

The owner will name a theme (a room: a boy's room, a girl's room, a bathroom, electronics...) and give a
number of items. Each theme is done in four sessions, one kind of thing each, in this order:

1. Clothes
2. Furniture
3. Appliances
4. Miscellaneous: books, music, movies, toys, trophies, anything that belongs in that room.

What the owner said to keep in mind (21 Nov 2026):

- Even trash can be recycled and used. Nothing is junk with no use: an empty tin, a wrapper, a broken toy
  breaks down into something (scrap, a material, a part).
- Anything that can be held in one or two hands is also a weapon, but most things don't last long at all
  being smacked against someone's head. So every holdable item needs how it hits and how quickly it breaks
  doing so, and what it breaks into.
- Clothes can be worn, torn, tied, and turned into makeshift things: rags, strips to tie with, a molotov's
  wick. That is why it is done in batches: each kind has its own uses to work out.

So each item made in a batch carries, besides what every item has now (`name`, `w`, `cat`, `size`, `rare`,
`found`, `for`, a picture recipe in `ItemArt.ART`): how it does as a weapon if held (one or two hands, the
kind of blow, how hard, how many blows before it breaks); what it breaks or is taken apart into; and for
clothes, where it is worn, what it keeps out (cold, bites, glass, a blow) and whether it has pockets, and
what it can be torn or tied into. Furniture and appliances in a batch are made with the furniture kit's
principles (rule 1 and rule 2, `Solid`, a `Stash` if things are kept in it). What the batches share is built
(see Held weapons and taking apart): every item now also gets `hit`, `apart` and, if it is a tool, `does`.

First theme (owner, 21 Nov 2026): a middle-class living room. No number of items given yet. Claude's proposal
for how clothes are worn, sent to the owner the same day and waiting for an answer (build no clothes before):

- Layers by body area: head; neck; torso under (t-shirt), mid (sweater, hoodie, cardigan), outer (jacket,
  coat); legs under and outer; feet socks and shoes; hands; the back (bags, as now); a belt at the waist.
- Slots come from what you wear: pockets from the clothes (jeans 4 small, a hoodie's pouch, a coat's 2 to 4),
  belt slots only with a belt on. Hands are always there. So a new character starts in clothes.
- Each garment: warmth (for the warmth need to come), and against bites, glass and cuts, and blows, per body
  area, layers adding up; a stopped bite tears the cloth, and holes add up until it protects nothing. Dirt,
  wet and blood on it. It tears into rags, strips to tie with (a splint, a tourniquet, a wick), or gets taken
  apart.
- On the character: close-fitting clothes painted by the body shader as layers; bulky things (coats, hats) as
  simple shells later. Not settled.
- Draft list for the living room (12): slippers, wool socks, sneakers, sweatpants, jeans, t-shirt, hoodie,
  cardigan, dressing gown, winter parka (hall closet), knit beanie, wool scarf.

## Held weapons and taking apart (built 21 Nov 2026, in review; not seen by the owner)

The plumbing every themed batch needs (owner: anything held in one or two hands is a weapon, most things don't
last long against a head; nothing is junk, everything comes apart into something). On the session branch only.
Every number is Claude's first guess. Test `tools/melee_test.gd`; sheet `tools/preview/held_weapons.png`.

- Item fields (`items.gd`, documented at the top): `hit` (hands, kind blunt/chop/pierce, force, smash and
  breaks for things, reach, time, lasts, into, noise, look), `does` (what it serves as a tool for: "blade",
  "hammer", "pry"; `Inventory.tool_for()`), `apart` (into, tool, time, noise). A carried thing that has been hit
  with keeps `hits`. `Items.about(id)` is the `for` sentence plus how it does as a weapon and what it comes
  apart into, in words; the character page and the loot screen show it. The label says "worn", "about to go".
- Weapons now: hatchet, sledgehammer, hammer, crowbar, hand torch, burning torch, cooking pot, plank, rock,
  bottle, and a new item, the broken bottle (pierce, 5 blows, it cuts: `does` blade). A bottle breaks on the
  first blow and you are left holding the broken bottle.
- How it plays (`player.gd`): no new slot on the wheel. The Hands slot swings whatever weapon is in your right
  hand, else your left (`wield()`); the wheel and the status name it ("Plank, one-handed"). Two-handed with the
  other hand full, or one arm, is swung one-handed (`one_hand_force` 0.6, `one_hand_slow` 1.35). Its own pace
  (wind-up 40%), stamina by weight. Shoving and the guard work as before.
- Part picking for all hand-to-hand, punches included (the owner's "punches using the part picking"): the blow
  goes to the part the crosshair is on if that one is in reach (`blow_part_chance`: head 0.7, limbs 0.75 to
  0.8, times Dexterity and aim; otherwise the body), else the nearest in front, at the body. The prompt names
  the part, the weapon and the odds in words. `Enemy.take_blow(part, force, how, dir)`: the head is a skull
  to crack (`SKULL_BLOW` 40 is a sound skull's worth, rot softens it, a chop 1.25 and a point 1.5 times as
  good), a blunt blow there may knock it down; the body takes damage; a chop on a limb may take it off, a club
  on a leg may put it down. Raiders take double in the head, nothing more yet.
- Wear (`wear_weapon`): each blow that lands (on someone or on a thing) is a knock; at `lasts` it breaks, the
  remains (`into`) go to your feet, or into your hand if they are a weapon. `break_tool` now considers what is
  in your hand (a plank on a crate) besides a hatchet or sledgehammer carried anywhere, and wears what it used.
- Taking apart (`Player.take_apart(key)`): Shift+Enter on the character page, Shift+right-click on a slot in
  the loot screen. Standing still, weapon down, for its time; moving, Ready, a grab or a hit stops it and
  nothing is lost. A bag must be empty. Now: plank (needs a blade: 3 splintered wood), bottle (smashed: a
  broken bottle and glass, heard 9 m), broken bottle, hand torch, water filter, helmet, backpack.
- In the hand: a plain bar on the hand's bone (`PlayerBody.hold_in`, `GRIP_AXIS` found by render), coloured
  from the item's ink. Ready it is held up over the shoulder, drawn back over the head in the wind-up and
  brought down in front; a two-handed thing gets the other hand on it.
- Cloud run, blows to put a zombie down at Strength 10, aimed at the head (fresh / half / long rotted): fists
  25, 14, 12; bottle then broken bottle 8, 5, 2; hammer 7, 4, 2.5; crowbar 5, 3, 2.7; plank 6, 4, 3 (it broke
  in 2 of 6 fights with fresh ones); hatchet 2.3, 2.2, 1.5; sledgehammer 3.2, 1.5, 1.0. The hatchet took a
  half-rotted arm off at the third blow; a crowbar on a fresh leg put it down 15 times in 20. A plank read
  "worn" at 3 blows, "about to go" at 5, broke at 6 into 2 splintered wood. Taking a plank apart took 6.0 s.
- Not built: a pose of its own per weapon (one overhead swing for all), the weapon's real look (a bar), what
  it hangs like with the weapon away (it sticks out sideways from the hand), a hatchet sticking in and needing
  a yank, a freeze on contact, sounds, raiders with weapons, the left-hand grip checked by render, part picking
  for finishers beyond what they had, a click during a swing remembered for the next.

## The first working items (built 21 Nov 2026, in review; not seen by the owner)

The owner: "Take into consideration what we need as far as items go to get some of the talked about
functionality going and start there. Afterwards I will give you themes (boys room girls room bathroom
electronics etc) and you will generate a set number of items per theme." So this batch is only the things
that switch on what was already built or promised and was waiting for an item. On `main` since 21 Nov 2026. Every number is Claude's first guess.

- An item's record (`items.gd`, `Items.DEFS`) now has: `name`, `w`, `cat` (medical, tool, material,
  clothing, food, thrown, scrap), `stack` or `uses`, `keep` (still a thing when used up), `wear` ("feet",
  "head"), `found` (the kinds of place it turns up in, for the loot tables to come: kitchen, bathroom,
  bedroom, living room, garage, yard, shop, anywhere; `Items.found_in(place)`), and `for` (what it is for,
  in a sentence the player reads on the character page). 35 items with the backpack; `size` and `rare`
  came with searching. An item with nothing in the game to use
  it doesn't go in (rule 2 holds for things you carry). The themed batches must fill in all of these.
- What each new one switches on:
  - `hammer`, `nails` (a box of 20), `plank` (stack of 4): boarding a window. P at a window by the
    crosshair, standing at it (`Player.work_window()`): 2 planks, 4 nails, `board_time` 6 s of standing
    there; every hammer blow is heard 12 m. Walk off, be grabbed or be hit and nothing is used.
  - `crowbar`: at a boarded window P prises the boards off in 3 s, heard 4 m, and you keep the planks.
  - `boots`, `helmet`: worn (`Inventory.worn`, places "feet" and "head", `wear()`, `take_off()`). Boots end
    `barefoot`. A helmet takes a head hit from 75 to 30 of 100 health. Nobody starts with either. What you
    wear lies with your body when you die. Not drawn on the character (no clothes on the model yet).
  - `matches` (10), `cooking_pot`, and wood (`Items.FUEL`: splintered wood 240 s, a plank 480 s): a fire is
    real now (`campfire.gd`). A stove is cold: lay wood on it, light it with a match, feed it or it burns
    out (`fuel`, `lit`, signal `changed`; the stove's door glows while it burns). Water only boils with a
    pot. The level's camp fires are `kept` (somebody else keeps them in: always alight), a stand-in.
  - `battery` (a set; stack of 4): the hand torch has 600 s of light in it, drained a second at a time
    while lit; flat, it wants a fresh set.
  - `canned_food` ("Tin of beans") and `can_opener`: a tin is `meal` 45 of the food need; hacked open with
    a hatchet half is lost and it is heard 6 m; with neither it stays shut.
  - `antibiotics` (6): for `abx_time` 300 s a wound that isn't filthy mends (three times as fast, dressed
    or not) and a filthy one worsens at a quarter of the pace (`BodyHealth.take_antibiotic()`). Nothing
    against a bite. Painkillers and steroids can now be taken outside the treatment screen too.
  - `cloth_scrap` (from couches and beds): washed in water clean enough for a wound it becomes a
    `clean_rag` (`Player.wash_cloth()`); a wash of the bottle each.
- Food and water run down (`CharacterSheet.RUNS_DOWN`, `needs_rate` set from `Player.day_seconds` 10800: a
  game day of three real hours, the middle of the owner's 2 to 4). Over a day food falls 96 of 100 and
  water 144, so about two tins and six drinks a day. Rest does not run down: there is nowhere to sleep.
- Using and dropping (`Player.use_item(key)`, `drop_item(key)`): the character page (C) is now two columns,
  who you are on the left, and on the right your body, what you carry and wear a slot to a line, and your
  conditions. PgUp PgDn reach the carried rows; the picked thing shows what it is for; Enter uses it (eats,
  drinks, wears, takes a pill, loads batteries, washes cloth, lays glass), Delete puts it down at your feet
  as a small pickup. A stand-in until the loot screen. Sheet: `tools/preview/items_page.png`
  (`tools/items_preview.gd`; the page only: the level behind it is black in the cloud).
- Keys: P boards or prises (Shift+P the old free boarding); U boots on and off (Shift+U the old test
  switch); I is now your things (see Searching and the grid), Shift+I treats water as before.
- In the test level: a "Carpenter's box" (hammer, nails, 4 planks, crowbar) and "Boots and a helmet" by the
  spawn; batteries in the tool box; antibiotics in every first-aid box; "Kitchen things" (pot, matches, 3
  tins, tin opener) by the kit house's stove.
- Cloud run (`tools/items_test.gd`):
  - Boarding took 6.0 s and used 2 planks and 4 nails; a zombie 10 m off heard it and one 15 m off did not.
    The boards stand 9 zombie blows. Started and left after 2 s: nothing used. Prised off in 3.0 s: heard
    at 3 m, not at 10 m, planks back.
  - In boots, 3 shards were still there after 60 footfalls, no wounds; boots off, they were in the feet
    within 7.
  - The stove: cold and useless with nothing; wood laid, "it wants a match"; lit; no pot, no boiling; with
    a pot the water had boiled 20 s later; one piece of splintered wood burned 240 s and it went out.
  - A torch lit 10 s used 10 of its 600; run flat it went out and read "flat"; a set of batteries filled it.
  - A minute standing: food 99.58 to 99.04, water 99.37 to 98.57, rest unchanged. From food 30: no opener,
    nothing; hatchet, 52; tin opener, 98.
  - An arm wound that has taken hold: never washed, fully infected at 65 s, or at 233 s on antibiotics;
    washed once and left open, fully infected at 91 s, or clear of it at 70 s on antibiotics.
  - Standing water won't wash cloth; a clean bottle made two rags for two washes. Rags put down lay at the
    player's feet and were picked up again. Dying in boots left them with the body.
- Not built, and why: guns, magazines and rounds (to be designed together); using a thing on a wound outside
  the treatment screen; cooking, spoiling, more than one food; clothes beyond boots and a helmet, and any
  of it showing on the character; a boarded window costing more planks for a bigger window; raiders using
  any of it; warmth and light from a fire you lit; the weight you carry feeding the WT number.

## Searching and the grid (built 21 Nov 2026, in review; not seen by the owner)

The owner, after the first items: "dont forget that cupboards and dressers need search functionality as well
as drawer renders for the inventory grid view. Drawers. Etc." Built to the owner's sketch and their answers
on it (see Loot). On `main` since 21 Nov 2026. Every number is Claude's first guess.

- What can be searched (`stash.gd`, `Stash`, a child of the piece: `FurnitureKit` puts one on each): a
  dresser (three drawers, 6 by 3 squares each), a wardrobe (hanging rail 5 by 5, top shelf 5 by 2), a
  kitchen counter (drawer 6 by 2, cupboard 6 by 4), a fridge (shelves 4 by 4, freezer box 4 by 2), a
  bookshelf (shelves 6 by 4). `Stash.KINDS` has them; a new piece of furniture that holds things is one
  line there. Interact with it, weapon away.
- What is in a part is rolled the first time anyone looks in it, from `Items.found_in(place)` for that
  piece's kind of place (dresser and wardrobe: bedroom; counter and fridge: kitchen, the fridge only food
  and drink; bookshelf: living room), each thing part used or part of a stack (`Stash.found_item`). A new
  item field `rare` (0 to 1) makes a thing turn up less (a backpack 0.25). A piece put down damaged or
  worn out has been picked over: 0.6 and 0.3 as much. Nothing refills.
- The grid (`item_grid.gd`, `ItemGrid`: plain data, `{"w", "h", "things": [{"item", "x", "y", "z"}]}`).
  Every item has a `size` in squares (`Items.size_of`; small 1 by 1, a bottle 1 by 2, a hatchet 1 by 3, a
  plank 1 by 4, boots 2 by 2, a sledgehammer 2 by 4). Things lie on each other as they were left (`z` 1,
  the owner's layered clutter; 4 in 10 found things try to): what is under something can't be seen or
  taken until the thing on it is moved (its edge is dashed gold). What a person puts down only goes where
  there is clear room.
- Searching (`Stash.search`, `found` 0 to 1 a column): a part nobody has been through is dark. The column
  your hand is over is gone through, `search_time` 3 s a column, and the drawer's own picture is the meter:
  it comes up out of the dark from the front. When a column is done, what lies wholly in searched columns
  shows. Shift hurries (`hurry_mult` 3) and is heard `hurry_noise` 8 m, twice a second. Wisdom stands in
  for the searching skill (3% a point). A part once searched opens at once from then on.
- It costs your view (`Player.searching`, `search_sight` 7 m ahead, `search_near` 1.2 m round you, against
  40 and 3); ALT looks up, your hands stop and the screen fades. A step, being grabbed, being hit, or the
  piece being broken shuts it; so does Esc or I.
- The screen (`loot_screen.gd`, `LootScreen`, `hud.loot`): the lower 60% of the screen, the world still
  showing above. Left: your eight slots, what you wear, and the grid of the bag on your back. Right: the
  piece, its parts as tabs (1 2 3), the open part drawn as itself with the grid over it. The hand is the
  screen's own pointer (the mouse is captured). Drag a thing to a slot, a square, your feet, head or back,
  or up out of the panel to put it on the ground; double-click sends it across; right-click uses what is in
  a slot (`Player.use_item`) or says what a thing is for. The line at the bottom names what the hand is
  over. I opens it with nothing on the right: just what you carry.
- The drawer renders and the icons (`item_art.gd`, `ItemArt`): made by code, 16 texels a square, shown big
  with no smoothing. `backdrop(look, stain, w, h)`: "drawer" (from above: sides, bottom boards, a handle),
  "cupboard" and "shelf" (from the front, a shelf every two rows), "rail" (a wardrobe: a steel rail with
  hangers), "fridge" (enamel, a wire shelf, the lamp), "freezer" (frost), "bag" (canvas, stitching, a zip),
  dithered on 8-shade ramps; the wood is the piece's own stain. `icon(id)`: each item is a short recipe of
  shapes in `ItemArt.ART` (box, round, bar, any shape, flat mark, cut), shaded and outlined by the code,
  so a new item's picture is one line; one without a recipe shows as a parcel. The themed batches must
  give every item a `size` and a recipe.
- A backpack (`backpack`, worn on "back", `hold` 6 by 4; in the box by the spawn with the boots and
  helmet): its grid is on the item itself (`Items.hold_of`), so it keeps what is in it when it is taken
  off, dropped or left on your body. What no slot will take goes into it when you pick things up
  (`Inventory.add`). What is in it can't be used until it is in a slot (`inv.has` only looks at slots): a
  bag is storage. No bag goes in a bag. It weighs what is in it.
- Breaking the piece (rule 1): what was in it, searched or not, lies on the floor as a pickup ("What was in
  the dresser").
- Review pictures (the screen is 2D, so these are as it will look; the level above it is black in the
  cloud): `tools/preview/loot_search.png` (a dresser, four columns in), `loot_screen.png` (dresser, fridge,
  wardrobe, cupboard), `loot_drawers.png` (every backdrop), `loot_icons.png` (every item). Made by
  `tools/loot_preview.gd` (MODE icons, backs, screen).
- Cloud run (`tools/search_test.gd`):
  - In the level: 4 dressers, 2 bookshelves, a wardrobe, a counter, a fridge. Over 200 rolls a sound
    dresser holds about 10 things in its three drawers, a wardrobe 7, a counter 7, a fridge 4, a
    bookshelf 4; about a quarter lie on something. Worn out: 3, 2, 2, 1, 1, and some parts empty.
  - A six-column drawer took 18 s carefully and was not heard at 6 m; 6 s in a hurry, heard at 6 m and
    not at 11 m. Things showed as their columns were done.
  - Searching, sight was 7 m ahead and 1.2 m round; ALT gave back 40 and 3.
  - A double-click took a bottle; a drag put it back in a clear square; a drag up out of the panel left
    painkillers on the ground. Boots lying on antibiotics hid them until the boots were dragged aside. A
    column not yet looked in took nothing.
  - A step shut it; back at it the prompt was "Look in the dresser" and nothing was left to go through. A
    hit shut it.
  - With a backpack on, eleven kinds of thing picked up: eight slots filled and the pot, tins and water
    went in the bag. The bag came off into a free hand with its 3 things in it. Dying left it with the body.
  - A bookshelf chopped up left its 2 things on the floor.
- Stand-ins and not built: the pool is thin until the themed items exist (a bedroom's is eight things, so
  dressers hold needles and painkillers); things are placed at random, not as a person would (clothes
  hung, tins on a shelf); no junk items to be the clutter (any found thing may lie on another); your view
  shrinks to a short cone, not a drawn "behind you: unseen" as in the sketch; the hand doesn't shake;
  searching has no pose (you stand at it); zombies and raiders don't search or take; nothing is locked;
  beds, couches, cars, bins and bodies can't be searched; a stack can't be split; things can't be turned
  to fit; the slots on the left are a list, not laid out on a body; time does nothing to what is in a
  stash; the fridge keeps nothing cold. In headless tests the screen needs `root.size` set.

## Small rules the owner has set (20 Nov 2026)

- The mind goes with the body (owner: zombies follow tracks too, but "the more they rot they lose the ability
  to follow tracks, they move slower and they generally just follow movement and noise... the brain is
  deteriorating as they decompose. Essentially fresh walkers should be more dangerous than long decayed ones").
  Built the same day, untested on the owner's PC. `ZombieBody.wits`: 1 until a quarter rotted, 0 from about
  two thirds, worked out once in `refresh()` like the rest of its decay.
  - Tracks (`Enemy._read_tracks()`, looked at every 0.8 s by one that isn't chasing): with wits of 0.3 or
    more it takes up your prints from `track_nose` 4.5 m times its wits, no older than `track_fresh` 200 s
    times its wits, and goes along the trail a few prints at a time (`Ground.trail_ahead()`). At each step it
    may lose the thread, with a chance of 1 minus its wits. Where the trail ends it carries on the way it was
    going. Crawlers don't track. It needs no light (raiders do).
  - Speed (`walk_mult`): 1.2 fresh down to 0.6 rotted (was 1.0 to 0.65).
  - Movement (`_still_factor()`): a rotted one notices someone standing quite still from only `still_notice`
    0.35 of its range (4.2 m instead of 12); a fresh one sees you either way. Noise works on all of them.
  - Cloud run, 12 zombies beside the start of a 26 m trail in snow, the player standing still at its end:
    fresh, 8 took it up and 8 reached the player within 45 s; half rotted, 10 and 10; long rotted, none took
    it up and none moved more than a few metres.
  - With the earlier rules (fresh ones have more health, harder skulls, are harder to knock over and get
    straight back up) a fresh zombie is now the dangerous one on every count.

- Zombies linger when you look away: one that leaves your view stays drawn for `linger_time` 1.2 s (you remember
  where it was) and then fades over 0.9 s; it has moved on by then. Fading in is still quick. (`enemy.gd`.)
- Zombies are tougher the fresher they are, on three counts (`enemy.gd`, Toughness): health 1.7 to 0.85 times
  `shambler_hp`, how much of a blow reaches the skull 0.55 to 1.4 (so a fresh one takes 3 stomps at Strength 10
  and a rotted one 2), and how easily it is knocked over 0.3 to 1.8 times `knockdown_chance`. Raiders were left
  as they were: the owner said dying easily is fair while everyone is naked.
- Doors open and close on a click (interact, weapon away). Walking or running into one does nothing. Only a bash
  opens one by force: a dash into it by a character strong enough. Bashing is to be an ability strong characters
  unlock or learn; until abilities exist `Player.can_bash()` is Strength 13 or more (`bash_strength`). A shut door
  stops zombies and raiders: they press on it like a wall.
- Still to settle (owner): what clicking on things does with the weapon Ready and with it away.

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
- Ground assets (dirt, grass, seasons): the **Ground Assets** artifact,
  https://claude.ai/artifact/UJoHeBzm47cZoGwVgMa3xU (`files/Ground/`; in review). The same files as
  `assets/ground/`.
- Building assets (the house kit, the fence kit, the street kit and the furniture kit): the **Building
  Assets** artifact, https://claude.ai/artifact/T6hgheyYpqh5JaiJSvoCwr (`files/House/`, `files/Fence/`,
  `files/Street/` and `files/Furniture/`; in review). The same files as `assets/buildings/house/`,
  `assets/buildings/fence/`, `assets/buildings/street/` and `assets/buildings/furniture/` (the harnesses
  are in `tools/`).
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
- Crawl: zombies missing a leg always crawl. Any zombie can be knocked down (hard hits, shoves). (Crawling
  under obstacles waits for low obstacles in the level.)
- Going down (owner, 20 Nov 2026: they always fell on their stomachs, and most intact ones should get back up
  before giving up and crawling; untested on the owner's PC). `Enemy._knock_down(push)`: one on its feet sent
  backward lands on its back (`on_back`: face up, head away from the way it faces), otherwise on its front; a
  body killed on its feet falls the same way. It lies stunned (`stun_time` 0.8 to 2.4 s, longer rotted). Then,
  with both legs, it mostly gets straight up (`getup_first` 85% fresh to 55% rotted; from its back it sits
  up); otherwise it crawls at you first for `down_time` (rolling onto its front if need be: `roll_time` 0.8 s,
  after which it lies the other way round and turns to you). A get-up can fail (`getup_fail` 5% fresh to 35%
  rotted) and over it goes again; after `give_up_after` 2 failures it gives up and crawls for twice as long
  before trying again. A leg gone means a crawler for good. Finishers, part aiming and `aim_point()` know which
  way round it lies. Cloud run, 32 each: fresh, 26 got straight up and all 32 were standing within 30 s (4.7 s
  on average); rotted, 17 straight up, 7 failed get-ups, 22 standing within 30 s (10.1 s). Poses
  (`zombie_body.gd` `_back_w`): the back fall pivots at the feet and sprawls like the dead. Sheet:
  `tools/preview/zombie_falls.png`, made by `tools/zombie_fall_preview.gd` (a copy of the asset's animation
  harness with a "falls" sheet; the approved asset's own harness was left alone). `zombie_body.gd` is the
  game's script, not part of the approved model.
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
- Aiming at a part (owner, 20 Nov 2026; built the same day, untested on the owner's PC). The cursor is the
  ring (white Ready, grey with the weapon away; it no longer hides with fists Ready). The owner tried a small
  grey x for it and changed their mind the same day: the ring stays, and Ready it switches to a red x on an
  enemy or on something that can be broken (see Breaking things). The
  part of the enemy it is on is where the shot is likeliest to land. `Enemy.part_points()` gives where the six
  parts are (standing up, or lying along its facing); `Player._update_hover()` takes each part where the camera
  sees it against the ground (the camera never turns) and picks the nearest within `hover_radius` 0.34 m
  (`hover_target`, `hover_part`). The gun turns to whoever the crosshair is on, so a shot at the head goes at
  the zombie and not over it. `Player.part_chance(part, dist)`: a base by part (head 0.22, body 0.7, arm 0.3,
  leg 0.38) times Dexterity (4% a point) and the sheet's aim, times `gun_accuracy`, times range (1.8 at arm's
  length down to 0.35, over `accurate_range` 10 m times the gun times `scope_mult`). At DEX 10: head 36% at 2 m,
  27% at 7 m, 13% at 15 m; body 95%, 87%, 42%. Guns and scopes as items are to set `gun_accuracy` and
  `scope_mult`. A shot that doesn't land where it was aimed lands elsewhere on them, mostly the body
  (`Projectile.stray_part()`); so does a shot fired with the crosshair off them. `Enemy.take_part_hit()`: head
  = a kill; body = full damage; an arm or leg = 0.65 damage and it may come off (30%, up to 70% rotted); a leg
  hit may knock it down. The old aimed-shot damage bonus and flat headshot chance are no longer used for the
  player (raiders still use them). The prompt names the part and how good the shot is in words, never a number.
  The same picking is to be used for melee and for finishers (owner: "aiming guns will work similarly").
- Lock-on with it: once the crosshair is on someone it is not pulled (you are choosing a part); the pull only
  brings a crosshair resting near an enemy onto them.
- Lock-on (sticky aim, 20 Nov 2026, untested on the owner's PC): `player.gd` `_lock_pull()`. Once the mouse rests,
  a crosshair within `lock_on_mouse_radius` 1 m of a living enemy the player can see settles onto it (dead centre
  inside `lock_on_core` 0.5 m, fading to nothing at the radius, so it never sticks) and follows it; moving the
  mouse takes it off. Exports in the Lock-on group. (The stick version went with the controller.)
- Debug keys: G adds a test gunner at the crosshair (Shift+G removes them); T adds a raider (Shift+T removes those);
  V switches the cutaway off and on; Z shows the horde readout.
- The UI can be hidden (owner, 20 Nov 2026: "I can't see the game anymore"): F2 steps `Hud.ui_level`: 0
  everything, 1 only what you need to play (bars, ammo, prompts, conditions, the stance line), 2 nothing. The
  long help text now starts closed (F1 opens it), with a one-line hint in its place.
- Debug keys: H treat wounds, J a test wound, F1 help, F2 hide the UI, C character page, F3 input check, F5/F6/F7 crowd test, L all zombies on the low model. Don't bind F8 (the
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

- (Floors: see "Cover and shooting between floors" under The house kit. Cover is per floor now.)
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
  Bandits mod do it); 30% in a helmet (`helmet_share` 0.4, Claude's guess). On zombies a headshot is still a
  kill.
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
- Finishers (owner, 20 Nov 2026; `player.gd`, Finisher exports). Changed by the owner the same day: only with
  the weapon raised (Ready), the crosshair on a downed zombie (crawling, knocked down, in a heap) within about
  2 m, then left-click. Weapon away, the click only interacts. It works on any part of it, but only the head
  finishes it: a blow anywhere else is `Enemy.take_body_blow()` (`body_blow_damage` 16 at full power; a limb may
  come off). Fists Ready: stomp. Gun Ready with a round: one shot. Gun Ready and empty: rifle butt (1.4 times a
  stomp). Blows by Strength: a blow is STR/14 of a sound skull, so 14 = one blow, 10 = two, 6 =
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

## Sound, hordes and hunting (built 20 Nov 2026, in review; untested on the owner's PC)

The owner asked for this before items exist, because items will make noise and change how enemies behave.

- Sound: every sound that matters goes through `Earshot.make(pos, radius, tree, from, by_player)` (`earshot.gd`;
  the name `Noise` is taken by Godot). Whatever is in earshot hears it (`hear_noise`), and the horde warms that
  area. Sources now: the player's shots and a raider's (30 m), a barged door (14 m), a finishing blow (5 m). New
  loud things (racking a round, a hurried rummage) should call it too.
- Zombies have a memory, not a plan (`enemy.gd`, Wandering exports). A sound turns one toward it and gives it
  `_drive`: 2 to 4 minutes of purpose. It walks to the sound and then keeps going the same way (`_heading`) until
  the drive runs out; stuck against something it can't pass, it forgets four times faster. Losing its prey, it
  carries on the way the prey went for 30 s. Wandering is at 0.75 of chasing speed.
- Hordes form by following: a zombie with nothing in its head looks about once a second (`_look_about`) and falls
  in behind the nearest zombie it can see within 10 m that is going somewhere. It takes 0.85 of that one's drive
  and only follows one with more drive than its own, so chains never loop and die away down their length. A zombie
  chasing someone counts as going somewhere, so others fall in behind it. Movers are indexed by 8 m cell, rebuilt
  once a second.
- The horde (`horde.gd`, `Horde.it`, one node in the level): the map is cut into 20 m areas. Each has zombies in
  play and a reserve out of play (3 each at the start; the level's own zombies are extra). The world's total is
  fixed. Every 2 s: warmth fades (one gunshot's worth in 4 minutes); an area at 0.8 warmth or more draws up to 2
  zombies, from its own reserve first and then from the areas round it, fullest first. They appear in the area
  they came from, out of the player's sight and at least 14 m off, and walk to the sound. So noise fills an area
  and empties the ones round it. A zombie gone quiet, unseen and 30 m or more away for a minute goes back into
  the reserve where it stands; one that leaves the map goes at once. At most 160 in play.
- Nothing respawns while a Horde exists: a killed shambler is freed once its corpse has gone. (Without one, as in
  the preview harnesses, the old 90 s respawn still applies.) Z shows the readout: out of play / in play / warmth
  per area.
- Cloud run: a gunshot every 5 s in one area drew 15 zombies in from the five areas beside it in 30 s, emptying
  their reserves; 11 ended up in the player's area; the total stayed fixed.
- Reserves don't yet flow between areas on their own, so once the ring round a noisy area is empty no more come.
  The owner's plan for spawning and migration across a bigger map will want that.
- Raiders hunt (`raider.gd`): they hear every sound. A sound the player didn't make only brings in raiders who
  are on watch. Flanking: the first raider into a fight comes straight on, the next works round one side, the
  next the other (`_side`), each preferring cover on its own bearing from the player (`flank_angle` 70 degrees).
  Searching: where it lost you it works out up to three places near by that are hidden from where it stands (the
  far sides of cover) and goes round them before giving up. Getting about: it vaults low cover it walks into, and
  goes round anything else toward the nearer end (`_get_past`). There is still no path finding.
- Zombies do none of that: no searching, no flanking, no going round. They only remember a direction.

## Stealth: what raiders know, crouching and prone (built 20 Nov 2026, in review; untested on the owner's PC)

The owner: raiders must not be automatically aware of things they cannot see; that opens the game to stealth,
with crouching and going prone.

- Raiders know only what they see or hear (`raider.gd`). Sight is a cone in front of them always: 150 degrees on
  watch or searching, 240 in a fight (`fight_fov_deg`). The old all-round sense within 4 m is gone. Seeing isn't
  instant unless they are already fighting you: `notice` builds from 0 to 1 while you are in view, in 0.25 s at
  arm's length up to 1.6 s at the edge of their sight (`notice_time`), 1.8 times longer if you are crouched and
  2.5 times if prone, quicker if you run; from 0.25 they turn their head your way; out of view it fades in 3 s.
  Shot from where they can't see, they learn which way it came from, not where you are (a point back along the
  shot, up to 9 m, off by up to 17 degrees). A shove still tells them exactly: you are touching them.
- Footsteps (`Player.noise_radius()`): running, dashing or rolling 10 m; walking 4.5 m; crouched 1.5 m; crawling
  0.8 m; standing still, nothing. A raider who hears them goes to look at where the sound was (once a second).
  (Zombies hear them too, a little less far: see "More of it" below.)
- Crouch is Ctrl and prone is X; each key gets you down and up again (`Player.posture` 0, 1, 2). Speed 0.55 and
  0.25 of walking. You are seen from 0.65 and 0.4 of the usual distance (`seen_mult()`): by raiders, and
  zombies notice you from that much nearer too. Crouched within 1.3 m behind low cover, or prone within 2.6 m, it
  hides you from the far side without the cover button (`low_hidden_from()`). Your own eyes drop to 0.6 m and
  0.3 m, so low cover blocks your view. Prone: no punches, no guard, no dash, roll or run. Cover, a dash, a
  roll, a vault, running, being grabbed and standing on bodies put you back on your feet.
- Cloud runs, raider on watch, player standing still: facing you at 12 m, seen in 1.1 s; back turned, never.
  Crouched: not seen at 12 m, seen in 1.7 s at 9 m. Prone: not seen at 9 m, seen in about 1.8 s at 6 m. A raider
  on watch looks about, so walking up behind one is a gamble on when it turns.
- Prone with a gun (owner, 20 Nov 2026: "we as humans can't really crawl on our backs"). You lie along
  `prone_dir` (head that way) and crawl on your front with the weapon away. Gun raised, you stay put: aiming
  ahead of you, you stay on your stomach and shoot; aiming behind you (more than `back_beyond_deg` 110 round
  from where your head points) you roll onto your back, head where it was, and shoot past your feet; aim within
  `front_within_deg` 80 again, or lower the gun, and you roll back over. Rolling takes `roll_over_time` 0.5 s
  and you can't fire during it. Aiming a gun from the ground, the crosshair roams 6 m further
  (`prone_aim_reach`, 22 m in all).
- Poses (`player_body.gd`, `_prone_w`, `Player.prone_back`): the crouch reuses the cover squat. Prone has
  real poses now: lying on the front with the chest propped and the head up; crawling, the hands planted
  ahead with the elbows wide and pulling back in turn, one knee drawn up at a time; with a gun, it lies out in
  front on the ground and turns to where you aim while the body stays put; on the back, knees up and feet
  planted, chin down, the gun held over the belly pointing past the feet.
- Tall grass (`tall_grass.gd`, `TallGrass.at()`): down low in it you are seen from much less far, on top of
  the stance: crouched 0.7 again, flat 0.35 again (`grass_crouch_seen`, `grass_prone_seen`). So flat in grass
  a raider has to be within about 2.5 m and a zombie 1.7 m. Standing in it changes nothing. One test patch by
  the spawn (9 by 7 m, placed where it is clear of the level), drawn with the tall standing grass
  (`GrassBlades`, see Ground and grass). It hides nothing from the player and enemies don't use it. The owner mentioned "things like tall grass": other
  such things (crops, reeds, brush) should be `TallGrass` patches or join the same check. Sheet: `tools/preview/stances.png`
  (`tools/cover_pose_preview.gd` ROW=2).
- More of it (owner, 20 Nov 2026: "we ain't done with stealth yet", then "all of that" to the list of what was
  missing). Built the same day, untested on the owner's PC:
  - The mark over a raider's head (`_mark`): a yellow "?" that firms up as it starts to notice you, a red "!"
    for 1.4 s when it has. Only seen when the raider itself is.
  - Quiet take-down (`Player._update_takedown()`, `_takedown()`): weapon raised, crosshair on a raider who
    hasn't seen you and isn't fighting, within 1.6 m and behind him, left-click: he is dead, heard 3 m off.
    Any weapon. No animation of its own and no Strength check yet.
  - Zombies hear footsteps from 0.8 of the distance a raider does (`footstep_hearing`) and turn toward them.
  - Raiders tell each other: one that sees you shouts (`shout_range` 14 m). Raiders in earshot who aren't
    fighting learn where it saw you and come looking; zombies come to the shout.
  - Raiders out searching go in a crouch (the look only: it doesn't yet make them harder to see or quieter).
    They don't go prone.
  - Light and dark: see below.
- Light and dark (owner, 20 Nov 2026: "build light and dark for stealth"; untested on the owner's PC, and its
  look could not be rendered in the cloud at all). `daylight.gd` (`Daylight`, one node in the level):
  - How light a spot is (`Daylight.at(pos)`, 0 to 1) is the daylight or a lamp near by, whichever is brighter.
    Daylight is `level`: day 1, dusk and dawn 0.45, night 0 (open ground at night is 0.08, starlight). There is
    no clock, so N steps the time of day by hand and the light eases over 4 s; the clock is to drive
    `Daylight.want`. Lamps (`Daylight.add_lamp(pos, radius)`, `main.gd` `_lamp()`): full light near, fading to
    nothing at the radius. Two in the test level: the raider camp's fire (9 m) and a lamp by the spawn (6 m).
  - Being seen: `Player.seen_mult()` is also times 0.3 in pitch dark up to 1 in full light (`dark_seen`), by
    the light where you stand (`light_on_you()`). So at night in the open a raider sees you from 6.4 m instead
    of 18 and a zombie notices from 4.3 m instead of 12; in a lamp's light, from as far as by day. It stacks with
    crouching, lying flat and tall grass. A raider also takes up to about twice as long to be sure of you in the
    dark. Firing a gun lights you fully for 0.6 s (`shot_lights_you`).
  - Seeing: your own sight shrinks to 0.35 by night (40 m to 14 m), but anything standing in lamp light shows
    from as far as by day (`Player.can_see()`, and the same in the fog shader). So a lit camp stands out at
    night and you don't.
  - On screen: the fog of war's screen quad (`fog.gd`) lays the dark over everything, up to `dark_max` 0.82
    black at night, except where a lamp lights the ground. It is done there because the character shaders do
    their own lighting and are approved assets: scene lights alone would not darken them. Lamps also have a
    real warm `OmniLight3D` for the look. The level's sun and sky are not dimmed.
  - Cloud run at night: standing in the dark, a raider on watch first saw the player at 5 m; standing in the
    lamp's light, at 12 m (the furthest tried).
  - The torch (owner, 20 Nov 2026; untested on the owner's PC): an item (`torch`, in the tool box by the
    spawn). E switches it on and off (`Player._update_torch()`, `torch_on`). It throws a beam where you face:
    16 m long, 24 degrees either side, fading over its last 40%, with 2.2 m of light round your feet
    (`Daylight.beam_*`, one carried beam for the whole level). What stands in the beam counts as lit, so you
    see it at night from as far as by day, and the screen isn't darkened there. Carrying it lit, you count as
    fully lit and, at night, are seen from 1.5 times the daytime distance (`torch_seen`: a raider from 27 m, a
    zombie from 18 m); by day it makes no difference. A real `SpotLight3D` on the player gives the look. It
    runs on batteries now (see The first working items); it doesn't need a free hand, and lying down the beam's drawn light follows the body rather than
    the aim.
  - The burning torch (owner, 21 Nov 2026: "both" kinds; not yet seen by the owner): `fire_torch`, also in
    the tool box. E now steps through what you carry: hand torch, burning torch, nothing (`torch_kind`). It
    has no beam: it lights 9 m all round you (`fire_torch_range`; a carried "beam" wider than any angle, with
    a warm `OmniLight3D`), shows you from as far as the hand torch does, and burns away in 300 s of being
    lit (a stand-in), then it is gone. Not built: making one, lighting it from a fire, setting things or
    zombies alight, rain putting it out, raiders carrying one.
  - Raiders carry torches (owner, 20 Nov 2026; untested on the owner's PC). `Daylight.beams` now holds any
    number of carried beams by who carries them (`set_beam()`, `clear_beam()`); the fog shader draws the 6
    nearest the player (`BEAM_MAX`). A raider (`raider.gd` `_update_torch()`, `carries_torch`) has his on when
    the daylight is under 0.35 and he is away from his post: searching, fighting or going home. On watch he
    leaves it off (the camp has its fire). His beam is 14 m, 24 degrees either side. What it falls on is lit,
    the player included, so a searching raider's sweep can find you from as far as by day; and the pool of
    light round him shows where he is from a long way off. Cloud run at night: a raider 16 m off couldn't be
    seen until he heard a noise and switched it on; walking toward the noise his beam fell on the player after
    4.7 s and he had seen them 1.3 s later, from 6 m.
  - Not built: light from
    windows or indoors versus outdoors, moonlight by phase, shadows cast by walls counting as dark, at most 8
    lamps drawn (`LAMP_MAX`), zombies and raiders being hard for you to see for any reason but distance.

## Throwing (built 20 Nov 2026, in review; untested on the owner's PC)

The owner: pick up and throw things like rocks and bottles; the noise sends zombies off toward it and brings
raiders to look; hold Ready to ready it, left-click to throw; it can be used from behind cover.

- Rocks and bottles are items (`items.gd`, 0.4 kg, up to 3 to a slot that can take the weight) lying about as
  small pickups (`ItemPickup.small`; `main.gd` `_throwable()`): seven near the spawn and on the way to the
  raider camp.
- "Throw" is the third thing on the Tab wheel (`Player.WEAPONS`). `is_melee()` now means "not the gun", so
  everything that asks about guns treats a throwable like empty hands; only the guard, the shove and the
  punch ask for fists by name. Ready, the crosshair roams your throwing range: 8 m plus 0.6 a point of Strength
  (14 m at 10). Left-click throws the first of bottle, rock that you carry (`_throw()`); 0.7 s between throws.
- From behind cover a click throws without Ready and without leaving the hunker.
- `thrown.gd` (`Thrown`): it arcs (the top of the arc is 0.6 m plus 0.22 a metre thrown above your hand). It
  clears low cover always and anything whose top is under the arc (a one-storey wall from about 6 m back);
  otherwise it drops at the foot of what it hit. Landing is a noise through `Earshot`: rock 9 m, bottle 14 m.
  Zombies turn and walk to it (their usual sound memory); raiders on watch go to look, and one that has lost
  you takes it for you. A rock lies where it landed and can be picked up again; a bottle is gone.
- Cloud run: a bottle thrown 12 m sent a zombie 6 m from the landing toward it and put a raider on watch 7 m
  away into a search of that exact spot, without it knowing where the player was.
- Not built: hitting someone with it, the bottle's broken glass, a throwing pose (it uses the reach), an arc
  shown before you throw, throwing other things. The hatchet and steroids moved to a "Tool box" by the spawn so
  the first-aid box leaves your hands free.

## Ground and grass (built overnight 20 Nov 2026, in review; never seen on Forward+)

The owner, going to bed: assets to start building a level with, kept simple; shaders for different kinds of dirt,
modular, with the seasons and textures (cold and cracked, wet, farm, soil, dirt roads), "extra love on this";
then grasses, as a second batch. Everything is in `assets/ground/` (its README has the full account).

- The look: world-space texels, 16 to the metre, turned 45 degrees to face the camera (`GROUND_TURN` in
  `ground_lib.gdshaderinc`; it must match `camera_rig.gd` `yaw_deg`). Each material is one 8-shade ramp
  (`ground_ramps.gdshaderinc`, generated by `source/gen_ramps.py`: natural colours, 12 ramps). A pattern moves
  a spot along its ramp; `ground_color()` dithers it into a shade and adds grit. Light falls in three dithered
  steps (`ground_light.gdshaderinc`).
- Modular: `dirt_modules.gdshaderinc` is the pieces (base clods, pebbles, cracks, furrows, ruts, wet, puddles
  with rain rings and ice, leaves, sprouts, seedlings, stubble, frost, snow). `dirt_types.gdshaderinc` builds
  the kinds from them: 0 soil, 1 farm, 2 road, 3 clay, 4 mud. `grass_types.gdshaderinc`: 8 lawn, 9 meadow,
  10 rough. A new kind is one short function and a number.
- Seasons: one project-wide shader value `ground_season` (x time of year 0 to 4, y wetness, z snow, w frost),
  kept by `seasons.gd` (`Seasons.it`), eased, and idle when nothing changes. M steps the season and K the rain
  in the test level, as stand-ins for the clock and the weather. A material can pin its own with
  `season_override`.
- Level building: `ground.gd` (`Ground`, `Ground.it`): `setup(rect, kind)`, `road(points)`, `path(kind, points,
  width)`, `rect(kind, rect, rows_deg)`, `blob(kind, centre, radius)`, `apply()`, `grow_grass()`,
  `kind_at(pos)`. It paints a map (a texel to 0.25 m: the kind, how far across a road, which way rows run);
  `ground.gdshader` draws every kind on one mesh and makes the borders ragged. All roads on one Ground share
  `road_width`.
- Standing grass: `grass_blades.gd` (`GrassBlades.in_rect(kind, rect)`, `at_points()`), kinds short, meadow,
  tall, tussock; one MultiMesh a patch; `grass_blades.gdshader` gives the season's height and colour, a stepped
  sway, and parting round the player (`grass_push`, set in `Player._update_visuals()`, wider crouched and widest
  crawling). `TallGrass` (the hiding grass) is now drawn with the tall kind.
- The test level uses it: soil, a dirt road up the yard, a field, clay and mud patches, a lawn by the spawn, a
  meadow down the west side, rough ground; about 7,900 tufts. B swaps back to the old plain ground, in case
  the shader misbehaves on the owner's machine.
- Soft ground (owner, 20 Nov 2026: "make mud slow you and leave tracks"; untested on the owner's PC).
  `Ground.softness(pos)` goes by the kind and the season: mud is soft unless baked by drought or frozen, a
  field a little, bare ground when soaked. Mud slows (`slow_at()`, `mud_slow` 0.5): walking speed about 0.6 in
  spring and 0.5 in rain, unchanged in a dry summer or a frost (cloud run: 2.1 m/s on firm ground, 1.29 in
  spring mud, 1.05 in rain). The player looks it up on the sheet's slow clock; zombies and raiders at each
  footfall, and are slowed the same. Tracks: `Ground.stamp(pos, dir, side, drag)` presses a print (or a
  crawler's swathe) into a second map, a texel to 0.125 m, in soft ground or lying snow only; the player
  stamps every 0.7 m (`Player._update_ground()`), enemies every 0.75 m (`Enemy._leave_tracks()`). The shader
  draws them dark in earth, with a little water in them when wet, and packed blue-grey in snow. Rain and fresh
  snow wipe them (`Seasons` calls `clear_tracks()`); nothing else does. The map goes to the graphics card at
  most 5 times a second and only when someone has made a print. Sheet: `assets/ground/preview/tracks.png`.
  Not built: tracks fading with time, tracks in grass, footstep noise by ground.
- Raiders follow tracks (owner, 20 Nov 2026; untested on the owner's PC). `Ground.trail` is the player's own
  prints in the order they were made (the last 400; `trail_near()`, `trail_point()`); zombies' and raiders'
  prints are drawn but not kept. A raider on watch, searching or going home who has one of your prints
  within `track_sight` 5 m, in front of him, on ground lit at least `track_light` 0.3 (his torch does that at
  night) and no older than `track_age` 240 s, takes up the trail (`Raider._read_tracks()`, `tracking`): he
  walks from print to print toward the newest, with the "?" over his head, until he sees you or the prints
  run out, and then searches round where they stopped. He never goes back over prints he has followed. Rain
  and fresh snow wipe the trail from under him. Cloud run in snow: a raider 3 m from the start of a 24 m
  dog-leg trail took it up at once and found the player lying flat at the end of it in 10 s. He doesn't tell
  the others, and you can't yet hide or false-lay a trail except by walking on firm ground. (Fresh zombies
  follow tracks too: see "The mind goes with the body" under Small rules.)
- Review sheets (software renderer, made by `tools/ground_preview.gd`, SHEET=dirt, grass or scene):
  `assets/ground/preview/dirt_seasons.png`, `dirt_scene_seasons.png`, `grass_seasons.png`,
  `grass_scene_seasons.png`.
- Unchecked: everything on Forward+ (colours, the stepped light, shadows on the ground: the cloud renderer drew
  none, cost). Zoomed right out a texel is about a pixel and may shimmer.
- Zombies and raiders part the grass too (owner, 20 Nov 2026; untested on the owner's PC). `grass_push.gd`
  (`GrassPush`, one node in the level): 10 times a second it marks every living enemy near the player on a
  small map (64 by 64, a texel to 0.5 m, centred on the player and moved in whole texels) and hands it to the
  grass shader as the project-wide texture `grass_push_map` (with `grass_push_rect`). A blade leans downhill
  on the map and is pressed down where it is marked, so a horde costs the shader no more than one zombie.
  Crawlers mark a wider spot. The player's own parting stays exact and separate (`grass_push`). Nothing is
  sent while nobody is near. Checked in the cloud by rendering the same tall grass with and without two
  figures in it (the pictures differ where they stand) and by the map filling in the level; the look in motion
  is for the owner's PC. Beyond 16 m from the player nobody parts the grass.
- Also in the Ground Assets artifact (see Where game design assets live).

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
  Starving...). Food and water run down since 21 Nov 2026 (see The first working items); rest waits for
  somewhere to sleep.
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
- AI (`mode`): idle (on watch, sees 18 m (was 26; the owner had it lowered) in a 150 degree cone; see Stealth; comes to gunshots), fight, search
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
