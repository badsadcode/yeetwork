<!-- Made by tools/make_guide.gd from scripts/mapkit/pressure_plate.gd: change the comments there and run it again, not this page. -->
# PressurePlate

*Puzzles: a Map Kit piece (Add Child Node > PressurePlate). Script: `scripts/mapkit/pressure_plate.gd`.* [All the pieces](README.md)

A plate in the floor, on while enough weight stands on it: crates, anvils, barrels, a friend (a player counts as 70). The rim glows amber, then green when pressed. Masses: crate 25, barrel 40, couch 60, big crate 70, anvil 300, player 70.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(2.4, 2.4)` | The plate's size, metres. |
| **Required Mass** | `40` | On while this much weighs on it, kg: crate 25, barrel 40, couch 60, big crate 70, Yeet 70, anvil 300. *(1 to 400)* |
| **Color** | `Color(0.5, 0.55, 0.68)` | Its colour. |
| **Model** | (none) | Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look. It works the same; only the look changes. A child named "Plate" sinks when it's pressed. The plate's collision stays a slab of Size. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Plate` | sinks when it's weighed down | nothing sinks when it's weighed down |

## Used in

[Example Garden](../../custom/example_garden/example_garden.tscn), [Moving Day](../../maps/moving_day.tscn) (3), [The Pump House](../../maps/pump_house.tscn), [The Scrapyard](../../maps/scrapyard.tscn) (2), [Test Chambers](../../maps/test_chambers.tscn) (2), [The Warehouse](../../maps/warehouse.tscn)
