extends Node
## Developer check for Yeetball: kickoff (the ball waits on its spot, can't be grabbed, then
## goes), a goal (score, celebration, everyone back to their half), the hold limit, a lost
## ball coming back, the win at 5, and bots that actually play the ball. Exits 1 if a step
## fails. Usage: godot -- --host --map yeetball_stadium --mode yeetball --bots 3 --tour x --tour-mode yeetball

var world: Node
var out_dir := ""
var pl: Player
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func():
		print("YEETBALL CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(0.6)
	pl = world.local_player
	# The bots stand still until their part of the check.
	var brains := {}
	for q: Player in world.players.values():
		if q.is_bot and q.bot_brain:
			brains[q] = q.bot_brain
			q.bot_brain = null
			q.cmd.move = Vector2.ZERO
			q.cmd.jump = false
	var mode := world.mode_logic as ModeYeetball
	_check("Yeetball mode with two goals", mode != null and world.arena.goals.size() == 2 and world.is_team_mode(), "")
	var b := mode.ball()
	_check("kickoff: the ball waits on its spot, frozen", b != null and b.freeze and b.global_position.distance_to(world.arena.ball_spot) < 0.3 and mode.phase == ModeYeetball.Phase.KICKOFF, "")
	_place_player(world.arena.ball_spot + Vector3(-3, 0, 0))
	await _wait(0.2)
	_aim_at(b.global_position)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), b.global_position - pl.eye_position())
	await _wait(0.4)
	_check("no grabbing it before the whistle", pl.gun.held_kind == GravityGun.Kind.NONE, "")
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	await _wait(3.2)
	_check("after the countdown it's in play", not b.freeze and mode.phase == ModeYeetball.Phase.PLAY, "phase %d" % mode.phase)
	_shot("y01_kickoff")
	# The hold limit: grab it, and it's let go after 2.5 s.
	await _wait(0.8)
	_place_player(Vector3(-5, 0, 0))
	b.global_position = Vector3(-2.5, 1.2, 0)
	b.linear_velocity = Vector3.ZERO
	await _wait(0.2)
	_aim_at(b.global_position)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), b.global_position - pl.eye_position())
	await _wait(1.0)
	var held := pl.gun.held_kind == GravityGun.Kind.PROP and pl.gun.held_id == b.prop_id
	await _wait(2.2)
	_check("the gun holds the ball 2.5 s at most", held and pl.gun.held_kind == GravityGun.Kind.NONE, "held %s, still holding %s" % [held, pl.gun.held_kind != GravityGun.Kind.NONE])
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	# A goal: punted into Blue's goal by a Red player.
	var blue_goal := mode.goal_of(Game.TEAM_BLUE)
	var red0: int = world.team_scores.get(Game.TEAM_RED, 0)
	b.global_position = blue_goal.mouth() + (blue_goal.global_transform.basis.z * -1.6)
	b.linear_velocity = Vector3.ZERO
	b.last_thrower = pl.player_id if pl.team == Game.TEAM_RED else 0
	await _wait(0.3)
	_check("the whole ball over the line: a goal for Red", world.team_scores.get(Game.TEAM_RED, 0) == red0 + 1 and mode.phase == ModeYeetball.Phase.GOAL, "red %d, phase %d" % [world.team_scores.get(Game.TEAM_RED, 0), mode.phase])
	_look(blue_goal.mouth() + Vector3(-7, 2.5, 4), blue_goal.mouth())
	await _wait(0.3)
	_shot("y02_goal")
	await _wait(ModeYeetball.CELEBRATE + 0.3)
	var lined_up := true
	var wrong := ""
	for q: Player in world.players.values():
		var half := -1.0 if q.team == Game.TEAM_RED else 1.0
		if q.is_alive() and q.global_position.x * half < 0.0:
			lined_up = false
			wrong += " %s (team %d) at %s, state %d" % [q.display_name, q.team, q.global_position.snapped(Vector3.ONE * 0.1), q.state]
	_check("after the goal: kickoff again, everyone in their own half", mode.phase == ModeYeetball.Phase.KICKOFF and b.freeze and lined_up, "phase %d, lined up %s%s" % [mode.phase, lined_up, wrong])
	await _wait(ModeYeetball.COUNTDOWN + 0.3)
	# A lost ball comes back.
	b.global_position = Vector3(0, -30, 0)
	await _wait(0.5)
	_check("a ball lost out of the stadium comes back to the spot", b.global_position.distance_to(world.arena.ball_spot) < 0.5 and mode.phase == ModeYeetball.Phase.KICKOFF, "at %s" % b.global_position)
	await _wait(ModeYeetball.COUNTDOWN + 0.3)
	# The bots play: the ball moves around, they punt it.
	for q in brains:
		q.bot_brain = brains[q]
	var travel := 0.0
	var last := b.global_position
	var max_x := 0.0
	for k in 120:
		await _wait(0.1)
		travel += b.global_position.distance_to(last)
		last = b.global_position
		max_x = maxf(max_x, absf(b.global_position.x))
	_check("the bots chase and punt the ball", travel > 15.0, "ball travelled %.0f m in 12 s, got %.0f m from the middle" % [travel, max_x])
	_look(Vector3(0, 12, -16), Vector3(0, 0, 0))
	await _wait(0.3)
	_shot("y03_bots")
	# The win at 5.
	for q in brains:
		q.bot_brain = null
		q.cmd.move = Vector2.ZERO
	world.team_scores[Game.TEAM_BLUE] = ModeYeetball.GOALS_TO_WIN - 1
	var red_goal := mode.goal_of(Game.TEAM_RED)
	while mode.phase != ModeYeetball.Phase.PLAY:
		await _wait(0.2)
	b.global_position = red_goal.mouth() + (red_goal.global_transform.basis.z * -1.6)
	b.linear_velocity = Vector3.ZERO
	await _wait(0.3)
	_check("the fifth goal wins, the scores reset", world.team_scores.get(Game.TEAM_BLUE, 0) == 0 and world.team_scores.get(Game.TEAM_RED, 0) == 0, "%s" % world.team_scores)
	print("YEETBALL CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _place_player(pos: Vector3) -> void:
	pl.respawn(pos, 0.0)
	pl.cmd.move = Vector2.ZERO


func _aim_at(p: Vector3) -> void:
	var to := p - pl.eye_position()
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


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
