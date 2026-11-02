# Custom character models

Drop models here and they're in the game, no code needed:

- `hats/`: hats (Character menu: Hat)
- `extras/`: head extras (Character menu: Head extra)
- `outfits/`: outfits over the torso (Character menu: Outfit)
- `parts/`: replaces a body part's built-in shape: `head`, `torso`, `arm_r`, `arm_l`, `leg_r`, `leg_l`
- `guns/`: gravity guns: `default.glb` is the one everyone carries, any other is picked in the
  Character menu (Gun). Model it over `art/gravity_gun/gravity_gun.blend`; the example is
  `scrap_gun.glb`

`.glb` / `.gltf` from Blender (or Godot `.tscn` / `.scn`), modelled where the part sits on a
standing Yeet in `art/characters/characters.blend`. Materials named `Shirt` take the team
colour, `Skin` the skin tone. Step by step: [docs/CHARACTERS.md](../../docs/CHARACTERS.md).
