<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_reset.gd: change the comments there and run it again, not this page. -->
# PuzzleReset

*Puzzles: a Map Kit piece (Add Child Node > PuzzleReset). Script: `scripts/mapkit/puzzle_reset.gd`.* [All the pieces](README.md)

The big red button: walk up and press Use (E) on it, and every map prop whose home is inside Area goes back home, and the ones that were destroyed come back. Players can always recover a room they've made a mess of; nobody resets it by bumping into it. Gates and other pieces are not reset. (It also fires when its Inputs switch on, if it has any.)

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Area** | `(16, 8, 16)` | The box whose props are reset: Area Center (relative to the button) and its size. |
| **Area Center** | `(0, 0, 0)` | The middle of Area, from the node. |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Cap` | moves in when it's pressed | nothing is missed |

## Used in

[Moving Day](../../maps/moving_day.tscn) (2), [The Pump House](../../maps/pump_house.tscn) (3), [The Scrapyard](../../maps/scrapyard.tscn) (4), [Test Chambers](../../maps/test_chambers.tscn) (9), [The Warehouse](../../maps/warehouse.tscn) (3)
