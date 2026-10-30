class_name ModePuzzle
extends ModeBase
## Co-op puzzle levels (docs/design/PUZZLE_COOP.md): no bots, everybody on one side, no
## damage from friends (falls, fire, acid and explosions still count). Get through the
## level built from Map Kit puzzle pieces; dying respawns you at the last checkpoint
## reached. The clock starts with the match and stops when everyone reaches the exit.
## Then everybody gets the results: the time and its medal (MapSettings medal times), a few
## stats, and awards that celebrate how it went (Noor's list): any solution counts, these
## just cheer for the ridiculous ones.

const AWARDS := {
	"big_brain": ["Big Brain Yeet", "Used every plate, target and button on the way"],
	"structural": ["Structural Disagreement", "Wrecked most of what could be wrecked"],
	"flight": ["Unscheduled Flight", "A Yeet was launched or thrown into a checkpoint or the exit"],
	"failed": ["Task Failed Successfully", "A gate opened right after an explosion went off next to it"],
	"engineer": ["Certified Yeet Engineer", "Reached the exit with a gate still shut: over, around or through"],
}

var _finished := false
# Run statistics (server).
var _destroyed := 0
var _deaths := {} # player id -> deaths
var _yeeted := {} # player id -> times a friend threw / punted them
var _launched := {} # player id -> last time they were launched (any way)
var _throws := {} # prop id -> [start position, time, thrower name]
var _longest := 0.0
var _longest_by := ""
var _ever_on := {} # puzzle piece -> true once it switched on
var _explosions: Array = [] # [time, position]
var _flags := {} # award key -> true


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
	var now: float = world.now()
	if n.active:
		_ever_on[n] = true
		# An objective done right after an explosion next to it.
		if (n.objective != "" or n is PuzzleDoor) and not n is Checkpoint:
			for e in _explosions:
				if now - float(e[0]) < 3.0 and (e[1] as Vector3).distance_to(n.global_position) < 15.0:
					_flags.failed = true
		# Someone launched or thrown into a checkpoint or the exit.
		if n is Checkpoint or n is PuzzleExit:
			var zone := Vector3((n as Checkpoint).radius * 2.0, 3.0, (n as Checkpoint).radius * 2.0) if n is Checkpoint else (n as PuzzleExit).size
			for pl in n.players_in(Vector3(0, zone.y * 0.5, 0), zone):
				if now - float(_launched.get(pl.player_id, -100.0)) < 3.0:
					_flags.flight = true
	if n is Checkpoint and n.active:
		world.server_message("Checkpoint!", Color(0.4, 1.0, 0.5))
	elif n is PuzzleExit and n.active and not _finished:
		_finished = true
		var t: float = world.net_time() - world.puzzle_start
		world.server_puzzle_time(world.puzzle_start, world.net_time())
		world.server_fx("score", n.global_position, Vector3.UP, 1.0)
		world.server_puzzle_results(results(t))


# --- Keeping score -------------------------------------------------------------------

func on_kill(victim: Player, _killer: Player, _cause: String) -> void:
	_deaths[victim.player_id] = _deaths.get(victim.player_id, 0) + 1


func on_prop_broken(_p: Prop) -> void:
	_destroyed += 1


func on_explosion(pos: Vector3) -> void:
	_destroyed += 1 # the barrel itself
	_explosions.append([world.now(), pos])
	if _explosions.size() > 32:
		_explosions.pop_front()


func on_player_launched(pl: Player, _vel: Vector3, attacker: int) -> void:
	_launched[pl.player_id] = world.now()
	if attacker != 0 and attacker != pl.player_id:
		_yeeted[pl.player_id] = _yeeted.get(pl.player_id, 0) + 1


func on_prop_thrown(p: Prop, thrower: Player) -> void:
	_throws[p.prop_id] = [p.global_position, world.now(), thrower.display_name]


func on_prop_impact(p: Prop) -> void:
	var t: Array = _throws.get(p.prop_id, [])
	if t.is_empty() or world.now() - float(t[1]) < 0.15:
		return
	_throws.erase(p.prop_id)
	var d := Vector2(p.global_position.x - t[0].x, p.global_position.z - t[0].z).length()
	if d > _longest:
		_longest = d
		_longest_by = t[2]


## The end screen: time, medal, stats and awards.
func results(t: float) -> Dictionary:
	var ms: MapSettings = world.arena.map_settings
	var medal := ""
	var times := [0.0, 0.0, 0.0]
	if ms:
		times = [ms.gold_time, ms.silver_time, ms.bronze_time]
		for k in 3:
			if times[k] > 0.0 and t <= times[k] and medal == "":
				medal = ["gold", "silver", "bronze"][k]
	var name_of := func(id: int) -> String:
		var pl: Player = world.get_player(id)
		return pl.display_name if pl else "?"
	var stats := []
	stats.append(["Props destroyed", str(_destroyed)])
	var yeets := 0
	var most := -1
	for id in _yeeted:
		yeets += _yeeted[id]
		if most < 0 or _yeeted[id] > _yeeted[most]:
			most = id
	stats.append(["Yeeted by a friend", str(yeets) + ("  (%s the most)" % name_of.call(most) if most >= 0 else "")])
	var deaths := 0
	for id in _deaths:
		deaths += _deaths[id]
	stats.append(["Deaths", str(deaths)])
	stats.append(["Longest throw", "%.1f m  (%s)" % [_longest, _longest_by] if _longest > 0.0 else "-"])
	# Awards.
	var switches: Array = world.arena.puzzle.filter(func(n: PuzzleNode) -> bool: return n is PressurePlate or n is PuzzleTarget or n is PuzzleButton)
	if not switches.is_empty() and switches.all(func(n: PuzzleNode) -> bool: return _ever_on.has(n)):
		_flags.big_brain = true
	var cells := 0
	var broken := 0
	for d in world.arena.destructibles:
		cells += d.cells.size()
		broken += d.broken_cells.size()
	if (cells > 0 and broken * 1.0 / cells >= 0.4) or _destroyed >= 12:
		_flags.structural = true
	for n in world.arena.puzzle:
		if n is PuzzleDoor and n.objective != "" and not n.active:
			_flags.engineer = true
	var awards := []
	for key in AWARDS:
		if _flags.get(key, false):
			awards.append(AWARDS[key])
	return {"time": t, "medal": medal, "medal_times": times, "stats": stats, "awards": awards}


static func clock_text(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
