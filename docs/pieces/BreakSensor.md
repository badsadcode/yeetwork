<!-- Made by tools/make_guide.gd from scripts/mapkit/break_sensor.gd: change the comments there and run it again, not this page. -->
# BreakSensor

*Puzzles: a Map Kit piece (Add Child Node > BreakSensor). Script: `scripts/mapkit/break_sensor.gd`.* [All the pieces](README.md)

Turns on once a BreakableSlab is broken enough: wreck the wall, the pillar, the statue and the door opens (destruction puzzles). Invisible in game; place it anywhere.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Slab** | (none) | The BreakableSlab to watch. |
| **Percent** | `30` | How much of it must be broken (percent of its pieces). *(1 to 100)* |

## Used in

[The Pump House](../../maps/pump_house.tscn) (2), [Test Chambers](../../maps/test_chambers.tscn) (2)
