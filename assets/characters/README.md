# Character assets

The same files as the **Godot Assets** artifact (https://claude.ai/artifact/WRBAYq3aDXi9hMi5zS2wzC), in a form Godot
can use directly: real `.glb` models instead of base64 text, and `.gd` / `.gdshader` instead of `.txt`. The artifact
is where they are shared and previewed; this folder is where the game uses them. When an asset changes, both are
updated together.

| Folder | What it is | Status |
| --- | --- | --- |
| `MaleBody_Muscular/` | The male base body: three detail levels, 72-bone skeleton, the base skin shader | Approved and locked |
| `MaleBody_Muscular_Skins/` | Living skin tones and looks for that body (`body_living.gdshader`, `living_body.gd`) | Approved |
| `ShamblerMale_Muscular/` | The shambler: swappable wounded parts, decay by Freshness, painted insides (`zombie_decay.gdshader`, `shambler.gd`, `freshness.gd`, `anatomy_map.gd`), and the cut-off pieces that fly off when a part comes off (`ShamblerMale_Muscular_Pieces*.glb`, `shambler_piece.gd`, `zombie_decay_piece.gdshader`): they move like dead limbs, rot and fade away | Approved; pieces added 15 Nov 2026 |

Each folder has its own README with setup steps and what every file is. `source/` (the recipes that build the models
and shaders) and `preview/` (the review renders) each hold a `.gdignore`, so Godot doesn't import them.

None of these are used by the level yet: `main.gd` still builds its placeholder shamblers in code.

Quick start in Godot:

- **Shambler:** right-click `ShamblerMale_Muscular/ShamblerMale_Muscular.glb`, choose **New Inherited Scene**, attach
  `shambler.gd` to the root and save. Each instance rolls its own look. Set its `pieces_scene` to
  `ShamblerMale_Muscular_Pieces_low.glb` and `dismember()` throws the part that came off as a physics piece whose
  wrist and fingers (or ankle and toes) move like a dead limb's, and which rots and fades away.
- **Living person:** the same with `MaleBody_Muscular/MaleBody_Muscular.glb` and `MaleBody_Muscular_Skins/living_body.gd`.

Checked here with Godot 4.5 (Compatibility renderer, no GPU): the project imports these files without errors, a
shambler and a living body load from these paths with their scripts, and the existing main scene still runs. Still
to check on 4.7 with Forward+.
