extends Node
## Developer check for MegaYeet (on the Fortress): the ways to the Heart reach every rift; a
## wave comes; monsters walk toward the Heart, batter a gate down and drain the Fortress
## meter in the zones; a push sends one flying, a blast and a thrown crate kill them (the
## meter refills), one reaching the Heart takes a bite; bots get kills; how long 200 of them
## take a tick; the fortress falls and everything starts again (walls whole). The kinds:
## runners outpace shamblers, a brute shrugs a push off and can't be grabbed, a ghost drifts
## through a wall, ignores a push and burns in a flashlight's beam, a climber gets over a
## wall, a bomber blows a gate in and a killed one takes its neighbours with it, fire spreads,
## a monster is grabbed and thrown, waves mix the kinds. The shop: personal Y$ earned by
## kills and waves held, spent in the shop window (a power-up, a trap onto a map's spot, every
## gate, the Heart healed), not without the Y$. Traps put down anywhere: from the shop, where
## you aim (a preview), paid when down, hurting monsters; not on the Heart, another trap,
## out of reach or past the Heart's Max Traps; picked up and put down again free, or sold for
## half; one still carried when the wave comes is sold. Screenshots.
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
	get_tree().create_timer(450.0).timeout.connect(func():
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
			world.gun_action(q, GravityGun.Action.GRAB_END) # (nor its gun still reaching for things)
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
		if mode.meter < mode.max_meter and (mode._zone_counts[1] + mode._zone_counts[2]) > 0:
			break
	await _shot("m04_through")
	_check("monsters in the zones drain the Fortress meter", mode.meter < mode.max_meter and (mode._zone_counts[1] + mode._zone_counts[2]) > 0, "meter %.0f, in zones %s" % [mode.meter, mode._zone_counts])
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
	await _way_out(brains)
	await _shop()
	await _shop_window()
	await _placing()
	await _team_lift(brains)
	await _boss_fight()
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
	var traps_down: bool = world.arena.puzzle.all(func(n): return not (n is TrapSpot) or not n.built)
	_check("... and it all starts again (walls whole, the meter full, wave 0, no traps or upgrades)", mode.phase == ModeMegaYeet.Phase.BREAK and mode.wave == 0 and mode.meter == mode.max_meter and whole and horde.count() == 0 and mode.ups == 0 and traps_down, "phase %d wave %d meter %.0f walls whole %s ups %d traps down %s" % [mode.phase, mode.wave, mode.meter, whole, mode.ups, traps_down])
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
	for id in world._burning_props.keys(): # (other fires out: there's a cap on how many burn at once)
		var bp: Prop = world.get_prop(id)
		if bp:
			world._server_put_out(0, id, bp.global_position)
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
	_check("later waves mix every kind (but the boss, who leads boss waves)", Horde.KIND_IDS.all(func(k): return kinds.has(k) or Horde.KINDS[k].has("boss")), str(kinds.keys()))


## A bot finds its way out of the keep to a monster beyond the inner wall, the gates shut: over
## the low keep wall, up a jump pad onto the inner wall, off its far side (BotField).
func _way_out(brains: Dictionary) -> void:
	mode.phase = ModeMegaYeet.Phase.BREAK # (no wave coming meanwhile: just the one monster)
	mode.phase_end = world.now() + 999.0
	mode._to_spawn = 0
	horde.server_clear()
	world.server_restore_walls()
	await _wait(0.2)
	if horde.field.refresh_gates():
		horde.field.solve()
	var at := Vector3(6, 0, -30)
	var target := horde.server_spawn(at, "shambler")
	target.speed = 0.0 # (it stays put: the bot has to get there)
	await _wait(2.3) # (the bots' map, made again with it on it)
	var route := horde.bot_field.trace(horde.field, mode.heart.global_position + Vector3(4, 0, 4))
	var over := false
	for p: Vector3 in route:
		over = over or p.y > 6.0
	var ends: bool = not route.is_empty() and Vector2(route[route.size() - 1].x - at.x, route[route.size() - 1].z - at.z).length() < 2.0
	_check("the bots' map from the Heart to beyond the inner wall (gates shut) goes up a pad and over", ends and over, "%d steps, over the wall %s, to the monster %s" % [route.size(), over, ends])
	var bot: Player = brains.keys()[0] if not brains.is_empty() else null
	if bot == null:
		return
	bot.respawn(mode.heart.global_position + Vector3(4, 0.2, 4), 0.0)
	bot.bot_brain = BotBrain.new(bot, world) # (fresh: not one left paused mid-thought)
	var reached := false
	var best := INF
	var tries := 0
	while not reached and tries < 2: # (a bot caught on something gets one more go from the Heart)
		tries += 1
		if tries > 1:
			bot.respawn(mode.heart.global_position + Vector3(4, 0.2, 4), 0.0)
			bot.bot_brain = BotBrain.new(bot, world)
		for k in 120: # (a minute: the long way round, a missed pad tried again)
			await _wait(0.5)
			if k == 16 and tries == 1:
				_cam(bot.global_position + Vector3(6, 5, 8), bot.global_position)
				await _shot("m12_bot_way_out")
			var d := bot.global_position.distance_to(target.pos)
			best = minf(best, d)
			if d < 6.5 or target.hp <= 0.0:
				reached = true
				break
	if not reached:
		var br = bot.bot_brain
		print("WAYOUT alive %s state %d at %s path %d/%d monster %s held %d" % [bot.is_alive(), bot.state, bot.global_position.snapped(Vector3.ONE * 0.1), br._path_i, br._path.size(), br._monster != null, bot.gun.held_kind])
	_check("... and a bot gets there by itself", reached, "closest %.1f m, %d go%s" % [best, tries, "" if tries == 1 else "es"])
	bot.bot_brain = null
	bot.cmd.move = Vector2.ZERO
	world.gun_action(bot, GravityGun.Action.GRAB_END)
	bot.respawn(Vector3(-24.0, 7.3, 38.0), 0.0)
	horde.server_clear()


## Between waves, spending the meter: a gate repaired, spikes built (a monster crossing them
## is hurt), a mine built (it goes off under the first monster), a team upgrade (stronger
## pushes); nothing for sale during a wave, nor below what's kept back.
func _shop() -> void:
	horde.server_clear()
	world.server_restore_walls()
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.phase_end = world.now() + 999.0
	mode.meter = mode.max_meter
	mode._send_state()
	await _wait(0.3)
	var gate: Destructible = null
	for d: Destructible in world.arena.destructibles:
		if absf(d.global_position.z + 38.0) < 1.0 and absf(d.global_position.x) < 1.0:
			gate = d
	world.server_damage_destructible(gate, gate.global_position, 2.5, 3000.0, Vector3(0, 0, 5), 0, 1.0)
	await _wait(0.3)
	var broken := gate.broken_cells.size()
	horde.request_gate_refresh()
	await _wait(0.8)
	var open_before: bool = horde.field.walk[horde.field.cell_of(gate.global_position)] == 1
	pl.respawn(Vector3(0, 0, -36.0), 0.0) # (well within Use's reach of the gate's middle)
	await _wait(0.6) # (landed: slow machines settle a moment after a respawn)
	_face(pl, gate.global_position)
	var reach := pl.eye_position().distance_to(gate.global_position)
	var m0 := mode.meter
	world.use_pressed(pl)
	await _wait(0.2)
	_check("between waves: Use on a broken gate repairs it, out of the meter", broken > 0 and gate.broken_cells.is_empty() and mode.meter < m0, "%d cells broken, meter %.0f -> %.0f, %.1f m from it" % [broken, m0, mode.meter, reach])
	# ... and shuts the monsters' way through again (they go by the grid, not by bumping into it).
	var gate_cell := horde.field.cell_of(gate.global_position)
	await _wait(0.8)
	var shut := horde.field.walk[gate_cell] == 2
	_check("a repaired gate stops the monsters again (their ways see it shut)", open_before and shut, "open when broken %s, shut when repaired %s" % [open_before, shut])
	var traps := {}
	for n in world.arena.puzzle:
		if n is TrapSpot:
			traps[String(n.name)] = n
	var spikes: TrapSpot = traps["SpikesN"]
	pl.respawn(Vector3(0, 0, -31.2), 0.0) # (within Use reach of its middle)
	await _wait(0.3)
	_face(pl, spikes.use_point())
	m0 = mode.meter
	world.use_pressed(pl)
	await _wait(0.3)
	_check("... Use on a trap spot builds its trap", spikes.built and spikes.active and absf(m0 - mode.meter - spikes.price()) < 0.5, "built %s, meter %.0f -> %.0f" % [spikes.active, m0, mode.meter])
	pl.respawn(mode.heart.global_position + Vector3(6, 0, 6), 0.0)
	var walker := horde.server_spawn(Vector3(0, 0, -36.2), "shambler")
	_cam(Vector3(5, 4, -28), Vector3(0, 0.5, -33.5))
	await _wait(1.5)
	await _shot("m13_spikes")
	for k in 40:
		await _wait(0.2)
		if walker.hp <= 0.0:
			break
	_check("spikes hurt (and slow) the monsters crossing them", walker.hp <= 0.0 and walker.cause == "spikes", "hp %.0f, %s" % [walker.hp, walker.cause])
	var mine: TrapSpot = traps["MineN"]
	pl.respawn(Vector3(0, 0, -15.2), 0.0)
	await _wait(0.3)
	_face(pl, mine.use_point())
	world.use_pressed(pl)
	await _wait(0.3)
	var mine_built := mine.active
	pl.respawn(mode.heart.global_position + Vector3(6, 0, 6), 0.0)
	var stepper := horde.server_spawn(Vector3(0, 0, -19.6), "shambler") # (in the courtyard, clear of the gate)
	for k in 60:
		await _wait(0.2)
		if not mine.built:
			break
	await _wait(0.3)
	_check("a mine goes off under the first monster (and is gone)", mine_built and not mine.built and not mine.active and stepper.hp <= 0.0, "built %s, still there %s, hp %.0f" % [mine_built, mine.built, stepper.hp])
	# A team upgrade at the Heart.
	pl.respawn(mode.heart.global_position + Vector3(0, 0, 2.2), 0.0)
	await _wait(0.3)
	_face(pl, mode.heart.global_position + Vector3.UP * 1.6)
	world.use_pressed(pl)
	await _wait(0.2)
	_check("... Use on the Heart buys a team upgrade (stronger pushes)", mode.ups == 1 and is_equal_approx(mode.gun_power(pl), 1.3), "%d bought" % mode.ups)
	await _shot("m14_break")
	mode.phase = ModeMegaYeet.Phase.WAVE
	mode._to_spawn = 3 # (a wave with monsters still to come: it doesn't end at once)
	mode._send_state()
	await _wait(0.1)
	world.use_pressed(pl)
	await _wait(0.2)
	var in_wave := mode.ups
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.meter = mode.max_meter * ModeMegaYeet.KEEP + 20.0
	mode._send_state()
	await _wait(0.1)
	world.use_pressed(pl)
	await _wait(0.2)
	_check("nothing for sale during a wave, nor below what's kept back", in_wave == 1 and mode.ups == 1, "during the wave %d, kept back %d" % [in_wave, mode.ups])
	mode.meter = mode.max_meter
	horde.server_clear()


## Personal Y$ and the shop window: a Yeet starts with some; a stylish kill earns more (and
## puts nothing in the meter: it's only life now); a wave held pays everyone; the shop sells
## a power-up (it lasts into the wave), builds the free trap spot nearest you, repairs every
## gate, heals the Heart; nothing without the Y$. The window opens on the shop key with the
## tab's wares, and closes itself when the wave comes.
func _shop_window() -> void:
	horde.server_clear()
	world.server_restore_walls()
	for n in world.arena.puzzle:
		if n is TrapSpot:
			(n as TrapSpot).server_clear()
	mode.personal = true
	mode.cash.clear()
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.phase_end = world.now() + 999.0
	mode.meter = mode.max_meter * 0.5
	mode._send_state()
	await _wait(0.3)
	_check("personal Y$: everyone starts with some", ModeMegaYeet.is_personal(world) and ModeMegaYeet.wallet(world, pl) == ModeMegaYeet.CASH_START, "%d Y$" % ModeMegaYeet.wallet(world, pl))
	var m0 := mode.meter
	var mon = horde.server_spawn(mode.heart.global_position + Vector3(12, 0, 12), "shambler")
	mon.attacker = pl.player_id
	mon.attacker_t = world.now()
	horde._kill(mon, "fall")
	mode._send_state()
	await _wait(0.2)
	var after_kill := ModeMegaYeet.wallet(world, pl)
	_check("a stylish kill earns Y$ (and puts nothing back in the meter)", after_kill == ModeMegaYeet.CASH_START + ModeMegaYeet.CASH_KILL + ModeMegaYeet.CASH_STYLE and mode.meter == m0, "%d Y$, meter %.0f -> %.0f" % [after_kill, m0, mode.meter])
	mode._wave_cleared()
	mode.phase_end = world.now() + 999.0
	await _wait(0.2)
	var paid := ModeMegaYeet.wallet(world, pl) - after_kill
	_check("a wave held pays every Yeet", paid == ModeMegaYeet.CASH_WAVE + 5 * mode.wave, "+%d Y$ (wave %d)" % [paid, mode.wave])
	mode.cash[pl.player_id] = 1000
	mode.meter = mode.max_meter * 0.5
	mode._send_state()
	await _wait(0.2)
	# The window.
	pl.respawn(Vector3(9.0, 0.2, 0.0), 0.0) # (east of the Heart: FireE is the fire grate nearest)
	await _wait(0.3)
	world.hud.open_shop()
	await _wait(0.6)
	var win: ShopWindow = world.hud._shop
	var trap_cards := win._cards.size() if win else 0
	_check("the shop key opens the window: the traps tab, a card for each kind", win != null and win.visible and trap_cards == 3, "%d cards" % trap_cards)
	await _shot("m15_shop_traps")
	var fire: TrapSpot = ModeMegaYeet._free_spot(world, pl, "Fire grate|fire")
	win._buy("trap:Fire grate|fire")
	await _wait(0.4)
	var placing: bool = world.trap_placer != null and world.trap_placer.active and world.trap_placer.key == "Fire grate|fire" and not win.visible
	world.trap_placer.stop()
	pl.respawn(fire.global_position + Vector3(0, 0, 4), 0.0) # (within reach)
	await _wait(0.3)
	world.place_trap("Fire grate|fire", fire.global_position, 0.0) # (put down on the map's spot)
	await _wait(0.4)
	_check("... a trap bought is put down where you aim: onto the map's spot of its kind there", placing and fire and fire.name == "FireE" and fire.active and ModeMegaYeet.placed_count(world) == 0 and ModeMegaYeet.wallet(world, pl) == 1000 - int(fire.price()), "placing %s, %s built %s, %d Y$" % [placing, fire.name if fire else "none", fire.active if fire else false, ModeMegaYeet.wallet(world, pl)])
	world.hud.open_shop()
	await _wait(0.4)
	win = world.hud._shop
	win._set_tab(1)
	await _wait(0.6)
	_check("... the power-ups tab", win._cards.size() == ModeMegaYeet.POWERS.size(), "%d cards" % win._cards.size())
	await _shot("m16_shop_powerups")
	var y0 := ModeMegaYeet.wallet(world, pl)
	win._buy("power:speed")
	await _wait(0.4)
	_check("... a power-up bought lasts into the wave", pl.buff_left("speed") > ModeMegaYeet.POWER_LASTS and ModeMegaYeet.wallet(world, pl) == y0 - 40, "%.0f s left, %d Y$" % [pl.buff_left("speed"), ModeMegaYeet.wallet(world, pl)])
	# Every gate repaired at once.
	var hit := 0
	for d: Destructible in world.arena.destructibles:
		if hit < 2:
			world.server_damage_destructible(d, d.global_position, 2.5, 3000.0, Vector3(0, 0, 5), 0, 1.0)
			hit += 1
	await _wait(0.3)
	var broken := 0
	for d: Destructible in world.arena.destructibles:
		broken += 0 if d.broken_cells.is_empty() else 1
	world.shop_buy("fix:all")
	await _wait(0.3)
	var still := 0
	for d: Destructible in world.arena.destructibles:
		still += 0 if d.broken_cells.is_empty() else 1
	_check("... repair every gate: all of them whole", broken >= 2 and still == 0, "%d broken, %d after" % [broken, still])
	win._set_tab(4)
	await _wait(0.4)
	m0 = mode.meter
	win._buy("heal")
	await _wait(0.3)
	_check("... heal the Heart (Y$ only)", absf(mode.meter - m0 - mode.max_meter * ModeMegaYeet.HEAL) < 0.5, "meter %.0f -> %.0f" % [m0, mode.meter])
	await _shot("m17_shop_heart")
	mode.cash[pl.player_id] = 10
	mode._send_state()
	await _wait(0.2)
	world.shop_buy("power:super")
	await _wait(0.3)
	_check("... nothing without the Y$", ModeMegaYeet.wallet(world, pl) == 10 and pl.buff_left("super") == 0.0, "%d Y$" % ModeMegaYeet.wallet(world, pl))
	mode.phase = ModeMegaYeet.Phase.WAVE
	mode._to_spawn = 3
	mode._send_state()
	await _wait(0.3)
	_check("... the window closes itself when the wave comes", not win.visible, "")
	# Back to the shared meter.
	mode.personal = false
	mode.cash.clear()
	mode._to_spawn = 0
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.meter = mode.max_meter
	for n in world.arena.puzzle:
		if n is TrapSpot:
			(n as TrapSpot).server_clear()
	pl.buffs.clear()
	mode._send_state()
	await _wait(0.2)


## Traps put down anywhere the monsters walk: bought in the shop, a preview where you aim,
## paid when it's down; it hurts a monster; refused on the Heart, on another trap, out of
## reach, past Max Traps; picked up and put down again (free, turned), or sold for half; one
## still carried when the wave comes is sold.
func _placing() -> void:
	horde.server_clear()
	mode.personal = true
	mode.cash.clear()
	mode.cash[pl.player_id] = 500
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.phase_end = world.now() + 999.0
	mode._send_state()
	var key := "Spikes|spikes"
	var spot := _open_ground()
	_check("traps anywhere: open ground the monsters walk, found", spot != Vector3.INF, "%s" % spot)
	if spot == Vector3.INF:
		return
	pl.respawn(spot + Vector3(0, 0, 4.5), 0.0)
	await _wait(0.4)
	_face(pl, spot)
	world.shop_buy("trap:" + key)
	await _wait(0.5)
	var placer: TrapPlacer = world.trap_placer
	var previewed := placer != null and placer.active and placer.ok and placer._at.distance_to(spot) < 0.6
	_check("... the shop's trap follows your aim, green where it fits", previewed, "active %s, ok %s (%s), at %s" % [placer.active, placer.ok, placer.why, placer._at])
	if pl.camera:
		pl.camera.make_current()
	await _wait(0.2)
	await _shot("m18_place_trap")
	var y0 := ModeMegaYeet.wallet(world, pl)
	placer.confirm()
	await _wait(0.4)
	var t: TrapSpot = world.arena.puzzle[world.arena.puzzle.size() - 1] if world.arena.puzzle[-1] is TrapSpot else null
	var down := t != null and t.placed and t.active and t.global_position.distance_to(spot) < 0.6
	_check("... put down: built there, paid when it's down", down and ModeMegaYeet.placed_count(world) == 1 and ModeMegaYeet.wallet(world, pl) == y0 - 80, "down %s, %d Y$" % [down, ModeMegaYeet.wallet(world, pl)])
	if not down:
		return
	var m = horde.server_spawn(spot + Vector3(0.5, 0, 0.5), "shambler")
	m.speed = 0.0
	await _wait(0.6)
	_check("... a monster in it is hurt and slowed", m.hp < 40.0 and m.slow_to < 1.0, "hp %.0f, slowed to %.2f" % [m.hp, m.slow_to])
	horde.server_clear()
	# Where it can't go.
	var back := pl.global_position
	pl.respawn(mode.heart.global_position + Vector3(4, 0, 0), 0.0)
	await _wait(0.3)
	var why_heart: String = ModeMegaYeet.placement(world, pl, key, mode.heart.global_position + Vector3(0.5, 0, 0), 0.0).why
	pl.respawn(back, 0.0)
	await _wait(0.3)
	var why_far: String = ModeMegaYeet.placement(world, pl, key, pl.global_position + Vector3(0, 0, 25), 0.0).why
	var why_on: String = ModeMegaYeet.placement(world, pl, key, spot + Vector3(1, 0, 0), 0.0).why
	_check("... not on the Heart, not on another trap, not out of reach", why_heart == "Too close to the Heart" and why_on == "On another trap" and why_far == "Too far away", "%s / %s / %s" % [why_heart, why_on, why_far])
	mode.heart.max_traps = 1
	var why_full: String = ModeMegaYeet.placement(world, pl, key, spot + Vector3(0, 0, -5), 0.0).why
	var item: Dictionary = ModeMegaYeet.shop_items(world, pl).filter(func(it): return it.id == "trap:" + key)[0]
	mode.heart.max_traps = 12
	_check("... not past the Heart's Max Traps (the shop counts them; the map's own spots still take one)", why_full.begins_with("All 1 traps are down") and String(item.about).contains("1 of 1 placed"), "%s / %s" % [why_full, item.about])
	# Picked up, put down again (free, turned).
	t.server_used(pl)
	await _wait(0.3)
	var carrying := placer.active and placer.free and t.gone and ModeMegaYeet.placed_count(world) == 0
	_face(pl, spot)
	placer._turn = PI * 0.25
	await _wait(0.4)
	var y1 := ModeMegaYeet.wallet(world, pl)
	placer.confirm()
	await _wait(0.4)
	var t2: TrapSpot = world.arena.puzzle[-1] if world.arena.puzzle[-1] is TrapSpot else null
	var turned := t2 != null and t2 != t and t2.active and absf(wrapf(t2.global_rotation.y - (pl.yaw + PI * 0.25), -PI, PI)) < 0.05
	_check("... Use picks it up (preview, free), put down again elsewhere or turned: free", carrying and turned and ModeMegaYeet.wallet(world, pl) == y1, "carrying %s, turned %s, %d -> %d Y$" % [carrying, turned, y1, ModeMegaYeet.wallet(world, pl)])
	if t2 == null:
		return
	t2.server_used(pl)
	await _wait(0.3)
	var y2 := ModeMegaYeet.wallet(world, pl)
	placer.cancel()
	await _wait(0.3)
	_check("... or sold, for half", ModeMegaYeet.wallet(world, pl) == y2 + 40 and ModeMegaYeet.placed_count(world) == 0, "%d -> %d Y$" % [y2, ModeMegaYeet.wallet(world, pl)])
	# Still carried when the wave comes: sold.
	_face(pl, spot)
	world.shop_buy("trap:" + key)
	await _wait(0.4)
	placer.confirm()
	await _wait(0.4)
	(world.arena.puzzle[-1] as TrapSpot).server_used(pl)
	await _wait(0.3)
	var y3 := ModeMegaYeet.wallet(world, pl)
	var wave0 := mode.wave
	mode._start_wave()
	await _wait(0.3)
	_check("... one still carried when the wave comes is sold, and the preview's gone", not placer.active and ModeMegaYeet.wallet(world, pl) == y3 + 40, "placing %s, %d -> %d Y$" % [placer.active, y3, ModeMegaYeet.wallet(world, pl)])
	horde.server_clear()
	mode._to_spawn = 0
	mode.wave = wave0
	mode.personal = false
	mode.cash.clear()
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.phase_end = world.now() + 999.0
	mode._send_state()
	await _wait(0.2)


## Open, flat ground a fair way from the Heart, where monsters walk (the FlowField), with no
## trap spot near: a place to put a trap down (Vector3.INF if there's none).
func _open_ground() -> Vector3:
	var f := horde.field
	var h := mode.heart.global_position
	for i in f.walk.size():
		if f.walk[i] != 1 or f.dist[i] >= FlowField.INF_COST:
			continue
		var p := Vector3(f.origin.x + (i % f.nx + 0.5) * FlowField.CELL, f.height[i], f.origin.y + (i / f.nx + 0.5) * FlowField.CELL)
		var d := Vector2(p.x - h.x, p.z - h.z).length()
		if d < 6.0 or d > 22.0:
			continue
		var clear := true
		for n in world.arena.puzzle:
			if n is TrapSpot and (n as TrapSpot).global_position.distance_to(p) < 5.0:
				clear = false
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var c := f.cell_of(p + Vector3(dx, 0, dz))
				if c < 0 or f.walk[c] != 1 or absf(f.height[c] - p.y) > 0.15:
					clear = false
		if clear:
			return p
	return Vector3.INF


## The iron ball: one gun alone only strains at it; a second lifts it; they throw it together
## (both guns let go) and it flattens a brute in its way.
func _team_lift(brains: Dictionary) -> void:
	horde.server_clear()
	var helper: Player = brains.keys()[0] if not brains.is_empty() else null
	if helper == null:
		return
	var ball: Prop = world.server_spawn_prop("iron_ball", Transform3D(Basis.IDENTITY, Vector3(-9.0, 1.2, 30.0)))
	await _wait(1.0)
	pl.respawn(Vector3(-12.5, 0, 30.0), 0.0)
	helper.respawn(Vector3(-11.5, 0, 33.0), 0.0)
	await _wait(0.4)
	_face(pl, ball.global_position)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await _wait(0.8)
	var alone := pl.gun.held_kind == GravityGun.Kind.PROP and ball.lift_count == 1 and ball.global_position.y < 1.6
	_check("an iron ball: one gun alone only strains at it", alone, "holding %s, %d pulling, y %.1f" % [pl.gun.held_kind == GravityGun.Kind.PROP, ball.lift_count, ball.global_position.y])
	_face(helper, ball.global_position)
	world.gun_action(helper, GravityGun.Action.GRAB_START)
	var lifted := false
	for k in 20:
		await _wait(0.1)
		_face(pl, ball.global_position + Vector3.UP * 0.5)
		_face(helper, ball.global_position + Vector3.UP * 0.5)
		if ball.lift_count == 2 and ball.global_position.y > 1.8:
			lifted = true
			break
	_cam(Vector3(-6, 3, 37), ball.global_position)
	await _shot("m15_team_lift")
	_check("... two together lift it", lifted, "%d pulling, y %.1f" % [ball.lift_count, ball.global_position.y])
	var brute := horde.server_spawn(Vector3(5.0, 0, 30.0), "brute")
	brute.speed = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_face(pl, brute.pos + Vector3.UP * 4.0)
	_face(helper, brute.pos + Vector3.UP * 4.0)
	await _wait(0.4)
	world.gun_action(pl, GravityGun.Action.THROW)
	await _wait(0.4)
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await get_tree().physics_frame
	var speed := ball.linear_velocity.length()
	var let_go := pl.gun.held_kind == GravityGun.Kind.NONE and helper.gun.held_kind == GravityGun.Kind.NONE
	_check("... and throw it together (both let go)", speed > 12.0 and let_go, "%.1f m/s, let go %s" % [speed, let_go])
	for k in 30:
		await _wait(0.1)
		if brute.hp <= 0.0:
			break
	_check("the iron ball flattens a brute", brute.hp <= 0.0, "hp %.0f" % brute.hp)
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	world.gun_action(helper, GravityGun.Action.GRAB_END)
	if is_instance_valid(ball):
		world.server_despawn_prop(ball)
	horde.server_clear()


## The boss: a boss wave brings the Siege Golem (and its bar on the HUD); a push and the gun
## do nothing to it; it stomps a Yeet close by, throws a boulder at one up on the wall, calls
## a pack; the iron ball takes a big bite out of it; brought down, it pays the meter back.
func _boss_fight() -> void:
	horde.server_clear()
	await _wait(0.2)
	mode.wave = mode.heart.boss_every - 1
	mode._start_wave()
	await _wait(0.8)
	var b = mode.boss
	_check("a boss wave brings the Siege Golem, its health on the HUD", b != null and b.kind == "golem" and world.hud._boss_bar.visible and horde._draw["golem"][0].multimesh.visible_instance_count == 1, "boss %s, bar %s" % [b != null, world.hud._boss_bar.visible])
	horde.server_clear()
	mode.boss = null
	mode.phase = ModeMegaYeet.Phase.BREAK
	mode.phase_end = world.now() + 999.0
	mode._to_spawn = 0
	await _wait(0.2)
	# One of our own, held in place.
	var g = horde.server_spawn(Vector3(-20, 0, 30), "golem")
	g.speed = 0.0
	g.stomp_cd = 99.0
	g.throw_cd = 99.0
	g.call_cd = 99.0
	mode.boss = g
	pl.respawn(Vector3(-20, 0, 25.5), 0.0)
	await _wait(0.4)
	_face(pl, g.pos + Vector3.UP * 2.0)
	var hp0: float = g.hp
	var pushed := horde.server_punt(pl.eye_position(), pl.aim_direction(), 6.0, 0.5, 1.0, pl.player_id)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await _wait(0.3)
	var held := pl.gun.held_kind == GravityGun.Kind.MONSTER
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	_check("a push doesn't move it, the gun can't hold it", pushed == 1 and g.state == Horde.State.WALK and not held and g.hp > hp0 - 40.0, "pushed %d, state %d, held %s" % [pushed, g.state, held])
	_cam(Vector3(-12, 4, 22), g.pos + Vector3.UP * 3.0)
	await _shot("m16_golem")
	# Its stomp (standing where it throws you down the open corridor, not into a wall).
	pl.respawn(Vector3(-24.5, 0, 30), 0.0)
	await _wait(0.3)
	var hp_pl := pl.hp
	g.stomp_cd = 0.0
	var thrown := false
	for k in 10:
		await _wait(0.1)
		if pl.velocity.length() > 8.0 or pl.state == Player.State.RAGDOLL:
			thrown = true
			break
	_check("its stomp sends a Yeet close by flying", thrown and pl.hp < hp_pl, "hp %.0f -> %.0f" % [hp_pl, pl.hp])
	pl.hp = 100.0
	# A boulder at a Yeet up on the wall.
	pl.respawn(Vector3(-20, 7.3, 38.0), 0.0)
	await _wait(0.4)
	var rocks: int = horde._boulders.size()
	g.throw_cd = 0.0
	await _wait(0.6)
	_check("it throws a boulder at a Yeet up on the wall", horde._boulders.size() > rocks, "%d boulders" % horde._boulders.size())
	# Its call.
	var id0: int = horde._next_id # (counting the ones that come, not the ones still standing: a rolling boulder may get one)
	g.call_cd = 0.0
	await _wait(0.3)
	_check("it calls a pack out of the ground", horde._next_id - id0 >= 5, "%d came" % (horde._next_id - id0))
	# The iron ball.
	var ball: Prop = world.server_spawn_prop("iron_ball", Transform3D(Basis.IDENTITY, g.pos + Vector3(-7, 3, 0)))
	await get_tree().physics_frame
	ball.linear_velocity = ((g.pos + Vector3.UP * 2.5) - ball.global_position).normalized() * 18.0
	ball.last_thrower = pl.player_id
	ball.last_thrown_time = world.now()
	var before: float = g.hp
	for k in 15:
		await _wait(0.1)
		if g.hp < before - 1.0:
			break
	_check("the iron ball takes a big bite out of it", before - g.hp >= 600.0, "%.0f -> %.0f" % [before, g.hp])
	# Down it goes: the reward.
	mode.meter = mode.max_meter * 0.5
	var m0 := mode.meter
	g.hp = 30.0
	world.server_explode_at(g.pos + Vector3.UP * 1.5, 6.0, pl.player_id)
	await _wait(0.8)
	_check("brought down, it pays the meter back (the bar goes)", g.hp <= 0.0 and mode.boss == null and mode.meter >= m0 + mode.heart.boss_reward - 1.0 and not world.hud._boss_bar.visible, "meter %.0f -> %.0f" % [m0, mode.meter])
	if is_instance_valid(ball):
		world.server_despawn_prop(ball)
	horde.server_clear()
	mode.meter = mode.max_meter


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
