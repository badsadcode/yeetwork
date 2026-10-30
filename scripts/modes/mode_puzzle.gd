class_name ModePuzzle
extends ModeBase
## Co-op puzzle levels (docs/design/PUZZLE_COOP.md): no bots, everybody on one side, no
## damage from friends (falls, fire, acid and explosions still count). Get through the
## level built from Map Kit puzzle pieces; dying respawns you at the last checkpoint
## reached. The clock starts with the match and stops when everyone reaches the exit.

var _finished := false


func mode_name() -> String:
	return "Puzzle (co-op)"


func setup(p_world: Node) -> void:
	super.setup(p_world)
	world.puzzle_start = world.net_time()
	world.puzzle_finish = -1.0
	if world.arena.puzzle.is_empty():
		world.server_message("This map has no puzzle: try one made for the Puzzle mode.", Color(1, 0.8, 0.4))


func allows_bots() -> bool:
	return false


func allow_build() -> bool:
	return true


func hold_time_limit(_a: Player, _b: Player) -> float:
	return 6.0 # carrying a friend across a gap takes a while


## Friends can't hurt each other: no damage from thrown props or bumps by another player.
func allow_damage(pl: Player, attacker: int, cause: String) -> bool:
	if attacker != 0 and attacker != pl.player_id and (cause.begins_with("prop") or cause == "player"):
		return false
	return true


func spawn_point(pl: Player) -> Vector3:
	var best: Checkpoint = null
	for n in world.arena.puzzle:
		if n is Checkpoint and n.active:
			best = n # the last one in the scene that's been reached
	if best:
		return best.spawn_spot(world.rng)
	return super.spawn_point(pl)


func on_puzzle_changed(n: PuzzleNode) -> void:
	if n is Checkpoint and n.active:
		world.server_message("Checkpoint!", Color(0.4, 1.0, 0.5))
	elif n is PuzzleExit and n.active and not _finished:
		_finished = true
		var t: float = world.net_time() - world.puzzle_start
		world.server_puzzle_time(world.puzzle_start, world.net_time())
		world.server_message("LEVEL COMPLETE in %s!" % ModePuzzle.clock_text(t), Color(0.4, 1.0, 0.55), true)
		world.server_fx("score", n.global_position, Vector3.UP, 1.0)


static func clock_text(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
