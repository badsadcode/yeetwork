<!-- Made by tools/make_guide.gd from scripts/mapkit/flood_drain.gd: change the comments there and run it again, not this page. -->
# FloodDrain

*Water and ships: a Map Kit piece (Add Child Node > FloodDrain). Script: `scripts/mapkit/flood_drain.gd`.* [All the pieces](README.md)

A grate in the floor that takes water out of the FloodZone it's in, while its inputs are on (always, with no inputs): open the drain to empty the room. Rate: m³ a second. (Water also pours out wherever the floor falls away below the zone: a pit.)

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Rate** | `3` | How fast it takes water out, cubic metres a second. *(0.1 to 40)* |
| **Radius** | `0.8` | How big its grate is, metres. *(0.3 to 3)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. A child named "Intake" is where the water goes in (a grate off to one side of the model, a plughole). |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Intake` | where the water goes in | the water goes in at the piece's origin |

## Start from

- [`custom/make_your_own/my_drain.tscn`](../../custom/make_your_own/my_drain.tscn): a drain of your own
- [`custom/make_your_own/models/drain.glb`](../../custom/make_your_own/models/drain.glb): its model, Intake in place

## Used in

[My Drain](../../custom/make_your_own/my_drain.tscn), [The Pump House](../../maps/pump_house.tscn)
