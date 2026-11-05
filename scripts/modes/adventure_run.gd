class_name AdventureRun
extends RefCounted
## The adventure being played (on the host): which file, which chapter, the story flags and
## what carries over from chapter to chapter. It outlives each chapter's World; saved per
## adventure as each chapter starts, so the host can Continue. Yeets start each chapter fresh:
## health and what they carry don't come along.

## Where it's saved (dev checks use another file: Main).
static var path := "user://adventures.cfg"
static var want_continue := false # (the match setup: Continue, not Start over)
static var file := ""
static var adventure: Adventure
static var chapter := 0
static var flags := {} # story flag -> true
static var time := 0.0 # (seconds played, chapters before this one)
static var stats := {} # (ModeAdventure's counts, chapters before this one)
static var _moving_on := false


## As a World starts: a new run, or a saved one (want_continue), unless it's the next chapter
## of this one. Returns what's wrong ("" when it can be played).
static func begin(adventure_file: String) -> String:
	if _moving_on and adventure_file == file:
		_moving_on = false
		return ""
	_moving_on = false
	var a := load(adventure_file) as Adventure if ResourceLoader.exists(adventure_file) else null
	if a == null:
		return "That adventure isn't there: %s" % adventure_file
	var wrong := a.problems()
	if not wrong.is_empty():
		return "%s can't be played: %s" % [a.title(), wrong[0]]
	file = adventure_file
	adventure = a
	chapter = 0
	flags = {}
	time = 0.0
	stats = {}
	if want_continue:
		_load()
	return ""


## The map of the chapter being played.
static func map_now() -> String:
	return adventure.chapters[chapter].map


static func is_last() -> bool:
	return chapter >= adventure.chapters.size() - 1


## On to the next chapter (the next World that starts takes it up).
static func next() -> void:
	chapter += 1
	_moving_on = true


## What every peer needs to know of it (a late joiner too).
static func info() -> Dictionary:
	var c: AdventureChapter = adventure.chapters[chapter]
	return {"name": adventure.title(), "chapter": chapter, "total": adventure.chapters.size(), "title": c.title, "intro": c.intro}


## The saved chapter of an adventure, or -1 (the match setup offers Continue).
static func saved_chapter(adventure_file: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(adventure_file):
		return -1
	return int(cfg.get_value(adventure_file, "chapter", -1))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(file, "chapter", chapter)
	cfg.set_value(file, "flags", flags)
	cfg.set_value(file, "time", time)
	cfg.set_value(file, "stats", stats)
	cfg.save(path)


## Finished: nothing to continue.
static func erase() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK and cfg.has_section(file):
		cfg.erase_section(file)
		cfg.save(path)


static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(file):
		return
	chapter = clampi(int(cfg.get_value(file, "chapter", 0)), 0, adventure.chapters.size() - 1)
	flags = cfg.get_value(file, "flags", {})
	time = float(cfg.get_value(file, "time", 0.0))
	stats = cfg.get_value(file, "stats", {})
