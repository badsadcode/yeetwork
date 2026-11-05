class_name ModeAdventure
extends ModePuzzle
## The Adventure mode (docs/design/ADVENTURE.md): Puzzle mode's rules over a few maps linked by a
## story (an Adventure file). When everyone reaches a chapter's exit, a moment later everyone
## moves on to the next map together (Main swaps the World on every peer; each says hello
## again, the connection staying up); the clock and the end screen's counts carry over
## (AdventureRun), the last chapter's exit brings the end screen.

const NEXT_AFTER := 2.5 # (seconds from the exit to the next chapter)

var _next_at := -1.0


func mode_name() -> String:
	return "Adventure (co-op)"


func setup(p_world: Node) -> void:
	super.setup(p_world)
	world.puzzle_start = world.net_time() - AdventureRun.time
	var s: Dictionary = AdventureRun.stats
	_destroyed = int(s.get("destroyed", 0))
	_deaths = s.get("deaths", {})
	_yeeted = s.get("yeeted", {})
	_longest = float(s.get("longest", 0.0))
	_longest_by = String(s.get("longest_by", ""))
	_flags = s.get("awards", {})
	_monsters = int(s.get("monsters", 0))
	world.adventure_info = AdventureRun.info()
	world.hud.show_chapter_card(world.adventure_info)
	AdventureRun.save()


## Everyone's at the exit: on to the next chapter, or the end of the adventure.
func _level_done(n: PuzzleExit) -> void:
	AdventureRun.time = world.net_time() - world.puzzle_start
	AdventureRun.stats = {"destroyed": _destroyed, "deaths": _deaths, "yeeted": _yeeted, "longest": _longest, "longest_by": _longest_by, "awards": _flags, "monsters": _monsters}
	if AdventureRun.is_last():
		AdventureRun.erase()
		super._level_done(n)
		return
	world.server_fx("score", n.global_position, Vector3.UP, 1.0)
	world.server_message("Chapter complete!", Color(0.45, 1.0, 0.55), true)
	_next_at = world.now() + NEXT_AFTER


func tick(delta: float) -> void:
	super(delta)
	if _next_at >= 0.0 and world.now() >= _next_at:
		_next_at = -1.0
		AdventureRun.next()
		world.server_next_chapter()


func results(t: float) -> Dictionary:
	var r := super.results(t)
	r.title = "ADVENTURE COMPLETE"
	r.medal = "" # (a level's medal times don't mean much over a whole adventure)
	r.medal_times = [0.0, 0.0, 0.0]
	r.stats.push_front(["Chapters", str(AdventureRun.adventure.chapters.size())])
	return r
