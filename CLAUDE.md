# Twin Sticks of Depth

Godot 4 twin-stick game. Everything in the level is built in code (see README.md).

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
- Art style: "8-shade 3D-Pixel" (the eight-shade-3d-pixel skill): 8-shade banded ramps, Bayer dither.
- "Dark and gritty" is the game's setting and themes, not a rule that every asset is dark. The mood comes from
  places, lighting and story; assets get natural colors (a farmland area can be pretty). Don't darken palettes
  just to look gritty: dead bodies go pale first and only darken as they rot, for example.
- Zombie wounds are painted, not modelled. A wound is a real hole in the skin with one inner surface under it, and
  the shader paints the anatomy on that surface (ribs, organs, bone; in the torso from the anatomy map) and
  smears it with blood, clots and muck: reds and darks inside, not a clean anatomy model. Don't add bones or
  organs as models; it costs too many triangles. Keep wounds big.
- Painted insides must have depth and sit where the real anatomy is. The torso's anatomy map stores how far in
  each bone and organ is, and the shader follows the line of sight through it, so bones stand in front of organs
  and slide across them as the view moves. Check the layout against real anatomy (for example, ribs slope down to
  the front and are evenly spaced there, not bunched).
- Colors of the insides follow real decay too. Bone is never white in a body (white is sun-bleached bone): ivory
  and pink when fresh, yellow and greasy, stained dark by the rot, tan-brown when dried. Rib cartilage is
  off-white, not the blue of anatomy diagrams.
- Nothing hangs off the zombie model. Spilling guts, blood, bits of brain and intestine, and limbs flying off
  and piling up on the ground are live effects in the game (pixel particle effects and loose pieces), not part
  of the character model.

## Testing Godot assets in a cloud session

No Godot is installed. The official 4.5.1 Linux build downloads from GitHub releases and runs under
`xvfb-run` with `--rendering-driver opengl3`. That software (Compatibility) renderer skips the linear->sRGB step
and ignores instance uniforms, so test harnesses should output palette colors directly and set per-shambler
values per material. Say so when reporting results, and that Forward+ on 4.7 still needs a check.
