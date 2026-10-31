# Your own character models

Hats, head extras, outfits, and even the Yeet's own body parts can be your models. Make them
in Blender, save them into a folder, and they're in the game: no code to change.

| Folder | What it is | Where it shows up |
|---|---|---|
| `assets/characters/hats/` | a hat | Character menu → **Hat**, after the built-in hats |
| `assets/characters/extras/` | a head extra (glasses, a mask, a mustache...) | Character menu → **Head extra** |
| `assets/characters/outfits/` | an outfit over the torso | Character menu → **Outfit** (the picker appears once there is one) |
| `assets/characters/parts/` | replaces a body part's built-in shape | on every classic Yeet (see [Body parts](#replacing-body-parts)) |

The file name becomes the name in the menu: `pirate_hat.glb` → *Pirate hat*. Files can be
`.glb` / `.gltf` (from Blender) or Godot scenes (`.tscn` / `.scn`).

There's an example to look at: **`assets/characters/hats/pirate_hat.glb`**, made by
`tools/make_example_hat.py` with the exact steps below.

![The example hat in Blender](images/characters/pirate_hat_blender.jpg)
![The same hat in the game: its band takes the shirt colour](images/characters/pirate_hat_game.jpg)

## Before you start: the character file

Open **`art/characters/characters.blend`** in Blender (4.x or 5.x). It holds the whole Yeet
as the game builds it, in collections you switch on and off with the eye icons:

- **Body**: the classic Yeet, standing on the ground, with the classic face.
- **Hats/…**, **Head extras/…**, **Outfits/…**: every built-in part, already sitting where
  it belongs. Switch one on to see how big things are and where they sit.
- **Characters/Noor Yeet**: Noor's own look.

Things to know about the file:

- **The Yeet faces +Y.** Look at its face with the **Back** view (Ctrl + Numpad 1);
  Front (Numpad 1) shows the back of its head.
- **1 unit = 1 metre**, Z is up, the feet stand at Z = 0.
- **Where the parts are** (their pivots: the point each part turns around when the Yeet
  moves):

  | Part | Pivot (X, Y, Z) | Notes |
  |---|---|---|
  | head | (0, 0, 1.55) | a ball of radius 0.36: its top is at Z 1.91 |
  | torso | (0, 0, 0.95) | |
  | arm_r / arm_l | (±0.43, 0, 1.28): the shoulders | the Yeet's right arm is at +X; the gun is in its right hand |
  | leg_r / leg_l | (±0.16, 0, 0.55): the hips | |

The important rule: **model the part where it sits on the standing Yeet** and leave it there.
Don't move it to the origin and don't parent it to the body's empties. The game works out
which body part it's on and keeps it there as the Yeet runs, jumps and ragdolls.

## Making a hat, step by step

1. **Open** `art/characters/characters.blend`. Switch on **Body** (and a built-in hat of a
   similar size, for reference). Switch the other collections off.
2. **Make a new collection** for your hat (right-click the Scene Collection → *New
   Collection*), so it's easy to select on its own.
3. **Model the hat on the head.** Add your shapes and place them on the head in the Back view
   and from the side. Check it from all round: it should sit on the head, not float above it
   or sink deep into it (a little overlap is good).
4. **Materials.** Every material keeps its colour and textures, except two names:
   - a material named **`Shirt`** (or **`Team`**) is painted the player's shirt colour,
     which is the **team colour** in team modes. Use it for a band or a stripe, so teams
     stay easy to tell apart.
   - a material named **`Skin`** takes the player's skin tone (for ears, a nose...).
5. **Keep it light.** A few hundred to a couple of thousand triangles is plenty: a whole
   Yeet with a hat is about 5,000, and there can be a dozen on screen. Modifiers (bevel,
   subdivision) are fine: they're applied on export.
6. **Export.** Select only your hat's objects (click the collection, or box-select), then
   *File → Export → glTF 2.0*:
   - **Format**: glTF Binary (.glb)
   - **Include → Limit to: Selected Objects** ✔
   - **Transform → +Y Up** ✔ (it's on by default)
   - **Data → Mesh → Apply Modifiers** ✔
   - Save as `assets/characters/hats/<your_hat_name>.glb` in the Yeetwork folder.
7. **See it in the game.**
   - From the **Godot editor**: switch to the editor window (it imports the new file by
     itself), then play (F5). Open *Character* in the main menu and step through **Hat**:
     yours is after the built-in ones.
   - The **built game** (`Yeetwork.exe`) only has the models that were there when it was
     exported: export it again (*Project → Export*), or ask Claude to build it.

Changing it later: edit, export over the same file, and the game picks up the new version
(after the editor imports it, or a new export of the game).

## Head extras and outfits

The same steps, with a different folder:

- **Head extras** (`assets/characters/extras/`): glasses, masks, mustaches, earrings... Model
  them on the head, like a hat. They're worn together with any hat (except the pumpkin
  head, which covers the face).
- **Outfits** (`assets/characters/outfits/`): model them over the torso (pivot at Z 0.95):
  a vest, a cape, armour, a backpack. The shirt underneath stays, so a `Shirt` material on
  the outfit isn't needed unless you want the team colour on the outfit itself. Players pick
  them under **Outfit** in the character menu.

## Replacing body parts

A file in `assets/characters/parts/` named after a body part replaces that part's built-in
shape on every classic Yeet (Noor keeps her own look):

`head.glb`, `torso.glb`, `arm_r.glb`, `arm_l.glb`, `leg_r.glb`, `leg_l.glb`

- Model it in place on the standing Yeet, like everything else (switch off the part you're
  replacing in the Body collection to see where it goes). It turns around the part's pivot
  (the table above), so a new arm swings from the shoulder.
- **A new head keeps the game's face**: the eyes, mouth, brows and cheeks still sit in front
  of it, blink, look around and react. Model the head so the face sits on it (the eyes'
  fronts are at Y ≈ 0.4, Z ≈ 1.62).
- The gun stays in the right hand: an `arm_r` model should end with a hand near
  (0.43, 0.05, 0.73).
- Use `Shirt` for clothing (sleeves, a jacket) and `Skin` for skin, so team colours and skin
  tones still work.

## Changing a built-in part

The built-in hats and extras are made by the game's code (`scripts/player/character_model.gd`),
so they can't be edited in place. To make your own version of one: copy its collection in
the .blend (e.g. *Hats/Top hat*), change the copy, and export it as a custom hat with a new
name. The original stays in the list too.

## Playing online

Custom models are packed into the game when it's exported, so everyone playing together
needs **the same build**. A player with an older build sees the hair tuft instead of a hat
their game doesn't have.

## When something's wrong

| Problem | Likely cause |
|---|---|
| It isn't in the menu | Wrong folder or file type, or the game was started before the file was there (restart; for the .exe, export again). |
| It floats, or sits inside the Yeet | It was moved away from where it sits on the Yeet (to the origin, say) before export. Put it back on the body, export again. |
| It faces backwards | It was modelled facing −Y. The Yeet faces +Y in the .blend (Back view). |
| It's lying on its side | *+Y Up* was off in the export settings. |
| No team colour | The material isn't named `Shirt` (or `Team`). |
| Textures missing | Use .glb (it packs the images in), not .gltf with separate files. |
| Far too big or small | The scene's unit scale was changed. The Yeet is about 2 m tall: model to that. |

## For reference

- `scripts/player/character_parts.gd` finds the files; `CharacterModel._add_custom()` puts
  them on the Yeet.
- `art/characters/characters.blend` is made from the game's code. If the built-in parts
  change, it can be rebuilt (see the README's *Characters* section). Keep your own work in
  your own .blend files or collections, or re-add it after a rebuild.
- `tools/make_example_hat.py` builds the example hat and exports it:
  `blender --background art/characters/characters.blend --python tools/make_example_hat.py`
