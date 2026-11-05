<!-- Made by tools/make_guide.gd from scripts/mapkit/adventure.gd: change the comments there and run it again, not this page. -->
# Adventure

*Adventure: a type file (Create New > Resource > Adventure). Script: `scripts/mapkit/adventure.gd`.* [All the pieces](README.md)

An adventure for the Adventure mode: a few maps linked by a story, played together, each chapter's PuzzleExit leading everyone on to the next (progress is saved on the host). Make one: right-click a folder > Create New > Resource > Adventure, save it as <name>.adventure.tres in adventures/ (or a custom map's folder), add its Chapters, and it's in the match setup. Each chapter's map is a Puzzle level. See docs/design/ADVENTURE.md.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Display Name** | (empty) | Its name in the match setup and the HUD. |
| **Description** | (empty) | A line or two for the match setup. |
| **Chapters** | (none) | The chapters, in order. |

## Start from

- [`adventures/two_small_rooms.adventure.tres`](../../adventures/two_small_rooms.adventure.tres): the smallest adventure there is: two chapters
