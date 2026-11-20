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

- The camera never turns in play (owner, 20 Nov 2026): it only pans and moves in and out. No rotation, snapped
  or free. Later the same day the owner decided the view itself is turned 45 degrees: `camera_rig.gd`
  `yaw_deg` 45, so north is toward the top right of the screen, as in an isometric game. (Claude took "a 45
  degree rotation on the camera" to mean this fixed turn, not a camera the player can rotate; if the owner
  meant turning in 45 degree steps, everything already asks the rig for its yaw.) Anything that maps the
  screen to the ground must go through `Player.screen_to_ground()` / `CamRig.yaw()`: movement keys (up is up
  the screen), mouse travel, the camera lead. Lighting set from the camera (zombie and raider `key_dir`) is
  worked out once at start-up from the camera as it stands, so it follows; it is unchecked on real hardware.
- In and out, and further (owner, 20 Nov 2026; untested on the owner's PC). The mouse wheel moves the camera
  between 9 and 42 m from what it looks at (`camera_rig.gd` `zoom()`, 18 m by default; the angle never
  changes). The crosshair roams 16 m (`reticle_range`, was 10) and is kept on the screen: at the edge it stops
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
- Professions are hands-on mini-games (owner, 20 Nov 2026, on seeing the treatment screen: "Trauma Center! I
  loved that game"; a slice or two of it is welcome, and "most professions should work in a similar mini-game
  style way"). So medicine is the model: a skill is something the player does with the mouse, close up, and the
  character's skill changes what they can see and how forgiving it is. Borrow mechanics, never another game's
  names, art, characters or levels. Which professions and what each one's game is are not designed: propose.
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
- Unloading (agreed in outline): Shift+R is "make safe": the magazine comes out and the chambered round is racked
  out; holding it strips rounds from the magazine. Racking makes a noise. In the inventory a gun opens to show its
  chamber and magazine well, and a magazine shows its rounds, to drag out by hand. Still to settle together: the
  rest of loading (R tap to swap magazines, R hold to thumb rounds in, where magazines are kept).
- Order (owner): enemy AI that follows sound came first, because items will make noise. That is built (see Sound,
  hordes and hunting). Items are next.
- Claude's earlier layout, which the owner answered against: items are records (weight, condition, category);
  container contents are rolled when first opened; time is applied on opening (spoiling, picked over by others);
  nothing respawns in a cupboard; keepsakes unlock starting builds.

## Health, injury and medicine (being designed with the owner, 20 Nov 2026; nothing built)

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
  other people, dropping or moving items between slots.

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
  aimed at a missing limb go to the chest. Hooks, improvised hands and peg legs are for later (owner). The
  player's model still shows the limb: the body model is approved and locked, so this needs the owner's say.
- What you can tell (`bite_guess()`): Medical 0 to 1, only that you were bitten; 2, that it is infected; 4, how
  far up the limb it has got, or that the bite seems not to have taken.
- Death (`Player._die()`): infected, your old character gets up where you fell as a fresh zombie (`Enemy`
  `was_player`, `carried`), missing the limbs you had lost, with everything you carried; killing it drops "Your
  old things". Not infected, your things lie there as "Your body". The new character starts with nothing. The
  risen zombie's skin is rolled, not yours: the player has no look of its own yet.
- Not built: sickness other than the bite, a turned raider, more than one cutting tool, cauterising, the look of
  a missing limb on the player, prosthetics.
- Next, in order: sickness; the new needs (hygiene, morale, toilet, warmth).

## Small rules the owner has set (20 Nov 2026)

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
- Aiming at a part (owner, 20 Nov 2026; built the same day, untested on the owner's PC). The cursor is the
  ring (white Ready, grey with the weapon away; it no longer hides with fists Ready). The owner tried a small
  grey x for it and changed their mind the same day: the ring stays, and Ready it switches to a red x on an
  enemy or on something that can be broken (a node in the group "destructible"; nothing is in it yet). The
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
- Debug keys: H treat wounds, J a test wound, F1 help, C character page, F3 input check, F5/F6/F7 crowd test, L all zombies on the low model. Don't bind F8 (the
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
  Zombies don't hear footsteps yet.
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
  the spawn (9 by 7 m, placed where it is clear of the level); the look is a stand-in of plain blades. It
  hides nothing from the player and enemies don't use it. The owner mentioned "things like tall grass": other
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
    zombie from 18 m); by day it makes no difference. A real `SpotLight3D` on the player gives the look. No
    batteries, it doesn't need a free hand, and lying down the beam's drawn light follows the body rather than
    the aim.
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
- Review sheets (software renderer, made by `tools/ground_preview.gd`, SHEET=dirt, grass or scene):
  `assets/ground/preview/dirt_seasons.png`, `dirt_scene_seasons.png`, `grass_seasons.png`,
  `grass_scene_seasons.png`.
- Unchecked: everything on Forward+ (colours, the stepped light, shadows on the ground: the cloud renderer drew
  none, cost). Zoomed right out a texel is about a pixel and may shimmer. Nothing reads the kind of ground yet
  (mud doesn't slow, no tracks or footstep sounds); zombies and raiders don't part the grass.
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
