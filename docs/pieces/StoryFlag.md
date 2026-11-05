<!-- Made by tools/make_guide.gd from scripts/mapkit/story_flag.gd: change the comments there and run it again, not this page. -->
# StoryFlag

*Adventure: a Map Kit piece (Add Child Node > StoryFlag). Script: `scripts/mapkit/story_flag.gd`.* [All the pieces](README.md)

A story's memory, across an Adventure's chapters: "found the diary", "met Bob". remember sets its flag when its Inputs come on; check is on when the flag is set, even from an earlier chapter, so a later map can react to what you did: a line, a door, a Talking Yeet. Flags are saved with the adventure. Outside the Adventure mode they last for the one level. Nothing to see in the game.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Flag** | (empty) | The flag's name (the same on both sides: spelled the same, in any chapter). |
| **Action** | `remember` | remember: set the flag when Inputs come on. check: on when the flag is set. Choices: `remember`, `check`. |
