<!-- Made by tools/make_guide.gd from scripts/mapkit/pulley.gd: change the comments there and run it again, not this page. -->
# Pulley

*Puzzles: a Map Kit piece (Add Child Node > Pulley). Script: `scripts/mapkit/pulley.gd`.* [All the pieces](README.md)

Two wheels (Width apart along local X) and one rope over them, a lift platform hanging on each end: Drop A (the -X side) and Drop B below the wheels. The rope's length is fixed, so what goes down on one side comes up on the other: the heavier side sinks. Yeets standing on a platform weigh 70 kg each; an anvil 300. The counterweight lift: stand on one platform, load the other until you rise to the ledge. Platforms stay level and under their wheels.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Width** | `5` | How far apart its two wheels are, metres. *(1 to 20)* |
| **Drop A** | `8` | How far below its wheel platform A hangs at the start, metres. *(1 to 30)* |
| **Drop B** | `3` | How far below its wheel platform B hangs at the start, metres. *(1 to 30)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[The Scrapyard](../../maps/scrapyard.tscn)
