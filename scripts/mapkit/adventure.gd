@tool
class_name Adventure
extends Resource
## An adventure for the Adventure mode: a few maps linked by a story, played together, each
## chapter's PuzzleExit leading everyone on to the next (progress is saved on the host). Make
## one: right-click a folder > Create New > Resource > Adventure, save it as
## <name>.adventure.tres in adventures/ (or a custom map's folder), add its Chapters, and it's
## in the match setup. Each chapter's map is a Puzzle level. See docs/design/ADVENTURE.md.

## The folder of the game's own adventures (custom maps' folders count too).
const DIR := "res://adventures"
## What an adventure file's name ends with.
const SUFFIX := ".adventure.tres"

## Its name in the match setup and the HUD.
@export var display_name := ""
## A line or two for the match setup.
@export_multiline var description := ""
## The chapters, in order.
@export var chapters: Array[AdventureChapter] = []


## Its name: Display Name, or the file's.
func title() -> String:
	return display_name if display_name != "" else resource_path.get_file().trim_suffix(SUFFIX).capitalize()


## What's wrong with it ([] when it can be played).
func problems() -> Array:
	var out := []
	if chapters.is_empty():
		out.append("It has no chapters.")
	for i in chapters.size():
		var c: AdventureChapter = chapters[i]
		if c == null or c.map == "":
			out.append("Chapter %d has no map." % (i + 1))
		elif not ResourceLoader.exists(c.map):
			out.append("Chapter %d's map isn't there: %s" % [i + 1, c.map])
	return out


## Every adventure file there is: the game's own, then those in custom maps' folders.
static func list() -> PackedStringArray:
	var out := _in_dir(DIR)
	var root := DirAccess.open(MapPacks.CUSTOM_DIR)
	if root:
		for sub in root.get_directories():
			out.append_array(_in_dir(MapPacks.CUSTOM_DIR.path_join(sub)))
	return out


static func _in_dir(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for f in dir.get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(SUFFIX) and not out.has(path.path_join(f)):
			out.append(path.path_join(f))
	out.sort()
	return out
