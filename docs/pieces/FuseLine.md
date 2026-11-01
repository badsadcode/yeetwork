<!-- Made by tools/make_guide.gd from scripts/mapkit/fuse_line.gd: change the comments there and run it again, not this page. -->
# FuseLine

*Puzzles: a Map Kit piece (Add Child Node > FuseLine). Script: `scripts/mapkit/fuse_line.gd`.* [All the pieces](README.md)

A fuse cord along the floor, from this node to End (the editor shows it). Light its start with fire (a burning prop or Yeet, a lit Beacon, or its inputs switching on) and a spark runs along it at Speed; when it reaches the end the fuse is on for good (open a gate, light the Beacon there, set off a barrel). Water on the cord puts the spark out: light it again where it stopped.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **End** | `(0, 0, -6)` | Where the cord ends (from the node): drag it in the 3D view. |
| **Speed** | `1.5` | How fast the spark runs along it, metres a second. *(0.2 to 10)* |

## Used in

[The Pump House](../../maps/pump_house.tscn)
