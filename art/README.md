# Source art

Blender files and other source art. Godot ignores this folder (`.gdignore`).

- `characters/characters.blend`: the game's characters as editable parts. Collections:
  *Body*, *Hats/<hat>*, *Head extras/<extra>*, *Outfits/<outfit>* and *Characters/Noor Yeet*; every part already sits on the head, so
  toggling the eye icons composes a character. Regenerate it from the game code with the
  two commands in the README's *Characters* section.
- `gravity_gun/gravity_gun.blend`: the gravity gun. `tools/make_gravity_gun.py` rebuilds it
  and exports `assets/models/gravity_gun.glb`. The game animates the nodes `Muzzle`, `Core`
  and `ClawPivot0-2` (each with one hinge child), and tints the `Accent` material.
