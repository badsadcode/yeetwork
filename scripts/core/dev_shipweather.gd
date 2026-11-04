extends Node
## Developer check for High Seas' weather (phase 2). On the Hurricane: she rolls harder than
## in a storm, and green water comes over the low side by itself now and then. On a calm sea
## (Golden Hour: on a deck heeling 17 degrees how far things go says more about the roll at
## that moment than about the wave): a wash shoves a Yeet and a crate across the deck; a rogue
## wave (warning, horn, a wall of water) makes her lurch and knocks Yeets down; a wet deck is
## slippery (a Yeet slides further stopping). Screenshots. Exits 1 if a step fails.
## Usage: godot -- --host --map highseas_extreme --bots 1 --port 24700 --tour <dir> --tour-mode shipweather
##        godot -- --host --map highseas_dusk --bots 1 --port 24700 --tour <dir> --tour-mode shipweather

var world: Node
var out_dir := ""
var _failed := 0
var ship: Ship
var pl: Player


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func():
		print("SHIP WEATHER CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	ship = world.arena.carrier
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	for q: Player in world.players.values():
		if q != pl:
			q.bot_brain = null
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.explosive:
			world.server_despawn_prop(p)
	if ship.sea == "extreme":
		await _hurricane()
	else:
		await _events()
	print("SHIP WEATHER CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## The hurricane: rolls harder, and washes over the deck by itself.
func _hurricane() -> void:
	var deck := MapHighSeas.DECK
	_put(Vector3(-46.0, deck + 6.2, -4.0), Vector3(1, -0.2, 0))
	var max_roll := 0.0
	var washes := 0
	var seen := {}
	for k in 300:
		await get_tree().physics_frame
		max_roll = maxf(max_roll, absf(ship.global_transform.basis.get_euler().x))
		for c in ship.get_children():
			if c is ShipWash and not seen.has(c):
				seen[c] = true
				washes += 1
	for k in 25:
		await _wait(0.5)
		max_roll = maxf(max_roll, absf(ship.global_transform.basis.get_euler().x))
		for c in ship.get_children():
			if c is ShipWash and not seen.has(c):
				seen[c] = true
				washes += 1
	_check("a hurricane: she rolls hard, and green water comes over by itself", rad_to_deg(max_roll) > 14.0 and washes >= 1, "roll %.1f deg, %d washes in 17 s" % [rad_to_deg(max_roll), washes])
	await _wait(0.1)
	await _shot("w00_hurricane", Vector3(-58.0, MapHighSeas.DECK + 30.0, -20.0), Vector3(15.0, 0.0, 10.0))


## Green water, a rogue wave and a wet deck, each placed by the check (a calm sea).
func _events() -> void:
	var deck := MapHighSeas.DECK
	# (the other Yeet out of the way: Blue spawns right on the open deck these runs cross)
	for q: Player in world.players.values():
		if q != pl:
			q.bot_brain = null
			q.respawn(ship.global_transform * Vector3(30.0, deck + 0.2, -14.0), 0.0)
	# A wet deck (as after green water): less grip slowing a Yeet that stops (first: a fresh
	# Yeet). Measured headless only: in a window the bot's contact with the moving deck isn't
	# measured reliably (it reads airborne through a dry run), whatever the grip.
	if DisplayServer.get_name() == "headless":
		# (a moving Yeet on a moving deck: one slide can read high on a slow machine, so the best
		# of three wet ones against the best of the dry)
		var was_wet := false
		var wet_slide := INF
		var dry_slide := 0.0
		for k in 3:
			ship.wet_until = Liquid.wave_time() + 30.0
			was_wet = ship.wet()
			wet_slide = minf(wet_slide, await _slide())
			ship.wet_until = -1000.0
			dry_slide = maxf(dry_slide, await _slide())
			if was_wet and wet_slide < dry_slide * 0.7:
				break
		_check("a wet deck is slippery: less grip slowing a Yeet that stops running", was_wet and wet_slide < dry_slide * 0.7, "loses %.2f m/s a step on the deck wet, %.2f dry" % [wet_slide, dry_slide])
	else:
		print("SKIP  a wet deck is slippery (measured headless)")
	# A wash shoves a Yeet and a crate across the deck (toward port), on the open deck in
	# front of the bridge (on the walkways it slams you into the stacks).
	_put(Vector3(-46.0, deck + 0.2, 12.0), Vector3(0, 0, -1))
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, ship.global_transform * Vector3(-43.5, deck + 0.7, 11.5)))
	await _wait(0.6)
	var z0 := _local(pl).z
	var c0 := (ship.global_transform.affine_inverse() * crate.global_position).z
	world.server_wash(1.0, -45.0, 8.0, 1.0)
	await _wait(0.25)
	await _shot("w01_wash", Vector3(-44.0, deck + 11.0, -15.0), Vector3(-46.0, deck, 7.0))
	await _wait(1.3)
	var cz := (ship.global_transform.affine_inverse() * crate.global_position).z if is_instance_valid(crate) else c0
	_check("a wash shoves a Yeet and a crate across the deck", z0 - _local(pl).z > 2.0 and c0 - cz > 1.5, "Yeet %.1f m, crate %.1f m" % [z0 - _local(pl).z, c0 - cz])
	# 3. A rogue wave: a warning, a wall of water, a lurch, Yeets knocked down.
	_put(Vector3(0.0, deck + 0.2, 0.0), Vector3(0, 0, 1))
	await _wait(0.5)
	var bot: Player = null
	for q: Player in world.players.values():
		if q != pl:
			bot = q
	if bot:
		bot.bot_brain = null # (again: a respawn may have given it one back)
		bot.cmd.move = Vector2.ZERO
		bot.respawn(ship.global_transform * Vector3(-44.0, deck + 0.2, 6.0), 0.0)
	world.server_rogue(1.0)
	await _wait(0.4)
	var warned: bool = world.hud._big_label.visible and world.hud._big_label.text.begins_with("ROGUE")
	await _wait(2.6)
	await _shot("w02_rogue_coming", Vector3(-58.0, deck + 30.0, -6.0), Vector3(-5.0, 3.0, 65.0))
	var roll_before := absf(ship.global_transform.basis.get_euler().x)
	var lurch := 0.0
	var knocked := false
	for k in 50:
		await _wait(0.1)
		lurch = maxf(lurch, absf(ship.global_transform.basis.get_euler().x))
		if bot and (bot.state == Player.State.RAGDOLL or not bot.is_alive()):
			knocked = true
		if k == 18:
			await _shot("w03_rogue_hits", Vector3(-58.0, deck + 30.0, -6.0), Vector3(-15.0, deck, 12.0))
	_check("a rogue wave: warned, she lurches, a Yeet on deck is knocked down", warned and lurch > deg_to_rad(6.0) and knocked, "warned %s, lurch %.1f deg (was %.1f), knocked %s" % [warned, rad_to_deg(lurch), rad_to_deg(roll_before), knocked])


## Runs across the open deck in front of the bridge, lets go, and reports how much speed it
## loses per physics step while it's on the deck (that's where grip acts: running Yeets leave
## the ground now and then, more or less depending on how the steps fall).
func _slide() -> float:
	# (the other Yeet does the running: a bot reads no input, whatever the window is doing)
	var q: Player = pl
	for o: Player in world.players.values():
		if o != pl:
			q = o
	q.bot_brain = null
	q.cmd.jump = false # (stopping its brain doesn't let go of what it was holding: held jump hops)
	q.cmd.jump_pressed = false
	q.cmd.crouch = false
	q.respawn(ship.global_transform * Vector3(-46.0, MapHighSeas.DECK + 0.2, -12.0), 0.0)
	var d := ship.global_transform.basis * Vector3(0, 0, 1)
	q.yaw = atan2(-d.x, -d.z)
	await _wait(0.4)
	q.cmd.move = Vector2(0, 1)
	q.cmd.run = true
	await _wait(1.2)
	q.cmd.move = Vector2.ZERO
	q.cmd.run = false
	var lost := 0.0
	var steps := 0
	var prev := q.horizontal_speed()
	for k in 20:
		await get_tree().physics_frame
		var v := q.horizontal_speed()
		if q.is_on_floor() and v > 0.5:
			lost += prev - v
			steps += 1
		prev = v
	q.respawn(ship.global_transform * Vector3(30.0, MapHighSeas.DECK + 0.2, -14.0), 0.0)
	return lost / maxf(steps, 1)


func _put(local: Vector3, face: Vector3) -> void:
	pl.respawn(ship.global_transform * local, 0.0)
	pl.cmd.move = Vector2.ZERO
	var d := ship.global_transform.basis * face.normalized()
	pl.yaw = atan2(-d.x, -d.z)
	pl.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _local(q: Player) -> Vector3:
	return ship.global_transform.affine_inverse() * q.global_position


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## A screenshot; with `eye` and `at` (ship-local) from a camera of its own (the Yeets stay put).
func _shot(n: String, eye := Vector3.INF, at := Vector3.ZERO) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	world.hud.visible = false
	if pl.gun:
		pl.gun.set_viewmodel_visible(false)
	var cam: Camera3D = null
	if eye != Vector3.INF:
		cam = Camera3D.new()
		world.add_child(cam)
		cam.global_position = ship.global_transform * eye
		cam.look_at(ship.global_transform * at)
		cam.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
	if cam:
		cam.queue_free()
	world.hud.visible = true
