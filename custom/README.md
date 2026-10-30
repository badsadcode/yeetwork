# Custom maps (the Map Kit)

Make your own Yeetwork maps in Godot and share them as **map packs**: one `.zip` per map
that players drop into the game's `maps` folder. Nothing gets compiled into the game.

**New to it? Follow the step-by-step guide with pictures:
[docs/CUSTOM_MAPS_GUIDE.md](../docs/CUSTOM_MAPS_GUIDE.md).** This page is the short version.

## What you need

- **Godot 4.7.2** (the standard build, not .NET): <https://godotengine.org/download>
- **Godot's export templates** for 4.7.2 (in Godot: *Editor → Manage Export Templates →
  Download*). Exporting a map pack needs them.
- **This project** (the Yeetwork project folder): open `project.godot` in Godot.

## Make a map

1. Make a folder for your map here: `custom/<your_map>/` (lowercase, no spaces, e.g.
   `custom/pirate_cove/`). Everything your map uses goes in it: the map scene, textures,
   materials, models, sounds, scripts.
2. Make a new 3D scene in that folder (e.g. `pirate_cove.tscn`) and build it from the Map Kit
   nodes: add a **MapSettings** node first (name, sky, ocean...), then blocks, spawn points,
   jump pads and so on. Every piece is described in `docs/MAPPING.md`. Click a piece in the
   3D view to select it; drag the handles on a block's faces (or use the Scale tool) to
   resize it.
3. Press **F6** (Run Current Scene) to play it right away, with bots.
4. Look at `custom/example_garden/` for a small example.

## Your own look

- **Textures and PBR materials.** Import your textures (drag them into your map's folder),
  make a `StandardMaterial3D` (albedo, normal, roughness, metallic, AO maps...) and put it in
  a block's **Custom Material**. It's wrapped onto the block in world space, so it tiles
  evenly at any size; **Texture Size** is how many metres one repeat covers.
- **Models.** Import `.glb` / `.gltf` / `.blend` / `.fbx` models into your folder. Use them as
  scenery (drop them in the scene; give them collision if players should stand on them), or
  as the look of a Map Kit piece: **jump pads, lifts, doors, buttons and pressure plates** have
  a **Model** slot. They keep working the same; only the look changes. A button's model can
  have a child named `Cap` (it moves down when pressed), a pressure plate's a child named
  `Plate` (it sinks).

## Your own functionality (scripts)

You can attach your own scripts to nodes in your map: moving scenery, special effects,
custom rules. Keep them in your map's folder. Keep in mind:

- A map pack with scripts **runs code on the computers of everyone who plays it**. The game
  asks players before loading such a pack ("only allow packs from people you trust"); packs
  without scripts load straight away.
- Scripts run on every player's computer. Gameplay that must be the same for everyone (scores,
  doors) is safest built from the Map Kit's puzzle pieces, which the game keeps in sync.

## Export and share it

From the project folder run:

```
tools\export_map_pack.bat pirate_cove        (Windows)
tools/export_map_pack.sh pirate_cove         (Linux / Mac)
```

(If `godot` isn't on your PATH, set `GODOT` to your Godot executable first, e.g.
`set GODOT=C:\Godot\Godot_v4.7.2-stable_win64_console.exe`.)

You get `build/map_packs/pirate_cove.zip`. It holds your map and what it uses (not the
game's own files: players already have them).

## Install a map pack

Put the `.zip` in a folder called `maps` next to the game (`Yeetwork.exe` /
`Yeetwork.x86_64`), or in the game's data folder: `%APPDATA%\Godot\app_userdata\Yeetwork\maps`
on Windows, `~/.local/share/godot/app_userdata/Yeetwork/maps` on Linux and the Steam Deck.
The map shows up in the map list as *(custom)*.

For multiplayer, **everyone needs the same map pack**: the host picks the map, and a player
without it is told which pack to get.
