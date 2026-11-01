extends Node
## Developer check for High Seas' routes (phase 2): overboard, a Yeet swims to a hull ladder
## and climbs back aboard; a bot does it by itself; a ladder up through the wing's hatch into
## the bridge; the ship's horn; a bridge window breaks; a ladder up onto a lashing bridge;
## the engine room (down a hatch, dry below the waterline, its machines running, the
## switchboard's zap, up the ladder and out; a bot down there climbs out by itself).
## Screenshots of the bridge, a hull ladder, the lashing bridges and the engine room.
## Exits 1 if a step fails.
## Usage: godot -- --host --map highseas --bots 1 --port 24700 --tour <dir> --tour-mode shiproutes

var world: Node
var out_dir := ""
var _failed := 0
var ship: Ship
var pl: Player


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func():
		print("SHIP ROUTES CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	ship = world.arena.carrier
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	var bot: Player = null
	var brain = null
	for q: Player in world.players.values():
		if q != pl and q.is_bot:
			bot = q
	for p: Prop in world.props.values(): # (no blasts going off mid-check)
		if is_instance_valid(p) and p.explosive:
			world.server_despawn_prop(p)
	var deck := MapHighSeas.DECK
	# 1. Overboard: swim to the ladder at x -10 (starboard) and climb it.
	_put(pl, Vector3(-10, 0.2, 16.9), Vector3(0, 0, -1))
	await _wait(0.5)
	await _shot("r01_overboard")
	var back := await _climb(pl, Vector3(0, 0, -1), 14.0, func(l: Vector3): return absf(l.y - deck) < 0.7 and absf(l.z) < 15.6)
	_check("overboard: swim to a hull ladder, climb back aboard", back, "at %s" % _local(pl))
	# 2. A bot overboard finds a ladder by itself.
	if bot:
		bot.respawn(ship.global_transform * Vector3(25, 0.2, 24), 0.0)
		var aboard := false
		for k in 350: # (every 0.1 s: once aboard, its own wandering may take it over the rail again)
			await _wait(0.1)
			var l := _local(bot)
			if OS.get_cmdline_user_args().has("--trace") and k % 10 == 0:
				var lad: Node3D = bot.bot_brain._ladder if bot.bot_brain else null
				print("TRACE bot %s v %s ladder %s move %s" % [l, bot.velocity, (ship.global_transform.affine_inverse() * lad.global_position) if lad else null, bot.cmd.move])
			if l.y > deck - 0.5 and absf(l.z) < 15.6 and bot.is_alive():
				aboard = true
				break
		_check("a bot overboard swims to a ladder and climbs aboard", aboard, "bot at %s" % _local(bot))
		brain = bot.bot_brain
		bot.bot_brain = null
		bot.respawn(ship.global_transform * Vector3(30, deck + 0.2, -14), 0.0)
	# 3. Up the ladder through the starboard wing's hatch into the bridge.
	_put(pl, Vector3(-55.3, deck + 0.2, 14.6), Vector3(0, 0, 1))
	await _wait(0.4)
	await _shot("r02_hatch_ladder")
	var inside := await _climb(pl, Vector3(0, 0, 1), 10.0, func(l: Vector3): return absf(l.y - (deck + 18.0)) < 0.8 and l.x > -60.0 and l.x < -50.0)
	_check("up the ladder through the hatch, into the bridge", inside, "at %s" % _local(pl))
	# Inside the bridge, looking forward through the windows.
	_put(pl, Vector3(-58.5, deck + 18.2, -3), Vector3(1, 0, 0.15))
	await _wait(0.6)
	await _shot("r03_bridge")
	# 4. The horn.
	var horn: Horn = null
	for n in world.arena.puzzle:
		if n is Horn:
			horn = n
	_put(pl, Vector3(-52.6, deck + 18.2, 2.0), Vector3(1, 0, 0))
	await _wait(0.3)
	var usable = world.usable_for(pl)
	if horn and OS.get_cmdline_user_args().has("--trace"):
		print("TRACE horn point %s eye %s d %.2f" % [ship.global_transform.affine_inverse() * horn.use_point(), _local(pl) + Vector3(0, 1.6, 0), horn.use_point().distance_to(pl.eye_position())])
	world.use_pressed(pl)
	await _wait(0.2)
	_check("the ship's horn: in reach on the console, sounds", horn != null and usable == horn and horn._next > world.now(), "usable %s" % [usable])
	# 5. A window breaks.
	var pane: Destructible = world.arena.destructibles[0]
	world.server_damage_destructible(pane, pane.global_position, 1.5, 200.0, pane.global_transform.basis.z * 5.0, 0, 1.0)
	await _wait(0.5)
	_check("a bridge window breaks", pane.broken_cells.size() > 0, "%d cells broken" % pane.broken_cells.size())
	_put(pl, Vector3(-58.5, deck + 18.2, -3), Vector3(1, 0, 0.15))
	await _wait(0.5)
	await _shot("r04_window_broken")
	# 6. Up a ladder onto a lashing bridge (between bays 1 and 2, port side).
	var gx := (-20.7 + -5.5) * 0.5
	_put(pl, Vector3(gx, deck + 0.2, -13.6), Vector3(0, 0, 1))
	await _wait(0.4)
	var up := await _climb(pl, Vector3(0, 0, 1), 8.0, func(l: Vector3): return absf(l.y - (deck + MapHighSeas.CONT.y * 2.0)) < 0.7 and absf(l.z) < 12.7)
	_check("up a ladder onto a lashing bridge", up, "at %s" % _local(pl))
	_put(pl, Vector3(gx - 8.0, deck + 9.0, -15.0), Vector3(1, -0.5, 1.2))
	await _wait(0.5)
	await _shot("r05_lashing_bridges")
	_put(pl, Vector3(-12, deck + 4.0, 24), Vector3(0.2, -0.35, -1))
	await _wait(0.5)
	await _shot("r06_hull_ladders")
	# 7. The engine room.
	var f := MapHighSeas.ROOM_FLOOR
	var machines: Array = world.arena.puzzle.filter(func(n): return n is Fixture)
	_check("the engine room's machines are running", machines.size() >= 10 and machines.all(func(m): return m._level > 0.9 and (m._audio.stream == null or m._audio.playing)), "%d fixtures" % machines.size())
	# Into the starboard hatch: you catch the ladder; hold back to climb down.
	_put(pl, Vector3(-44.8, deck + 0.6, 6.5), Vector3(1, 0, 0))
	await _wait(0.5)
	var down := false
	for k in 60:
		pl.cmd.move = Vector2(0, -1)
		await _wait(0.1)
		if ship.in_hold(pl.global_position) and pl.is_on_floor() and absf(_local(pl).y - f) < 0.5:
			down = true
			break
	pl.cmd.move = Vector2.ZERO
	_check("down a hatch and its ladder into the engine room", down, "at %s" % _local(pl))
	# (points under the swell: beside her, and inside the room's walls)
	var ocean: Liquid = ship.ocean
	var beside := ship.global_transform * Vector3(-54, 1.2, 20)
	beside.y = ocean.height_at(beside.x, beside.z) - 0.5
	var in_room := ship.global_transform * Vector3(-54, 1.2, 4)
	var sea_beside: Liquid = Liquid.at(beside, 30.0)
	var sea_inside: Liquid = Liquid.at(in_room, 30.0)
	_check("... dry below the waterline (the sea's beside her, not in there)", sea_beside != null and sea_inside == null, "beside %s, inside %s" % [sea_beside != null, sea_inside != null])
	_put(pl, Vector3(-45.2, f + 0.2, -4.0), Vector3(-1, -0.12, 0.25))
	await _wait(0.6)
	await _shot("r07_engine_room")
	_put(pl, Vector3(-56.5, f + 0.2, 3.2), Vector3(-1, -0.1, -0.45))
	await _wait(0.5)
	await _shot("r08_engine_room_aft")
	_put(pl, Vector3(-49.5, deck + 0.2, -1.0), Vector3(1, -0.3, 0.6))
	await _wait(0.5)
	await _shot("r09_hatches")
	var hp := pl.hp
	_put(pl, Vector3(-62.4, f + 0.2, 0.3), Vector3(-1, 0, 0))
	var zapped := false
	for k in 30:
		await _wait(0.05)
		if pl.hp < hp or pl.velocity.length() > 3.0:
			zapped = true
			break
	_check("lean on the switchboard: zap", zapped, "hp %.0f -> %.0f" % [hp, pl.hp])
	pl.hp = 100.0
	_put(pl, Vector3(-44.6, f + 0.2, 6.5), Vector3(1, 0, 0))
	await _wait(0.3)
	var out := await _climb(pl, Vector3(1, 0, 0), 10.0, func(l: Vector3): return absf(l.y - deck) < 0.7 and l.x > -48.0)
	_check("up the ladder and out of the hatch", out and not ship.in_hold(pl.global_position), "at %s" % _local(pl))
	if bot and brain:
		bot.bot_brain = brain
		bot.respawn(ship.global_transform * Vector3(-52.0, f + 0.2, 5.0), 0.0)
		var climbed := false
		for k in 300:
			await _wait(0.1)
			var l := _local(bot)
			if OS.get_cmdline_user_args().has("--trace") and k % 10 == 0:
				print("TRACE hold bot %s v %s move %s" % [l, bot.velocity, bot.cmd.move])
			if l.y > deck - 0.5 and not ship.in_hold(bot.global_position) and bot.is_alive():
				climbed = true
				break
		_check("a bot down there climbs out by itself", climbed, "bot at %s" % _local(bot))
	print("SHIP ROUTES CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Holds forward (facing `face`, ship-local: it climbs a ladder, swims) until `arrived` says so
## and it's standing (or time's up). (Not jump: a bot-flagged player bunny-hops while it's held.)
func _climb(q: Player, face: Vector3, seconds: float, arrived: Callable) -> bool:
	for k in int(seconds * 10.0):
		_face(q, face)
		q.cmd.move = Vector2(0, 1)
		await _wait(0.1)
		if OS.get_cmdline_user_args().has("--trace"):
			print("TRACE %s v %s floor %s" % [_local(q), q.velocity, q.is_on_floor()])
		if arrived.call(_local(q)) and q.is_on_floor():
			q.cmd.move = Vector2.ZERO
			q.cmd.jump = false
			await _wait(0.3)
			return true
	q.cmd.move = Vector2.ZERO
	q.cmd.jump = false
	return false


## Puts a player at a ship-local spot, looking along a ship-local direction.
func _put(q: Player, local: Vector3, face: Vector3) -> void:
	q.respawn(ship.global_transform * local, 0.0)
	q.cmd.move = Vector2.ZERO
	_face(q, face)


func _face(q: Player, face: Vector3) -> void:
	var d := ship.global_transform.basis * face.normalized()
	q.yaw = atan2(-d.x, -d.z)
	q.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _local(q: Player) -> Vector3:
	return ship.global_transform.affine_inverse() * q.global_position


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	world.hud.visible = false
	if pl.gun:
		pl.gun.set_viewmodel_visible(false)
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
