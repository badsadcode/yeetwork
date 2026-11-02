<!-- Made by tools/make_guide.gd from scripts/mapkit/animated_model.gd: change the comments there and run it again, not this page. -->
# AnimatedModel

*Building: a Map Kit piece (Add Child Node > AnimatedModel). Script: `scripts/mapkit/animated_model.gd`.* [All the pieces](README.md)

Your own model, moving the way you animated it in Blender: a windmill's sails turning, a sign swinging, a buoy bobbing, a piston, a platform sliding to and fro, a drawbridge. Object animation is enough (no armature needed); an armature works too.

- Model: a .glb/.gltf/.blend/.tscn with at least one animation; Animation picks which.
- Parts named "Collision..." (CollisionDeck, Collision_Arm) are what things bump into, moving with the animation and carrying what stands on them (hidden in the game; a moving part is best a box or another simple shape: it's made convex). With none, it's only seen: you walk through it.
- Every player sees it at the same point of its animation: it runs off the match clock, nothing is sent.
- Inputs (it's a puzzle piece): without any, it plays all the time; with some, it plays while they're on (Play once: forward while on, back while off: a drawbridge, a gate you made). It's on (an input for others) while it plays.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Model** | (none) | Your model (with its animation). |
| **Animation** | (empty) | Which of its animations plays (empty: the first one). |
| **Speed** | `1` | How fast: 1 as you animated it, 2 twice as fast, 0.5 half as fast. *(0.05 to 10, or more)* |
| **Play** | `loop` | loop: over and over. ping pong: there and back again. once: to its end, then it stays there (with Inputs: forward while they're on, back while they're off). Choices: `loop`, `ping pong`, `once`. |
| **Offset** | `0` | Seconds into its animation it starts (several the same: offset them so they don't move in step). |
| **Solid** | on | Its parts named "Collision..." are solid and move with it. |
| **Preview** | on | In the editor, show it moving (off: its first frame). |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Collision...` | any part whose name starts so is solid, moving with the animation and carrying what stands on it (made convex, hidden in the game) | nothing is missed |

## Start from

- [`custom/make_your_own/models/windmill.glb`](../../custom/make_your_own/models/windmill.glb): a windmill, its sails turning (loop)
- [`custom/make_your_own/models/sign.glb`](../../custom/make_your_own/models/sign.glb): an inn sign swinging (ping pong)
- [`custom/make_your_own/models/platform.glb`](../../custom/make_your_own/models/platform.glb): a platform sliding 6 m and back, carrying riders (ping pong)
- [`custom/make_your_own/models/drawbridge.glb`](../../custom/make_your_own/models/drawbridge.glb): a drawbridge lowering (once: wire it to a button)

## Used in

[Make Your Own Workshop](../../custom/make_your_own/workshop.tscn) (4)
