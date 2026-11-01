<!-- Made by tools/make_guide.gd from scripts/mapkit/wire.gd: change the comments there and run it again, not this page. -->
# Wire

*Puzzles: a Map Kit piece (Add Child Node > Wire). Script: `scripts/mapkit/wire.gd`.* [All the pieces](README.md)

A power cable through Points (this node's space, starting here), live while its inputs are on: it glows and passes the power on (other pieces can take it as an input, like a relay). Show where the power goes: from a battery socket to a magnet, from contacts to a door. Zap Water: a live wire whose end lies in water shocks the Yeets swimming near it.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Points** | `PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -4)])` | Where the cable runs (from the node): add and drag points. |
| **Zap Water** | off | A live end in water shocks the Yeets swimming near it. |

## Used in

[The Scrapyard](../../maps/scrapyard.tscn) (3)
