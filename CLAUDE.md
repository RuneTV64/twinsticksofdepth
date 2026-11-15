# Twin Sticks of Depth

Godot 4 twin-stick game. Everything in the level is built in code (see README.md).

## Naming: zombies and shamblers

- **Zombies** is the name for the undead as a whole group.
- **Shamblers** are one kind of zombie: the most common, slow, and they walk straight at you. Other kinds will get
  their own nicknames, with different AI and some different physical features.
- Shamblers come in all the same body types as the living, and in every complexion, because they were people.
  So shaders and scripts made for them are named for shamblers (e.g. `shambler_decay.gdshader`), not "zombie".
- Skin tones: don't use "olive" as a tone name, since it's tied to a particular ethnic group. Use descriptive
  names (the white group is Pale, Light, Tan; shambler complexions are fair, tan, dark).

## Where game design assets live

All game design assets go into our claude.ai **Artifacts**, not just this repo, so they can be shared across
devices and pulled into any chat. That covers models, shaders, asset scripts, previews, design docs and plans.

- Character assets: the **Godot Assets** artifact, https://claude.ai/artifact/WRBAYq3aDXi9hMi5zS2wzC
  (MaleBody_Muscular, ShamblerMale_Muscular). Find others with the Artifact tool's `list` action.
- Before starting asset work, check the Artifacts first. Work done in an earlier chat may only be there, not in git.
- Layout inside an asset artifact: `files/<AssetName>/`. Models are `.glb.b64.txt` (base64 of the .glb, since
  artifacts can't hold .glb). Godot scripts and shaders are `.gd.txt` / `.gdshader.txt`. The recipe that builds
  them is under `source/`, preview renders under `preview/`, plus a README.md. List every file on the page with a
  short "what it is", and keep the asset's status pill (approved / in review) current.
- When an asset changes, republish to the same artifact URL (read it first) instead of making a new one.
- Art style: "8-shade 3D-Pixel" (the eight-shade-3d-pixel skill): 8-shade banded ramps, Bayer dither, dark and gritty.

## Testing Godot assets in a cloud session

No Godot is installed. The official 4.5.1 Linux build downloads from GitHub releases and runs under
`xvfb-run` with `--rendering-driver opengl3`. That software (Compatibility) renderer skips the linear->sRGB step
and ignores instance uniforms, so test harnesses should output palette colors directly and set per-shambler
values per material. Say so when reporting results, and that Forward+ on 4.7 still needs a check.
