# Ready Stance (rebuilt from scratch)

Godot 4.3+. Unzip the folder, open `project.godot`, then press F5. Everything is built in code, so there's no editor setup.

## The idea
You switch between two stances so that exploring and fighting use different controls.

- **Weapon away (default):** you face the way you walk. The right stick or mouse moves a crosshair, and the camera pans to keep it centered. Your facing doesn't change. When you let go, the camera comes back to you and the crosshair hides. The attack button works as **Interact**. Hold Sprint to run.
- **Ready (HOLD):** twin-stick. The reticle appears on you and you move it out from there. The right stick or mouse sets your facing once the reticle is off you, and the camera leans toward where you aim. The attack button **attacks**. You move slower and can't run, but you can still dash.
- **Doors work in either stance.** Walk into a door to push it open or shut. Run or dash into a shut door to barge it. The camera angle never rotates; it only pans.

## Controls
| | Controller | Mouse + Keyboard |
|---|---|---|
| Move | Left stick | WASD |
| Look / aim | Right stick | Mouse |
| Ready (hold) | LT | Right mouse button (Q also works) |
| Attack (Ready) / Interact (weapon away) | RT (A also works) | Left-click |
| Sprint: tap = dash, hold = run | LB or L3 | Shift |
| Reload | X | R |

F1 hides the help text. Esc frees the mouse, and clicking captures it again. Keys 1 to 6 lower or raise STR, END and WT live, so you can feel how the stats change movement.

## What's in the level
- **Ammo crate** next to spawn. It's the first interaction: put your weapon away, walk up and interact. Crates respawn.
- **Dummies** to the west. They heal after 3 seconds and respawn fast.
- **Shamblers** to the east, plus two inside the house. They're slow and walk straight at you. They swipe in melee, and they shove doors open just like you do.
- **House:** the south door is a normal door. The east door is heavy and locked: a run won't open it, but a dash will. Every failed barge weakens it.
- When your ammo is completely gone, attacking does a short bash.

## Stats to movement (`recompute_stats()` in player.gd)
There is no speed stat. Speed comes from Strength, Endurance and Weight.
- **Burden = weight / strength.** Carrying more than your frame can handle slows walking and running, makes stamina cost more, and shortens your dash.
- **Endurance** gives you a bigger stamina pool, faster regen and a small boost to top speed.
- **Ready speed** is 65% of walk speed, and you're slower backing away from your aim. **Run** is about 1.45x walk. **Dash** is 1.8x run for a split second.
- **Fatigue:** below 50% stamina every kind of movement slows and gets more sluggish, down to 65% speed at empty. A tired run ends up slower than a fresh walk, and too slow to barge a door.
- **Running out of stamina** leaves you winded, with no run or dash, until you're back up to 35%.
- **Barge power = (STR + WT) x your speed.** A barge always hurts. If the door holds, you bounce off and it hurts more.

## Aimed shots
In Ready, the reticle turns red over an enemy. A shot fired while it's red is aimed at that enemy:
- **More damage.** x1.5 at the defaults. Each point of Dexterity adds 3%, and each point of weapon damage adds 0.8%.
- **Headshot chance.** 13% at the defaults, capped at 60%. A headshot kills outright. Dexterity and weapon damage both raise the odds.
- The bonus only applies if the shot hits the enemy you aimed at. Keys 7 and 8 lower or raise DEX live.

## Tuning
All the feel settings are exported variables at the top of each script:
- **player.gd:** `base_walk_speed`, `run_mult`, accel and decel, `fatigue_start`, `fatigue_min_speed`, `fatigue_min_accel`, turn speeds, `draw_time`, `sprint_tap_time`, look and aim range, `ready_cam_lead`, mouse sensitivity, weapon stats.
- **camera_rig.gd:** pitch, distance, FOV, `follow_sharpness`.
- **door.gd:** toughness, locked, max swing angle.
- **enemy.gd:** speed, aggro range, damage.

## Files
main.gd (level), player.gd, camera_rig.gd, door.gd, enemy.gd, projectile.gd, ammo_pickup.gd, hud.gd, input_setup.gd

## Mouse note
Ready and Attack read the mouse buttons three ways (button events, the held-button mask on every
mouse event, and the OS button state), because some setups drop a left-click while the right
button is held. The INPUT CHECK box (F3) shows what's getting through.
