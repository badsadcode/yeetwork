extends Node
## Developer check for the Puzzle mode: plays through Moving Day by itself (a crate on the
## first plate, a player and the anvil on the two heavy plates, a checkpoint and a respawn
## there, the exit), checks every step and saves screenshots. Exits 1 if a step fails.
## Usage: godot -- --host --map moving_day --mode puzzle --tour <dir> --tour-mode puzzle
## (add --headless to only check)

var world: Node
var out_dir := ""
var pl: Player
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("PUZZLE CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	pl = world.local_player
	var hud_ok: bool = world.mode == Game.Mode.PUZZLE and world.puzzle_start >= 0.0
	_check("puzzle mode running, no bots", hud_ok and world.players.size() == 1, "mode %d, players %d" % [world.mode, world.players.size()])
	_check("first objective shown", world.puzzle_objective() == "Put a crate on the plate to open the gate", world.puzzle_objective())
	_look(Vector3(0, 4.5, 1.5), Vector3(2, 0.5, 12))
	await _wait(0.4)
	_shot("01_room1")
	# Room 1: a crate on the plate.
	var plate1: PuzzleNode = _piece("Plate1")
	var crate := _nearest("crate", plate1.global_position)
	crate.global_position = plate1.global_position + Vector3(0, 0.8, 0)
	crate.linear_velocity = Vector3.ZERO
	await _wait(1.6)
	_check("crate on plate opens the gate", plate1.active and _piece("Gate1").active, "plate %s (%.0f kg), gate %s" % [plate1.active, (plate1 as PressurePlate).weight, _piece("Gate1").active])
	_shot("02_gate_open")
	# Room 2: through checkpoint 1; one heavy plate is not enough...
	_place_player(_piece("Checkpoint1").global_position + Vector3(0, 0.3, 0))
	await _wait(0.5)
	_place_player(_piece("Plate2").global_position + Vector3(0, 0.3, 0))
	await _wait(0.8)
	_check("one heavy plate alone keeps the gate shut", _piece("Plate2").active and not _piece("Gate2").active, "plate2 %s gate2 %s" % [_piece("Plate2").active, _piece("Gate2").active])
	# ...the anvil on the other one opens it.
	var plate3: PuzzleNode = _piece("Plate3")
	var anvil := _nearest("anvil", plate3.global_position)
	anvil.global_position = plate3.global_position + Vector3(0, 0.6, 0)
	anvil.linear_velocity = Vector3.ZERO
	await _wait(1.2)
	_check("both plates open the second gate", _piece("Gate2").active, "plate3 %s (%.0f kg)" % [plate3.active, (plate3 as PressurePlate).weight])
	_check("checkpoint 1 reached on the way", _piece("Checkpoint1").active, "")
	_look(Vector3(0, 5, 18), Vector3(0, 1, 30))
	await _wait(0.6)
	_shot("03_room2")
	# Room 3: the checkpoint, then a respawn there.
	_place_player(_piece("Checkpoint2").global_position + Vector3(0, 0.3, 0))
	await _wait(0.6)
	_check("checkpoint 2 reached", _piece("Checkpoint2").active, "")
	world.server_damage_player(pl, 1000.0, 0, "void", pl.body_center(), Vector3.UP)
	await _wait(World.RESPAWN_TIME + 0.8)
	var d := pl.global_position.distance_to(_piece("Checkpoint2").global_position)
	_check("respawn at the last checkpoint", pl.is_alive() and d < 4.0, "%.1f m from it" % d)
	_look(Vector3(0, 4, 31), Vector3(0, 0, 44))
	await _wait(0.4)
	_shot("04_moat")
	# The exit.
	_check("objective before the exit", world.puzzle_objective() == "Get everyone to the exit", world.puzzle_objective())
	_place_player(_piece("Exit").global_position + Vector3(0, 0.3, 0))
	await _wait(0.8)
	_check("everyone at the exit finishes the level", world.puzzle_finish >= 0.0 and world.puzzle_objective() == "Level complete!", "finish %.1f, objective %s" % [world.puzzle_finish, world.puzzle_objective()])
	_look(Vector3(0, 3, 43), Vector3(0, 1.5, 50))
	await _wait(0.5)
	_shot("05_exit")
	print("PUZZLE CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _piece(n: String) -> PuzzleNode:
	for p in world.arena.puzzle:
		if p.name == n:
			return p
	push_error("no puzzle piece " + n)
	return null


func _nearest(kind: String, to: Vector3) -> Prop:
	var best: Prop = null
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.kind == kind and (best == null or p.global_position.distance_to(to) < best.global_position.distance_to(to)):
			best = p
	return best


func _place_player(pos: Vector3) -> void:
	pl.respawn(pos, 0.0)
	pl.cmd.move = Vector2.ZERO


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var to := target - eye
	_place_player(eye - Vector3(0, Player.EYE_STAND, 0))
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
