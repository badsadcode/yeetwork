@tool
class_name AdventureChapter
extends Resource
## One chapter of an Adventure: a map (a Puzzle level: Map Kit pieces and a PuzzleExit), and what
## the card says as it starts.

## The chapter's map (a scene with MapSettings, Puzzle on, and a PuzzleExit).
@export_file("*.tscn", "*.scn") var map := ""
## Its title on the card and the HUD.
@export var title := ""
## A line or two on the card as it starts.
@export_multiline var intro := ""
