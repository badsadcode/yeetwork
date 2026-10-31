extends Node
## Developer check for MegaYeet (on the Fortress): the ways to the Heart reach every rift; a
## wave comes; monsters walk toward the Heart, batter a gate down and drain the Fortress
## meter in the zones; a push sends one flying, a blast and a thrown crate kill them (the
## meter refills), one reaching the Heart takes a bite; bots get kills; how long 200 of them
## take a tick; the fortress falls and everything starts again (walls whole). Screenshots.
## Exits 1 if a step fails.
## Usage: godot -- --host --map res://maps/fortress.tscn --mode megayeet --bots 3 --port 24700 --tour <dir> --tour-mode megayeet

var world: Node
var out_dir := ""
var _failed := 0
var _camera: Camera3D
var mode: ModeMegaYeet
var horde: Horde
var pl: Player


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func():
		print("MEGAYEET CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	mode = world.mode_logic as ModeMegaYeet
	horde = world.horde
	pl = world.local_player
	pl.is_bot = true # (held still: no player input)
	pl.bot_brain = null
	for k in 50:
		if horde.field:
			break
		await _wait(0.1)
	var f := horde.field
	var reach := 0
	for s: MonsterSpawn in world.arena.monster_spawns:
		if f and f.distance(s.global_position) < FlowField.INF_COST:
			reach += 1
	_check("the ways to the Heart reach every rift", f != null and reach == world.arena.monster_spawns.size() and reach >= 4, "%d of %d rifts" % [reach, world.arena.monster_spawns.size()])
	_cam(Vector3(0, 70, 75), Vector3(0, 0, 5))
	await _wait(0.5)
	await _shot("m01_fortress")
	# A wave.
	mode.phase_end = world.now()
	await _wait(3.0)
	_check("a wave comes: monsters at the rifts", mode.wave == 1 and horde.count() > 3, "wave %d, %d monsters" % [mode.wave, horde.count()])
	var m: Horde.Monster = horde.monsters[0]
	var d0 := f.distance(m.pos)
	await _wait(3.0)
	_check("they walk toward the Heart", m.hp > 0.0 and f.distance(m.pos) < d0, "%d -> %d" % [d0, f.distance(m.pos)])
	_cam(m.pos + Vector3(6, 4, 6), m.pos + Vector3.UP)
	await _wait(0.3)
	await _shot("m02_shamblers")
	# A gate battered down: a pack right outside the north gate.
	var gate: Destructible = null
	for d: Destructible in world.arena.destructibles:
		if absf(d.global_position.z + 38.0) < 1.0 and absf(d.global_position.x) < 1.0:
			gate = d
	for k in 10:
		horde.server_spawn(Vector3(randf_range(-2, 2), 0, -44 - randf_range(0, 3)))
	_cam(Vector3(8, 9, -52), Vector3(0, 2, -38))
	var broke := false
	for k in 60:
		await _wait(0.5)
		if k == 6:
			await _shot("m03_at_the_gate")
		if gate and gate.broken_cells.size() > 4:
			broke = true
			break
	_check("they batter the gate down", broke, "%d cells broken" % (gate.broken_cells.size() if gate else -1))
	for k in 30: # (a few broken cells may not be a monster-sized hole yet: they keep at it)
		await _wait(0.5)
		if mode.meter < ModeMegaYeet.METER and (mode._zone_counts[1] + mode._zone_counts[2]) > 0:
			break
	await _shot("m04_through")
	_check("monsters in the zones drain the Fortress meter", mode.meter < ModeMegaYeet.METER and (mode._zone_counts[1] + mode._zone_counts[2]) > 0, "meter %.0f, in zones %s" % [mode.meter, mode._zone_counts])
	# A push sends one flying.
	pl.respawn(Vector3(30, 0, 30), 0.0)
	await _wait(0.3)
	var target := horde.server_spawn(Vector3(30, 0, 27))
	_face(pl, target.pos + Vector3.UP * 0.9)
	await get_tree().physics_frame
	world.gun_action(pl, GravityGun.Action.THROW)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("a push sends a monster flying", target.state == Horde.State.FLY or target.hp < target.max_hp, "state %d, hp %.0f" % [target.state, target.hp])
	# A blast among a crowd.
	var kills0 := mode.kills
	var meter0 := mode.meter
	for k in 12:
		horde.server_spawn(Vector3(-30 + randf_range(-2.5, 2.5), 0, 30 + randf_range(-2.5, 2.5)))
	var boom: Prop = world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, Vector3(-30, 0.7, 30)))
	_cam(Vector3(-22, 6, 38), Vector3(-30, 1, 30))
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.server_explode(boom)
	await _wait(0.15)
	await _shot("m05_blast")
	await _wait(0.3)
	_check("a blast kills a crowd (the meter refills)", mode.kills - kills0 >= 8 and mode.meter > meter0 - 30.0, "%d kills" % (mode.kills - kills0))
	# A crate thrown into one.
	var victim := horde.server_spawn(Vector3(26, 0, -26))
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(26, 1.0, -21)))
	await get_tree().physics_frame
	crate.linear_velocity = Vector3(0, 0, -16)
	crate.last_thrower = pl.player_id
	crate.last_thrown_time = world.now()
	await _wait(0.6)
	_check("a crate thrown into one crushes it (the thrower's kill)", victim.hp <= 0.0 and pl.score > 0, "hp %.0f, score %d" % [victim.hp, pl.score])
	# One reaching the Heart takes a bite.
	var before := mode.meter
	horde.server_spawn(Vector3(0, 0, 3.2))
	await _wait(1.5)
	_check("a monster reaching the Heart takes a bite", mode.meter <= before - ModeMegaYeet.HEART_BITE + 15.0, "%.0f -> %.0f" % [before, mode.meter])
	# Bots fight.
	var bot_kills := 0
	for k in 25:
		if horde.count() < 15:
			for j in 5:
				var a := randf() * TAU
				horde.server_spawn(Vector3(cos(a) * 15.0, 0, sin(a) * 15.0))
		await _wait(1.0)
		bot_kills = 0
		for q: Player in world.players.values():
			if q.is_bot and q != pl:
				bot_kills += q.score
		if bot_kills >= 3:
			break
	_check("bots fight the monsters (kills)", bot_kills >= 3, "%d bot kills" % bot_kills)
	# 200 of them: how long a server tick takes.
	horde.server_clear()
	await _wait(0.5)
	for k in 200:
		var a := randf() * TAU
		horde.server_spawn(Vector3(cos(a) * randf_range(25.0, 60.0), 0, sin(a) * randf_range(25.0, 60.0)))
	await _wait(0.5)
	var total := 0.0
	var ticks := 0
	for k in 90:
		var t0 := Time.get_ticks_usec()
		horde._physics_process(1.0 / 60.0)
		total += (Time.get_ticks_usec() - t0) / 1000.0
		ticks += 1
		await get_tree().physics_frame
	var per := total / ticks
	print("MEGAYEET PERF: %d monsters, %.2f ms a tick (horde), %d FPS" % [horde.count(), per, Engine.get_frames_per_second()])
	_check("200 monsters: the horde's server tick stays cheap", per < 12.0, "%.2f ms" % per)
	_cam(Vector3(0, 35, 70), Vector3(0, 0, 20))
	await _wait(0.4)
	await _shot("m06_two_hundred")
	# The fall, and a fresh start.
	mode.meter = 1.0
	await _wait(1.6)
	_check("the fortress falls when the meter runs out", mode.phase == ModeMegaYeet.Phase.OVER, "phase %d" % mode.phase)
	await _shot("m07_fallen")
	mode.phase_end = world.now()
	await _wait(0.25) # (straight after: the bots may punt a gate again soon enough)
	var whole: bool = world.arena.destructibles.all(func(d): return d.broken_cells.is_empty())
	_check("... and it all starts again (walls whole, the meter full, wave 0)", mode.phase == ModeMegaYeet.Phase.BREAK and mode.wave == 0 and mode.meter == ModeMegaYeet.METER and whole and horde.count() == 0, "phase %d wave %d meter %.0f walls whole %s" % [mode.phase, mode.wave, mode.meter, whole])
	print("MEGAYEET CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _face(q: Player, at: Vector3) -> void:
	var to := at - q.eye_position()
	q.yaw = atan2(-to.x, -to.z)
	q.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _cam(eye: Vector3, target: Vector3) -> void:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 70.0
		world.add_child(_camera)
	_camera.look_at_from_position(eye, target)
	_camera.make_current()


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
