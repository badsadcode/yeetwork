<!-- Made by tools/make_guide.gd from scripts/mapkit/horn.gd: change the comments there and run it again, not this page. -->
# Horn

*Things in it: a Map Kit piece (Add Child Node > Horn). Script: `scripts/mapkit/horn.gd`.* [All the pieces](README.md)

A horn (a ship's on its bridge, a factory whistle, a stadium klaxon): walk up and press Use to sound it, a deep blast everyone hears. A lever on a post; not too often (a few seconds between blasts). Model: your own; a part named "Lever" is pulled down and back.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Model** | (none) | Your own model for it (instead of the lever on a post, and the map theme's). |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Lever` | is pulled when it sounds | nothing is pulled when it sounds |

## Start from

- [`custom/make_your_own/models/bell.glb`](../../custom/make_your_own/models/bell.glb): a bell on a post, its Lever named

## Used in

[Make Your Own Boat](../../custom/make_your_own/boat.tscn), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [High Seas](../../maps/high_seas.tscn)
