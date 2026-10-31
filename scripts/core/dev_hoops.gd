extends Node
## Developer check for YeetHoops: the tip-off, a ball dropped through the rim is 2, one from
## beyond the arc is 3, one going up through the rim isn't a basket, a dunk counts, bank
## shots off the board, bots that grab the ball and shoot (and score), and the full-time
## screen at 21. Exits 1 if a step fails.
## Usage: godot -- --host --map hoops_court --mode hoops --bots 3 --port 24700 --tour <dir> --tour-mode hoops

var world: Node
var out_dir := ""
var pl: Player
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func():
		print("HOOPS CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(0.6)
	pl = world.local_player
	Game.bot_skill = 1 # normal bots, whatever the saved setting (not saved)
	var brains := {}
	for q: Player in world.players.values():
		if q.is_bot and q.bot_brain:
			brains[q] = q.bot_brain
			q.bot_brain = null
			q.cmd.move = Vector2.ZERO
			world.gun_action(q, GravityGun.Action.GRAB_END)
			q.gun.release(false)
	var mode := world.mode_logic as ModeHoops
	_check("YeetHoops with two hoops and a basketball", mode != null and mode.goal_of(1) is Hoop and mode.goal_of(2) is Hoop and mode.ball() and mode.ball().kind == "basketball", "")
	var b := mode.ball()
	var blue: Hoop = mode.goal_of(Game.TEAM_BLUE)
	var red: Hoop = mode.goal_of(Game.TEAM_RED)
	_look(red.mouth() + red.global_transform.basis.z * 6.0 + Vector3(2.5, -1.2, 3.0), red.mouth() - Vector3(0, 1.2, 0))
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 6.0)
	_shot("h01_court")
	_check("tip-off: the ball goes up after the countdown", mode.phase == ModeYeetball.Phase.PLAY and not b.freeze, "phase %d" % mode.phase)
	# Dropped through the rim (thrown from close by): 2 points for Red, who attack the blue hoop.
	var thrower := pl if pl.team == Game.TEAM_RED else _bot_of(Game.TEAM_RED)
	var r0: int = world.team_scores.get(Game.TEAM_RED, 0)
	await _drop_in(b, blue, thrower, blue.mouth() + blue.global_transform.basis.z * 3.0)
	_check("dropped through the rim: 2 points", world.team_scores.get(Game.TEAM_RED, 0) == r0 + 2, "red %d" % world.team_scores.get(Game.TEAM_RED, 0))
	await _next_play(mode)
	# From beyond the arc: 3.
	r0 = world.team_scores.get(Game.TEAM_RED, 0)
	await _drop_in(b, blue, thrower, blue.mouth() + blue.global_transform.basis.z * (blue.three_range + 2.0))
	_check("from beyond the arc: 3 points", world.team_scores.get(Game.TEAM_RED, 0) == r0 + 3, "red %d" % world.team_scores.get(Game.TEAM_RED, 0))
	await _next_play(mode)
	# Up through the rim from below isn't a basket.
	r0 = world.team_scores.get(Game.TEAM_RED, 0)
	b.global_position = blue.mouth() - Vector3(0, 1.2, 0)
	b.linear_velocity = Vector3(0, 9, 0)
	b.last_thrower = thrower.player_id
	await _wait(0.5)
	_check("up through the rim from below: no basket", world.team_scores.get(Game.TEAM_RED, 0) == r0 and mode.phase == ModeYeetball.Phase.PLAY, "red %d, phase %d" % [world.team_scores.get(Game.TEAM_RED, 0), mode.phase])
	# Off the backboard: a ball thrown at the board drops off it (the board is solid).
	b.global_position = blue.mouth() + blue.global_transform.basis.z * 2.5 + Vector3(0, 0.6, 0)
	b.linear_velocity = -blue.global_transform.basis.z * 9.0
	await _wait(0.35)
	var bounced := b.linear_velocity.dot(blue.global_transform.basis.z) > 0.5
	_check("the backboard is solid: the ball bounces off it", bounced, "v %s" % b.linear_velocity.snapped(Vector3.ONE * 0.1))
	await _wait(1.0)
	await _next_play(mode)
	# A dunk: carried down through the rim on the gun.
	r0 = world.team_scores.get(Game.TEAM_RED, 0)
	var holder := _bot_of(Game.TEAM_RED)
	b.global_position = holder.eye_position() + Vector3(0, 0, -1)
	await get_tree().physics_frame
	b.held_by = holder.player_id
	b.last_thrower = holder.player_id
	var before := blue.mouth() + Vector3(0, 0.6, 0)
	b.global_position = before
	await get_tree().physics_frame
	b.global_position = blue.mouth() - Vector3(0, 0.4, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	b.held_by = 0
	_check("a dunk counts (2)", world.team_scores.get(Game.TEAM_RED, 0) == r0 + 2, "red %d" % world.team_scores.get(Game.TEAM_RED, 0))
	await _next_play(mode)
	# The bots play: they grab the ball and shoot at the hoops.
	for q in brains:
		q.bot_brain = brains[q]
	var shots := 0
	var up := false
	for k in 250:
		await _wait(0.1)
		var bb := mode.ball()
		if bb and bb.held_by == 0 and bb.linear_velocity.y > 6.0 and bb.global_position.y > 2.5:
			up = true
		elif up and bb and bb.linear_velocity.y < -1.0:
			shots += 1
			up = false
	_check("bots grab the ball and shoot", shots >= 2, "%d lobs in 25 s" % shots)
	_look(Vector3(0, 9, -12), Vector3(0, 1, 0))
	await _wait(0.3)
	_shot("h02_bots")
	# A bot alone on the court scores (its aim, without anyone in the way).
	var lone: Player = null
	for q in brains:
		if lone == null:
			lone = q
			continue
		q.bot_brain = null
		q.cmd.move = Vector2.ZERO
		world.gun_action(q, GravityGun.Action.GRAB_END)
		q.gun.release(false)
		q.respawn(Vector3(0, 0, -12.5 if q.team == 1 else 12.5) + Vector3(q.player_id % 5, 0, 0), 0.0)
	_move_away(pl)
	var lone_team := lone.team
	var s0: int = world.team_scores.get(lone_team, 0)
	var t := 0.0
	var ly := 0.0
	var tg: Hoop = blue if lone_team == Game.TEAM_RED else red
	while t < 40.0 and world.team_scores.get(lone_team, 0) == s0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var bb := mode.ball()
		var m: Vector3 = tg.mouth()
		if bb:
			ly = bb.global_position.y
	_check("a bot alone scores", world.team_scores.get(lone_team, 0) > s0, "%d points in %.0f s" % [world.team_scores.get(lone_team, 0) - s0, t])
	for q in brains:
		q.bot_brain = null
		q.cmd.move = Vector2.ZERO
		world.gun_action(q, GravityGun.Action.GRAB_END)
		q.gun.release(false)
	# 21 wins: the full-time screen.
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 10.0)
	world.team_scores[Game.TEAM_RED] = ModeHoops.POINTS_TO_WIN - 2
	await _drop_in(mode.ball(), blue, thrower, blue.mouth() + blue.global_transform.basis.z * 3.0)
	var res: Dictionary = world.mode_state.get("results", {})
	_check("21 wins: full time, in points", mode.phase == ModeYeetball.Phase.FULL_TIME and res.get("unit", "") == "point" and res.get("red", 0) >= 21, "%s" % res)
	_look(Vector3(0, 3, 6), Vector3(0, 2, 0))
	await _wait(0.6)
	_shot("h03_results")
	print("HOOPS CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Drops the ball into a hoop from above (as if lobbed from `from`, by `who`).
func _drop_in(b: Prop, h: Hoop, who: Player, from: Vector3) -> void:
	b.global_position = from
	b.last_thrower = who.player_id
	b.last_thrown_time = world.now()
	await get_tree().physics_frame
	await get_tree().physics_frame
	b.global_position = h.mouth() + Vector3(0, 1.4, 0)
	b.linear_velocity = Vector3(0, -2, 0)
	b.angular_velocity = Vector3.ZERO
	for k in 40:
		await get_tree().physics_frame
		if (world.mode_logic as ModeYeetball).phase != ModeYeetball.Phase.PLAY:
			break


func _next_play(mode: ModeHoops) -> void:
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 10.0)
	await _wait(0.3)


## Out of the way, up on the side wall's top (the camera player).
func _move_away(q: Player) -> void:
	q.respawn(Vector3(0, 0, -12.8), 0.0)


func _bot_of(team: int) -> Player:
	for q: Player in world.players.values():
		if q.is_bot and q.team == team:
			return q
	return pl


func _until(ok: Callable, limit: float) -> void:
	var t := 0.0
	while not ok.call() and t < limit:
		await _wait(0.1)
		t += 0.1


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var to := target - eye
	pl.respawn(eye - Vector3(0, Player.EYE_STAND, 0), 0.0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
