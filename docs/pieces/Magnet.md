<!-- Made by tools/make_guide.gd from scripts/mapkit/magnet.gd: change the comments there and run it again, not this page. -->
# Magnet

*Puzzles: a Map Kit piece (Add Child Node > Magnet). Script: `scripts/mapkit/magnet.gd`.* [All the pieces](README.md)

An electromagnet facing its local -Y (hang it from a ceiling; rotate it to face a wall). While its inputs are on (always, with no inputs) it pulls metal props within Reach toward its face and holds them there: barrels, anvils, batteries, fuses, fans. Switch it off and they drop. A Yeet with the gun can still pull a light thing off it. Strength: pull at the face (m/s², gravity is 24); heavy things feel less of it (an anvil about a third).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Reach** | `7` | How far below it pulls, metres. *(1 to 20)* |
| **Strength** | `70` | How hard it pulls (gravity is 24). *(10 to 200)* |
| **Radius** | `0.8` | How big its face is, metres. *(0.3 to 3)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[The Scrapyard](../../maps/scrapyard.tscn)
