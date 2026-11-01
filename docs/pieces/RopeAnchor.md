<!-- Made by tools/make_guide.gd from scripts/mapkit/rope_anchor.gd: change the comments there and run it again, not this page. -->
# RopeAnchor

*Puzzles: a Map Kit piece (Add Child Node > RopeAnchor). Script: `scripts/mapkit/rope_anchor.gd`.* [All the pieces](README.md)

A rope from this point (a ceiling, a beam) holding a prop, which it spawns hanging Length below. The prop swings on the rope, and Yeets can push it, punt it, even grab it, but it won't come off. The rope can be cut: fire burns through it in a second, and its Inputs (a lever, a plate) let go of it. It's on once cut: drop the anvil on the plate, the cage on the beacon, the crate into the water. Cut is cut (for good).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `anvil` | The prop it holds. Choices: `crate`, `crate_big`, `barrel`, `boom_barrel`, `anvil`, `couch`, `tire`, `battery`, `boulder`, `lost_yeet`. |
| **Length** | `3` | How long the rope is, metres. *(0.5 to 20)* |
| **Burnable** | on | Fire burns through it (hold something burning to it). |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[The Scrapyard](../../maps/scrapyard.tscn)
