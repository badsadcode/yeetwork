extends Node
## Developer check for MegaYeet (on the Fortress): the ways to the Heart reach every rift; a
## wave comes; monsters walk toward the Heart, batter a gate down and drain the Fortress
## meter in the zones; a push sends one flying, a blast and a thrown crate kill them (the
## meter refills), one reaching the Heart takes a bite; bots get kills; how long 200 of them
## take a tick; the fortress falls and everything starts again (walls whole). The kinds:
## runners outpace shamblers, a brute shrugs a push off and can't be grabbed, a ghost drifts
## through a wall, ignores a push and burns in a flashlight's beam, a climber gets over a
## wall, a bomber blows a gate in and a killed one takes its neighbours with it, fire spreads,
## a monster is grabbed and thrown, waves mix the kinds. Screenshots.
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
	get_tree().create_timer(260.0).timeout.connect(func():
		print("MEGAYEET CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	mode = world.mode_logic as ModeMegaYeet
	horde = world.horde
	pl = world.local_player
	pl.is_bot = true # (held still: no player input)
	pl.bot_brain = null
	# The bots stand still but for their own step (their pushes and kills would muddle the
	# rest), out of the way up on the outer wall (by the Heart they'd draw monsters to them).
	var brains := {}
	for q: Player in world.players.values():
		if q.is_bot and q.bot_brain:
			brains[q] = q.bot_brain
			q.bot_brain = null
			q.cmd.move = Vector2.ZERO
			q.cmd.jump = false
			q.respawn(Vector3(-24.0 + brains.size() * 4.0, 7.3, 38.0), 0.0)
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
	var bites := mode.heart_hits
	horde.server_spawn(Vector3(0, 0, 3.2))
	await _wait(1.5)
	_check("a monster reaching the Heart takes a bite", mode.heart_hits >= bites + 1 and mode.meter < before, "%.0f -> %.0f, %d bites" % [before, mode.meter, mode.heart_hits - bites])
	await _kinds()
	# Bots fight.
	for q: Player in brains:
		q.bot_brain = brains[q]
		q.respawn(mode.spawn_point(q), 0.0)
	horde.server_clear() # (a fresh lot round the keep for them, nothing left elsewhere)
	await _wait(0.3)
	var bot_kills := 0
	for k in 35:
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
	mode.meter = -200.0 # (run out, beyond what the bots' kills put back in a second)
	await _wait(1.6)
	_check("the fortress falls when the meter runs out", mode.phase == ModeMegaYeet.Phase.OVER, "phase %d" % mode.phase)
	await _shot("m07_fallen")
	mode.phase_end = world.now()
	await _wait(0.25) # (straight after: the bots may punt a gate again soon enough)
	var whole: bool = world.arena.destructibles.all(func(d): return d.broken_cells.is_empty())
	_check("... and it all starts again (walls whole, the meter full, wave 0)", mode.phase == ModeMegaYeet.Phase.BREAK and mode.wave == 0 and mode.meter == ModeMegaYeet.METER and whole and horde.count() == 0, "phase %d wave %d meter %.0f walls whole %s" % [mode.phase, mode.wave, mode.meter, whole])
	print("MEGAYEET CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _kinds() -> void:
	horde.server_clear()
	await _wait(0.3)
	# One of each, in a row (all drawn).
	var row := []
	for i in Horde.KIND_IDS.size():
		row.append(horde.server_spawn(Vector3(-6.0 + i * 2.4, 0, 30.0), Horde.KIND_IDS[i]))
	await _wait(0.2)
	var drawn := Horde.KIND_IDS.all(func(k): return horde._draw[k][0].multimesh.visible_instance_count >= 1)
	_check("every kind is drawn", drawn, "")
	_cam(Vector3(0, 2.4, 36.5), Vector3(0, 1.0, 30.0))
	await _wait(0.1)
	await _shot("m08_kinds")
	horde.server_clear()
	await _wait(0.2)
	# Runners outpace shamblers (far from anyone, the same way in).
	var sh := horde.server_spawn(Vector3(-30, 0, 55), "shambler")
	var ru := horde.server_spawn(Vector3(-28, 0, 55), "runner")
	var d_sh := f_dist(sh)
	var d_ru := f_dist(ru)
	await _wait(2.0)
	_check("runners outpace shamblers", (d_ru - f_dist(ru)) > (d_sh - f_dist(sh)) * 1.6, "%d vs %d" % [d_ru - f_dist(ru), d_sh - f_dist(sh)])
	# A brute: a push barely moves it, the gun can't hold it.
	# (an open spot: no prop near for the gun to catch instead)
	pl.respawn(Vector3(-10, 0, 30), 0.0)
	await _wait(0.3)
	var brute := horde.server_spawn(Vector3(-10, 0, 27.5), "brute")
	_face(pl, brute.pos + Vector3.UP)
	await get_tree().physics_frame
	await get_tree().physics_frame # (the horde has it in its buckets after a tick of its own)
	var hit_n := horde.server_punt(pl.eye_position(), pl.aim_direction(), 6.0, 0.5, 1.0, pl.player_id)
	var moved := brute.vel.length()
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await _wait(0.3)
	var held_brute := pl.gun.held_kind == GravityGun.Kind.MONSTER
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	_check("a brute: a push barely moves it, the gun can't hold it", hit_n == 1 and moved < 4.0 and brute.hp < brute.max_hp and brute.hp > 250.0 and not held_brute, "pushed %d, %.1f m/s, hp %.0f, held %s" % [hit_n, moved, brute.hp, held_brute])
	# Grab a shambler and throw it.
	await _wait(0.5)
	var grab := horde.server_spawn(Vector3(-4, 0, 27.5), "shambler")
	pl.respawn(Vector3(-4, 0, 30), 0.0)
	await _wait(0.3)
	_face(pl, grab.pos + Vector3.UP * 0.9)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	var held := false
	for k in 15: # (it comes at you and may knock you aside: keep aiming, the gun keeps trying)
		await _wait(0.1)
		held = pl.gun.held_kind == GravityGun.Kind.MONSTER and grab.state == Horde.State.HELD
		if held:
			break
		_face(pl, grab.pos + Vector3.UP * 0.9)
	_cam(Vector3(-8, 3.5, 33), grab.pos + Vector3.UP)
	await _shot("m09_held")
	world.gun_action(pl, GravityGun.Action.THROW)
	await _wait(0.3)
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await get_tree().physics_frame
	var flung := grab.vel.length()
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	_check("the gun grabs a monster and throws it", held and grab.state == Horde.State.FLY and flung > 15.0, "held %s, thrown at %.1f m/s" % [held, flung])
	# A ghost: through the outer wall, a push goes through it, a flashlight burns it.
	pl.torch_on = false # (off for now: the push test next)
	var ghost := horde.server_spawn(Vector3(8, 0, -43), "ghost")
	await _wait(6.5)
	# (past the outer wall's inner face, z -36.5; ghosts drift at 1.3 to 1.7 m/s)
	_check("a ghost drifts through the walls", ghost.hp > 0.0 and ghost.pos.z > -36.5, "at z %.1f" % ghost.pos.z)
	pl.respawn(ghost.pos + Vector3(0, -ghost.pos.y, 5.0), 0.0)
	await _wait(0.2)
	_face(pl, ghost.pos + Vector3.UP * 1.2)
	var hp_before := ghost.hp
	world.gun_action(pl, GravityGun.Action.THROW)
	await _wait(0.2)
	var hp_pushed := ghost.hp
	_face(pl, ghost.pos + Vector3.UP * 1.2)
	pl.torch_on = true
	var lit := false
	for k in 30:
		await _wait(0.1)
		_face(pl, ghost.pos + Vector3.UP * 1.2)
		if ghost.hp < hp_pushed - 10.0 or ghost.hp <= 0.0:
			lit = true
			break
	_check("... a push goes right through it; a flashlight's beam burns it", hp_pushed >= hp_before - 0.1 and lit, "%.0f -> %.0f after the push, lit %s" % [hp_before, hp_pushed, lit])
	# A climber goes over a wall (away from the gates).
	var climber := horde.server_spawn(Vector3(14, 0, -43), "climber")
	var top := 0.0
	for k in 60:
		await _wait(0.2)
		top = maxf(top, climber.pos.y)
		if k == 25:
			_cam(climber.pos + Vector3(5, 2, -4), climber.pos + Vector3.UP)
			await _shot("m10_climbing")
		if climber.hp > 0.0 and climber.pos.z > -36.0 and climber.pos.y < 1.0:
			break
	_check("a climber climbs the wall and over", top > 6.0 and climber.pos.z > -37.0, "highest %.1f m, at z %.1f" % [top, climber.pos.z])
	# A bomber blows a gate in (the east outer one).
	var east: Destructible = null
	for d: Destructible in world.arena.destructibles:
		if absf(d.global_position.x - 38.0) < 1.0 and absf(d.global_position.z) < 1.0:
			east = d
	var cells0 := east.broken_cells.size()
	var bomber := horde.server_spawn(Vector3(44, 0, 0.5), "bomber")
	for k in 40:
		await _wait(0.2)
		if bomber.hp <= 0.0:
			break
	await _wait(0.3)
	_check("a bomber blows the gate in", bomber.hp <= 0.0 and east.broken_cells.size() > cells0 + 3, "%d -> %d cells broken" % [cells0, east.broken_cells.size()])
	# A killed bomber goes off and takes the crowd round it.
	var b2 := horde.server_spawn(Vector3(-28, 0, -28), "bomber")
	var crowd := []
	for k in 6:
		crowd.append(horde.server_spawn(Vector3(-28 + randf_range(-2, 2), 0, -28 + randf_range(-2, 2)), "shambler"))
	await get_tree().physics_frame
	horde._hit(b2, 100.0, Vector3.ZERO, pl.player_id, "punt")
	await _wait(0.4)
	var dead := crowd.filter(func(m): return m.hp <= 0.0).size()
	_check("a killed bomber goes off, and the crowd round it with it", dead >= 5, "%d of 6" % dead)
	# Fire spreads through a crowd.
	var pack := []
	for k in 5: # (a tight knot round a crate about to burn)
		var a := k * TAU / 5.0
		pack.append(horde.server_spawn(Vector3(30 + cos(a) * 1.0, 0, -26 + sin(a) * 1.0), "shambler"))
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(30, 0.6, -26)))
	await get_tree().physics_frame
	world.server_ignite_prop(crate, 12.0)
	var burning := 0
	for k in 20:
		await _wait(0.2)
		burning = pack.filter(func(m): return m.burn > 0.0 or m.hp <= 0.0).size()
		if burning >= 4:
			break
	_cam(Vector3(31, 3, -21), Vector3(31, 1, -26))
	await _shot("m11_fire")
	_check("fire catches and spreads through a crowd", burning >= 4, "%d of 5 burning or burnt" % burning)
	# Waves mix the kinds.
	var was := mode.wave
	mode.wave = 8
	mode._spawned = 0
	mode._brutes = 3
	var kinds := {}
	for k in 300:
		kinds[mode._pick_kind()] = true
		mode._spawned += 1
	mode.wave = was
	_check("later waves mix every kind", Horde.KIND_IDS.all(func(k): return kinds.has(k)), str(kinds.keys()))


func f_dist(m) -> int:
	return horde.field.distance(m.pos)


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
