extends Node
## Developer tool: what a MegaYeet map costs at the Steam Deck's settings (run it with
## --graphics 0): at 1280 x 800, from a Yeet's view, frame times, draw calls and triangles in a
## quiet break, then with the Heart's Max Traps down, then a big wave, then a boss in it too;
## and how long each of the monsters' systems takes, one call each. Uncapped (no vsync), so
## frame times show the headroom and the hitches. CPU times carry over to a Deck roughly
## (slower by a factor); GPU times don't; draw calls and triangles do exactly. Prints the
## numbers; no pass or fail.
## Usage: godot -- --host --map res://maps/foundry.tscn --mode megayeet --bots 3 --graphics 0 --tour x --tour-mode deckperf

var world: Node
var out_dir := ""


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _wait(2.5)
	var compiles0 := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	print("DECK compiles so far (the map, the warm-up): %d" % compiles0)
	if world.mode_logic is ModePuzzle:
		await _level()
		return
	var mode := world.mode_logic as ModeMegaYeet
	var horde: Horde = world.horde
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	mode.phase_end = world.now() + 9999.0
	mode._send_state()
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var f: FlowField = horde.field
	var heart := mode.heart.global_position
	# Where a Yeet sees the most of it: the deepest open ground away from the Heart.
	var at := Vector3.INF
	var best := -1
	for i in f.walk.size():
		if f.walk[i] == 1 and f.dist[i] < FlowField.INF_COST and f.dist[i] > best and Vector2(heart.x, heart.z).distance_to(f.center(i)) < 26.0:
			best = f.dist[i]
			at = Vector3(f.center(i).x, f.height[i], f.center(i).y)
	pl.respawn(at + Vector3.UP * 0.2, atan2(at.x - heart.x, at.z - heart.z))
	await _wait(1.0)
	await _measure("quiet", vp)
	# Traps: as many as a map lets you put down, on open ground near here.
	var put := 0
	for i in f.walk.size():
		if put >= mode.heart.max_traps:
			break
		var c := f.center(i)
		var p := Vector3(c.x, f.height[i], c.y)
		if f.walk[i] != 1 or p.distance_to(at) > 40.0 or i % 37 != 0:
			continue
		var key: String = ["Spikes|spikes", "Fire grate|fire", "Mine|mine"][put % 3]
		pl.respawn(p + Vector3(0, 0.2, 3), 0.0)
		if ModeMegaYeet.placement(world, pl, key, p, 0.0, true).ok:
			world.server_place_trap(key, Transform3D(Basis.IDENTITY, p), pl.player_id)
			put += 1
	pl.respawn(at + Vector3.UP * 0.2, atan2(at.x - heart.x, at.z - heart.z))
	await _wait(1.0)
	await _measure("%d traps" % put, vp)
	# A big wave, in sight.
	for k in 200:
		var a := randf() * TAU
		var q := Vector3(at.x + cos(a) * randf_range(3.0, 30.0), 0, at.z + sin(a) * randf_range(3.0, 30.0))
		var cell := f.cell_of(q)
		if cell >= 0 and f.walk[cell] == 1:
			horde.server_spawn(Vector3(q.x, f.height[cell], q.z), ["shambler", "runner", "shambler", "climber", "shambler", "runner", "shambler", "ghost", "shambler", "shambler", "climber", "runner", "shambler", "bomber"][k % 14])
	mode.phase = ModeMegaYeet.Phase.WAVE
	mode._to_spawn = 0
	await _wait(1.0)
	await _measure("%d monsters" % horde.count(), vp)
	var b = horde.server_spawn(at + Vector3(0, 0, 8), "ram")
	b.max_hp = 1000000.0
	b.hp = b.max_hp
	await _wait(0.5)
	_systems(horde)
	await _measure("and a boss", vp)
	print("DECK compiles during the fight: %d" % (int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) - compiles0))
	get_tree().quit(0)


## A level (Adventure, Puzzle): from the spots to look from a map names (Marker3Ds called "View..."),
## else where the Yeet starts; then its fights, one after another, at their Max At Once.
func _level() -> void:
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var views: Array = world.arena.find_children("View*", "Marker3D", true, false)
	for v: Marker3D in views:
		pl.respawn(v.global_position, v.global_rotation.y)
		await _wait(1.0)
		await _measure(String(v.name), vp)
	if views.is_empty():
		await _measure("the start", vp)
	var horde: Horde = world.horde
	for n in world.arena.puzzle:
		if not n is Encounter:
			continue
		var e: Encounter = n
		pl.respawn(e.global_position + Vector3.UP * 0.2, 0.0)
		e.inputs.clear() # (off it goes, now)
		await _wait(0.5)
		for s in e._rift_nodes():
			for k in e.max_at_once / maxi(e._rift_nodes().size(), 1):
				horde.server_spawn((s as MonsterSpawn).spot(world.rng), "shambler")
		await _wait(1.0)
		await _measure("%s, %d monsters" % [e.name, horde.count()], vp)
		break
	print("DECK compiles during the fight: %d" % int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)))
	get_tree().quit(0)


func _measure(what: String, vp: RID) -> void:
	var times := PackedFloat32Array()
	var cpu := 0.0
	var gpu := 0.0
	var calls := 0.0
	var tris := 0.0
	var objs := 0.0
	var t0 := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		if (now - last) > 33000:
			print("SLOW %.0f ms at %.1f s (%s): physics max %.0f, process max %.0f, %d nodes, %d monsters, %d props, render cpu %.1f gpu %.1f, compiles %d" % [(now - last) / 1000.0, (Time.get_ticks_msec() - t0) / 1000.0, what, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), world.horde.count(), world.props.size(), RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)])
		last = now
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var n := float(maxi(times.size(), 1))
	var avg := 8000.0 / n
	times.sort()
	var p99: float = times[int(n * 0.99)] if times.size() > 1 else 0.0
	var top: float = times[-1] if times.size() > 0 else 0.0
	print("DECK %-14s %4d fps | frame %5.1f ms, 1%% worst %5.1f, worst %5.1f | render cpu %4.1f gpu %4.1f | %4d draws %7d tris %4d objects" % [what, int(n / 8.0), avg, p99, top, cpu / n, gpu / n, int(calls / n), int(tris / n), int(objs / n)])


## One call of each of the monsters' systems, timed.
func _systems(horde: Horde) -> void:
	var line := "DECK systems:"
	for s: Array in [["hash", horde._rebuild_hash], ["bot map", horde._update_bot_field], ["props hit", horde._props_hit.bind(world.now())], ["fire", horde._spread_fire], ["lights", horde._flashlights], ["traps", horde._trap_tick.bind(0.1)], ["bites", horde._bite_players.bind(world.now())], ["snapshot", horde._send_snapshot]]:
		var t := Time.get_ticks_usec()
		(s[1] as Callable).call()
		line += " %s %.2f" % [s[0], (Time.get_ticks_usec() - t) / 1000.0]
	var t2 := Time.get_ticks_usec()
	for m in horde.monsters:
		if m.state == Horde.State.WALK and not m.def.has("ghost"):
			horde._walk(m, 0.016, world.now())
	line += " | walk all %.2f (%d monsters)" % [(Time.get_ticks_usec() - t2) / 1000.0, horde.monsters.size()]
	print(line)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
