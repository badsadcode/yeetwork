extends Node
## Developer check for the Adventure mode, on the test adventure Two Small Rooms: it's listed for
## its own mode only; a chapter's exit moves on to the next map (a new World), flags, the clock
## and the counts carried over; it's saved, Continue finds it, Start over doesn't; the last exit
## brings the end screen and clears the save; a broken adventure says what's wrong. The story
## pieces: a note read, a line set off by a zone, a Talking Yeet's lines (their flag remembered,
## and checked in the next chapter). With
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
	await _story_pieces(world.local_player)
	# Through it: press the button, to the exit.
	var door: PuzzleDoor = _piece(PuzzleDoor)
	var exit: PuzzleExit = _piece(PuzzleExit)
	var mode := world.mode_logic as ModeAdventure
	pl.is_bot = true
	pl.bot_brain = null
	_piece(PuzzleButton).server_used(pl)
	await _wait(0.6)
	_check("... the button opens the door", door.active, "")
	AdventureRun.flags["met_the_button"] = true # (and "met_bob": _story_pieces, for real)
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
	await _wait(1.2) # (A voice's line: a second after the chapter starts)
	_check("a story flag from chapter 1 is checked in chapter 2: a line says so", _named("YouMetBob").active and world.hud.story_line_now().contains("Bob says hello"), "flag %s, now saying \"%s\"" % [_named("YouMetBob").active, world.hud.story_line_now()])
	await _wait(2.6)
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


## In chapter 1: a note read (on from then on; walking off closes it), Bob's lines one by one
## (the flag once he's said them all), a zone setting off a line, the next waiting its turn.
func _story_pieces(pl: Player) -> void:
	pl.is_bot = true
	pl.bot_brain = null
	var note: StoryNote = _named("Note")
	_check("a story note: not read yet, not on", not note.active and note.usable(), "")
	note.server_used(pl)
	await _wait(0.3)
	_check("... read: on, and open on the reader's screen", note.active and world.hud.note_open(), "")
	await _shot("a05_note")
	world.use_pressed(pl)
	_check("... Use closes it", not world.hud.note_open(), "")
	note.server_used(pl)
	await _wait(0.2)
	pl.respawn(Vector3(-2, 0.2, 7), 0.0) # (in the room, far from the note, looking at Bob)
	await _wait(0.2)
	_check("... walking off closes it too", not world.hud.note_open(), "")
	var bob: TalkingYeet = _named("Bob")
	var met: StoryFlag = _named("MetBob")
	_check("a Talking Yeet: their name on the prompt, built with a body", bob.usable() and bob.use_label() == "Talk to Bob" and bob._model != null, bob.use_label())
	bob.server_used(pl)
	await _wait(0.2)
	var first_said: String = world.hud.story_line_now()
	bob.server_used(pl) # (too soon: they're still saying it)
	await _wait(0.3)
	_check("... the first line, for everyone, not cut short", first_said.begins_with("Oh! Visitors") and bob._said == 1, "\"%s\", %d said" % [first_said, bob._said])
	await _shot("a06_talking")
	_check("... not on until they've said it all, nor the flag", not bob.active and not met.active, "")
	await _wait(StoryLine.seconds_for(bob.lines[0]) * 0.6)
	bob.server_used(pl)
	await _wait(0.4)
	_check("... all said: on, and StoryFlag remembers", bob.active and met.active and world.story_flag("met_bob"), "on %s, flag %s" % [bob.active, world.story_flag("met_bob")])
	var zone: StoryZone = _named("NearDoor")
	var line: StoryLine = _named("DoorLine")
	_check("a story zone: nobody in it, off; the line it sets off, silent", not zone.active and line._done_at < 0.0, "")
	pl.respawn(zone.global_position + Vector3.UP * 0.2, 0.0)
	await _wait(0.5)
	_check("... a Yeet walks in: on for good, and the line's said", zone.active and line._done_at >= 0.0, "")
	pl.respawn(Vector3(-10, 0.2, 0), 0.0)
	await _wait(0.3)
	_check("... gone again, it stays on", zone.active, "")
	var bad := StoryLine.new()
	bad.name = "Silent"
	_check("the map check notes a line with no words and no Inputs", bad.problems().size() == 2, "%s" % [bad.problems()])
	bad.free()


func _named(n: String) -> Variant:
	for p in world.arena.puzzle:
		if String(p.name) == n:
			return p
	return null


## The host's side of the network check: moves on with one client, then waits for another to
## join late, in chapter 2.
func _with_client() -> void:
	for k in 300:
		await _wait(0.1)
		if world.players.size() >= 2:
			break
	await _wait(2.0)
	_named("Bob").server_used(world.local_player)
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
