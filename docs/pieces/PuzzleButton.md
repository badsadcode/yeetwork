<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_button.gd: change the comments there and run it again, not this page. -->
# PuzzleButton

*Puzzles: a Map Kit piece (Add Child Node > PuzzleButton). Script: `scripts/mapkit/puzzle_button.gd`.* [All the pieces](README.md)

A button on the floor or a wall (rotate it). Press:   touch:   on while anything touches its cap: a player, a prop leaning on it, a ball            rolling over it, a thrown Yeet.   use key: players walk up and press Use (E); props can't press it. Hold Time keeps it on for a while after it's released (use key: after the press; 0 makes each press switch it on or off).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(1.2, 1.2)` | The button's size, metres. |
| **Press** | `touch` | touch: on while anything touches it. use key: players walk up and press Use (E). Choices: `touch`, `use key`. |
| **Hold Time** | `0` | Seconds it stays on after it's let go (use key with 0: each press switches it on or off). *(0 to 60)* |
| **Label** | `Press` | Use key: what the prompt says, "[E] <label>". |
| **Color** | `Color(0.45, 0.48, 0.6)` | Its colour. |
| **Model** | (none) | Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look. It works the same; a child named "Cap" moves down when it's pressed. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Cap` | moves in when it's pressed | nothing moves when it's pressed |

## Used in

[Haunted Yard](../../maps/haunted_yard.tscn), [The Pump House](../../maps/pump_house.tscn), [The Scrapyard](../../maps/scrapyard.tscn), [Test Chambers](../../maps/test_chambers.tscn) (3)
