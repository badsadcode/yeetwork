extends Node
## Developer check for YeetVolley: the serve, a ball landing in a half, out (and whose fault),
## four touches, the gun reaching the ball only on your side, staying on your side of the net,
## a ball in the sea, the net rising in TOTAL YEET, bots rallying, full time at 15.
## Exits 1 if a step fails.
## Usage: godot -- --host --map volley_beach --mode volley --bots 3 --port 24700 --tour <dir> --tour-mode volley

var world: Node
var out_dir := ""
var pl: Player
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func():
		print("VOLLEY CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(0.6)
	pl = world.local_player
	Game.bot_skill = 1 # normal bots, whatever the saved setting (not saved)
	var brains := {}
	for q: Player in world.players.values():
		if q.is_bot and q.bot_brain:
			brains[q] = q.bot_brain
			_idle(q)
	var mode := world.mode_logic as ModeVolley
	mode.rules = ModeYeetball.Rules.CLASSIC # (whatever the saved setting)
	var n := mode.net() if mode else null
	_check("YeetVolley with a net and a volleyball", n != null and mode.ball() and mode.ball().kind == "volleyball", "")
	var b := mode.ball()
	var serve_side := n.side_of(b.global_position)
	_check("the serve floats over the serving team's half", mode.phase == ModeYeetball.Phase.KICKOFF and b.freeze and serve_side == mode._serve_team, "side %d, serving %d" % [serve_side, mode._serve_team])
	_look(n.global_transform * Vector3(9, 4.5, 0), n.global_position + Vector3.UP * 1.5)
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 6.0)
	_shot("v01_court")
	var red := _player_of(Game.TEAM_RED)
	var blue := _player_of(Game.TEAM_BLUE)
	# Landing in Red's half: a point for Blue, who serve next.
	var b0: int = world.team_scores.get(Game.TEAM_BLUE, 0)
	await _drop(b, n.global_transform * Vector3(2, 3, -5), blue)
	_check("down in Red's half: a point for Blue, Blue serve", world.team_scores.get(Game.TEAM_BLUE, 0) == b0 + 1 and mode._serve_team == Game.TEAM_BLUE, "blue %d, serving %d" % [world.team_scores.get(Game.TEAM_BLUE, 0), mode._serve_team])
	await _next(mode)
	# Out, off a Red touch: a point for Blue.
	b0 = world.team_scores.get(Game.TEAM_BLUE, 0)
	await _drop(b, n.global_transform * Vector3(n.court.x * 0.5 + 2.0, 3, 4), red)
	_check("out after Red touched it: a point for Blue", world.team_scores.get(Game.TEAM_BLUE, 0) == b0 + 1, "blue %d" % world.team_scores.get(Game.TEAM_BLUE, 0))
	await _next(mode)
	# Four touches on Red's side: a fault, a point for Blue.
	b0 = world.team_scores.get(Game.TEAM_BLUE, 0)
	b.global_position = n.global_transform * Vector3(0, 4, -4)
	b.linear_velocity = Vector3.ZERO
	for k in 4:
		b.last_thrower = red.player_id
		b.last_thrown_time = world.now() + k * 0.01
		b.global_position = n.global_transform * Vector3(0, 4, -4)
		b.linear_velocity = Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
	await _wait(0.2)
	_check("four touches on one side: a fault", world.team_scores.get(Game.TEAM_BLUE, 0) == b0 + 1 and mode._fault == "touches", "blue %d, fault %s" % [world.team_scores.get(Game.TEAM_BLUE, 0), mode._fault])
	await _next(mode)
	# The gun reaches the ball on your own side only.
	b.global_position = n.global_transform * Vector3(0, 1.5, 3.0)
	b.linear_velocity = Vector3.ZERO
	await get_tree().physics_frame
	var red_on_blue := mode.allow_grab(red, b)
	var blue_on_blue := mode.allow_grab(blue, b)
	_check("Classic: the gun only reaches the ball on your side", not red_on_blue and blue_on_blue, "red %s, blue %s" % [red_on_blue, blue_on_blue])
	# Over the net, you're bounced back.
	red.respawn(n.global_transform * Vector3(-3, 0, 3.0), 0.0)
	var back := false
	for k in 20:
		await _wait(0.1)
		if n.side_of(red.global_position) == Game.TEAM_RED:
			back = true
			break
	_check("over the net: put back on your side", back, "at %s" % red.global_position.snapped(Vector3.ONE * 0.1))
	# Into the sea: out (Blue touched it last: a point for Red).
	await _next(mode)
	var r0: int = world.team_scores.get(Game.TEAM_RED, 0)
	b.last_thrower = blue.player_id
	b.last_thrown_time = world.now()
	b.global_position = Vector3(0, -30, 0)
	await _wait(0.4)
	_check("into the sea: out, against whoever touched it last", world.team_scores.get(Game.TEAM_RED, 0) == r0 + 1, "red %d" % world.team_scores.get(Game.TEAM_RED, 0))
	# TOTAL YEET: the net climbs with each point.
	await _next(mode)
	mode.rules = ModeYeetball.Rules.TOTAL
	var h0 := n.top()
	await _drop(b, n.global_transform * Vector3(-2, 3, 5), red)
	await _wait(0.2)
	_check("TOTAL YEET: the net rises with each point", n.top() > h0 + 0.1, "%.2f -> %.2f" % [h0, n.top()])
	mode.rules = ModeYeetball.Rules.CLASSIC
	await _next(mode)
	# The bots rally: the ball goes back and forth over the net.
	for q in brains:
		q.bot_brain = brains[q]
	var crossings := 0
	var last_side := n.side_of(b.global_position)
	var s0: int = world.team_scores.get(1, 0) + world.team_scores.get(2, 0)
	for k in 400:
		await _wait(0.1)
		var bb := mode.ball()
		var side := n.side_of(bb.global_position) if bb else 0
		if side != 0 and side != last_side and bb.global_position.y > 1.0:
			crossings += 1
		if side != 0:
			last_side = side
		if crossings >= 4 and k > 100:
			break
	var points: int = world.team_scores.get(1, 0) + world.team_scores.get(2, 0) - s0
	_check("bots rally: back and forth over the net, points won", crossings >= 3 and points > 0, "%d crossings, %d points" % [crossings, points])
	_look(n.global_transform * Vector3(11, 6, -2), n.global_position + Vector3.UP * 1.5)
	await _wait(0.3)
	_shot("v02_rally")
	for q in brains:
		_idle(q)
	# 15 wins: the full-time screen.
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 10.0)
	world.team_scores[Game.TEAM_RED] = ModeVolley.POINTS_TO_WIN - 1
	await _drop(mode.ball(), n.global_transform * Vector3(0, 3, 5), red)
	var res: Dictionary = world.mode_state.get("results", {})
	_check("15 wins: full time, in points", mode.phase == ModeYeetball.Phase.FULL_TIME and res.get("unit", "") == "point" and res.get("red", 0) >= 15, "%s" % res)
	_look(n.global_transform * Vector3(0, 3, -8), n.global_position + Vector3.UP * 2.0)
	await _wait(0.6)
	_shot("v03_results")
	print("VOLLEY CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Drops the ball at `at` (as if `who` touched it last) and waits for it to land.
func _drop(b: Prop, at: Vector3, who: Player) -> void:
	b.global_position = at
	b.linear_velocity = Vector3(0, -3, 0)
	b.last_thrower = who.player_id
	b.last_thrown_time = world.now()
	for k in 180:
		await get_tree().physics_frame
		if (world.mode_logic as ModeYeetball).phase != ModeYeetball.Phase.PLAY:
			break


func _next(mode: ModeVolley) -> void:
	await _until(func() -> bool: return mode.phase == ModeYeetball.Phase.PLAY, 10.0)
	await _wait(0.2)


func _idle(q: Player) -> void:
	q.bot_brain = null
	q.cmd.move = Vector2.ZERO
	world.gun_action(q, GravityGun.Action.GRAB_END)
	q.gun.release(false)


func _player_of(team: int) -> Player:
	for q: Player in world.players.values():
		if q.team == team:
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
