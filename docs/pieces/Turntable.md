<!-- Made by tools/make_guide.gd from scripts/mapkit/turntable.gd: change the comments there and run it again, not this page. -->
# Turntable

*Puzzles: a Map Kit piece (Add Child Node > Turntable). Script: `scripts/mapkit/turntable.gd`.* [All the pieces](README.md)

A round platform turning around its Y axis: always, or while its Inputs are on (a button that turns the fan around). Whatever stands on it rides along: props, Yeets, a fan. The server turns it and streams the angle; everyone sees the same.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Radius** | `3` | How big it is, metres. *(0.5 to 12)* |
| **Thickness** | `0.4` | How thick the platform is, metres. *(0.1 to 2)* |
| **Speed** | `30` | Degrees per second (negative: the other way). *(-360 to 360)* |
| **Color** | `Color(0.55, 0.6, 0.75)` | Its colour. |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[Test Chambers](../../maps/test_chambers.tscn)
