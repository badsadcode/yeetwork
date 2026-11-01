<!-- Made by tools/make_guide.gd from scripts/mapkit/float_switch.gd: change the comments there and run it again, not this page. -->
# FloatSwitch

*Water and ships: a Map Kit piece (Add Child Node > FloatSwitch). Script: `scripts/mapkit/float_switch.gd`.* [All the pieces](README.md)

A float on a post: on while the water in its FloodZone stands at least Level above the node (the float rides up the post and its lamp turns green). Fill the room to open the hatch; use a PuzzleLogic with Invert for "until the water's drained".

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Level** | `1` | On while the water stands this many metres above the node. *(0.1 to 10)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. A child named "Float" rides up and down on the water. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Float` | rides up and down on the water | nothing rides on the water |

## Used in

[The Pump House](../../maps/pump_house.tscn)
