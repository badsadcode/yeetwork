<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_exit.gd: change the comments there and run it again, not this page. -->
# PuzzleExit

*Puzzles: a Map Kit piece (Add Child Node > PuzzleExit). Script: `scripts/mapkit/puzzle_exit.gd`.* [All the pieces](README.md)

The way out: a glowing archway over a zone of Size. On when every living player is inside (and its Inputs are on, if it has any: e.g. the package must be delivered first). In the Puzzle mode, that finishes the level.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(4, 3, 4)` | The exit's box, metres: every living player inside finishes the level. |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[Moving Day](../../maps/moving_day.tscn), [The Pump House](../../maps/pump_house.tscn), [The Scrapyard](../../maps/scrapyard.tscn), [Test Chambers](../../maps/test_chambers.tscn), [The Warehouse](../../maps/warehouse.tscn)
