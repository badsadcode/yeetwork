extends Node
## Developer check for pickups and power-ups: a first aid kit heals and comes back, full
## health walks past it, each boost does its thing (measured on a bot against itself without
## it), the HUD shows the boosts, dying clears them, and the host's setting turns pickups off.
## Exits 1 if a step fails.
## Usage: godot -- --host --map prime --bots 2 --port 24700 --tour <dir> --tour-mode pickups

var world: Node
var out_dir := ""
var pl: Player
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func():
		print("PICKUP CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	pl = world.local_player
	var bot: Player = null
	for q: Player in world.players.values():
		if q.is_bot:
			q.bot_brain = null
			q.cmd.move = Vector2.ZERO
			q.cmd.jump = false
			# (its brain may have left the grab trigger held: let go, or the gun catches
			# whatever comes in front of it)
			world.gun_action(q, GravityGun.Action.GRAB_END)
			q.gun.release(false)
			bot = q if bot == null else bot
	# (the bots may have taken one in the first second, before they were stopped: put them back)
	world._server_setup_pickups()
	var pickups: Array = world.arena.pickups
	var health := -1
	var power := -1
	for i in pickups.size():
		if pickups[i].kind == "health" and health < 0:
			health = i
		if pickups[i].kind == "random" and power < 0:
			power = i
	_check("the map's pickups are out", pickups.size() >= 5 and health >= 0 and power >= 0 and pickups.all(func(p): return p.is_available()), "%d pickups" % pickups.size())
	if health < 0 or power < 0:
		get_tree().quit(1)
		return
	# A close look at a first aid kit and a power-up.
	var hk: PickupSpawn = pickups[health]
	var pw: PickupSpawn = pickups[power]
	_look(hk.global_position + Vector3(1.5, 1.2, 1.5), hk.item_position())
	await _wait(0.5)
	_shot("p01_first_aid")
	for k in Pickups.INFO:
		world._pickups[power][1] = k
		world._s_pickups(world._pickup_states())
		_look(pw.global_position + Vector3(1.5, 1.2, 1.5), pw.item_position())
		await _wait(0.5)
		_shot("p02_%s" % k)
	world._pickups[power][1] = "super"
	world._s_pickups(world._pickup_states())
	# Full health walks past a first aid kit; hurt, it heals and the kit goes for a while.
	_place(pl, hk.global_position)
	await _wait(0.4)
	_check("full health leaves the first aid kit", hk.is_available(), "")
	_place(pl, hk.global_position + Vector3(4, 0, 0))
	world.server_damage_player(pl, 55.0, 0, "test", pl.global_position, Vector3.ZERO)
	await _wait(0.2)
	_move(pl, hk.global_position) # (not a respawn: that would heal)
	await _wait(0.4)
	_check("first aid: +50 HP, the kit goes", pl.hp > 94.0 and not hk.is_available(), "hp %.0f, there %s" % [pl.hp, hk.is_available()])
	_move(pl, hk.global_position + Vector3(5, 0, 0)) # (off the pad, or it's taken again at once)
	world._pickups[health][2] = world.now() + 0.3 # (comes back soon, for the check)
	await _wait(0.6)
	_check("the kit comes back", hk.is_available(), "")
	# Taking a power-up from its pad.
	world._pickups[power][1] = "speed"
	world._s_pickups(world._pickup_states())
	_place(bot, pw.global_position)
	await _wait(0.4)
	_check("a power-up gives its boost for a while", bot.has_buff("speed") and absf(bot.buff_left("speed") - Pickups.duration("speed")) < 1.0 and not pw.is_available(), "left %.1f" % bot.buff_left("speed"))
	bot.buffs = {}
	# Speed: the bot runs the same stretch with and without it.
	var start: Vector3 = world.arena.spawn_points[0][0]
	var base_v := await _run(bot, start)
	world._server_take_pickup(bot, "speed", bot.global_position)
	var fast_v := await _run(bot, start)
	_check("SPEED: runs about 40% faster", fast_v > base_v * 1.25, "%.1f m/s -> %.1f m/s" % [base_v, fast_v])
	bot.buffs = {}
	# Feather: jumps higher.
	var base_h := await _jump(bot, start)
	world._server_take_pickup(bot, "feather", bot.global_position)
	var high_h := await _jump(bot, start)
	_check("FEATHER: jumps much higher", high_h > base_h * 1.6, "%.1f m -> %.1f m" % [base_h, high_h])
	bot.buffs = {}
	# Super Yeet: a punt sends a ball flying faster.
	var base_p := await _punt(bot, start)
	world._server_take_pickup(bot, "super", bot.global_position)
	var super_p := await _punt(bot, start)
	_check("SUPER YEET: punts hit harder", super_p > base_p * 1.5, "ball %.1f m/s -> %.1f m/s" % [base_p, super_p])
	bot.buffs = {}
	# Iron Yeet: half damage, barely budges, can't be grabbed.
	world._server_take_pickup(bot, "iron", bot.global_position)
	_place(bot, start)
	await _wait(0.3)
	var hp0 := bot.hp
	world.server_damage_player(bot, 20.0, 0, "test", bot.global_position, Vector3.ZERO)
	var hit := hp0 - bot.hp
	world.server_launch_player(bot, Vector3(0, 6, 20), true, 1.0, 0)
	var shove := 0.0
	for k in 6:
		await get_tree().physics_frame
		shove = maxf(shove, Vector2(bot.velocity.x, bot.velocity.z).length())
	_place(pl, start + Vector3(0, 0, 2.5))
	await _wait(0.2)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), bot.body_center() - pl.eye_position())
	await _wait(0.3)
	var grabbed := pl.gun.held_kind == GravityGun.Kind.PLAYER
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	_check("IRON YEET: half damage, barely budges, can't be grabbed", absf(hit - 10.0) < 0.5 and shove < 6.0 and not grabbed, "took %.0f of 20, pushed %.1f m/s, grabbed %s" % [hit, shove, grabbed])
	# Dying clears the boosts.
	world.server_damage_player(bot, 500.0, 0, "test", bot.global_position, Vector3.ZERO)
	await _wait(0.2)
	_check("dying clears the boosts", bot.buffs.is_empty(), "%s" % bot.buffs)
	# The HUD: every boost on the local player, rows and screen effects.
	for k in Pickups.POWERUPS:
		world._server_take_pickup(pl, k, pl.global_position)
	world.hud.visible = true
	_look(start + Vector3(0, 1.7, 0), start + Vector3(0, 1.4, -10))
	await _wait(1.2)
	_check("the HUD shows the boosts", world.hud._buff_rows.visible and world.hud._buff_fx.visible, "")
	_shot("p03_hud_all")
	for k in Pickups.POWERUPS:
		pl.buffs = {k: world.net_time() + 9.0}
		await _wait(0.9)
		_shot("p04_fx_%s" % k)
	pl.buffs = {}
	# A hurt bot goes and gets first aid.
	var medic: Player = null
	for q: Player in world.players.values():
		if q.is_bot and q.is_alive():
			medic = q
			break
	if medic:
		_move(pl, hk.global_position + Vector3(0, 30, 0)) # (out of the way, not on the kit)
		_place(medic, hk.global_position + Vector3(6, 0, 0))
		await _wait(0.3)
		world.server_damage_player(medic, 60.0, 0, "test", medic.global_position, Vector3.ZERO)
		medic.bot_brain = BotBrain.new(medic, world)
		var healed := false
		for k in 50:
			await _wait(0.2)
			if medic.hp > 80.0:
				healed = true
				break
		medic.bot_brain = null
		_check("a hurt bot goes and gets first aid", healed, "hp %.0f" % medic.hp)
	# The host's setting: no pickups at all.
	Game.pickups = 2
	world._server_setup_pickups()
	await _wait(0.2)
	_check("Pickups: None hides them all", pickups.all(func(p): return not p.is_available() and not p.visible), "")
	Game.pickups = 0
	print("PICKUP CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Top running speed over a stretch.
func _run(q: Player, start: Vector3) -> float:
	_place(q, start)
	q.yaw = 0.0
	await _wait(0.3)
	q.cmd.move = Vector2(0, 1)
	q.cmd.run = true
	var top := 0.0
	for k in 16:
		await _wait(0.1)
		top = maxf(top, Vector2(q.velocity.x, q.velocity.z).length())
	q.cmd.move = Vector2.ZERO
	q.cmd.run = false
	return top


## How high a standing jump goes.
func _jump(q: Player, start: Vector3) -> float:
	_place(q, start)
	await _wait(0.4)
	var y0 := q.global_position.y
	q.cmd.jump = true
	q.cmd.jump_pressed = true
	var top := 0.0
	for k in 25:
		await _wait(0.05)
		q.cmd.jump_pressed = false
		top = maxf(top, q.global_position.y - y0)
	q.cmd.jump = false
	await _wait(1.0)
	return top


## How fast a ball leaves a punt.
func _punt(q: Player, start: Vector3) -> float:
	_place(q, start)
	q.yaw = 0.0
	q.pitch = 0.0
	await _wait(0.3)
	var at := q.eye_position() + Vector3(0, -0.3, -2.0)
	var ball: Prop = world.server_spawn_prop("ball", Transform3D(Basis.IDENTITY, at))
	for k in 4: # (physics frames, not seconds: the ball must be in the physics world)
		await get_tree().physics_frame
	q.gun._punt_cd = 0.0
	world.gun_action(q, GravityGun.Action.THROW)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var v := ball.linear_velocity.length() if is_instance_valid(ball) else 0.0
	if is_instance_valid(ball):
		world.server_despawn_prop(ball)
	await _wait(0.3)
	return v


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _place(q: Player, pos: Vector3) -> void:
	q.respawn(pos + Vector3.UP * 0.1, q.yaw)
	q.cmd.move = Vector2.ZERO


func _move(q: Player, pos: Vector3) -> void:
	q.global_position = pos + Vector3.UP * 0.1
	q.velocity = Vector3.ZERO


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var to := target - eye
	_place(pl, eye - Vector3(0, Player.EYE_STAND, 0))
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
