<!-- Made by tools/make_guide.gd from scripts/mapkit/seesaw.gd: change the comments there and run it again, not this page. -->
# Seesaw

*Puzzles: a Map Kit piece (Add Child Node > Seesaw). Script: `scripts/mapkit/seesaw.gd`.* [All the pieces](README.md)

The Yeetapult: a plank on a pivot, along its local X. It tips toward the heavier side (props and players weigh what they weigh), takes a kick from things landing on it, and when an end slams down hard, whatever stands on the other end is launched up and away: drop an anvil on the red end, fly off the yellow one. Launch Boost scales the yeet. The server simulates it and streams the angle; the node is the pivot.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Length** | `7` | How long the plank is, metres (along X). *(2 to 16)* |
| **Width** | `1.6` | How wide the plank is, metres. *(0.6 to 6)* |
| **Pivot Height** | `0.8` | Height of the pivot above the floor (the node sits at the pivot). *(0.3 to 3)* |
| **Max Angle** | `18` | How far it tips each way, degrees. *(5 to 40)* |
| **Launch Boost** | `1.6` | How hard the end that flies up launches what stands on it. *(0.5 to 4)* |
| **Color** | `Color(0.85, 0.62, 0.35)` | Its colour. |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. A child named "Plank" tips with the plank (the rest stays put). |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Plank` | tips (the rest of the model stays put) | the whole model stays put while the plank tips |

## Used in

[Moving Day](../../maps/moving_day.tscn), [Test Chambers](../../maps/test_chambers.tscn), [The Warehouse](../../maps/warehouse.tscn)
