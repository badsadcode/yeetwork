<!-- Made by tools/make_guide.gd from scripts/mapkit/flood_valve.gd: change the comments there and run it again, not this page. -->
# FloodValve

*Water and ships: a Map Kit piece (Add Child Node > FloodValve). Script: `scripts/mapkit/flood_valve.gd`.* [All the pieces](README.md)

A pipe that pours water into the FloodZone it's in while its inputs are on (always, with no inputs): fill a room, raise a raft, flush a corridor. Put it on a wall or a ceiling; the water falls straight down from the node. Rate: m³ a second (a 4 x 4 m room rises ~6 cm a second at 1). Total: stops after pouring this much (0: never).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Rate** | `2` | How fast it pours, cubic metres a second (a 10 x 12 m room rises 1 m per 120). *(0.1 to 20)* |
| **Total** | `0` | Stops after pouring this much, cubic metres (0: never). *(0 to 2000)* |
| **Radius** | `0.6` | How wide the water lands where it pours, metres. *(0.2 to 3)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. A child named "Wheel" turns while it pours; one named "Spout" is where the water comes out, the way it points (its Y axis: a Blender arrow empty's arrow), say sideways out of a pipe in a wall: the water arcs out and lands where it falls. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Spout` | where the water comes out, pointing the way it pours (its Y axis: the arrow of a Blender "Single Arrow" empty) | the water falls straight down from the piece's origin |
| `Wheel` | turns while it pours | nothing is missed |

## Start from

- [`custom/make_your_own/my_pipe.tscn`](../../custom/make_your_own/my_pipe.tscn): a pipe of your own, saved as its own piece
- [`custom/make_your_own/models/pipe.glb`](../../custom/make_your_own/models/pipe.glb): its model, Spout and Wheel in place

## Used in

[My Pipe](../../custom/make_your_own/my_pipe.tscn), [The Pump House](../../maps/pump_house.tscn) (2)
