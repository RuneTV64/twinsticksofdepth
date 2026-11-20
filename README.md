# Ready Stance (rebuilt from scratch)

Godot 4.3+. Unzip the folder, open `project.godot`, then press F5. Everything is built in code, so there's no editor setup.

## The idea
You switch between two stances so that exploring and fighting use different controls.

- **Weapon away (default):** you face the way you walk. The mouse moves a crosshair, and the camera pans to keep it centered. Your facing doesn't change. When you let go, the camera comes back to you and the crosshair hides. The attack button works as **Interact**. Hold Sprint to run.
- **Ready (HOLD):** the reticle appears on you and you move it out from there. The mouse sets your facing once the reticle is off you, and the camera leans toward where you aim. The attack button **attacks**. You move slower and can't run, but you can still dash.
- **Doors:** click a door (weapon away) to open or shut it. A character with Strength 13 or more can bash a shut door in by dashing at it; running into one does nothing. Shut doors stop zombies and raiders. The camera angle never rotates; it only pans.

## Controls
Mouse and keyboard only. There is no controller support.

| | Mouse + Keyboard |
|---|---|
| Move | WASD |
| Look / aim | Mouse |
| Ready (hold) | Right mouse button (Q also works) |
| Attack or finisher (Ready) / Interact (weapon away) | Left-click |
| Sprint: tap = dash, hold = run | Shift |
| Cover: tap = in or out, hold = go to the marked cover | Space |
| Roll (out of cover) | Space twice quickly |
| Weapon wheel (hold) | Tab |
| Reload | R |
| Crouch / Prone (press again to get up) | Ctrl / X |
| Camera in and out | Mouse wheel |
| Free look (hold): the camera follows the crosshair further out | F or middle mouse button |
| Character page | C |
| Treat wounds (sit down to it) | H; keys 1 to 7 or a click pick a tool; hold Alt to look up |

F1 hides the help text. Esc frees the mouse, and clicking captures it again. Keys 1 to 6 lower or raise STR, END and WT live, so you can feel how the stats change movement.

## What's in the level
- **First-aid box** by the spawn (and one in the yard house): take it, then H treats wounds by hand. J gives you a test wound.
- **Bites infect.** Only taking the arm or leg off in time (the hatchet, in the treatment screen) can cure one, and that takes luck; steroids slow it. Let it run and you turn: your old character gets up as a zombie carrying your things.
- **Ammo crate** next to spawn. It's the first interaction: put your weapon away, walk up and interact. Crates respawn.
- **Dummies** to the west. They heal after 3 seconds and respawn fast.
- **Shamblers** to the east, plus two inside the house. They're slow and walk straight at you, and they shove doors open just like you do. Each one is a different person, dead for a different time, with different parts missing (see Zombies).
- **House:** the south door is a normal door. The east door is heavy and locked: only a bash opens it (Strength 13, dash into it). Every failed bash weakens it.
- When your ammo is completely gone, attacking does a short bash.

## Zombies
Shamblers use the ShamblerMale_Muscular body (`zombie_body.gd`, see below). What one can do depends on what it has left:
- **Grab:** with a hand left it reaches for you. With your guard up and facing it, you shove it off first. Otherwise it has hold of you: one hand slows you to 35%, two hands (or two zombies) nearly root you, and you can't run or dash. It pulls in and bites (15) after a second, then again every 1.5 s.
- **Get loose:** hold Ready unarmed, facing it, to shove it off (costs stamina), or wiggle the move keys back and forth to struggle free (about 1.5 s of hard wiggling against one hand, 3 s against two). Hitting it helps.
- **Lunge:** with no hands it can't grab. It crouches and throws itself at you mouth first; your guard shoves it off.
- **Crawl:** with a leg gone it always crawls. A hard hit or a shove can knock any of them down; it crawls at you for a while, then gets back up if it has the legs. Crawlers grab at your ankles and bite.
- **Losing parts:** a hit that doesn't kill can take an arm or a leg off (rotted parts go more easily), and the piece flies off. A headshot kills, and sometimes takes the head off. The head is still alive on the floor and, very rarely, bites if you step right next to it.
- **Rot:** the longer dead, the slower, with more dragging, lurching and stumbling. In rigor they're stiff and jerky. The most rotted fall apart on their own now and then.
- A dead zombie lies where it fell for 30 s, then fades (a stand-in until the clean-up lore is designed), and comes back at its spot after 90 s as a new zombie.

## Stats to movement (`recompute_stats()` in player.gd)
There is no speed stat. Speed comes from Strength, Endurance and Weight.
- **Burden = weight / strength.** Carrying more than your frame can handle slows walking and running, makes stamina cost more, and shortens your dash.
- **Endurance** gives you a bigger stamina pool, faster regen and a small boost to top speed.
- **Walk** is 3.2 m/s at the default stats. **Ready speed** is 80% of walk speed, and you're slower backing away from your aim. **Run** is about 2.1x walk. **Dash** is 1.8x run for a split second.
- **Fatigue:** below 50% stamina every kind of movement slows and gets more sluggish, down to 65% speed at empty. A tired run ends up too slow to barge a door.
- **Running out of stamina** leaves you winded, with no run or dash, until you're back up to 35%.
- **Barge power = (STR + WT) x your speed.** A barge always hurts. If the door holds, you bounce off and it hurts more.

## Aimed shots
In Ready, the reticle turns red over an enemy. A shot fired while it's red is aimed at that enemy:
- **More damage.** x1.5 at the defaults. Each point of Dexterity adds 3%, and each point of weapon damage adds 0.8%.
- **Headshot chance.** 13% at the defaults, capped at 60%. A headshot kills outright. Dexterity and weapon damage both raise the odds.
- The bonus only applies if the shot hits the enemy you aimed at. Keys 7 and 8 lower or raise DEX live.

## Tuning
All the feel settings are exported variables at the top of each script:
- **player.gd:** `base_walk_speed`, `run_mult`, `ready_mult`, accel and decel, `fatigue_start`, `fatigue_min_speed`, `fatigue_min_accel`, turn speeds, `draw_time`, `sprint_tap_time`, `reticle_range` (shared by both stances; `look_range_bonus` and `aim_range_bonus` are set by gear such as binoculars or scopes), `ready_cam_lead`, mouse sensitivity, weapon stats.
- **camera_rig.gd:** pitch, distance, FOV, `follow_sharpness`.
- **door.gd:** toughness, locked, max swing angle.
- **enemy.gd (Crowd):** `personal_space`, `separation` and `min_gap`: zombies don't collide with each other, they steer apart, so these set how tightly a horde packs.
- **enemy.gd:** speed, aggro range, and the zombie abilities: grab range and windup, bite damage and timing, lunge, crawl speed, knockdown chance, limb and head loss, corpse time, falling apart.
- **player.gd (held):** `held_speed_one`, `held_speed_two`, `struggle_per_wiggle`, `struggle_needed`, `break_free_cost`.
- **zombie_body.gd:** `pose_sharpness`; the poses themselves are the numbers in `_pose_walk()` and `_pose_crawl()`.

## Files
main.gd (level), player.gd, camera_rig.gd, door.gd, enemy.gd, projectile.gd, ammo_pickup.gd, hud.gd, input_setup.gd, player_body.gd (the player model and its animation), body/ (the MaleBody_Muscular models and skin shader), zombie_body.gd (a zombie's model and its animation), severed_head.gd (a head that came off, still biting)

## The player body
`player_body.gd` loads `body/MaleBody_Muscular_mid.glb`, puts the skin shader on it and poses the skeleton in code every tick from the player state. There are no animation clips: legs step the way you move, the arms are placed on a boxing guard or on the gun in Ready, and punches, shoves, recoil, reload, hits, dashes and death all come from the same timers the controller uses. To change a pose, edit the numbers in `animate()`. To use the close-up or far model, change `MODEL_PATH`.

## The zombie body
`zombie_body.gd` works like `player_body.gd`: no clips, the bones are posed in code every tick from the Enemy's state. It loads `ShamblerMale_Muscular_mid.glb` with `shambler.gd` on it (which rolls who he was, how long he's been dead and which parts are missing) and the decay shader. One script covers every mix of missing parts and every decay stage: the shamble with a dragging bad leg, reaching arms, the crawl, grab, bite, lunge, flinch, knockdown and getting up, and dying face down. Out of your view a zombie dithers away instead of going transparent. Zombies in the upper part of the screen (over 21 m from the camera) use the low model, 5,000 triangles against the mid model's 15,000. Each zombie takes about 100 of the renderer's per-object shader values: Forward+ has room for about 650 zombies (raise `rendering/limits/global_shader_variables/buffer_size` for more), the Compatibility renderer about 40. Review sheets are in `assets/characters/ShamblerMale_Muscular/preview/zombie_anim_*.png`; `source/zombie_anim_preview.gd` makes them.

## Mouse note
Ready and Attack read the mouse buttons three ways (button events, the held-button mask on every
mouse event, and the OS button state), because some setups drop a left-click while the right
button is held. The INPUT CHECK box (F3) shows what's getting through.
