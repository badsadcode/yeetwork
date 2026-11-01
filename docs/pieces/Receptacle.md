<!-- Made by tools/make_guide.gd from scripts/mapkit/receptacle.gd: change the comments there and run it again, not this page. -->
# Receptacle

*Puzzles: a Map Kit piece (Add Child Node > Receptacle). Script: `scripts/mapkit/receptacle.gd`.* [All the pieces](README.md)

Somewhere to bring things: a fuse box that wants its fuses, a rescue mat for Lost Yeets. Props of the right Kind set down (not held) inside the zone are locked in a slot for good: they can't be grabbed or blown away again. On once Required of them are in. The counter shows how many are in, and the objective can say it too: "Fuses: {count}/{required}". Zone: Size around this node, standing on its floor (local +Y is up).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `fuse` | What goes in it (a fuse, a Lost Yeet, a battery, any prop...). Choices: `fuse`, `lost_yeet`, `any`, `crate`, `crate_big`, `barrel`, `ball`, `beachball`, `anvil`, `couch`, `tire`, `cone`, `boulder`, `battery`. |
| **Required** | `1` | How many it needs to be on. *(1 to 12)* |
| **Size** | `(3, 2.5, 1.6)` | Its box, metres: props set down inside lock into a slot. |
| **Title** | (empty) | Over the counter, e.g. "FUSES" or "RESCUE" ("" for the kind's name). |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[Moving Day](../../maps/moving_day.tscn) (2), [The Scrapyard](../../maps/scrapyard.tscn), [Test Chambers](../../maps/test_chambers.tscn), [The Warehouse](../../maps/warehouse.tscn) (2)
