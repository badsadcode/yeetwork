extends Node
## Developer check for Yeetball: kickoff (the ball waits on its spot, can't be grabbed, then
## goes), a goal (score, celebration, everyone back to their half), the hold limit, a lost
## ball coming back, bots that actually play the ball, the win at 5 and full time, the match
## clock and golden goal, no camping in your own net, and TOTAL YEET's multi-ball and
## barrels. Exits 1 if a step fails. Usage: godot -- --host --map yeetball_stadium --mode yeetball --bots 3 --tour x --tour-mode yeetball

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
	_check("the fifth goal wins: full time", mode.phase == ModeYeetball.Phase.FULL_TIME and world.team_scores.get(Game.TEAM_BLUE, 0) == ModeYeetball.GOALS_TO_WIN, "phase %d, %s" % [mode.phase, world.team_scores])
	await _wait(0.5)
	var r: Dictionary = world.mode_state.get("results", {})
	var shown_end: bool = world.hud._match_end != null if DisplayServer.get_name() != "headless" else true
	_check("full time: the results screen, for every peer", r.get("winner", 0) == Game.TEAM_BLUE and r.get("blue", 0) == ModeYeetball.GOALS_TO_WIN and shown_end, "%s, panel %s" % [r, shown_end])
	_shot("y06_results")
	await _wait(3.0)
	_check("full time waits for the host", mode.phase == ModeYeetball.Phase.FULL_TIME, "phase %d" % mode.phase)
	mode.next_match()
	await _wait(0.3)
	var gone: bool = world.hud._match_end == null
	_check("Next match: scores reset, kickoff, the screen closes", world.team_scores.get(Game.TEAM_BLUE, 0) == 0 and world.team_scores.get(Game.TEAM_RED, 0) == 0 and mode.phase == ModeYeetball.Phase.KICKOFF and gone and world.mode_state.get("results", {}).is_empty(), "%s, phase %d, screen gone %s" % [world.team_scores, mode.phase, gone])
	# The clock: runs in play only, shared with the HUD.
	mode.minutes = 1
	mode._new_match()
	await _wait(ModeYeetball.COUNTDOWN + 0.3)
	var c0 := mode.clock_left
	await _wait(1.0)
	var ran := c0 - mode.clock_left
	var shown := ModeYeetball.clock_text(world.mode_state, world.net_time())
	_check("the match clock runs in play, the HUD shows it", ran > 0.7 and ran < 1.3 and world.mode_state.get("clock_end", -1.0) > 0.0 and shown.begins_with("0:5"), "ran %.2f s, shows %s" % [ran, shown])
	# Time up with the scores level: golden goal, and the next goal wins.
	world.team_scores = {1: 1, 2: 1}
	mode.clock_left = 0.2
	await _wait(0.5)
	_check("level at full time: golden goal", mode.overtime and mode.phase == ModeYeetball.Phase.PLAY and ModeYeetball.clock_text(world.mode_state, world.net_time()) == "GOLDEN GOAL", "overtime %s, phase %d" % [mode.overtime, mode.phase])
	b.global_position = blue_goal.mouth() + (blue_goal.global_transform.basis.z * -1.6)
	b.linear_velocity = Vector3.ZERO
	await _wait(0.3)
	_check("the golden goal ends it", mode.phase == ModeYeetball.Phase.FULL_TIME and world.team_scores.get(Game.TEAM_RED, 0) == 2, "phase %d, %s" % [mode.phase, world.team_scores])
	await _wait(0.3)
	mode.next_match()
	# (the rules run on physics time, which can fall behind the wall clock in a hitch)
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 20.0)
	# No camping in your own net.
	var home := mode.goal_of(pl.team)
	mode._idle = -100.0
	var camp_at := home.global_transform * Vector3(0, 0.1, -1.3)
	_place_player(camp_at)
	await _wait(0.3)
	var camping := home.contains_ball(pl.global_position + Vector3.UP * 0.5, 0.0)
	await _wait(ModeYeetball.CAMP_TIME + 1.5)
	var out := not home.contains_ball(pl.global_position + Vector3.UP * 0.5, 0.0)
	_check("no camping in your own net", camping and out and mode.phase == ModeYeetball.Phase.PLAY, "in the net at first %s, now at %s, phase %d" % [camping, pl.global_position.snapped(Vector3.ONE * 0.1), mode.phase])
	# Knockdown on (Classic rules): a fast ball bowls a Yeet over, without hurting.
	mode.knockdown = true
	var victim: Player = null
	for q: Player in world.players.values():
		if q.is_bot and q.is_alive():
			victim = q
			break
	victim.respawn(world.arena.ball_spot + Vector3(0, -1.2, 6), 0.0)
	await _wait(0.4)
	var hp0 := victim.hp
	var target := victim.body_center()
	b.global_position = target + Vector3(0, 0, -5)
	b.linear_velocity = Vector3(0, 0, 22)
	var knocked := false
	for k in 12:
		await _wait(0.05)
		knocked = knocked or victim.state != 0 or victim.velocity.length() > 6.0
	_check("knockdown: a fast ball bowls a Yeet over, no damage", knocked and victim.hp >= hp0, "state %d, speed %.1f, hp %d -> %d" % [victim.state, victim.velocity.length(), hp0, victim.hp])
	mode.knockdown = false
	await _wait(1.5)
	# TOTAL YEET: multi-ball and barrels; a goal with an extra ball counts.
	mode.rules = ModeYeetball.Rules.TOTAL
	mode._multiball_t = 0.0
	await _wait(0.3)
	_check("TOTAL YEET: multi-ball", mode.balls().size() == 3, "%d balls" % mode.balls().size())
	mode._barrel_t = 0.0
	await _wait(0.2)
	var barrels: int = world.props.values().filter(func(p): return is_instance_valid(p) and p.kind == "boom_barrel").size()
	_check("TOTAL YEET: a barrel from the sky", barrels > 0, "%d boom barrels" % barrels)
	_look(Vector3(0, 12, -16), world.arena.ball_spot)
	await _wait(0.6)
	_shot("y04_multiball")
	_look(Vector3(0, 2, 4), Vector3(0, 25, 40)) # the balls out of view: arrows at the edge
	await _wait(0.3)
	_shot("y05_arrows")
	var red1: int = world.team_scores.get(Game.TEAM_RED, 0)
	var x: Prop = mode.balls()[1]
	x.global_position = blue_goal.mouth() + (blue_goal.global_transform.basis.z * -1.6)
	x.linear_velocity = Vector3.ZERO
	await _wait(0.3)
	_check("a goal with an extra ball counts", world.team_scores.get(Game.TEAM_RED, 0) == red1 + 1, "%s" % world.team_scores)
	await _wait(ModeYeetball.CELEBRATE + 0.3)
	_check("the kickoff clears the extra balls", mode.balls().size() == 1 and mode.phase == ModeYeetball.Phase.KICKOFF, "%d balls, phase %d" % [mode.balls().size(), mode.phase])
	print("YEETBALL CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _until(ok: Callable, limit: float) -> void:
	var t := 0.0
	while not ok.call() and t < limit:
		await _wait(0.1)
		t += 0.1


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
