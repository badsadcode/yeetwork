<!-- Made by tools/make_guide.gd from scripts/mapkit/lift_platform.gd: change the comments there and run it again, not this page. -->
# LiftPlatform

*Building: a Map Kit piece (Add Child Node > LiftPlatform). Script: `scripts/mapkit/lift_platform.gd`.* [All the pieces](README.md)

A platform moving to and fro between where it is and Travel (from there), a round trip every Period seconds, pausing briefly at each end: a lift, a ferry over a gap. It runs off a clock every player shares, so everyone sees it in the same place. Players and props ride on it. Several lifts: offset them with Phase. Model: your own look (it still bumps as a Size box).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(3, 0.5, 3)` | The platform's box, metres. |
| **Travel** | `(0, 6, 0)` | Where it goes (from where it starts), metres: up 6 is (0, 6, 0). |
| **Period** | `8` | Seconds for a round trip. *(1 to 60)* |
| **Phase** | `0` | 0-1: where in its trip it starts (to offset several lifts). *(0 to 1)* |
| **Model** | (none) | Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look. It works the same; only the look changes. (Its collision stays a box of Size.) |

## Used in

[Courtyard](../../maps/courtyard.tscn), [Yeetwork Prime](../../maps/prime.tscn) (4)
