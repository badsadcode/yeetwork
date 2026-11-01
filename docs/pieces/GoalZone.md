<!-- Made by tools/make_guide.gd from scripts/mapkit/goal_zone.gd: change the comments there and run it again, not this page. -->
# GoalZone

*Modes: a Map Kit piece (Add Child Node > GoalZone). Script: `scripts/mapkit/goal_zone.gd`.* [All the pieces](README.md)

A football goal for Yeetball: posts, a crossbar and a net, its mouth facing local +Z (turn it toward the pitch). Team: the team that defends it (the other team scores here). A goal counts once the whole ball is past the line (inside Size: width, height, depth behind the line). The frame and net are solid: the ball stays in.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Team** | `Red` | Who defends it (the other team scores in it). Choices: `Red`, `Blue`. |
| **Size** | `(7, 3.5, 2.5)` | The goal's mouth and depth, metres: width X, height Y, depth behind the line Z. |
| **Model** | (none) | Your own model for the frame (a scene: an imported .glb...), instead of the built-in look and the map theme's. The net stays solid where it is. |

## Used in

[Yeetball Stadium](../../maps/yeetball_stadium.tscn) (2)
