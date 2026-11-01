<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_node.gd: change the comments there and run it again, not this page. -->
# PuzzleNode

*Puzzles: a Map Kit piece (Add Child Node > PuzzleNode). Script: `scripts/mapkit/puzzle_node.gd`.* [All the pieces](README.md)

Base of the puzzle pieces (PressurePlate, PuzzleDoor, PuzzleLogic, Checkpoint, PuzzleExit). Every piece is on or off. The server decides (World checks the pieces ten times a second) and every player sees the same. Pieces with Inputs turn on from other pieces: a door opens while its plates are pressed.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Inputs** | (none) | Other puzzle pieces that switch this one on. |
| **Combine** | `all` | all: every input must be on (AND). any: one is enough (OR). Choices: `all`, `any`. |
| **Latch** | off | Once on, stay on (a door that stays open after the puzzle is solved). |
| **Objective** | (empty) | In the Puzzle mode, shown at the top of the screen while this piece is still off, e.g. "Open the gate" (the first unfinished objective in the scene is shown). |
