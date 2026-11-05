extends Node
## Developer check for the Adventure mode, on the test adventure Two Small Rooms: it's listed for
## its own mode only; a chapter's exit moves on to the next map (a new World), flags, the clock
## and the counts carried over; it's saved, Continue finds it, Start over doesn't; the last exit
## brings the end screen and clears the save; a broken adventure says what's wrong. With
## --with-client: waits for a client, moves on with it (after the move, a door it must see open,
## and the client's own moves must reach here), then for a second (a late joiner: run
## dev_adventureclient on each). Screenshots. Exits 1 if a step fails.
## Usage: godot -- --host --map res://adventures/two_small_rooms.adventure.tres --mode adventure --tour <dir> --tour-mode adventure

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(100.0).timeout.connect(func():
		print("ADVENTURE CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	if OS.get_cmdline_user_args().has("--with-client"):
		await _with_client()
		return
	var list: Array = Game.list_maps()
	var entry: Dictionary = Game.map_info(Game.map)
	var prime: Dictionary = Game.map_info("prime")
	_check("the test adventure is listed, in its own mode only", not entry.is_empty() and Game.mode_fits(Game.Mode.ADVENTURE, entry) and not Game.mode_fits(Game.Mode.SANDBOX, entry) and not Game.mode_fits(Game.Mode.ADVENTURE, prime), "%d maps" % list.size())
	var bad := Adventure.new()
	_check("a broken adventure says what's wrong", not bad.problems().is_empty() and AdventureRun.begin("res://adventures/nothing.adventure.tres") != "", "%s" % [bad.problems()])
	var first := world
	var pl: Player = world.local_player
	_check("chapter 1: its map, its card", world.mode == Game.Mode.ADVENTURE and world.map_key.ends_with("room1.tscn") and world.adventure_info.chapter == 0 and world.adventure_info.title == "The Button", "%s" % [world.adventure_info])
	await _shot("a01_card")
	await _wait(3.8)
	await _shot("a02_chapter1")
	# Through it: press the button, to the exit.
	var door: PuzzleDoor = _piece(PuzzleDoor)
	var exit: PuzzleExit = _piece(PuzzleExit)
	var mode := world.mode_logic as ModeAdventure
	pl.is_bot = true
	pl.bot_brain = null
	_piece(PuzzleButton).server_used(pl)
	await _wait(0.6)
	_check("... the button opens the door", door.active, "")
	AdventureRun.flags["met_the_button"] = true
	mode._destroyed = 3
	mode._deaths = {pl.player_id: 2}
	await _wait(1.0)
	pl.respawn(exit.global_position + Vector3.UP * 0.2, 0.0)
	var t0: float = world.net_time() - world.puzzle_start
	await _wait(0.6)
	_check("... everyone at the exit: the chapter's complete", mode._finished, "")
	for k in 60:
		await _wait(0.1)
		if world != first and world.local_player != null:
			break
	await _wait(0.5)
	pl = world.local_player
	_check("on to chapter 2, a new map", world != first and pl != null and world.map_key.ends_with("room2.tscn") and world.adventure_info.chapter == 1 and world.adventure_info.title == "The Plate", "%s, %s" % [world.map_key, world.adventure_info])
	mode = world.mode_logic as ModeAdventure
	var clock: float = world.net_time() - world.puzzle_start
	_check("... the flags, the clock and the counts carried over", AdventureRun.flags.has("met_the_button") and clock >= t0 and mode._destroyed == 3 and mode._deaths.get(pl.player_id, 0) == 2, "%.1f s, %d destroyed, %s" % [clock, mode._destroyed, mode._deaths])
	_check("... and it's saved at chapter 2", AdventureRun.saved_chapter(Game.map) == 1, "%d" % AdventureRun.saved_chapter(Game.map))
	# Start over and Continue, as a new run would.
	AdventureRun.want_continue = false
	AdventureRun.begin(Game.map)
	var fresh: bool = AdventureRun.chapter == 0 and AdventureRun.flags.is_empty()
	AdventureRun.want_continue = true
	AdventureRun.begin(Game.map)
	AdventureRun.want_continue = false
	_check("Start over begins at chapter 1; Continue finds chapter 2, the flags too", fresh and AdventureRun.chapter == 1 and AdventureRun.flags.has("met_the_button"), "fresh %s, then chapter %d" % [fresh, AdventureRun.chapter + 1])
	await _wait(3.8)
	await _shot("a03_chapter2")
	# The plate: a crate on it.
	door = _piece(PuzzleDoor)
	exit = _piece(PuzzleExit)
	pl.is_bot = true
	pl.bot_brain = null
	var plate: PressurePlate = _piece(PressurePlate)
	world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, plate.global_position + Vector3.UP * 0.8))
	await _wait(1.5)
	_check("... a crate on the plate opens the door", door.active, "")
	pl.respawn(exit.global_position + Vector3.UP * 0.2, 0.0)
	await _wait(1.0)
	_check("the last exit: the end screen, the save cleared", world.hud._results != null and AdventureRun.saved_chapter(Game.map) == -1, "results %s, saved %d" % [world.hud._results != null, AdventureRun.saved_chapter(Game.map)])
	await _shot("a04_end")
	print("ADVENTURE CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## The host's side of the network check: moves on with one client, then waits for another to
## join late, in chapter 2.
func _with_client() -> void:
	for k in 300:
		await _wait(0.1)
		if world.players.size() >= 2:
			break
	await _wait(2.0)
	var first := world
	(world.mode_logic as ModeAdventure)._level_done(_piece(PuzzleExit))
	for k in 100:
		await _wait(0.1)
		if world != first and world.players.size() >= 2:
			break
	await _wait(1.0)
	var plate: PressurePlate = _piece(PressurePlate)
	world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, plate.global_position + Vector3.UP * 0.8))
	# The client walks to this spot (dev_adventureclient): its moves reach the new World.
	var seen := false
	for k in 100:
		await _wait(0.1)
		for q: Player in world.players.values():
			if q != world.local_player and q.global_position.distance_to(Vector3(-5, 0, 6)) < 1.5:
				seen = true
		if seen:
			break
	_check("after the move, a client's own moves reach the host", seen, "")
	for pass_n in 2: # (the first client leaving, the second coming and going)
		for k in 300:
			await _wait(0.1)
			if world.players.size() == (1 if pass_n == 0 else 2):
				break
	for k in 300:
		await _wait(0.1)
		if world.players.size() == 1:
			break
	print("ADVENTURE HOST ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _piece(kind: Variant) -> Variant:
	for n in world.arena.puzzle:
		if is_instance_of(n, kind):
			return n
	return null


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
