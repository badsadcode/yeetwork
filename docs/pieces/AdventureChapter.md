<!-- Made by tools/make_guide.gd from scripts/mapkit/adventure_chapter.gd: change the comments there and run it again, not this page. -->
# AdventureChapter

*Adventure: a type file (Create New > Resource > AdventureChapter). Script: `scripts/mapkit/adventure_chapter.gd`.* [All the pieces](README.md)

One chapter of an Adventure: a map (a Puzzle level: Map Kit pieces and a PuzzleExit), and what the card says as it starts.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Map** | (empty) | The chapter's map (a scene with MapSettings, Puzzle on, and a PuzzleExit). |
| **Title** | (empty) | Its title on the card and the HUD. |
| **Intro** | (empty) | A line or two on the card as it starts. |

## Start from

- [`adventures/two_small_rooms/room1.tscn`](../../adventures/two_small_rooms/room1.tscn): a chapter's map: Puzzle on, and a PuzzleExit
