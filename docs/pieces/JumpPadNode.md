<!-- Made by tools/make_guide.gd from scripts/mapkit/jump_pad.gd: change the comments there and run it again, not this page. -->
# JumpPadNode

*Building: a Map Kit piece (Add Child Node > JumpPadNode). Script: `scripts/mapkit/jump_pad.gd`.* [All the pieces](README.md)

A pad that throws players and props through the air to a spot: up to a ledge, across a gap. Aim it by moving Target (from the pad: drag it in the 3D view); it throws just hard enough for the arc to peak Arc Height above the higher end. The editor draws the arc in green. Velocity Override: throw with exactly this instead.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Target** | `(0, 6, -8)` | Where it throws you to (from the pad): drag it in the 3D view, the arc shows in green. |
| **Arc Height** | `2.5` | How high the arc peaks above the higher end, metres. *(0.5 to 30)* |
| **Velocity Override** | `(0, 0, 0)` | If set, launch with exactly this velocity (relative to the pad) instead of aiming at `target` (the converted built-in maps use it to keep their original pads). |
| **Model** | (none) | Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look. It works the same; only the look changes. |

## Used in

[Example Garden](../../custom/example_garden/example_garden.tscn), [Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (2), [Make Your Own Boat](../../custom/make_your_own/boat.tscn), [Courtyard](../../maps/courtyard.tscn) (3), [Facing Yeets](../../maps/facing.tscn) (10), [The Fortress](../../maps/fortress.tscn) (8), [The Foundry](../../maps/foundry.tscn) (17), [High Seas](../../maps/high_seas.tscn) (8), [Hoops Court](../../maps/hoops_court.tscn) (4), [Lagoon](../../maps/lagoon.tscn) (3), [Yeetwork Prime](../../maps/prime.tscn) (8)
