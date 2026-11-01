<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_target.gd: change the comments there and run it again, not this page. -->
# PuzzleTarget

*Puzzles: a Map Kit piece (Add Child Node > PuzzleTarget). Script: `scripts/mapkit/puzzle_target.gd`.* [All the pieces](README.md)

A bullseye that turns on when something thrown hits it hard enough. Faces its local +Z (rotate it to aim; lay it flat for a floor target). Kind: only that kind of prop counts ("any": anything). Stay On: seconds it stays on after a hit (0: for good).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Radius** | `0.8` | How big the bullseye is, metres. *(0.3 to 4)* |
| **Kind** | `any` | Which props count when they hit it (any: all of them). Choices: `any`, `ball`, `beachball`, `crate`, `crate_big`, `barrel`, `boom_barrel`, `anvil`, `plank`, `couch`, `tire`, `cone`. |
| **Min Speed** | `5` | How fast the thing must hit (m/s): ~5 is a gentle throw, ~15 a hard one. *(0 to 40)* |
| **Stay On** | `4` | Seconds it stays on after a hit (0: for good). *(0 to 120)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[Test Chambers](../../maps/test_chambers.tscn) (4)
