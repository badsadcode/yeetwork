<!-- Made by tools/make_guide.gd from scripts/mapkit/checkpoint.gd: change the comments there and run it again, not this page. -->
# Checkpoint

*Puzzles: a Map Kit piece (Add Child Node > Checkpoint). Script: `scripts/mapkit/checkpoint.gd`.* [All the pieces](README.md)

A flag on a ring. Once any player reaches it, it turns green and (in the Puzzle mode) everyone who dies respawns here. The last one reached counts.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Radius** | `3` | How big its ring is, metres: reach inside it to take the checkpoint. *(1 to 10)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[Moving Day](../../maps/moving_day.tscn) (4), [The Pump House](../../maps/pump_house.tscn) (4), [The Scrapyard](../../maps/scrapyard.tscn) (4), [Test Chambers](../../maps/test_chambers.tscn) (9), [The Warehouse](../../maps/warehouse.tscn)
