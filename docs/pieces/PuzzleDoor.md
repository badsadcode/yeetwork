<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_door.gd: change the comments there and run it again, not this page. -->
# PuzzleDoor

*Puzzles: a Map Kit piece (Add Child Node > PuzzleDoor). Script: `scripts/mapkit/puzzle_door.gd`.* [All the pieces](README.md)

A heavy door (or gate, or bridge, or platform) that slides by Open Offset while its Inputs are on, and back when they go off. It can't be broken: the puzzle is the way through (add a BreakableSlab next to it if you want a messy alternative). Lights above it show red (shut) and green (open).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(4, 4, 0.5)` | The door's box, metres. |
| **Open Offset** | `(0, 3.8, 0)` | Where the door goes when open, relative to where it stands (default: up into the ceiling). |
| **Speed** | `3` | How fast it slides, metres a second. *(0.5 to 20)* |
| **Color** | `Color(0.55, 0.6, 0.72)` | Its colour. |
| **Model** | (none) | Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look. It works the same; only the look changes. It moves with the door; its collision stays a box of Size. |

## Used in

[Example Garden](../../custom/example_garden/example_garden.tscn), [Moving Day](../../maps/moving_day.tscn) (3), [The Pump House](../../maps/pump_house.tscn) (2), [The Scrapyard](../../maps/scrapyard.tscn) (2), [Test Chambers](../../maps/test_chambers.tscn) (9), [The Warehouse](../../maps/warehouse.tscn) (2)
