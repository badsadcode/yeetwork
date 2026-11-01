<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_logic.gd: change the comments there and run it again, not this page. -->
# PuzzleLogic

*Puzzles: a Map Kit piece (Add Child Node > PuzzleLogic). Script: `scripts/mapkit/puzzle_logic.gd`.* [All the pieces](README.md)

Combines other pieces' states. Invisible in game.   gate:     on when all (AND) or any (OR) of its Inputs are on.   window:   on when every input has been on within the last Window seconds ("hit all             three targets within 3 s": three players at once, or one very clever throw).   sequence: on once the inputs have switched on in list order (a wrong one starts over). Invert flips the result; Hold Time keeps it on for a while after it would go off (a door that closes again 5 s after you step off the plate: race through!).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Mode** | `gate` | gate: all or any of its inputs (Combine). window: every input on within the last Window seconds. sequence: its inputs switched on in list order (a wrong one starts over). Choices: `gate`, `window`, `sequence`. |
| **Window** | `3` | Window mode: seconds. *(0.5 to 60)* |
| **Invert** | off | On when it would be off, and off when on. |
| **Hold Time** | `0` | Seconds it stays on after it would go off (a timed door). *(0 to 60)* |

## Used in

[The Pump House](../../maps/pump_house.tscn), [Test Chambers](../../maps/test_chambers.tscn) (2)
