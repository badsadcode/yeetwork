<!-- Made by tools/make_guide.gd from scripts/mapkit/story_zone.gd: change the comments there and run it again, not this page. -->
# StoryZone

*Adventure: a Map Kit piece (Add Child Node > StoryZone). Script: `scripts/mapkit/story_zone.gd`.* [All the pieces](README.md)

A place that notices you: on when a Yeet walks into its box (its bottom on the node). What sets off a StoryLine as you enter a room, a door slamming behind you, and later a fight. With Inputs, it only counts while they're on. Nothing to see in the game.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(4, 3, 4)` | Its box, metres. |
| **Stays** | `once` | once: on for good from the first Yeet in. while inside: off again when they've left. Choices: `once`, `while inside`. |
| **Who** | `anyone` | anyone: one Yeet is enough. everyone: every living Yeet has to be in it. Choices: `anyone`, `everyone`. |
